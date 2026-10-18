--[=[
	Widgets (client, part of HUD)
	Owns: the UI kit every HUD screen uses (Art bible B, Table 13): wooden panels with rounded
	corners and a dark outline, parchment cards, chunky buttons with a pressed edge, gift-tag titles
	on twine, chips, a round hold ring, gift viewports, scrolling lists and the modal screen frame
	(tag title, round close button, wooden body). Colours and the one rounded font come from
	Config.UI; chrome never uses a present or rarity colour. Every control is a large tap target.
	Must never: hold state or talk to the server. Screens do that.
	Read first: src/client/HUD/README.md
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Art = require(ReplicatedStorage.Shared.Art.Art)
local GiftModels = require(ReplicatedStorage.Shared.Art.GiftModels)
local Icons = require(script.Parent.Icons)

local Widgets = {}

local UI = Config.UI

local function hex(name: string): Color3
	return Color3.fromHex(UI[name])
end

Widgets.C = {
	woodDark = hex("woodDark"),
	woodMid = hex("woodMid"),
	woodLight = hex("woodLight"),
	parchment = hex("parchment"),
	ink = hex("ink"),
	cream = hex("cream"),
	twine = hex("twine"),
	action = hex("action"),
	close = hex("close"),
	disabled = hex("disabled"),
}
Widgets.FONT = Enum.Font[UI.font]
Widgets.SIZE = { S = UI.textSizes[1], M = UI.textSizes[2], L = UI.textSizes[3] }

function Widgets.make(className: string, props: { [string]: any }): any
	local object = Instance.new(className)
	local corner = props.Corner
	for key, value in props do
		if key ~= "Parent" and key ~= "Corner" then
			(object :: any)[key] = value
		end
	end
	if object:IsA("GuiObject") then
		object.BorderSizePixel = 0
		if corner ~= false and className ~= "ScrollingFrame" then
			local c = Instance.new("UICorner")
			c.CornerRadius = if typeof(corner) == "UDim" then corner else UDim.new(0, UI.cornerPx)
			c.Parent = object
		end
	end
	object.Parent = props.Parent
	return object
end

function Widgets.stroke(object: Instance, color: Color3?, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or Widgets.C.woodDark
	s.Thickness = thickness or UI.strokePx
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = object
	return s
end

function Widgets.padding(object: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop, p.PaddingBottom = UDim.new(0, px), UDim.new(0, px)
	p.PaddingLeft, p.PaddingRight = UDim.new(0, px), UDim.new(0, px)
	p.Parent = object
end

function Widgets.aspect(object: Instance, ratio: number)
	local a = Instance.new("UIAspectRatioConstraint")
	a.AspectRatio = ratio
	a.Parent = object
end

-- A label. `tier` "S" | "M" | "L" caps the text size; `ink` draws dark text for parchment.
function Widgets.text(parent: Instance, value: string, size: UDim2, order: number?, tier: string?, ink: boolean?): TextLabel
	local label = Widgets.make("TextLabel", {
		Parent = parent,
		Size = size,
		LayoutOrder = order or 0,
		Text = value,
		TextScaled = true,
		Font = Widgets.FONT,
		TextColor3 = if ink then Widgets.C.ink else Widgets.C.cream,
		BackgroundTransparency = 1,
		Corner = false,
	})
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = Widgets.SIZE[tier or "M"]
	cap.MinTextSize = 8
	cap.Parent = label
	if not ink then
		Widgets.stroke(label, Widgets.C.woodDark, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	end
	return label
end

-- A wooden panel: a dark outline, a mid-wood frame and a lighter face with a soft top light.
-- Returns the panel and its face (put content in the face).
function Widgets.wood(parent: Instance, size: UDim2, position: UDim2?, name: string?): (Frame, Frame)
	local panel = Widgets.make("Frame", { Parent = parent, Name = name or "Wood", Size = size, Position = position or UDim2.new(), BackgroundColor3 = Widgets.C.woodMid })
	Widgets.stroke(panel, Widgets.C.woodDark, UI.strokePx + 1)
	local face = Widgets.make("Frame", { Parent = panel, Name = "Face", Size = UDim2.new(1, -12, 1, -12), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = Widgets.C.woodLight })
	local light = Instance.new("UIGradient")
	light.Rotation = 90
	light.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 205, 195))
	light.Parent = face
	return panel, face
end

-- A parchment card with a dark outline and a dropped edge. Returns the card.
function Widgets.card(parent: Instance, size: UDim2, order: number?): Frame
	local card = Widgets.make("Frame", { Parent = parent, Name = "Card", Size = size, LayoutOrder = order or 0, BackgroundColor3 = Widgets.C.parchment })
	Widgets.stroke(card, Widgets.C.woodDark, 2)
	return card
end

-- A chunky button: a darker pressed edge under a bright face. `style` "action" (default), "wood",
-- "close" or "chip". Presses sink the face; `Widgets.enable` greys it out (the server still decides).
function Widgets.button(parent: Instance, value: string, size: UDim2, onTap: () -> (), style: string?): TextButton
	local colors = { action = Widgets.C.action, wood = Widgets.C.woodLight, close = Widgets.C.close, chip = Widgets.C.parchment }
	local face = colors[style or "action"] or Widgets.C.action
	local holder = Widgets.make("Frame", { Parent = parent, Name = "Button", Size = size, BackgroundColor3 = face:Lerp(Color3.new(0, 0, 0), 0.35) })
	Widgets.stroke(holder, Widgets.C.woodDark, 2)
	local b = Widgets.make("TextButton", {
		Parent = holder,
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -5),
		BackgroundColor3 = face,
		Text = value,
		TextScaled = true,
		Font = Widgets.FONT,
		TextColor3 = if style == "chip" then Widgets.C.ink else Widgets.C.cream,
		AutoButtonColor = false,
	})
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = Widgets.SIZE.M
	cap.Parent = b
	if style ~= "chip" then
		Widgets.stroke(b, Widgets.C.woodDark, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	end
	Widgets.padding(b, 4)
	local shine = Instance.new("UIGradient")
	shine.Rotation = 90
	shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(225, 215, 205))
	shine.Parent = b
	b.Activated:Connect(function()
		if not b:GetAttribute("Off") then
			onTap()
		end
	end)
	b.MouseButton1Down:Connect(function()
		b.Position = UDim2.fromOffset(0, 3)
	end)
	b.MouseButton1Up:Connect(function()
		b.Position = UDim2.new()
	end)
	b.MouseLeave:Connect(function()
		b.Position = UDim2.new()
	end)
	b:SetAttribute("Face", face:ToHex())
	return b
end

-- Greys a button out when it cannot be used (the server still decides).
function Widgets.enable(b: TextButton, on: boolean)
	b.Active = on
	b:SetAttribute("Off", not on)
	b.AutoButtonColor = false
	local face = b:GetAttribute("Face")
	b.BackgroundColor3 = if on and face then Color3.fromHex(face) else Widgets.C.disabled
	b.TextTransparency = if on then 0 else 0.35
end

function Widgets.list(parent: Instance, horizontal: boolean?, wraps: boolean?, padding: number?): UIListLayout
	return Widgets.make("UIListLayout", {
		Parent = parent,
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Wraps = wraps or false,
		Padding = UDim.new(0, padding or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = if horizontal then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top,
	})
end

function Widgets.scroll(parent: Instance, size: UDim2, position: UDim2?): ScrollingFrame
	local s = Widgets.make("ScrollingFrame", {
		Parent = parent,
		Size = size,
		Position = position or UDim2.new(),
		BackgroundTransparency = 1,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 10,
		ScrollBarImageColor3 = Widgets.C.woodDark,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	})
	Widgets.padding(s, 6)
	return s
end

-- A small rounded pill: rarity names, counts, prices. `color` is its fill.
function Widgets.chip(parent: Instance, value: string, color: Color3, size: UDim2, order: number?): TextLabel
	local chip = Widgets.make("TextLabel", {
		Parent = parent,
		Size = size,
		LayoutOrder = order or 0,
		BackgroundColor3 = color,
		Text = value,
		TextScaled = true,
		Font = Widgets.FONT,
		TextColor3 = Widgets.C.cream,
		Corner = UDim.new(0.5, 0),
	})
	Widgets.stroke(chip, Widgets.C.woodDark, 2)
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = Widgets.SIZE.S
	cap.Parent = chip
	Widgets.padding(chip, 3)
	return chip
end

-- An illustration slot: the final image from Art if it exists (`slot`, else Icon<name>), else the
-- code-drawn icon.
function Widgets.icon(parent: Instance, name: string, size: UDim2, position: UDim2?, slot: string?): Frame
	local frame = Widgets.make("Frame", { Parent = parent, Name = "Icon", Size = size, Position = position or UDim2.new(), BackgroundTransparency = 1, Corner = false })
	Widgets.aspect(frame, 1)
	local image = Art.image(slot or `Icon{name}`)
	if image then
		Widgets.make("ImageLabel", { Parent = frame, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = image, ScaleType = Enum.ScaleType.Fit, Corner = false })
	else
		Icons.draw(name, frame)
	end
	return frame
end

-- A gift's picture: its final icon from Art if it exists, else its toy in a viewport.
function Widgets.gift(parent: Instance, giftId: string, rarity: string, mutation: string?, size: UDim2, position: UDim2?): GuiObject
	local image = Art.giftImage(giftId)
	if image then
		return Widgets.make("ImageLabel", { Parent = parent, Size = size, Position = position or UDim2.new(), BackgroundTransparency = 1, Image = image, ScaleType = Enum.ScaleType.Fit, Corner = false })
	end
	local view = Widgets.make("ViewportFrame", {
		Parent = parent,
		Name = "Gift",
		Size = size,
		Position = position or UDim2.new(),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 190, 180),
		LightColor = Color3.fromRGB(255, 244, 230),
		LightDirection = Vector3.new(-1, -1.5, -1),
		Corner = false,
	})
	Widgets.aspect(view, 1)
	local toy = GiftModels.build(giftId, rarity, { studs = 1, mutation = if mutation ~= "" then mutation else nil, static = true })
	if rarity == "Secret" then
		for _, part in GiftModels.baseParts(toy) do
			part.Color = Color3.fromHSV(0.8, 0.45, 1)
		end
	end
	toy.Parent = view
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local mid = Vector3.new(0, 0.5, 0)
	camera.CFrame = CFrame.lookAt(mid + Vector3.new(1.4, 0.9, -2.2), mid)
	camera.Parent = view
	view.CurrentCamera = camera
	return view
end

-- A gift-tag title: a parchment tag with a punched hole on the left and twine above it.
function Widgets.tag(parent: Instance, value: string, size: UDim2, position: UDim2?): (Frame, TextLabel)
	local tag = Widgets.make("Frame", { Parent = parent, Name = "Tag", Size = size, Position = position or UDim2.new(), BackgroundColor3 = Widgets.C.parchment, Corner = UDim.new(0, 10) })
	Widgets.stroke(tag, Widgets.C.woodDark, UI.strokePx)
	local hole = Widgets.make("Frame", { Parent = tag, Name = "Hole", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 16, 0.5, 0), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Widgets.C.woodDark, Corner = UDim.new(0.5, 0) })
	local twine = Widgets.make("Frame", { Parent = tag, Name = "Twine", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0, 16, 0.5, -4), Size = UDim2.new(0, 4, 0.9, 0), BackgroundColor3 = Widgets.C.twine, Rotation = -18, ZIndex = 0, Corner = false })
	Widgets.stroke(twine, Widgets.C.woodDark, 1)
	hole.ZIndex = 2
	local label = Widgets.text(tag, value, UDim2.new(1, -40, 1, -8), nil, "L", true)
	label.Position = UDim2.fromOffset(32, 4)
	label.TextXAlignment = Enum.TextXAlignment.Left
	return tag, label
