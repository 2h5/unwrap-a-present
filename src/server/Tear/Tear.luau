--[=[
	Tear (server system)
	Owns: Panel bitfields per layer, tool and action validation, panel timing, layer-cleared events.
	Must never: Trust a client position or timer. Timing uses the server clock; reach uses the
	server's own character position; the client's touch point only places the rip line.
	Pure, tested logic: PanelGrid, LayerModel, LayerGeometry, TearSession, LidSession, Tools, RateLimit.
	This file is the Roblox glue: builds the run's layers as greybox Parts (Workspace.Present), routes
	TearRequest / LidLift, advances depth when a layer clears, spawns the scissors pickup after depth 0.
	Read first: src/server/Tear/README.md
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local Economy = require(script.Parent.Parent.Economy.Economy)
local PanelGrid = require(script.Parent.PanelGrid)
local LayerModel = require(script.Parent.LayerModel)
local LayerGeometry = require(script.Parent.LayerGeometry)
local LidSession = require(script.Parent.LidSession)
local RateLimit = require(script.Parent.RateLimit)
local TearSession = require(script.Parent.TearSession)
local Tools = require(script.Parent.Tools)

type Hold = { depth: number, id: number, lid: boolean }

local Tear = {}

local run: any = nil -- the current run, see Tear.loadNest
local holding: { [Player]: Hold } = {}
local timers: { [Player]: thread } = {}
local lidTimers: { [number]: thread } = {}
local limiter = RateLimit.new(Config.Tear.maxRequestsPerSecond)
local tearState: RemoteEvent
local clearedListeners: { (depth: number, layerType: string) -> () } = {}
local completeListeners: { () -> () } = {}

local RULES = { layerTable = Config.LayerTable, tape = Config.TapeOverlay, ribbon = Config.Ribbon }

local function owned(player: Player): { [string]: boolean }
	local out = {}
	for _, name in Tools.order do
		out[name] = player:GetAttribute(`Tool_{name}`) == true
	end
	return out
end

local function timeScale(player: Player): number
	return if player:GetAttribute("Upgrade_GripTape") then Config.Shop.GripTape.panelTimeScale else 1
end

local function send(target: Player?, payload: { [string]: any })
	if target then
		tearState:FireClient(target, payload)
	else
		tearState:FireAllClients(payload)
	end
end

local function broadcast(depth: number, id: number, state: string, progress: number, seconds: number)
	local point = run.ripPoints[`{depth}:{id}`]
	send(nil, {
		depth = depth,
		panelId = id,
		state = state, -- "Holding" | "Released" | "Torn" | "Lifted"
		progress = progress,
		seconds = seconds,
		u = point and point.u or 0.5,
		v = point and point.v or 0.5,
	})
end

local function refuse(player: Player, reason: string)
	send(player, { state = "Refused", reason = reason })
end

local function hide(part: BasePart?)
	if part then
		part.Transparency = 1
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
	end
end

---------------------------------------------------------------- building

local function paperColor(depth: number): (Color3, Color3)
	local palette = Config.Palette.paper
	local base = Color3.fromHex(palette[(run.nest.seed + depth) % #palette + 1])
	return base, base:Lerp(Color3.new(1, 1, 1), Config.Greybox.checkerLighten)
end

local function makePart(p: LayerGeometry.Placement, center: Vector3, parent: Instance): Part
	local c = center + Vector3.new(p.center.x, p.center.y, p.center.z)
	local n = Vector3.new(p.normal.x, p.normal.y, p.normal.z)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = Vector3.new(p.sizeX, p.sizeY, p.depth)
	-- A part's front (-Z) points along the outward normal; its up is the face's v axis.
	part.CFrame = CFrame.lookAt(c, c + n, Vector3.new(p.up.x, p.up.y, p.up.z))
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function layerCenter(depth: number): Vector3
	return run.base + Vector3.new(0, run.sizes[depth] / 2, 0)
end

local function build(depth: number)
	if run.parts[depth] or not run.nest.layers[depth + 1] then
		return
	end
	local layer = run.nest.layers[depth + 1]
	local size = run.sizes[depth]
	local perFace = PanelGrid.gridPerFace(size, Config.Panels)
	local model = LayerModel.build(layer, perFace, RULES)
	run.models[depth] = model
	run.sessions[depth] = TearSession.new(model :: any)
	run.parts[depth] = {}

	local folder = Instance.new("Folder")
	folder.Name = `Layer{depth}_{layer.layerType}`
	folder:SetAttribute("Depth", depth)
	local thickness = Config.Greybox.panelThickness
	local center = layerCenter(depth)
	local light, dark = paperColor(depth)
	for id, item in model.items do
		if not item.bottom then
			local p = LayerGeometry.place(model, id, size, thickness, Config.TapeOverlay.stripStuds)
			local part = makePart(p, center, folder)
			part.Name = `P{id}`
			part:SetAttribute("PanelId", id)
			part:SetAttribute("Depth", depth)
			part:SetAttribute("Kind", item.kind)
			if item.kind == "Panel" then
				part.Color = if ((item.row :: number) + (item.col :: number)) % 2 == 0 then light else dark
			elseif item.kind == "Tape" then
				part.Color = Color3.fromHex(Config.Palette.tape.color)
				part.Transparency = Config.Palette.tape.transparency
				part.Reflectance = Config.Palette.tape.reflectance
			elseif item.kind == "Segment" or item.kind == "Bow" then
				part.Color = Color3.fromHex(Config.Palette.ribbon.color)
				part.Reflectance = Config.Palette.ribbon.reflectance
			elseif item.kind == "Lid" then
				part.Color = Color3.fromHex(Config.Palette.cardboard)
				part.Material = Enum.Material.Cardboard
			end
			run.parts[depth][id] = part
		end
	end
	if layer.layerType == "BoxLid" then
		run.walls[depth] = {}
		for _, p in LayerGeometry.walls(size, thickness) do
			if p.normal.y > -0.5 then -- the floor wall is never seen
				local wall = makePart(p, center, folder)
				wall.Name = "Wall"
				wall.Color = Color3.fromHex(Config.Palette.cardboard)
				wall.Material = Enum.Material.Cardboard
				table.insert(run.walls[depth], wall)
			end
		end
	end
	folder.Parent = run.present
end

-- The current layer, the one inside it, and the one a ribbon wraps are visible; build them.
local function buildVisible()
	local c = run.current
	build(c)
	build(c + 1)
	local inner = run.nest.layers[c + 2]
	if inner and inner.layerType == "Ribbon" then
		build(c + 2)
	end
end

---------------------------------------------------------------- run flow

local function spawnScissors()
	local s = Config.Greybox.pickupStuds
	local pickup = Instance.new("Part")
	pickup.Name = "ScissorsPickup"
	pickup.Anchored = true
	pickup.CanCollide = false
	pickup.Material = Enum.Material.Neon
	pickup.Color = Color3.fromHex(Config.Greybox.pickupColor)
	pickup.Size = Vector3.new(s, s / 2, s)
	local half = run.sizes[0] / 2
	pickup.Position = run.base + Vector3.new(half, s / 4, half + Config.Panels.panelStuds)
	pickup.Touched:Connect(function(other)
		local player = Players:GetPlayerFromCharacter(other.Parent)
		if player and not player:GetAttribute("Tool_Scissors") then
			player:SetAttribute("Tool_Scissors", true)
		end
	end)
	pickup.Parent = run.present
end

local function clearLayer(depth: number)
	local model = run.models[depth]
	LayerModel.dropBottom(model)
	local folder = run.present:FindFirstChild(`Layer{depth}_{model.layerType}`)
	if folder then
		task.delay(Config.Tear.flutterSeconds, function()
			folder:Destroy() -- after clients have swapped the last pieces for debris
		end)
	end
	run.current = depth + 1
	run.present:SetAttribute("CurrentDepth", run.current)
	for _, listener in clearedListeners do
		task.spawn(listener, depth, model.layerType)
	end
	if depth == 0 then
		spawnScissors()
	end
	if run.current >= #run.nest.layers then
		run.done = true
		for _, listener in completeListeners do
			task.spawn(listener)
		end
		return
	end
	buildVisible()
end

local function itemDone(depth: number, id: number, players: { Player })
	local part = run.parts[depth][id]
	local cash = Economy.cashPerPanel(run.nest.tier)
	for _, player in players do
		Economy.addCash(player, cash)
	end
	if run.models[depth].items[id].kind ~= "Lid" then
		hide(part)
	end
	if LayerModel.isCleared(run.models[depth]) then
		clearLayer(depth)
	end
end

---------------------------------------------------------------- lids

local function lidPropSlot(lidSize: number): CFrame
	-- Lifted lids stand upright on the floor round the present, facing it, one present-width out
	-- from its centre, so the team can hide behind them in the Night. Later lids stand further out.
	local dirs = { Vector3.xAxis, -Vector3.xAxis, -Vector3.zAxis }
	local k = run.lidsLifted
	local dir = dirs[k % #dirs + 1]
	local out = run.sizes[0] + (k // #dirs) * Config.Panels.panelStuds
	local up = Vector3.new(0, lidSize / 2, 0)
	local pos = run.base + dir * out + up
	return CFrame.lookAt(pos, run.base + up)
end

local function liftLid(depth: number)
	local session = run.lids[depth]
	local holders = {}
	for player, hold in holding do
		if hold.depth == depth and hold.lid then
			table.insert(holders, player)
			holding[player] = nil
		end
	end
	run.lids[depth] = nil
	PanelGrid.setTorn(run.models[depth] :: any, 1, true)
	local lid = run.parts[depth][1]
	broadcast(depth, 1, "Lifted", 1, session.seconds)
	-- The lid becomes a prop the team can hide behind during the Night; the box walls open.
	lid.Parent = run.props
	lid.Name = "LidProp"
	lid:SetAttribute("PanelId", nil)
	lid:SetAttribute("Kind", "LidProp")
	lid.CanQuery = false
	lid.CFrame = lidPropSlot(run.sizes[depth])
	run.lidsLifted += 1
	for _, wall in run.walls[depth] or {} do
		wall:Destroy()
	end
	itemDone(depth, 1, holders)
end

local function lidTimer(depth: number, remaining: number?)
	local old = lidTimers[depth]
	if old then
		lidTimers[depth] = nil
		if coroutine.running() ~= old then
			task.cancel(old)
		end
	end
	if remaining then
		lidTimers[depth] = task.delay(remaining, function()
			lidTimers[depth] = nil
			local session = run and run.lids[depth]
			if session and LidSession.isDone(session, os.clock()) then
				liftLid(depth)
			end
		end)
	end
end

---------------------------------------------------------------- holds

local function endHold(player: Player, now: number)
	local timer = timers[player]
	if timer then
		timers[player] = nil
		task.cancel(timer)
	end
	local hold = holding[player]
	if not hold or not run then
		holding[player] = nil
		return
	end
	holding[player] = nil
	if hold.lid then
		local session = run.lids[hold.depth]
		if session then
			local remaining = LidSession.leave(session, player, now)
			lidTimer(hold.depth, remaining)
			broadcast(hold.depth, hold.id, if remaining then "Holding" else "Released", LidSession.fraction(session, now), session.seconds)
		end
		return
	end
	local session = run.sessions[hold.depth]
	local current = TearSession.holding(session, player)
	if not current then
		return
	end
	local seconds = current.seconds
	local result = TearSession.release(session, player, now)
	if not result then
		return
	end
	if result.torn then
		broadcast(hold.depth, result.panelId, "Torn", 1, seconds)
		itemDone(hold.depth, result.panelId, { player })
	else
		broadcast(hold.depth, result.panelId, "Released", result.progress, seconds)
	end
end

local function finite01(x: any): number
	if typeof(x) ~= "number" or x ~= x then
		return 0.5
	end
	return math.clamp(x, 0, 1)
end

-- Shared checks for any Begin. Returns the item and its part, or nil after telling the player why.
local function validate(player: Player, depth: any, id: any): (any, BasePart?)
	if not run or run.done or typeof(depth) ~= "number" or typeof(id) ~= "number" or depth ~= run.current then
		return nil, nil
	end
	local model = run.models[depth]
	local part = run.parts[depth] and run.parts[depth][id]
	if not model or not part then
		return nil, nil
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - part.Position).Magnitude > run.reach then
		return nil, nil
	end
	local ok, reason = LayerModel.canStart(model, id)
	if not ok then
		if reason == "taped" then
			refuse(player, "Cut the tape first")
		end
		return nil, nil
	end
	return model.items[id], part
end

local function toolHint(grade: number): string
	if grade >= 2 then
		return "Needs a box cutter"
	end
	return "Needs scissors"
end

local function beginTear(player: Player, depth: any, id: any, u: any, v: any)
	local item = validate(player, depth, id)
	if not item or item.kind == "Lid" then
		return
	end
	local seconds = Tools.best(owned(player), item.action, item.grade, Config.Tools, timeScale(player))
	if not seconds then
		refuse(player, toolHint(item.grade))
		return
	end
	local now = os.clock()
	endHold(player, now)
	local session = run.sessions[depth]
	local needed = TearSession.begin(session, player, id, seconds, now)
	if not needed then
		return
	end
	holding[player] = { depth = depth, id = id, lid = false }
	local key = `{depth}:{id}`
	run.ripPoints[key] = run.ripPoints[key] or { u = finite01(u), v = finite01(v) }
	broadcast(depth, id, "Holding", TearSession.fraction(session, id, seconds, now), seconds)
	timers[player] = task.delay(needed, function()
		timers[player] = nil
		endHold(player, os.clock())
	end)
end

local function beginLid(player: Player, depth: any, id: any)
	local item = validate(player, depth, id)
	if not item or item.kind ~= "Lid" then
		return
	end
	local seconds = Tools.best(owned(player), item.action, item.grade, Config.Tools, timeScale(player))
	if not seconds then
		return
	end
	local now = os.clock()
	endHold(player, now)
	local session = run.lids[depth]
	if not session then
		local required = LidSession.requiredHolders(run.tierNumber, Config.LayerTable.BoxLid.twoPlayerFromTier, #Players:GetPlayers())
		session = LidSession.new(required, seconds)
		run.lids[depth] = session
	end
	holding[player] = { depth = depth, id = id, lid = true }
	local remaining = LidSession.join(session, player, now)
	lidTimer(depth, remaining)
	broadcast(depth, id, if remaining then "Holding" else "Released", LidSession.fraction(session, now), session.seconds)
	if not remaining then
		refuse(player, `Needs {session.required} players`)
	end
end

---------------------------------------------------------------- public

function Tear.onLayerCleared(listener: (depth: number, layerType: string) -> ())
	table.insert(clearedListeners, listener)
end

function Tear.onRunComplete(listener: () -> ())
	table.insert(completeListeners, listener)
end

function Tear.getModel(depth: number): LayerModel.Model?
	return run and run.models[depth]
end

-- Replaces the present with a fresh one built from `nest` (Present -> Tear: Nest).
-- `sizes` by depth (Nest.sizes); `base` is the floor point under the present's centre.
function Tear.loadNest(nest: any, sizes: { [number]: number }, tierNumber: number, base: Vector3)
	for player in holding do
		holding[player] = nil
	end
	for player, timer in timers do
		task.cancel(timer)
		timers[player] = nil
	end
	for depth in lidTimers do
		lidTimer(depth, nil)
	end
	if run then
		run.present:Destroy()
		run.props:Destroy()
	end
	local present = Instance.new("Model")
	present.Name = "Present"
	present:SetAttribute("CurrentDepth", 0)
	present:SetAttribute("LayerCount", #nest.layers)
	present:SetAttribute("Tier", nest.tier)
	present:SetAttribute("TierNumber", tierNumber)
	local props = Instance.new("Model")
	props.Name = "LidProps"
	run = {
		nest = nest,
		sizes = sizes,
		tierNumber = tierNumber,
		base = base,
		reach = math.max(Config.Tear.reachMinStuds, sizes[0] + Config.Tear.reachPadStuds), -- N37
		present = present,
		props = props,
		models = {},
		parts = {},
		walls = {},
		sessions = {},
		lids = {},
		ripPoints = {},
		current = 0,
		lidsLifted = 0,
		done = false,
	}
	buildVisible()
	present.Parent = workspace
	props.Parent = workspace
end

function Tear.init()
	tearState = Remotes.get("TearState")

	Remotes.get("TearRequest").OnServerEvent:Connect(function(player, kind, depth, panelId, u, v)
		-- No RunState yet; validate it here first once Lobby starts runs (Phase 3).
		if not RateLimit.allow(limiter, player, os.clock()) then
			return
		end
		if kind == "Begin" then
			beginTear(player, depth, panelId, u, v)
		elseif kind == "End" then
			endHold(player, os.clock())
		end
	end)

	Remotes.get("LidLift").OnServerEvent:Connect(function(player, kind, depth, panelId)
		if not RateLimit.allow(limiter, player, os.clock()) then
			return
		end
		if kind == "Begin" then
			beginLid(player, depth, panelId)
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
