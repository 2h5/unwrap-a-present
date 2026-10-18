-- Spec for src/server/Night/Sight.luau, JackBrain.luau and NightRules.luau. Numbers come from Config.

local Sight = require("../../src/server/Night/Sight")
local JackBrain = require("../../src/server/Night/JackBrain")
local NightRules = require("../../src/server/Night/NightRules")
local Config = require("../../src/shared/Config/Config")

local N = Config.Night

local RULES = {
	stillSeconds = N.jackStillSeconds,
	lungeSeconds = N.jackLungeSeconds,
	lungeSpeed = N.jackLungeSpeed,
	hitStuds = N.jackHitStuds,
	headStuds = N.jackHeadStuds,
	radius = N.jackRadiusStuds,
	roomCenter = { x = 0, y = 0, z = 0 },
	roomHalf = Config.RunRoom.sizeStuds / 2,
}

local function v(x, y, z)
	return { x = x, y = y, z = z }
end

-- An upright lid prop of side `s` standing on the floor at (x, z), its broad face toward ±X.
local function lidAt(x, z, s)
	return { center = v(x, s / 2, z), axes = { v(0, 0, 1), v(0, 1, 0), v(1, 0, 0) }, half = v(s / 2, s / 2, 0.1) }
end

local function body(id, x, z, down, scale)
	return { id = id, pos = v(x, 3, z), down = down or false, lungeScale = scale or 1 }
end

-- Runs Jack for `seconds` in steps of 1/30 s; returns every hit and lunge seen.
local function run(jack, seconds, bodies, boxes)
	local hits, lunges = {}, {}
	for _ = 1, math.floor(seconds * 30 + 0.5) do
		local out = JackBrain.step(jack, 1 / 30, bodies, boxes, RULES)
		if out.lunged then
			table.insert(lunges, out.lunged.id)
		end
		for _, id in out.hits do
			table.insert(hits, id)
		end
	end
	return hits, lunges
end

