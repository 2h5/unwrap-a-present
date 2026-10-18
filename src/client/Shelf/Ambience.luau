--[=[
	Ambience (client, part of Shelf)
	Owns: the lobby's ambient motion on this client: gentle snowfall from one emitter that follows the
	camera, a few paper scraps drifting down now and then, the tags, bunting and ribbon the server marks
	`Sway`, and the glows it marks `Pulse` (the pads' rims, the landmark's light). Lobby place only.
	Must never: move a part anything stands on or taps (only decorations carry the marks), add a light,
	run more than one emitter, or run in the run place.
	Read first: src/client/Shelf/README.md
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Art = require(ReplicatedStorage.Shared.Art.Art)
local Config = require(ReplicatedStorage.Shared.Config.Config)

local Ambience = {}

local A = Config.Lobby.ambience
local TAU = 2 * math.pi

type Swing = { parts: { BasePart }, rel: { CFrame }, hinge: CFrame, axis: Vector3, amp: number, phase: number }
type Glow = { low: number, high: number, light: Light?, brightness: number, phase: number }
type Scrap = { part: BasePart, from: Vector3, ground: number, start: number, yaw: number, phase: number }

local swinging: { [Instance]: Swing } = {}
local glowing: { [Instance]: Glow } = {}
local scraps: { Scrap } = {}
local rng = Random.new()
local folder: Folder? = nil
local snowfall: BasePart? = nil
local nextScrap = 0

---------------------------------------------------------------- sway and pulse

local function addSwing(model: Instance)
	if not model:IsA("Model") or swinging[model] then
		return
	end
	local hinge, axis, degrees = model:GetAttribute("SwayHinge"), model:GetAttribute("SwayAxis"), model:GetAttribute("SwayDegrees")
	if typeof(hinge) ~= "Vector3" or typeof(axis) ~= "Vector3" or typeof(degrees) ~= "number" then
		return
	end
	local at = CFrame.new(hinge)
	local parts, rel = {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(rel, at:ToObjectSpace(d.CFrame))
		end
	end
	swinging[model] = { parts = parts, rel = rel, hinge = at, axis = axis, amp = math.rad(degrees), phase = (hinge.X * 0.37 + hinge.Z * 0.23) % TAU }
end

local function addGlow(part: Instance)
	if not part:IsA("BasePart") or glowing[part] then
		return
	end
	local light = part:FindFirstChildWhichIsA("Light")
	glowing[part] = {
		low = part:GetAttribute("PulseLow") or part.Transparency,
		high = part:GetAttribute("PulseHigh") or part.Transparency,
		light = light,
		brightness = if light then light.Brightness else 0,
		phase = (part.Position.X * 0.11 + part.Position.Z * 0.07) % TAU,
	}
end

local function watch(tag: string, add: (Instance) -> (), list: { [Instance]: any })
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(object)
		list[object] = nil
	end)
	for _, object in CollectionService:GetTagged(tag) do
		add(object)
	end
end

---------------------------------------------------------------- snow and paper

-- One emitter above the camera, moved with it every frame: snow wherever the player looks.
local function makeSnowfall(parent: Instance): BasePart
	local box = Instance.new("Part")
	box.Name = "Snowfall"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.Transparency = 1
	box.Size = Vector3.new(A.snowBoxStuds, 1, A.snowBoxStuds)
	local flakes = Instance.new("ParticleEmitter")
	flakes.Texture = Art.particles.snow
	flakes.Color = ColorSequence.new(Color3.fromHex(Config.Lobby.dress.snow))
	flakes.LightEmission = 0.3
	flakes.LightInfluence = 0.7
	flakes.Rate = A.snowRate
	flakes.Lifetime = NumberRange.new(A.snowLifetime[1], A.snowLifetime[2])
	flakes.Speed = NumberRange.new(A.snowSpeed[1], A.snowSpeed[2])
	flakes.SpreadAngle = Vector2.new(15, 15)
	flakes.Acceleration = Vector3.new(0.6, 0, 0.3)
	flakes.RotSpeed = NumberRange.new(-40, 40)
	flakes.Size = NumberSequence.new(A.snowSize)
	flakes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.15),
		NumberSequenceKeypoint.new(0.85, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	flakes.EmissionDirection = Enum.NormalId.Bottom
	flakes.Parent = box
	box.Parent = parent
	return box
end

-- A paper scrap in one of the launch papers, its pattern drawn by Debris/PaperLook like any paper.
local function newScrap(parent: Instance): BasePart
	local k = rng:NextInteger(1, #Config.Palette.paper)
	local part = Instance.new("Part")
	part.Name = "DriftingPaper"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = Vector3.new(1.1, 0.8, 0.05)
	part.Color = Color3.fromHex(Config.Palette.paper[k])
	part:SetAttribute("Pattern", Config.PaperLook.patterns[k])
	part:SetAttribute("PatternRepeats", 1)
	part.Parent = parent
	return part
end

local function dropScrap(now: number, parent: Instance)
	local camera = workspace.CurrentCamera
	if not camera or #scraps >= A.paperMax then
		return
	end
	local look = camera.CFrame
	local ahead = look.Position + look.LookVector * rng:NextNumber(8, A.paperRadiusStuds)
	local from = Vector3.new(ahead.X + rng:NextNumber(-8, 8), look.Position.Y + rng:NextNumber(8, 14), ahead.Z + rng:NextNumber(-8, 8))
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { parent }
	local hit = workspace:Raycast(from, Vector3.new(0, -80, 0), params)
	local ground = if hit then hit.Position.Y + 0.05 else from.Y - 14
	table.insert(scraps, { part = newScrap(parent), from = from, ground = ground, start = now, yaw = rng:NextNumber(0, TAU), phase = rng:NextNumber(0, TAU) })
end

-- Falls with a side-to-side flutter and a tumble, lies flat a moment, then fades.
local function moveScraps(now: number)
	for i = #scraps, 1, -1 do
		local s = scraps[i]
		local t = (now - s.start) / A.paperFallSeconds
		local part = s.part
		if t < 1 then
			local swing = math.sin(t * TAU * 1.5 + s.phase)
			local pos = s.from:Lerp(Vector3.new(s.from.X + 3, s.ground, s.from.Z + 1.5), t) + Vector3.new(swing * 1.4, 0, math.cos(t * TAU + s.phase) * 0.8)
			part.CFrame = CFrame.new(pos) * CFrame.Angles(swing * 0.9, s.yaw + t * 3, math.cos(t * TAU * 1.2) * 0.5)
		elseif t < 1.4 then
			local rest = Vector3.new(s.from.X + 3, s.ground, s.from.Z + 1.5)
			part.CFrame = CFrame.new(rest) * CFrame.Angles(0, s.yaw, 0) * CFrame.Angles(math.rad(-90), 0, 0)
			part.Transparency = math.max(0, (t - 1.2) / 0.2)
		else
			part:Destroy()
			table.remove(scraps, i)
		end
	end
end

---------------------------------------------------------------- loop

local function step()
	local now = os.clock()
	-- Sway: every marked model turns about its hinge; one bulk move for all of them.
	local parts, frames = {}, {}
	for model, s in swinging do
		if not model.Parent then
			swinging[model] = nil
		else
			local turn = s.hinge * CFrame.fromAxisAngle(s.axis, s.amp * math.sin(now / A.swaySeconds * TAU + s.phase))
			for i, part in s.parts do
				table.insert(parts, part)
				table.insert(frames, turn * s.rel[i])
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	-- Pulse: transparency breathes between the marks; a light inside brightens as the glow does.
	for part, g in glowing do
		if not part.Parent then
			glowing[part] = nil
		else
			local k = 0.5 + 0.5 * math.sin(now / A.pulseSeconds * TAU + g.phase)
			part.Transparency = g.low + (g.high - g.low) * k
			if g.light then
				g.light.Brightness = g.brightness * (1.1 - 0.3 * k)
			end
		end
	end
	-- Snow follows the camera; paper drops now and then.
	local camera = workspace.CurrentCamera
	if snowfall and camera then
		local at = camera.CFrame.Position
		snowfall.CFrame = CFrame.new(at.X, at.Y + A.snowHeightStuds, at.Z)
	end
	if folder and now >= nextScrap then
		nextScrap = now + rng:NextNumber(A.paperEverySeconds[1], A.paperEverySeconds[2])
		dropScrap(now, folder)
	end
	moveScraps(now)
end

function Ambience.init()
	if workspace:GetAttribute("PlaceKind") ~= "Lobby" then
		return
	end
	local holder = Instance.new("Folder")
	holder.Name = "LobbyAmbience"
	holder.Parent = workspace
	folder = holder
	snowfall = makeSnowfall(holder)
	nextScrap = os.clock() + A.paperEverySeconds[1]
	watch("Sway", addSwing, swinging)
	watch("Pulse", addGlow, glowing)
	RunService.RenderStepped:Connect(step)
end

return Ambience
