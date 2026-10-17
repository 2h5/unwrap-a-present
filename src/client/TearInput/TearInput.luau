--[=[
	TearInput (client system)
	Owns: Hold detection, rip-line preview, TearRequest.
	Must never: Decide that a panel is gone. It sends Begin/End and draws what TearState says.
	Touch and mouse share one path (invariant 3): press on a panel, hold, release.
	Rip line: grows from the touch point to both panel edges over the panel time; stays on release.
	Read first: src/client/TearInput/README.md
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)

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

local function findPanel(depth: number, panelId: number): BasePart?
	local present = workspace:FindFirstChild("Present")
	if not present then
		return nil
	end
	for _, layer in present:GetChildren() do
		local part = layer:FindFirstChild(`Panel{panelId}`)
		if part and part:GetAttribute("Depth") == depth then
			return part :: BasePart
		end
	end
	return nil
end

local function panelUnder(screen: Vector3): (BasePart?, number, number)
	local ray = workspace.CurrentCamera:ScreenPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Players.LocalPlayer.Character :: any }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)
	if not hit or hit.Instance:GetAttribute("PanelId") == nil then
		return nil, 0, 0
	end
	local panel = hit.Instance :: BasePart
	local localHit = panel.CFrame:PointToObjectSpace(hit.Position)
	return panel, localHit.X / panel.Size.X + 0.5, localHit.Y / panel.Size.Y + 0.5
end

local function draw(line: Line, fraction: number)
	local panel = line.panel
	local w, h, thickness = panel.Size.X, panel.Size.Y, panel.Size.Z
	local width = Config.Greybox.ripLineWidth
	local x0 = (line.u - 0.5) * w
	local left = x0 - fraction * (x0 + w / 2)
	local right = x0 + fraction * (w / 2 - x0)
	local length = right - left
	line.part.Transparency = if length > 0 then 0 else 1
	line.part.Size = Vector3.new(math.max(length, width), width, width)
	-- The panel's front (-Z) faces out of the present; the line sits on that face.
	line.part.CFrame = panel.CFrame * CFrame.new((left + right) / 2, (line.v - 0.5) * h, -(thickness + width) / 2)
end

local function onTearState(state: { [string]: any })
	local key = `{state.depth}:{state.panelId}`
	local line = lines[key]
	if state.state == "Torn" then
		if line then
			line.part:Destroy()
			lines[key] = nil
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
	l.holding = state.state == "Holding"
	draw(l, l.from)
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

function TearInput.init()
	local request = Remotes.get("TearRequest")

	folder = Instance.new("Folder")
	folder.Name = "RipLines"
	folder.Parent = workspace

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or activeInput or not isPress(input) then
			return
		end
		local panel, u, v = panelUnder(input.Position)
		if not panel then
			return
		end
		activeInput = input
		request:FireServer("Begin", panel:GetAttribute("Depth"), panel:GetAttribute("PanelId"), u, v)
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
			request:FireServer("End")
		end
	end)

	Remotes.get("TearState").OnClientEvent:Connect(onTearState)

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
