--[=[
	Status (client, part of HUD)
	Owns: the always-on HUD of Art bible B / PLAN-TABLES Table 13, in the wooden kit: cash top left (gems
	there in the lobby), depth top centre as a stack of coloured bars under a wooden plaque (layer n of
	N), the red Night timer on that plaque, the round tool badge bottom centre with the hold ring, party
	cards on the left edge (class icon, name, Lucky, DOWN) and one prompt button in the bottom third.
	Must never: Compute a value it displays. Cash, gems, the tool, the class and the layer colours come
	from the server (attributes, ProfileState); the hold ring follows this player's TearState.
	Read first: src/client/HUD/README.md
]=]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local Widgets = require(script.Parent.Widgets)

local Status = {}

local C = Widgets.C
local player = Players.LocalPlayer
local isLobby = workspace:GetAttribute("PlaceKind") == "Lobby"
local moneyLabel: TextLabel
local moneyScale: UIScale
local money = { shown = 0, target = 0 }
local depthPlaque: Frame
local depthBars: Frame
local depthLabel: TextLabel
local toolHolder: Frame
local toolArt: Frame
local toolName: TextLabel
local toolShown = ""
local setRing: (progress: number) -> ()
local partyFrame: Frame
local promptHolder: Frame
local promptButton: TextButton
local promptKey: TextLabel
local promptPad: UIPadding
local shownPrompt: ProximityPrompt? = nil
local heldPrompt: ProximityPrompt? = nil -- held down by the prompt button
local hold: { from: number, seconds: number, at: number }? = nil
local nightEndsAt: number? = nil -- os.clock() when the Night ends, from NightState

local TOOL_NAMES = { Hands = "Hands", Scissors = "Scissors", BoxCutter = "Box cutter", Chainsaw = "Chainsaw" }

local function present(): Instance?
	return workspace:FindFirstChild("Present")
end

local function limit(object: Instance, min: Vector2, max: Vector2)
	local l = Instance.new("UISizeConstraint")
	l.MinSize, l.MaxSize = min, max
	l.Parent = object
end

---------------------------------------------------------------- money

-- A wooden pill with a big round icon on its left end and one big number.
local function moneyPill(gui: Instance, icon: string)
	local pill = Widgets.make("Frame", { Parent = gui, Name = "Money", Position = UDim2.new(0, 14, 0.02, 4), Size = UDim2.fromScale(0.2, 0.075), BackgroundColor3 = C.woodMid, Corner = UDim.new(0.5, 0) })
	Widgets.stroke(pill, C.woodDark, Config.UI.strokePx)
	limit(pill, Vector2.new(150, 44), Vector2.new(250, 64))
	Widgets.make("Frame", { Parent = pill, Name = "Inset", Size = UDim2.new(1, -10, 1, -10), Position = UDim2.fromOffset(5, 5), BackgroundColor3 = C.woodDark, BackgroundTransparency = 0.4, Corner = UDim.new(0.5, 0) })
	Widgets.icon(pill, icon, UDim2.fromScale(1.3, 1.3), UDim2.new(0, -12, -0.15, 0), `Icon{icon}`).ZIndex = 2
	moneyLabel = Widgets.text(pill, "0", UDim2.new(0.68, -8, 0.8, 0), nil, "L")
	moneyLabel.Position = UDim2.new(0.32, 0, 0.1, 0)
	moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
	moneyScale = Instance.new("UIScale")
	moneyScale.Parent = pill
end

