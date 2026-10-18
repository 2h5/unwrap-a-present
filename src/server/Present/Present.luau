--[=[
	Present (server system)
	Owns: Seed, Nest generation, layer table, Tick placement.
	Must never: Be called by the client. The seed is rolled here, on the server, never sent up.
	Nest rules are pure and tested: Nest.luau. This file rolls the seed, lays the tape, sizes the
	layers, hands the Nest to Tear and Loot, sets RunState, and until Lobby exists starts a new
	Birthday run when the bank is done.
	Read first: src/server/Present/README.md
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Rng = require(ReplicatedStorage.Shared.Rng.Rng)
local Nest = require(script.Parent.Nest)
local PanelGrid = require(script.Parent.Parent.Tear.PanelGrid)
local Tear = require(script.Parent.Parent.Tear.Tear)
local Economy = require(script.Parent.Parent.Economy.Economy)
local Loot = require(script.Parent.Parent.Loot.Loot)
local Lobby = require(script.Parent.Parent.Lobby.Lobby)
local RunState = require(script.Parent.RunState)

local Present = {}

local current: Nest.Nest? = nil

local function perFaceOf(studs: number): number
	return PanelGrid.gridPerFace(studs, Config.Panels)
end

-- The floor point under the present's centre: one present-width behind the origin, so it clears
-- the default SpawnLocation (greybox placement, DECISIONS.md).
local function presentBase(tier: string): Vector3
	return Vector3.new(0, 0, -Config.Tiers[tier].presentStuds)
end

-- Builds a new Nest for `tier` from a fresh server-rolled seed (or the given one, for replays).
function Present.newNest(tier: string, seed: number?): Nest.Nest
	local useSeed = seed or Random.new():NextInteger(1, 2 ^ 31 - 1)
	local nest = Nest.generate(useSeed, tier, {
		tiers = Config.Tiers,
		layerTable = Config.LayerTable,
		layerTypes = Config.LaunchLayerTypes,
	}, Rng)
	current = nest
	return nest
end

function Present.getNest(): Nest.Nest?
	return current
end

-- Starts a run: new Nest, tape, sizes, cash reset, and the present built by Tear.
function Present.startRun(tier: string, seed: number?)
	-- Studio only: Workspace attributes NextSeed and NextTier replay a seed or tier on the next run.
	local replay = if RunService:IsStudio() then workspace:GetAttribute("NextSeed") else nil
	if typeof(replay) == "number" then
		workspace:SetAttribute("NextSeed", nil)
		seed = replay
	end
	local nextTier = if RunService:IsStudio() then workspace:GetAttribute("NextTier") else nil
	if typeof(nextTier) == "string" and Config.Tiers[nextTier] then
		workspace:SetAttribute("NextTier", nil)
		tier = nextTier
	end
	RunState.set("Building")
	local nest = Present.newNest(tier, seed)
	local sizes = Nest.sizes(nest, Config.Tiers[tier].presentStuds, Config.Tiers.coreBoxStuds)
	local tierNumber = table.find(Config.Tiers.order, tier) or 1
	Nest.tape(nest, sizes, perFaceOf, Config.TapeOverlay, PanelGrid.faceCount, PanelGrid.BOTTOM, Rng, tierNumber)
	Economy.resetRun(tierNumber)
	Tear.loadNest(nest, sizes, tierNumber, presentBase(tier))
	Loot.startRun(nest, tierNumber)
	RunState.set("Unwrapping")

	local names = {}
	for _, layer in nest.layers do
		local strips = layer.tapeStrips and ` (tape {#layer.tapeStrips})` or ""
		table.insert(names, layer.layerType .. strips)
	end
	print(`Present: seed {nest.seed}, {nest.tier}: {table.concat(names, " > ")}`)
end

function Present.init()
	-- After the bank the party goes back to the lobby (Lobby.runEnded); in local play the next run starts here.
	Loot.onBankDone(function()
		if not Lobby.runEnded() then
			Present.startRun(Economy.nextRunTier())
		end
	end)
	task.defer(function()
		Economy.setupShop(presentBase("Birthday"))
		-- The run place waits for its party and uses their tier (N13); local play starts at once.
		Present.startRun(Lobby.waitForParty() or "Birthday")
	end)
end

return Present
