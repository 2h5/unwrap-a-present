--[=[
	Nest (pure logic, server)
	Owns: building the Nest (ordered layers, outside in) from a seed, a tier and the layer table.
	Rules (PLAN.md › Mechanics A; PLAN-TABLES.txt Table 4, Table 9): tier sets the layer count; each
	layer type is picked by its weight in the depth band (outer, middle, inner third); a type never
	follows itself; the last two layers are always BoxLid (the box lid over the core box).
	Must never: call game:GetService or read a clock. The caller passes the seed and an Rng.
	Read first: src/server/Present/README.md
]=]

export type Layer = { layerType: string, depth: number }

export type Nest = { seed: number, tier: string, layers: { Layer } }

export type NestConfig = {
	tiers: { [string]: any }, -- Config.Tiers: [tier].layers
	layerTable: { [string]: any }, -- Config.LayerTable: [type].weights = { outer, middle, inner }
	layerTypes: { string }, -- the types this build ships, in a fixed order (Config.LaunchLayerTypes)
}

-- Rng is passed in, not required, so this module needs no path into ReplicatedStorage.
export type RngApi = {
	new: (seed: number) -> any,
	weighted: (rng: any, entries: { { value: string, weight: number } }) -> string?,
}

local LID = "BoxLid"
local LIDS_AT_END = 2

local Nest = {}

-- Depth band of a layer: 1 outer third, 2 middle third, 3 inner third. Depth 0 is the outside.
function Nest.band(depth: number, layerCount: number): number
	return math.clamp(depth * 3 // layerCount + 1, 1, 3)
end

function Nest.generate(seed: number, tier: string, config: NestConfig, Rng: RngApi): Nest
	local tierInfo = config.tiers[tier]
	assert(tierInfo and tierInfo.layers, `Nest: unknown tier {tier}`)
	local count = tierInfo.layers
	assert(count > LIDS_AT_END, `Nest: tier {tier} needs more than {LIDS_AT_END} layers`)

	local rng = Rng.new(seed)
	local layers: { Layer } = {}
	local previous: string? = nil
	for depth = 0, count - LIDS_AT_END - 1 do
		local band = Nest.band(depth, count)
		local entries = {}
		for _, layerType in config.layerTypes do
			local rule = config.layerTable[layerType]
			if layerType ~= LID and layerType ~= previous and rule and rule.weights then
				table.insert(entries, { value = layerType, weight = rule.weights[band] })
			end
		end
		local picked = Rng.weighted(rng, entries)
		assert(picked, `Nest: no layer type can follow {previous} in band {band}`)
		table.insert(layers, { layerType = picked, depth = depth })
		previous = picked
	end
	for depth = count - LIDS_AT_END, count - 1 do
		table.insert(layers, { layerType = LID, depth = depth })
	end
	return { seed = seed, tier = tier, layers = layers }
end

return Nest
