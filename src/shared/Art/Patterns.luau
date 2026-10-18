--[=[
	Patterns (shared, used by client systems)
	Owns: the look of wrapping paper and cardboard on one part's front face (the face that points out of
	the present): the six launch paper patterns (Table 12, one per paper colour) and the cardboard print
	(arrows and a barcode). With a final tile in Art, a Texture; until then a placeholder drawn in code
	on a SurfaceGui, in one lighter and one darker step of the part's own colour, never a second hue.
	Patterns repeat a whole number of times per panel, so neighbouring panels line up.
	Must never: put a stud, bevel or dot relief on paper (invariant 4: printed dots are flat), or run on
	the server (SurfaceGuis are local to each client).
	Read first: src/shared/README.md
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Art = require(ReplicatedStorage.Shared.Art.Art)

local Patterns = {}

local P = Config.PaperLook
local LOOK = "PaperLook"

type Drawn = { light: { GuiObject }, dark: { GuiObject }, gradients: { UIGradient }, connection: RBXScriptConnection? }

local drawn: { [BasePart]: Drawn } = setmetatable({}, { __mode = "k" }) :: any

-- The lighter and darker steps of `color`'s own hue.
function Patterns.steps(color: Color3): (Color3, Color3)
	local h, s, v = color:ToHSV()
	local light = Color3.fromHSV(h, math.max(0, s - P.step), math.min(1, v + P.step))
	local dark = Color3.fromHSV(h, math.min(1, s + P.step / 2), math.max(0, v - P.step))
	return light, dark
end

local function frame(parent: Instance, x: number, y: number, w: number, h: number, rotation: number?): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.Rotation = rotation or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function round(f: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = f
end

-- A square canvas must keep its aspect for rotated shapes: shapes are sized in units of the shorter side.
local function aspect(canvas: Frame)
	local a = Instance.new("UIAspectRatioConstraint")
	a.AspectRatio = 1
	a.Parent = canvas
end

---------------------------------------------------------------- the six patterns

local DRAW = {}

-- Candy stripes at 45°: hard-edged bands from one transparency gradient.
function DRAW.Stripes(canvas: Frame, n: number, d: Drawn)
	local band = frame(canvas, 0.5, 0.5, math.sqrt(2), math.sqrt(2), 45)
	table.insert(d.light, band)
	local bands = 4 * n -- light, clear, light, clear ... along the diagonal
	local keys = { NumberSequenceKeypoint.new(0, 0) }
	for i = 1, bands - 1 do
		local t = i / bands
		local was = if i % 2 == 1 then 0 else 1
		table.insert(keys, NumberSequenceKeypoint.new(t - 0.001, was))
		table.insert(keys, NumberSequenceKeypoint.new(t, 1 - was))
	end
	table.insert(keys, NumberSequenceKeypoint.new(1, if bands % 2 == 0 then 1 else 0))
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new(keys)
	gradient.Parent = band
end

-- Polka dots: light dots with a darker rim.
function DRAW.PolkaDots(canvas: Frame, n: number, d: Drawn)
	for i = 1, n do
		for j = 1, n do
			local dot = frame(canvas, (i - 0.5) / n, (j - 0.5) / n, 0.42 / n, 0.42 / n)
			round(dot)
			local rim = Instance.new("UIStroke")
			rim.Thickness = 2
			rim.Parent = dot
			table.insert(d.light, dot)
			table.insert(d.dark, rim :: any)
		end
	end
end

-- Snowflakes: three crossing bars per flake, with a dark heart.
function DRAW.Snowflakes(canvas: Frame, n: number, d: Drawn)
	for i = 1, n do
		for j = 1, n do
			local x, y = (i - 0.5) / n, (j - 0.5) / n
			for _, angle in { 0, 60, 120 } do
				table.insert(d.light, frame(canvas, x, y, 0.5 / n, 0.07 / n, angle))
			end
			local heart = frame(canvas, x, y, 0.12 / n, 0.12 / n, 45)
			table.insert(d.dark, heart)
		end
	end
end

-- Zigzag: n rows of light chevrons that run edge to edge.
function DRAW.Zigzag(canvas: Frame, n: number, d: Drawn)
	local teeth = 2 * n
	local rise = 0.35 / n
	local length = math.sqrt((1 / teeth) ^ 2 + rise ^ 2)
	local angle = math.deg(math.atan2(rise, 1 / teeth))
	for row = 1, n do
		local y = (row - 0.5) / n
		for k = 1, teeth do
			local x = (k - 0.5) / teeth
			local up = k % 2 == 1
			table.insert(d.light, frame(canvas, x, y, length * 1.04, 0.09 / n, if up then -angle else angle))
		end
	end
end

-- Stars: eight-point stars from two squares, light, with a dark centre.
function DRAW.Stars(canvas: Frame, n: number, d: Drawn)
	for i = 1, n do
		for j = 1, n do
			local x, y = (i - 0.5) / n, (j - 0.5) / n
			table.insert(d.light, frame(canvas, x, y, 0.36 / n, 0.36 / n, 0))
			table.insert(d.light, frame(canvas, x, y, 0.36 / n, 0.36 / n, 45))
			local centre = frame(canvas, x, y, 0.1 / n, 0.1 / n)
			round(centre)
			table.insert(d.dark, centre)
		end
	end
end

-- Plaid: crossing light bands with thin dark lines.
function DRAW.Plaid(canvas: Frame, n: number, d: Drawn)
	for k = 1, n do
		local c = (k - 0.5) / n
		local h = frame(canvas, 0.5, c, 1, 0.3 / n)
		local v = frame(canvas, c, 0.5, 0.3 / n, 1)
		h.BackgroundTransparency, v.BackgroundTransparency = 0.45, 0.45
		table.insert(d.light, h)
		table.insert(d.light, v)
		table.insert(d.dark, frame(canvas, 0.5, c, 1, 0.03 / n))
		table.insert(d.dark, frame(canvas, c, 0.5, 0.03 / n, 1))
	end
end

---------------------------------------------------------------- apply

local function recolor(part: BasePart, d: Drawn)
	local light, dark = Patterns.steps(part.Color)
	for _, object in d.light do
		object.BackgroundColor3 = light
	end
	for _, object in d.dark do
		if object:IsA("UIStroke") then
			(object :: any).Color = dark
		else
			object.BackgroundColor3 = dark
		end
	end
end

-- Removes whatever look `part` was given.
function Patterns.clear(part: BasePart)
	local d = drawn[part]
	if d and d.connection then
		d.connection:Disconnect()
	end
	drawn[part] = nil
	for _, child in part:GetChildren() do
		if child.Name == LOOK then
			child:Destroy()
		end
	end
end

local function surface(part: BasePart): (SurfaceGui, Frame)
	local gui = Instance.new("SurfaceGui")
	gui.Name = LOOK
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = P.pixelsPerStud
	gui.LightInfluence = 1
	gui.MaxDistance = P.maxDrawStuds
	gui.ClipsDescendants = true
	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.BackgroundTransparency = 1
	canvas.ClipsDescendants = true
	canvas.Parent = gui
	return gui, canvas
end

local function seams(canvas: Frame, d: Drawn)
	-- The panel's edges in the darker step: the grid of tear targets reads from across the room.
	for _, spec in { { 0.5, 0, 1, 0.04 }, { 0.5, 1, 1, 0.04 }, { 0, 0.5, 0.04, 1 }, { 1, 0.5, 0.04, 1 } } do
		local edge = frame(canvas, spec[1], spec[2], spec[3], spec[4])
		edge.BackgroundTransparency = P.seamTransparency
		table.insert(d.dark, edge)
	end
end

-- Gives `part` the paper pattern `name` ("Stripes", "PolkaDots", ...), repeated `repeats` times across
-- its front face (default Config.PaperLook.repeatsPerPanel). Follows the part's Color (Night desaturation).
function Patterns.apply(part: BasePart, name: string, repeats: number?)
	Patterns.clear(part)
	local n = repeats or P.repeatsPerPanel
	local tile = Art.image(`Paper{name}`)
	if tile then
		local texture = Instance.new("Texture")
		texture.Name = LOOK
		texture.Face = Enum.NormalId.Front
		texture.Texture = tile
		texture.StudsPerTileU = part.Size.X / n
		texture.StudsPerTileV = part.Size.Y / n
		texture.Parent = part
		return
	end
	local draw = DRAW[name]
	if not draw then
		return
	end
	local gui, canvas = surface(part)
	local d: Drawn = { light = {}, dark = {}, gradients = {}, connection = nil }
	aspect(canvas)
	draw(canvas, n, d)
	seams(canvas, d)
	recolor(part, d)
	d.connection = part:GetPropertyChangedSignal("Color"):Connect(function()
		recolor(part, d)
	end)
	drawn[part] = d
	gui.Parent = part
end

-- The cardboard print on `part`'s front face: two "this way up" arrows and a barcode (Table 12).
function Patterns.print(part: BasePart)
	Patterns.clear(part)
	local tile = Art.image("CardboardPrint")
	if tile then
		local decal = Instance.new("Decal")
		decal.Name = LOOK
		decal.Face = Enum.NormalId.Front
		decal.Texture = tile
		decal.Parent = part
		return
	end
	local gui, canvas = surface(part)
	aspect(canvas)
	local ink = Color3.fromHex(P.printColor)
	local function inked(f: Frame)
		f.BackgroundColor3 = ink
		f.BackgroundTransparency = 0.15
	end
	-- Two arrows, upper left: a shaft and a chevron head each.
	for k = 0, 1 do
		local x = 0.12 + k * 0.1
		inked(frame(canvas, x, 0.22, 0.025, 0.16))
		inked(frame(canvas, x - 0.022, 0.15, 0.06, 0.022, -45))
		inked(frame(canvas, x + 0.022, 0.15, 0.06, 0.022, 45))
	end
	-- Barcode, lower right: bars of three widths from a fixed rhythm.
	local widths = { 2, 1, 1, 3, 1, 2, 1, 1, 2, 3, 1, 2 }
	local x = 0.62
	for i, w in widths do
		local width = w * 0.006
		if i % 2 == 1 then
			inked(frame(canvas, x + width / 2, 0.82, width, 0.12))
		end
		x += width + 0.004
	end
	gui.Parent = part
end

-- Copies `from`'s look onto `to` (a torn piece keeps its paper).
function Patterns.copy(from: BasePart, to: BasePart)
	local name = from:GetAttribute("Pattern")
	if typeof(name) == "string" then
		Patterns.apply(to, name, from:GetAttribute("PatternRepeats") :: number?)
	elseif from:GetAttribute("Print") then
		Patterns.print(to)
	else
		Patterns.clear(to)
	end
end

-- Hides or shows a part's look (a torn panel is see-through on the server, its look must follow).
function Patterns.setVisible(part: BasePart, on: boolean)
	for _, child in part:GetChildren() do
		if child.Name == LOOK then
			if child:IsA("SurfaceGui") then
				child.Enabled = on
			elseif child:IsA("Texture") or child:IsA("Decal") then
				child.Transparency = if on then 0 else 1
			end
		end
	end
end

return Patterns
