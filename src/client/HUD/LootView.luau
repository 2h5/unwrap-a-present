--[=[
	LootView (client, part of HUD)
	Owns: how loot looks and sounds on this client (Table 14): a side-gift's spawn pop (12 sparkles in
	its rarity colour, a pop clip); the core reveal's light shaft out of the box, its slow 30-sparkle
	drift and the reveal sting; and the hue sweep on Secret gifts (never replicated every frame).
	The gifts themselves are the server's models in Workspace.Gifts (Loot); the rarity glow and the
	arc's trail ride on them.
	Must never: decide a gift, a rarity or where a gift goes.
	Read first: src/client/HUD/README.md
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Art = require(ReplicatedStorage.Shared.Art.Art)
local GiftModels = require(ReplicatedStorage.Shared.Art.GiftModels)
local Sfx = require(ReplicatedStorage.Shared.Sfx.Sfx)

local LootView = {}

local V = Config.Vfx
local secret: { [Model]: { BasePart } } = {}
local pop: ParticleEmitter

local function rarityColor(rarity: string): Color3
	local hex = Config.Rarity[rarity] and Config.Rarity[rarity].color
	return if hex then Color3.fromHex(hex) else Color3.fromHex(Config.UI.cream)
end

local function holder(name: string, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = size
	part.Parent = workspace
	return part
end

local function sparkles(parent: Instance, color: Color3): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = Art.particles.sparkle
	e.Rate = 0
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.8
	e.Parent = parent
	return e
end

-- The core reveal: a light shaft from the box and a slow drift, both in the rarity colour, for 3 s.
local function reveal(model: Model, rarity: string)
	local root = model:WaitForChild("Root", 5) :: BasePart?
	if not root then
		return
	end
	local color = rarityColor(rarity)
	local base = root.Position
	local shaft = holder("RevealShaft", Vector3.new(V.revealShaftStuds, V.revealShaftWidth, V.revealShaftWidth))
	shaft.Shape = Enum.PartType.Cylinder
	shaft.Material = Enum.Material.Neon
	shaft.Color = color
	shaft.Transparency = 0.55
	shaft.CFrame = CFrame.new(base + Vector3.yAxis * V.revealShaftStuds / 2) * CFrame.Angles(0, 0, math.pi / 2)
	local drift = sparkles(shaft, color)
	drift.Shape = Enum.ParticleEmitterShape.Cylinder
	drift.Speed = NumberRange.new(0.5, 1.5)
	drift.Lifetime = NumberRange.new(1.5, 2.5)
	drift.Size = NumberSequence.new(0.5, 0.1)
	drift.Rate = V.revealDrift / Config.Loot.coreRevealSeconds
	if rarity == "Secret" then
		local swept = secret[model] or {}
		table.insert(swept, shaft)
		secret[model] = swept
	end
	Sfx.playAt(Config.Sounds.coreSting, base)
	TweenService:Create(shaft, TweenInfo.new(Config.Loot.coreRevealSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	task.delay(Config.Loot.coreRevealSeconds, function()
		drift.Rate = 0
		task.delay(3, function()
			shaft:Destroy()
		end)
	end)
end

local function gift(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local rarity = model:GetAttribute("Rarity")
	if typeof(rarity) ~= "string" then
		return
	end
	if rarity == "Secret" then
		local parts = GiftModels.baseParts(model)
		if model.PrimaryPart then
			table.insert(parts, model.PrimaryPart) -- its glow
		end
		secret[model] = parts
		model.Destroying:Connect(function()
			secret[model] = nil
		end)
	end
	if model:GetAttribute("Kind") == "Core" then
		task.spawn(reveal, model, rarity)
		return
	end
	local root = model:WaitForChild("Root", 5) :: BasePart?
	if root then
		local at = pop.Parent :: BasePart
		at.CFrame = root.CFrame
		pop.Color = ColorSequence.new(rarityColor(rarity))
		pop:Emit(V.giftPop)
		Sfx.playAt(Config.Sounds.giftPop, root.Position)
	end
end

function LootView.init()
	local at = holder("GiftPop", Vector3.one)
	pop = sparkles(at, Color3.new(1, 1, 1))
	pop.Shape = Enum.ParticleEmitterShape.Sphere
	pop.Speed = NumberRange.new(4, 7)
	pop.Lifetime = NumberRange.new(0.4, 0.7)
	pop.Size = NumberSequence.new(0.6, 0)
	pop.Drag = 4

	local function watch(folder: Instance)
		folder.ChildAdded:Connect(gift)
		for _, child in folder:GetChildren() do
			task.spawn(gift, child)
		end
	end
	local folder = workspace:FindFirstChild("Gifts")
	if folder then
		watch(folder)
	end
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "Gifts" then
			watch(child)
		end
	end)
	RunService.RenderStepped:Connect(function()
		if next(secret) == nil then
			return
		end
		local color = Color3.fromHSV((os.clock() / Config.Greybox.secretHueSeconds) % 1, 0.6, 1)
		for _, parts in secret do
			for _, part in parts do
				part.Color = color
				local light = part:FindFirstChildOfClass("PointLight")
				if light then
					light.Color = color
				end
			end
		end
	end)
end

return LootView
