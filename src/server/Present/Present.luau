--[=[
	Present (server system)
	Owns: Seed, Nest generation, layer table, Tick placement.
	Must never: Be called by the client. The seed is rolled here, on the server, never sent up.
	Nest rules are pure and tested: Nest.luau. This file rolls the seed and keeps the run's Nest.
	Read first: src/server/Present/README.md
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Rng = require(ReplicatedStorage.Shared.Rng.Rng)
local Nest = require(script.Parent.Nest)

local Present = {}

local current: Nest.Nest? = nil

-- Builds a new Nest for `tier` from a fresh server-rolled seed (or the given one, for replays).
function Present.newNest(tier: string, seed: number?): Nest.Nest
	local useSeed = seed or Random.new():NextInteger(1, 2 ^ 31 - 1)
	current = Nest.generate(useSeed, tier, {
		tiers = Config.Tiers,
		layerTable = Config.LayerTable,
		layerTypes = Config.LaunchLayerTypes,
	}, Rng)
	return current :: Nest.Nest
end

function Present.getNest(): Nest.Nest?
	return current
end

function Present.init()
	-- Until Lobby and Data exist (Phase 3), every server is one Birthday run.
	local nest = Present.newNest("Birthday")
	local names = {}
	for _, layer in nest.layers do
		table.insert(names, layer.layerType)
	end
	print(`Present: seed {nest.seed}, {nest.tier}: {table.concat(names, " > ")}`)
end

return Present
