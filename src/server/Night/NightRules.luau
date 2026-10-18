--[=[
	NightRules (pure logic, server)
	Owns: the small rules of the Night (Mechanics C, Table 20): who is wiped, when a solo down
	revives itself, which tool a down drops, whether a prompt hold lasted long enough, each player's
	Night lighting, how loud the Tick ticks, and where a shuttered lid stands.
	Must never: call game:GetService or read a clock. Callers pass `now` and plain tables.
	Read first: src/server/Night/README.md
]=]

export type Vec = { x: number, y: number, z: number }

local NightRules = {}

-- A wipe is every player down at once. A solo player is never wiped: they revive themselves.
function NightRules.isWipe(players: number, down: number): boolean
	return players >= 2 and down >= players
end

function NightRules.soloRevives(players: number): boolean
	return players == 1
end

-- The highest-grade tool a downed player owns (never hands), from `order` (lowest grade first).
function NightRules.toolToDrop(owned: { [string]: boolean }, order: { string }): string?
	for i = #order, 1, -1 do
		local name = order[i]
		if name ~= "Hands" and owned[name] then
			return name
		end
	end
	return nil
end

-- Whether a hold that began at `began` has lasted `seconds` by `now`, allowing `slack` for the network.
function NightRules.holdDone(began: number?, now: number, seconds: number, slack: number): boolean
	return began ~= nil and now - began >= seconds - slack
end

-- A player's Night lighting: base 30%, the Flashlight's 60% for its holder, plus Night Eyes levels
-- (+5% each, the bonus capped at 30%). Never above full light.
function NightRules.lighting(base: number, flashlight: number?, eyesLevel: number, perLevel: number, maxBonus: number): number
	local light = flashlight or base
	return math.min(1, light + math.min(eyesLevel * perLevel, maxBonus))
end

-- Tick volume: full at its own layer, halved (`falloff`) for each layer still in the way.
function NightRules.tickVolume(tickDepth: number, currentDepth: number, max: number, falloff: number, min: number): number
	local away = math.max(0, tickDepth - currentDepth)
	return math.max(min, max * falloff ^ away)
end

-- Where a held lid stands: `offset` studs from its holders' middle, toward Jack, facing him.
-- Returns the floor point under the lid's centre and the unit direction it faces.
function NightRules.shutterSpot(holders: { Vec }, jack: Vec, offset: number): (Vec, Vec)
	local mx, mz = 0, 0
	for _, p in holders do
		mx += p.x / #holders
		mz += p.z / #holders
	end
	local dx, dz = jack.x - mx, jack.z - mz
	local length = math.sqrt(dx * dx + dz * dz)
	local dir = if length > 1e-6 then { x = dx / length, y = 0, z = dz / length } else { x = 1, y = 0, z = 0 }
	local step = math.min(offset, length)
	return { x = mx + dir.x * step, y = 0, z = mz + dir.z * step }, dir
end

return NightRules
