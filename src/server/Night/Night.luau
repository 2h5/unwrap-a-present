--[=[
	Night (server system)
	Owns: Tick open, Jack AI, line of sight, downs, revives, wipe detection.
	Must never: Run in the lobby (Main leaves it out there).
	Pure, tested logic: Sight, JackBrain, NightRules. This file is the Roblox glue: builds the Tick
	where Present placed it (hidden until its layer is current; Volume attribute for the ticking ramp),
	the Open / Shutter / Revive prompts (holds timed here, never trusted from the client), the Night
	(RunState, NightState timer, NightLight per player), Jack's model, the lids held up as shutters,
	downs and the dropped tool, revives, the solo auto-revive, the wipe, and both Night endings.
	Read first: src/server/Night/README.md
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local ToolModels = require(ReplicatedStorage.Shared.Art.ToolModels)
local Data = require(script.Parent.Parent.Data.Data)
local Economy = require(script.Parent.Parent.Economy.Economy)
local Loot = require(script.Parent.Parent.Loot.Loot)
local RunState = require(script.Parent.Parent.Present.RunState)
local Tear = require(script.Parent.Parent.Tear.Tear)
local Tools = require(script.Parent.Parent.Tear.Tools)
local JackBrain = require(script.Parent.JackBrain)
local NightRules = require(script.Parent.NightRules)
local Sight = require(script.Parent.Sight)

local N = Config.Night
local UP = Vector3.yAxis

type Down = { walk: number, jumpPower: number, jumpHeight: number, prompt: ProximityPrompt?, token: number }
type Shutter = { holders: { [Player]: boolean }, since: number }

local Night = {}

local nightState: RemoteEvent
local folder: Folder
local roomCenter = Vector3.zero
local token = 0 -- bumps every run, so a delayed revive from an old run does nothing
local tick: { model: Model, box: BasePart, prompt: ProximityPrompt, depth: number, blocking: boolean }? = nil
local active = false
local endsAt = 0
local jack: JackBrain.Jack? = nil
local jackModel: Model? = nil
local crankAngle = 0
local beat: RBXScriptConnection? = nil
local timer: thread? = nil
local downs: { [Player]: Down } = {}
local soloTimer: thread? = nil
local shutters: { [BasePart]: Shutter } = {}
local spareGiven: { [Player]: boolean } = {}

---------------------------------------------------------------- helpers

local function vec(v: Vector3): Sight.Vec
	return { x = v.X, y = v.Y, z = v.Z }
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function prompt(parent: Instance, name: string, action: string, object: string, seconds: number, reach: number): ProximityPrompt
	local pr = Instance.new("ProximityPrompt")
	pr.Name = name
	pr.ActionText = action
	pr.ObjectText = object
	pr.HoldDuration = seconds
	pr.KeyboardKeyCode = Enum.KeyCode.E
	pr.RequiresLineOfSight = false
	pr.MaxActivationDistance = reach
	pr.Style = Enum.ProximityPromptStyle.Custom -- drawn by the HUD in the bottom third, hold to use
	pr.Parent = parent
	return pr
end

-- Times each player's hold on `pr` with the server clock. Returns `done(player)`: true when that
-- player has held for the prompt's whole HoldDuration (less the network slack). A hold let go early
-- is forgotten, so a Triggered without a real hold is refused (invariant 7).
local function timedHolds(pr: ProximityPrompt): (player: Player) -> boolean
	local began: { [Player]: number } = {}
	pr.PromptButtonHoldBegan:Connect(function(player)
		began[player] = os.clock()
	end)
	pr.PromptButtonHoldEnded:Connect(function(player)
		if not NightRules.holdDone(began[player], os.clock(), pr.HoldDuration, N.holdSlackSeconds) then
			began[player] = nil
		end
	end)
	return function(player: Player): boolean
		local ok = NightRules.holdDone(began[player], os.clock(), pr.HoldDuration, N.holdSlackSeconds)
		began[player] = nil
		return ok
	end
end

local function near(player: Player, position: Vector3, reach: number): boolean
	local root = rootOf(player)
	return root ~= nil and (root.Position - position).Magnitude <= reach + N.jackRadiusStuds
end

local function lidProps(): { BasePart }
	local props = workspace:FindFirstChild("LidProps")
	local out = {}
	for _, child in props and props:GetChildren() or {} do
		if child:IsA("BasePart") then
			table.insert(out, child)
		end
	end
	return out
end

-- What Jack cannot see through: the present's current layer and every lid prop.
local function sightBoxes(): { Sight.Box }
	local boxes = {}
	local info = Tear.getRunInfo()
	if info and info.sizes[info.current] then
		local s = info.sizes[info.current]
		table.insert(boxes, Sight.aabb(vec(info.base + UP * s / 2), { x = s, y = s, z = s }))
	end
	for _, lid in lidProps() do
		local cf, size = lid.CFrame, lid.Size
		table.insert(boxes, {
			center = vec(cf.Position),
			axes = { vec(cf.RightVector), vec(cf.UpVector), vec(cf.LookVector) },
			half = { x = size.X / 2, y = size.Y / 2, z = size.Z / 2 },
		})
	end
	return boxes
end

local function jackRules(): JackBrain.Rules
	return {
		stillSeconds = N.jackStillSeconds,
		lungeSeconds = N.jackLungeSeconds,
		lungeSpeed = N.jackLungeSpeed,
		hitStuds = N.jackHitStuds,
		headStuds = N.jackHeadStuds,
		radius = N.jackRadiusStuds,
		roomCenter = vec(roomCenter),
		roomHalf = Config.RunRoom.sizeStuds / 2,
	}
end

---------------------------------------------------------------- the Tick

local function tickVolume()
	local info = Tear.getRunInfo()
	if tick and info then
		local t = Config.Tick
		tick.model:SetAttribute("Volume", NightRules.tickVolume(tick.depth, info.current, t.volumeMax, t.volumeFalloff, t.volumeMin))
	end
end

local function setTickVisible(on: boolean)
	if not tick then
		return
	end
	for _, p in tick.model:GetChildren() do
		if p:IsA("BasePart") then
			p.Transparency = if on then 0 else 1
		end
	end
	tick.model:SetAttribute("Revealed", on)
	tick.prompt.Enabled = on
end

-- Builds the Tick in the layer Present placed it in. Blocking: on the lid's top edge, across the
-- seam. Not blocking: on the floor at the layer's corner, beside the path. Hidden inside the outer
-- layers until its own layer is the current one; it ticks (client) from the start.
local function buildTick(info: any)
	local depth, blocking
	for _, layer in info.nest.layers do
		if layer.tick then
			depth, blocking = layer.depth, layer.tick.blocking
		end
	end
	if not depth then
		return
	end
	local s, studs = info.sizes[depth], Config.Tick.studs
	local offset = if blocking
		then Vector3.new(s / 2, s, s / 4)
		else Vector3.new(s / 2 + studs / 2, studs / 2, s / 2 + studs / 2)
	local center = info.base + offset
	local present = workspace:FindFirstChild("Present")
	local colors = string.split(present and present:GetAttribute("LayerColors") or "", ",")
	local hex = colors[depth + 1]
	local model = Instance.new("Model")
	model.Name = "Tick"
	model:SetAttribute("Depth", depth)
	model:SetAttribute("Blocking", blocking)
	local box = part({ Name = "Box", Size = Vector3.one * studs, CFrame = CFrame.new(center), Color = if hex and hex ~= "" then Color3.fromHex(hex) else Color3.fromHex(Config.Palette.cardboard) })
	-- Same paper as its ring (Table 12): the client draws the layer's pattern on it, once.
	local patterns = string.split(present and present:GetAttribute("LayerPatterns") or "", ",")
	if patterns[depth + 1] and patterns[depth + 1] ~= "" then
		box:SetAttribute("Pattern", patterns[depth + 1])
		box:SetAttribute("PatternRepeats", 1)
	end
	box.Parent = model
	-- Neon seams: two thin planes through the box show as a cross on every face (Table 12).
	for i, size in { Vector3.new(studs * 1.04, studs * 1.04, 0.08), Vector3.new(0.08, studs * 1.04, studs * 1.04) } do
		local seam = part({ Name = `Seam{i}`, Size = size, CFrame = CFrame.new(center), Material = Enum.Material.Neon, Color = Color3.fromHex(Config.Tick.seamColor) })
		seam.Parent = model
	end
	model.PrimaryPart = box
	-- Roblox hides a prompt whose spot is off screen, and a blocking Tick sits high on its lid: the
	-- prompt hangs at chest height under the Tick, where a player facing that wall is looking.
	local spot = Instance.new("Attachment")
	spot.Name = "PromptSpot"
	spot.Parent = box
	spot.WorldPosition = Vector3.new(center.X, info.base.Y + math.min(center.Y - info.base.Y, Config.Tick.promptStuds), center.Z)
	local pr = prompt(spot, "TickPrompt", "Open", "Tick", Config.Tick.openSeconds, info.reach)
	tick = { model = model, box = box, prompt = pr, depth = depth, blocking = blocking }
	model.Parent = folder
	setTickVisible(info.current >= depth)
	tickVolume()

	local done = timedHolds(pr)
	pr.Triggered:Connect(function(player)
		local ok = done(player)
		if ok and tick and tick.prompt == pr and RunState.get() == "Unwrapping" and not player:GetAttribute("Down") and near(player, spot.WorldPosition, pr.MaxActivationDistance) then
			Night.openTick()
		end
	end)
end

---------------------------------------------------------------- Jack

-- A decoration that rides on `root` (anchored): welded, so moving the root moves it.
local function rideOn(root: BasePart, p: BasePart, model: Model)
	p.Anchored = false
	p.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
end

-- Jack (N17, mild): a toy jack-in-the-box. The box wears the Tick's paper with its flaps folded open; a
-- coiled spring; a round toy head with a painted grin, blush, a clown nose, a ruff and a two-point
-- jester cap; a crank on the side. Moving parts: Box, Rings, Head, Arm, Knob (placeJack); the rest
-- is welded to the Box or the Head.
local function buildJack(at: Vector3)
	local j, look = Config.Night, Config.JackLook
	local s = j.jackBoxStuds
	local model = Instance.new("Model")
	model.Name = "Jack"
	local color = if tick then tick.box.Color else Color3.fromHex(Config.Palette.cardboard)
	local pattern = if tick then tick.box:GetAttribute("Pattern") else nil
	local box = part({ Name = "Box", Size = Vector3.one * s, Color = color, CFrame = CFrame.new(at + UP * s / 2) })
	box:SetAttribute("Pattern", pattern)
	box:SetAttribute("PatternRepeats", 1)
	box.Parent = model
	local light = Instance.new("PointLight") -- the cold rim light from the Tick box
	light.Color = Color3.fromHex(Config.Tick.rimLightColor)
	light.Range = Config.Tick.rimLightRange
	light.Brightness = Config.Tick.rimLightBrightness
	light.Parent = box
	-- A pattern draws on a part's front face: three thin skins carry the paper round the other sides.
	for _, n in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis } do
		local skin = part({ Name = "Skin", Size = Vector3.new(s, s, 0.05), Color = color, CFrame = box.CFrame * CFrame.lookAt(n * (s / 2 + 0.03), n * s) })
		skin:SetAttribute("Pattern", pattern)
		skin:SetAttribute("PatternRepeats", 1)
		rideOn(box, skin, model)
	end
	for _, side in { -1, 1 } do
		local flap = part({ Name = "Flap", Size = Vector3.new(s, 0.08, s / 2), Color = color, CFrame = box.CFrame * CFrame.new(0, s / 2, side * s / 2) * CFrame.Angles(-side * math.rad(look.flapOpenDegrees), 0, 0) * CFrame.new(0, 0, side * s / 4) })
		rideOn(box, flap, model)
	end

	for k = 1, look.springRings do
		local ring = part({ Name = `Ring{k}`, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.22, look.springStuds, look.springStuds), Color = Color3.fromHex(if k % 2 == 0 then look.springDark else look.spring), Material = Enum.Material.Metal })
		ring.Parent = model
	end

	local headSize = math.max(j.jackHeadStuds - s, 2) -- a head the size of a player, on the spring
	local r = headSize / 2
	local head = part({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.one * headSize, Color = Color3.fromHex(look.face) })
	head.Parent = model
	local hcf = head.CFrame
	local function onHead(name: string, shape: Enum.PartType, size: Vector3, offset: CFrame, hex: string)
		rideOn(head, part({ Name = name, Shape = shape, Size = size, CFrame = hcf * offset, Color = Color3.fromHex(hex) }), model)
	end
	for _, side in { -1, 1 } do
		onHead("Eye", Enum.PartType.Ball, Vector3.one * r * 0.26, CFrame.new(side * r * 0.34, r * 0.22, -r * 0.86), look.ink)
		onHead("Blush", Enum.PartType.Ball, Vector3.one * r * 0.24, CFrame.new(side * r * 0.6, -r * 0.12, -r * 0.74), look.blush)
	end
	onHead("Nose", Enum.PartType.Ball, Vector3.one * r * 0.3, CFrame.new(0, 0, -r * 0.98), look.nose)
	for k = -2, 2 do
		local a = math.rad(k * 24)
		local x, y = r * 0.5 * math.sin(a), -r * 0.42 + r * 0.22 * (1 - math.cos(a))
		local z = -math.sqrt(math.max(0, r * r - x * x - y * y)) + 0.03
		onHead("Grin", Enum.PartType.Block, Vector3.new(r * 0.2, r * 0.1, r * 0.1), CFrame.new(x, y, z), look.ink)
	end
	onHead("Ruff", Enum.PartType.Cylinder, Vector3.new(r * 0.3, headSize * 1.15, headSize * 1.15), CFrame.new(0, -r * 0.95, 0) * CFrame.Angles(0, 0, math.pi / 2), look.collar)
	for i, side in { -1, 1 } do
		local horn = CFrame.new(side * r * 0.42, r * 0.62, 0) * CFrame.Angles(0, 0, -side * math.rad(35))
		for k = 0, 2 do
			local d = r * (0.8 - k * 0.24)
			onHead("Cap", Enum.PartType.Cylinder, Vector3.new(r * 0.32, d, d), horn * CFrame.new(0, k * r * 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2), look.hat[i])
		end
		onHead("Bell", Enum.PartType.Ball, Vector3.one * r * 0.28, horn * CFrame.new(0, r * 0.98, 0), look.hat[3 - i])
	end

	local arm = part({ Name = "Arm", Size = Vector3.new(0.2, 0.9, 0.2), Color = Color3.fromHex(look.crank), Material = Enum.Material.Metal })
	arm.Parent = model
	local knob = part({ Name = "Knob", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.42, Color = Color3.fromHex(look.collar) })
	knob.Parent = model
	model.PrimaryPart = box
	jackModel = model
	model.Parent = folder
