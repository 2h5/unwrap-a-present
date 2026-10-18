--[=[
	Economy (server system)
	Owns: Cash, gems, shop, classes, prestige, gamepass checks, daily and group rewards.
	Must never: Grant a gift for Robux (invariant 6). Products pay gems; passes change speed, storage
	or luck under 2x; nothing here can name a gift.
	Pure, tested rules: Meta.luau. This file: run cash (player attribute "Cash", class and pass scales),
	the run room shop, starting kits, the profile's gem economy over Up EconomyRequest / ClassSpin,
	Down ProfileState, gamepass checks and dev product receipts.
	Read first: src/server/Economy/README.md
]=]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local Rng = require(ReplicatedStorage.Shared.Rng.Rng)
local Props = require(ReplicatedStorage.Shared.Art.Props)
local Data = require(script.Parent.Parent.Data.Data)
local Shelf = require(script.Parent.Parent.Loot.Shelf)
local RateLimit = require(script.Parent.Parent.Tear.RateLimit)
local RunState = require(script.Parent.Parent.Present.RunState)
local Meta = require(script.Parent.Meta)

local Economy = {}

-- Shop items that are tools set Tool_<name>; the rest set Upgrade_<name>. One of each per run.
local TOOLS = { Scissors = true, BoxCutter = true, Chainsaw = true }
local BUSY_STATES = { Building = true, Reveal = true, Bank = true } -- the profile is being banked

local SLOT_SIZES = {}
for rarity, entry in Config.Rarity do
	SLOT_SIZES[rarity] = entry.shelfSlots
end
local SHELF = { slotSizes = SLOT_SIZES, stackMax = Config.Shelf.stackMax }

local runTier = 1
local limiter = RateLimit.new(Config.Tear.maxRequestsPerSecond)
local rng = Rng.new(Random.new():NextInteger(1, 2 ^ 31 - 1))
local fractions: { [Player]: number } = {} -- cash below 1 left over from a scaled payout
local passes: { [Player]: { [string]: boolean } } = {}
local profileListeners: { (player: Player) -> () } = {}
local profileState: RemoteEvent

local function attributeFor(item: string): string
	return if TOOLS[item] then `Tool_{item}` else `Upgrade_{item}`
end

---------------------------------------------------------------- passes

-- Whether the player owns a gamepass. Studio only: the Workspace attribute DevPasses
-- ("DoubleCash,Lucky") pretends, since ids are 0 until the passes exist.
function Economy.hasPass(player: Player, name: string): boolean
	if passes[player] and passes[player][name] then
		return true
	end
	local dev = if RunService:IsStudio() then workspace:GetAttribute("DevPasses") else nil
	return typeof(dev) == "string" and table.find(string.split(dev, ","), name) ~= nil
end

-- Passes other players can see: Lucky shows an icon by the owner's name on the party panel.
local function showPasses(player: Player)
	player:SetAttribute("Lucky", if Economy.hasPass(player, "Lucky") then true else nil)
end

local function checkPasses(player: Player)
	passes[player] = passes[player] or {}
	local data = Data.get(player)
	for _, name in Config.GamepassOrder do
		local id = Config.Gamepasses[name].id
		if id ~= 0 then
			local ok, owned = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
			if ok then
				passes[player][name] = owned
				if data then
					data.passes[tostring(id)] = owned -- re-checked on every join (schema)
				end
			end
		end
	end
	showPasses(player)
end

---------------------------------------------------------------- cash

function Economy.cashPerPanel(tier: string): number
	local cash = Config.Cash.perPanel[tier]
	assert(cash, `Economy: cash per panel at {tier} is not set (PLAN-TABLES Table 7)`)
	return cash
end

