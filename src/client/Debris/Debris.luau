--[=[
	Debris (client system)
	Owns: Torn-panel pool, 40 live max, physics, recycle.
	Must never: Exceed the budget (Config.Tear.maxLiveDebris). Pieces are local to this client.
	On a tear: swaps the panel for a torn-edge piece (ReplicatedStorage.Assets.TornPanel if it
	exists, else a part in the panel's color and pattern), pushes it away from the present, flutters it,
	then it settles and stays until the pool recycles it, oldest first; six paper flecks fly off and a
	soft thud plays on first landing. A cleared layer throws a ring of confetti in its colour with a light
	pulse (Table 14). PaperLook draws the paper patterns, prints and bows.
	Slot logic is pure and tested: DebrisPool.luau.
	Read first: src/client/Debris/README.md
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Art = require(ReplicatedStorage.Shared.Art.Art)
local Patterns = require(ReplicatedStorage.Shared.Art.Patterns)
local DebrisPool = require(script.Parent.DebrisPool)
local PaperLook = require(script.Parent.PaperLook)
local Sfx = require(ReplicatedStorage.Shared.Sfx.Sfx)

type Piece = { part: BasePart, lift: VectorForce, token: number, landed: boolean }

local Debris = {}

local pool = DebrisPool.new(Config.Tear.maxLiveDebris)
local pieces: { [number]: Piece } = {}
local folder: Folder
local rng = Random.new()
local flecks: ParticleEmitter
local confetti: ParticleEmitter
local pulse: PointLight

local function template(): BasePart
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local torn = assets and assets:FindFirstChild("TornPanel")
	if torn and torn:IsA("BasePart") then
		return torn:Clone()
	end
	return Instance.new("Part")
end

local function newPiece(): Piece
	local part = template()
	part.Name = "TornPanel"
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	local attachment = Instance.new("Attachment")
	attachment.Parent = part
	local lift = Instance.new("VectorForce")
	lift.Attachment0 = attachment
	lift.RelativeTo = Enum.ActuatorRelativeTo.World
	lift.ApplyAtCenterOfMass = true
	lift.Enabled = false
	lift.Parent = part
	local piece: Piece = { part = part, lift = lift, token = 0, landed = true }
	-- First contact with anything but the present or a player (other debris counts): one soft thud.
	part.Touched:Connect(function(other)
		if piece.landed then
			return
		end
		local present = workspace:FindFirstChild("Present")
		if present and other:IsDescendantOf(present) then
			return
		end
		local model = other:FindFirstAncestorWhichIsA("Model")
		if model and model:FindFirstChildOfClass("Humanoid") then
			return -- a player, including their accessories
		end
		piece.landed = true
		Sfx.playAt(Config.Sounds.paperLand, part.Position)
	end)
	return piece
end

local function spin(): number
	return rng:NextNumber(-Config.Tear.debrisSpinMax, Config.Tear.debrisSpinMax)
end

-- One emitter part, moved to each event: particles live in world space, so one emitter serves all.
local function emitterPart(name: string): (Part, ParticleEmitter)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Parent = folder
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = Art.particles.fleck
	emitter.Rate = 0
	emitter.Enabled = true
	emitter.LightInfluence = 1
	emitter.Parent = part
	return part, emitter
end

local function fleck(panel: BasePart)
	local part = flecks.Parent :: BasePart
	part.Size = panel.Size
	part.CFrame = panel.CFrame
	flecks.Color = ColorSequence.new(panel.Color)
	flecks:Emit(Config.Vfx.tearFlecks)
end

-- Swaps a torn panel for a debris piece. `panel` is the panel part; its front (-Z) faces out.
function Debris.spawn(panel: BasePart)
	local id = DebrisPool.acquire(pool)
	local piece = pieces[id]
	if not piece then
		piece = newPiece()
		pieces[id] = piece
	end
	piece.token += 1
	local token = piece.token
	local part = piece.part

	part.Anchored = true
	part.Size = panel.Size
	part.CFrame = panel.CFrame
	part.Color = panel.Color -- torn paper is the same paper
	part.Material = panel.Material
	part.Reflectance = panel.Reflectance
	part.CanCollide = true
	part.CanTouch = true
	part.Transparency = if panel:GetAttribute("Kind") == "Tape" then Config.Palette.tape.transparency else 0
	Patterns.copy(panel, part)
	piece.landed = false
	part.Parent = folder
	part.Anchored = false
	fleck(panel)

	part.AssemblyLinearVelocity = panel.CFrame.LookVector * Config.Tear.debrisImpulse
	part.AssemblyAngularVelocity = Vector3.new(spin(), spin(), spin())
	piece.lift.Force = Vector3.yAxis * part.AssemblyMass * workspace.Gravity * (1 - Config.Tear.debrisFallScale)
	piece.lift.Enabled = true

	task.delay(Config.Tear.flutterSeconds, function()
		if piece.token ~= token then
			return -- recycled while it was still fluttering
		end
		piece.lift.Enabled = false
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		piece.landed = true
	end)
end

function Debris.liveCount(): number
	return DebrisPool.liveCount(pool)
end

-- A ring of confetti in the cleared layer's colour, and a light pulse (Table 14: 40 particles, 0.6 s).
local function layerCleared(present: Instance, depth: number)
	local layer
	for _, child in present:GetChildren() do
		if child:GetAttribute("Depth") == depth then
			layer = child
		end
	end
	if not layer then
		return
	end
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in layer:GetDescendants() do
		if part:IsA("BasePart") then
			lo, hi = lo:Min(part.Position), hi:Max(part.Position)
		end
	end
	if lo.X == math.huge then
		return
	end
	local colors = string.split(present:GetAttribute("LayerColors") or "", ",")
	local hex = colors[depth + 1]
	local color = if hex and hex ~= "" then Color3.fromHex(hex) else Color3.fromHex(Config.Palette.cardboard)
	local light = Patterns.steps(color)
	local size = math.max(hi.X - lo.X, hi.Z - lo.Z, 1)
	local part = confetti.Parent :: BasePart
	part.Size = Vector3.new(size, 0.2, size)
	part.CFrame = CFrame.new((lo + hi) / 2)
	confetti.Color = ColorSequence.new(color, light)
	confetti:Emit(Config.Vfx.clearConfetti)
	pulse.Color = light
	pulse.Range = size * 1.5
	pulse.Brightness = Config.Vfx.clearLightBrightness
	TweenService:Create(pulse, TweenInfo.new(Config.Vfx.clearSeconds), { Brightness = 0 }):Play()
end

local function watchPresent(present: Instance)
	local last = present:GetAttribute("CurrentDepth") or 0
	present:GetAttributeChangedSignal("CurrentDepth"):Connect(function()
		local now = present:GetAttribute("CurrentDepth") or 0
		if now > last then
			layerCleared(present, now - 1)
		end
		last = now
	end)
end

function Debris.init()
	folder = Instance.new("Folder")
	folder.Name = "Debris"
	folder.Parent = workspace

	local _, f = emitterPart("Flecks")
	f.EmissionDirection = Enum.NormalId.Front
	f.Shape = Enum.ParticleEmitterShape.Box
	f.Size = NumberSequence.new(0.35, 0.2)
	f.Lifetime = NumberRange.new(0.7, 1.1)
	f.Speed = NumberRange.new(5, 9)
	f.SpreadAngle = Vector2.new(50, 50)
	f.Acceleration = Vector3.new(0, -18, 0)
	f.Drag = 2
	f.Rotation = NumberRange.new(0, 360)
	f.RotSpeed = NumberRange.new(-200, 200)
	flecks = f

	local confettiPart, c = emitterPart("Confetti")
	c.EmissionDirection = Enum.NormalId.Top
	c.Shape = Enum.ParticleEmitterShape.Disc
	c.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	c.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	c.Size = NumberSequence.new(0.4, 0.25)
	c.Lifetime = NumberRange.new(0.6, 1.2)
	c.Speed = NumberRange.new(8, 14)
	c.SpreadAngle = Vector2.new(25, 25)
	c.Acceleration = Vector3.new(0, -24, 0)
	c.Drag = 1.5
	c.Rotation = NumberRange.new(0, 360)
	c.RotSpeed = NumberRange.new(-300, 300)
	confetti = c
	pulse = Instance.new("PointLight")
	pulse.Brightness = 0
	pulse.Shadows = false
	pulse.Parent = confettiPart

	PaperLook.init()
	local present = workspace:FindFirstChild("Present")
	if present then
		watchPresent(present)
	end
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "Present" then
			watchPresent(child)
		end
	end)
end

return Debris