end

-- A round hold ring around `parent`: returns a setter for its fill (0 to 1). Drawn with two halves,
-- each a ring whose stroke is cut by a hard-edged gradient (the HoldRing image replaces it later).
function Widgets.ring(parent: Instance, thickness: number, color: Color3): (progress: number) -> ()
	local holder = Widgets.make("Frame", { Parent = parent, Name = "HoldRing", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Corner = false })
	local halves = {}
	for i, side in { "Right", "Left" } do
		local clip = Widgets.make("Frame", { Parent = holder, Name = side, Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale(if side == "Right" then 0.5 else 0, 0), BackgroundTransparency = 1, ClipsDescendants = true, Corner = false })
		-- Inset by the stroke so the clip (which also clips strokes) keeps the whole ring.
		local ring = Widgets.make("Frame", { Parent = clip, Size = UDim2.new(2, -2 * thickness, 1, -2 * thickness), Position = UDim2.new(if side == "Right" then -1 else 0, thickness, 0, thickness), BackgroundTransparency = 1, Corner = UDim.new(0.5, 0) })
		local s: Instance
		local image = Art.image("HoldRing")
		if image then
			s = Widgets.make("ImageLabel", { Parent = clip, Size = UDim2.fromScale(2, 1), Position = UDim2.fromScale(if side == "Right" then -1 else 0, 0), BackgroundTransparency = 1, Image = image, ImageColor3 = color, Corner = false })
			ring:Destroy()
		else
			s = Widgets.stroke(ring, color, thickness)
		end
		local cut = Instance.new("UIGradient")
		cut.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.499, 0),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		cut.Parent = s
		halves[i] = cut
	end
	local function set(progress: number)
		local p = math.clamp(progress, 0, 1)
		-- The opaque half of each gradient turns clockwise from 12 o'clock: the right half fills over
		-- the first half of the hold, the left over the second.
		halves[1].Rotation = math.min(p, 0.5) * 360
		halves[2].Rotation = math.max(p, 0.5) * 360
		holder.Visible = p > 0
	end
	set(0)
	return set
