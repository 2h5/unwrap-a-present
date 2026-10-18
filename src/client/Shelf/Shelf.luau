--[=[
	Shelf (client system)
	Owns: Lobby shelf rendering, steal prompt and 6-second timer display. Phase 3: draws each player's
	shelf in the shelf row from the board the server mirrors (attributes Items, Capacity, OwnerName),
	slots by rarity, Secret sweeping its hue; and the porch decoration for this player's tier
	(Table 9: balloons at Birthday, a tree at Christmas). Steal comes in Phase 6.
	Must never: Move an item.
	Read first: src/client/Shelf/README.md
]=]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Gifts = require(ReplicatedStorage.Shared.Gifts.Gifts)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)

local Shelf = {}

local COLUMNS = 6 -- slots per row on a shelf board
local secretBlocks: { [BasePart]: boolean } = {}
local decor: Folder? = nil

local function rarityColor(rarity: string): Color3
	local hex = Config.Rarity[rarity] and Config.Rarity[rarity].color
	return if hex then Color3.fromHex(hex) else Color3.new(1, 1, 1)
end

local function draw(model: Model)
	local board = model.PrimaryPart
	local old = model:FindFirstChild("Items")
	if old then
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
	local top = board.Position + Vector3.new(0.5 + cell / 2, board.Size.Y / 2 - cell / 2, -board.Size.Z / 2)
	for _, item in (if ok then items else {}) do
		local slots = Config.Rarity[item.rarity] and Config.Rarity[item.rarity].shelfSlots or 1
		local index = item.slotIndex - 1
		local col, row = index % COLUMNS, index // COLUMNS
		if row < rows then
			local width = math.min(slots, COLUMNS - col) * cell
			local block = Instance.new("Part")
			block.Anchored = true
			block.CanCollide = false
			block.Size = Vector3.new(cell * 0.8, cell * 0.8, width - cell * 0.2)
			block.Position = top + Vector3.new(0, -row * cell, col * cell + width / 2)
			block.Color = rarityColor(item.rarity)
			block.Material = Enum.Material.SmoothPlastic
			if item.rarity == "Secret" then
				secretBlocks[block] = true
			end
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Right
			gui.PixelsPerStud = 40
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.TextScaled = true
			label.Font = Enum.Font.GothamBold
			label.TextColor3 = Color3.fromHex(Config.HUD.barColor)
			label.Text = `{Gifts.displayName(item.giftId, item.mutation)}{if item.count > 1 then ` ×{item.count}` else ""}`
			label.Parent = gui
			gui.Parent = block
			block.Parent = folder
		end
	end
	folder.Parent = model
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
	local board = model:WaitForChild("Board", 5)
	if board and not board:FindFirstChild("Owner") then
		local gui = Instance.new("BillboardGui")
		gui.Name = "Owner"
		gui.Size = UDim2.fromOffset(160, 36)
		gui.StudsOffset = Vector3.new(0, 4, 0)
		gui.MaxDistance = 80
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 0.3
		label.BackgroundColor3 = Color3.fromHex(Config.HUD.barColor)
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Text = `{model:GetAttribute("OwnerName") or "?"}'s shelf`
		label.Parent = gui
		gui.Parent = board
	end
end

-- Porch decoration for this player's tier (Table 9). Greybox: balloons or a cone tree.
local function decorate(tier: number)
	local lobby = workspace:FindFirstChild("Lobby")
	local porch = lobby and lobby:FindFirstChild("Porch") :: BasePart?
	if not porch then
		return
	end
	if decor then
		decor:Destroy()
	end
	decor = Instance.new("Folder")
	decor.Name = "TierDecor"
	local base = porch.Position + Vector3.new(porch.Size.X / 2 - 2, 0.5, 0)
	if tier == 1 then
		for i, hex in Config.Palette.paper do
			local balloon = Instance.new("Part")
			balloon.Shape = Enum.PartType.Ball
			balloon.Anchored = true
			balloon.CanCollide = false
			balloon.Size = Vector3.one * 1.6
			balloon.Color = Color3.fromHex(hex)
			balloon.Position = base + Vector3.new((i % 3) - 1, 6 + (i % 2), (i // 3) - 0.5)
			balloon.Parent = decor
		end
	else
		local tree = Instance.new("Part")
		tree.Anchored = true
		tree.CanCollide = false
		tree.Size = Vector3.new(4, 7, 4)
		tree.Color = Color3.fromHex(Config.Lobby.colors.tree)
		tree.Material = Enum.Material.Grass
		tree.Position = base + Vector3.new(0, 3.5, 0)
		tree.Parent = decor
	end
	decor.Parent = workspace
end

function Shelf.init()
	if workspace:GetAttribute("PlaceKind") ~= "Lobby" then
		return
	end
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
		if next(secretBlocks) == nil then
			return
		end
		local color = Color3.fromHSV((os.clock() / Config.Greybox.secretHueSeconds) % 1, 0.6, 1)
		for block in secretBlocks do
			if block.Parent then
				block.Color = color
			else
				secretBlocks[block] = nil
			end
		end
	end)
end

return Shelf
