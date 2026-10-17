-- Spec for src/client/Debris/DebrisPool.luau. Numbers come from Config, never inline.

local DebrisPool = require("../../src/client/Debris/DebrisPool")
local Config = require("../../src/shared/Config/Config")

local MAX = Config.Tear.maxLiveDebris

return function(test, expectEqual)
	test("live debris never exceeds the budget", function()
		local pool = DebrisPool.new(MAX)
		for i = 1, MAX * 3 do
			DebrisPool.acquire(pool)
			assert(DebrisPool.liveCount(pool) <= MAX, `over budget after {i}`)
		end
		expectEqual(DebrisPool.liveCount(pool), MAX, "live count")
		expectEqual(pool.created, MAX, "slots created")
	end)

	test("new slots until the budget, then the oldest is recycled first", function()
		local pool = DebrisPool.new(MAX)
		for i = 1, MAX do
			local id, recycled = DebrisPool.acquire(pool)
			expectEqual(id, i, "slot")
			expectEqual(recycled, false, "recycled")
		end
		for i = 1, 3 do
			local id, recycled = DebrisPool.acquire(pool)
			expectEqual(id, i, "oldest slot")
			expectEqual(recycled, true, "recycled")
		end
	end)

	test("a released slot is reused before recycling a live one", function()
		local pool = DebrisPool.new(MAX)
		for _ = 1, MAX do
			DebrisPool.acquire(pool)
		end
		DebrisPool.release(pool, 7)
		local id, recycled = DebrisPool.acquire(pool)
		expectEqual(id, 7, "slot")
		expectEqual(recycled, false, "recycled")
		expectEqual(DebrisPool.liveCount(pool), MAX, "live count")
	end)
end
