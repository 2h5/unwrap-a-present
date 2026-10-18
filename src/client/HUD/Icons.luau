--[=[
	Icons (client, part of HUD)
	Owns: the original code-drawn icons every screen uses until the final illustrations exist (Shared/
	Art slots; docs/art/assets.md): currencies, the four right-edge buttons, tools and run-shop items,
	passes, gem packs, class emblems and reward icons. Each is a few rounded frames in a square, with
	chunky shapes and a dark outline, so it reads at thumb size.
	Must never: carry text, a price, odds or a button; labels stay live UI beside the icon.
	Read first: src/client/HUD/README.md
]=]

local Icons = {}

local INK = Color3.fromRGB(59, 36, 22)
local C = {
	gold = Color3.fromRGB(242, 178, 58),
	goldDark = Color3.fromRGB(196, 132, 34),
	gem = Color3.fromRGB(127, 216, 255),
	gemDark = Color3.fromRGB(64, 156, 214),
	wood = Color3.fromRGB(198, 142, 90),
	woodDark = Color3.fromRGB(139, 90, 53),
	paper = Color3.fromRGB(243, 227, 195),
	red = Color3.fromRGB(217, 69, 59),
	redDark = Color3.fromRGB(160, 44, 40),
	orange = Color3.fromRGB(232, 128, 58),
	cream = Color3.fromRGB(255, 246, 230),
	metal = Color3.fromRGB(201, 206, 214),
	green = Color3.fromRGB(88, 177, 74),
	greenDark = Color3.fromRGB(54, 124, 50),
	blue = Color3.fromRGB(70, 120, 220),
	purple = Color3.fromRGB(150, 90, 210),
	skin = Color3.fromRGB(243, 201, 160),
	dark = Color3.fromRGB(70, 60, 56),
	white = Color3.fromRGB(255, 255, 255),
}

-- One shape in the unit square: centre (x, y), size (w, h), colour, rotation, roundness (0 square,
-- 1 round), outline thickness (0 none).
local function shape(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, rotation: number?, round: number?, outline: number?): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Rotation = rotation or 0
	if round and round > 0 then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(round * 0.5, 0)
		c.Parent = f
	end
	if (outline or 2) > 0 then
		local s = Instance.new("UIStroke")
		s.Color = INK
		s.Thickness = outline or 2
		s.Parent = f
	end
	f.Parent = parent
	return f
end

-- A ring: a transparent circle with a thick outline in `color`.
local function ring(parent: Instance, x: number, y: number, d: number, color: Color3, thickness: number)
	local f = shape(parent, x, y, d, d, color, 0, 1, 0)
	f.BackgroundTransparency = 1
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = f
	return f
end

local function star(parent: Instance, x: number, y: number, s: number, color: Color3)
	shape(parent, x, y, s, s, color, 0, 0.2, 2)
	shape(parent, x, y, s, s, color, 45, 0.2, 0)
end

local function gem(parent: Instance, x: number, y: number, s: number)
	shape(parent, x, y, s, s, C.gem, 45, 0.15, 2)
	shape(parent, x, y - s * 0.05, s * 0.45, s * 0.45, C.white, 45, 0.15, 0).BackgroundTransparency = 0.45
end

local function coin(parent: Instance, x: number, y: number, s: number)
	shape(parent, x, y, s, s, C.gold, 0, 1, 2)
	shape(parent, x, y, s * 0.66, s * 0.66, C.goldDark, 0, 1, 0)
	shape(parent, x - s * 0.1, y, s * 0.2, s * 0.2, C.gold, 45, 0.3, 0)
	shape(parent, x + s * 0.1, y, s * 0.2, s * 0.2, C.gold, 45, 0.3, 0)
end

local function box(parent: Instance, x: number, y: number, s: number, color: Color3)
	shape(parent, x, y + s * 0.08, s, s * 0.84, color, 0, 0.12, 2)
	shape(parent, x, y - s * 0.38, s * 1.08, s * 0.24, color:Lerp(Color3.new(0, 0, 0), 0.2), 0, 0.12, 2)
	shape(parent, x, y + s * 0.02, s * 0.18, s * 0.98, C.cream, 0, 0, 0)
	shape(parent, x - s * 0.2, y - s * 0.56, s * 0.3, s * 0.22, C.cream, -20, 1, 2)
	shape(parent, x + s * 0.2, y - s * 0.56, s * 0.3, s * 0.22, C.cream, 20, 1, 2)
end

local DRAW: { [string]: (Frame) -> () } = {}

---------------------------------------------------------------- currencies and buttons

DRAW.Cash = function(f)
	coin(f, 0.5, 0.5, 0.86)
