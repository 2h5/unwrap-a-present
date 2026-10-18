--[=[
	TearInput (client system)
	Owns: Hold detection, rip-line preview, TearRequest (LidLift for a box lid).
	Must never: Decide that a panel is gone. It sends Begin/End and draws what TearState says;
	on "Torn" it hands the panel to Debris.spawn.
	Touch and mouse share one path (invariant 3): press on a panel, hold, release.
	Rip line: grows from the touch point to both panel edges over the panel time; stays on release.
	Sounds: crinkle on hold start, rip on tear. Haptic: one light tap on this player's tear (touch only).
	Read first: src/client/TearInput/README.md
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local Debris = require(script.Parent.Parent.Debris.Debris)
local HUD = require(script.Parent.Parent.HUD.HUD)
local Sfx = require(ReplicatedStorage.Shared.Sfx.Sfx)

local RAY_LENGTH = 1000 -- camera ray only; the server enforces reach

type Line = {
	panel: BasePart,
	part: BasePart,
	u: number,
	v: number,
	from: number, -- fraction when the state arrived
	seconds: number,
	at: number, -- os.clock() when the state arrived
	holding: boolean,
}

local TearInput = {}

local lines: { [string]: Line } = {}
local folder: Folder
local activeInput: InputObject? = nil
local activeRemote: RemoteEvent? = nil -- TearRequest, or LidLift for a box lid
local myKey: string? = nil -- the panel this client asked to tear, for the release haptic
local haptic: HapticEffect

local function findPanel(depth: number, panelId: number): BasePart?
	local present = workspace:FindFirstChild("Present")
	if not present then
		return nil
	end
	for _, layer in present:GetChildren() do
		if layer:GetAttribute("Depth") == depth then
			return layer:FindFirstChild(`P{panelId}`) :: BasePart?
		end
	end
	return nil
end

local function panelUnder(screen: Vector3): (BasePart?, number, number)
	local ray = workspace.CurrentCamera:ScreenPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Players.LocalPlayer.Character :: any, workspace:FindFirstChild("Debris") :: any }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)
	local present = workspace:FindFirstChild("Present")
	local current = present and present:GetAttribute("CurrentDepth")
	if not hit or hit.Instance:GetAttribute("PanelId") == nil or hit.Instance:GetAttribute("Depth") ~= current then
		return nil, 0, 0 -- deeper layers show through holes but are not ready yet
	end
	local panel = hit.Instance :: BasePart
	local localHit = panel.CFrame:PointToObjectSpace(hit.Position)
	return panel, localHit.X / panel.Size.X + 0.5, localHit.Y / panel.Size.Y + 0.5
end

local function draw(line: Line, fraction: number)
	local panel = line.panel
	local width = Config.Greybox.ripLineWidth
	-- The line grows along the panel's longer side (a tape strip or ribbon segment is long and thin).
	local alongX = panel.Size.X >= panel.Size.Y
	local long = if alongX then panel.Size.X else panel.Size.Y
	local across = if alongX then panel.Size.Y else panel.Size.X
	local t0 = ((if alongX then line.u else line.v) - 0.5) * long
	local s0 = ((if alongX then line.v else line.u) - 0.5) * across
	local a = t0 - fraction * (t0 + long / 2)
	local b = t0 + fraction * (long / 2 - t0)
	local length = b - a
	line.part.Transparency = if length > 0 then 0 else 1
	local mid = (a + b) / 2
	local x, y = if alongX then mid else s0, if alongX then s0 else mid
	line.part.Size = if alongX
		then Vector3.new(math.max(length, width), width, width)
		else Vector3.new(width, math.max(length, width), width)
	-- The panel's front (-Z) faces out of the present; the line sits on that face.
	line.part.CFrame = panel.CFrame * CFrame.new(x, y, -(panel.Size.Z + width) / 2)
end

