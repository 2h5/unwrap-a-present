--[=[
	Lobby (server system)
	Owns: Start pads, party of up to 4, teleport to run place, booths, lobby night clock.
	Must never: Hold any loot or cash logic. It mirrors shelves for display and moves players.
	Lobby place: builds the field (Field.luau), wires pads (Party.luau) and booths, mirrors each
	player's shelf and vault crate, teleports a party with a token (N9, N19) and offers a rejoin (N10).
	Run place: admits only players named by a valid token, holds the run until the party arrives, and
	sends everyone back after the bank. In Studio, or with place ids still 0, both sides fall back to local play.
	Read first: src/server/Lobby/README.md
]=]

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local Data = require(script.Parent.Parent.Data.Data)
local Economy = require(script.Parent.Parent.Economy.Economy)
local RunState = require(script.Parent.Parent.Present.RunState)
local RateLimit = require(script.Parent.Parent.Tear.RateLimit)
local Field = require(script.Parent.Field)
local Party = require(script.Parent.Party)

local Lobby = {}

local L = Config.Lobby
local IS_LOBBY = workspace:GetAttribute("PlaceKind") == "Lobby"
local TOKEN_MAP = "PartyTokens"

local limiter = RateLimit.new(Config.Tear.maxRequestsPerSecond)
local tokens: MemoryStoreHashMap? = nil

---------------------------------------------------------------- shared

-- True when teleports can work: a live server and both place ids created. Studio cannot teleport.
local function linked(): boolean
	return not RunService:IsStudio() and Config.Places.run ~= 0 and Config.Places.lobby ~= 0
end

local function tokenMap(): MemoryStoreHashMap?
	if not tokens then
		local ok, map = pcall(MemoryStoreService.GetHashMap, MemoryStoreService, TOKEN_MAP)
		tokens = if ok then map else nil
	end
	return tokens
end

local function sendToLobby(players: { Player })
	if not linked() then
		return
	end
	for _, player in players do
		Data.release(player)
	end
	local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, Config.Places.lobby, players)
	if not ok then
		warn(`Lobby: teleport to the lobby failed: {err}`)
		for _, player in players do
			Data.reload(player)
		end
	end
end

---------------------------------------------------------------- lobby place

local field: any = nil
local queue = Party.newQueue()
local queueLabel: TextLabel? = nil
local launching: { [Player]: boolean } = {}

local function tierOf(player: Player): number
	local data = Data.get(player)
	local pick = player:GetAttribute("NextTier")
	if data and typeof(pick) == "number" and pick >= 1 and pick <= data.tier then
		return pick
	end
	return if data then data.tier else 1
end

