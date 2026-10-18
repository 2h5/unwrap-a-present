--[=[
	Economy (server system)
	Owns: Cash, gems, shop, classes, prestige, gamepass checks, daily and group rewards.
	Must never: Grant a gift for Robux.
	Phase 1: run cash (player attribute "Cash", reset each run) and the run room shop (a counter
	with a ProximityPrompt; ShopBuy validated here). Bought items become player attributes that other
	systems read: Tool_<name> (Tear), Upgrade_<name>. Gems, classes, prestige: Phase 3.
	Read first: src/server/Economy/README.md
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local RateLimit = require(script.Parent.Parent.Tear.RateLimit)

local Economy = {}

-- Shop items that are tools set Tool_<name>; the rest set Upgrade_<name>. One of each per run.
local TOOLS = { Scissors = true, BoxCutter = true, Chainsaw = true }

local runTier = 1
local limiter = RateLimit.new(Config.Tear.maxRequestsPerSecond)

local function attributeFor(item: string): string
	return if TOOLS[item] then `Tool_{item}` else `Upgrade_{item}`
end

function Economy.cashPerPanel(tier: string): number
	local cash = Config.Cash.perPanel[tier]
	assert(cash, `Economy: cash per panel at {tier} is not set yet (PLAN-TABLES Table 7)`)
	return cash
end

function Economy.addCash(player: Player, amount: number)
	player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + amount)
end

function Economy.getCash(player: Player): number
	return player:GetAttribute("Cash") or 0
end

local function resetPlayer(player: Player)
	player:SetAttribute("Cash", 0)
	for item in Config.Shop do
		player:SetAttribute(attributeFor(item), nil)
	end
end

-- Cash resets to 0 at run start, and run items go with it (Table 7).
function Economy.resetRun(tierNumber: number)
	runTier = tierNumber
	for _, player in Players:GetPlayers() do
		resetPlayer(player)
	end
end

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

-- Builds the shop counter in the run room's corner, `roomCenter` being the floor point at its middle.
function Economy.setupShop(roomCenter: Vector3)
	local corner = Config.RunRoom.sizeStuds / 2 - Config.RunRoom.shopInsetStuds
	local counter = Instance.new("Part")
	counter.Name = "ShopCounter"
	counter.Anchored = true
	counter.Size = Vector3.new(Config.Panels.panelStuds * 2, Config.Panels.panelStuds, Config.Panels.panelStuds)
	counter.Position = roomCenter + Vector3.new(-corner, Config.Panels.panelStuds / 2, corner)
	counter.Material = Enum.Material.WoodPlanks
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Shop"
	prompt.ObjectText = "Run room shop"
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	counter.Parent = workspace
end

function Economy.init()
	Players.PlayerAdded:Connect(resetPlayer)
	for _, player in Players:GetPlayers() do
		resetPlayer(player)
	end
	Remotes.get("ShopBuy").OnServerEvent:Connect(function(player, item)
		if RateLimit.allow(limiter, player, os.clock()) then
			buy(player, item)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		RateLimit.forget(limiter, player)
	end)
end

return Economy