return function(test, expectEqual)
	test("sight: a box between blocks, a box beside does not", function()
		local box = Sight.aabb(v(0, 2, 0), v(4, 4, 4))
		expectEqual(Sight.crosses(v(-10, 2, 0), v(10, 2, 0), box), true, "through")
		expectEqual(Sight.crosses(v(-10, 2, 5), v(10, 2, 5), box), false, "beside")
		expectEqual(Sight.crosses(v(-10, 2, 0), v(-5, 2, 0), box), false, "stops short")
		expectEqual(Sight.crosses(v(-10, 9, 0), v(10, 9, 0), box), false, "over the top")
	end)

	test("sight: an upright lid blocks the player crouched behind it, not one beside it", function()
		local lid = lidAt(0, 0, 6)
		local eye = v(-12, N.jackHeadStuds, 0)
		expectEqual(Sight.blocked(eye, v(2, 3, 0), { lid }), true, "behind")
		expectEqual(Sight.blocked(eye, v(2, 3, 8), { lid }), false, "beside")
	end)

	test("jack: still for the still time, then lunges at the nearest player in sight", function()
		local jack = JackBrain.new(v(0, 0, 20), RULES)
		local bodies = { body("far", 0, -20), body("near", 0, 10) }
		local _, lunges = run(jack, N.jackStillSeconds - 0.1, bodies, {})
		expectEqual(#lunges, 0, "no lunge while still")
		_, lunges = run(jack, 0.2, bodies, {})
		expectEqual(lunges[1], "near", "nearest")
		expectEqual(jack.phase, "Lunge", "lunging")
	end)

	test("jack: a lunge that connects downs the player and ends the lunge", function()
		local jack = JackBrain.new(v(0, 0, 20), RULES)
		local hits = run(jack, N.jackStillSeconds + N.jackLungeSeconds, { body("a", 0, 5) }, {})
		expectEqual(hits[1], "a", "hit")
		expectEqual(#hits, 1, "one hit")
		expectEqual(jack.phase, "Still", "back to still")
	end)

	test("jack: nobody in sight, nobody lunged at; hidden behind a lid is safe", function()
		local jack = JackBrain.new(v(-15, 0, 0), RULES)
		local hits, lunges = run(jack, 10, { body("hider", 2, 0) }, { lidAt(0, 0, 8) })
		expectEqual(#lunges, 0, "no lunge")
		expectEqual(#hits, 0, "no hit")
		expectEqual(jack.pos.x, -15, "did not move")
	end)

	test("jack: a lunge stops at a box and never leaves the room", function()
		local jack = JackBrain.new(v(-20, 0, 0), RULES)
		jack.phase, jack.timer, jack.dir, jack.speed = "Lunge", 10, v(1, 0, 0), N.jackLungeSpeed
		run(jack, 2, {}, { Sight.aabb(v(0, 8, 0), v(16, 16, 16)) })
		assert(jack.pos.x <= -8 - N.jackRadiusStuds + 1e-6, `went into the present: {jack.pos.x}`)
		local edge = JackBrain.new(v(25, 0, 0), RULES)
		edge.phase, edge.timer, edge.dir, edge.speed = "Lunge", 10, v(1, 0, 0), N.jackLungeSpeed
		run(edge, 2, {}, {})
		assert(edge.pos.x <= RULES.roomHalf - N.jackRadiusStuds + 1e-6, `left the room: {edge.pos.x}`)
	end)

	test("jack: Sprinter lunges run at the class's scale; down players are ignored", function()
		local jack = JackBrain.new(v(0, 0, 20), RULES)
		local _, lunges = run(jack, N.jackStillSeconds + 0.05, { body("down", 0, 15, true), body("sprinter", 0, -15, false, Config.Classes.Sprinter.jackLungeScale) }, {})
		expectEqual(lunges[1], "sprinter", "skips the downed player")
		expectEqual(jack.speed, N.jackLungeSpeed * Config.Classes.Sprinter.jackLungeScale, "slower lunge")
	end)

	test("downs: a wipe is everyone down, never a solo player", function()
		expectEqual(NightRules.isWipe(1, 1), false, "solo")
		expectEqual(NightRules.isWipe(2, 1), false, "one of two")
		expectEqual(NightRules.isWipe(2, 2), true, "two of two")
		expectEqual(NightRules.isWipe(4, 4), true, "four of four")
		expectEqual(NightRules.soloRevives(1), true, "solo revives")
		expectEqual(NightRules.soloRevives(2), false, "party does not")
	end)

	test("downs: the highest-grade tool drops, never hands", function()
		local order = { "Hands", "Scissors", "BoxCutter", "Chainsaw" }
		expectEqual(NightRules.toolToDrop({ Scissors = true, BoxCutter = true }, order), "BoxCutter", "box cutter")
		expectEqual(NightRules.toolToDrop({ Scissors = true }, order), "Scissors", "scissors")
		expectEqual(NightRules.toolToDrop({}, order), nil, "hands only")
	end)

	test("prompts: a hold must last its time, less the network slack", function()
		local seconds, slack = N.reviveHoldSeconds, N.holdSlackSeconds
		expectEqual(NightRules.holdDone(nil, 10, seconds, slack), false, "never began")
		expectEqual(NightRules.holdDone(10, 10 + seconds - slack - 0.01, seconds, slack), false, "too short")
		expectEqual(NightRules.holdDone(10, 10 + seconds - slack, seconds, slack), true, "long enough")
	end)

	test("lighting: 30%, flashlight 60%, Night Eyes adds up to 30%", function()
		local eyes = Config.PermanentTrack.NightEyes
		local function light(flash, level)
			return NightRules.lighting(N.lightingScale, flash, level, eyes.lightingPerLevel, eyes.maxBonus)
		end
		expectEqual(light(nil, 0), 0.3, "base")
		expectEqual(light(Config.Shop.Flashlight.nightLightingScale, 0), 0.6, "flashlight")
		assert(math.abs(light(nil, 2) - 0.4) < 1e-9, "two levels")
		assert(math.abs(light(nil, 99) - 0.6) < 1e-9, "eyes capped")
		assert(math.abs(light(Config.Shop.Flashlight.nightLightingScale, 99) - 0.9) < 1e-9, "both")
	end)

	test("tick: louder as the team tears toward it", function()
		local t = Config.Tick
		local function vol(current)
			return NightRules.tickVolume(4, current, t.volumeMax, t.volumeFalloff, t.volumeMin)
		end
		expectEqual(vol(4), t.volumeMax, "at its layer")
		assert(vol(3) < vol(4) and vol(2) < vol(3), "ramps up")
		expectEqual(vol(-20), t.volumeMin, "floor")
		expectEqual(vol(6), t.volumeMax, "passed it")
	end)

	test("shutter: a held lid stands between its holders and Jack", function()
		local spot, dir = NightRules.shutterSpot({ v(0, 3, -2), v(0, 3, 2) }, v(10, 0, 0), N.shutterOffsetStuds)
		expectEqual(spot.x, N.shutterOffsetStuds, "toward Jack")
		expectEqual(spot.z, 0, "between holders")
		expectEqual(dir.x, 1, "faces Jack")
		local close = NightRules.shutterSpot({ v(0, 3, 0) }, v(1, 0, 0), N.shutterOffsetStuds)
		expectEqual(close.x, 1, "never past Jack")
	end)
end