end

-- A modal screen: a wooden frame centred on screen, a gift-tag title over its top-left edge, a round
-- close button on its top-right corner, and a body. Returns frame, title label, body, close button.
function Widgets.screen(gui: Instance, name: string, title: string?): (Frame, TextLabel, Frame, TextButton)
	local frame, face = Widgets.wood(gui, UDim2.fromScale(0.88, 0.8), nil, name)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.54)
	frame.Visible = false
	frame.ZIndex = 10
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(1040, 660)
	limit.Parent = frame
	local tag, label = Widgets.tag(frame, title or name, UDim2.new(0.34, 0, 0, 52), UDim2.new(0, 18, 0, -30))
	tag.ZIndex = 12
	local closeHolder = Widgets.make("Frame", { Parent = frame, Name = "Close", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(56, 56), BackgroundTransparency = 1, Corner = false })
	local close = Widgets.button(closeHolder, "", UDim2.fromScale(1, 1), function()
		frame.Visible = false
	end, "close")
	close.Parent.ZIndex = 13
	Widgets.icon(close, "Close", UDim2.fromScale(0.6, 0.6), UDim2.fromScale(0.2, 0.18))
	for _, round in { close, close.Parent } do
		local c = round:FindFirstChildOfClass("UICorner")
		if c then
			c.CornerRadius = UDim.new(0.5, 0)
		end
	end
	local body = Widgets.make("Frame", { Parent = face, Name = "Body", Size = UDim2.new(1, -16, 1, -40), Position = UDim2.fromOffset(8, 32), BackgroundTransparency = 1, Corner = false })
	-- One screen at a time: showing this one hides the others; a gentle pop in when shown.
	frame:SetAttribute("Screen", true)
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if frame.Visible then
			for _, other in gui:GetChildren() do
				if other ~= frame and other:GetAttribute("Screen") and other:IsA("GuiObject") then
					other.Visible = false
				end
			end
			scale.Scale = 0.92
			TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end)
	return frame, label, body, close
