--[=[
	NightView (client, part of HUD)
	Owns: how the Night looks and sounds on this client: lighting at this player's NightLight (set by
	the server), the run room's window light dropped, paper desaturated, ribbon dulled and tape gloss
	off (Table 12 Night versions), the Tick's ticking at the server's Volume, its pulsing seams and
	faint heat shimmer, Jack's crank, lunge and the dust puffs where he lands, the down sound, and a
	greyscale screen while this player is down (Table 14).
	Must never: Compute a value it displays or decide anything. Lighting, volume, downs and the
	timer come from the server (player attributes, Tick attributes, NightState).
	Read first: src/client/HUD/README.md
]=]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Art = require(ReplicatedStorage.Shared.Art.Art)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx.Sfx)

local NightView = {}

local player = Players.LocalPlayer
local dayExposure = Lighting.ExposureCompensation
local isNight = false
local changed: { [BasePart]: { color: Color3?, reflectance: number?, material: Enum.Material? } } = {}
local presentWatch: RBXScriptConnection? = nil
local downGrey: ColorCorrectionEffect
local puffs: ParticleEmitter

-- Lights at `scale` of day: exposure scales everything on screen, sky and sun included (log2 stops).
local function light()
	local scale = if isNight then player:GetAttribute("NightLight") or Config.Night.lightingScale else 1
	Lighting.ExposureCompensation = dayExposure + math.log(scale, 2)
end

-- Night drops the window light (Diagram D); the cold rim light comes from Jack's box.
local function windowLight(on: boolean)
	local room = workspace:FindFirstChild("Room")
	local glass = room and room:FindFirstChild("Glass")
	local sun = glass and glass:FindFirstChild("WindowLight") :: SurfaceLight?
	if sun then
		sun.Enabled = on
	end
end

-- Paper panels lose 40% of their colour; ribbon loses its shine; tape loses its gloss (Table 12).
local function nightLook(object: Instance)
	if not object:IsA("BasePart") or changed[object] then
		return
	end
	local kind = object:GetAttribute("Kind")
	if kind == "Panel" then
		local h, s, v = object.Color:ToHSV()
		changed[object] = { color = object.Color }
		object.Color = Color3.fromHSV(h, s * (1 - Config.Night.desaturate), v)
	elseif kind == "Segment" or kind == "Bow" or kind == "BowLoop" then
		changed[object] = { reflectance = object.Reflectance }
		object.Reflectance = Config.Night.nightRibbonReflectance
	elseif kind == "Tape" then
		changed[object] = { material = object.Material }
		object.Material = Enum.Material.SmoothPlastic
	end
end

local function setNight(on: boolean)
	if on == isNight then
		return
	end
	isNight = on
	light()
	windowLight(not on)
	if presentWatch then
		presentWatch:Disconnect()
		presentWatch = nil
	end
	if on then
		local present = workspace:FindFirstChild("Present")
		if present then
			for _, object in present:GetDescendants() do
				nightLook(object)
			end
			presentWatch = present.DescendantAdded:Connect(nightLook)
		end
	else
		for object, was in changed do
			if object.Parent then
				if was.color then
					object.Color = was.color
				end
				if was.reflectance then
					object.Reflectance = was.reflectance
				end
				if was.material then
					object.Material = was.material
				end
			end
		end
		changed = {}
	end
end

local function loop(parent: Instance, clips: { string }, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = clips[1]
	sound.Looped = true
	sound.Volume = volume
	sound.Parent = parent
	sound:Play()
	return sound
end

-- The Tick ticks from the start, louder as the team tears toward it (server attribute Volume).
local function watchTick(model: Model)
	local box = model:WaitForChild("Box", 5) :: BasePart?
	if not box then
		return
	end
	local sound = loop(box, Config.Sounds.tickLoop, model:GetAttribute("Volume") or Config.Tick.volumeMin)
	model:GetAttributeChangedSignal("Volume"):Connect(function()
		sound.Volume = model:GetAttribute("Volume") or sound.Volume
	end)
	local seams = {}
	for _, child in model:GetChildren() do
		if child.Name:sub(1, 4) == "Seam" then
			table.insert(seams, child)
		end
	end
	-- A faint heat shimmer: a Neon shell round the box, no particles (Table 14, Tick found).
	local shimmer = Instance.new("Part")
	shimmer.Name = "Shimmer"
	shimmer.Anchored = true
	shimmer.CanCollide = false
	shimmer.CanQuery = false
	shimmer.CanTouch = false
	shimmer.CastShadow = false
	shimmer.Material = Enum.Material.Neon
	shimmer.Color = Color3.fromHex(Config.Tick.seamColor)
	shimmer.Size = box.Size * 1.5
	shimmer.CFrame = box.CFrame
	shimmer.Transparency = 1
	shimmer.Parent = box
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not model.Parent then
			connection:Disconnect()
			return
		end
		if model:GetAttribute("Revealed") then
			-- Seams pulse faintly every 0.8 s; at Night they burn at full brightness (Table 12).
			local pulse = 0.5 + 0.5 * math.sin(os.clock() * 2 * math.pi / Config.Tick.seamPulseSeconds)
			for _, seam in seams do
				seam.Transparency = if isNight then 0 else 0.25 + 0.5 * pulse
			end
			local base = Config.Vfx.tickShimmerTransparency
			shimmer.Transparency = base + (1 - base) * (1 - pulse)
			shimmer.CFrame = box.CFrame * CFrame.Angles(0, os.clock() % (2 * math.pi), 0)
		else
			shimmer.Transparency = 1
		end
	end)
