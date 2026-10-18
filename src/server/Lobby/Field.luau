--[=[
	Field (server, part of Lobby)
	Owns: building the lobby, Unwrapping Plaza (Diagram D as revised 2026-10-18): the spawn on a round
	dais south of the plaza's centre facing north, the three Start a Run pads in a row before the giant
	present with glowing rims and gift-tag posts, and calling the builders for the setting (Village),
	the landmark (Landmark) and the pavilions (Pavilions). Also the shelf spot and dressing, the
	wooden label chip and prompts that Lobby wires up.
	Must never: hold logic. It returns the instances Lobby wires up. World tier: stock materials only,
	no stud or dot surface (invariant 4); paper patterns only on the landmark.
	Read first: src/server/Lobby/README.md
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Props = require(ReplicatedStorage.Shared.Art.Props)
local Landmark = require(script.Parent.Landmark)
local Pavilions = require(script.Parent.Pavilions)
local Village = require(script.Parent.Village)

local Field = {}

local L = Config.Lobby
local D = L.dress
local UI = Config.UI

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-- A small wooden chip above a part, readable on a phone from the spawn (vault crates, pad status).
function Field.label(adornee: BasePart, text: string, height: number): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(200, 48)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	gui.Adornee = adornee
	local chip = Instance.new("TextLabel")
	chip.Size = UDim2.fromScale(1, 1)
	chip.BackgroundColor3 = Color3.fromHex(UI.woodLight)
	chip.TextColor3 = Color3.fromHex(UI.cream)
	chip.TextStrokeColor3 = Color3.fromHex(UI.woodDark)
	chip.TextStrokeTransparency = 0
	chip.TextScaled = true
	chip.Font = Enum.Font[UI.font]
	chip.Text = text
	chip.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, UI.cornerPx)
	corner.Parent = chip
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex(UI.woodDark)
	stroke.Thickness = UI.strokePx
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = chip
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = chip
	gui.Parent = adornee
	return chip
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

---------------------------------------------------------------- start area

-- A start pad as an opened box: the pad colour inside, cardboard flaps folded out on every side, and
-- a glowing rim on the ground round it that breathes on the client (Pulse).
local function pad(parent: Instance, i: number, center: Vector3): BasePart
	local s = L.padStuds
	local p = Props.part(parent, `Pad{i}`, v(s, 1, s), CFrame.new(center), L.padColors[i], "SmoothPlastic")
	for _, n in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local hinge = center + n * (s / 2) + Vector3.yAxis * 0.5
		local cf = CFrame.lookAt(hinge, hinge + n) * CFrame.Angles(math.rad(-25), 0, 0) * CFrame.new(0, 0, -1.3)
		local flap = Props.trim(parent, "PadFlap", v(s, 0.3, 2.6), cf, Config.Palette.cardboard, "Cardboard")
		flap.CanCollide = false
	end
	Props.trim(parent, "PadRim", v(s + 0.4, 0.9, s + 0.4), CFrame.new(center - Vector3.yAxis * 0.1), Config.Palette.cardboard, "Cardboard")
	local reach = s / 2 + 2.6
	for _, n in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local bar = Props.trim(parent, "PadGlow", v(0.4, 0.12, 2 * reach + 0.4), CFrame.fromMatrix(v(center.X, 0.24, center.Z) + n * reach, n, Vector3.yAxis), L.padColors[i], "Neon")
		bar.CastShadow = false
		Props.pulse(bar, 0.15, 0.55)
	end
	return p
end

-- The three pads in a row before the giant present (solo, party, join anyone), each with a tag on a
-- ribbon-banded post behind it. A pad's tag text is its `Label` (Lobby updates pad 3's).
local function startArea(parent: Instance): { BasePart }
	local model = Instance.new("Model")
	model.Name = "StartArea"
	local pads = {}
	local names = {
		{ "Solo", "Just you" },
		{ "Party", "You and friends on the pad" },
		{ "Join anyone", "Up to 4 players" },
	}
	local z = L.padsZ
	for i, x in L.padsX do
		local p = pad(model, i, v(x, 0.5, z))
		local postZ = z - L.padStuds / 2 - 3
		Props.part(model, "PadPost", v(0.8, 6.6, 0.8), CFrame.new(x, 3.3, postZ), D.woodDark, "Wood")
		Props.trim(model, "PostBand", v(0.9, 0.5, 0.9), CFrame.new(x, 1.4, postZ), D.ribbonRed)
		Props.trim(model, "PostKnob", Vector3.one * 1.1, CFrame.new(x, 6.9, postZ), D.ribbonGold, "SmoothPlastic", Enum.PartType.Ball)
		Props.trim(model, "Snow", v(0.9, 0.3, 0.9), CFrame.new(x, 7.45, postZ), D.snow, "Snow")
		local tagCf = CFrame.lookAt(v(x, 5, postZ + 0.7), v(x, 5, postZ + 4))
		local board = Props.tag(model, tagCf, 5.4, 2, names[i][1], names[i][2])
		local gui = board:FindFirstChild("Text") :: SurfaceGui
		gui.Name = "Label"
		gui.Adornee = board
		gui.Parent = p
		table.insert(pads, p)
	end
	for _, x in { (L.padsX[1] + L.padsX[2]) / 2, (L.padsX[2] + L.padsX[3]) / 2 } do
		Props.lantern(model, v(x, 0.1, z - L.padStuds / 2 - 3), 6, false)
	end
	model.Parent = parent
	return pads
