--[=[
	PaperLook (client, part of Debris)
	Owns: drawing the present's surfaces on this client from the attributes the server sets: `Pattern`
	(a paper pattern, Shared/Art/Patterns), `Print` (the cardboard print) and the bow's loops and tails
	on a ribbon's `Kind = "Bow"` panel. A look hides with its part (a torn panel is see-through on the
	server). The same looks go on the Tick, Jack's box, the lobby's giant present and its drifting paper.
	Must never: change a server part's size, collision or attributes; decorations never take raycasts.
	Read first: src/client/Debris/README.md
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Patterns = require(ReplicatedStorage.Shared.Art.Patterns)

local PaperLook = {}

local watched: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function decoration(parent: BasePart, name: string, size: Vector3, cframe: CFrame, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = parent.Material
	part.Color = parent.Color
	part.Reflectance = parent.Reflectance
	part:SetAttribute("Kind", "BowLoop") -- NightView dulls it with the ribbon
	part.Parent = parent
	return part
end

-- Two loops, a knot and two tails on top of the bow panel (its front, -Z, points up).
local function bow(part: BasePart)
	local w = part.Size.X
	local loop = w * Config.PaperLook.bowLoopStuds
	local top = part.CFrame * CFrame.new(0, 0, -part.Size.Z / 2)
	local pieces = {}
	for _, side in { -1, 1 } do
		-- A loop is a short, wide cylinder tipped outward: it reads as a ribbon loop from every side.
		local cf = top * CFrame.new(side * loop * 0.55, 0, -loop * 0.35) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(side * 30))
		table.insert(pieces, decoration(part, "Loop", Vector3.new(w * 0.22, loop, loop), cf, Enum.PartType.Cylinder))
		local tail = top * CFrame.new(side * w * 0.22, side * w * 0.3, -w * 0.04) * CFrame.Angles(0, 0, math.rad(side * 20))
		table.insert(pieces, decoration(part, "Tail", Vector3.new(w * 0.2, w * 0.5, w * 0.05), tail))
	end
	table.insert(pieces, decoration(part, "Knot", Vector3.one * w * 0.3, top * CFrame.new(0, 0, -w * 0.12), Enum.PartType.Ball))
	local function follow()
		for _, piece in pieces do
			piece.Transparency = part.Transparency
			piece.Color = part.Color
			piece.Reflectance = part.Reflectance
		end
	end
	part:GetPropertyChangedSignal("Transparency"):Connect(follow)
	part:GetPropertyChangedSignal("Color"):Connect(follow)
	part:GetPropertyChangedSignal("Reflectance"):Connect(follow)
	follow()
end

local function look(object: Instance)
	if not object:IsA("BasePart") or watched[object] then
		return
	end
	local pattern = object:GetAttribute("Pattern")
	local printed = object:GetAttribute("Print")
	local isBow = object:GetAttribute("Kind") == "Bow"
	if typeof(pattern) ~= "string" and not printed and not isBow then
		return
	end
	watched[object] = true
	if typeof(pattern) == "string" then
		Patterns.apply(object, pattern, object:GetAttribute("PatternRepeats") :: number?)
	elseif printed then
		Patterns.print(object)
	end
	if isBow then
		bow(object)
	end
	local function visible()
		Patterns.setVisible(object, object.Transparency < 1)
	end
	object:GetPropertyChangedSignal("Transparency"):Connect(visible)
	visible()
end

function PaperLook.init()
	workspace.DescendantAdded:Connect(look)
	for _, object in workspace:GetDescendants() do
		look(object)
	end
end

return PaperLook
