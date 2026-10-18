--[=[
	Shelf (client system)
	Owns: Lobby shelf rendering, steal prompt and 6-second timer display. Phase 3: draws each player's
	shelf in the shelf gallery from the board the server mirrors (attributes Items, Capacity,
	OwnerName), in the board's own frame, and the porch decoration for this player's tier (Table 9).
	Phase 5: each item is its chunky toy (Shared/Art/GiftModels) on a wooden shelf plank with a rarity
	plate, a Mythic turns slowly, a Secret sweeps its hue; the owner's name hangs on a gift tag. The
	lobby's ambient motion is in Ambience.luau. Steal comes in Phase 6.
	Must never: Move an item.
	Read first: src/client/Shelf/README.md
]=]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local GiftModels = require(ReplicatedStorage.Shared.Art.GiftModels)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local Ambience = require(script.Parent.Ambience)

local Shelf = {}

local COLUMNS = 6 -- slots per row on a shelf board
local UI = Config.UI
local D = Config.Lobby.dress
local secretParts: { [BasePart]: boolean } = {}
local spinners: { [Model]: CFrame } = {}
local decor: Folder? = nil

local function rarityColor(rarity: string): Color3
	local hex = Config.Rarity[rarity] and Config.Rarity[rarity].color
	return if hex then Color3.fromHex(hex) else Color3.new(1, 1, 1)
end