end

local function watchJack(model: Model)
	local box = model:WaitForChild("Box", 5)
	if box then
		loop(box, Config.Sounds.jackCrank, 0.6)
	end
end

local function rootOf(userId: number): BasePart?
	local other = Players:GetPlayerByUserId(userId)
	local character = other and other.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function NightView.init()
	downGrey = Instance.new("ColorCorrectionEffect")
	downGrey.Name = "DownGrey"
	downGrey.Saturation = Config.Night.downGrey
	downGrey.Enabled = false
	downGrey.Parent = Lighting

	local holder = Instance.new("Part")
	holder.Name = "JackDust"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(3, 0.2, 3)
	holder.Parent = workspace
	puffs = Instance.new("ParticleEmitter")
	puffs.Texture = Art.particles.dust
	puffs.Rate = 0
	puffs.Shape = Enum.ParticleEmitterShape.Disc
	puffs.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	puffs.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	puffs.EmissionDirection = Enum.NormalId.Top
	puffs.Speed = NumberRange.new(2, 4)
	puffs.Lifetime = NumberRange.new(0.6, 0.9)
	puffs.Size = NumberSequence.new(1, 2.2)
	puffs.Transparency = NumberSequence.new(0.4, 1)
	puffs.Color = ColorSequence.new(Color3.fromHex(Config.RunRoom.colors.floor):Lerp(Color3.new(1, 1, 1), 0.5))
	puffs.Parent = holder

	local function onDown()
		downGrey.Enabled = player:GetAttribute("Down") == true
	end
	player:GetAttributeChangedSignal("Down"):Connect(onDown)
	player:GetAttributeChangedSignal("NightLight"):Connect(light)
	onDown()

	local function watchNight(folder: Instance)
		folder.ChildAdded:Connect(function(child)
			if child.Name == "Tick" and child:IsA("Model") then
				task.spawn(watchTick, child)
			elseif child.Name == "Jack" and child:IsA("Model") then
				task.spawn(watchJack, child)
			end
		end)
		for _, child in folder:GetChildren() do
			if child.Name == "Tick" and child:IsA("Model") then
				task.spawn(watchTick, child)
			elseif child.Name == "Jack" and child:IsA("Model") then
				task.spawn(watchJack, child)
			end
		end
	end
	local folder = workspace:FindFirstChild("Night")
	if folder then
		watchNight(folder)
	else
		workspace.ChildAdded:Connect(function(child)
			if child.Name == "Night" and child:IsA("Folder") then
				watchNight(child)
			end
		end)
	end

	Remotes.get("NightState").OnClientEvent:Connect(function(night)
		if not night then
			return
		end
		if night.kind == "Lunge" then
			local jack = workspace:FindFirstChild("Night") and workspace.Night:FindFirstChild("Jack")
			local head = jack and jack:FindFirstChild("Head") :: BasePart?
			if head then
				Sfx.playAt(Config.Sounds.jackLunge, head.Position)
			end
			-- Eight dust puffs where he lands (Table 14).
			task.delay(Config.Night.jackLungeSeconds, function()
				local box = jack and jack.Parent and jack:FindFirstChild("Box") :: BasePart?
				if box then
					local holder = puffs.Parent :: BasePart
					holder.CFrame = CFrame.new(box.Position - Vector3.yAxis * (box.Size.Y / 2 - 0.2))
					puffs:Emit(Config.Vfx.lungePuffs)
				end
			end)
		elseif night.kind == "Down" then
			local root = rootOf(night.userId)
			if root then
				Sfx.playAt(Config.Sounds.playerDown, root.Position)
			end
		elseif night.kind == nil then
			setNight(typeof(night.secondsLeft) == "number")
		end
	end)
end

return NightView
