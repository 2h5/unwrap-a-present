--[=[
	ToolModels (shared)
	Owns: the chunky prop for each pickable tool (Scissors, BoxCutter, Chainsaw), lying flat, and
	`dress(pickup, tool)`, which turns a pickup's touch box into that prop on a soft glowing ring.
	Placeholders until final models exist; a model in ReplicatedStorage.Assets.Tools named by tool
	replaces one with no code change.
	Must never: change the pickup's size, position or touch behaviour (the caller owns pickups).
	Read first: src/shared/README.md
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)

local ToolModels = {}

local T = Config.ToolLook

-- Recipe pieces: shape (B block, C cylinder along x, W wedge), size, centre, colour key, yaw in degrees.
-- Units: about 1 long, lying on y = 0.
local RECIPES = {
	Scissors = {
		{ "B", 0.62, 0.06, 0.1, 0.22, 0.05, -0.05, "metal", 14 },
		{ "B", 0.62, 0.06, 0.1, 0.22, 0.08, 0.05, "metal", -14 },
		{ "C", 0.08, 0.3, 0.3, -0.22, 0.06, -0.14, "grip", 0 },
		{ "C", 0.08, 0.3, 0.3, -0.22, 0.06, 0.14, "grip", 0 },
		{ "C", 0.1, 0.08, 0.08, 0.0, 0.1, 0, "ink", 0 },
	},
	BoxCutter = {
		{ "B", 0.6, 0.14, 0.2, -0.1, 0.07, 0, "body", 0 },
		{ "B", 0.5, 0.04, 0.22, -0.14, 0.15, 0, "ink", 0 },
		{ "W", 0.06, 0.1, 0.34, 0.33, 0.06, 0, "metal", 90 },
	},
	Chainsaw = {
		{ "B", 0.4, 0.3, 0.26, -0.25, 0.15, 0, "body", 0 },
		{ "B", 0.6, 0.06, 0.16, 0.25, 0.12, 0, "metal", 0 },
		{ "B", 0.62, 0.08, 0.04, 0.25, 0.12, 0, "ink", 0 },
		{ "B", 0.08, 0.2, 0.26, -0.38, 0.38, 0, "ink", 0 },
		{ "B", 0.28, 0.06, 0.06, -0.26, 0.47, 0, "grip", 0 },
	},
}

local SHAPES = { B = Enum.PartType.Block, C = Enum.PartType.Cylinder }

-- The prop for `tool`, its largest side `studs`, every part anchored, pivot at its floor centre.
function ToolModels.build(tool: string, studs: number): Model
	local model = Instance.new("Model")
	model.Name = tool
	local final = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Tools")
	local authored = final and final:FindFirstChild(tool)
	if authored and authored:IsA("Model") then
		local copy = authored:Clone()
		copy:ScaleTo(studs)
		copy:PivotTo(CFrame.new())
		return copy
	end
	for _, piece in RECIPES[tool] or RECIPES.Scissors do
		local shape, sx, sy, sz, x, y, z, color, yaw = table.unpack(piece)
		local part: BasePart
		if shape == "W" then
			part = Instance.new("WedgePart")
		else
			local block = Instance.new("Part")
			block.Shape = SHAPES[shape]
			part = block
		end
		part.Size = Vector3.new(sx, sy, sz) * studs
		local cf = CFrame.new(x * studs, y * studs, z * studs) * CFrame.Angles(0, math.rad(yaw), 0)
		if shape == "C" then
			cf *= CFrame.Angles(0, 0, math.rad(90)) -- a ring lying flat
		end
		part.CFrame = cf
		part.Color = Color3.fromHex(T[color])
		part.Material = if color == "metal" then Enum.Material.Metal else Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Parent = model
	end
	return model
end

-- Turns `pickup` (an anchored touch box on the floor) into `tool`'s prop on a glowing ring.
function ToolModels.dress(pickup: BasePart, tool: string)
	local studs = math.max(pickup.Size.X, pickup.Size.Z)
	pickup.Transparency = 1
	local ring = Instance.new("Part")
	ring.Name = "Glow"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.1, studs * 1.2, studs * 1.2)
	ring.CFrame = CFrame.new(pickup.Position.X, pickup.Position.Y - pickup.Size.Y / 2 + 0.05, pickup.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromHex(T.glow)
	ring.Transparency = 0.4
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Parent = pickup
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex(T.glow)
	light.Range = studs * 3
	light.Brightness = 1.2
	light.Parent = ring
	local model = ToolModels.build(tool, studs)
	model:PivotTo(CFrame.new(ring.Position + Vector3.yAxis * 0.1) * CFrame.Angles(0, math.rad(30), 0))
	model.Parent = pickup
end

return ToolModels
