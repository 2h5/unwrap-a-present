--[=[
	Landmark (server, part of Lobby)
	Owns: building the plaza's signature landmark north of the pads: an oversized present half
	unwrapped on a round stone terrace. Teal plaid paper (drawn on the client from `Pattern`) torn away
	at one top corner to show the printed cardboard, a peeled panel and curled strips, the front ribbon
	snipped and trailing, the lid lifted on its back edge under a big gold bow, a warm glow inside, the
	"Start a Run" gift tag hung on its front, ordinary presents at its feet for scale, scraps around.
	Must never: hold logic or give anything; it is decoration (no prompt, no reward). Stock materials
	only, no stud or dot surface (invariant 4).
	Read first: src/server/Lobby/README.md
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Art = require(ReplicatedStorage.Shared.Art.Art)
local Config = require(ReplicatedStorage.Shared.Config.Config)
local Props = require(ReplicatedStorage.Shared.Art.Props)

local Landmark = {}

local L = Config.Lobby
local M = L.landmark
local D = L.dress
local PAL = Config.Palette
local PATTERN = Config.PaperLook.patterns[M.paper]

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function ribbon(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local p = Props.trim(parent, name, size, cf, PAL.ribbon.color)
	p.Reflectance = PAL.ribbon.reflectance
	return p
end

local function paper(parent: Instance, name: string, size: Vector3, cf: CFrame, repeats: number): Part
	local p = Props.part(parent, name, size, cf, PAL.paper[M.paper])
	p:SetAttribute("Pattern", PATTERN)
	p:SetAttribute("PatternRepeats", repeats)
	return p
end

-- A strip of paper curling as it goes: `count` segments from `start`, each bent `bend` degrees further
-- (along the start's -Z). Returns the end frame.
local function curl(parent: Instance, start: CFrame, count: number, length: number, width: number, bend: number): CFrame
	local cf = start
	for k = 1, count do
		Props.trim(parent, "Curl", v(width, 0.2, length), cf * CFrame.new(0, 0, -length / 2), if k % 2 == 0 then PAL.paper[M.paper] else D.cream, "SmoothPlastic")
		cf = cf * CFrame.new(0, 0, -length) * CFrame.Angles(math.rad(bend), 0, 0)
	end
	return cf
end

-- Builds the landmark under `parent`.
function Landmark.build(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "GiantPresent"
	local cx, cz = M.center[1], M.center[2]
	local R, H, S = M.terraceRadius, M.terraceStuds, M.presentStuds
	local flat = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder's axis upright

	-- The round terrace: a stone drum, a coping lip, a paved top, two broad steps toward the pads.
	Props.part(model, "Terrace", v(H + 0.5, 2 * R, 2 * R), CFrame.new(cx, (H - 0.5) / 2, cz) * flat, D.stoneDark, "Slate")
	Props.part(model, "TerraceCoping", v(0.5, 2 * R + 0.8, 2 * R + 0.8), CFrame.new(cx, H - 0.15, cz) * flat, D.stone, "Slate")
	Props.part(model, "TerraceTop", v(0.2, 2 * R - 1, 2 * R - 1), CFrame.new(cx, H + 0.1, cz) * flat, D.paving, "Pavement")
	local front = cz + R -- the terrace's south edge
	for k, spec in { { H * 2 / 3, 4 }, { H / 3, 3 } } do
		local top, depth = spec[1], spec[2]
		local z = front - 2 + (k - 1) * 3.5 + depth / 2 - 1
		Props.part(model, "Step", v(16, top + 0.5, depth), CFrame.new(cx, (top - 0.5) / 2, z), D.stone, "Slate")
	end

	-- The present's own frame: on the terrace, a little north of centre, turned a touch toward the east.
	local base = CFrame.new(cx, H + 0.2, cz - 2) * CFrame.Angles(0, math.rad(M.yawDeg), 0)
	local p = S / 3 -- one paper panel
	local rimTop = S - 2.2

	-- Cardboard inside, a rim round the open top, and the warm glow inside it.
	Props.part(model, "Box", v(S - 0.6, rimTop, S - 0.6), base * CFrame.new(0, rimTop / 2, 0), PAL.cardboard, "Cardboard")
	for _, side in { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } } do
		local size = if side[1] == 0 then v(S - 0.6, 2.2, 0.4) else v(0.4, 2.2, S - 0.6)
		Props.part(model, "BoxRim", size, base * CFrame.new(side[1] * (S / 2 - 0.5), rimTop + 1.1, side[2] * (S / 2 - 0.5)), PAL.cardboard, "Cardboard")
	end
	local glow = Props.trim(model, "Glow", v(S - 1.6, 0.2, S - 1.6), base * CFrame.new(0, rimTop + 0.1, 0), D.glow, "Neon")
	glow.Transparency = 0.15
	glow.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex(D.glow)
	light.Range = M.glowRange
	light.Brightness = M.glowBrightness
	light.Shadows = false
	light.Parent = glow
	Props.pulse(glow, 0.1, 0.35)
	local motes = Instance.new("ParticleEmitter") -- a few warm motes rising out of the gap; not confetti
	motes.Texture = Art.particles.sparkle
	motes.Color = ColorSequence.new(Color3.fromHex(D.glow))
	motes.LightEmission = 1
	motes.Rate = 3
	motes.Lifetime = NumberRange.new(3, 4)
	motes.Speed = NumberRange.new(1.5, 3)
	motes.SpreadAngle = Vector2.new(25, 25)
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	motes.EmissionDirection = Enum.NormalId.Top
	motes.Parent = glow

	-- Paper, 3 by 3 on each side. Torn away at the front's top right and the east face's top front;
	-- one front panel and one east panel peel open on their outer edges.
	local faces = {
		{ n = v(0, 0, 1), missing = { ["3,2"] = true, ["3,3"] = true, ["2,3"] = true }, peel = "3,1" },
		{ n = v(1, 0, 0), missing = { ["3,1"] = true, ["2,1"] = true }, peel = "3,2" },
		{ n = v(0, 0, -1), missing = {} },
		{ n = v(-1, 0, 0), missing = {} },
	}
	for _, face in faces do
		local right = Vector3.yAxis:Cross(face.n)
		for row = 1, 3 do
			for col = 1, 3 do
				local key = `{row},{col}`
				local c = face.n * (S / 2 + 0.15) + right * ((col - 2) * p) + Vector3.yAxis * ((row - 0.5) * p)
				local cf = base * CFrame.lookAt(c, c + face.n)
				if face.peel == key then
					-- Hinged on its outer vertical edge (away from the tear), swung 55 degrees open.
					local edge = if col == 1 then -1 else 1
					local hinge = cf * CFrame.new(-edge * p / 2, 0, 0)
					paper(model, "PeelPanel", v(p - 0.1, p - 0.1, 0.3), hinge * CFrame.Angles(0, math.rad(edge * 55), 0) * CFrame.new(edge * p / 2, 0, 0), 2)
				elseif not face.missing[key] then
					paper(model, "Paper", v(p - 0.1, p - 0.1, 0.3), cf, 2)
				end
			end
		end
	end
	-- The printed cardboard showing through the tear (arrows and a barcode, drawn on the client).
	local hole = v(p / 2, S - p, S / 2 - 0.25)
	Props.trim(model, "Print", v(2 * p - 0.4, 2 * p - 0.4, 0.2), base * CFrame.lookAt(hole, hole + Vector3.zAxis), PAL.cardboard, "Cardboard"):SetAttribute("Print", true)
	-- Ragged paper teeth on the torn edges: along the top of the panels left below the tear, and up the
	-- side of the one left beside it. Each is a thin wedge in the face's plane.
	local rng = Random.new(31)
	local teeth = { { -p * 0.3, 2 * p, 0 }, { 0, 2 * p, 0 }, { p * 0.3, 2 * p, 0 }, { p * 0.75, p, 0 }, { p * 1.15, p, 0 }, { p / 2, p * 1.3, -90 }, { p / 2, p * 1.7, -90 } }
	for _, t in teeth do
		local at = v(t[1], t[2], S / 2 + 0.2)
		local frame = base * CFrame.lookAt(at, at + Vector3.zAxis) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(math.rad(t[3] + rng:NextNumber(-15, 15)), 0, 0)
		local tooth = Props.wedge(model, "Tooth", v(0.25, rng:NextNumber(0.6, 1.1), rng:NextNumber(0.7, 1.3)), frame * CFrame.new(0, 0.4, 0), PAL.paper[M.paper])
		tooth.CanCollide = false
	end

	-- Ribbon bands down the back and both sides; the front band is snipped and trails onto the terrace.
	local band = S * 0.12
	ribbon(model, "Ribbon", v(band, S, 0.3), base * CFrame.new(0, S / 2, -S / 2 - 0.35))
	ribbon(model, "Ribbon", v(0.3, S, band), base * CFrame.new(-S / 2 - 0.35, S / 2, 0))
	ribbon(model, "Ribbon", v(0.3, S, band), base * CFrame.new(S / 2 + 0.35, S / 2, 0))
	ribbon(model, "Ribbon", v(band, p, 0.3), base * CFrame.new(0, p / 2, S / 2 + 0.35))
	local tail = Instance.new("Model")
	tail.Name = "RibbonTail"
	local tailStart = base * CFrame.new(0, p, S / 2 + 0.4) * CFrame.Angles(math.rad(-100), 0, 0) -- down, a little out
	local cf = tailStart
	for _ = 1, 6 do
		ribbon(tail, "RibbonTail", v(band, 0.2, 1.7), cf * CFrame.new(0, 0, -0.85))
		cf = cf * CFrame.new(0, 0, -1.7) * CFrame.Angles(math.rad(-14), 0, 0) -- easing out onto the terrace
	end
	tail.Parent = model
	Props.sway(tail, tailStart.Position, base.RightVector, 3)

	-- The lid, hinged on its back top edge and lifted at the front so the glow shows from the plaza.
	local lw = S + 1.2
	local lid = base * CFrame.new(0, S, -lw / 2) * CFrame.Angles(math.rad(-M.lidLiftDeg), 0, 0) * CFrame.new(0, 1.2, lw / 2)
	Props.part(model, "Lid", v(lw - 0.4, 2.2, lw - 0.4), lid, PAL.cardboard, "Cardboard")
	for _, n in { v(0, 0, 1), v(0, 0, -1), v(1, 0, 0), v(-1, 0, 0) } do
		local c = n * (lw / 2 + 0.15)
		local size = v(lw, 2.4, 0.3)
		paper(model, "LidPaper", size, lid * CFrame.lookAt(c, c + n), 1)
	end
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			paper(model, "LidPaper", v(lw / 2 - 0.1, lw / 2 - 0.1, 0.3), lid * CFrame.new(x * lw / 4, 1.35, z * lw / 4) * CFrame.Angles(math.rad(90), 0, 0), 2)
		end
	end
	ribbon(model, "LidRibbon", v(band, 0.3, lw + 0.4), lid * CFrame.new(0, 1.55, 0))
	ribbon(model, "LidRibbon", v(lw + 0.4, 0.3, band), lid * CFrame.new(0, 1.55, 0))
	for _, n in { v(0, 0, 1), v(0, 0, -1), v(1, 0, 0), v(-1, 0, 0) } do
		local size = if n.Z ~= 0 then v(band, 2.6, 0.3) else v(0.3, 2.6, band)
		ribbon(model, "LidRibbon", size, lid * CFrame.new(n * (lw / 2 + 0.35)))
	end
	Props.bow(model, lid * CFrame.new(0, 1.7, 0), S * 0.55, PAL.ribbon.color)
	Props.snow(model, lid * CFrame.new(-lw * 0.3, 1.7, -lw * 0.28), 5, 4, 0.5, 0.9)

	-- Curled paper: one strip off the torn corner, one off the east tear, one peeled sheet on the terrace.
	curl(model, base * CFrame.new(S / 2 - 1.2, S - 0.6, S / 2 + 0.4) * CFrame.Angles(math.rad(-114), 0, 0), 6, 1.6, 2.2, -22)
	curl(model, base * CFrame.new(S / 2 + 0.4, S - p - 0.4, S / 2 - p) * CFrame.Angles(0, math.rad(-90), 0) * CFrame.Angles(math.rad(-114), 0, 0), 5, 1.6, 1.8, -26)
	curl(model, base * CFrame.new(S / 2 + 2.5, 0.12, -3) * CFrame.Angles(0, math.rad(180), 0), 7, 1.7, 3.2, 14)

	-- "Start a Run": the big gift tag hung on twine from the rim, over the front face, swaying gently.
	local tagModel = Instance.new("Model")
	tagModel.Name = "StartTag"
	local tagAt = base * CFrame.new(-1, p + 3.3, S / 2 + 0.9)
	Props.tag(tagModel, CFrame.lookAt(tagAt.Position, tagAt.Position + tagAt.LookVector * -1), 13, 4.4, "Start a Run", "Stand on a pad, then tap Start")
	for _, x in { -4.5, 4.5 } do
		local top = base * CFrame.new(x - 1, S, S / 2 + 0.45)
		local knot = tagAt * CFrame.new(x, 2.2, 0)
		Props.twine(tagModel, top.Position, knot.Position)
	end
	for _, part in tagModel:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
	tagModel.Parent = model
	Props.sway(tagModel, (base * CFrame.new(0, S, S / 2 + 0.6)).Position, base.RightVector, 1.5)

	-- Ordinary presents at its feet: the giant reads as giant.
	local gold, crimson = PAL.ribbon.colors[1], PAL.ribbon.colors[2]
	local feet = {
		{ -S / 2 - 2.4, S / 2 - 2, 2.6, 1, gold },
		{ -S / 2 + 0.5, S / 2 + 2.2, 1.8, 3, gold },
		{ -S / 2 - 4.2, S / 2 - 4.5, 1.4, 4, crimson },
		{ S / 2 + 2.6, -S / 2 + 3, 2.2, 5, gold },
	}
	for k, f in feet do
		Props.present(model, base * CFrame.new(f[1], 0, f[2]) * CFrame.Angles(0, math.rad(k * 23), 0), f[3], PAL.paper[f[4]], f[5])
	end

	-- Scraps of torn paper and a cut strip of tape on the terrace's top.
	local placed = 0
	while placed < 8 do
		local x, z = rng:NextNumber(-S / 2, S / 2 + 4), S / 2 + rng:NextNumber(1, 6)
		if Vector2.new(x, z + 2).Magnitude > R - 2 then
			continue -- the present stands 2 studs north of the terrace's centre
		end
		placed += 1
		local spot = base * CFrame.new(x, 0.12, z)
		local scrap = Props.trim(model, "Scrap", v(rng:NextNumber(1.2, 2.4), rng:NextNumber(1.2, 2), 0.15), spot * CFrame.Angles(math.rad(-90 + rng:NextNumber(-8, 8)), math.rad(rng:NextNumber(0, 360)), 0), PAL.paper[M.paper])
		scrap:SetAttribute("Pattern", PATTERN)
		scrap:SetAttribute("PatternRepeats", 1)
	end
	local tape = Props.trim(model, "Tape", v(0.9, 0.08, 3.4), base * CFrame.new(-S / 2 + 2, 0.1, S / 2 + 3) * CFrame.Angles(0, math.rad(35), 0), PAL.tape.color, PAL.tape.material)
	tape.Transparency = PAL.tape.transparency

	model.Parent = parent
end

return Landmark