-- Run cash earned (panels, side-gifts). Kid's +5% and the 2x Cash pass scale it; fractions carry over.
function Economy.addCash(player: Player, amount: number)
	local class = Config.Classes[player:GetAttribute("Class") or ""]
	local scale = 1 + (class and class.cashBonus or 0)
	if Economy.hasPass(player, "DoubleCash") then
		scale *= Config.Gamepasses.DoubleCash.cashScale
	end
	local total = amount * scale + (fractions[player] or 0)
	local whole = math.floor(total + 1e-9)
	fractions[player] = total - whole
	player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + whole)
end

function Economy.getCash(player: Player): number
	return player:GetAttribute("Cash") or 0
end

-- The class this run uses: fixed at run start from the profile's pick (Mechanics D).
function Economy.classOf(player: Player): string?
	return player:GetAttribute("Class")
end

local function applyWalkSpeed(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local class = Config.Classes[Economy.classOf(player) or ""]
		humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed + (class and class.walkSpeedBonus or 0)
	end
end

-- Starting kit once per run: Pockets cash plus the class's cash, tools and upgrades, and Tool Keeper's tools.
local function giveKit(player: Player)
	local data = Data.get(player)
	if not data or player:GetAttribute("KitGiven") then
		return
	end
	player:SetAttribute("KitGiven", true)
	player:SetAttribute("Class", if data.activeClass ~= "" then data.activeClass else nil)
	local cash = data.upgrades.pockets * Config.PermanentTrack.Pockets.startCashPerLevel
	local class = Config.Classes[data.activeClass]
	if class then
		cash += class.startCash or 0
		for _, tool in class.startTools or {} do
			player:SetAttribute(`Tool_{tool}`, true)
		end
		for _, upgrade in class.startUpgrades or {} do
			player:SetAttribute(`Upgrade_{upgrade}`, true)
		end
	end
	if Economy.hasPass(player, "ToolKeeper") then
		for _, tool in Config.Gamepasses.ToolKeeper.startTools do
			player:SetAttribute(`Tool_{tool}`, true)
		end
	end
	player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + cash)
	applyWalkSpeed(player)
end

local function resetPlayer(player: Player)
	player:SetAttribute("Cash", 0)
	player:SetAttribute("KitGiven", nil)
	fractions[player] = nil
	for item in Config.Shop do
		player:SetAttribute(attributeFor(item), nil)
	end
	giveKit(player)
end

-- Cash resets to 0 at run start, and run items go with it (Table 7); then each kit is handed out.
function Economy.resetRun(tierNumber: number)
	runTier = tierNumber
	for _, player in Players:GetPlayers() do
		resetPlayer(player)
	end
end

---------------------------------------------------------------- profile state

function Economy.shelfCapacity(player: Player, data: any): number
	return Meta.shelfCapacity(data, Config.Shelf, Economy.hasPass(player, "BigShelf"))
end

local function sendState(player: Player, message: string?)
	local data = Data.get(player)
	if not data then
		return
	end
	local owned = {}
	for _, name in Config.GamepassOrder do
		owned[name] = Economy.hasPass(player, name)
	end
	local tiers, need, maxTier = Config.Tiers.order, Config.Tiers.completedRunsToPrestige, #Config.LaunchTiers
	profileState:FireClient(player, {
		message = message,
		gems = data.gems,
		tier = data.tier,
		prestigeCount = data.prestigeCount,
		tierRuns = data.tierCompletions[tostring(data.tier)] or 0,
		prestigeNeed = Meta.prestigeNeed(data, tiers, need, maxTier),
		canPrestige = Meta.canPrestige(data, tiers, need, maxTier),
		nextTier = player:GetAttribute("NextTier") or data.tier,
		classes = data.classes,
		activeClass = data.activeClass,
		runClass = Economy.classOf(player),
		spinCost = Config.Gems.classSpin,
		pockets = data.upgrades.pockets,
		nightEyes = data.upgrades.nightEyes,
		pocketsCost = Meta.trackCost(Config.PermanentTrack.Pockets, data.upgrades.pockets),
		nightEyesCost = Meta.trackCost(Config.PermanentTrack.NightEyes, data.upgrades.nightEyes),
		streakDays = data.streak.days,
		dailyWait = Meta.dailyWait(data, os.time(), Config.Gems.dailyIntervalSeconds),
		groupClaimed = data.groupClaimed,
		groupReady = Config.Group.id ~= 0,
		shelfSlots = Economy.shelfCapacity(player, data),
		shelfSlotsCost = if data.shelfSlots + 4 <= Config.Shelf.gemSlotsMax then Config.Shelf.gemsPer4Slots else nil,
		vault = data.vault,
		vaultReclaimsLeft = data.vaultReclaimsLeft,
		passes = owned,
		rejoinSecondsLeft = if data.rejoin.accessCode ~= "" and data.rejoin.expiresAt > os.time() then data.rejoin.expiresAt - os.time() else nil,
	})
