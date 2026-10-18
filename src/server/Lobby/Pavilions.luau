--[=[
	Pavilions (server, part of Lobby)
	Owns: building the three gift-themed pavilions round the plaza, each facing its centre, and the
	update board: Rewards is a round hatbox rotunda under a red lid with a gold ribbon and bow; Classes
	is a tower of stacked wrapped boxes, the bottom one open as a booth with the live odds board;
	Shop is an open cardboard box with its flaps folded out as awnings and a big gem on a post. Each has
	a counter part `{name}Booth` (Lobby puts the prompt on it) and a gift-tag sign.
	Must never: hold logic. Stock materials only, no stud or dot surface (invariant 4); plain paper
	colours here, drawn patterns are kept for the landmark.
	Read first: src/server/Lobby/README.md
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Props = require(ReplicatedStorage.Shared.Art.Props)

local Pavilions = {}

local L = Config.Lobby
local D = L.dress
local UI = Config.UI
local PAL = Config.Palette

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's axis upright

-- The frame of a pavilion `bearing` degrees round the plaza at `distance`, its front (-Z) to the centre.
function Pavilions.frame(bearing: number, distance: number): CFrame
	local b = math.rad(bearing)
	local at = Vector3.new(math.sin(b) * distance, 0, -math.cos(b) * distance)
	return CFrame.lookAt(at, Vector3.zero)
end

local function ribbon(parent: Instance, size: Vector3, cf: CFrame, color: string?): Part
	local p = Props.trim(parent, "Ribbon", size, cf, color or PAL.ribbon.color)
	p.Reflectance = PAL.ribbon.reflectance
	return p
end

-- A counter: the prompt part, with slats, a top and a kick plate. `cf` is its centre.
local function counter(parent: Instance, name: string, cf: CFrame, size: Vector3): BasePart
	local part = Props.part(parent, `{name}Booth`, size, cf, D.wood, "WoodPlanks")
	Props.trim(parent, "CounterTop", size + v(0.6, -size.Y + 0.4, 0.6), cf * CFrame.new(0, size.Y / 2 + 0.2, 0), D.woodDark, "Wood")
	for _, y in { -size.Y / 4, size.Y / 4 } do
		Props.trim(parent, "Slat", v(size.X + 0.1, 0.35, 0.2), cf * CFrame.new(0, y, -size.Z / 2 - 0.05), D.woodDark, "Wood")
	end
	return part
end

-- A gift-tag sign hung on twine from height `hookY` above it, swaying a little; nobody bumps into it.
-- Front faces -Z of `at`.
local function hungTag(parent: Instance, at: CFrame, hookY: number, w: number, h: number, title: string, subtitle: string)
	local model = Instance.new("Model")
	model.Name = "Sign"
	Props.tag(model, at, w, h, title, subtitle)
	for _, x in { -w * 0.35, w * 0.35 } do
		local knot = at * CFrame.new(x, h / 2, 0)
		Props.twine(model, knot.Position, knot.Position + v(0, hookY - knot.Position.Y, 0))
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
	model.Parent = parent
	Props.sway(model, at.Position + v(0, hookY - at.Position.Y, 0), at.RightVector, 2.5)
end

---------------------------------------------------------------- Rewards

-- The hatbox rotunda: six posts on a round stone base, a back wall, a red drum roof with a gold
-- ribbon cross and bow, snow on top. Three small wrapped boxes on the counter.
local function rewards(parent: Instance, at: CFrame): BasePart
	local model = Instance.new("Model")
	model.Name = "RewardsPavilion"
	Props.part(model, "Base", v(0.5, 15.2, 15.2), at * CFrame.new(0, 0.25, 0) * FLAT, D.stone, "Slate")
	local postR, postH = 6.6, 8.3
	local posts = {}
	for k = 0, 5 do
		local a = math.rad(30 + k * 60)
		local p = v(math.sin(a) * postR, 0, -math.cos(a) * postR)
		table.insert(posts, p)
		Props.part(model, "Post", v(0.9, postH, 0.9), at * CFrame.new(p + v(0, 0.5 + postH / 2, 0)), D.woodDark, "Wood")
		Props.trim(model, "PostBand", v(1, 0.6, 1), at * CFrame.new(p + v(0, 3.2, 0)), D.red)
	end
	-- Back wall: three panels between the four back posts (30 and 330 degrees stay open at the front).
	for k = 3, 5 do
		local a, b = posts[k - 1], posts[k]
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		Props.part(model, "BackWall", v(len, postH - 1, 0.5), at * CFrame.lookAt(mid + v(0, 0.5 + (postH - 1) / 2, 0), mid + v(0, 0.5 + (postH - 1) / 2, 0) + mid.Unit), D.wall, "WoodPlanks")
	end
	-- The hatbox lid roof.
	local roofY = 0.5 + postH + 1.3
	Props.part(model, "Drum", v(2.6, 16.4, 16.4), at * CFrame.new(0, roofY, 0) * FLAT, D.red)
	Props.trim(model, "DrumRim", v(0.5, 16.7, 16.7), at * CFrame.new(0, roofY - 1.05, 0) * FLAT, PAL.ribbon.color)
	local top = roofY + 1.3
	ribbon(model, v(16.8, 0.25, 1.8), at * CFrame.new(0, top, 0))
	ribbon(model, v(1.8, 0.25, 16.8), at * CFrame.new(0, top, 0))
	for _, n in { v(0, 0, 1), v(0, 0, -1), v(1, 0, 0), v(-1, 0, 0) } do
		local size = if n.Z ~= 0 then v(1.8, 2.7, 0.25) else v(0.25, 2.7, 1.8)
		ribbon(model, size, at * CFrame.new(n * 8.25 + v(0, roofY, 0)))
	end
	Props.trim(model, "Snow", v(0.7, 14.6, 14.6), at * CFrame.new(0, top + 0.3, 0) * FLAT, D.snow, "Snow")
	for _, lump in { { 3.2, -2.4, 5.4 }, { -3.6, 1.8, 4.6 }, { 0.8, 4, 3.8 } } do
		Props.trim(model, "Snow", v(0.6, lump[3], lump[3]), at * CFrame.new(lump[1], top + 0.75, lump[2]) * FLAT, D.snow, "Snow")
	end
	Props.bow(model, at * CFrame.new(0, top + 1, 0), 6, PAL.ribbon.color)
	-- A lantern hanging in the middle, lit.
	Props.hangingLantern(model, (at * CFrame.new(0, roofY - 1.3, 0)).Position, true)
	-- The counter and its display: three small wrapped boxes.
	local desk = counter(model, "Rewards", at * CFrame.new(0, 0.5 + 1.8, -3.4), v(6, 3.6, 2.4))
	for k, spec in { { -1.8, 1.3, 1 }, { 0, 1.8, 3 }, { 1.8, 1.1, 5 } } do
		local s = spec[2]
		local c = at * CFrame.new(spec[1], 0.5 + 3.6 + 0.4 + s / 2, -3.4) * CFrame.Angles(0, math.rad(k * 12), 0)
		Props.trim(model, "RewardBox", Vector3.one * s, c, PAL.paper[spec[3]])
		Props.trim(model, "RewardRibbon", v(s + 0.05, s + 0.05, s * 0.2), c, UI.twine)
	end
	hungTag(model, at * CFrame.new(0, 6.6, -8), (at * CFrame.new(0, roofY - 1.3, 0)).Position.Y, 6, 2, "Rewards", "Daily and group gems")
	model.Parent = parent
	return desk
end

---------------------------------------------------------------- Classes

-- The live odds board (Diagram D): every class and its spin odds, text from Config. Front faces -Z of `cf`.
local function oddsBoard(parent: Instance, cf: CFrame)
	local board = Props.trim(parent, "OddsBoard", v(6.4, 3.8, 0.2), cf, UI.parchment, "SmoothPlastic")
	Props.trim(parent, "OddsFrame", v(6.9, 4.3, 0.15), cf * CFrame.new(0, 0, 0.15), D.woodDark, "Wood")
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0.6
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0.01, 0)
	list.Parent = gui
	local function line(text: string, h: number)
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, h)
		l.BackgroundTransparency = 1
		l.TextScaled = true
		l.Font = Enum.Font[UI.font]
		l.TextColor3 = Color3.fromHex(UI.ink)
		l.Text = text
		l.Parent = gui
	end
	line(`Spin · {Config.Gems.classSpin} gems`, 0.2)
	for _, id in Config.ClassOrder do
		local class = Config.Classes[id]
		line(`{class.name}  {class.odds}%`, 0.12)
	end
	gui.Parent = board
