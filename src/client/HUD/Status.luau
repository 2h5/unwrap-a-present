--[=[
	Status (client, part of HUD)
	Owns: the always-on HUD of Art bible B / PLAN-TABLES Table 13: cash top left, depth top centre as a
	stack of coloured bars (layer n of N), tool bottom centre with the hold ring, party on the left edge
	(name, class, down state), and one prompt in the bottom third.
	Must never: Compute a value it displays. Cash, the tool, the class and the layer colours are
	attributes the server sets; the hold ring follows this player's TearState.
	Read first: src/client/HUD/README.md
]=]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local Widgets = require(script.Parent.Widgets)

local Status = {}

local player = Players.LocalPlayer
local cashLabel: TextLabel
local depthFrame: Frame
local depthLabel: TextLabel
local toolLabel: TextLabel
local ringFill: Frame
local partyFrame: Frame
local promptButton: TextButton
local shownPrompt: ProximityPrompt? = nil
local hold: { from: number, seconds: number, at: number }? = nil
local nightEndsAt: number? = nil -- os.clock() when the Night ends, from NightState

local TOOL_NAMES = { Hands = "Hands", Scissors = "Scissors", BoxCutter = "Box cutter", Chainsaw = "Chainsaw" }

local function present(): Instance?
	return workspace:FindFirstChild("Present")
end

local function panel(name: string, size: UDim2, pos: UDim2): TextLabel
	local l = Widgets.text(nil :: any, "", size)
	l.Name = name
	l.Position = pos
	l.BackgroundColor3 = Widgets.DARK
	l.BackgroundTransparency = 0.25
	return l
end

---------------------------------------------------------------- refresh

function Status.refresh()
	cashLabel.Text = `Cash {player:GetAttribute("Cash") or 0}`
	toolLabel.Text = TOOL_NAMES[player:GetAttribute("Tool") or "Hands"] or "Hands"

	for _, child in depthFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local p = present()
	local count = p and p:GetAttribute("LayerCount") or 0
	local depth = p and p:GetAttribute("CurrentDepth") or 0
	local colors = string.split(p and p:GetAttribute("LayerColors") or "", ",")
	depthLabel.Text = `Layer {math.min(depth + 1, count)} / {count}`
	depthLabel.TextColor3 = Color3.new(1, 1, 1)
	for d = 0, count - 1 do
		local bar = Widgets.make("Frame", {
			Parent = depthFrame,
			LayoutOrder = d,
			Size = UDim2.new(1, 0, 1 / math.max(count, 1), -2),
			BackgroundColor3 = if colors[d + 1] and colors[d + 1] ~= "" then Color3.fromHex(colors[d + 1]) else Widgets.DARK,
			BackgroundTransparency = if d < depth then 0.85 elseif d == depth then 0 else 0.45,
		})
		if d == depth then
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.new(1, 1, 1)
			stroke.Thickness = 2
			stroke.Parent = bar
		end
	end
end

local function refreshParty()
	Widgets.clear(partyFrame)
	for i, other in Players:GetPlayers() do
		local class = Config.Classes[other:GetAttribute("Class") or ""]
		local down = other:GetAttribute("Down") == true
		local lucky = if other:GetAttribute("Lucky") == true then " 🍀" else "" -- Lucky covers the whole party
		local line = Widgets.text(partyFrame, `{other.DisplayName}{lucky}{if class then ` · {class.name}` else ""}{if down then " · DOWN" else ""}`, UDim2.new(1, 0, 0.24, 0), i)
		line.BackgroundColor3 = Widgets.DARK
		line.BackgroundTransparency = 0.35
		line.TextColor3 = if down then Color3.fromHex(Config.Rarity.Common.color) else Color3.new(1, 1, 1)
	end
end

---------------------------------------------------------------- hold ring

-- This player's own hold, from TearState: `progress` so far and `seconds` for the whole panel. nil ends it.
function Status.hold(progress: number?, seconds: number?)
	hold = if progress and seconds then { from = progress, seconds = seconds, at = os.clock() } else nil
	ringFill.Size = UDim2.fromScale(if progress then progress else 0, 1)
end

---------------------------------------------------------------- prompt