end

local function placeJack(dt: number)
	local brain, model = jack, jackModel
	if not brain or not model then
		return
	end
	local j, look = Config.Night, Config.JackLook
	local s = j.jackBoxStuds
	local floor = Vector3.new(brain.pos.x, roomCenter.Y, brain.pos.z)
	local facing = Vector3.new(brain.dir.x, 0, brain.dir.z)
	facing = if facing.Magnitude > 1e-3 then facing.Unit else Vector3.xAxis
	local boxCf = CFrame.lookAt(floor + UP * s / 2, floor + UP * s / 2 + facing)
	;(model:FindFirstChild("Box") :: BasePart).CFrame = boxCf
	-- The spring stretches while he lunges (Table 14).
	local head = model:FindFirstChild("Head") :: BasePart
	local stretch = if brain.phase == "Lunge" then look.lungeStretch else 1
	local bottom = s
	local top = bottom + (j.jackHeadStuds - head.Size.Y / 2 - s) * stretch
	for k = 1, look.springRings do
		local ring = model:FindFirstChild(`Ring{k}`) :: BasePart?
		if ring then
			local y = bottom + (k - 0.5) / look.springRings * (top - bottom)
			local wobble = boxCf.RightVector * (if k % 2 == 0 then 0.12 else -0.12) -- a coil, side to side
			ring.CFrame = CFrame.new(floor + UP * y + wobble) * CFrame.Angles(0, 0, math.pi / 2)
		end
	end
	local headPos = floor + UP * (top + head.Size.Y / 2)
	head.CFrame = CFrame.lookAt(headPos, headPos + facing)
	if brain.phase == "Still" then
		crankAngle += dt * 2 * math.pi -- the crank turns while he waits
	end
	local hub = boxCf * CFrame.new(s / 2 + 0.15, 0, 0) * CFrame.Angles(crankAngle, 0, 0)
	;(model:FindFirstChild("Arm") :: BasePart).CFrame = hub * CFrame.new(0, 0.4, 0)
	;(model:FindFirstChild("Knob") :: BasePart).CFrame = hub * CFrame.new(0.25, 0.8, 0)