end

-- A wrapped box with ribbon bands crossing over it and snow on top. `cf` is its bottom centre.
local function wrapped(parent: Instance, cf: CFrame, size: Vector3, color: string, ribbonColor: string, rng: Random)
	Props.part(parent, "Box", size, cf * CFrame.new(0, size.Y / 2, 0), color)
	ribbon(parent, v(size.X + 0.3, size.Y + 0.3, 1.4), cf * CFrame.new(0, size.Y / 2, 0), ribbonColor)
	ribbon(parent, v(1.4, size.Y + 0.3, size.Z + 0.3), cf * CFrame.new(0, size.Y / 2, 0), ribbonColor)
	Props.snow(parent, cf * CFrame.new(rng:NextNumber(-0.4, 0.4), size.Y + 0.15, rng:NextNumber(-0.4, 0.4)), size.X, size.Z, 0.45, rng:NextNumber(0.75, 0.92))
end

-- The tower of stacked boxes: a teal box open at the front as the booth, a cream box and a red box
-- turned on top of it, a bow on the summit.
local function classes(parent: Instance, at: CFrame): BasePart
	local model = Instance.new("Model")
	model.Name = "ClassesPavilion"
	local rng = Random.new(41)
	local W, Dp, H = 12, 10, 10
	Props.part(model, "Floor", v(W, 0.3, Dp), at * CFrame.new(0, 0.15, 0), D.plank, "WoodPlanks")
	Props.part(model, "BackWall", v(W, H, 0.8), at * CFrame.new(0, H / 2, Dp / 2 - 0.4), D.teal)
	for _, sx in { -1, 1 } do
		Props.part(model, "SideWall", v(0.8, H, Dp), at * CFrame.new(sx * (W / 2 - 0.4), H / 2, 0), D.teal)
		Props.part(model, "FramePost", v(1, H, 1), at * CFrame.new(sx * (W / 2 - 0.4), H / 2, -Dp / 2), D.cream)
		ribbon(model, v(0.25, H, 1.8), at * CFrame.new(sx * (W / 2 + 0.05), H / 2, 0.5))
	end
	Props.part(model, "Roof", v(W + 0.6, 0.9, Dp + 0.6), at * CFrame.new(0, H + 0.45, 0), D.teal)
	Props.part(model, "Header", v(W + 0.6, 1.6, 1), at * CFrame.new(0, H - 0.8, -Dp / 2), D.cream)
	ribbon(model, v(1.8, H, 0.25), at * CFrame.new(0, H / 2, Dp / 2 + 0.05))
	ribbon(model, v(1.8, 0.25, Dp + 0.8), at * CFrame.new(0, H + 0.95, 0))
	ribbon(model, v(W + 0.8, 0.25, 1.8), at * CFrame.new(0, H + 0.95, 0.5))
	Props.snow(model, at * CFrame.new(0, H + 1, 0), W + 0.2, Dp + 0.2, 0.5, 0.95)
	-- The stack above: each box a little turned from the one below.
	local y = H + 0.9
	wrapped(model, at * CFrame.new(0.3, y, 0.6) * CFrame.Angles(0, math.rad(12), 0), v(8.5, 6, 7.5), D.cream, PAL.ribbon.colors[2], rng)
	wrapped(model, at * CFrame.new(-0.2, y + 6, 0.4) * CFrame.Angles(0, math.rad(-14), 0), v(5.2, 5.2, 5.2), D.red, PAL.ribbon.color, rng)
	Props.bow(model, at * CFrame.new(-0.2, y + 11.7, 0.4) * CFrame.Angles(0, math.rad(-14), 0), 4.2, PAL.ribbon.color)
	-- Inside: the counter, the odds board on the back wall, a lantern under the header.
	local desk = counter(model, "Classes", at * CFrame.new(0, 0.3 + 1.8, -2.6), v(8, 3.6, 2.4))
	oddsBoard(model, at * CFrame.new(0, 5.6, Dp / 2 - 1))
	Props.hangingLantern(model, (at * CFrame.new(3.8, H - 0.1, -1)).Position, true)
	-- The sign is fixed to the header, not hung: the odds board stays in view under it.
	Props.tag(model, at * CFrame.new(0, H - 0.8, -Dp / 2 - 0.8), 6, 1.6, "Classes", "Spin for a class")
	model.Parent = parent
	return desk