end

local function changed(player: Player, message: string?)
	sendState(player, message)
	for _, listener in profileListeners do
		task.spawn(listener, player)
	end
end

-- Called when Economy has changed a player's shelf or vault (prestige, reclaim, slots); Loot resends ShelfState.
function Economy.onProfileChanged(listener: (player: Player) -> ())
	table.insert(profileListeners, listener)
end

function Economy.refresh(player: Player, message: string?)
	sendState(player, message)
end

-- Gems for a completed run, banked by Loot: Collector's +10%, bring-a-friend, and the run counted
-- toward prestige at the player's own tier. Returns the gems paid.
function Economy.bankRun(player: Player, data: any, baseGems: number, partySize: number, tierNumber: number): number
	local class = Config.Classes[Economy.classOf(player) or ""]
	local gems = math.floor(baseGems * (1 + (class and class.gemBonus or 0)) + 0.5)
	gems += Meta.friendBonus(partySize, Config.Gems.friendBonusPerPlayer)
	data.gems += gems
	Meta.runCompleted(data, tierNumber, Config.Tiers.vaultReclaimsPerRun)
	sendState(player)
	return gems
end

-- The tier of the next run: the host's pick (N13; first player until Lobby pads exist), or their own tier.
function Economy.nextRunTier(): string
	local host = Players:GetPlayers()[1]
	local data = host and Data.get(host)
	if not data then
		return Config.Tiers.order[1]
	end
	local pick = host:GetAttribute("NextTier")
	local tier = if typeof(pick) == "number" and Meta.canRunTier(data, pick) then pick else data.tier
	return Config.Tiers.order[tier]
end

---------------------------------------------------------------- requests

local function buy(player: Player, item: any)
	if typeof(item) ~= "string" then
		return
	end
	local entry = Config.Shop[item]
	if not entry or (entry.minTier and runTier < entry.minTier) then
		return
	end
	local attribute = attributeFor(item)
	if player:GetAttribute(attribute) then
		return
	end
	local cash = Economy.getCash(player)
	if cash < entry.cost then
		return
	end
	player:SetAttribute("Cash", cash - entry.cost)
	player:SetAttribute(attribute, true)
end

local function reclaim(player: Player, data: any, i: any)
	local item = typeof(i) == "number" and data.vault[i]
	if not item or data.vaultReclaimsLeft <= 0 then
		return "No reclaims left this run"
	end
	local capacity = Economy.shelfCapacity(player, data)
	local outcome, target = Shelf.preview(data.shelf, item, capacity, SHELF)
	if outcome == "full" then
		return "No room on your shelf"
	elseif outcome == "stacked" and target.count + item.count > Config.Shelf.stackMax then
		return "That stack is full"
	end
	table.remove(data.vault, i)
	for slot, vaulted in data.vault do
		vaulted.slotIndex = slot
	end
	if outcome == "stacked" then
		target.count += item.count
	else
		item.slotIndex = target
		table.insert(data.shelf, item)
		table.sort(data.shelf, function(a, b)
			return a.slotIndex < b.slotIndex
		end)
	end
	data.vaultReclaimsLeft -= 1
	return nil
end

