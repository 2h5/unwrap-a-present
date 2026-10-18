--[=[
	Field (server, part of Lobby)
	Owns: building the greybox lobby to Diagram D: one open field, spawn centre-bottom facing the three
	Start a Run pads, the booths along the top (Rewards, Classes, Shop), the house and porch top-left
	with the half-torn demo present, the shelf row below it, and the update board top-right.
	Must never: hold logic. It returns the instances Lobby wires up. World tier: stock materials only.
	Read first: src/server/Lobby/README.md
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)

local Field = {}

local L = Config.Lobby

local function part(parent: Instance, name: string, size: Vector3, position: Vector3, color: string, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.Color = Color3.fromHex(color)
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A sign above a part: big text, readable on a phone from the spawn.
function Field.label(adornee: BasePart, text: string, height: number): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(220, 60)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.3
	label.BackgroundColor3 = Color3.fromHex(Config.HUD.barColor)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.Parent = gui
	Instance.new("UICorner").Parent = label
	gui.Parent = adornee
	return label
end

-- A prompt the HUD draws in the bottom third (Custom style, Table 13).
function Field.prompt(parent: BasePart, name: string, action: string, object: string?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = object or ""
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = parent
	return prompt
end

local function demoPresent(parent: Instance, base: Vector3)
	-- Half torn: a paper cube with its top-front corner open and the paper on the ground.
	local size = Config.Panels.panelStuds * 2
	local color = Config.Palette.paper[1]
	local box = part(parent, "DemoBox", Vector3.new(size, size, size) * 0.96, base + Vector3.new(0, size / 2, 0), Config.Palette.cardboard, Enum.Material.Cardboard)
	box.CanCollide = true
	local half = size / 2
	for row = 0, 1 do
		for col = 0, 1 do
			if not (row == 1 and col == 1) then
				part(parent, "DemoPaper", Vector3.new(half, half, 0.2), base + Vector3.new(-half / 2 + col * half, half / 2 + row * half, half + 0.1), color)
			end
		end
	end
	for i = 1, 3 do
		local piece = part(parent, "DemoDebris", Vector3.new(half, 0.2, half), base + Vector3.new(-2 + i * 2, 0.1, half + 2 + i), color)
		piece.Orientation = Vector3.new(0, i * 37, 0)
	end
end

-- Builds the lobby under Workspace.Lobby. Returns the parts Lobby needs.
function Field.build(): { pads: { BasePart }, booths: { [string]: BasePart }, porch: BasePart, shelves: Folder, board: BasePart, folder: Folder }
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	local w, d = L.fieldStuds[1], L.fieldStuds[2]
	part(folder, "Field", Vector3.new(w, 1, d), Vector3.new(0, -0.5, 0), L.colors.field, Enum.Material.Grass)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.lookAt(Vector3.new(L.spawn[1], 0.5, L.spawn[2]), Vector3.new(L.spawn[1] + 1, 0.5, L.spawn[2]))
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Duration = 0
	spawn.Parent = folder

	-- Start a Run: three pads stacked north from the spawn line, 12 studs east of spawn.
	local pads = {}
	local names = { "Solo", "Party (friends)", "Join anyone" }
	for i = 1, 3 do
		local z = L.spawn[2] - (i - 1) * (L.padStuds + L.padGapStuds)
		local pad = part(folder, `Pad{i}`, Vector3.new(L.padStuds, 1, L.padStuds), Vector3.new(L.padsX + L.padStuds / 2, 0.5, z), L.padColors[i], Enum.Material.SmoothPlastic)
		Field.label(pad, names[i], 4)
		table.insert(pads, pad)
	end

	local booths = {}
	for i, name in { "Rewards", "Classes", "Shop" } do
		local booth = part(folder, `{name}Booth`, Vector3.new(8, 4, 4), Vector3.new(L.boothsX[i], 2, L.boothsZ), Config.Palette.cardboard, Enum.Material.WoodPlanks)
		Field.label(booth, name, 5)
		booths[name] = booth
	end

	-- House and porch, top-left. The porch faces south (toward the shelf row and spawn).
	local hx, hz = L.house[1], L.house[2]
	part(folder, "House", Vector3.new(16, 12, 12), Vector3.new(hx, 6, hz), L.colors.house, Enum.Material.WoodPlanks)
	local roof = part(folder, "Roof", Vector3.new(18, 2, 14), Vector3.new(hx, 13, hz), L.colors.roof, Enum.Material.Slate)
	roof.CanCollide = false
	local porch = part(folder, "Porch", Vector3.new(16, 1, 8), Vector3.new(hx, 0.5, hz + 10), Config.Palette.cardboard, Enum.Material.WoodPlanks)
	demoPresent(folder, Vector3.new(hx - 3, 1, hz + 9))

	local shelves = Instance.new("Folder")
	shelves.Name = "Shelves"
	shelves.Parent = folder

	local board = part(folder, "UpdateBoard", Vector3.new(10, 8, 1), Vector3.new(L.updateBoard[1], 5, L.updateBoard[2]), Config.Palette.cardboard, Enum.Material.WoodPlanks)
	Field.label(board, "Something new arrives soon", 6)

	folder.Parent = workspace
	return { pads = pads, booths = booths, porch = porch, shelves = shelves, board = board, folder = folder }
end

-- The floor point for shelf `i` in the row (Diagram D: left, below the house, running south).
function Field.shelfSpot(i: number): Vector3
	return Vector3.new(L.shelfRow[1], 0, L.shelfRow[2] + (i - 1) * L.shelfSpacingStuds)
end

return Field