local function onPad(player: Player, pad: BasePart, slack: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local offset = root.Position - pad.Position
	local half = pad.Size.X / 2 + slack
	return math.abs(offset.X) <= half and math.abs(offset.Z) <= half
end

-- Sends `members` to a fresh reserved run server with a party token (N9) and the host's tier (N13).
local function launch(members: { Player }, tierNumber: number)
	for _, player in members do
		if launching[player] then
			return
		end
	end
	if not linked() then
		local why = if RunService:IsStudio() then "Runs start in the live game, not in Studio" else "The run place is not set up yet"
		for _, player in members do
			Economy.refresh(player, why)
		end
		return
	end
	for _, player in members do
		launching[player] = true
	end
	local ok, code = pcall(TeleportService.ReserveServer, TeleportService, Config.Places.run)
	local token = HttpService:GenerateGUID(false)
	local userIds = {}
	for _, player in members do
		table.insert(userIds, player.UserId)
	end
	local map = tokenMap()
	local stored = ok and map and pcall(map.SetAsync, map, token, { userIds = userIds, tier = tierNumber }, L.tokenSeconds)
	if not ok or not stored then
		for _, player in members do
			launching[player] = nil
			Economy.refresh(player, "Could not start the run. Try again.")
		end
		return
	end
	for _, player in members do
		local data = Data.get(player)
		if data then
			data.rejoin = { accessCode = code, expiresAt = 0 } -- the only teleport data kept (N10)
		end
		Data.release(player)
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	options:SetTeleportData({ token = token })
	local sent, err = pcall(TeleportService.TeleportAsync, TeleportService, Config.Places.run, members, options)
	if not sent then
		warn(`Lobby: teleport failed: {err}`)
		for _, player in members do
			launching[player] = nil
			Data.reload(player)
		end
	end
end

local function rejoin(player: Player)
	local data = Data.get(player)
	if not data or not linked() or data.rejoin.accessCode == "" or data.rejoin.expiresAt < os.time() then
		return
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = data.rejoin.accessCode
	options:SetTeleportData({ rejoin = true })
	Data.release(player)
	local ok = pcall(TeleportService.TeleportAsync, TeleportService, Config.Places.run, { player }, options)
	if not ok then
		Data.reload(player)
	end
end

-- Mirrors each player's shelf onto a board in the shelf row (the client Shelf system draws it).
local function mirrorShelf(player: Player)
	if not field then
		return
	end
	local data = Data.get(player)
	local model = field.shelves:FindFirstChild(`Shelf_{player.UserId}`)
	if not data then
		return
	end
	if not model then
		local slot = #field.shelves:GetChildren() + 1
		model = Instance.new("Model")
		model.Name = `Shelf_{player.UserId}`
		local spot = Field.shelfSpot(slot)
		local back = Instance.new("Part")
		back.Name = "Board"
		back.Anchored = true
		back.Size = Vector3.new(1, 6, 6)
		back.Position = spot + Vector3.new(-0.5, 3, 0)
		back.Material = Enum.Material.WoodPlanks
		back.Color = Color3.fromHex(Config.Palette.cardboard)
		back.Parent = model
		model.PrimaryPart = back
		model:SetAttribute("OwnerId", player.UserId)
		model:SetAttribute("OwnerName", player.DisplayName)
		model.Parent = field.shelves

		-- The vault crate on the porch (P2): a prompt that opens the owner's vault.
		local crate = Instance.new("Part")
		crate.Name = `Crate_{player.UserId}`
		crate.Anchored = true
		crate.Size = Vector3.new(2.5, 2.5, 2.5)
		crate.Position = field.porch.Position + Vector3.new(-6 + (slot - 1) * 3 % 12, 1.75, 2)
		crate.Material = Enum.Material.Cardboard
		crate.Color = Color3.fromHex(Config.Palette.cardboard)
		crate:SetAttribute("OwnerId", player.UserId)
		crate.Parent = field.folder
		Field.label(crate, `{player.DisplayName}'s vault`, 2.5)
		local prompt = Field.prompt(crate, "VaultPrompt", "Vault", player.DisplayName)
		prompt:SetAttribute("OwnerId", player.UserId)
	end
	model:SetAttribute("Capacity", Economy.shelfCapacity(player, data))
	model:SetAttribute("Items", HttpService:JSONEncode(data.shelf))
end

local function unmirror(player: Player)
	if not field then
		return
	end
	local model = field.shelves:FindFirstChild(`Shelf_{player.UserId}`)
	if model then
		model:Destroy()
	end
	local crate = field.folder:FindFirstChild(`Crate_{player.UserId}`)
	if crate then
		crate:Destroy()
	end
end

local function padLoop()
	while true do
		task.wait(L.padPollSeconds)
		local now = os.clock()
		for _, userId in table.clone(queue.members) do
			local player = Players:GetPlayerByUserId(userId)
			if not player or not onPad(player, field.pads[3], L.padStuds) then
				Party.leave(queue, userId)
			end
		end
		local members = Party.take(queue, now, Config.Matchmaking.maxParty, Config.Matchmaking.waitSeconds)
		if members then
			local players = {}
			for _, userId in members do
				local player = Players:GetPlayerByUserId(userId)
				if player then
					table.insert(players, player)
				end
			end
			if #players > 0 then
				task.spawn(launch, players, tierOf(players[1]))
			end
		end
		if queueLabel then
			local left = Party.waitLeft(queue, now, Config.Matchmaking.waitSeconds)
			queueLabel.Text = if left
				then `Join anyone · {#queue.members}/{Config.Matchmaking.maxParty} · {math.ceil(left)} s`
				else "Join anyone"
		end
	end
end

local function initLobby()
	field = Field.build()
	local solo = Field.prompt(field.pads[1], "SoloPrompt", "Start solo run")
	local party = Field.prompt(field.pads[2], "PartyPrompt", "Start party run", "You and friends on the pad")
	local anyone = Field.prompt(field.pads[3], "AnyPrompt", "Join anyone", "Up to 4 players")
	queueLabel = field.pads[3]:FindFirstChild("Label") and field.pads[3].Label:FindFirstChildOfClass("TextLabel")
	Field.prompt(field.booths.Rewards, "RewardsPrompt", "Rewards")
	Field.prompt(field.booths.Classes, "ClassesPrompt", "Classes")
	Field.prompt(field.booths.Shop, "StorePrompt", "Shop")

	solo.Triggered:Connect(function(player)
		launch({ player }, tierOf(player))
	end)
	party.Triggered:Connect(function(host)
		local standing = {}
		for _, player in Players:GetPlayers() do
			if onPad(player, field.pads[2], 0) then
				table.insert(standing, player.UserId)
			end
		end
		local ids = Party.fromPad(host.UserId, standing, function(userId)
			local ok, friends = pcall(host.IsFriendsWith, host, userId)
			return ok and friends
		end, Config.Matchmaking.maxParty)
		local members = {}
		for _, userId in ids do
			table.insert(members, Players:GetPlayerByUserId(userId))
		end
		launch(members, tierOf(host))
	end)
	anyone.Triggered:Connect(function(player)
		Party.join(queue, player.UserId, os.clock(), Config.Matchmaking.maxParty)
	end)

	Data.onLoaded(function(player)
		mirrorShelf(player)
	end)
	Economy.onProfileChanged(mirrorShelf)
	Players.PlayerRemoving:Connect(function(player)
		Party.leave(queue, player.UserId)
		launching[player] = nil
		unmirror(player)
	end)
	task.spawn(padLoop)
end

---------------------------------------------------------------- run place

local admitted: { number } = {} -- userIds of this run's party
local runTier: number? = nil
local partyKnown = Instance.new("BindableEvent")

local function admit(player: Player)
	if not linked() then
		return -- local play (Studio, or places not created yet): everyone is in
	end
	if Party.admits(admitted, player.UserId) then
		return -- a party member arriving late or rejoining (N10)
	end
	local joinData = player:GetJoinData()
	local token = joinData.TeleportData and joinData.TeleportData.token
	local map = tokenMap()
	if typeof(token) == "string" and map then
		local ok, record = pcall(map.GetAsync, map, token)
		if ok and record and Party.admits(record.userIds, player.UserId) then
			if #admitted == 0 then
				admitted = record.userIds
				runTier = record.tier
				partyKnown:Fire()
			end
			if Party.admits(admitted, player.UserId) then
				return
			end
		end
	end
	sendToLobby({ player }) -- no valid token (N9)
end

-- Run place: yields until the party is known and here (or arrivalWaitSeconds pass), then returns the
-- run's tier name. Returns nil in local play, where Present picks the tier itself.
function Lobby.waitForParty(): string?
	if IS_LOBBY or not linked() then
		return nil
	end
	if #admitted == 0 then
		partyKnown.Event:Wait()
	end
	local deadline = os.clock() + L.arrivalWaitSeconds
	while os.clock() < deadline do
		local here = 0
		for _, userId in admitted do
			if Players:GetPlayerByUserId(userId) then
				here += 1
			end
		end
		if here >= #admitted then
			break
		end
		task.wait(0.5)
	end
	return Config.Tiers.order[runTier or 1]
end

-- Run place, after the bank: everyone goes back to the lobby (Diagram B). Returns true if they were
-- sent; false in local play, where the next run starts here.
function Lobby.runEnded(): boolean
	if IS_LOBBY or not linked() then
		return false
	end
	for _, player in Players:GetPlayers() do
		local data = Data.get(player)
		if data then
			data.rejoin = { accessCode = "", expiresAt = 0 }
		end
	end
	sendToLobby(Players:GetPlayers())
	return true
end

local function initRun()
	Players.PlayerAdded:Connect(admit)
	for _, player in Players:GetPlayers() do
		task.spawn(admit, player)
	end
	-- Leaving mid-run opens the 2-minute rejoin window (N10); after the bank there is nothing to rejoin.
	Data.beforeRelease(function(_, data)
		local state = RunState.get()
		local midRun = state == "Unwrapping" or state == "Night" or state == "CoreLid" or state == "Reveal"
		data.rejoin.expiresAt = if midRun and data.rejoin.accessCode ~= "" then os.time() + Config.Run.rejoinWindowSeconds else 0
	end)
end

---------------------------------------------------------------- init

function Lobby.isLobby(): boolean
	return IS_LOBBY
end

function Lobby.init()
	Remotes.get("LobbyRequest").OnServerEvent:Connect(function(player, kind)
		if IS_LOBBY and kind == "Rejoin" and RateLimit.allow(limiter, player, os.clock()) then
			rejoin(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		RateLimit.forget(limiter, player)
	end)
	if IS_LOBBY then
		initLobby()
	else
		initRun()
	end
end

return Lobby