end

-- Calls `onPress` when keyboard key `key` (a KeyCode name) is pressed outside a text box or chat.
function Widgets.onKey(key: string, onPress: () -> ())
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode[key] then
			onPress()
		end
	end)
end

-- Removes every row a screen built last time (keeps its layouts and padding).
function Widgets.clear(body: Instance)
	for _, child in body:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- A wide parchment card in a list: an icon on the left (an icon name, or a function that draws into a
-- 56 px square, e.g. a gift viewport), a title and a line of detail, and up to two buttons on the
-- right. Returns the card and its detail label.
function Widgets.rowCard(parent: Instance, order: number, icon: (string | (Frame) -> ())?, title: string, detail: string?, buttons: { { text: string, on: boolean?, tap: () -> (), style: string? } }): (Frame, TextLabel?)
	local card = Widgets.card(parent, UDim2.new(1, -8, 0, 74), order)
	local x = 10
	if typeof(icon) == "function" then
		local slot = Widgets.make("Frame", { Parent = card, Name = "Art", Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(10, 9), BackgroundTransparency = 1, Corner = false })
		icon(slot)
		x = 76
	elseif icon then
		Widgets.icon(card, icon, UDim2.fromOffset(56, 56), UDim2.fromOffset(10, 9))
		x = 76
	end
	local buttonW = 0.24
	local textW = 1 - buttonW * #buttons
	local name = Widgets.text(card, title, UDim2.new(textW, -x - 6, if detail then 0.5 else 0.8, 0), nil, "M", true)
	name.Position = UDim2.new(0, x, if detail then 0.08 else 0.1, 0)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local line
	if detail then
		line = Widgets.text(card, detail, UDim2.new(textW, -x - 6, 0.34, 0), nil, "S", true)
		line.Position = UDim2.new(0, x, 0.56, 0)
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.TextColor3 = Widgets.C.woodMid
	end
	for i, spec in buttons do
		local holder = Widgets.make("Frame", { Parent = card, Size = UDim2.new(buttonW, -10, 0, 52), Position = UDim2.new(textW + buttonW * (i - 1), 2, 0.5, -26), BackgroundTransparency = 1, Corner = false })
		local b = Widgets.button(holder, spec.text, UDim2.fromScale(1, 1), spec.tap, spec.style)
		Widgets.enable(b, spec.on ~= false)
	end
	return card, line