end

-- Where Jack comes out: on the floor below the Tick, pushed out past the current layer.
local function jackSpawn(): Vector3
	local info = Tear.getRunInfo()
	local from = if tick then tick.box.Position else roomCenter
	if not info then
		return Vector3.new(from.X, roomCenter.Y, from.Z)
	end
	local flat = Vector3.new(from.X - info.base.X, 0, from.Z - info.base.Z)
	local dir = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.xAxis
	local s = info.sizes[info.current] or 0
	local out = s * 0.75 + N.jackRadiusStuds + 0.5 -- past the corner of the current layer
	return info.base + dir * math.max(flat.Magnitude, out)
end

---------------------------------------------------------------- downs and revives

local function applyDown(player: Player, d: Down)
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.Sit = true
	end
	local root = rootOf(player)
	if root and not d.prompt then
		local pr = prompt(root, "RevivePrompt", "Revive", player.DisplayName, N.reviveHoldSeconds, N.reachStuds)
		pr:SetAttribute("HideFor", player.UserId) -- the HUD never offers a player their own revive
		d.prompt = pr
		local done = timedHolds(pr)
		pr.Triggered:Connect(function(reviver)
			local ok = done(reviver)
			if ok and reviver ~= player and not reviver:GetAttribute("Down") and downs[player] == d and near(reviver, root.Position, N.reachStuds) then
				Night.revive(player)
			end
		end)
	end
