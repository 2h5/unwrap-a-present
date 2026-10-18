--[=[
	Props (shared, used by server builders)
	Owns: the world tier's construction kit (Table 11: smooth low-poly, stock materials, no studs):
	anchored parts, chunky layered trees, snowy firs, bushes, soft snow on tops, bows, lanterns,
	benches, low fences, the gift-tag sign that is the game's sign motif (a wooden tag with a notched
	point, a punched hole and twine), the Sway and Pulse marks the client animates, and applying a
	Config.Lighting entry. Lobby (Field and its builders) and Present (Room) build with it.
	Must never: hold game logic, touch the present tier's looks, or use a stud, bevel or dot surface.
	Read first: src/shared/README.md
]=]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)

local Props = {}

local D = Config.Lobby.dress

-- An anchored, smooth part. `color` is a hex string; `material` an Enum.Material name.
function Props.part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: string, material: string?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cframe
	p.Color = Color3.fromHex(color)
	p.Material = Enum.Material[material or "SmoothPlastic"]
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A decoration nobody stands on or taps: no collision, no raycasts.
function Props.trim(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: string, material: string?, shape: Enum.PartType?): Part
	local p = Props.part(parent, name, size, cframe, color, material, shape)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

function Props.wedge(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: string, material: string?): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = Color3.fromHex(color)
	p.Material = Enum.Material[material or "SmoothPlastic"]
	p.Parent = parent
	return p
end

-- A chunky tree: a trunk and three stacked, slightly turned blocks of leaves. `scale` 1 is about 14 tall.
function Props.tree(parent: Instance, base: Vector3, scale: number, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local trunkH = 5 * scale
	Props.part(model, "Trunk", Vector3.new(1.6, trunkH, 1.6) * Vector3.new(scale, 1, scale), CFrame.new(base + Vector3.yAxis * trunkH / 2), D.trunk, "Wood")
	local y = trunkH
	for tier = 1, 3 do
		local w = (7.5 - tier * 1.6) * scale
		local h = (3.6 - tier * 0.4) * scale
		local leaves = D.leaves[(tier + rng:NextInteger(0, 2)) % #D.leaves + 1]
		local cf = CFrame.new(base + Vector3.yAxis * (y + h / 2 - 0.4 * scale)) * CFrame.Angles(0, math.rad(rng:NextNumber(-25, 25)), 0)
		local block = Props.part(model, "Leaves", Vector3.new(w, h, w), cf, leaves, "Grass")
		block.CanCollide = tier == 1
		y += h * 0.78
	end
	model.Parent = parent
	return model
end

-- A low bush: two overlapping leaf blocks.
function Props.bush(parent: Instance, base: Vector3, scale: number, rng: Random)
	for k = 1, 2 do
		local w = (2.4 - k * 0.4) * scale
		local cf = CFrame.new(base + Vector3.new(k * 0.6 * scale, w / 2, -k * 0.3 * scale)) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 90)), 0)
		Props.trim(parent, "Bush", Vector3.one * w, cf, D.leaves[k], "Grass")
	end
end