end

---------------------------------------------------------------- Shop

-- The open box market: cardboard walls with a counter cut in the front, the four flaps folded out as
-- awnings, packing tape over the front flap, a big gem on a post rising out of it.
local function shop(parent: Instance, at: CFrame): BasePart
	local model = Instance.new("Model")
	model.Name = "ShopPavilion"
	local rng = Random.new(43)
	local W, Dp, H = 13, 10, 6.5
	local cb = PAL.cardboard
	Props.part(model, "Floor", v(W, 0.3, Dp), at * CFrame.new(0, 0.15, 0), D.plank, "WoodPlanks")
	Props.part(model, "BackWall", v(W, H, 0.6), at * CFrame.new(0, H / 2, Dp / 2 - 0.3), cb, "Cardboard")
	for _, sx in { -1, 1 } do
		Props.part(model, "SideWall", v(0.6, H, Dp), at * CFrame.new(sx * (W / 2 - 0.3), H / 2, 0), cb, "Cardboard")
		Props.part(model, "FrontWall", v(2.5, H, 0.6), at * CFrame.new(sx * (W / 2 - 1.25), H / 2, -Dp / 2 + 0.3), cb, "Cardboard")
	end
	Props.part(model, "FrontLintel", v(8, 1, 0.6), at * CFrame.new(0, H - 0.5, -Dp / 2 + 0.3), cb, "Cardboard")
	-- The flaps: front up as an awning, back steep, sides folded out; each hinged on its top edge.
	local flap = 0.35
	local front = at * CFrame.new(0, H, -Dp / 2) * CFrame.Angles(math.rad(25), 0, 0)
	Props.part(model, "Flap", v(W, flap, 5), front * CFrame.new(0, flap / 2, -2.5), cb, "Cardboard")
	Props.snow(model, front * CFrame.new(0, flap, -2.6), W - 1, 4.4, 0.4, 0.88)
	local tape = Props.trim(model, "Tape", v(1.4, 0.06, 5.1), front * CFrame.new(0, flap + 0.45, -2.5), PAL.tape.color, PAL.tape.material)
	tape.Transparency = PAL.tape.transparency
	local back = at * CFrame.new(0, H, Dp / 2) * CFrame.Angles(math.rad(-65), 0, 0)
	Props.part(model, "Flap", v(W, flap, 5), back * CFrame.new(0, flap / 2, 2.5), cb, "Cardboard")
	for _, sx in { -1, 1 } do
		local side = at * CFrame.new(sx * W / 2, H, 0) * CFrame.Angles(0, 0, math.rad(sx * 40))
		Props.part(model, "Flap", v(4, flap, Dp), side * CFrame.new(sx * 2, flap / 2, 0), cb, "Cardboard")
		Props.snow(model, side * CFrame.new(sx * 2.1, flap, 0), 3.4, Dp - 0.6, 0.35, rng:NextNumber(0.7, 0.9))
	end
	-- Inside: a stack of plain boxes, the gem on its post.
	for k, spec in { { -4.2, 2.4, 0.3 }, { -4.4, 1.8, 2.7 }, { 4.1, 2, 0.3 } } do
		Props.trim(model, "Crate", Vector3.one * spec[2], at * CFrame.new(spec[1], spec[3] + spec[2] / 2, 2.6) * CFrame.Angles(0, math.rad(k * 17), 0), cb, "Cardboard")
	end
	Props.part(model, "GemPost", v(0.8, 10, 0.8), at * CFrame.new(0, 5, 2.4), D.woodDark, "Wood")
	local gem = Props.trim(model, "BigGem", Vector3.one * 3, at * CFrame.new(0, 11.6, 2.4) * CFrame.Angles(math.rad(45), 0, math.rad(35.26)), D.gem, "Glass")
	gem.Transparency = 0.1
	-- The counter, its gems, a lantern under the awning.
	local desk = counter(model, "Shop", at * CFrame.new(0, 0.3 + 1.8, -Dp / 2 + 1), v(8, 3.6, 2))
	for k, spec in { { -0.8, 1.4, 20 }, { 0.4, 1.9, -15 }, { 1.4, 1.1, 40 } } do
		local g = Props.trim(model, "Gem", v(spec[2] * 0.7, spec[2], spec[2] * 0.7), at * CFrame.new(spec[1], 0.3 + 3.6 + 0.4 + spec[2] / 2, -Dp / 2 + 1.2) * CFrame.Angles(0, math.rad(spec[3] + 45), math.rad(k * 6)), D.gem, "Glass")
		g.Transparency = 0.15
	end
	Props.hangingLantern(model, (front * CFrame.new(3.5, 0, -2.5)).Position, true)
	local lip = front * CFrame.new(0, 0, -5)
	hungTag(model, at * CFrame.new(0, 6.6, -Dp / 2 - 4.6), lip.Position.Y, 6, 2, "Shop", "Gems and passes")
	model.Parent = parent
	return desk