end

local function dropTool(player: Player)
	if Economy.hasPass(player, "ToolKeeper") then
		return -- Tool Keeper: tools are never dropped (Table 10)
	end
	local owned = {}
	for _, name in Tools.order do
		owned[name] = player:GetAttribute(`Tool_{name}`) == true
	end
	local name = NightRules.toolToDrop(owned, Tools.order)
	local root = rootOf(player)
	if not name or not root then
		return
	end
	player:SetAttribute(`Tool_{name}`, nil)
	local s = Config.Greybox.pickupStuds
	local away = Vector3.new(root.Position.X - roomCenter.X, 0, root.Position.Z - roomCenter.Z)
	away = if away.Magnitude > 1e-3 then away.Unit else Vector3.xAxis
	local pickup = part({
		Name = "DroppedTool",
		Size = Vector3.new(s, s / 2, s),
		Position = Vector3.new(root.Position.X, roomCenter.Y + s / 4, root.Position.Z) + away * N.jackHitStuds,
		CanTouch = true,
	})
	pickup:SetAttribute("ToolName", name)
	ToolModels.dress(pickup, name)
	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromScale(4, 1)
	label.StudsOffset = Vector3.new(0, s, 0)
	label.AlwaysOnTop = true
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font[Config.UI.font]
	text.TextColor3 = Color3.fromHex(Config.UI.cream)
	text.TextStrokeColor3 = Color3.fromHex(Config.UI.woodDark)
	text.TextStrokeTransparency = 0
	text.Text = ({ Scissors = "Scissors", BoxCutter = "Box cutter", Chainsaw = "Chainsaw" } :: any)[name] or name
	text.Parent = label
	label.Parent = pickup
	-- Anyone up can take it, a teammate included, or its owner after a revive (DECISIONS.md, auto-tools).
	pickup.Touched:Connect(function(other)
		local taker = Players:GetPlayerFromCharacter(other.Parent)
		if taker and pickup.Parent and not taker:GetAttribute("Down") and not taker:GetAttribute(`Tool_{name}`) then
			taker:SetAttribute(`Tool_{name}`, true)
			pickup:Destroy()
		end
	end)
	pickup.Parent = folder
