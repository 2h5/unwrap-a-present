--[=[
	DebrisPool (pure logic, client)
	Owns: which debris slot a new torn panel uses. At most `max` slots are ever live; when all are
	live, the oldest is recycled first.
	Must never: create Instances or call game:GetService (runs under Lune tests). Debris.luau maps
	slot ids to parts.
	Read first: src/client/Debris/README.md
]=]

export type Pool = {
	max: number,
	created: number,
	live: { number }, -- oldest first
	free: { number },
}

local DebrisPool = {}

function DebrisPool.new(max: number): Pool
	return { max = max, created = 0, live = {}, free = {} }
end

-- Returns a slot id and whether it was taken from the oldest live piece.
function DebrisPool.acquire(pool: Pool): (number, boolean)
	local id: number
	local recycled = false
	if #pool.free > 0 then
		id = table.remove(pool.free) :: number
	elseif pool.created < pool.max then
		pool.created += 1
		id = pool.created
	else
		id = table.remove(pool.live, 1) :: number
		recycled = true
	end
	table.insert(pool.live, id)
	return id, recycled
end

-- Returns a live slot to the free list (e.g. when the layer is reset).
function DebrisPool.release(pool: Pool, id: number)
	local index = table.find(pool.live, id)
	if index then
		table.remove(pool.live, index)
		table.insert(pool.free, id)
	end
end

function DebrisPool.liveCount(pool: Pool): number
	return #pool.live
end

return DebrisPool