end
DRAW.Gems = function(f)
	gem(f, 0.5, 0.52, 0.62)
end
DRAW.Shelf = function(f)
	shape(f, 0.5, 0.52, 0.84, 0.86, C.woodDark, 0, 0.1, 2)
	shape(f, 0.5, 0.52, 0.7, 0.72, C.paper, 0, 0.05, 0)
	shape(f, 0.5, 0.53, 0.72, 0.06, C.wood, 0, 0, 0)
	shape(f, 0.5, 0.86, 0.72, 0.06, C.wood, 0, 0, 0)
	shape(f, 0.32, 0.4, 0.2, 0.2, C.red, 0, 0.2, 2)
	shape(f, 0.6, 0.42, 0.16, 0.16, C.blue, 0, 1, 2)
	shape(f, 0.45, 0.74, 0.22, 0.18, C.green, 0, 0.2, 2)
	shape(f, 0.7, 0.75, 0.14, 0.16, C.gold, 45, 0.2, 2)
end
DRAW.Shop = function(f)
	ring(f, 0.5, 0.3, 0.4, INK, 5)
	shape(f, 0.5, 0.62, 0.76, 0.6, C.orange, 0, 0.25, 2)
	shape(f, 0.5, 0.48, 0.76, 0.08, C.orange:Lerp(Color3.new(0, 0, 0), 0.2), 0, 0, 0)
	shape(f, 0.62, 0.7, 0.2, 0.26, C.paper, 12, 0.2, 2)
end
DRAW.Classes = function(f)
	shape(f, 0.42, 0.52, 0.5, 0.7, C.woodDark, -12, 0.15, 2)
	shape(f, 0.58, 0.5, 0.5, 0.7, C.paper, 8, 0.15, 2)
	star(f, 0.58, 0.48, 0.26, C.gold)
end
DRAW.Rewards = function(f)
	box(f, 0.5, 0.56, 0.7, C.red)
end
DRAW.Close = function(f)
	shape(f, 0.5, 0.5, 0.95, 0.2, C.cream, 45, 0.6, 0)
	shape(f, 0.5, 0.5, 0.95, 0.2, C.cream, -45, 0.6, 0)
end
DRAW.Star = function(f)
	star(f, 0.5, 0.5, 0.6, C.gold)
end

---------------------------------------------------------------- tools and run-shop items

DRAW.Hands = function(f)
	shape(f, 0.5, 0.56, 0.5, 0.62, C.skin, 0, 0.7, 2)
	shape(f, 0.25, 0.56, 0.18, 0.34, C.skin, -35, 1, 2)
	shape(f, 0.5, 0.88, 0.54, 0.14, C.red, 0, 0.4, 2)
end
DRAW.Scissors = function(f)
	shape(f, 0.62, 0.32, 0.12, 0.62, C.metal, 22, 0.4, 2)
	shape(f, 0.38, 0.32, 0.12, 0.62, C.metal, -22, 0.4, 2)
	ring(f, 0.3, 0.74, 0.28, C.red, 6)
	ring(f, 0.7, 0.74, 0.28, C.red, 6)
	shape(f, 0.5, 0.52, 0.1, 0.1, INK, 0, 1, 0)
end
DRAW.BoxCutter = function(f)
	shape(f, 0.42, 0.58, 0.74, 0.26, C.gold, -30, 0.3, 2)
	shape(f, 0.78, 0.32, 0.26, 0.16, C.metal, -30, 0.1, 2)
	shape(f, 0.4, 0.57, 0.5, 0.06, INK, -30, 0, 0)
end
DRAW.Chainsaw = function(f)
	shape(f, 0.66, 0.42, 0.58, 0.2, C.metal, -20, 0.5, 2)
	shape(f, 0.32, 0.6, 0.42, 0.36, C.orange, -20, 0.2, 2)
	ring(f, 0.22, 0.36, 0.22, INK, 5)
end
DRAW.GripTape = function(f)
	shape(f, 0.5, 0.5, 0.76, 0.76, C.dark, 0, 1, 2)
	shape(f, 0.5, 0.5, 0.36, 0.36, C.paper, 0, 1, 2)
	shape(f, 0.78, 0.8, 0.36, 0.14, C.dark, 30, 0, 2)
end
DRAW.Flashlight = function(f)
	shape(f, 0.66, 0.36, 0.5, 0.36, C.gold, -35, 0, 0).BackgroundTransparency = 0.45
	shape(f, 0.34, 0.66, 0.44, 0.2, C.dark, -35, 0.4, 2)
	shape(f, 0.53, 0.47, 0.18, 0.28, C.red, -35, 0.2, 2)
