--[=[
	LayerGeometry (pure logic, server)
	Owns: where every LayerModel item sits, relative to its layer's centre: centre, outward normal,
	up axis, size along the face (sizeX, sizeY) and thickness (depth). Also a box layer's walls.
	Shapes: paper panels inset in the shell; tape on top of the paper along a full grid line; ribbon
	bands one panel wide hugging the layer they wrap (band B sits over band A where they cross); a bow
	on top; a lid as the box's top slab.
	Must never: call game:GetService or touch an Instance. The caller turns this into CFrames.
	Read first: src/server/Tear/README.md
]=]

local PanelGrid = require("./PanelGrid")
local LayerModel = require("./LayerModel")

type Vec = PanelGrid.Vec

export type Placement = { center: Vec, normal: Vec, up: Vec, sizeX: number, sizeY: number, depth: number }

local LayerGeometry = {}

local function add(a: Vec, b: Vec, s: number): Vec
	return { x = a.x + b.x * s, y = a.y + b.y * s, z = a.z + b.z * s }
end

local ORIGIN = { x = 0, y = 0, z = 0 }

-- On face `face` of a cube of side `size`: the point at (du, dv) in the face plane, pushed `out` along
-- the normal (negative = inward).
local function onFace(face: number, size: number, du: number, dv: number, out: number): (Vec, Vec, Vec)
	local n, u, v = PanelGrid.faceAxes(face)
	local p = add(add(add(ORIGIN, n, size / 2 + out), u, du), v, dv)
	return p, n, v
end

-- `size` is the layer's size in studs (for Ribbon: the size of the layer it wraps, which is its own).
-- `tapeStuds` is a tape strip's width.
function LayerGeometry.place(model: LayerModel.Model, id: number, size: number, thickness: number, tapeStuds: number): Placement
	local item = model.items[id]
	local per = model.perFace
	local w = size / per
	local half = size / 2
	if item.kind == "Panel" then
		local du = -half + ((item.col :: number) - 0.5) * w
		local dv = -half + ((item.row :: number) - 0.5) * w
		local c, n, v = onFace(item.face :: number, size, du, dv, -thickness / 2)
		return { center = c, normal = n, up = v, sizeX = w, sizeY = w, depth = thickness }
	elseif item.kind == "Tape" then
		local offset = -half + (item.line :: number) * w
		local du, dv, sx, sy
		if item.along == "row" then
			du, dv, sx, sy = 0, offset, size, tapeStuds
		else
			du, dv, sx, sy = offset, 0, tapeStuds, size
		end
		local c, n, v = onFace(item.face :: number, size, du, dv, thickness / 2)
		return { center = c, normal = n, up = v, sizeX = sx, sizeY = sy, depth = thickness }
	elseif item.kind == "Segment" then
		local face = item.face :: number
		local crossesUV = item.band == "B" and (face == PanelGrid.TOP or face == PanelGrid.BOTTOM)
		local sx, sy = if crossesUV then size else w, if crossesUV then w else size
		local out = if crossesUV then thickness * 1.5 else thickness / 2
		local c, n, v = onFace(face, size, 0, 0, out)
		return { center = c, normal = n, up = v, sizeX = sx, sizeY = sy, depth = thickness }
	elseif item.kind == "Bow" then
		local bowDepth = w / 2
		local c, n, v = onFace(PanelGrid.TOP, size, 0, 0, thickness * 2 + bowDepth / 2)
		return { center = c, normal = n, up = v, sizeX = w, sizeY = w, depth = bowDepth }
	elseif item.kind == "Lid" then
		local c, n, v = onFace(PanelGrid.TOP, size, 0, 0, -thickness / 2)
		return { center = c, normal = n, up = v, sizeX = size, sizeY = size, depth = thickness }
	end
	error(`LayerGeometry: no shape for {item.kind}`)
end

-- A box layer's walls: every face but the top (the lid), as full slabs inset like panels.
function LayerGeometry.walls(size: number, thickness: number): { Placement }
	local out = {}
	for face = 1, PanelGrid.faceCount do
		if face ~= PanelGrid.TOP then
			local c, n, v = onFace(face, size, 0, 0, -thickness / 2)
			table.insert(out, { center = c, normal = n, up = v, sizeX = size, sizeY = size, depth = thickness })
		end
	end
	return out
end

return LayerGeometry
