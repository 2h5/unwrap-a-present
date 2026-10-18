--[=[
	LidSession (pure logic, server)
	Owns: lifting one box lid. Progress only runs while at least `required` players hold the lid
	(two from tier 2, capped at the players present); progress is kept when holders let go.
	Must never: read a clock or take a time from a client. The caller passes the server's `now`.
	Read first: src/server/Tear/README.md
]=]

export type Session = {
	required: number,
	seconds: number,
	holders: { [any]: boolean },
	count: number,
	progress: number, -- seconds lifted so far, not counting the current run
	since: number?, -- when the current run of enough holders started
}

local EPSILON = 1e-6

local LidSession = {}

function LidSession.new(required: number, seconds: number): Session
	return { required = required, seconds = seconds, holders = {}, count = 0, progress = 0, since = nil }
end

local function lifted(s: Session, now: number): number
	return s.progress + (if s.since then now - s.since else 0)
end

-- Adds a holder. Returns the seconds still needed if the lid is now lifting, else nil.
function LidSession.join(s: Session, holder: any, now: number): number?
	if not s.holders[holder] then
		s.holders[holder] = true
		s.count += 1
	end
	if s.count >= s.required and not s.since then
		s.since = now
	end
	if s.since then
		return math.max(0, s.seconds - lifted(s, now))
	end
	return nil
end

-- Removes a holder, keeping progress. Returns the seconds still needed if it is still lifting, else nil.
function LidSession.leave(s: Session, holder: any, now: number): number?
	if s.holders[holder] then
		s.holders[holder] = nil
		s.count -= 1
	end
	if s.since and s.count < s.required then
		s.progress += now - s.since
		s.since = nil
	end
	if s.since then
		return math.max(0, s.seconds - lifted(s, now))
	end
	return nil
end

function LidSession.isLifting(s: Session): boolean
	return s.since ~= nil
end

function LidSession.isDone(s: Session, now: number): boolean
	return lifted(s, now) >= s.seconds - EPSILON
end

function LidSession.fraction(s: Session, now: number): number
	return math.clamp(lifted(s, now) / s.seconds, 0, 1)
end

-- Holders needed for a lid: `twoFromTier` and up needs two, never more than the players present.
function LidSession.requiredHolders(tier: number, twoFromTier: number, players: number): number
	local want = if tier >= twoFromTier then 2 else 1
	return math.max(1, math.min(want, players))
end

return LidSession