end

-- The column on the right edge that holds the big round buttons, one per screen, in `order`.
local function sideBar(gui: Instance): Frame
	local bar = gui:FindFirstChild("SideButtons")
	if bar then
		return bar :: Frame
	end
	bar = Widgets.make("Frame", { Parent = gui, Name = "SideButtons", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromScale(0.1, 0.72), BackgroundTransparency = 1, Corner = false })
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize, limit.MaxSize = Vector2.new(52, 250), Vector2.new(100, 520)
	limit.Parent = bar
	Widgets.list(bar, false, false, 6).VerticalAlignment = Enum.VerticalAlignment.Center
	return bar :: Frame
end

-- A big round button on the right edge (Table 13): an icon, its name under it and its key letter
-- (shown when there is a keyboard). `order` places it in the column.
function Widgets.sideButton(gui: Instance, name: string, label: string, key: string, order: number, onTap: () -> ()): TextButton
	local holder = Widgets.make("Frame", { Parent = sideBar(gui), Name = `{name}Button`, LayoutOrder = order, Size = UDim2.new(1, 0, 0.25, -6), BackgroundTransparency = 1, Corner = false })
	Widgets.aspect(holder, 0.82)
	local roundHolder = Widgets.make("Frame", { Parent = holder, Size = UDim2.fromScale(1, 0.82), BackgroundTransparency = 1, Corner = false })
	local b = Widgets.button(roundHolder, "", UDim2.fromScale(1, 1), onTap, "wood")
	for _, round in { b, b.Parent } do
		local c = round:FindFirstChildOfClass("UICorner")
		if c then
			c.CornerRadius = UDim.new(0.5, 0)
		end
	end
	Widgets.icon(b, name, UDim2.fromScale(0.64, 0.64), UDim2.fromScale(0.18, 0.14), `Icon{name}`)
	local caption = Widgets.text(holder, label, UDim2.fromScale(1.3, 0.24), nil, "S")
	caption.AnchorPoint = Vector2.new(0.5, 0)
	caption.Position = UDim2.fromScale(0.5, 0.74)
	local keyChip = Widgets.chip(holder, key, Widgets.C.woodDark, UDim2.fromScale(0.34, 0.2))
	keyChip.Position = UDim2.fromScale(0.7, 0.56)
	keyChip.Visible = UserInputService.KeyboardEnabled
	return b
end

return Widgets