end

---------------------------------------------------------------- update board

-- The update board beside the pads: a roofed board with its poster, snow on the roof. Room is left
-- beside it for the most-liked shelves board and the leaderboards (Table 19, later).
local function updateBoard(parent: Instance, at: CFrame): BasePart
	local model = Instance.new("Model")
	model.Name = "UpdateBoardStand"
	for _, side in { -1, 1 } do
		Props.part(model, "BoardPost", v(0.9, 10, 0.9), at * CFrame.new(side * 5.4, 5, 0), D.woodDark, "Wood")
	end
	local board = Props.part(model, "UpdateBoard", v(10, 8, 1), at * CFrame.new(0, 5, 0), D.wood, "WoodPlanks")
	local roof = at * CFrame.new(0, 9.6, -0.4) * CFrame.Angles(math.rad(-12), 0, 0)
	Props.part(model, "BoardRoof", v(12, 0.6, 3), roof, L.colors.roof, "RoofShingles")
	Props.snow(model, roof * CFrame.new(0, 0.3, 0), 11.4, 2.6, 0.35, 0.9)
	local poster = Props.trim(model, "Poster", v(8, 6, 0.2), at * CFrame.new(0, 5, -0.6), UI.parchment)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.6
	for _, spec in { { "???", 0.08, 0.5 }, { "Something new arrives soon", 0.62, 0.28 } } do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0.05, spec[2])
		l.Size = UDim2.fromScale(0.9, spec[3])
		l.TextScaled = true
		l.Font = Enum.Font[UI.font]
		l.TextColor3 = Color3.fromHex(UI.ink)
		l.Text = spec[1]
		l.Parent = gui
	end
	gui.Parent = poster
	model.Parent = parent
	return board
