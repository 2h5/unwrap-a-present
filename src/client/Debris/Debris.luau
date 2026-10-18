--[=[
	Debris (client system)
	Owns: Torn-panel pool, 40 live max, physics, recycle.
	Must never: Exceed the budget (Config.Tear.maxLiveDebris). Pieces are local to this client.
	On a tear: swaps the panel for a torn-edge piece (ReplicatedStorage.Assets.TornPanel if it
	exists, else a part in the panel's color), pushes it away from the present, flutters it, then it settles and
	stays until the pool recycles it, oldest first; a soft thud plays on first landing.
	Slot logic is pure and tested: DebrisPool.luau.
	Read first: src/client/Debris/README.md
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local DebrisPool = require(script.Parent.DebrisPool)
local Sfx = require(ReplicatedStorage.Shared.Sfx.Sfx)

type Piece = { part: BasePart, lift: VectorForce, token: number, landed: boolean }

local Debris = {}

local pool = DebrisPool.new(Config.Tear.maxLiveDebris)
local pieces: { [number]: Piece } = {}
local folder: Folder
local rng = Random.new()

local function template(): BasePart
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local torn = assets and assets:FindFirstChild("TornPanel")
	if torn and torn:IsA("BasePart") then
		return torn:Clone()
	end
	return Instance.new("Part")
end

local function newPiece(): Piece
	local part = template()
	part.Name = "TornPanel"
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	local attachment = Instance.new("Attachment")
	attachment.Parent = part
	local lift = Instance.new("VectorForce")
	lift.Attachment0 = attachment
	lift.RelativeTo = Enum.ActuatorRelativeTo.World
	lift.ApplyAtCenterOfMass = true
	lift.Enabled = false
	lift.Parent = part
	local piece: Piece = { part = part, lift = lift, token = 0, landed = true }
	-- First contact with anything but the present or a player (other debris counts): one soft thud.
	part.Touched:Connect(function(other)
		if piece.landed then
			return
		end
		local present = workspace:FindFirstChild("Present")
		if present and other:IsDescendantOf(present) then
			return
		end
		local model = other:FindFirstAncestorWhichIsA("Model")
		if model and model:FindFirstChildOfClass("Humanoid") then
			return -- a player, including their accessories
		end
		piece.landed = true
		Sfx.playAt(Config.Sounds.paperLand, part.Position)
	end)
	return piece
end

local function spin(): number
	return rng:NextNumber(-Config.Tear.debrisSpinMax, Config.Tear.debrisSpinMax)
end

-- Swaps a torn panel for a debris piece. `panel` is the panel part; its front (-Z) faces out.
function Debris.spawn(panel: BasePart)
	local id = DebrisPool.acquire(pool)
	local piece = pieces[id]
	if not piece then
		piece = newPiece()
		pieces[id] = piece
	end
	piece.token += 1
	local token = piece.token
	local part = piece.part

	part.Anchored = true
	part.Size = panel.Size
	part.CFrame = panel.CFrame
	part.Color = panel.Color -- torn paper is the same paper
	part.Material = panel.Material
	part.Reflectance = panel.Reflectance
	part.CanCollide = true
	part.CanTouch = true
	part.Transparency = 0
	piece.landed = false
	part.Parent = folder
	part.Anchored = false

	part.AssemblyLinearVelocity = panel.CFrame.LookVector * Config.Tear.debrisImpulse
	part.AssemblyAngularVelocity = Vector3.new(spin(), spin(), spin())
	piece.lift.Force = Vector3.yAxis * part.AssemblyMass * workspace.Gravity * (1 - Config.Tear.debrisFallScale)
	piece.lift.Enabled = true

	task.delay(Config.Tear.flutterSeconds, function()
		if piece.token ~= token then
			return -- recycled while it was still fluttering
		end
		piece.lift.Enabled = false
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		piece.landed = true
	end)
end

function Debris.liveCount(): number
	return DebrisPool.liveCount(pool)
end

function Debris.init()
	folder = Instance.new("Folder")
	folder.Name = "Debris"
	folder.Parent = workspace
end

return Debris
