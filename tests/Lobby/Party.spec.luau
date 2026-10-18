-- Spec for src/server/Lobby/Party.luau. Numbers come from Config.

local Party = require("../../src/server/Lobby/Party")
local Config = require("../../src/shared/Config/Config")

local MAX = Config.Matchmaking.maxParty
local WAIT = Config.Matchmaking.waitSeconds

return function(test, expectEqual)
	test("party pad: the host and friends on the pad, up to 4", function()
		local friends = { [2] = true, [3] = true, [5] = true, [6] = true }
		local members = Party.fromPad(1, { 1, 2, 4, 3, 5, 6 }, function(id)
			return friends[id] == true
		end, MAX)
		expectEqual(table.concat(members, ","), "1,2,3,5", "host first, strangers skipped, capped at 4")
		expectEqual(#Party.fromPad(9, {}, function()
			return false
		end, MAX), 1, "alone is still a party of one")
	end)

	test("join anyone: launches when full", function()
		local q = Party.newQueue()
		for id = 1, MAX do
			expectEqual(Party.join(q, id, id, MAX), true, `join {id}`)
		end
		expectEqual(Party.join(q, 99, 5, MAX), false, "full")
		local members = Party.take(q, 5, MAX, WAIT)
		expectEqual(members and #members, MAX, "four go")
		expectEqual(#q.members, 0, "queue emptied")
	end)

	test("join anyone: waits up to 20 s, then starts with whoever is there, even one player", function()
		local q = Party.newQueue()
		Party.join(q, 7, 100, MAX)
		Party.join(q, 8, 110, MAX)
		expectEqual(Party.take(q, 100 + WAIT - 1, MAX, WAIT), nil, "still waiting")
		expectEqual(Party.waitLeft(q, 105, WAIT), WAIT - 5, "timer from the first join")
		local members = Party.take(q, 100 + WAIT, MAX, WAIT)
		expectEqual(members and table.concat(members, ","), "7,8", "two go")
		Party.join(q, 3, 200, MAX)
		expectEqual(Party.take(q, 200 + WAIT, MAX, WAIT)[1], 3, "one player alone")
	end)

	test("join anyone: leaving the pad leaves the queue; an empty queue has no timer", function()
		local q = Party.newQueue()
		Party.join(q, 1, 0, MAX)
		expectEqual(Party.join(q, 1, 1, MAX), false, "already in")
		Party.leave(q, 1)
		expectEqual(Party.waitLeft(q, 2, WAIT), nil, "no timer")
		expectEqual(Party.take(q, 100, MAX, WAIT), nil, "nothing to launch")
		expectEqual(Party.admits({ 4, 5 }, 5), true, "listed")
		expectEqual(Party.admits({ 4, 5 }, 6), false, "not listed")
	end)
end
