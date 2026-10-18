--[=[
	Nest (pure logic, server)
	Owns: building the Nest (ordered layers, outside in) from a seed, a tier and the layer table, and
	each layer's size in studs, and which middle-third layer holds the Tick (placeTick).
	Rules (PLAN.md › Mechanics A; PLAN-TABLES.txt Table 4, Table 9): tier sets the layer count; depth 0
	is Paper; each other layer is picked by its band weight; a type never follows itself; at least one
	BoxLid sits in the middle third; the last two layers are BoxLid (never preceded by a third lid).
	Must never: call game:GetService or read a clock. The caller passes the seed and an Rng.
	Read first: src/server/Present/README.md
]=]

export type Layer = { layerType: string, depth: number, tapeStrips: { TapeStrip }?, tick: { blocking: boolean }? }

export type Nest = { seed: number, tier: string, layers: { Layer } }

export type NestConfig = {
	tiers: { [string]: any }, -- Config.Tiers: [tier].layers
	layerTable: { [string]: any }, -- Config.LayerTable: [type].weights = { outer, middle, inner }
	layerTypes: { string }, -- the types this build ships, in a fixed order (Config.LaunchLayerTypes)
}

-- Rng is passed in, not required, so this module needs no path into ReplicatedStorage.
export type RngApi = {
	new: (seed: number) -> any,
	next: (rng: any) -> number,
	int: (rng: any, lo: number, hi: number) -> number,
	weighted: (rng: any, entries: { { value: string, weight: number } }) -> string?,
}

-- A strip on a full grid line of one face: along "row" sits between rows `line` and `line + 1`,
-- along "col" between columns `line` and `line + 1`. A box lid's strips are along "lid": strip `line` crosses
-- the lid seam on the lid's `line`-th side; LayerModel picks the face.
export type TapeStrip = { seamIndex: number, face: number?, along: string, line: number, cut: boolean }

export type TapeConfig = {
	paperChanceByBand: { number },
	seamFraction: { number }, -- { min, max }
	boxLidFromTier: number,
	boxLidStrips: number,
}

local LID = "BoxLid"
local FIRST = "Paper"
local LIDS_AT_END = 2
local RIBBON = "Ribbon"

local Nest = {}

