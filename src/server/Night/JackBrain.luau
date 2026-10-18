--[=[
	JackBrain (pure logic, server)
	Owns: Jack's bursts (Table 20): still for `stillSeconds` with the crank turning, then a lunge of
	`lungeSeconds` in a straight line toward where the nearest player in sight stood. Nobody in sight:
	he stays still another round. A lunge stops at the present, at a lid or at the room's edge, and
	ends when it connects. Sprinter: lunges at them run at their `lungeScale` (Table 8).
	Must never: call game:GetService or read a clock. Night passes `dt`, bodies and sight boxes.
	Read first: src/server/Night/README.md
]=]

local Sight = require("./Sight")

type Vec = Sight.Vec

export type Jack = { pos: Vec, phase: string, timer: number, dir: Vec, speed: number }

-- A player as Jack sees them: root position, whether down, and how fast lunges at them run.
export type Body = { id: any, pos: Vec, down: boolean, lungeScale: number }

export type Rules = {
	stillSeconds: number,
	lungeSeconds: number,
	lungeSpeed: number,
	hitStuds: number,
	headStuds: number,
	radius: number,
	roomCenter: Vec, -- floor point at the room's middle
	roomHalf: number, -- half the room's side
}

export type Step = { lunged: Body?, hits: { any } }

local JackBrain = {}

local function flat(a: Vec, b: Vec): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

-- A still Jack at floor point `pos`; his first lunge waits a full still phase.
function JackBrain.new(pos: Vec, rules: Rules): Jack
	return { pos = { x = pos.x, y = 0, z = pos.z }, phase = "Still", timer = rules.stillSeconds, dir = { x = 1, y = 0, z = 0 }, speed = 0 }
end

-- Where Jack looks from.
function JackBrain.eye(jack: Jack, rules: Rules): Vec
	return { x = jack.pos.x, y = rules.headStuds, z = jack.pos.z }
end

-- The nearest player who is up and in sight, or nil.
function JackBrain.pickTarget(jack: Jack, bodies: { Body }, boxes: { Sight.Box }, rules: Rules): Body?
	local eye = JackBrain.eye(jack, rules)
	local best, bestDistance = nil, math.huge
	for _, body in bodies do
		if not body.down then
			local distance = flat(jack.pos, body.pos)
			if distance < bestDistance and not Sight.blocked(eye, body.pos, boxes) then
				best, bestDistance = body, distance
			end
		end
	end
	return best
end

local function still(jack: Jack, rules: Rules)
	jack.phase = "Still"
	jack.timer = rules.stillSeconds
	jack.speed = 0
end

-- Advances Jack by `dt` seconds. Returns who a lunge started at and who it connected with.
function JackBrain.step(jack: Jack, dt: number, bodies: { Body }, boxes: { Sight.Box }, rules: Rules): Step
	local out: Step = { lunged = nil, hits = {} }
	if jack.phase == "Still" then
		jack.timer -= dt
		if jack.timer > 0 then
			return out
		end
		local target = JackBrain.pickTarget(jack, bodies, boxes, rules)
		if not target then
			jack.timer += rules.stillSeconds
			return out
		end
		local dx, dz = target.pos.x - jack.pos.x, target.pos.z - jack.pos.z
		local length = math.sqrt(dx * dx + dz * dz)
		jack.dir = if length > 1e-6 then { x = dx / length, y = 0, z = dz / length } else { x = 1, y = 0, z = 0 }
		jack.speed = rules.lungeSpeed * target.lungeScale
		jack.phase = "Lunge"
		jack.timer = rules.lungeSeconds
		out.lunged = target
		return out
	end

	local move = math.min(dt, jack.timer)
	local limit = rules.roomHalf - rules.radius
	local nx = math.clamp(jack.pos.x + jack.dir.x * jack.speed * move, rules.roomCenter.x - limit, rules.roomCenter.x + limit)
	local nz = math.clamp(jack.pos.z + jack.dir.z * jack.speed * move, rules.roomCenter.z - limit, rules.roomCenter.z + limit)
	local body = { x = nx, y = rules.radius, z = nz }
	for _, box in boxes do
		if Sight.inside(body, box, rules.radius) then
			still(jack, rules)
			return out
		end
	end
	jack.pos = { x = nx, y = 0, z = nz }
	for _, other in bodies do
		if not other.down and flat(jack.pos, other.pos) <= rules.hitStuds then
			table.insert(out.hits, other.id)
		end
	end
	jack.timer -= move
	if #out.hits > 0 or jack.timer <= 0 then
		still(jack, rules)
	end
	return out
end

return JackBrain
