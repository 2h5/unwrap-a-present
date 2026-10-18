--[=[
	Room (server, part of Present)
	Owns: building the run room once (Diagram D): one 60 by 60 interior with a warm wood floor, plaster
	walls over a wood wainscot, thick corner posts and ceiling beams, one wide window on the east wall
	with daylight through it and a little garden outside, a door behind the spawn, four hanging lamps,
	and warm interior lighting. Replaces Roblox's template baseplate and spawn.
	Must never: put a prop on the floor (the floor around the present stays clear for tearing, lid cover
	and Jack; the shop counter is Economy's, lid props are Tear's), or hold game logic.
	Read first: src/server/Present/README.md
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Props = require(ReplicatedStorage.Shared.Art.Props)

local Room = {}

local R = Config.RunRoom
local C = R.colors

-- Builds the room around `center` (the floor point at its middle). Returns the folder.
function Room.build(center: Vector3): Folder
	Props.clearTemplate()
	Props.applyLighting("Run")
	local folder = Instance.new("Folder")
	folder.Name = "Room"
	local half, H, t = R.sizeStuds / 2, R.wallStuds, R.wallThickness
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(center + Vector3.new(x, y, z))
	end

	-- Floor and ceiling.
	Props.part(folder, "Floor", Vector3.new(R.sizeStuds + 2 * t, 1, R.sizeStuds + 2 * t), at(0, -0.5, 0), C.floor, "WoodPlanks")
	Props.part(folder, "Ceiling", Vector3.new(R.sizeStuds + 2 * t, 1, R.sizeStuds + 2 * t), at(0, H + 0.5, 0), C.ceiling, "WoodPlanks")

	-- A wall along one side: `axis` "X" runs along x at z = side * half (north / south), "Z" along z.
	-- `openings` are { from, to, bottom, top } spans (along the wall) left open for the window or door.
	local function wall(name: string, axis: string, side: number, openings: { { number } })
		local inward = if axis == "X" then Vector3.new(0, 0, -side) else Vector3.new(-side, 0, 0)
		local along = if axis == "X" then Vector3.xAxis else Vector3.zAxis
		local mid = if axis == "X" then Vector3.new(0, 0, side * (half + t / 2)) else Vector3.new(side * (half + t / 2), 0, 0)
		-- Solid pieces between openings: below, above and beside each opening.
		local cuts = { { -half - t, -half - t, 0, H } }
		for _, o in openings do
			table.insert(cuts, o)
		end
		table.insert(cuts, { half + t, half + t, 0, H })
		table.sort(cuts, function(a, b)
			return a[1] < b[1]
		end)
		local function slab(from: number, to: number, bottom: number, top: number)
			if to - from <= 0.01 or top - bottom <= 0.01 then
				return
			end
			local c = center + mid + along * ((from + to) / 2) + Vector3.yAxis * ((bottom + top) / 2)
			local size = if axis == "X" then Vector3.new(to - from, top - bottom, t) else Vector3.new(t, top - bottom, to - from)
			Props.part(folder, name, size, CFrame.new(c), C.wall, "SmoothPlastic")
		end
		for k = 1, #cuts - 1 do
			slab(cuts[k][2], cuts[k + 1][1], 0, H)
		end
		for _, o in openings do
			slab(o[1], o[2], 0, o[3])
			slab(o[1], o[2], o[4], H)
		end
		-- Wainscot, chair rail and baseboard on the inside face, broken where an opening comes down low.
		local function band(from: number, to: number, bottom: number, top: number, depth: number, color: string, material: string)
			if to - from <= 0.01 then
				return
			end
			local face = center + mid + inward * (t / 2 + depth / 2) + along * ((from + to) / 2) + Vector3.yAxis * ((bottom + top) / 2)
			local size = if axis == "X" then Vector3.new(to - from, top - bottom, depth) else Vector3.new(depth, top - bottom, to - from)
			Props.trim(folder, "Wainscot", size, CFrame.new(face), color, material)
		end
		local spans = { { -half, half } }
		for _, o in openings do
			if o[3] < R.wainscotStuds then -- a door cuts through the wainscot
				local out = {}
				for _, s in spans do
					if o[1] > s[1] then
						table.insert(out, { s[1], math.min(s[2], o[1]) })
					end
					if o[2] < s[2] then
						table.insert(out, { math.max(s[1], o[2]), s[2] })
					end
				end
				spans = out
			end
		end
		for _, s in spans do
			band(s[1], s[2], 0, R.wainscotStuds, 0.4, C.wainscot, "WoodPlanks")
			band(s[1], s[2], R.wainscotStuds, R.wainscotStuds + 0.5, 0.7, C.trim, "Wood")
			band(s[1], s[2], 0, 0.8, 0.6, C.trim, "Wood")
		end
		-- The top plate under the ceiling.
		band(-half, half, H - 1.5, H, 0.9, C.beam, "Wood")
	end

	local W = R.window
	local wz, wy = W.widthStuds / 2, W.sillStuds
	local D = R.door
	local door = { -D.widthStuds / 2, D.widthStuds / 2, 0, D.heightStuds }
	wall("NorthWall", "X", -1, {})
	wall("SouthWall", "X", 1, { door })
	wall("WestWall", "Z", -1, {})
	wall("EastWall", "Z", 1, { { -wz, wz, wy, wy + W.heightStuds } })

	-- Thick corner posts and ceiling beams (the room's construction, not props).
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Props.part(folder, "Post", Vector3.new(2.4, H, 2.4), at(sx * (half - 1.2), H / 2, sz * (half - 1.2)), C.beam, "Wood")
		end
	end
	local beams = math.floor(R.sizeStuds / R.beamSpacingStuds)
	for k = 1, beams - 1 do
		local z = -half + k * R.beamSpacingStuds
		Props.trim(folder, "Beam", Vector3.new(R.sizeStuds, R.beamStuds, R.beamStuds), at(0, H - R.beamStuds / 2, z), C.beam, "Wood")
	end
	Props.trim(folder, "Ridge", Vector3.new(R.beamStuds, R.beamStuds * 0.8, R.sizeStuds), at(0, H - R.beamStuds * 0.4, 0), C.beam, "Wood")

	-- The window: sill, head, jambs, mullions and glass; daylight pours in through it.
	local wx = half + t / 2
	local frameC = C.trim
	Props.part(folder, "Sill", Vector3.new(t + 1.6, 0.8, W.widthStuds + 1.6), at(wx - 0.4, wy - 0.4, 0), frameC, "Wood")
	Props.trim(folder, "WindowHead", Vector3.new(t + 0.8, 1.2, W.widthStuds + 1.6), at(wx, wy + W.heightStuds + 0.6, 0), frameC, "Wood")
	for _, sz in { -1, 1 } do
		Props.trim(folder, "Jamb", Vector3.new(t + 0.8, W.heightStuds, 0.8), at(wx, wy + W.heightStuds / 2, sz * (wz + 0.4)), frameC, "Wood")
	end
	local panes = W.mullions + 1
	for k = 1, W.mullions do
		local z = -wz + k * W.widthStuds / panes
		Props.trim(folder, "Mullion", Vector3.new(0.6, W.heightStuds, 0.6), at(wx, wy + W.heightStuds / 2, z), frameC, "Wood")
	end
	Props.trim(folder, "Transom", Vector3.new(0.6, 0.6, W.widthStuds), at(wx, wy + W.heightStuds * 0.62, 0), frameC, "Wood")
	local glass = Props.part(folder, "Glass", Vector3.new(0.2, W.heightStuds, W.widthStuds), at(wx + 0.3, wy + W.heightStuds / 2, 0), C.glass, "Glass")
	glass.Transparency = 0.7
	glass.CastShadow = false
	local sun = Instance.new("SurfaceLight")
	sun.Name = "WindowLight" -- NightView drops it at Night (Diagram D)
	sun.Face = Enum.NormalId.Left -- into the room (-x)
	sun.Color = Color3.fromHex(R.windowLight.color)
	sun.Brightness = R.windowLight.brightness
	sun.Range = R.windowLight.range
	sun.Angle = R.windowLight.angle
	sun.Shadows = true
	sun.Parent = glass

	-- Outside the window: grass and a few chunky trees, so the daylight comes from somewhere.
	local rng = Random.new(7)
	Props.part(folder, "Garden", Vector3.new(80, 1, 120), at(half + t + 40, -0.6, 0), C.outside, "Grass")
	for k = 1, 5 do
		Props.tree(folder, center + Vector3.new(half + 18 + rng:NextNumber(0, 30), 0, -40 + k * 16 + rng:NextNumber(-4, 4)), rng:NextNumber(0.8, 1.2), rng)
	end

	-- The door the party came in by, behind the spawn.
	local dz = half + t / 2
	Props.trim(folder, "Door", Vector3.new(D.widthStuds, D.heightStuds, 0.6), at(0, D.heightStuds / 2, dz), C.wainscot, "WoodPlanks")
	for _, y in { D.heightStuds / 4, D.heightStuds * 3 / 4 } do
		Props.trim(folder, "DoorBrace", Vector3.new(D.widthStuds, 0.5, 0.3), at(0, y, dz - 0.45), C.trim, "Wood")
	end
	Props.trim(folder, "DoorKnob", Vector3.one * 0.5, at(D.widthStuds / 2 - 0.8, D.heightStuds / 2 - 0.2, dz - 0.6), C.trim, "Metal", Enum.PartType.Ball)
	Props.trim(folder, "DoorFrame", Vector3.new(D.widthStuds + 1.6, 0.8, t + 0.6), at(0, D.heightStuds + 0.4, dz), C.trim, "Wood")
	for _, sx in { -1, 1 } do
		Props.trim(folder, "DoorFrame", Vector3.new(0.8, D.heightStuds, t + 0.6), at(sx * (D.widthStuds / 2 + 0.4), D.heightStuds / 2, dz), C.trim, "Wood")
	end

	-- Four lamps hanging between the beams, high above the play space.
	local lamp = R.lampLight
	for k = 0, R.lampCount - 1 do
		local x = if k % 2 == 0 then -half / 2 else half / 2
		local z = if k < 2 then -half / 2 else half / 2
		local drop = 4
		Props.trim(folder, "LampCord", Vector3.new(0.15, drop, 0.15), at(x, H - drop / 2, z), C.trim, "Fabric")
		Props.trim(folder, "LampShade", Vector3.new(1.4, 2.6, 2.6), at(x, H - drop - 0.4, z) * CFrame.Angles(0, 0, math.pi / 2), C.wall, "Fabric", Enum.PartType.Cylinder)
		local bulb = Props.trim(folder, "LampBulb", Vector3.one * 0.9, at(x, H - drop - 1.1, z), lamp.color, "Neon", Enum.PartType.Ball)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromHex(lamp.color)
		light.Brightness = lamp.brightness
		light.Range = lamp.range
		light.Shadows = false
		light.Parent = bulb
	end

	-- The spawn, just inside the door, facing the present.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "RoomSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.2, 6)
	spawn.CFrame = CFrame.lookAt(center + Vector3.new(0, 0.1, half - 8), center + Vector3.new(0, 0.1, 0))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Parent = folder

	folder.Parent = workspace
	return folder
end

return Room