end

-- The spawn: a round stone dais with a gold ring and a ribbon cross, facing north to the pads.
local function spawn(parent: Instance)
	local sx, sz = L.spawn[1], L.spawn[2]
	local flat = CFrame.Angles(0, 0, math.rad(90))
	Props.part(parent, "SpawnDais", v(0.6, 12, 12), CFrame.new(sx, 0.06, sz) * flat, D.stone, "Slate")
	Props.trim(parent, "SpawnRing", v(0.5, 12.8, 12.8), CFrame.new(sx, 0.02, sz) * flat, D.ribbonGold, "SmoothPlastic")
	for _, turn in { 0, 90 } do
		Props.trim(parent, "SpawnRibbon", v(11.4, 0.05, 1.4), CFrame.new(sx, 0.38, sz) * CFrame.Angles(0, math.rad(turn), 0), D.ribbonRed, "SmoothPlastic")
	end
	local point = Instance.new("SpawnLocation")
	point.Name = "LobbySpawn"
	point.Anchored = true
	point.Size = v(8, 0.6, 8)
	point.CFrame = CFrame.lookAt(v(sx, 0.06, sz), v(sx, 0.06, sz - 1))
	point.Transparency = 1
	point.Duration = 0
	point.Parent = parent
end

---------------------------------------------------------------- build

-- Builds the lobby under Workspace.Lobby. Returns the parts Lobby needs.
function Field.build(): { pads: { BasePart }, booths: { [string]: BasePart }, porch: BasePart, shelves: Folder, board: BasePart, folder: Folder }
	Props.clearTemplate()
	Props.applyLighting("Lobby")
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	local rng = Random.new(5)
	Village.terrain(rng)
	Village.plaza(folder)
	Village.terrace(folder, rng)
	local porch = Village.cottage(folder, rng)
	Village.gallery(folder, rng)
	Village.backdrop(folder, rng)
	Landmark.build(folder)
	local booths, board = Pavilions.build(folder)
	local pads = startArea(folder)
	spawn(folder)
	local shelves = Instance.new("Folder")
	shelves.Name = "Shelves"
	shelves.Parent = folder
	folder.Parent = workspace
	return { pads = pads, booths = booths, porch = porch, shelves = shelves, board = board, folder = folder }
end

---------------------------------------------------------------- shelves

-- The floor point and facing of shelf slot `i` in the gallery; the CFrame's +X points out of the
-- shelf's front (Lobby puts the board half a stud behind it).
function Field.shelfSpot(i: number): CFrame
	return Village.shelfSpot(i)
end

-- Dresses a shelf board as a display cabinet: side panels, a plinth, a top and a crest, in the
-- board's own frame. `board` is the shelf's back (1 x 6 x 6; items stand on its +X side).
function Field.dressShelf(model: Model, board: BasePart)
	local cf = board.CFrame
	local h, wz = board.Size.Y, board.Size.Z
	board.Color = Color3.fromHex(D.wall)
	for _, side in { -1, 1 } do
		Props.trim(model, "ShelfSide", v(2.4, h + 0.6, 0.4), cf * CFrame.new(1.2, 0.3, side * (wz / 2 + 0.2)), D.wood, "WoodPlanks")
	end
	Props.trim(model, "ShelfPlinth", v(2.6, 0.6, wz + 1.2), cf * CFrame.new(1.2, -h / 2 + 0.3, 0), D.woodDark, "Wood")
	Props.trim(model, "ShelfTop", v(2.8, 0.5, wz + 1.4), cf * CFrame.new(1.1, h / 2 + 0.55, 0), D.woodDark, "Wood")
	Props.trim(model, "ShelfCrest", v(0.6, 0.9, wz * 0.6), cf * CFrame.new(0, h / 2 + 1.2, 0), D.wood, "WoodPlanks")
end

return Field