end

-- Builds the pavilions and the update board. Returns the counters by name and the board.
function Pavilions.build(parent: Instance): ({ [string]: BasePart }, BasePart)
	local P = L.pavilions
	local booths = {
		Rewards = rewards(parent, Pavilions.frame(P.Rewards[1], P.Rewards[2])),
		Classes = classes(parent, Pavilions.frame(P.Classes[1], P.Classes[2])),
		Shop = shop(parent, Pavilions.frame(P.Shop[1], P.Shop[2])),
	}
	-- A little stack of wrapped presents at each pavilion's front corners.
	local stacks = Instance.new("Model")
	stacks.Name = "PresentStacks"
	for k, name in { "Rewards", "Classes", "Shop" } do
		local at = Pavilions.frame(P[name][1], P[name][2])
		for side, spec in { { -1, 1 }, { 1, 4 } } do
			local corner = at * CFrame.new(spec[1] * 10, 0.16, -4.5) * CFrame.Angles(0, math.rad(k * 19 + side * 31), 0)
			Props.present(stacks, corner, 2.2, PAL.paper[spec[2] + k - 1], PAL.ribbon.colors[side])
			Props.present(stacks, corner * CFrame.new(0.2, 2.22, -0.1) * CFrame.Angles(0, math.rad(25), 0), 1.3, PAL.paper[(spec[2] + k + 1) % #PAL.paper + 1], PAL.ribbon.colors[3 - side])
		end
	end
	stacks.Parent = parent
	local ux, uz = L.updateBoard[1], L.updateBoard[2]
	local board = updateBoard(parent, CFrame.lookAt(Vector3.new(ux, 0, uz), Vector3.new(0, 0, 4)))
	return booths, board
end

return Pavilions