local function onTearState(state: { [string]: any })
	if state.state == "Refused" then
		HUD.toast(state.reason)
		return
	end
	local key = `{state.depth}:{state.panelId}`
	local line = lines[key]
	if state.state == "Lifted" then
		if line then
			line.part:Destroy()
			lines[key] = nil
		end
		return
	end
	if state.state == "Torn" then
		if line then
			line.part:Destroy()
			lines[key] = nil
		end
		local panel = findPanel(state.depth, state.panelId)
		if panel then
			Sfx.playAt(Config.Sounds.tearRelease, panel.Position)
			Debris.spawn(panel)
		end
		if key == myKey then
			myKey = nil
			if UserInputService.TouchEnabled then
				haptic:Play() -- one light tap on release (mobile)
			end
		end
		return
	end
	if not line then
		local panel = findPanel(state.depth, state.panelId)
		if not panel then
			return
		end
		local part = Instance.new("Part")
		part.Name = `Rip{key}`
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Color = Color3.fromHex(Config.Greybox.ripLineColor)
		part.Parent = folder
		line = { panel = panel, part = part, u = state.u, v = state.v, from = 0, seconds = 1, at = 0, holding = false }
		lines[key] = line
	end
	local l = line :: Line
	l.from = state.progress
	l.seconds = state.seconds
	l.at = os.clock()
	local wasHolding = l.holding
	l.holding = state.state == "Holding"
	if l.holding and not wasHolding then
		Sfx.playAt(Config.Sounds.tearHoldStart, l.panel.Position)
	end
	draw(l, l.from)
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

-- Roblox's touch controls do not mark their touches as game-processed, so a thumb on the
-- movement zone or the jump button would also start a tear. Those touches belong to movement.
local MOVE_CONTROLS = { "DynamicThumbstickFrame", "ThumbstickFrame", "JumpButton" }
local function onTouchControls(input: InputObject): boolean
	if input.UserInputType ~= Enum.UserInputType.Touch then
		return false
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
	local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	if not frame then
		return false
	end
	for _, name in MOVE_CONTROLS do
		local control = frame:FindFirstChild(name) :: GuiObject?
		if control and control.Visible then
			local p, s = control.AbsolutePosition, control.AbsoluteSize
			local x, y = input.Position.X, input.Position.Y
			if x >= p.X and x <= p.X + s.X and y >= p.Y and y <= p.Y + s.Y then
				return true
			end
		end
	end
	return false
end

function TearInput.init()
	local request = Remotes.get("TearRequest")
	local lidLift = Remotes.get("LidLift")

	folder = Instance.new("Folder")
	folder.Name = "RipLines"
	folder.Parent = workspace

	haptic = Instance.new("HapticEffect")
	haptic.Type = Enum.HapticEffectType.UIClick
	haptic.Parent = folder

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or activeInput or not isPress(input) or onTouchControls(input) then
			return
		end
		local panel, u, v = panelUnder(input.Position)
		if not panel then
			return
		end
		activeInput = input
		local remote = if panel:GetAttribute("Kind") == "Lid" then lidLift else request
		activeRemote = remote
		myKey = `{panel:GetAttribute("Depth")}:{panel:GetAttribute("PanelId")}`
		remote:FireServer("Begin", panel:GetAttribute("Depth"), panel:GetAttribute("PanelId"), u, v)
	end)

	UserInputService.InputEnded:Connect(function(input)
		local active = activeInput
		if not active then
			return
		end
		local same = input == active
			or (input.UserInputType == Enum.UserInputType.MouseButton1 and active.UserInputType == input.UserInputType)
		if same then
			activeInput = nil
			myKey = nil
			if activeRemote then
				activeRemote:FireServer("End")
				activeRemote = nil
			end
		end
	end)

	Remotes.get("TearState").OnClientEvent:Connect(onTearState)
	task.spawn(Sfx.preload)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, line in lines do
			if line.holding then
				draw(line, math.min(1, line.from + (now - line.at) / line.seconds))
			end
		end
	end)
end

return TearInput
