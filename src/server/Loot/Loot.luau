--[=[
	Loot (server system)
	Owns: Rarity rolls, side-gift spawn, RunBag, core gift, Bank, Index, Shelf state.
	Must never: Roll on the client or re-roll on request. Every roll is made once, here, from a
	server-seeded Rng; the client is told what happened.
	Pure, tested logic: Rarity, Shelf, Index, Bank. This file is the Roblox glue: side-gifts pop from a
	cleared layer and fly to the nearest player (cash on pickup, N32), the shared RunBag, the core
	reveal, the bank (every finisher banks a copy, N14), the bank screen's sell / replace choices, and
	the Night's hooks (the Tick's side-gifts, downs, the solo cost, the wipe).
	Read first: src/server/Loot/README.md
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Gifts = require(ReplicatedStorage.Shared.Gifts.Gifts)
local GiftModels = require(ReplicatedStorage.Shared.Art.GiftModels)
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

local function capacity(player: Player, data: any): number
	return Economy.shelfCapacity(player, data)
end

-- Whether anyone in the run has `class` (class perks apply to the whole team, N14).
local function teamHas(class: string): boolean
	for _, player in Players:GetPlayers() do
		if Economy.classOf(player) == class then
			return true
		end
	end
	return false
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
		capacity = capacity(player, data),
		items = data.shelf,
		gems = data.gems,
		indexCount = found,
	})
end

local function rarityColor(rarity: string): Color3
	local hex = Config.Rarity[rarity].color
	return if hex then Color3.fromHex(hex) else Color3.new(1, 1, 1)
end

-- A gift as its chunky toy (Shared/Art/GiftModels) with its rarity glow and a trail for the arc to the
-- bag. The anchored Root carries the welded toy: moving the Root moves the gift. A Secret's hue sweep is
-- drawn on each client (HUD LootView), never replicated every frame.
local function giftModel(giftId: string, rarity: string, studs: number, kind: string, mutation: string?): (Model, BasePart)
	local model = GiftModels.build(giftId, rarity, { studs = studs, mutation = mutation })
	model:SetAttribute("Kind", kind)
	local root = model.PrimaryPart :: BasePart
	local light = Instance.new("PointLight")
	light.Range = Config.LootLook.glowRange
	light.Color = rarityColor(rarity)
	light.Parent = root
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, studs * 0.8, 0), Vector3.new(0, studs * 0.2, 0)
	a0.Parent, a1.Parent = root, root
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(rarityColor(rarity))
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.Lifetime = Config.Vfx.giftTrailSeconds / 2
	trail.LightEmission = 0.6
	trail.Enabled = false
	trail.Parent = root
	return model, root
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