-- A snowy fir: a trunk and four tiers of needles, each turned 45 degrees from the one below, every tier
-- carrying a little uneven snow. `scale` 1 is about 14 tall.
function Props.fir(parent: Instance, base: Vector3, scale: number, rng: Random): Model
	local model = Instance.new("Model")
	model.Name = "Fir"
	local trunkH = 3 * scale
	Props.part(model, "Trunk", Vector3.new(1.4, trunkH, 1.4) * Vector3.new(scale, 1, scale), CFrame.new(base + Vector3.yAxis * trunkH / 2), D.trunk, "Wood")
	local y = trunkH - 0.5 * scale
	for tier = 1, 4 do
		local w = (8.4 - tier * 1.7) * scale
		local h = 2.8 * scale
		local cf = CFrame.new(base + Vector3.yAxis * (y + h / 2)) * CFrame.Angles(0, math.rad(tier * 45 + rng:NextNumber(-8, 8)), 0)
		local block = Props.part(model, "Needles", Vector3.new(w, h, w), cf, D.fir[(tier + rng:NextInteger(0, 1)) % #D.fir + 1], "Grass")
		block.CanCollide = tier == 1
		local cover = rng:NextNumber(0.72, 0.95)
		local drift = CFrame.new(rng:NextNumber(-0.3, 0.3) * scale, h / 2 + 0.2 * scale, rng:NextNumber(-0.3, 0.3) * scale)
		Props.trim(model, "Snow", Vector3.new(w * cover, 0.45 * scale, w * cover), cf * drift, D.snow, "Snow")
		y += h * 0.72
	end
	Props.trim(model, "Tip", Vector3.new(1.3, 1.6, 1.3) * scale, CFrame.new(base + Vector3.yAxis * (y + 0.6 * scale)) * CFrame.Angles(0, math.rad(45), 0), D.snow, "Snow")
	model.Parent = parent
	return model
end

-- Snow lying on a flat top: a slab with a smaller, thicker mound on it, so it reads soft rather than as
-- a lid. `top` is the surface's centre (snow builds along its up); `cover` 0..1 of the top is covered.
function Props.snow(parent: Instance, top: CFrame, w: number, d: number, depth: number, cover: number?)
	local c = cover or 0.9
	Props.trim(parent, "Snow", Vector3.new(w * c, depth, d * c), top * CFrame.new(0, depth / 2, 0), D.snow, "Snow")
	Props.trim(parent, "Snow", Vector3.new(w * c * 0.66, depth * 0.9, d * c * 0.66), top * CFrame.new(w * 0.04, depth * 1.2, -d * 0.05), D.snow, "Snow")
end

-- A satin bow: two tipped loops, a knot and two tails, on top of a present at `top` (its centre).
function Props.bow(parent: Instance, top: CFrame, w: number, color: string)
	local reflect = Config.Palette.ribbon.reflectance
	for _, side in { -1, 1 } do
		local loop = top * CFrame.new(side * w * 0.38, w * 0.22, 0) * CFrame.Angles(0, 0, math.rad(side * 35))
		Props.trim(parent, "BowLoop", Vector3.new(w * 0.18, w * 0.5, w * 0.5), loop * CFrame.Angles(0, math.rad(90), 0), color, "SmoothPlastic", Enum.PartType.Cylinder).Reflectance = reflect
		Props.trim(parent, "BowTail", Vector3.new(w * 0.16, 0.12, w * 0.55), top * CFrame.new(side * w * 0.18, 0.06, w * 0.3) * CFrame.Angles(0, math.rad(side * 25), 0), color).Reflectance = reflect
	end
	Props.trim(parent, "BowKnot", Vector3.one * w * 0.26, top * CFrame.new(0, w * 0.12, 0), color, "SmoothPlastic", Enum.PartType.Ball).Reflectance = reflect
end

-- An ordinary wrapped present `s` studs on a side standing at `cf`: a box, two ribbon bands, a bow.
function Props.present(parent: Instance, cf: CFrame, s: number, color: string, ribbonColor: string)
	Props.trim(parent, "SmallPresent", Vector3.one * s, cf * CFrame.new(0, s / 2, 0), color)
	Props.trim(parent, "SmallRibbon", Vector3.new(s + 0.06, s + 0.06, s * 0.18), cf * CFrame.new(0, s / 2, 0), ribbonColor)
	Props.trim(parent, "SmallRibbon", Vector3.new(s * 0.18, s + 0.06, s + 0.06), cf * CFrame.new(0, s / 2, 0), ribbonColor)
	Props.bow(parent, cf * CFrame.new(0, s + 0.02, 0), s * 0.5, ribbonColor)
end

-- Marks `model` to swing on this client (Shelf/Ambience): around `axis` through `hinge`, by `degrees`
-- either way. Atomic, so the model streams in whole.
function Props.sway(model: Model, hinge: Vector3, axis: Vector3, degrees: number)
	model:SetAttribute("SwayHinge", hinge)
	model:SetAttribute("SwayAxis", axis.Unit)
	model:SetAttribute("SwayDegrees", degrees)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	CollectionService:AddTag(model, "Sway")
end

-- Marks a glowing part (and any light in it) to breathe on this client between two transparencies.
function Props.pulse(part: BasePart, low: number, high: number)
	part:SetAttribute("PulseLow", low)
	part:SetAttribute("PulseHigh", high)
	CollectionService:AddTag(part, "Pulse")
end

-- A lantern on a post: a warm glow at the edge of a path. `lit` adds a PointLight; most lanterns only
-- glow, so the lights stay few.
function Props.lantern(parent: Instance, base: Vector3, height: number?, lit: boolean?)
	local h = height or 6
	Props.part(parent, "LanternPost", Vector3.new(0.6, h, 0.6), CFrame.new(base + Vector3.yAxis * h / 2), D.woodDark, "Wood")
	Props.trim(parent, "LanternArm", Vector3.new(1.4, 0.3, 0.3), CFrame.new(base + Vector3.new(0.5, h - 0.2, 0)), D.woodDark, "Wood")
	local lamp = Props.trim(parent, "Lantern", Vector3.new(0.8, 1, 0.8), CFrame.new(base + Vector3.new(1, h - 0.9, 0)), D.lantern, "Neon")
	Props.trim(parent, "LanternCap", Vector3.new(1, 0.25, 1), CFrame.new(base + Vector3.new(1, h - 0.3, 0)), D.woodDark, "Wood")
	Props.trim(parent, "Snow", Vector3.new(0.9, 0.2, 0.9), CFrame.new(base + Vector3.new(1, h - 0.08, 0)), D.snow, "Snow")
	if lit ~= false then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromHex(D.lantern)
		light.Range = 14
		light.Brightness = 0.8
		light.Parent = lamp
	end
end

-- A hanging lantern on a short chain under `at` (the point it hangs from).
function Props.hangingLantern(parent: Instance, at: Vector3, lit: boolean)
	Props.trim(parent, "Chain", Vector3.new(0.12, 1.2, 0.12), CFrame.new(at - Vector3.yAxis * 0.6), D.woodDark, "Metal")
	Props.trim(parent, "LanternCap", Vector3.new(1, 0.3, 1), CFrame.new(at - Vector3.yAxis * 1.3), D.woodDark, "Wood")
	local lamp = Props.trim(parent, "Lantern", Vector3.new(0.8, 1.1, 0.8), CFrame.new(at - Vector3.yAxis * 2), D.lantern, "Neon")
	if lit then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromHex(D.lantern)
		light.Range = 16
		light.Brightness = 0.9
		light.Parent = lamp
	end
end

-- A wooden bench facing along `cf`'s front (-Z), its seat at `cf`'s height, a little snow on one end.
function Props.bench(parent: Instance, cf: CFrame)
	Props.part(parent, "Seat", Vector3.new(6, 0.4, 1.8), cf * CFrame.new(0, 1.8, 0), D.plank, "WoodPlanks")
	Props.trim(parent, "Back", Vector3.new(6, 1.4, 0.3), cf * CFrame.new(0, 3, 0.85) * CFrame.Angles(math.rad(-10), 0, 0), D.plank, "WoodPlanks")
	for _, x in { -2.4, 2.4 } do
		Props.part(parent, "BenchLeg", Vector3.new(0.5, 1.6, 1.6), cf * CFrame.new(x, 0.8, 0), D.woodDark, "Wood")
	end
	Props.trim(parent, "Snow", Vector3.new(2.2, 0.25, 1.5), cf * CFrame.new(1.6, 2.1, 0.05), D.snow, "Snow")
end

-- A low two-rail fence from `a` to `b` on the ground.
function Props.fence(parent: Instance, a: Vector3, b: Vector3, spacing: number)
	local span = b - a
	local length = span.Magnitude
	if length < 1 then
		return
	end
	local dir = span.Unit
	local posts = math.max(1, math.floor(length / spacing))
	for k = 0, posts do
		local p = a + dir * (length * k / posts)
		Props.part(parent, "FencePost", Vector3.new(0.8, 3.2, 0.8), CFrame.new(p + Vector3.yAxis * 1.6), D.wood, "Wood")
	end
	for _, y in { 1.2, 2.4 } do
		local mid = (a + b) / 2 + Vector3.yAxis * y
		Props.part(parent, "FenceRail", Vector3.new(0.35, 0.5, length), CFrame.lookAt(mid, mid + dir), D.plank, "WoodPlanks")
	end
end

-- The gift-tag sign: a wooden tag `width` by `height`, its notched point on the left, a punched hole
-- and twine. `cframe` is the tag's centre, front (-Z) toward the reader. Returns the tag board and its
-- title and subtitle labels (live text).
function Props.tag(parent: Instance, cframe: CFrame, width: number, height: number, title: string, subtitle: string?): (Part, TextLabel, TextLabel?)
	local thick = 0.5
	local board = Props.part(parent, "Tag", Vector3.new(width, height, thick), cframe, D.sign, "WoodPlanks")
	-- The notched point: two wedges meeting in a point on the left.
	local pointW = height * 0.45
	for _, side in { -1, 1 } do
		local cf = cframe * CFrame.new(-width / 2 - pointW / 2, side * height / 4, 0) * CFrame.Angles(0, math.rad(90), if side > 0 then 0 else math.pi)
		local w = Props.wedge(parent, "TagPoint", Vector3.new(thick, height / 2, pointW), cf, D.sign, "WoodPlanks")
		w.CanCollide = false
	end
	-- The punched hole with its twine running up and out of view.
	local hole = cframe * CFrame.new(-width / 2 - pointW * 0.15, 0, 0)
	Props.trim(parent, "TagHole", Vector3.new(thick * 1.1, height * 0.16, height * 0.16), hole * CFrame.Angles(0, math.rad(90), 0), D.woodDark, "SmoothPlastic", Enum.PartType.Cylinder)
	-- A thin frame round the board's face, in the darker wood.
	Props.trim(parent, "TagEdge", Vector3.new(width + 0.3, height + 0.3, thick * 0.6), cframe * CFrame.new(0, 0, thick * 0.3), D.woodDark, "Wood")

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Text"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.6
	gui.MaxDistance = 220
	local function line(text: string, y: number, h: number): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.fromScale(0.5, y)
		l.Size = UDim2.fromScale(0.92, h)
		l.Text = text
		l.TextScaled = true
		l.Font = Enum.Font[Config.UI.font]
		l.TextColor3 = Color3.fromHex(D.ink)
		l.Parent = gui
		return l
	end
	local titleLabel = line(title, if subtitle then 0.08 else 0.18, if subtitle then 0.56 else 0.64)
	local subtitleLabel = if subtitle then line(subtitle, 0.66, 0.26) else nil
	gui.Parent = board
	return board, titleLabel, subtitleLabel
end

-- Twine from `a` to `b`: a thin cream cord.
function Props.twine(parent: Instance, a: Vector3, b: Vector3)
	local span = b - a
	local up = if math.abs(span.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis -- a hanging cord is vertical
	Props.trim(parent, "Twine", Vector3.new(0.12, 0.12, span.Magnitude), CFrame.lookAt((a + b) / 2, b, up), Config.UI.twine, "Fabric")
end

-- Applies a Config.Lighting entry ("Lobby" or "Run") to the Lighting service.
function Props.applyLighting(name: string)
	local spec = Config.Lighting[name]
	Lighting.ClockTime = spec.clockTime
	Lighting.Brightness = spec.brightness
	Lighting.Ambient = Color3.fromHex(spec.ambient)
	Lighting.OutdoorAmbient = Color3.fromHex(spec.outdoorAmbient)
	Lighting.ColorShift_Top = Color3.fromHex(spec.colorShiftTop)
	Lighting.GlobalShadows = true
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = spec.atmosphere.density
	atmosphere.Haze = spec.atmosphere.haze
	atmosphere.Color = Color3.fromHex(spec.atmosphere.color)
	atmosphere.Decay = Color3.fromHex(spec.atmosphere.decay)
	atmosphere.Parent = Lighting
	-- Optional extras (the lobby's dusk): a cool bottom colour shift, sun glare, soft bloom, clouds.
	if spec.colorShiftBottom then
		Lighting.ColorShift_Bottom = Color3.fromHex(spec.colorShiftBottom)
	end
	if spec.atmosphere.glare then
		atmosphere.Glare = spec.atmosphere.glare
	end
	if spec.bloom then
		local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
		bloom.Intensity = spec.bloom.intensity
		bloom.Size = spec.bloom.size
		bloom.Threshold = spec.bloom.threshold
		bloom.Parent = Lighting
	end
	if spec.clouds then
		local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
		clouds.Cover = spec.clouds.cover
		clouds.Density = spec.clouds.density
		clouds.Color = Color3.fromHex(spec.clouds.color)
		clouds.Parent = workspace.Terrain
	end
end

-- Removes Roblox's template baseplate (its grid texture is a stud pattern, invariant 4) and spawn.
function Props.clearTemplate()
	for _, name in { "Baseplate", "SpawnLocation" } do
		local template = workspace:FindFirstChild(name)
		if template and template:IsA("BasePart") then
			template:Destroy()
		end
	end
end

return Props