end

local checkWipe: () -> ()

local function soloRevive(player: Player)
	local runToken = token
	soloTimer = task.delay(N.soloAutoReviveSeconds, function()
		soloTimer = nil
		if token == runToken and downs[player] then
			Loot.removeCommon() -- the solo cost: one Common side-gift (Table 20)
			Night.revive(player)
		end
	end)
end

-- Jack's lunge connected (or Studio's DevDown): the player goes down.
function Night.down(player: Player)
	if downs[player] or not active then
		return
	end
	local humanoid = humanoidOf(player)
	local d: Down = {
		walk = if humanoid then humanoid.WalkSpeed else 16,
		jumpPower = if humanoid then humanoid.JumpPower else 50,
		jumpHeight = if humanoid then humanoid.JumpHeight else 7.2,
		prompt = nil,
		token = token,
	}
	downs[player] = d
	player:SetAttribute("Down", true)
	Tear.cancelHold(player)
	for _, shutter in shutters do
		shutter.holders[player] = nil
	end
	dropTool(player)
	applyDown(player, d)
	Loot.noteDown()
	nightState:FireAllClients({ kind = "Down", userId = player.UserId })
	checkWipe()
end

function Night.revive(player: Player)
	local d = downs[player]
	if not d then
		return
	end
	downs[player] = nil
	if d.prompt then
		d.prompt:Destroy()
	end
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.Sit = false
		humanoid.WalkSpeed = d.walk
		humanoid.JumpPower = d.jumpPower
		humanoid.JumpHeight = d.jumpHeight
	end
	player:SetAttribute("Down", nil)
	nightState:FireAllClients({ kind = "Revive", userId = player.UserId })
