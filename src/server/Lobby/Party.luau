--[=[
	Party (pure logic, server)
	Owns: who goes on a run from the Start a Run pads (Diagram D; P12, N11, N13): solo goes alone; a
	party is the host plus friends standing on the party pad, up to maxParty; join-anyone fills a
	queue and launches when it is full or waitSeconds after the first player joined, with whoever is
	there. The run's tier is the tier of the player who started it (N13).
	Must never: call game:GetService or read a clock. The caller passes userIds, friendship and time.
	Read first: src/server/Lobby/README.md
]=]

export type Queue = { members: { number }, since: number? }

local Party = {}

-- The party pad: the host and up to maxParty - 1 of the host's friends standing on the pad, in the
-- order they stand there. `isFriend(userId)` says whether a player is the host's friend.
function Party.fromPad(host: number, standing: { number }, isFriend: (userId: number) -> boolean, maxParty: number): { number }
	local members = { host }
	for _, userId in standing do
		if #members >= maxParty then
			break
		end
		if userId ~= host and isFriend(userId) then
			table.insert(members, userId)
		end
	end
	return members
end

function Party.newQueue(): Queue
	return { members = {}, since = nil }
end

-- Joins the join-anyone queue. Returns false if already in it or it is full.
function Party.join(queue: Queue, userId: number, now: number, maxParty: number): boolean
	if table.find(queue.members, userId) or #queue.members >= maxParty then
		return false
	end
	table.insert(queue.members, userId)
	queue.since = queue.since or now
	return true
end

function Party.leave(queue: Queue, userId: number)
	local i = table.find(queue.members, userId)
	if i then
		table.remove(queue.members, i)
	end
	if #queue.members == 0 then
		queue.since = nil
	end
end

-- Seconds until the queue launches on its own, or nil while it is empty.
function Party.waitLeft(queue: Queue, now: number, waitSeconds: number): number?
	if not queue.since then
		return nil
	end
	return math.max(0, queue.since + waitSeconds - now)
end

-- The members to launch now (full, or the wait is over), emptying the queue; or nil to keep waiting.
function Party.take(queue: Queue, now: number, maxParty: number, waitSeconds: number): { number }?
	local left = Party.waitLeft(queue, now, waitSeconds)
	if left == nil or (#queue.members < maxParty and left > 0) then
		return nil
	end
	local members = queue.members
	queue.members = {}
	queue.since = nil
	return members
end

-- Whether a player may enter a run: listed in its party, and (for a rejoin) inside the window (N9, N10).
function Party.admits(members: { number }, userId: number): boolean
	return table.find(members, userId) ~= nil
end

return Party