-- Arcs `part` (a gift's Root) into `player` over `seconds`, following them as they move.
local function flyTo(part: BasePart, player: Player, seconds: number)
	local start = part.Position
	local began = os.clock()
	local trail = part:FindFirstChildOfClass("Trail")
	if trail then
		trail.Enabled = true
	end
	while part.Parent and part:IsDescendantOf(workspace) do
		local root = rootOf(player)
		if not root then
			return
		end
		local a = math.min((os.clock() - began) / seconds, 1)
		local spin = CFrame.Angles(0, a * math.pi * 2, 0)
		part.CFrame = CFrame.new(start:Lerp(root.Position, a) + Vector3.yAxis * math.sin(a * math.pi) * Config.Greybox.giftPopStuds) * spin
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
	local start = info.base + Vector3.new(math.cos(angle) * size / 4, size + Config.LootLook.sideGiftStuds / 2, math.sin(angle) * size / 4)
	local model, part = giftModel(item.giftId, item.rarity, Config.LootLook.sideGiftStuds, "Side")
	part.CFrame = CFrame.new(start)
	model.Parent = giftsFolder
	TweenService:Create(part, TweenInfo.new(Config.Loot.flyToBagDelay, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(start + Vector3.yAxis * Config.Greybox.giftPopStuds) * CFrame.Angles(0, math.pi, 0),
	}):Play()
	task.wait(Config.Loot.flyToBagDelay)
	local player = nearestPlayer(part.Position)
	if player then
		flyTo(part, player, Config.Loot.flySeconds)
	end
	model:Destroy()
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

-- Rolls `count` side-gifts from depth band `band` and pops them from the layer at `depth`.
local function dropSides(depth: number, band: number, count: number)
	local lucky = false
	for _, player in Players:GetPlayers() do
		lucky = lucky or Economy.hasPass(player, "Lucky")
	end
	for slot = 1, count do
		-- Lucky (any player in the run owns it): roll twice, keep the better. Never the core (invariant 6).
		local rarity = Rarity.rollSide(run.rng, RARITY, run.tier, band, lucky, Rng)
		local gift = pickSide(run.rng)
		task.spawn(spawnSide, run, { giftId = gift.id, rarity = rarity, kind = "Side", depth = depth }, slot, count)
	end
end

local function layerCleared(depth: number, layerType: string)
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
	if layerType == "BoxLid" and teamHas("Collector") then
		count += Config.Classes.Collector.lidSideGifts
	end
	dropSides(depth, band, count)
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
				local outcome = Shelf.place(data.shelf, item, capacity(player, data), SHELF)
				if outcome == "full" then
					table.insert(pending, item)
				end
				if item.rarity == "Mythic" then
					data.stats.mythicsFound += 1
				end
				table.insert(outcomes, { giftId = item.giftId, rarity = item.rarity, mutation = item.mutation, kind = item.kind, outcome = outcome })
			end
			-- Downs and the Tick are the whole party's (Night tells Loot).
			local base = Bank.runGems(GEMS, run.downs, run.tickSurvived, data.tier > run.tierNumber)
			local gems = Economy.bankRun(player, data, base, #Players:GetPlayers(), run.tierNumber)
			data.stats.completions += 1
			if run.tickSurvived then
				data.stats.ticksSurvived += 1
			end
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
		if Shelf.place(data.shelf, item, capacity(player, data), SHELF) == "full" then
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
	if teamHas("Heir") then
		-- Heir: the core rolls twice and keeps the better, for the whole team (N14). Gem-spun, not Robux.
		for _ = 2, Config.Classes.Heir.coreRolls do
			local again = Rarity.rollCore(run.rng, RARITY, run.tier, firstRun, Rng)
			if Rarity.rank(RARITY, again) > Rarity.rank(RARITY, rarity) then
				rarity = again
			end
		end
	end
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
		-- The core rises out of its box for the 3 s reveal, turning once; a Mythic keeps turning and
		-- bobbing (its idle animation). The light shaft and drift are drawn on each client (LootView).
		local coreSize = info.sizes[depth]
		local studs = Config.LootLook.coreGiftStuds
		local model, root = giftModel(gift.id, rarity, studs, "Core")
		model.Name = "CoreGift"
		local from, to = info.base, info.base + Vector3.yAxis * coreSize
		root.CFrame = CFrame.new(from)
		model.Parent = giftsFolder
		task.spawn(function()
			local began = os.clock()
			local L = Config.LootLook
			while model.Parent do
				local t = os.clock() - began
				local a = math.min(t / Config.Loot.coreRevealSeconds, 1)
				local eased = 1 - (1 - a) ^ 2
				local turns = if rarity == "Mythic" then t / L.mythicSpinSeconds else eased
				local bob = if rarity == "Mythic" then math.sin(t * 2) * L.mythicBobStuds else 0
				root.CFrame = CFrame.new(from:Lerp(to, eased) + Vector3.yAxis * bob) * CFrame.Angles(0, turns * 2 * math.pi, 0)
				RunService.Heartbeat:Wait()
			end
		end)
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
		downs = 0,
		tickSurvived = false,
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

-- Called when the run is over: every banking player is done (or has left), or a wipe's screen has
-- been shown. Present sends the party to the lobby, or in local play starts the next run.
function Loot.onBankDone(listener: () -> ())
	table.insert(bankDoneListeners, listener)
end

---------------------------------------------------------------- night (Night -> Loot)

-- The Tick was opened: it drops the run's best side-gifts (the most a layer rolls, from the
-- inner-third table) from the layer it sat in.
function Loot.tickOpened(depth: number)
	if run then
		dropSides(depth, Config.Tick.sideGiftBand, Config.Tick.sideGifts)
	end
end

-- A player went down this run (bank gems: no 5 for no downs).
function Loot.noteDown()
	if run then
		run.downs += 1
	end
end

-- The party lived through the Night (bank gems: 8, stats.ticksSurvived).
function Loot.noteTickSurvived()
	if run then
		run.tickSurvived = true
	end
end

-- A solo auto-revive costs one Common side-gift from the bag, if there is one (Table 20).
function Loot.removeCommon()
	if not run then
		return
	end
	for i = #run.bag, 1, -1 do
		local item = run.bag[i]
		if item.kind == "Side" and item.rarity == "Common" then
			table.remove(run.bag, i)
			lootEvent:FireAllClients({ type = "Lost", giftId = item.giftId, rarity = item.rarity })
			return
		end
	end
end

-- Every player went down at once: the run bag is lost, the Index keeps what was seen (it recorded
-- each gift as it landed), the shelf is untouched (invariant 10). The run is over after the screen.
function Loot.wipe()
	if not run then
		return
	end
	run = nil -- gifts still flying land nowhere
	for _, player in Players:GetPlayers() do
		local data = Data.get(player)
		if data then
			data.stats.wipes += 1
		end
	end
	lootEvent:FireAllClients({ type = "Wipe", seconds = Config.Night.wipeScreenSeconds })
	task.delay(Config.Night.wipeScreenSeconds, function()
		for _, listener in bankDoneListeners do
			task.spawn(listener)
		end
	end)
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
	Economy.onProfileChanged(sendShelf)
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