end

---------------------------------------------------------------- shutters

local function dropShutter(lid: BasePart)
	local shutter = shutters[lid]
	if not shutter then
		return
	end
	shutters[lid] = nil
	lid.CanCollide = true
	local pr = lid:FindFirstChild("ShutterPrompt") :: ProximityPrompt?
	if pr then
		-- Toggling ends every client's hold, so the 4 s cap is felt on the button too.
		pr.Enabled = false
		task.defer(function()
			pr.Enabled = active
		end)
	end
end

local function addShutterPrompt(lid: BasePart)
	if lid:FindFirstChild("ShutterPrompt") then
		return
	end
	local pr = prompt(lid, "ShutterPrompt", "Shutter", "Lid", N.shutterMaxSeconds, math.max(N.reachStuds, lid.Size.Y * 0.75))
	pr.Enabled = active
	pr.PromptButtonHoldBegan:Connect(function(player)
		if not active or player:GetAttribute("Down") then
			return
		end
		local shutter = shutters[lid]
		if not shutter then
			shutter = { holders = {}, since = os.clock() }
			shutters[lid] = shutter
			lid.CanCollide = false
		end
		shutter.holders[player] = true
	end)
	pr.PromptButtonHoldEnded:Connect(function(player)
		local shutter = shutters[lid]
		if shutter then
			shutter.holders[player] = nil
			if next(shutter.holders) == nil then
				dropShutter(lid)
			end
		end
	end)
	pr.Triggered:Connect(function()
		dropShutter(lid) -- held for the full 4 s
	end)
end

local function moveShutters()
	local brain = jack
	if not brain then
		return
	end
	local now = os.clock()
	for lid, shutter in shutters do
		local spots = {}
		for player in shutter.holders do
			local root = rootOf(player)
			if root and player.Parent and not player:GetAttribute("Down") then
				table.insert(spots, vec(root.Position))
			else
				shutter.holders[player] = nil
			end
		end
		if #spots == 0 or now - shutter.since >= N.shutterMaxSeconds then
			dropShutter(lid)
		else
			local spot, dir = NightRules.shutterSpot(spots, brain.pos, N.shutterOffsetStuds)
			local center = Vector3.new(spot.x, roomCenter.Y + lid.Size.Y / 2, spot.z)
			lid.CFrame = CFrame.lookAt(center, center + Vector3.new(dir.x, 0, dir.z))
		end
	end
end

