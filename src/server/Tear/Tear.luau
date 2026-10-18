--[=[
	Tear (server system)
	Owns: Panel bitfields per layer, tool and action validation, panel timing, layer-cleared events.
	Must never: Trust a client position or timer. Timing uses the server clock; reach uses the
	server's own character position; the client's touch point only places the rip line.
	Pure, tested logic: PanelGrid, TearSession, RateLimit. This file is the Roblox glue.
	Phase 0: one greybox Paper layer on one cube as server Parts (Workspace.Present).
	Read first: src/server/Tear/README.md
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local PanelGrid = require(script.Parent.PanelGrid)
local RateLimit = require(script.Parent.RateLimit)
local TearSession = require(script.Parent.TearSession)

local Tear = {}

local sessions: { [number]: TearSession.Session } = {} -- by depth
local panelParts: { [number]: { [number]: BasePart } } = {} -- by depth, then panel id
local ripPoints: { [number]: { [number]: { u: number, v: number } } } = {} -- first touch point per panel
local holdingDepth: { [Player]: number } = {}
local timers: { [Player]: thread } = {}
local limiter = RateLimit.new(Config.Tear.maxRequestsPerSecond)
local tearState: RemoteEvent

-- Phase 0: everyone tears with hands. Tools and pickups arrive in Phase 1.
local function panelSeconds(layerType: string): number?
	local rule = Config.LayerTable[layerType]
	local tool = Config.Tools.Hands
	if not rule or tool.grade < rule.grade then
		return nil
	end
	if tool.actions == "All" then
		return tool.seconds
	end
	return tool.actions[rule.action]
end

local function broadcast(depth: number, panelId: number, state: string, progress: number, seconds: number)
	local point = ripPoints[depth][panelId]
	tearState:FireAllClients({
		depth = depth,
		panelId = panelId,
		state = state, -- "Holding" | "Released" | "Torn"
		progress = progress,
		seconds = seconds,
		u = point and point.u or 0.5,
		v = point and point.v or 0.5,
	})
end

local function endHold(player: Player, now: number)
	local timer = timers[player]
	if timer then
		timers[player] = nil
		task.cancel(timer)
	end
	local depth = holdingDepth[player]
	if not depth then
		return
	end
	holdingDepth[player] = nil
	local session = sessions[depth]
	local seconds = TearSession.holding(session, player).seconds
	local result = TearSession.release(session, player, now)
	if not result then
		return
	end
	if result.torn then
		-- Phase 0 stand-in until Debris swaps in torn-edge pieces (next criterion).
		local part = panelParts[depth][result.panelId]
		part.Transparency = 1
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		broadcast(depth, result.panelId, "Torn", 1, seconds)
	else
		broadcast(depth, result.panelId, "Released", result.progress, seconds)
	end
end

local function finite01(x: any): number
	if typeof(x) ~= "number" or x ~= x then
		return 0.5
	end
	return math.clamp(x, 0, 1)
end

local function beginHold(player: Player, depth: any, panelId: any, u: any, v: any)
	if typeof(depth) ~= "number" or typeof(panelId) ~= "number" then
		return
	end
	local session = sessions[depth]
	local part = panelParts[depth] and panelParts[depth][panelId]
	if not session or not part then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - part.Position).Magnitude > Config.Tear.reachStuds then
		return
	end
	local seconds = panelSeconds(session.grid.layerType)
	if not seconds then
		return
	end

	local now = os.clock()
	endHold(player, now)
	local needed = TearSession.begin(session, player, panelId, seconds, now)
	if not needed then
		return
	end
	holdingDepth[player] = depth
	ripPoints[depth][panelId] = ripPoints[depth][panelId] or { u = finite01(u), v = finite01(v) }
	broadcast(depth, panelId, "Holding", TearSession.fraction(session, panelId, seconds, now), seconds)
	timers[player] = task.delay(needed, function()
		timers[player] = nil
		endHold(player, os.clock())
	end)
end

-- Builds a layer's panels as anchored Parts on a cube of side `size` centred at `origin`.
local function buildGreybox(grid: PanelGrid.Grid, size: number, origin: Vector3): Folder
	local folder = Instance.new("Folder")
	folder.Name = `Layer{grid.depth}_{grid.layerType}`
	local thickness = Config.Greybox.panelThickness
	local parts = {}
	for id = 1, grid.count do
		local p = PanelGrid.placement(grid, id, size)
		local normal = Vector3.new(p.normal.x, p.normal.y, p.normal.z)
		local center = origin + Vector3.new(p.center.x, p.center.y, p.center.z) - normal * (thickness / 2)
		local part = Instance.new("Part")
		part.Name = `Panel{id}`
		part.Anchored = true
		part.Size = Vector3.new(p.width, p.width, thickness)
		local _, row, col = PanelGrid.locate(grid, id)
		part.Color = Color3.fromHex(Config.Greybox.panelColors[(row + col) % 2 + 1])
		-- A part's front (-Z) points along the outward normal.
		local up = if math.abs(normal.Y) > 0.5 then Vector3.zAxis else Vector3.yAxis
		part.CFrame = CFrame.lookAt(center, center + normal, up)
		part:SetAttribute("PanelId", id)
		part:SetAttribute("Depth", grid.depth)
		part.Parent = folder
		parts[id] = part
	end
	panelParts[grid.depth] = parts
	ripPoints[grid.depth] = {}
	return folder
end

function Tear.getGrid(depth: number): PanelGrid.Grid?
	local session = sessions[depth]
	return session and session.grid
end

function Tear.init()
	tearState = Remotes.get("TearState")

	-- Phase 0 greybox: one Paper layer at depth 0, Birthday tier. Present generates the Nest from Phase 1.
	-- Set one present-width back from the origin so it does not cover the default SpawnLocation.
	local tier = 1
	local size = Config.Tiers.Birthday.presentStuds
	local grid = PanelGrid.fromLayer({ layerType = "Paper", depth = 0 }, size, Config.Panels)
	sessions[grid.depth] = TearSession.new(grid)

	local present = Instance.new("Model")
	present.Name = "Present"
	buildGreybox(grid, size, Vector3.new(0, size / 2, -size)).Parent = present
	present.Parent = workspace

	Remotes.get("TearRequest").OnServerEvent:Connect(function(player, kind, depth, panelId, u, v)
		-- No RunState yet in Phase 0; validate it here first once Present owns runs.
		if not RateLimit.allow(limiter, player, os.clock()) then
			return
		end
		if kind == "Begin" then
			beginHold(player, depth, panelId, u, v)
		elseif kind == "End" then
			endHold(player, os.clock())
		end
	end)

	local function watchCharacter(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			endHold(player, os.clock())
		end)
	end
	local function watchPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			watchCharacter(player, character)
		end)
		if player.Character then
			task.spawn(watchCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		endHold(player, os.clock())
		RateLimit.forget(limiter, player)
	end)
end

return Tear