end
DRAW.SpareLid = function(f)
	shape(f, 0.5, 0.52, 0.8, 0.8, Color3.fromRGB(185, 138, 82), 0, 0.1, 2)
	shape(f, 0.32, 0.36, 0.06, 0.26, INK, 0, 0, 0)
	shape(f, 0.32, 0.25, 0.16, 0.16, INK, 45, 0, 0)
	for k = 0, 4 do
		shape(f, 0.56 + k * 0.05, 0.74, 0.025 + (k % 2) * 0.02, 0.16, INK, 0, 0, 0)
	end
end
DRAW.LuckyBow = function(f)
	shape(f, 0.3, 0.42, 0.4, 0.3, C.gold, -20, 1, 2)
	shape(f, 0.7, 0.42, 0.4, 0.3, C.gold, 20, 1, 2)
	shape(f, 0.38, 0.72, 0.14, 0.4, C.gold, 20, 0.3, 2)
	shape(f, 0.62, 0.72, 0.14, 0.4, C.gold, -20, 0.3, 2)
	shape(f, 0.5, 0.46, 0.2, 0.2, C.goldDark, 0, 1, 2)
end

---------------------------------------------------------------- passes and gem packs

DRAW.DoubleCash = function(f)
	coin(f, 0.38, 0.58, 0.6)
	coin(f, 0.62, 0.42, 0.6)
end
DRAW.BigShelf = function(f)
	shape(f, 0.5, 0.5, 0.74, 0.92, C.woodDark, 0, 0.1, 2)
	shape(f, 0.5, 0.5, 0.6, 0.8, C.paper, 0, 0.05, 0)
	for row = 0, 2 do
		shape(f, 0.5, 0.33 + row * 0.27, 0.62, 0.05, C.wood, 0, 0, 0)
		shape(f, 0.36, 0.24 + row * 0.27, 0.14, 0.14, ({ C.red, C.blue, C.green })[row + 1], 0, 0.2, 2)
		shape(f, 0.62, 0.24 + row * 0.27, 0.16, 0.14, ({ C.gold, C.purple, C.orange })[row + 1], 0, 1, 2)
	end
end
DRAW.ToolKeeper = function(f)
	ring(f, 0.5, 0.34, 0.36, INK, 6)
	shape(f, 0.5, 0.62, 0.84, 0.5, C.red, 0, 0.2, 2)
	shape(f, 0.5, 0.52, 0.84, 0.06, C.redDark, 0, 0, 0)
	shape(f, 0.5, 0.64, 0.18, 0.18, C.gold, 0, 0.3, 2)
end
DRAW.Lucky = function(f)
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		shape(f, 0.5 + math.cos(a) * 0.17, 0.44 + math.sin(a) * 0.17, 0.32, 0.32, C.green, 0, 1, 2)
	end
	shape(f, 0.56, 0.78, 0.07, 0.34, C.greenDark, -25, 0.5, 2)
	shape(f, 0.5, 0.44, 0.14, 0.14, C.greenDark, 0, 1, 0)
end
DRAW.Gems100 = function(f)
	gem(f, 0.5, 0.52, 0.5)
end
DRAW.Gems500 = function(f)
	gem(f, 0.32, 0.62, 0.36)
	gem(f, 0.68, 0.62, 0.36)
	gem(f, 0.5, 0.38, 0.42)
end
DRAW.Gems1200 = function(f)
	shape(f, 0.5, 0.78, 0.86, 0.28, C.woodDark, 0, 0.3, 2)
	for k, spec in { { 0.24, 0.6 }, { 0.42, 0.5 }, { 0.6, 0.56 }, { 0.78, 0.62 }, { 0.36, 0.34 }, { 0.62, 0.32 } } do
		gem(f, spec[1], spec[2], if k > 4 then 0.3 else 0.26)
	end
end

---------------------------------------------------------------- classes

DRAW.ClassKid = function(f) -- a balloon
	shape(f, 0.5, 0.38, 0.5, 0.58, C.red, 0, 1, 2)
	shape(f, 0.5, 0.7, 0.1, 0.08, C.redDark, 45, 0, 2)
	shape(f, 0.52, 0.86, 0.03, 0.24, INK, 8, 0, 0)
	shape(f, 0.4, 0.28, 0.1, 0.14, C.white, -20, 1, 0).BackgroundTransparency = 0.4
end
DRAW.ClassWrapper = function(f) -- a tape roll on paper
	shape(f, 0.5, 0.56, 0.84, 0.6, C.blue, -8, 0.1, 2)
	shape(f, 0.5, 0.42, 0.52, 0.52, Color3.fromRGB(255, 243, 196), 0, 1, 2)
	shape(f, 0.5, 0.42, 0.22, 0.22, C.paper, 0, 1, 2)