-- Spare lid (Table 7): one extra shutter prop, stood up beside the buyer.
local function spareLid(player: Player)
	local props = workspace:FindFirstChild("LidProps")
	local root = rootOf(player)
	if spareGiven[player] or not props or not root then
		return
	end
	spareGiven[player] = true
	local s = Config.Tiers.coreBoxStuds
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = if look.Magnitude > 1e-3 then look.Unit else Vector3.xAxis
	local center = Vector3.new(root.Position.X, roomCenter.Y + s / 2, root.Position.Z) + look * N.shutterOffsetStuds
	local lid = Instance.new("Part")
	lid.Name = "LidProp"
	lid.Anchored = true
	lid.Size = Vector3.new(s, s, Config.Greybox.panelThickness)
	lid.CFrame = CFrame.lookAt(center, center + look)
	lid.Color = Color3.fromHex(Config.Palette.cardboard)
	lid.Material = Enum.Material.Cardboard
	lid.CanQuery = false
	lid:SetAttribute("Kind", "LidProp")
	lid:SetAttribute("Print", true)
	lid.Parent = props
end

---------------------------------------------------------------- the Night

local function lightFor(player: Player)
	local data = Data.get(player)
	local eyes = Config.PermanentTrack.NightEyes
	local flash = if player:GetAttribute("Upgrade_Flashlight") then Config.Shop.Flashlight.nightLightingScale else nil
	player:SetAttribute("NightLight", NightRules.lighting(N.lightingScale, flash, data and data.upgrades.nightEyes or 0, eyes.lightingPerLevel, eyes.maxBonus))
end

local function step(dt: number)
	local brain = jack
	if not active or not brain then
		return
	end
	local bodies = {}
	local byId: { [number]: Player } = {}
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root then
			byId[player.UserId] = player
			local sprinter = Economy.classOf(player) == "Sprinter"
			table.insert(bodies, {
				id = player.UserId,
				pos = vec(root.Position),
				down = downs[player] ~= nil,
				lungeScale = if sprinter then Config.Classes.Sprinter.jackLungeScale else 1,
			})
		end
	end
	moveShutters()
	local out = JackBrain.step(brain, dt, bodies, sightBoxes(), jackRules())
	if out.lunged then
		nightState:FireAllClients({ kind = "Lunge" })
	end
	for _, id in out.hits do
		local player = byId[id]
		if player then
			Night.down(player)
		end
	end
	placeJack(dt)
end

local function teardown()
	active = false
	if beat then
		beat:Disconnect()
		beat = nil
	end
	if timer and coroutine.running() ~= timer then
		task.cancel(timer)
	end
	timer = nil
	if jackModel then
		jackModel:Destroy()
	end
	jack, jackModel = nil, nil
	for lid in shutters do
		dropShutter(lid)
	end
	for _, lid in lidProps() do
		local pr = lid:FindFirstChild("ShutterPrompt")
		if pr then
			pr:Destroy()
		end
	end
	for _, player in Players:GetPlayers() do
		player:SetAttribute("NightLight", nil)
	end
end

-- Ends the Night: "timer" (it ran out), "core" (the team reached the core lid) or "wipe".
function Night.endNight(reason: string)
	if not active then
		return
	end
	teardown()
	nightState:FireAllClients({ secondsLeft = nil })
	if reason == "wipe" then
		RunState.set("Wipe")
		Loot.wipe()
		return
	end
	-- Jack is back in his box: everyone down gets up (DECISIONS.md), and the Tick was survived.
	for player in downs do
		Night.revive(player)
	end
	Loot.noteTickSurvived()
	if RunState.get() == "Night" then
		RunState.set("Unwrapping")
	end
end

