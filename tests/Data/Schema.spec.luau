-- Spec for src/server/Data/Schema.luau: profile schema migration from version n-1 (N20).

local Schema = require("../../src/server/Data/Schema")

return function(test, expectEqual)
	test("a new profile is at the current version with every schema field", function()
		local data = Schema.template()
		expectEqual(data.schemaVersion, Schema.VERSION, "version")
		for _, key in { "tier", "prestigeCount", "gems", "naughty", "naughtyUpdatedAt", "shelf", "vault", "index", "classes", "activeClass", "passes", "stats", "upgrades", "streak", "likesReceived", "likedShelves", "rejoin", "dailyClaimedAt", "groupClaimed" } do
			assert(data[key] ~= nil, `missing {key}`)
		end
		expectEqual(Schema.migrate(data), true, "migrates")
		expectEqual(data.schemaVersion, Schema.VERSION, "unchanged")
	end)

	test("migration from version n-1 keeps what the player owns and fills the rest", function()
		local old = {
			gems = 140,
			shelf = { { giftId = "Robot", rarity = "Rare", slotIndex = 1, count = 2 } },
			index = { Robot = { count = 3, firstDepth = 8, firstSeenAt = 100 } },
			stats = { runs = 7 },
		}
		if Schema.VERSION > 1 then
			old.schemaVersion = Schema.VERSION - 1
		end
		expectEqual(Schema.migrate(old), true, "migrates")
		expectEqual(old.schemaVersion, Schema.VERSION, "version")
		expectEqual(old.gems, 140, "gems kept")
		expectEqual(old.shelf[1].count, 2, "shelf kept")
		expectEqual(old.index.Robot.count, 3, "index kept")
		expectEqual(old.stats.runs, 7, "stats kept")
		expectEqual(old.stats.completions, 0, "missing stat filled")
		expectEqual(old.upgrades.pockets, 0, "missing table filled")
		expectEqual(old.tier, 1, "missing number filled")
	end)

	test("v1 -> v2: per-tier run counts start from the completions so far", function()
		local v1 = { schemaVersion = 1, tier = 1, gems = 40, stats = { runs = 6, completions = 4 } }
		expectEqual(Schema.migrate(v1), true, "migrates")
		expectEqual(v1.schemaVersion, 2, "version")
		expectEqual(v1.tierCompletions["1"], 4, "Birthday completions carried")
		expectEqual(v1.shelfSlots, 12, "shelf slots filled")
		expectEqual(v1.vaultReclaimsLeft, 0, "reclaims filled")
		expectEqual(v1.gems, 40, "gems kept")
		local fresh = { schemaVersion = 1 }
		Schema.migrate(fresh)
		expectEqual(next(fresh.tierCompletions), nil, "no runs, no counts")
	end)

	test("migrating twice changes nothing", function()
		local data = { gems = 5 }
		Schema.migrate(data)
		local before = data.gems .. data.schemaVersion .. #data.shelf
		Schema.migrate(data)
		expectEqual(data.gems .. data.schemaVersion .. #data.shelf, before, "same")
	end)

	test("a profile from a newer build is never downgraded", function()
		local data = { schemaVersion = Schema.VERSION + 1, gems = 9 }
		expectEqual(Schema.migrate(data), false, "refused")
		expectEqual(data.schemaVersion, Schema.VERSION + 1, "version kept")
	end)

	test("templates are independent copies", function()
		local a, b = Schema.template(), Schema.template()
		a.stats.runs = 3
		table.insert(a.shelf, {})
		expectEqual(b.stats.runs, 0, "stats shared")
		expectEqual(#b.shelf, 0, "shelf shared")
	end)
end