local function piece(parent: Instance, name: string, size: Vector3, cf: CFrame, hex: string, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = Color3.fromHex(hex)
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local function draw(model: Model)
	local board = model.PrimaryPart
	local old = model:FindFirstChild("Items")
	if old then
		for _, child in old:GetDescendants() do
			if child:IsA("Model") then
				spinners[child] = nil
			end
		end
		old:Destroy()
	end
	if not board then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Items"
	local ok, items = pcall(HttpService.JSONDecode, HttpService, model:GetAttribute("Items") or "[]")
	local capacity = model:GetAttribute("Capacity") or Config.Shelf.startSlots
	local rows = math.ceil(capacity / COLUMNS)
	local cell = board.Size.Z / COLUMNS
	local rowH = board.Size.Y / math.max(rows, 1)
	-- Everything is placed in the board's own frame: items stand on its +X side, rows run along its Z.
	local frame = board.CFrame
	local face = board.Size.X / 2
	local top = board.Size.Y / 2
	local left = -board.Size.Z / 2
	-- One plank under each row.
	for row = 0, rows - 1 do
		local y = top - (row + 1) * rowH
		piece(folder, "Plank", Vector3.new(1.6, 0.14, board.Size.Z), frame * CFrame.new(face + 0.8, y + 0.07, 0), D.wood, Enum.Material.WoodPlanks)
	end
	for _, item in (if ok then items else {}) do
		local slots = Config.Rarity[item.rarity] and Config.Rarity[item.rarity].shelfSlots or 1
		local index = item.slotIndex - 1
		local col, row = index % COLUMNS, index // COLUMNS
		if row < rows then
			local width = math.min(slots, COLUMNS - col) * cell
			local floor = top - (row + 1) * rowH + 0.14
			local z = left + col * cell + width / 2
			local plate = piece(folder, "Plate", Vector3.new(1, 0.06, width - 0.12), frame * CFrame.new(face + 0.8, floor + 0.03, z), "#FFFFFF")
			plate.Color = rarityColor(item.rarity)
			plate.Material = Enum.Material.Neon
			plate.Transparency = 0.35
			if item.rarity == "Secret" then
				secretParts[plate] = true
			end
			local studs = math.min(rowH - 0.25, width) * Config.LootLook.shelfFill
			local toy = GiftModels.build(item.giftId, item.rarity, { studs = studs, mutation = if item.mutation ~= "" then item.mutation else nil, static = true })
			-- Toys face out of the shelf (their front, -Z, toward the board's +X).
			local pivot = frame * CFrame.new(face + 0.8, floor + 0.06, z) * CFrame.Angles(0, -math.pi / 2, 0)
			toy:PivotTo(pivot)
			if item.rarity == "Secret" then
				for _, part in GiftModels.baseParts(toy) do
					secretParts[part] = true
				end
			elseif item.rarity == "Mythic" then
				spinners[toy] = pivot
			end
			if item.count and item.count > 1 then
				local gui = Instance.new("BillboardGui")
				gui.Size = UDim2.fromOffset(34, 22)
				gui.StudsOffset = Vector3.new(0, studs + 0.2, 0)
				gui.MaxDistance = 40
				local badge = Instance.new("TextLabel")
				badge.Size = UDim2.fromScale(1, 1)
				badge.BackgroundColor3 = Color3.fromHex(UI.woodDark)
				badge.TextColor3 = Color3.fromHex(UI.cream)
				badge.TextScaled = true
				badge.Font = Enum.Font[UI.font]
				badge.Text = `×{item.count}`
				badge.Parent = gui
				Instance.new("UICorner").Parent = badge
				gui.Parent = toy.PrimaryPart
			end
			toy.Parent = folder
		end
	end
	folder.Parent = model
end

-- The owner's name on a gift tag hanging above the cabinet.
local function nameTag(board: BasePart, name: string)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Owner"
	gui.Size = UDim2.fromOffset(190, 46)
	gui.StudsOffset = Vector3.new(0, board.Size.Y / 2 + 2.6, 0)
	gui.MaxDistance = 80
	local tag = Instance.new("Frame")
	tag.Size = UDim2.fromScale(1, 1)
	tag.BackgroundColor3 = Color3.fromHex(UI.parchment)
	tag.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = tag
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex(UI.woodDark)
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = tag
	local hole = Instance.new("Frame")
	hole.AnchorPoint = Vector2.new(0.5, 0.5)
	hole.Position = UDim2.new(0, 14, 0.5, 0)
	hole.Size = UDim2.fromOffset(10, 10)
	hole.BackgroundColor3 = Color3.fromHex(UI.woodDark)
	hole.Parent = tag
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = hole
	local label = Instance.new("TextLabel")
	label.Position = UDim2.new(0, 26, 0, 4)
	label.Size = UDim2.new(1, -34, 1, -8)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromHex(UI.ink)
	label.TextScaled = true
	label.Font = Enum.Font[UI.font]
	label.Text = `{name}'s shelf`
	label.Parent = tag
	gui.Parent = board
end

local function watch(model: Instance)
	if not model:IsA("Model") then
		return
	end
	model:GetAttributeChangedSignal("Items"):Connect(function()
		draw(model)
	end)
	model:GetAttributeChangedSignal("Capacity"):Connect(function()
		draw(model)
	end)
	task.defer(draw, model)
	local board = model:WaitForChild("Board", 5) :: BasePart?
	if board and not board:FindFirstChild("Owner") then
		nameTag(board, model:GetAttribute("OwnerName") or "?")
	end
end

-- Porch decoration for this player's tier (Table 9): balloons on ribbons at Birthday; a layered tree
-- with a star, lights along the porch beam and a wreath on the door, from Christmas. Snow is no
-- longer the Christmas change: the whole village is snowy for everyone (DECISIONS.md, 2026-10-18).
local function decorate(tier: number)
	local lobby = workspace:FindFirstChild("Lobby")
	local porch = lobby and lobby:FindFirstChild("Porch") :: BasePart?
	if not porch then
		return
	end
	if decor then
		decor:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "TierDecor"
	decor = folder
	local base = porch.Position + Vector3.new(porch.Size.X / 2 - 2, porch.Size.Y / 2, 0)
	if tier == 1 then
		local knot = base + Vector3.new(0, 1.2, 0)
		piece(folder, "Weight", Vector3.new(0.8, 0.8, 0.8), CFrame.new(base + Vector3.new(0, 0.4, 0)), D.woodDark, Enum.Material.Wood)
		for i, hex in Config.Palette.paper do
			local angle = i / #Config.Palette.paper * 2 * math.pi
			local at = base + Vector3.new(math.cos(angle) * 1.4, 6.5 + (i % 3) * 0.7, math.sin(angle) * 1.4)
			piece(folder, "Balloon", Vector3.one * 1.7, CFrame.new(at), hex, Enum.Material.SmoothPlastic, Enum.PartType.Ball).Reflectance = 0.15
			local span = at - Vector3.yAxis * 0.85 - knot
			piece(folder, "String", Vector3.new(0.06, 0.06, span.Magnitude), CFrame.lookAt(knot + span / 2, knot + span), UI.twine, Enum.Material.Fabric)
		end
	else
		local trunkTop = base + Vector3.new(0, 1, 0)
		piece(folder, "Pot", Vector3.new(1.4, 1.6, 1.6), CFrame.new(base + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.pi / 2), D.woodDark, Enum.Material.Wood, Enum.PartType.Cylinder)
		for k = 0, 3 do
			local w = 4.2 - k * 0.9
			local cf = CFrame.new(trunkTop + Vector3.new(0, 0.8 + k * 1.4, 0)) * CFrame.Angles(0, math.rad(k * 22), 0)
			piece(folder, "Branches", Vector3.new(w, 1.5, w), cf, Config.Lobby.colors.tree, Enum.Material.Grass)
		end
		piece(folder, "Star", Vector3.new(0.9, 0.9, 0.3), CFrame.new(trunkTop + Vector3.new(0, 6.9, 0)) * CFrame.Angles(0, 0, math.rad(45)), Config.Lobby.dress.lantern, Enum.Material.Neon)
		local house = lobby and lobby:FindFirstChild("House")
		local beam = house and house:FindFirstChild("PorchBeam") :: BasePart?
		if beam then
			local n = 10
			for k = 0, n do
				local p = beam.Position + Vector3.new(-beam.Size.X / 2 + k * beam.Size.X / n, -0.6 - (k % 2) * 0.25, 0.2)
				piece(folder, "Light", Vector3.one * 0.35, CFrame.new(p), Config.Palette.paper[k % #Config.Palette.paper + 1], Enum.Material.Neon, Enum.PartType.Ball)
			end
		end
		-- A wreath on the cottage door: the snow everyone sees, the wreath only from Christmas.
		local door = house and house:FindFirstChild("Door") :: BasePart?
		if door then
			local centre = door.CFrame * CFrame.new(0, 1.2, door.Size.Z / 2 + 0.25) -- the door faces south (+Z)
			for k = 0, 9 do
				local a = k / 10 * 2 * math.pi
				piece(folder, "Wreath", Vector3.one * 0.6, centre * CFrame.new(math.cos(a) * 0.95, math.sin(a) * 0.95, 0), Config.Lobby.colors.tree, Enum.Material.Grass, Enum.PartType.Ball)
			end
			piece(folder, "WreathBow", Vector3.new(0.8, 0.5, 0.3), centre * CFrame.new(0, -0.95, 0.2), Config.Palette.ribbon.colors[2])
		end
	end
	folder.Parent = workspace
end

function Shelf.init()
	if workspace:GetAttribute("PlaceKind") ~= "Lobby" then
		return
	end
	Ambience.init()
	task.spawn(function()
		local lobby = workspace:WaitForChild("Lobby")
		local shelves = lobby:WaitForChild("Shelves")
		shelves.ChildAdded:Connect(watch)
		for _, model in shelves:GetChildren() do
			task.spawn(watch, model)
		end
	end)
	Remotes.get("ProfileState").OnClientEvent:Connect(function(state)
		if state.tier then
			decorate(state.tier)
		end
	end)
	RunService.RenderStepped:Connect(function()
		if next(secretParts) ~= nil then
			local color = Color3.fromHSV((os.clock() / Config.Greybox.secretHueSeconds) % 1, 0.6, 1)
			for part in secretParts do
				if part.Parent then
					part.Color = color
				else
					secretParts[part] = nil
				end
			end
		end
		if next(spinners) ~= nil then
			local turn = CFrame.Angles(0, os.clock() / Config.LootLook.mythicSpinSeconds * 2 * math.pi, 0)
			for toy, pivot in spinners do
				if toy.Parent then
					toy:PivotTo(pivot * turn)
				else
					spinners[toy] = nil
				end
			end
		end
	end)
end

return Shelf