checkWipe = function()
	if not active then
		return
	end
	local players = Players:GetPlayers()
	local down = 0
	for _, player in players do
		if downs[player] then
			down += 1
		end
	end
	if NightRules.isWipe(#players, down) then
		Night.endNight("wipe")
	elseif NightRules.soloRevives(#players) and down == 1 and not soloTimer then
		soloRevive(players[1])
	end
end

local function startNight()
	local info = Tear.getRunInfo()
	if not info then
		return
	end
	active = true
	RunState.set("Night")
	local seconds = Config.Tiers[info.nest.tier].nightSeconds
	endsAt = os.clock() + seconds
	for _, player in Players:GetPlayers() do
		lightFor(player)
	end
	nightState:FireAllClients({ secondsLeft = seconds })
	jack = JackBrain.new(vec(jackSpawn()), jackRules())
	buildJack(jackSpawn())
	placeJack(0)
	for _, lid in lidProps() do
		addShutterPrompt(lid)
	end
	beat = RunService.Heartbeat:Connect(step)
	timer = task.delay(seconds, function()
		timer = nil
		Night.endNight("timer")
	end)
end

-- The Tick opens: it drops the run's best side-gifts and the Night starts (Diagram B).
function Night.openTick()
	local t = tick
	if not t or active or RunState.get() ~= "Unwrapping" then
		return
	end
	t.prompt:Destroy()
	t.model:SetAttribute("Opened", true)
	Tear.openTick()
	Loot.tickOpened(t.depth)
	startNight() -- Jack comes out where the Tick was, in its colour
	tick = nil
	t.model:Destroy()
end

---------------------------------------------------------------- public

-- A new run (Present -> Night): no Night, nobody down, the Tick built where the Nest put it.
-- `center` is the run room's floor point at its middle (Jack never leaves the room).
function Night.startRun(center: Vector3)
	token += 1
	roomCenter = center
	teardown()
	for player in downs do
		Night.revive(player)
	end
	if soloTimer then
		task.cancel(soloTimer)
		soloTimer = nil
	end
	spareGiven = {}
	tick = nil
	folder:ClearAllChildren()
	local info = Tear.getRunInfo()
	if info then
		buildTick(info)
	end
end

function Night.isActive(): boolean
	return active
end

function Night.init()
	nightState = Remotes.get("NightState")
	folder = Instance.new("Folder")
	folder.Name = "Night"
	folder.Parent = workspace

	Tear.onLayerCleared(function(depth)
		local info = Tear.getRunInfo()
		if not info then
			return
		end
		if tick and info.current >= tick.depth and not tick.model:GetAttribute("Revealed") then
			setTickVisible(true)
		end
		if tick and depth >= #info.nest.layers - 2 then
			tick.prompt.Enabled = false -- the core lid is reached: too late to open it
		end
		tickVolume()
		if active and depth >= #info.nest.layers - 2 then
			Night.endNight("core")
		end
	end)

	local workspaceProps: RBXScriptConnection? = nil
	local function watchProps()
		local props = workspace:FindFirstChild("LidProps")
		if workspaceProps then
			workspaceProps:Disconnect()
			workspaceProps = nil
		end
		if props then
			workspaceProps = props.ChildAdded:Connect(function(child)
				if active and child:IsA("BasePart") then
					addShutterPrompt(child)
				end
			end)
		end
	end
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "LidProps" then
			watchProps()
		end
	end)
	watchProps()

	local function watchPlayer(player: Player)
		player.AttributeChanged:Connect(function(name)
			if name == "Upgrade_SpareLid" and player:GetAttribute(name) == true then
				spareLid(player)
			elseif name == "Upgrade_Flashlight" and active then
				lightFor(player)
			end
		end)
		player.CharacterAdded:Connect(function()
			local d = downs[player]
			if d then
				d.prompt = nil -- the old prompt went with the old character
				task.defer(applyDown, player, d)
			end
		end)
		if active then
			lightFor(player)
			nightState:FireClient(player, { secondsLeft = math.max(0, endsAt - os.clock()) })
		end
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		downs[player] = nil
		spareGiven[player] = nil
		for _, shutter in shutters do
			shutter.holders[player] = nil
		end
		task.defer(checkWipe)
	end)

	if RunService:IsStudio() then
		-- Studio only: Workspace attribute DevNight opens the Tick at once, wherever it is; DevDown
		-- downs the first player (solo: checks the auto-revive); DevWipe ends the Night as a wipe
		-- (a real wipe needs two players). Never in a live server.
		workspace:GetAttributeChangedSignal("DevWipe"):Connect(function()
			if workspace:GetAttribute("DevWipe") then
				workspace:SetAttribute("DevWipe", nil)
				Night.endNight("wipe")
			end
		end)
		workspace:GetAttributeChangedSignal("DevNight"):Connect(function()
			if workspace:GetAttribute("DevNight") then
				workspace:SetAttribute("DevNight", nil)
				Night.openTick()
			end
		end)
		workspace:GetAttributeChangedSignal("DevDown"):Connect(function()
			if workspace:GetAttribute("DevDown") then
				workspace:SetAttribute("DevDown", nil)
				local first = Players:GetPlayers()[1]
				if first then
					Night.down(first)
				end
			end
		end)
	end
end

return Night
