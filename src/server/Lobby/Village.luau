--[=[
	Village (server, part of Lobby)
	Owns: the setting of Unwrapping Plaza: terrain snow (the ground, soft banks against walls, mounds,
	hills), the paved plaza with its ribbon inlay, the raised terrace ring with steps, benches,
	lanterns and firs, the covered shelf gallery lane, the cottage with its porch, and the backdrop:
	lit village cottages, a fir forest and far peaks, so no baseplate edge or empty horizon shows.
	Must never: hold logic, block a route or a prompt, or put a wall where shelves, the Krampus walk or
	the steal prompt need room. Stock materials only, no stud or dot surface (invariant 4); few lights.
	Read first: src/server/Lobby/README.md
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Art = require(ReplicatedStorage.Shared.Art.Art)
local Config = require(ReplicatedStorage.Shared.Config.Config)
local Props = require(ReplicatedStorage.Shared.Art.Props)

local Village = {}

local L = Config.Lobby
local D = L.dress
local G = L.gallery
local TR = L.terrace
local PAL = Config.Palette

local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's axis upright
local WALL_R = L.plazaRadius + 0.8 -- the terrace's retaining wall, centre line
local TERRACE_IN = L.plazaRadius + 1.6

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-- The ground point `bearing` degrees round the plaza (clockwise from north) at `r` studs.
local function around(bearing: number, r: number, y: number?): Vector3
	local b = math.rad(bearing)
	return v(math.sin(b) * r, y or 0, -math.cos(b) * r)
end

local function bearingOf(p: Vector3): number
	return math.deg(math.atan2(p.X, -p.Z)) % 360
end

local function within(b: number, from: number, to: number): boolean
	if from <= to then
		return b >= from and b <= to
	end
	return b >= from or b <= to -- the span wraps through north
end

local function inGap(b: number): boolean
	for _, gap in TR.gaps do
		if within(b, gap[1], gap[2]) then
			return true
		end
	end
	return false
end

local function nearSteps(b: number, slack: number): boolean
	for _, s in TR.steps do
		local d = math.abs((b - s + 180) % 360 - 180)
		if d <= slack then
			return true
		end
	end
	return false
end

-- True inside the gallery lane's corridor (its buildings and a margin), where nothing else may stand.
local function inGallery(p: Vector3, margin: number): boolean
	local xb = G.startX - G.bays * G.bayStuds - 14
	return p.X < G.startX + 4 and p.X > xb - margin and math.abs(p.Z - G.z) < G.laneStuds / 2 + 6 + margin
end

local function nearCottage(p: Vector3, margin: number): boolean
	return (Vector2.new(p.X, p.Z) - Vector2.new(L.house[1], L.house[2] + 4)).Magnitude < 14 + margin
end

---------------------------------------------------------------- terrain

local function ball(center: Vector3, radius: number)
	workspace.Terrain:FillBall(center, radius, Enum.Material.Snow)
end

-- Terrain snow: the ground everywhere, the terrace's fill and its soft outer edge, banks against the
-- plaza's walls, mounds round the village and the hills beyond it. Built once at server start.
function Village.terrain(rng: Random)
	local T = workspace.Terrain
	T:SetMaterialColor(Enum.Material.Snow, Color3.fromHex(D.snow))
	local size = L.snowfieldStuds
	T:FillBlock(CFrame.new(0, -4.4, 0), v(size, 8, size), Enum.Material.Snow) -- top at y = -0.4
	-- The terrace ring, in 6-degree blocks, with a rounded outer edge.
	local mid, depth = (TERRACE_IN + TR.outer - 2) / 2, TR.outer - 2 - TERRACE_IN
	for b = 0, 354, 6 do
		local c = b + 3
		if not inGap(c) then
			local at = around(c, mid, (TR.heightStuds - 0.4) / 2)
			local chord = 2 * math.pi * TR.outer * 6 / 360 + 2
			T:FillBlock(CFrame.lookAt(at, v(0, at.Y, 0)), v(chord, TR.heightStuds + 0.4, depth), Enum.Material.Snow)
			ball(around(c, TR.outer - 2, 0), 3.4)
		end
	end
	-- Steps cut into the terrace (the stone steps themselves are parts).
	for _, s in TR.steps do
		local f = CFrame.lookAt(around(s, L.plazaRadius), v(0, 0, 0))
		T:FillBlock(f * CFrame.new(0, 3.2, 3), v(15, 6, 6.4), Enum.Material.Air)
	end
	-- Banks against the wall's foot inside the plaza, and soft mounds on the terrace.
	for b = 0, 356, 4 do
		if not inGap(b) and not inGap(b + 4) and not nearSteps(b, 11) and rng:NextNumber() < 0.55 then
			ball(around(b + rng:NextNumber(0, 4), L.plazaRadius - 0.3, -0.7), rng:NextNumber(2, 3.2))
		end
	end
	for _ = 1, 26 do
		local b = rng:NextNumber(0, 360)
		if not inGap(b) and not nearSteps(b, 14) then
			ball(around(b, rng:NextNumber(TERRACE_IN + 3, TR.outer - 4), TR.heightStuds - 0.8), rng:NextNumber(1.8, 3.2))
		end
	end
	-- Mounds through the village ring, then the hills.
	for _ = 1, 40 do
		local at = around(rng:NextNumber(0, 360), rng:NextNumber(TR.outer + 8, L.forest.ring[2]))
		if not inGallery(at, 4) and not nearCottage(at, 6) then
			local r = rng:NextNumber(5, 12)
			ball(at + v(0, -r * 0.65, 0), r)
		end
	end
	local H = L.hills
	for k = 1, H.count do
		local r = rng:NextNumber(H.radius[1], H.radius[2])
		ball(around(k / H.count * 360 + rng:NextNumber(-8, 8), rng:NextNumber(H.ring[1], H.ring[2])) + v(0, -r * 0.5, 0), r)
	end
end

---------------------------------------------------------------- plaza

-- The paved plaza: rings of paving, and a crimson ribbon inlay edged in gold crossing at the centre
-- under a gold medallion, as if the plaza were the top of a wrapped present. The north-south band
-- runs from the arrival steps past the spawn to the landmark's steps.
function Village.plaza(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Plaza"
	local R = L.plazaRadius
	for _, ring in { { R, 0, D.paving }, { R - 2, 0.04, D.pavingBand }, { R - 3.5, 0.08, D.paving }, { 30, 0.12, D.pavingBand }, { 28.5, 0.16, D.paving } } do
		local r, top = ring[1], ring[2]
		local h = if r == R then 1 else 0.2
		Props.part(model, "Paving", v(h, 2 * r, 2 * r), CFrame.new(0, top - h / 2, 0) * FLAT, ring[3], "Pavement")
	end
	local north = L.landmark.center[2] + L.landmark.terraceRadius + 3.5 -- the foot of the landmark's steps
	local function band(from: Vector3, to: Vector3)
		local span = to - from
		local mid = (from + to) / 2
		local look = CFrame.lookAt(mid, to)
		Props.trim(model, "RibbonInlay", v(6, 0.1, span.Magnitude), look * CFrame.new(0, 0.17, 0), D.ribbonRed, "SmoothPlastic")
		for _, side in { -1, 1 } do
			Props.trim(model, "RibbonEdge", v(0.6, 0.12, span.Magnitude), look * CFrame.new(side * 3.2, 0.18, 0), D.ribbonGold, "SmoothPlastic")
		end
	end
	band(v(0, 0, north), v(0, 0, R))
	band(v(-R + 0.5, 0, 0), v(R - 0.5, 0, 0))
	Props.trim(model, "Medallion", v(0.1, 10, 10), CFrame.new(0, 0.21, 0) * FLAT, D.ribbonGold, "SmoothPlastic")
	Props.trim(model, "Medallion", v(0.1, 7, 7), CFrame.new(0, 0.25, 0) * FLAT, D.ribbonRed, "SmoothPlastic")
	for _, side in { -1, 1 } do -- a flat bow: two loops either side of the knot
		Props.trim(model, "MedallionLoop", v(2.6, 0.1, 2.6), CFrame.new(side * 1.9, 0.29, 0) * CFrame.Angles(0, math.rad(45), 0), D.ribbonGold, "SmoothPlastic")
	end
	Props.trim(model, "MedallionKnot", v(0.1, 1.6, 1.6), CFrame.new(0, 0.31, 0) * FLAT, D.ribbonGold, "SmoothPlastic")
	model.Parent = parent
end

---------------------------------------------------------------- terrace

-- The terrace ring's stone retaining wall, coping and snow; steps with cheeks; pillars where the
-- wall stops; firs, benches and lanterns on the terrace and round the plaza.
function Village.terrace(parent: Instance, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Terrace"
	local h = TR.heightStuds
	local chord = 2 * WALL_R * math.sin(math.rad(3)) + 0.3
	local function pillar(b: number)
		local at = around(b, WALL_R, 0)
		Props.part(model, "Pillar", v(2.4, h + 2, 2.4), CFrame.new(at + v(0, (h + 2) / 2 - 0.8, 0)), D.stoneDark, "Slate")
		Props.trim(model, "PillarCap", v(2.9, 0.5, 2.9), CFrame.new(at + v(0, h + 1.45, 0)), D.stone, "Slate")
		Props.trim(model, "Snow", v(2.5, 0.5, 2.5), CFrame.new(at + v(0, h + 1.9, 0)), D.snow, "Snow")
	end
	for b = 0, 354, 6 do
		local c = b + 3
		local was, will = inGap(c - 6) or nearSteps(c - 6, 8), inGap(c + 6) or nearSteps(c + 6, 8)
		if not inGap(c) and not nearSteps(c, 8) then
			local f = CFrame.lookAt(around(c, WALL_R, 0), v(0, 0, 0))
			Props.part(model, "Wall", v(chord, h + 0.8, 1.6), f * CFrame.new(0, (h - 0.8) / 2, 0), D.stone, "Slate")
			Props.part(model, "Coping", v(chord + 0.1, 0.45, 2.4), f * CFrame.new(0, h + 0.22, 0.2), D.paving, "Slate")
			if rng:NextNumber() < 0.6 then
				local len = chord * rng:NextNumber(0.5, 1)
				local thick = rng:NextNumber(0.25, 0.55)
				Props.trim(model, "Snow", v(len, thick, 2), f * CFrame.new(rng:NextNumber(-0.5, 0.5), h + 0.45 + thick / 2, 0.3), D.snow, "Snow")
			end
			if was then
				pillar(c - 3)
			end
			if will then
				pillar(c + 3)
			end
		end
	end
	-- Steps: three risers up from the plaza, stone cheeks either side.
	local rise = (h + 0.05) / 3
	for _, s in TR.steps do
		local f = CFrame.lookAt(around(s, L.plazaRadius), v(0, 0, 0)) -- +Z runs outward
		for k = 1, 3 do
			local top = rise * k
			Props.part(model, "Step", v(14, top + 0.6, 1.8), f * CFrame.new(0, (top - 0.6) / 2, 0.9 + (k - 1) * 1.7), D.stone, "Slate")
		end
		Props.part(model, "Landing", v(14, h + 0.6, 2.4), f * CFrame.new(0, (h - 0.6) / 2, 6.1), D.stone, "Slate")
		for _, side in { -1, 1 } do
			Props.part(model, "StepCheek", v(1.4, h + 1.2, 7.4), f * CFrame.new(side * 7.7, (h + 1.2) / 2 - 0.6, 3.6), D.stoneDark, "Slate")
			Props.trim(model, "Snow", v(1.3, 0.4, 6.4), f * CFrame.new(side * 7.7, h + 0.8, 3.8), D.snow, "Snow")
		end
	end
	-- Firs and benches on the terrace, clear of the steps.
	for _ = 1, 12 do
		local b = rng:NextNumber(0, 360)
		if not inGap(b) and not nearSteps(b, 14) then
			Props.fir(model, around(b, rng:NextNumber(TERRACE_IN + 7, TR.outer - 3), h - 0.3), rng:NextNumber(0.75, 1.05), rng)
		end
	end
	for _, b in { 166, 194, 104, 124 } do
		local at = around(b, TERRACE_IN + 4, h)
		Props.bench(model, CFrame.lookAt(at, v(0, h, 0)))
	end
	-- Benches on the plaza, a gathering spot either side of the spawn.
	for _, spot in { v(-24, 0.16, 32), v(8, 0.16, 40) } do
		Props.bench(model, CFrame.lookAt(spot, v(0, 0.16, 0)))
	end
	-- Lanterns round the plaza's edge (four lit), two unlit beside the landmark's steps.
	for k, b in { 65, 112, 158, 202, 282 } do
		Props.lantern(model, around(b, L.plazaRadius - 2.5, 0.1), 7, k ~= 2)
	end
	local foot = L.landmark.center[2] + L.landmark.terraceRadius + 3
	for _, x in { -10, 10 } do
		Props.lantern(model, v(x, 0.1, foot), 6, false)
	end
	-- Low glowing bollards on the inner paving ring (no lights), clear of the ribbon bands and the
	-- walk from the porch.
	for b = 22.5, 337.5, 45 do
		if b ~= 292.5 then
			local at = around(b, 30, 0.12)
			Props.part(model, "Bollard", v(0.9, 2.4, 0.9), CFrame.new(at + v(0, 1.2, 0)), D.stoneDark, "Slate")
			Props.trim(model, "BollardLight", v(1, 0.6, 1), CFrame.new(at + v(0, 2.7, 0)), D.lantern, "Neon")
			Props.trim(model, "Snow", v(1.1, 0.3, 1.1), CFrame.new(at + v(0, 3.15, 0)), D.snow, "Snow")
		end
	end
	model.Parent = parent
end

---------------------------------------------------------------- the shelf gallery

-- The floor point and facing of shelf slot `i`: odd slots on the lane's north side facing south, even
-- on its south side facing north, nearest the plaza first; past the last bay the rows run on west.
-- The CFrame's +X points out of the shelf's front.
function Village.shelfSpot(i: number): CFrame
	local bay = math.ceil(i / 2)
	local side = if i % 2 == 1 then -1 else 1
	local pos = v(G.startX - (bay - 0.5) * G.bayStuds, 0.1, G.z + side * (G.laneStuds / 2 + 2))
	return CFrame.fromMatrix(pos, v(0, 0, -side), Vector3.yAxis)
end

-- The covered lane: paving, a timber-and-plaster arcade over each row of shelves with snow on its
-- roof, hanging lanterns, gift-tag bunting across the lane, a ribbon-wrapped gate facing the plaza
-- and a big fir closing the far end. The lane's middle stays clear for the Krampus walk.
function Village.gallery(parent: Instance, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Gallery"
	local xa = G.startX
	local xb = xa - G.bays * G.bayStuds
	local len = xa - xb
	local midX = (xa + xb) / 2
	Props.part(model, "LanePaving", v(len + 10, 0.2, G.laneStuds + 9), CFrame.new(midX + 1, 0, G.z), D.pavingBand, "Pavement")
	for _, side in { -1, 1 } do
		local spotZ = G.z + side * (G.laneStuds / 2 + 2)
		local backZ = spotZ + side * 1.6
		local postZ = spotZ - side * 2.6
		Props.part(model, "BackWall", v(len, 9, 1), CFrame.new(midX, 4.6, backZ), D.wall, "WoodPlanks")
		Props.trim(model, "WallBase", v(len, 1.2, 1.2), CFrame.new(midX, 0.7, backZ), D.woodDark, "Wood")
		Props.trim(model, "WallPlate", v(len, 0.8, 1.3), CFrame.new(midX, 8.8, backZ), D.woodDark, "Wood")
		for j = 0, G.bays do
			local x = xa - j * G.bayStuds
			Props.part(model, "Post", v(0.9, 9.6, 0.9), CFrame.new(x, 4.9, postZ), D.wood, "Wood")
			Props.trim(model, "Brace", v(0.5, 0.5, 2.6), CFrame.new(x, 8.6, postZ + side * 1.1) * CFrame.Angles(math.rad(side * 40), 0, 0), D.woodDark, "Wood")
		end
		Props.trim(model, "Beam", v(len + 0.8, 0.9, 0.9), CFrame.new(midX, 9.6, postZ), D.woodDark, "Wood")
		-- A lean-to roof, high at the lane, low over the back wall.
		local depth = math.abs(backZ - postZ) + 2.2
		local roofZ = (backZ + postZ) / 2 + side * 0.3
		local tilt = CFrame.Angles(math.rad(side * 9), 0, 0)
		local roof = CFrame.new(midX, G.roofStuds, roofZ) * tilt
		Props.part(model, "Roof", v(len + 1.2, 0.6, depth), roof, L.colors.roof, "RoofShingles")
		local x = xa + 0.6
		while x > xb - 0.6 do -- snow in uneven runs along the roof
			local run = math.min(rng:NextNumber(10, 22), x - (xb - 0.6))
			local thick = rng:NextNumber(0.35, 0.8)
			Props.trim(model, "Snow", v(run - 0.4, thick, depth * rng:NextNumber(0.75, 0.95)), roof * CFrame.new(x - run / 2 - midX, 0.3 + thick / 2, side * 0.3), D.snow, "Snow")
			x -= run
		end
		-- Hanging lanterns under the beam, two of them lit across the whole gallery.
		for j = 2, G.bays - 1, 2 do
			local lit = (side < 0 and j == 4) or (side > 0 and j == 8)
			Props.hangingLantern(model, v(xa - j * G.bayStuds, 9.15, postZ), lit)
		end
	end
	-- Bunting of little gift tags across the lane every other bay, each string swaying.
	local north, south = G.z - G.laneStuds / 2 - 2 + 2.6, G.z + G.laneStuds / 2 + 2 - 2.6
	for j = 1, G.bays - 1, 2 do
		local x = xa - j * G.bayStuds
		local string = Instance.new("Model")
		string.Name = "Bunting"
		local a, m, b = v(x, 9.1, north), v(x, 8, G.z), v(x, 9.1, south)
		Props.twine(string, a, m)
		Props.twine(string, m, b)
		for k = 1, 5 do
			local t = k / 6
			local p = if t < 0.5 then a:Lerp(m, t * 2) else m:Lerp(b, t * 2 - 1)
			Props.trim(string, "BuntingTag", v(0.08, 1, 0.75), CFrame.new(p - v(0, 0.55, 0)), PAL.paper[(j + k) % #PAL.paper + 1])
		end
		string.Parent = model
		Props.sway(string, v(x, 9.1, G.z), Vector3.zAxis, 5)
	end
	-- The gate: two posts, a beam wrapped in ribbon with a bow, the Shelves tag facing the plaza.
	local gx = xa + 1.5
	for _, side in { -1, 1 } do
		Props.part(model, "GatePost", v(1.4, 12.6, 1.4), CFrame.new(gx, 6.2, G.z + side * 9), D.woodDark, "Wood")
		Props.trim(model, "Snow", v(1.3, 0.4, 1.3), CFrame.new(gx, 12.7, G.z + side * 9), D.snow, "Snow")
	end
	Props.part(model, "GateBeam", v(1.3, 1.3, 19.6), CFrame.new(gx, 11.6, G.z), D.woodDark, "Wood")
	for _, z in { -6, 0, 6 } do
		Props.trim(model, "GateRibbon", v(1.45, 1.45, 1.2), CFrame.new(gx, 11.6, G.z + z), D.ribbonRed)
	end
	Props.bow(model, CFrame.new(gx, 12.25, G.z) * CFrame.Angles(0, math.rad(90), 0), 3, D.ribbonRed)
	Props.trim(model, "Snow", v(1.1, 0.35, 15), CFrame.new(gx, 12.4, G.z + 1.5), D.snow, "Snow")
	local sign = Instance.new("Model")
	sign.Name = "Sign"
	local tagAt = CFrame.lookAt(v(gx + 0.4, 9, G.z), v(gx + 4, 9, G.z))
	Props.tag(sign, tagAt, 7, 2.2, "Shelves", "Everyone's best finds")
	for _, z in { -2.4, 2.4 } do
		Props.twine(sign, v(gx + 0.4, 10.1, G.z + z), v(gx + 0.4, 11, G.z + z))
	end
	for _, part in sign:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
	sign.Parent = model
	Props.sway(sign, v(gx + 0.4, 11, G.z), Vector3.zAxis, 2.5)
	-- The far end: a big fir on a mound, a bench before it.
	local endX = xb - 12
	workspace.Terrain:FillBall(v(endX, -3, G.z), 6, Enum.Material.Snow)
	Props.fir(model, v(endX, 1.6, G.z), 1.5, rng)
	Props.bench(model, CFrame.lookAt(v(endX + 6, 0.1, G.z), v(xa, 0.1, G.z)))
	-- Firs behind both rows.
	for k = 1, 6 do
		for _, side in { -1, 1 } do
			if rng:NextNumber() < 0.7 then
				Props.fir(model, v(xa - k * 13 - rng:NextNumber(0, 5), -0.3, G.z + side * rng:NextNumber(17, 22)), rng:NextNumber(0.8, 1.15), rng)
			end
		end
	end
	model.Parent = parent
end

---------------------------------------------------------------- houses

-- A window on a wall face: `cf` its centre, front (-Z) out. Lit windows glow warm (Neon, no light).
local function window(parent: Instance, cf: CFrame, w: number, h: number, lit: boolean)
	local glass = Props.trim(parent, "Glass", v(w, h, 0.2), cf, if lit then D.window else D.glass, if lit then "Neon" else "Glass")
	glass.Transparency = if lit then 0.08 else 0.35
	for _, spec in { { 0, h / 2, w + 0.6, 0.4 }, { 0, -h / 2, w + 1, 0.5 }, { w / 2, 0, 0.4, h }, { -w / 2, 0, 0.4, h }, { 0, 0, 0.25, h }, { 0, 0, w, 0.25 } } do
		Props.trim(parent, "WindowFrame", v(spec[3], spec[4], 0.4), cf * CFrame.new(spec[1], spec[2], -0.15), D.trim, "Wood")
	end
	Props.trim(parent, "Snow", v(w + 0.9, 0.3, 0.6), cf * CFrame.new(0, -h / 2 + 0.38, -0.35), D.snow, "Snow")
end

-- A gabled roof over walls whose top centre is `top` (ridge along X), with uneven snow on both slopes.
local function roof(parent: Instance, top: CFrame, w: number, d: number, rise: number, color: string, rng: Random)
	local half = d / 2 + 1
	local slope = math.atan2(rise, half)
	local slab = math.sqrt(half * half + rise * rise) + 0.4
	for _, side in { -1, 1 } do
		local cf = top * CFrame.new(0, rise / 2 + 0.3, side * half / 2) * CFrame.Angles(side * slope, 0, 0)
		Props.part(parent, "Roof", v(w + 2.4, 0.8, slab), cf, color, "RoofShingles")
		local cover = rng:NextNumber(0.55, 0.95)
		local thick = rng:NextNumber(0.5, 1)
		Props.trim(parent, "Snow", v((w + 2) * cover, thick, slab * rng:NextNumber(0.7, 0.92)), cf * CFrame.new(rng:NextNumber(-1, 1), 0.4 + thick / 2, -side * 0.3), D.snow, "Snow")
		Props.trim(parent, "Snow", v((w + 2.2) * rng:NextNumber(0.4, 0.8), thick * 0.8, 0.9), cf * CFrame.new(rng:NextNumber(-2, 2), 0.4 + thick * 0.4, side * (slab / 2 - 0.3)), D.snow, "Snow")
		local gable = top * CFrame.new(0, rise / 2, side * d / 4) * (if side > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.new())
		for _, gx in { -w / 2 + 0.3, w / 2 - 0.3 } do
			Props.wedge(parent, "Gable", v(0.6, rise, d / 2), CFrame.new(gx, 0, 0) * gable, D.wall, "WoodPlanks")
		end
	end
	Props.trim(parent, "Ridge", v(w + 2.8, 0.9, 0.9), top * CFrame.new(0, rise + 0.5, 0), D.woodDark, "Wood")
	Props.trim(parent, "Snow", v(w + 2.2, 0.5, 1.2), top * CFrame.new(0, rise + 1.1, 0), D.snow, "Snow")
end

-- The cottage and its porch, facing the plaza. Returns the porch deck (vault crates and tier
-- decoration sit on it; Shelf finds `Porch` and `House.PorchBeam` by name).
function Village.cottage(parent: Instance, rng: Random): BasePart
	local hx, hz = L.house[1], L.house[2]
	local model = Instance.new("Model")
	model.Name = "House"
	local wallH = 10
	Props.part(model, "Foundation", v(17, 1, 13), CFrame.new(hx, 0.5, hz), D.stoneDark, "Slate")
	Props.part(model, "Walls", v(16, wallH, 12), CFrame.new(hx, 1 + wallH / 2, hz), D.wall, "WoodPlanks")
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Props.trim(model, "CornerPost", v(1.2, wallH + 0.4, 1.2), CFrame.new(hx + sx * 8, 1 + wallH / 2, hz + sz * 6), D.woodDark, "Wood")
		end
	end
	Props.trim(model, "Belt", v(16.4, 0.5, 12.4), CFrame.new(hx, 1 + wallH, hz), D.woodDark, "Wood")
	local top = 1 + wallH
	roof(model, CFrame.new(hx, top, hz), 16, 12, 4.5, L.colors.roof, rng)
	Props.part(model, "Chimney", v(2, 6, 2), CFrame.new(hx + 4.5, top + 3, hz - 2.6), D.chimney, "Slate")
	local cap = Props.trim(model, "ChimneyCap", v(2.6, 0.5, 2.6), CFrame.new(hx + 4.5, top + 6.2, hz - 2.6), D.woodDark, "Wood")
	local smoke = Instance.new("ParticleEmitter") -- a thin curl of chimney smoke, slow and sparse
	smoke.Texture = Art.particles.dust
	smoke.Color = ColorSequence.new(Color3.fromHex(D.snowShade))
	smoke.Rate = 1.2
	smoke.Lifetime = NumberRange.new(6, 8)
	smoke.Speed = NumberRange.new(2, 3)
	smoke.SpreadAngle = Vector2.new(8, 8)
	smoke.Acceleration = v(1.2, 0.3, 0)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 5) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Parent = cap
	-- Front (south) face: a door between two lit windows; one window on each end.
	local front = hz + 6
	Props.trim(model, "Door", v(3.4, 6.4, 0.4), CFrame.new(hx, 1 + 3.2, front + 0.15), D.woodDark, "WoodPlanks")
	Props.trim(model, "DoorFrame", v(4.4, 0.5, 0.5), CFrame.new(hx, 7.6, front + 0.2), D.trim, "Wood")
	for _, sx in { -1, 1 } do
		Props.trim(model, "DoorFrame", v(0.5, 6.6, 0.5), CFrame.new(hx + sx * 1.95, 4.3, front + 0.2), D.trim, "Wood")
		window(model, CFrame.lookAt(v(hx + sx * 4.9, 6, front + 0.15), v(hx + sx * 4.9, 6, front + 1)), 3, 3, true)
		window(model, CFrame.lookAt(v(hx + sx * 8.15, 6, hz), v(hx + sx * 9, 6, hz)), 3, 3, sx > 0)
	end
	Props.trim(model, "DoorKnob", Vector3.one * 0.4, CFrame.new(hx + 1.1, 4, front + 0.45), D.lantern, "Metal", Enum.PartType.Ball)
	-- The porch: deck, step, posts, a beam, a shallow snowy roof, railings with a gap for the step.
	local porch = Props.part(model, "Porch", v(16, 1, 8), CFrame.new(hx, 0.5, hz + 10), D.plank, "WoodPlanks")
	porch.Parent = parent -- Lobby and Shelf find the porch by name under Workspace.Lobby
	local edge = hz + 14
	Props.part(model, "Step", v(4.4, 0.5, 1.4), CFrame.new(hx, 0.25, edge + 0.7), D.wood, "WoodPlanks")
	for _, sx in { -1, 1 } do
		Props.part(model, "PorchPost", v(0.8, 8, 0.8), CFrame.new(hx + sx * 7.6, 5, edge - 0.4), D.woodDark, "Wood")
	end
	Props.trim(model, "PorchBeam", v(16.6, 0.8, 0.8), CFrame.new(hx, 9.2, edge - 0.4), D.woodDark, "Wood")
	local porchRoof = CFrame.new(hx, 9.9, hz + 9.8) * CFrame.Angles(math.rad(10), 0, 0)
	Props.part(model, "PorchRoof", v(17.2, 0.6, 9), porchRoof, L.colors.roof, "RoofShingles")
	Props.snow(model, porchRoof * CFrame.new(-1, 0.3, -0.5), 16, 8, 0.45, 0.85)
	Props.hangingLantern(model, v(hx - 4, 9.0, edge - 0.4), true)
	local function rail(a: Vector3, b: Vector3)
		local mid = (a + b) / 2
		local length = (b - a).Magnitude
		for _, y in { 1.6, 3.2 } do
			Props.part(model, "Rail", v(0.35, 0.35, length), CFrame.lookAt(mid + Vector3.yAxis * y, b + Vector3.yAxis * y), D.wood, "Wood")
		end
		Props.trim(model, "Snow", v(0.45, 0.2, length * 0.8), CFrame.lookAt(mid + Vector3.yAxis * 3.47, b + Vector3.yAxis * 3.47), D.snow, "Snow")
		for k = 0, 3 do
			Props.trim(model, "Baluster", v(0.3, 2.4, 0.3), CFrame.new(a:Lerp(b, k / 3) + Vector3.yAxis * 2.2), D.wood, "Wood")
		end
	end
	rail(v(hx - 7.6, 0, edge - 0.4), v(hx - 2.4, 0, edge - 0.4))
	rail(v(hx + 2.4, 0, edge - 0.4), v(hx + 7.6, 0, edge - 0.4))
	rail(v(hx - 7.6, 0, hz + 6.4), v(hx - 7.6, 0, edge - 0.8))
	rail(v(hx + 7.6, 0, hz + 6.4), v(hx + 7.6, 0, edge - 0.8))
	-- A paved forecourt from the porch step to the plaza, and snow banked at the cottage's corners.
	Props.part(model, "Forecourt", v(14, 0.2, 10), CFrame.new(hx + 2, 0, edge + 5), D.pavingBand, "Pavement")
	for _, corner in { v(hx - 9, -0.6, hz - 6.5), v(hx + 9, -0.6, hz - 6.5), v(hx - 9.5, -0.6, hz + 4) } do
		workspace.Terrain:FillBall(corner, rng:NextNumber(2.4, 3.4), Enum.Material.Snow)
	end
	model.Parent = parent
	return porch
end

-- A backdrop cottage at `at` (front, -Z, toward the plaza): walls, roof with snow, lit windows, a
-- door with a glowing lamp, sometimes a chimney. Nobody goes in.
local function villageHouse(parent: Instance, at: CFrame, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Cottage"
	local w, d, h = rng:NextNumber(12, 16), rng:NextNumber(10, 13), rng:NextNumber(8, 11)
	local walls = D.walls[rng:NextInteger(1, #D.walls)]
	Props.part(model, "Foundation", v(w + 1, 2.4, d + 1), at * CFrame.new(0, -0.2, 0), D.stoneDark, "Slate")
	Props.part(model, "Walls", v(w, h, d), at * CFrame.new(0, 1 + h / 2, 0), walls, "WoodPlanks")
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Props.trim(model, "CornerPost", v(1, h + 0.2, 1), at * CFrame.new(sx * w / 2, 1 + h / 2, sz * d / 2), D.woodDark, "Wood")
		end
	end
	roof(model, at * CFrame.new(0, 1 + h, 0), w, d, rng:NextNumber(3.5, 5.5), D.roofs[rng:NextInteger(1, #D.roofs)], rng)
	if rng:NextNumber() < 0.5 then
		local cx = rng:NextNumber(-w / 3, w / 3)
		Props.part(model, "Chimney", v(1.8, 5, 1.8), at * CFrame.new(cx, h + 3.2, d / 5), D.chimney, "Slate")
		Props.trim(model, "Snow", v(2, 0.4, 2), at * CFrame.new(cx, h + 5.9, d / 5), D.snow, "Snow")
	end
	local face = -d / 2 - 0.15
	Props.trim(model, "Door", v(3, 5.6, 0.3), at * CFrame.new(-w / 4, 1 + 2.8, face), D.woodDark, "WoodPlanks")
	Props.trim(model, "DoorLamp", v(0.6, 0.8, 0.6), at * CFrame.new(-w / 4 + 2.1, 6.2, face - 0.3), D.lantern, "Neon")
	window(model, at * CFrame.new(w / 5, 1 + h * 0.55, face), 2.8, 2.6, rng:NextNumber() < 0.8)
	for _, sx in { -1, 1 } do
		window(model, at * CFrame.new(sx * (w / 2 + 0.15), 1 + h * 0.55, 0) * CFrame.Angles(0, math.rad(sx * -90), 0), 2.4, 2.4, rng:NextNumber() < 0.5)
	end
	model.Parent = parent
	for _, corner in { v(-w / 2 - 1, 0, -d / 2 - 1), v(w / 2 + 1, 0, d / 2 + 1) } do
		workspace.Terrain:FillBall((at * CFrame.new(corner)).Position + v(0, -0.8, 0), rng:NextNumber(2.4, 3.6), Enum.Material.Snow)
	end
end

-- A far peak: a cube stood on its corner, a snow cap on its tip, and a lower shoulder beside it.
local function peak(parent: Instance, at: Vector3, s: number, rng: Random)
	local up = CFrame.Angles(math.rad(45), 0, math.rad(35.26)) -- one corner straight up
	local side = CFrame.lookAt(at, v(0, at.Y, 0)).RightVector
	for _, spec in { { 0, 1 }, { s * 0.55, 0.68 } } do
		local size = s * spec[2]
		local reach = size * math.sqrt(3) / 2 -- centre to the top corner
		local yaw = CFrame.Angles(0, math.rad(rng:NextNumber(0, 90)), 0)
		local tip = at + v(0, size * rng:NextNumber(0.42, 0.55), 0) + side * spec[1]
		local body = Props.trim(parent, "Peak", Vector3.one * size, CFrame.new(tip - v(0, reach, 0)) * yaw * up, D.rock, "Rock")
		body.CastShadow = false
		local cap = Props.trim(parent, "PeakSnow", Vector3.one * size * 0.4, CFrame.new(tip + v(0, 0.6 - reach * 0.4, 0)) * yaw * up, D.snowShade, "Snow")
		cap.CastShadow = false
	end
end

-- The backdrop: cottages round the village ring, the fir forest, and the far peaks (always streamed
-- in, so the horizon is never empty).
function Village.backdrop(parent: Instance, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Backdrop"
	local houses = {}
	local V = L.village
	local bearings = { 30, 62, 95, 122, 150, 178, 205, 290, 322 }
	for k = 1, math.min(V.houses, #bearings) do
		local at = around(bearings[k] + rng:NextNumber(-6, 6), rng:NextNumber(V.ring[1], V.ring[2]), 0.6)
		table.insert(houses, at)
		villageHouse(model, CFrame.lookAt(at, v(0, at.Y, 0)) * CFrame.Angles(0, math.rad(rng:NextNumber(-12, 12)), 0), rng)
	end
	local F = L.forest
	local placed, tries = 0, 0
	while placed < F.trees and tries < F.trees * 20 do
		tries += 1
		local r = rng:NextNumber(F.ring[1], F.ring[2])
		local at = around(rng:NextNumber(0, 360), r, -0.3)
		local clear = not inGallery(at, 6) and not nearCottage(at, 8)
		for _, h in houses do
			if (h - at).Magnitude < 15 then
				clear = false
			end
		end
		if clear then
			placed += 1
			Props.fir(model, at, rng:NextNumber(0.9, 1.3) * (1 + (r - F.ring[1]) / F.ring[2] * 0.8), rng)
		end
	end
	model.Parent = parent
	local peaks = Instance.new("Model")
	peaks.Name = "Peaks"
	peaks.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local M = L.mountains
	for k = 1, M.count do
		peak(peaks, around(k / M.count * 360 + rng:NextNumber(-10, 10), rng:NextNumber(M.ring[1], M.ring[2]), -20), rng:NextNumber(150, 230), rng)
	end
	peaks.Parent = parent
end

return Village
