--[=[
	RateLimit (pure logic, server)
	Owns: a per-key sliding one-second window that allows at most `perSecond` requests.
	Must never: read a clock. The caller passes the server's `now` (seconds).
	Read first: src/server/Tear/README.md
]=]

export type Limiter = { perSecond: number, stamps: { [any]: { number } } }

local RateLimit = {}

function RateLimit.new(perSecond: number): Limiter
	return { perSecond = perSecond, stamps = {} }
end

function RateLimit.allow(limiter: Limiter, key: any, now: number): boolean
	local stamps = limiter.stamps[key]
	if not stamps then
		stamps = {}
		limiter.stamps[key] = stamps
	end
	while stamps[1] and now - stamps[1] >= 1 do
		table.remove(stamps, 1)
	end
	if #stamps >= limiter.perSecond then
		return false
	end
	table.insert(stamps, now)
	return true
end

function RateLimit.forget(limiter: Limiter, key: any)
	limiter.stamps[key] = nil
end

return RateLimit
