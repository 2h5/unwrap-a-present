--[=[
	Sight (pure logic, server)
	Owns: Jack's line of sight. A sight line is blocked when it passes through any box: the present's
	current layer (Jack cannot see through layers) or a lid prop (hide and shutter).
	Boxes are oriented: a centre, three unit axes and the half size along each.
	Must never: call game:GetService or touch an Instance. Night turns parts into boxes.
	Read first: src/server/Night/README.md
]=]

export type Vec = { x: number, y: number, z: number }

export type Box = { center: Vec, axes: { Vec }, half: Vec }

local EPSILON = 1e-9

local Sight = {}

local function sub(a: Vec, b: Vec): Vec
	return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
end

local function dot(a: Vec, b: Vec): number
	return a.x * b.x + a.y * b.y + a.z * b.z
end

local X, Y, Z = { x = 1, y = 0, z = 0 }, { x = 0, y = 1, z = 0 }, { x = 0, y = 0, z = 1 }

-- An axis-aligned box from its centre and full size.
function Sight.aabb(center: Vec, size: Vec): Box
	return { center = center, axes = { X, Y, Z }, half = { x = size.x / 2, y = size.y / 2, z = size.z / 2 } }
end

-- Whether the segment a→b passes through `box` (slab test in the box's own axes).
function Sight.crosses(a: Vec, b: Vec, box: Box): boolean
	local p, d = sub(a, box.center), sub(b, a)
	local halves = { box.half.x, box.half.y, box.half.z }
	local t0, t1 = 0, 1
	for i, axis in box.axes do
		local origin, dir, h = dot(p, axis), dot(d, axis), halves[i]
		if math.abs(dir) < EPSILON then
			if origin < -h or origin > h then
				return false
			end
		else
			local near, far = (-h - origin) / dir, (h - origin) / dir
			if near > far then
				near, far = far, near
			end
			t0, t1 = math.max(t0, near), math.min(t1, far)
			if t0 > t1 then
				return false
			end
		end
	end
	return true
end

-- Whether any box blocks the sight line a→b.
function Sight.blocked(a: Vec, b: Vec, boxes: { Box }): boolean
	for _, box in boxes do
		if Sight.crosses(a, b, box) then
			return true
		end
	end
	return false
end

-- Whether point `p` is inside `box` grown by `pad` on every side (Jack's body against a box).
function Sight.inside(p: Vec, box: Box, pad: number): boolean
	local q = sub(p, box.center)
	local halves = { box.half.x, box.half.y, box.half.z }
	for i, axis in box.axes do
		if math.abs(dot(q, axis)) > halves[i] + pad then
			return false
		end
	end
	return true
end

return Sight