local function request(player: Player, kind: any, arg: any)
	if BUSY_STATES[RunState.get()] or not RateLimit.allow(limiter, player, os.clock()) then
		return
	end
	local data = Data.get(player)
	if not data then
		return
	end
	local now = os.time()
	local message: string?
	if kind == "DailyClaim" then
		local gems = Meta.claimDaily(data, now, Config.Gems.dailyIntervalSeconds, Config.Gems.daily)
		message = if gems then `Daily reward: +{gems} gems` else "Not ready yet"
	elseif kind == "GroupClaim" then
		local inGroup = false
		if Config.Group.id ~= 0 then
			local ok, result = pcall(player.IsInGroup, player, Config.Group.id)
			inGroup = ok and result
		end
		local gems = Meta.claimGroup(data, inGroup, Config.Gems.groupOneTime)
		message = if gems then `Group reward: +{gems} gems` elseif data.groupClaimed then "Already claimed" else "Join the group first"
	elseif kind == "ClassPick" and typeof(arg) == "string" then
		if Meta.pickClass(data, arg) then
			message = `{Config.Classes[arg].name} for your next run`
		end
	elseif kind == "TrackBuy" and (arg == "pockets" or arg == "nightEyes") then
		local line = if arg == "pockets" then Config.PermanentTrack.Pockets else Config.PermanentTrack.NightEyes
		local level = Meta.buyTrack(data, arg, line)
		message = if level then `{if arg == "pockets" then "Pockets" else "Night Eyes"} level {level}` else "Not enough gems"
	elseif kind == "ShelfSlots" then
		local slots = Meta.buyShelfSlots(data, Config.Shelf)
		message = if slots then `Shelf: {slots} slots` else "Not enough gems"
	elseif kind == "Prestige" then
		if Meta.canPrestige(data, Config.Tiers.order, Config.Tiers.completedRunsToPrestige, #Config.LaunchTiers) then
			local moved = Meta.prestige(data, Config.Tiers.shelfSlotsAfterPrestige, SLOT_SIZES)
			player:SetAttribute("NextTier", data.tier)
			message = `Prestige! {Config.Tiers.order[data.tier]} unlocked{if #moved > 0 then `; {#moved} items to the vault` else ""}`
		end
	elseif kind == "TierPick" and typeof(arg) == "number" then
		if Meta.canRunTier(data, arg) then
			player:SetAttribute("NextTier", arg)
			message = `Next run: {Config.Tiers.order[arg]}`
		end
	elseif kind == "VaultReclaim" then
		message = reclaim(player, data, arg) or "Back on your shelf"
	else
		return
	end
	changed(player, message)
end

local function spin(player: Player)
	if BUSY_STATES[RunState.get()] or not RateLimit.allow(limiter, player, os.clock()) then
		return
	end
	local data = Data.get(player)
	if not data then
		return
	end
	local rolled = Meta.rollClass(rng, Config.Classes, Config.ClassOrder, Rng)
	local id, isNew, refund = Meta.spin(data, rolled, Config.Gems.classSpin, Config.Gems.classDuplicateRefund)
	local message = if not id
		then "Not enough gems"
		elseif isNew then `New class: {Config.Classes[id].name}!`
		else `{Config.Classes[id].name} again: +{refund} gems back`
	sendState(player, message)
end

---------------------------------------------------------------- receipts

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and Data.get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(data.purchases, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	for _, name in Config.DevProductOrder do
		local product = Config.DevProducts[name]
		if product.id ~= 0 and product.id == receipt.ProductId then
			data.gems += product.gems
			table.insert(data.purchases, receipt.PurchaseId)
			while #data.purchases > Config.PurchaseHistoryMax do
				table.remove(data.purchases, 1)
			end
			Data.save(player)
			sendState(player, `+{product.gems} gems`)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

---------------------------------------------------------------- setup

-- Builds the shop counter in the run room's corner, `roomCenter` being the floor point at its middle.
function Economy.setupShop(roomCenter: Vector3)
	local corner = Config.RunRoom.sizeStuds / 2 - Config.RunRoom.shopInsetStuds
	local counter = Instance.new("Part")
	counter.Name = "ShopCounter"
	counter.Anchored = true
	counter.Size = Vector3.new(Config.Panels.panelStuds * 2, Config.Panels.panelStuds, Config.Panels.panelStuds)
	counter.Position = roomCenter + Vector3.new(-corner, Config.Panels.panelStuds / 2, corner)
	counter.Material = Enum.Material.WoodPlanks
	counter.Color = Color3.fromHex(Config.RunRoom.colors.wainscot)
	-- Dressing (Phase 5): a top, a kick plate and a gift-tag sign hung from the ceiling, facing the room.
	local top = counter.Position + Vector3.yAxis * (counter.Size.Y / 2 + 0.25)
	Props.trim(counter, "CounterTop", Vector3.new(counter.Size.X + 0.8, 0.5, counter.Size.Z + 0.8), CFrame.new(top), Config.RunRoom.colors.trim, "Wood")
	Props.trim(counter, "KickPlate", Vector3.new(counter.Size.X + 0.2, 0.6, counter.Size.Z + 0.2), CFrame.new(counter.Position - Vector3.yAxis * (counter.Size.Y / 2 - 0.3)), Config.RunRoom.colors.trim, "Wood")
	local signAt = counter.Position + Vector3.yAxis * 9
	local facing = CFrame.lookAt(signAt, Vector3.new(roomCenter.X, signAt.Y, roomCenter.Z))
	Props.tag(counter, facing, 6, 2.4, "Shop", "Tools for this run")
	for _, side in { -1, 1 } do
		local hook = facing * CFrame.new(side * 2.4, 1.2, 0)
		Props.twine(counter, hook.Position, hook.Position + Vector3.yAxis * (Config.RunRoom.wallStuds - hook.Position.Y + roomCenter.Y))
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Shop"
	prompt.ObjectText = "Run room shop"
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom -- drawn by the HUD in the bottom third (Table 13)
	prompt.Parent = counter
	counter.Parent = workspace
end

function Economy.init()
	profileState = Remotes.get("ProfileState")
	Players.PlayerAdded:Connect(function(player)
		resetPlayer(player)
		player.CharacterAdded:Connect(function()
			applyWalkSpeed(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		resetPlayer(player)
	end
	Data.onLoaded(function(player, data)
		checkPasses(player)
		local streak = Meta.login(data, os.time(), Config.Gems.streakPerDay, Config.Gems.streakCapDays)
		giveKit(player)
		changed(player, if streak > 0 then `Day {data.streak.days} streak: +{streak} gems` else nil)
	end)
	Remotes.get("ShopBuy").OnServerEvent:Connect(function(player, item)
		if RunState.canTear() and RateLimit.allow(limiter, player, os.clock()) then
			buy(player, item)
		end
	end)
	Remotes.get("EconomyRequest").OnServerEvent:Connect(request)
	Remotes.get("ClassSpin").OnServerEvent:Connect(spin)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, id, purchased)
		if purchased then
			for _, name in Config.GamepassOrder do
				if Config.Gamepasses[name].id == id then
					passes[player] = passes[player] or {}
					passes[player][name] = true
				end
			end
			showPasses(player)
			changed(player, "Thanks!")
		end
	end)
	MarketplaceService.ProcessReceipt = processReceipt
	if RunService:IsStudio() then
		-- Studio only: Workspace attribute DevGems adds that many gems to every loaded profile.
		workspace:GetAttributeChangedSignal("DevGems"):Connect(function()
			local gems = workspace:GetAttribute("DevGems")
			if typeof(gems) == "number" then
				workspace:SetAttribute("DevGems", nil)
				for _, player in Players:GetPlayers() do
					local data = Data.get(player)
					if data then
						data.gems += gems
						changed(player, `Studio: +{gems} gems`)
					end
				end
			end
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		RateLimit.forget(limiter, player)
		fractions[player] = nil
		passes[player] = nil
	end)
end

return Economy