local function showPrompt(prompt: ProximityPrompt?)
	shownPrompt = prompt
	promptButton.Visible = prompt ~= nil
	if prompt then
		local key = if prompt.KeyboardKeyCode ~= Enum.KeyCode.Unknown then ` [{prompt.KeyboardKeyCode.Name}]` else ""
		promptButton.Text = `{prompt.ActionText}{key}`
	end
end

---------------------------------------------------------------- init

function Status.init(gui: ScreenGui)
	cashLabel = panel("Cash", UDim2.fromScale(0.16, 0.06), UDim2.fromScale(0.01, 0.02))
	cashLabel.Parent = gui

	depthFrame = Widgets.make("Frame", { Parent = gui, Name = "Depth", Size = UDim2.fromScale(0.06, 0.2), Position = UDim2.fromScale(0.47, 0.09), BackgroundTransparency = 1 })
	Widgets.list(depthFrame).Padding = UDim.new(0, 2)
	depthLabel = panel("DepthLabel", UDim2.fromScale(0.16, 0.05), UDim2.fromScale(0.42, 0.02))
	depthLabel.Parent = gui

	local tool = Widgets.make("Frame", { Parent = gui, Name = "Tool", Size = UDim2.fromScale(0.2, 0.08), Position = UDim2.fromScale(0.4, 0.9), BackgroundColor3 = Widgets.DARK, BackgroundTransparency = 0.25 })
	local ring = Widgets.make("Frame", { Parent = tool, Name = "HoldRing", Size = UDim2.fromScale(1, 0.18), Position = UDim2.fromScale(0, 0.82), BackgroundTransparency = 1 })
	ringFill = Widgets.make("Frame", { Parent = ring, Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Widgets.BUTTON })
	toolLabel = Widgets.text(tool, "Hands", UDim2.fromScale(1, 0.8))

	partyFrame = Widgets.make("Frame", { Parent = gui, Name = "Party", Size = UDim2.fromScale(0.16, 0.22), Position = UDim2.fromScale(0.01, 0.62), BackgroundTransparency = 1 })
	Widgets.list(partyFrame)

	promptButton = Widgets.button(gui, "", UDim2.fromScale(0.24, 0.07), function()
		local prompt = shownPrompt
		if prompt then
			prompt:InputHoldBegin()
			prompt:InputHoldEnd()
		end
	end)
	if workspace:GetAttribute("PlaceKind") == "Lobby" then
		-- Cash, depth and tool belong to a run; the lobby shows the party and the prompt only.
		for _, item in { cashLabel, depthFrame, depthLabel, tool } do
			item.Visible = false
		end
	end
	promptButton.Name = "Prompt"
	promptButton.Position = UDim2.fromScale(0.38, 0.72)
	promptButton.Visible = false

	-- One prompt at a time, drawn here in the bottom third instead of over the object.
	ProximityPromptService.PromptShown:Connect(function(prompt)
		if prompt.Style == Enum.ProximityPromptStyle.Custom then
			showPrompt(prompt)
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		if prompt == shownPrompt then
			showPrompt(nil)
		end
	end)

	local function watchPlayer(other: Player)
		other.AttributeChanged:Connect(function(name)
			if name == "Class" or name == "Down" or name == "Lucky" then
				refreshParty()
			end
		end)
	end
	Players.PlayerAdded:Connect(function(other)
		watchPlayer(other)
		refreshParty()
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshParty)
	end)
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	refreshParty()

	-- Night timer: replaces the depth line, red, while NightState says the Night is on (Phase 4 sends
	-- { secondsLeft = n }, or { secondsLeft = nil } when it ends).
	Remotes.get("NightState").OnClientEvent:Connect(function(night)
		nightEndsAt = if night and typeof(night.secondsLeft) == "number" then os.clock() + night.secondsLeft else nil
		if not nightEndsAt then
			Status.refresh()
		end
	end)

	RunService.RenderStepped:Connect(function()
		local h = hold
		if nightEndsAt then
			depthLabel.Text = `Night {math.max(0, math.ceil(nightEndsAt - os.clock()))} s`
			depthLabel.TextColor3 = Color3.fromHex(Config.HUD.nightTimerColor)
		end
		if h then
			ringFill.Size = UDim2.fromScale(math.min(1, h.from + (os.clock() - h.at) / h.seconds), 1)
		end
	end)
end

return Status