end
DRAW.ClassSprinter = function(f) -- a lightning bolt
	shape(f, 0.56, 0.32, 0.22, 0.46, C.gold, 25, 0.1, 2)
	shape(f, 0.44, 0.68, 0.22, 0.46, C.gold, 25, 0.1, 2)
	shape(f, 0.5, 0.5, 0.4, 0.14, C.gold, -10, 0.1, 2)
end
DRAW.ClassCollector = function(f) -- a magnifying glass
	ring(f, 0.42, 0.42, 0.48, INK, 7)
	shape(f, 0.42, 0.42, 0.42, 0.42, C.gem, 0, 1, 0).BackgroundTransparency = 0.4
	shape(f, 0.72, 0.74, 0.12, 0.34, C.woodDark, -45, 0.4, 2)
end
DRAW.ClassHeir = function(f) -- a crown
	shape(f, 0.5, 0.66, 0.74, 0.28, C.gold, 0, 0.15, 2)
	for _, x in { 0.22, 0.5, 0.78 } do
		shape(f, x, 0.46, 0.2, 0.2, C.gold, 45, 0.1, 2)
	end
	shape(f, 0.5, 0.66, 0.12, 0.12, C.red, 45, 0, 2)
end
DRAW.ClassKrampusKid = function(f) -- two horns over a little head
	shape(f, 0.5, 0.62, 0.52, 0.48, C.red, 0, 1, 2)
	shape(f, 0.28, 0.3, 0.14, 0.36, C.dark, -30, 0.6, 2)
	shape(f, 0.72, 0.3, 0.14, 0.36, C.dark, 30, 0.6, 2)
	shape(f, 0.4, 0.6, 0.08, 0.08, INK, 0, 1, 0)
	shape(f, 0.6, 0.6, 0.08, 0.08, INK, 0, 1, 0)
end

---------------------------------------------------------------- rewards

DRAW.Daily = function(f)
	box(f, 0.5, 0.56, 0.66, C.green)
end
DRAW.Group = function(f)
	for _, spec in { { 0.32, C.blue }, { 0.68, C.orange } } do
		shape(f, spec[1], 0.36, 0.26, 0.26, C.skin, 0, 1, 2)
		shape(f, spec[1], 0.72, 0.36, 0.36, spec[2], 0, 0.6, 2)
	end
end
DRAW.Streak = function(f)
	shape(f, 0.5, 0.56, 0.84, 0.72, C.paper, 0, 0.15, 2)
	shape(f, 0.5, 0.26, 0.84, 0.16, C.red, 0, 0.15, 2)
	for k = 0, 5 do
		shape(f, 0.26 + (k % 3) * 0.24, 0.5 + (k // 3) * 0.2, 0.12, 0.12, if k < 4 then C.gold else C.metal, 0, 1, 0)
	end
end
DRAW.Pockets = function(f)
	shape(f, 0.5, 0.6, 0.72, 0.56, C.woodDark, 0, 0.5, 2)
	shape(f, 0.5, 0.36, 0.5, 0.14, C.wood, 0, 0.5, 2)
	coin(f, 0.5, 0.62, 0.3)
end
DRAW.NightEyes = function(f)
	shape(f, 0.5, 0.5, 0.84, 0.5, C.white, 0, 1, 2)
	shape(f, 0.5, 0.5, 0.36, 0.36, C.blue, 0, 1, 2)
	shape(f, 0.5, 0.5, 0.14, 0.14, INK, 0, 1, 0)
end
DRAW.Prestige = function(f)
	shape(f, 0.5, 0.52, 0.8, 0.8, C.gold, 0, 1, 2)
	star(f, 0.5, 0.52, 0.36, C.cream)
end
DRAW.Vault = function(f)
	shape(f, 0.5, 0.55, 0.8, 0.7, C.wood, 0, 0.1, 2)
	shape(f, 0.5, 0.55, 0.9, 0.08, C.woodDark, 38, 0, 0)
	shape(f, 0.5, 0.55, 0.9, 0.08, C.woodDark, -38, 0, 0)
	shape(f, 0.5, 0.25, 0.84, 0.12, C.woodDark, 0, 0, 2)
end
DRAW.Tier = function(f)
	box(f, 0.5, 0.56, 0.62, C.purple)
end

-- Draws icon `name` into `frame` (a square). Unknown names draw a plain gift box.
function Icons.draw(name: string, frame: Frame)
	local draw = DRAW[name] or DRAW.Rewards
	draw(frame)
end

function Icons.has(name: string): boolean
	return DRAW[name] ~= nil
end

return Icons