-- The number counts up to the server's value (Table 13: cash ticks up per panel); spending snaps down.
local function setMoney(value: number)
	if value > money.target then
		moneyScale.Scale = 1.08
		TweenService:Create(moneyScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	money.target = value
	if value < money.shown then
		money.shown = value
	end
	moneyLabel.Text = tostring(math.floor(money.shown))
end

---------------------------------------------------------------- refresh

function Status.refresh()
	if isLobby then
		return -- gems come from ProfileState; no depth or tool in the lobby
	end
	setMoney(player:GetAttribute("Cash") or 0)
	local tool = player:GetAttribute("Tool") or "Hands"
	if tool ~= toolShown then
		toolShown = tool
		Widgets.clear(toolArt)
		Widgets.icon(toolArt, tool, UDim2.fromScale(1, 1), nil, `Shop{tool}`)
		toolName.Text = TOOL_NAMES[tool] or "Hands"
	end

	Widgets.clear(depthBars)
	local p = present()
	local count = p and p:GetAttribute("LayerCount") or 0
	local depth = p and p:GetAttribute("CurrentDepth") or 0
	local colors = string.split(p and p:GetAttribute("LayerColors") or "", ",")
	depthPlaque.Visible = count > 0 or nightEndsAt ~= nil
	depthLabel.Text = `Layer {math.min(depth + 1, count)} / {count}`
	depthLabel.TextColor3 = C.cream
	for d = 0, count - 1 do
		local current = d == depth
		local bar = Widgets.make("Frame", {
			Parent = depthBars,
			LayoutOrder = d,
			Size = UDim2.new(if current then 1 else 0.72, 0, 1 / math.max(count, 1), -3),
			BackgroundColor3 = if colors[d + 1] and colors[d + 1] ~= "" then Color3.fromHex(colors[d + 1]) else C.woodDark,
			BackgroundTransparency = if d < depth then 0.8 elseif current then 0 else 0.3,
			Corner = UDim.new(0.3, 0),
		})
		Widgets.stroke(bar, if current then C.cream else C.woodDark, if current then 2 else 1)
	end
end

local function refreshParty()
	Widgets.clear(partyFrame)
	for i, other in Players:GetPlayers() do
		local id = other:GetAttribute("Class") or ""
		local class = Config.Classes[id]
		local down = other:GetAttribute("Down") == true
		local card = Widgets.make("Frame", { Parent = partyFrame, Name = other.Name, LayoutOrder = i, Size = UDim2.new(1, 0, 0.23, 0), BackgroundColor3 = if down then C.close else C.woodMid })
		Widgets.stroke(card, C.woodDark, 2)
		-- The class icon on a round parchment badge (Table 13: party shows a class icon).
		local badge = Widgets.make("Frame", { Parent = card, Name = "Class", Size = UDim2.fromScale(0.3, 0.84), Position = UDim2.fromScale(0.03, 0.08), BackgroundColor3 = C.parchment, Corner = UDim.new(0.5, 0) })
		Widgets.aspect(badge, 1)
		Widgets.stroke(badge, C.woodDark, 2)
		Widgets.icon(badge, if class then `Class{id}` else "Hands", UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.1, 0.1), if class then `Class{id}` else nil)
		local name = Widgets.text(card, other.DisplayName, UDim2.new(0.6, 0, 0.54, 0), nil, "S")
		name.Position = UDim2.fromScale(0.37, 0.06)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local line = Widgets.text(card, if down then "DOWN" elseif class then class.name else "", UDim2.new(0.6, 0, 0.36, 0), nil, "S")
		line.Position = UDim2.fromScale(0.37, 0.58)
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.TextColor3 = if down then C.cream else C.twine
		if other:GetAttribute("Lucky") == true then -- Lucky covers the whole party; the icon sits by its owner
			Widgets.icon(card, "Lucky", UDim2.fromOffset(26, 26), UDim2.new(1, -18, 0, -8), "PassLucky")
		end
	end
end

---------------------------------------------------------------- hold ring

-- This player's own hold, from TearState: `progress` so far and `seconds` for the whole panel. nil ends it.
function Status.hold(progress: number?, seconds: number?)
	hold = if progress and seconds then { from = progress, seconds = seconds, at = os.clock() } else nil
	setRing(progress or 0)
end

---------------------------------------------------------------- prompt

local function showPrompt(prompt: ProximityPrompt?)
	local held = heldPrompt
	if held and held ~= prompt then
		heldPrompt = nil
		held:InputHoldEnd() -- the button went away under the thumb
	end
	shownPrompt = prompt
	promptHolder.Visible = prompt ~= nil
	if prompt then
		local hasKey = UserInputService.KeyboardEnabled and prompt.KeyboardKeyCode ~= Enum.KeyCode.Unknown
		promptButton.Text = prompt.ActionText
		promptKey.Visible = hasKey
		promptKey.Text = if hasKey then prompt.KeyboardKeyCode.Name else ""
		promptPad.PaddingLeft = UDim.new(0, if hasKey then 46 else 4)
	end
end

---------------------------------------------------------------- init

