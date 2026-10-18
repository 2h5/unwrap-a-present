--[=[
	Loot (server system)
	Owns: Rarity rolls, side-gift spawn, RunBag, core gift, Bank, Index, Shelf state.
	Must never: Roll on the client or re-roll on request. Every roll is made once, here, from a
	server-seeded Rng; the client is told what happened.
	Pure, tested logic: Rarity, Shelf, Index, Bank. This file is the Roblox glue: side-gifts pop from a
	cleared layer and fly to the nearest player (cash on pickup, N32), the shared RunBag, the core
	reveal, the bank (every finisher banks a copy, N14) and the bank screen's sell / replace choices.
	Read first: src/server/Loot/README.md
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Gifts = require(ReplicatedStorage.Shared.Gifts.Gifts)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local Rng = require(ReplicatedStorage.Shared.Rng.Rng)
local Data = require(script.Parent.Parent.Data.Data)
local Economy = require(script.Parent.Parent.Economy.Economy)
local Nest = require(script.Parent.Parent.Present.Nest)
local RunState = require(script.Parent.Parent.Present.RunState)
local RateLimit = require(script.Parent.Parent.Tear.RateLimit)
local Tear = require(script.Parent.Parent.Tear.Tear)
local Bank = require(script.Parent.Bank)
local Index = require(script.Parent.Index)
local Rarity = require(script.Parent.Rarity)
local Shelf = require(script.Parent.Shelf)

type BagItem = { giftId: string, rarity: string, kind: string, depth: number, mutation: string? }

local Loot = {}

local RARITY = {
	order = Config.RarityOrder,
	odds = Config.RarityOdds,
	tiers = Config.Tiers.order,
	packageInnerSecretPercent = Config.Loot.packageInnerSecretPercent,
	firstRunMinRarity = Config.Loot.firstRunMinRarity,
	mutationChance = Config.Loot.mutationChance,
	mutationMinRarity = Config.Loot.mutationMinRarity,
	mutations = Config.Loot.launchMutations,
}

local SHELF = { slotSizes = {}, stackMax = Config.Shelf.stackMax }
for rarity, entry in Config.Rarity do
	SHELF.slotSizes[rarity] = entry.shelfSlots
end

local GEMS = {
	completed = Config.BankGems.completed,
	noDowns = Config.BankGems.noDowns,
	tickSurvived = Config.BankGems.tickSurvived,
	lowerTier = Config.Tiers.lowerTierGemsPerRun,
}

local run: any = nil -- see Loot.startRun
local banking: { [Player]: { pending: { BagItem } } } = {}
local bankDoneListeners: { () -> () } = {}
local lootEvent: RemoteEvent
local shelfState: RemoteEvent
local limiter = RateLimit.new(Config.Tear.maxRequestsPerSecond)
local giftsFolder: Folder

---------------------------------------------------------------- helpers

local function capacity(_data: any): number
	return Config.Shelf.startSlots -- gem and gamepass slots come with Phase 3
end

local function sendShelf(player: Player)
	local data = Data.get(player)
	if not data then
		return
	end
	local found = 0
	for _ in data.index do
		found += 1
	end
	shelfState:FireClient(player, {
		capacity = capacity(data),
		items = data.shelf,
		gems = data.gems,
		indexCount = found,
	})
end

local function rarityColor(rarity: string): Color3
	local hex = Config.Rarity[rarity].color
	return if hex then Color3.fromHex(hex) else Color3.new(1, 1, 1)
end

-- A greybox gift: a glowing Neon block in its rarity color (Secret sweeps the hue).
local function giftPart(studs: number, rarity: string): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = rarityColor(rarity)
	part.Size = Vector3.one * studs
	local light = Instance.new("PointLight")
	light.Range = Config.Greybox.giftLightRange
	light.Color = part.Color
	light.Parent = part
	if rarity == "Secret" then
		local connection
		connection = RunService.Heartbeat:Connect(function()
			if not part.Parent then
				connection:Disconnect()
				return
			end
			local color = Color3.fromHSV((os.clock() / Config.Greybox.secretHueSeconds) % 1, 0.6, 1)
			part.Color = color
			light.Color = color
		end)
	end
	return part
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function nearestPlayer(position: Vector3): Player?
	local best, bestDistance = nil, math.huge
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = player, distance
			end
		end
	end
	return best
end

-- Arcs `part` into `player` over `seconds`, following them as they move.
local function flyTo(part: BasePart, player: Player, seconds: number)
	local start = part.Position
	local began = os.clock()
	while part.Parent do
		local root = rootOf(player)
		if not root then
			return
		end
		local a = math.min((os.clock() - began) / seconds, 1)
		part.Position = start:Lerp(root.Position, a) + Vector3.yAxis * math.sin(a * math.pi) * Config.Greybox.giftPopStuds
		if a >= 1 then
			return
		end
		RunService.Heartbeat:Wait()
	end
end

local function recordSeen(item: BagItem, rarityForIndex: string?, key: string)
	for _, player in Players:GetPlayers() do
		local data = Data.get(player)
		if data then
			Index.record(data.index, key, item.depth, os.time(), rarityForIndex, Config.RarityOrder)
		end
	end
end

---------------------------------------------------------------- side-gifts

local function pickSide(rng: any)
	local family = Gifts.families[Rng.int(rng, 1, #Gifts.families)]
	local list = Gifts.side[family]
	return list[Rng.int(rng, 1, #list)]
end

local function spawnSide(thisRun: any, item: BagItem, slot: number, of: number)
	local info = Tear.getRunInfo()
	if not info then
		return
	end
	local size = info.sizes[item.depth]
	local angle = slot / of * 2 * math.pi
	local start = info.base + Vector3.new(math.cos(angle) * size / 4, size + Config.Greybox.sideGiftStuds, math.sin(angle) * size / 4)
	local part = giftPart(Config.Greybox.sideGiftStuds, item.rarity)
	part.Name = item.giftId
	part.Position = start
	part.Parent = giftsFolder
	TweenService:Create(part, TweenInfo.new(Config.Loot.flyToBagDelay, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = start + Vector3.yAxis * Config.Greybox.giftPopStuds,
	}):Play()
	task.wait(Config.Loot.flyToBagDelay)
	local player = nearestPlayer(part.Position)
	if player then
		flyTo(part, player, Config.Loot.flySeconds)
	end
	part:Destroy()
	if run ~= thisRun then
		return -- the run ended while it flew
	end
	table.insert(run.bag, item)
	recordSeen(item, item.rarity, item.giftId)
	local cash = Config.Cash.perSideGift[item.rarity]
	if player and player.Parent then
		Economy.addCash(player, cash)
	end
	lootEvent:FireAllClients({
		type = "Side",
		giftId = item.giftId,
		rarity = item.rarity,
		to = if player then player.DisplayName else nil,
		toUserId = if player then player.UserId else nil,
		cash = cash,
	})
end

local function layerCleared(depth: number)
	if not run then
		return
	end
	if depth == run.layerCount - 2 then
		RunState.set("CoreLid") -- the last layer is the core box's lid
	end
	if depth >= run.layerCount - 1 then
		return -- the core lid: the reveal instead
	end
	local band = Nest.band(depth, run.layerCount)
	local lo, hi = Config.Loot.sideGiftsPerLayer[1], Config.Loot.sideGiftsPerLayer[2]
	local count = Rng.int(run.rng, lo, hi)
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Upgrade_LuckyBow") == true then
			count += Config.Shop.LuckyBow.extraSideGifts
			player:SetAttribute("Upgrade_LuckyBow", "Used")
		end
	end
	for slot = 1, count do
		-- The Lucky gamepass (double roll) is wired with gamepasses in Phase 3; until then, false.
		local rarity = Rarity.rollSide(run.rng, RARITY, run.tier, band, false, Rng)
		local gift = pickSide(run.rng)
		task.spawn(spawnSide, run, { giftId = gift.id, rarity = rarity, kind = "Side", depth = depth }, slot, count)
	end
end

---------------------------------------------------------------- bank

local function finishBank()
	if RunState.get() ~= "Bank" or next(banking) ~= nil then
		return
	end
	for _, listener in bankDoneListeners do
		task.spawn(listener)
	end
end

local function pendingView(pending: { BagItem }): { any }
	local out = {}
	for i, item in pending do
		out[i] = {
			giftId = item.giftId,
			rarity = item.rarity,
			mutation = item.mutation,
			sellGems = Bank.sellGems(Config.Loot.sellGems, item.rarity),
		}
	end
	return out
end

local function sendPending(player: Player)
	local entry = banking[player]
	lootEvent:FireClient(player, { type = "BankPending", pending = pendingView(entry and entry.pending or {}) })
end

-- Sells a gift that is leaving the shelf or the bank screen; Secrets cannot be sold, so they go to
-- the vault instead and are never lost (invariant 10).
local function sellOrVault(data: any, item: any)
	local gems = Bank.sellGems(Config.Loot.sellGems, item.rarity, item.count or 1)
	if gems then
		data.gems += gems
	else
		table.insert(data.vault, {
			giftId = item.giftId,
			rarity = item.rarity,
			mutation = item.mutation,
			slotIndex = #data.vault + 1,
			count = item.count or 1,
		})
	end
end

-- Whatever is still pending is sold (or vaulted) and the player is done banking.
local function settle(player: Player)
	local entry = banking[player]
	local data = Data.get(player)
	if entry and data then
		for _, item in entry.pending do
			sellOrVault(data, item)
		end
	end
	banking[player] = nil
end

local function bankRun()
	RunState.set("Bank")
	local seconds = math.floor(os.clock() - run.startedAt + 0.5)
	for _, player in Players:GetPlayers() do
		local data = Data.get(player)
		if data then
			local items = table.clone(run.bag)
			local core = table.clone(run.core)
			core.mutation = run.coreMutation[player]
			table.insert(items, core)
			local outcomes, pending = {}, {}
			for _, item in items do
				local outcome = Shelf.place(data.shelf, item, capacity(data), SHELF)
				if outcome == "full" then
					table.insert(pending, item)
				end
				if item.rarity == "Mythic" then
					data.stats.mythicsFound += 1
				end
				table.insert(outcomes, { giftId = item.giftId, rarity = item.rarity, mutation = item.mutation, kind = item.kind, outcome = outcome })
			end
			-- No downs until the Night exists (Phase 4), so every completed run is a no-downs run.
			local gems = Bank.runGems(GEMS, 0, false, data.tier > run.tierNumber)
			data.gems += gems
			data.stats.completions += 1
			if run.tier == "Birthday" and (data.stats.fastestBirthdayRunSeconds == 0 or seconds < data.stats.fastestBirthdayRunSeconds) then
				data.stats.fastestBirthdayRunSeconds = seconds
			end
			banking[player] = { pending = pending }
			lootEvent:FireClient(player, { type = "Bank", items = outcomes, gems = gems, pending = pendingView(pending) })
			sendShelf(player)
		end
	end
	finishBank()
end

local function bankChoice(player: Player, kind: any, i: any, slotIndex: any)
	if RunState.get() ~= "Bank" or not RateLimit.allow(limiter, player, os.clock()) then
		return
	end
	local entry = banking[player]
	local data = Data.get(player)
	if not entry or not data then
		return
	end
	if kind == "Done" then
		settle(player)
		sendShelf(player)
		finishBank()
		return
	end
	local item = typeof(i) == "number" and entry.pending[i]
	if not item then
		return
	end
	if kind == "Sell" then
		local gems = Bank.sellGems(Config.Loot.sellGems, item.rarity)
		if not gems then
			lootEvent:FireClient(player, { type = "Refused", reason = "Secret gifts cannot be sold" })
			return
		end
		data.gems += gems
		table.remove(entry.pending, i)
	elseif kind == "Replace" and typeof(slotIndex) == "number" then
		local removed = Shelf.removeAt(data.shelf, slotIndex)
		if not removed then
			return
		end
		if Shelf.place(data.shelf, item, capacity(data), SHELF) == "full" then
			table.insert(data.shelf, removed)
			table.sort(data.shelf, function(a, b)
				return a.slotIndex < b.slotIndex
			end)
			lootEvent:FireClient(player, { type = "Refused", reason = "Not enough room there" })
			return
		end
		sellOrVault(data, removed)
		table.remove(entry.pending, i)
	else
		return
	end
	sendPending(player)
	sendShelf(player)
end

---------------------------------------------------------------- core

local function reveal()
	local thisRun = run
	RunState.set("Reveal")
	local firstRun = false
	for _, player in Players:GetPlayers() do
		local data = Data.get(player)
		if data and data.stats.completions == 0 then
			firstRun = true -- seeded so a new player's first core is Uncommon or better
		end
	end
	local rarity = Rarity.rollCore(run.rng, RARITY, run.tier, firstRun, Rng)
	local pool = Gifts.corePool(rarity, run.tier)
	local gift = pool[Rng.int(run.rng, 1, #pool)]
	local depth = run.layerCount - 1
	run.core = { giftId = gift.id, rarity = rarity, kind = "Core", depth = depth }
	run.coreMutation = {}
	for _, player in Players:GetPlayers() do
		local data = Data.get(player)
		local mutation = nil
		if data then
			mutation = Rarity.rollMutation(run.rng, RARITY, rarity, Index.has(data.index, gift.id), Rng)
			Index.record(data.index, Index.key(gift.id, mutation), depth, os.time())
		end
		run.coreMutation[player] = mutation
		lootEvent:FireClient(player, { type = "Core", giftId = gift.id, rarity = rarity, mutation = mutation })
	end

	local info = Tear.getRunInfo()
	if info then
		local coreSize = info.sizes[depth]
		local studs = Config.Greybox.coreGiftStuds
		local part = giftPart(studs, rarity)
		part.Name = "CoreGift"
		part.Position = info.base + Vector3.yAxis * studs / 2
		part.Parent = giftsFolder
		TweenService:Create(part, TweenInfo.new(Config.Loot.coreRevealSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = info.base + Vector3.yAxis * (coreSize + studs),
		}):Play()
	end
	task.wait(Config.Loot.coreRevealSeconds + Config.Loot.revealBeatSeconds)
	if run == thisRun then
		bankRun()
	end
end

---------------------------------------------------------------- public

-- A new run: an empty shared RunBag and a fresh server seed for its rolls (Present -> Loot).
function Loot.startRun(nest: any, tierNumber: number)
	run = {
		tier = nest.tier,
		tierNumber = tierNumber,
		layerCount = #nest.layers,
		rng = Rng.new(Random.new():NextInteger(1, 2 ^ 31 - 1)),
		bag = {},
		startedAt = os.clock(),
	}
	banking = {}
	giftsFolder:ClearAllChildren()
	for _, player in Players:GetPlayers() do
		local data = Data.get(player)
		if data then
			data.stats.runs += 1
		end
	end
end

-- The shared RunBag of the current run (read-only for other systems).
function Loot.getBag(): { BagItem }
	return run and run.bag or {}
end

-- Called once every banking player is done (or has left). Until Lobby exists, Present starts the next run.
function Loot.onBankDone(listener: () -> ())
	table.insert(bankDoneListeners, listener)
end

function Loot.init()
	lootEvent = Remotes.get("LootEvent")
	shelfState = Remotes.get("ShelfState")
	giftsFolder = Instance.new("Folder")
	giftsFolder.Name = "Gifts"
	giftsFolder.Parent = workspace

	Tear.onLayerCleared(layerCleared)
	Tear.onRunComplete(reveal)
	Remotes.get("BankChoice").OnServerEvent:Connect(bankChoice)
	Data.onLoaded(function(player)
		sendShelf(player)
	end)
	Data.beforeRelease(function(player)
		if banking[player] then
			settle(player)
			task.defer(finishBank)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		RateLimit.forget(limiter, player)
		if banking[player] then -- no profile to settle into
			banking[player] = nil
			task.defer(finishBank)
		end
	end)
end

return Loot