-- Depth band of a layer: 1 outer third, 2 middle third, 3 inner third. Depth 0 is the outside.
function Nest.band(depth: number, layerCount: number): number
	return math.clamp(depth * 3 // layerCount + 1, 1, 3)
end

-- Middle-third depths that can hold the guaranteed lid without touching the final pair.
local function lidCandidates(count: number): { number }
	local out = {}
	for depth = 1, count - LIDS_AT_END - 2 do
		if Nest.band(depth, count) == 2 then
			table.insert(out, depth)
		end
	end
	return out
end

function Nest.generate(seed: number, tier: string, config: NestConfig, Rng: RngApi): Nest
	local tierInfo = config.tiers[tier]
	assert(tierInfo and tierInfo.layers, `Nest: unknown tier {tier}`)
	local count = tierInfo.layers
	local candidates = lidCandidates(count)
	assert(#candidates > 0, `Nest: tier {tier} has no room for a middle-third lid`)
	assert(table.find(config.layerTypes, FIRST) and table.find(config.layerTypes, LID), "Nest: needs Paper and BoxLid")

	local rng = Rng.new(seed)
	local middleLid = candidates[Rng.int(rng, 1, #candidates)]
	local lastPicked = count - LIDS_AT_END - 1 -- depth just before the final lids

	local layers: { Layer } = { { layerType = FIRST, depth = 0 } }
	local previous = FIRST
	for depth = 1, lastPicked do
		local picked: string?
		if depth == middleLid then
			picked = LID
		else
			local band = Nest.band(depth, count)
			local noLid = depth + 1 == middleLid or depth == lastPicked
			local entries = {}
			for _, layerType in config.layerTypes do
				local rule = config.layerTable[layerType]
				local allowed = layerType ~= previous and not (noLid and layerType == LID)
				if allowed and rule and rule.weights then
					table.insert(entries, { value = layerType, weight = rule.weights[band] })
				end
			end
			picked = Rng.weighted(rng, entries)
		end
		assert(picked, `Nest: no layer type can follow {previous} at depth {depth}`)
		table.insert(layers, { layerType = picked :: string, depth = depth })
		previous = picked :: string
	end
	for depth = count - LIDS_AT_END, count - 1 do
		table.insert(layers, { layerType = LID, depth = depth })
	end
	return { seed = seed, tier = tier, layers = layers }
end

-- Lays tape on Paper layers (never depth 0): a layer is taped with its band's chance, and a taped
-- layer tapes seamFraction of its seams, chosen from the seed. Seams are the full grid lines of the
-- faces off the floor (`bottomFace` is skipped). Tape uses its own stream (seed + 1) so the layer
-- types a seed gives never change with tape rules. From `tape.boxLidFromTier` every BoxLid gets
-- `tape.boxLidStrips` strips across its seam (N36), no seed needed. Sets layer.tapeStrips; returns the nest.
function Nest.tape(
	nest: Nest,
	sizes: { [number]: number },
	perFaceOf: (studs: number) -> number,
	tape: TapeConfig,
	faceCount: number,
	bottomFace: number,
	Rng: RngApi,
	tierNumber: number?
): Nest
	local rng = Rng.new(nest.seed + 1)
	local count = #nest.layers
	local lidsTaped = (tierNumber or 1) >= tape.boxLidFromTier
	for _, layer in nest.layers do
		if layer.layerType == LID and lidsTaped then
			local strips = {}
			for side = 1, tape.boxLidStrips do
				table.insert(strips, { seamIndex = side, along = "lid", line = side, cut = false })
			end
			layer.tapeStrips = strips
		end
		if layer.layerType == FIRST and layer.depth > 0 then
			local band = Nest.band(layer.depth, count)
			if Rng.next(rng) < tape.paperChanceByBand[band] then
				local per = perFaceOf(sizes[layer.depth])
				local seams = {}
				for face = 1, faceCount do
					if face ~= bottomFace then
						for line = 1, per - 1 do
							table.insert(seams, { face = face, along = "row", line = line })
							table.insert(seams, { face = face, along = "col", line = line })
						end
					end
				end
				local lo, hi = tape.seamFraction[1], tape.seamFraction[2]
				local fraction = lo + Rng.next(rng) * (hi - lo)
				local k = math.clamp(math.floor(fraction * #seams + 0.5), 1, #seams)
				for i = 1, k do
					local j = Rng.int(rng, i, #seams)
					seams[i], seams[j] = seams[j], seams[i]
				end
				local strips = {}
				for i = 1, k do
					local s = seams[i]
					local seamIndex = (s.face - 1) * 2 * (per - 1) + (if s.along == "row" then 0 else per - 1) + s.line
					table.insert(strips, { seamIndex = seamIndex, face = s.face, along = s.along, line = s.line, cut = false })
				end
				table.sort(strips, function(a, b)
					return a.seamIndex < b.seamIndex
				end)
				layer.tapeStrips = strips
			end
		end
	end
	return nest
end

-- Places the Tick (Q1) in one middle-third layer, from its own stream (seed + 2) so layer types and
-- tape never change with it. Blocking (`blockingChance`): fused across a middle-third BoxLid's seam,
-- so that lid cannot lift until the Tick is opened. Not blocking: beside a middle-third Paper or
-- BoxLid layer (a Ribbon has no shell to sit by). Sets layer.tick; returns the Tick's depth.
function Nest.placeTick(nest: Nest, blockingChance: number, Rng: RngApi): number
	local rng = Rng.new(nest.seed + 2)
	local count = #nest.layers
	local lids, beside = {}, {}
	for _, layer in nest.layers do
		if Nest.band(layer.depth, count) == 2 and layer.depth < count - LIDS_AT_END then
			if layer.layerType == LID then
				table.insert(lids, layer)
			end
			if layer.layerType ~= RIBBON then
				table.insert(beside, layer)
			end
		end
	end
	assert(#lids > 0, "Nest: no middle-third lid for the Tick (N27)")
	local blocking = Rng.next(rng) < blockingChance
	local pool = if blocking then lids else beside
	local layer = pool[Rng.int(rng, 1, #pool)]
	layer.tick = { blocking = blocking }
	return layer.depth
end

-- Size in studs of every layer, by depth. Shells shrink evenly from `outerStuds` (depth 0) to
-- `coreStuds` (the last layer); a Ribbon has no shell and takes the size of the layer it wraps.
function Nest.sizes(nest: Nest, outerStuds: number, coreStuds: number): { [number]: number }
	local shells = {}
	for _, layer in nest.layers do
		if layer.layerType ~= RIBBON then
			table.insert(shells, layer.depth)
		end
	end
	local sizes = {}
	local step = if #shells > 1 then (outerStuds - coreStuds) / (#shells - 1) else 0
	for i, depth in shells do
		sizes[depth] = outerStuds - (i - 1) * step
	end
	for i = #nest.layers, 1, -1 do
		local layer = nest.layers[i]
		if layer.layerType == RIBBON then
			sizes[layer.depth] = sizes[layer.depth + 1]
		end
	end
	return sizes
end

return Nest
