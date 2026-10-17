--[=[
	PanelGrid (pure logic, server)
	Owns: one layer's panel grid, built from a layer definition, and its torn-panel bitfield.
	Must never: call game:GetService, touch an Instance, or hold a number inline. Numbers arrive
	as arguments (Config.Panels, present size) so this runs under Lune tests and in Roblox alike.
	Panel ids are 1-based; bit (id - 1) of the bitfield is set when that panel is torn.
	Read first: src/server/Tear/README.md
]=]

export type Vec = { x: number, y: number, z: number }

export type LayerDefinition = {
	layerType: string,
	depth: number,
}

export type PanelsConfig = {
	gridPerFaceLowTier: number,
	gridPerFaceHighTier: number,
	highTierFrom: number,
}

export type Grid = {
	layerType: string,
	depth: number,
	perFace: number,
	count: number,
	torn: buffer,
}

-- A cube: each face is a normal plus two in-plane axes (u = columns, v = rows).
local FACES: { { n: Vec, u: Vec, v: Vec } } = {
	{ n = { x = 1, y = 0, z = 0 }, u = { x = 0, y = 0, z = -1 }, v = { x = 0, y = 1, z = 0 } },
	{ n = { x = -1, y = 0, z = 0 }, u = { x = 0, y = 0, z = 1 }, v = { x = 0, y = 1, z = 0 } },
	{ n = { x = 0, y = 1, z = 0 }, u = { x = 1, y = 0, z = 0 }, v = { x = 0, y = 0, z = -1 } },
	{ n = { x = 0, y = -1, z = 0 }, u = { x = 1, y = 0, z = 0 }, v = { x = 0, y = 0, z = 1 } },
	{ n = { x = 0, y = 0, z = 1 }, u = { x = 1, y = 0, z = 0 }, v = { x = 0, y = 1, z = 0 } },
	{ n = { x = 0, y = 0, z = -1 }, u = { x = -1, y = 0, z = 0 }, v = { x = 0, y = 1, z = 0 } },
}

-- Layer types that are a grid of panels. Other types arrive with their own rules in Phase 1.
local GRID_LAYER_TYPES = { Paper = true }

local PanelGrid = {}

PanelGrid.faceCount = #FACES

function PanelGrid.gridPerFace(tier: number, panels: PanelsConfig): number
	if tier >= panels.highTierFrom then
		return panels.gridPerFaceHighTier
	end
	return panels.gridPerFaceLowTier
end

function PanelGrid.fromLayer(layer: LayerDefinition, tier: number, panels: PanelsConfig): Grid
	assert(GRID_LAYER_TYPES[layer.layerType], `PanelGrid: {layer.layerType} is not a panel grid layer`)
	local perFace = PanelGrid.gridPerFace(tier, panels)
	local count = #FACES * perFace * perFace
	return {
		layerType = layer.layerType,
		depth = layer.depth,
		perFace = perFace,
		count = count,
		torn = buffer.create(math.ceil(count / 8)),
	}
end

function PanelGrid.panelId(grid: Grid, face: number, row: number, col: number): number
	local n = grid.perFace
	return (face - 1) * n * n + (row - 1) * n + col
end

function PanelGrid.locate(grid: Grid, id: number): (number, number, number)
	assert(id >= 1 and id <= grid.count, `PanelGrid: panel {id} out of range`)
	local n = grid.perFace
	local i = id - 1
	local face = i // (n * n)
	local rest = i % (n * n)
	return face + 1, rest // n + 1, rest % n + 1
end

function PanelGrid.isTorn(grid: Grid, id: number): boolean
	assert(id >= 1 and id <= grid.count, `PanelGrid: panel {id} out of range`)
	local byte = buffer.readu8(grid.torn, (id - 1) // 8)
	return bit32.btest(byte, bit32.lshift(1, (id - 1) % 8))
end

function PanelGrid.setTorn(grid: Grid, id: number, torn: boolean)
	assert(id >= 1 and id <= grid.count, `PanelGrid: panel {id} out of range`)
	local offset = (id - 1) // 8
	local mask = bit32.lshift(1, (id - 1) % 8)
	local byte = buffer.readu8(grid.torn, offset)
	byte = if torn then bit32.bor(byte, mask) else bit32.band(byte, bit32.bnot(mask))
	buffer.writeu8(grid.torn, offset, bit32.band(byte, 0xFF))
end

-- The bitfield as a string, for replication or saving. decode is its exact inverse.
function PanelGrid.encode(grid: Grid): string
	return buffer.tostring(grid.torn)
end

function PanelGrid.decode(grid: Grid, encoded: string)
	assert(#encoded == buffer.len(grid.torn), "PanelGrid: encoded bitfield does not match this grid")
	grid.torn = buffer.fromstring(encoded)
end

-- Where a panel sits on a cube of side `size` centred on the origin: its centre, its outward
-- normal, and its edge length.
function PanelGrid.placement(grid: Grid, id: number, size: number): { center: Vec, normal: Vec, width: number }
	local face, row, col = PanelGrid.locate(grid, id)
	local f = FACES[face]
	local width = size / grid.perFace
	local half = size / 2
	local du = -half + (col - 0.5) * width
	local dv = -half + (row - 0.5) * width
	return {
		center = {
			x = f.n.x * half + f.u.x * du + f.v.x * dv,
			y = f.n.y * half + f.u.y * du + f.v.y * dv,
			z = f.n.z * half + f.u.z * du + f.v.z * dv,
		},
		normal = f.n,
		width = width,
	}
end

return PanelGrid