function Status.init(gui: ScreenGui)
	moneyPill(gui, if isLobby then "Gems" else "Cash")

	-- Depth: a wooden plaque top centre with the coloured bars hanging under it.
	local face
	depthPlaque, face = Widgets.wood(gui, UDim2.fromScale(0.17, 0.075), UDim2.new(0.5, 0, 0.02, 4), "Depth")
	depthPlaque.AnchorPoint = Vector2.new(0.5, 0)
	limit(depthPlaque, Vector2.new(150, 44), Vector2.new(240, 60))
	depthLabel = Widgets.text(face, "", UDim2.fromScale(1, 1), nil, "M")
	depthBars = Widgets.make("Frame", { Parent = depthPlaque, Name = "Bars", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 6), Size = UDim2.new(0.26, 0, 2.8, 0), BackgroundColor3 = C.woodDark, BackgroundTransparency = 0.45, Corner = UDim.new(0, 8) })
	Widgets.padding(depthBars, 4)
	Widgets.list(depthBars, false, false, 3)

	-- Tool: a round wooden badge bottom centre, the tool's picture in it and the hold ring around it.
	toolHolder = Widgets.make("Frame", { Parent = gui, Name = "Tool", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromScale(0.1, 0.17), BackgroundTransparency = 1, Corner = false })
	Widgets.aspect(toolHolder, 0.8)
	limit(toolHolder, Vector2.new(64, 80), Vector2.new(104, 130))
	local badge = Widgets.make("Frame", { Parent = toolHolder, Name = "Badge", Size = UDim2.fromScale(1, 0.8), BackgroundColor3 = C.woodMid, Corner = UDim.new(0.5, 0) })
	Widgets.stroke(badge, C.woodDark, Config.UI.strokePx + 1)
	Widgets.make("Frame", { Parent = badge, Name = "Face", Size = UDim2.new(1, -12, 1, -12), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = C.woodLight, Corner = UDim.new(0.5, 0) })
	toolArt = Widgets.make("Frame", { Parent = badge, Name = "Art", Size = UDim2.fromScale(0.6, 0.6), Position = UDim2.fromScale(0.2, 0.2), BackgroundTransparency = 1, Corner = false })
	setRing = Widgets.ring(badge, 6, C.action)
	toolName = Widgets.text(toolHolder, "Hands", UDim2.fromScale(1.6, 0.24), nil, "S")
	toolName.AnchorPoint = Vector2.new(0.5, 0)
	toolName.Position = UDim2.fromScale(0.5, 0.78)

	partyFrame = Widgets.make("Frame", { Parent = gui, Name = "Party", Size = UDim2.fromScale(0.17, 0.26), Position = UDim2.new(0, 14, 0.58, 0), BackgroundTransparency = 1, Corner = false })
	limit(partyFrame, Vector2.new(140, 120), Vector2.new(230, 230))
	Widgets.list(partyFrame, false, false, 6)

	-- Press and hold (invariant 3): the button holds the prompt down until the thumb lifts, so hold
	-- prompts (open the Tick, shutter, revive) work by touch; tap prompts trigger on the press.
	promptHolder = Widgets.make("Frame", { Parent = gui, Name = "Prompt", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.7), Size = UDim2.fromScale(0.26, 0.09), BackgroundTransparency = 1, Visible = false, Corner = false })
	limit(promptHolder, Vector2.new(200, 52), Vector2.new(340, 76))
	promptButton = Widgets.button(promptHolder, "", UDim2.fromScale(1, 1), function() end)
	promptPad = promptButton:FindFirstChildOfClass("UIPadding") :: UIPadding
	promptKey = Widgets.chip(promptButton, "", C.woodDark, UDim2.fromOffset(36, 36))
	promptKey.AnchorPoint = Vector2.new(0, 0.5)
	promptKey.Position = UDim2.new(0, -40, 0.5, 0)
	promptButton.InputBegan:Connect(function(input)
		local press = input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
		if press and shownPrompt and not heldPrompt then
			heldPrompt = shownPrompt
			shownPrompt:InputHoldBegin()
		end
	end)
	promptButton.InputEnded:Connect(function(input)
		local press = input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
		if press and heldPrompt then
			heldPrompt:InputHoldEnd()
			heldPrompt = nil
		end
	end)
	if isLobby then
		-- Depth and tool belong to a run; the lobby shows gems, the party and the prompt.
		depthPlaque.Visible = false
		toolHolder.Visible = false
		Remotes.get("ProfileState").OnClientEvent:Connect(function(state)
			if state and typeof(state.gems) == "number" then
				setMoney(state.gems)
			end
		end)
	end

	-- One prompt at a time, drawn here in the bottom third instead of over the object.
	-- A prompt tagged HideFor (a downed player's own revive) is never offered to that player.
	ProximityPromptService.PromptShown:Connect(function(prompt)
		if prompt.Style == Enum.ProximityPromptStyle.Custom and prompt:GetAttribute("HideFor") ~= player.UserId then
			showPrompt(prompt)
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		if prompt == shownPrompt then
			showPrompt(nil)
		end
	end)
	-- A hold prompt fills the same hold ring as a tear (key or button).
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		if prompt.HoldDuration > 0 then
			Status.hold(0, prompt.HoldDuration)
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function()
		Status.hold(nil)
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

	-- Night timer: replaces the depth line, red, while NightState says the Night is on ({ secondsLeft = n },
	-- or { secondsLeft = nil } when it ends). Messages with a `kind` are Night events for NightView.
	Remotes.get("NightState").OnClientEvent:Connect(function(night)
		if night and night.kind then
			return
		end
		nightEndsAt = if night and typeof(night.secondsLeft) == "number" then os.clock() + night.secondsLeft else nil
		Status.refresh()
	end)

	RunService.RenderStepped:Connect(function(dt)
		local h = hold
		if nightEndsAt then
			depthLabel.Text = `Night {math.max(0, math.ceil(nightEndsAt - os.clock()))} s`
			depthLabel.TextColor3 = Color3.fromHex(Config.HUD.nightTimerColor)
		end
		if h then
			setRing(math.min(1, h.from + (os.clock() - h.at) / h.seconds))
		end
		if money.shown < money.target then
			money.shown = math.min(money.target, money.shown + math.max(1, (money.target - money.shown) * dt * 10))
			moneyLabel.Text = tostring(math.floor(money.shown))
		end
	end)
end

return Status
