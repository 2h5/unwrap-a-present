--[=[
	Widgets (client, part of HUD)
	Owns: the few greybox UI builders every HUD screen uses: rounded frames, labels, big tap-target
	buttons, list layouts, and a screen frame with a title and a Close button.
	Must never: hold state or talk to the server. Screens do that.
	Read first: src/client/HUD/README.md
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)

local Widgets = {}

Widgets.DARK = Color3.fromHex(Config.HUD.barColor)
Widgets.BUTTON = Color3.fromHex(Config.HUD.buttonColor)
Widgets.PANEL = Color3.fromHex(Config.HUD.shopColor)

function Widgets.make(className: string, props: { [string]: any }): any
	local object = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(object :: any)[key] = value
		end
	end
	if object:IsA("GuiObject") and className ~= "ScrollingFrame" then
		Instance.new("UICorner").Parent = object
	end
	object.Parent = props.Parent
	return object
end

function Widgets.text(parent: Instance, value: string, size: UDim2, order: number?): TextLabel
	return Widgets.make("TextLabel", {
		Parent = parent,
		Size = size,
		LayoutOrder = order or 0,
		Text = value,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
	})
end

function Widgets.button(parent: Instance, value: string, size: UDim2, onTap: () -> ()): TextButton
	local b = Widgets.make("TextButton", {
		Parent = parent,
		Size = size,
		Text = value,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		BackgroundColor3 = Widgets.BUTTON,
	})
	b.Activated:Connect(onTap)
	return b
end

-- Greys a button out when it cannot be used (the server still decides).
function Widgets.enable(b: TextButton, on: boolean)
	b.AutoButtonColor = on
	b.BackgroundTransparency = if on then 0 else 0.6
	b.TextTransparency = if on then 0 else 0.45
end

function Widgets.list(parent: Instance, horizontal: boolean?, wraps: boolean?): UIListLayout
	return Widgets.make("UIListLayout", {
		Parent = parent,
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Wraps = wraps or false,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})
end

-- A centred screen: title on top, a scrolling body, Close at the bottom. Returns frame, title, body.
function Widgets.screen(gui: Instance, name: string, color: Color3): (Frame, TextLabel, ScrollingFrame)
	local frame = Widgets.make("Frame", {
		Parent = gui,
		Name = name,
		Size = UDim2.fromScale(0.6, 0.75),
		Position = UDim2.fromScale(0.2, 0.12),
		BackgroundColor3 = color,
		Visible = false,
	})
	Widgets.list(frame)
	local title = Widgets.text(frame, name, UDim2.fromScale(0.95, 0.1), 1)
	local body = Widgets.make("ScrollingFrame", {
		Parent = frame,
		Size = UDim2.fromScale(0.95, 0.72),
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 8,
	})
	Widgets.list(body)
	local close = Widgets.button(frame, "Close", UDim2.fromScale(0.4, 0.1), function()
		frame.Visible = false
	end)
	close.LayoutOrder = 3
	return frame, title, body
end

-- Removes every row a screen built last time (keeps its layout).
function Widgets.clear(body: Instance)
	for _, child in body:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- A row: label on the left, then buttons. Returns the row frame.
function Widgets.row(parent: Instance, order: number, label: string, buttons: { { text: string, on: boolean?, tap: () -> () } }): Frame
	local row = Widgets.make("Frame", { Parent = parent, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = order, BackgroundTransparency = 1 })
	Widgets.list(row, true)
	local width = if #buttons > 0 then 0.5 else 1
	Widgets.text(row, label, UDim2.new(width, -6, 1, 0))
	for _, spec in buttons do
		local b = Widgets.button(row, spec.text, UDim2.new((1 - width) / #buttons, -6, 1, 0), spec.tap)
		Widgets.enable(b, spec.on ~= false)
	end
	return row
end

return Widgets
