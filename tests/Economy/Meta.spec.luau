-- Spec for src/server/Economy/Meta.luau. Numbers come from Config.

local Meta = require("../../src/server/Economy/Meta")
local Schema = require("../../src/server/Data/Schema")
local Rng = require("../../src/shared/Rng/Rng")
local Config = require("../../src/shared/Config/Config")

local DAY = 24 * 60 * 60
local ORDER = { "Kid", "Wrapper", "Sprinter", "Collector", "Heir", "KrampusKid" }
local SIZES = {}
for rarity, entry in Config.Rarity do
	SIZES[rarity] = entry.shelfSlots
end

return function(test, expectEqual)
	test("daily reward every 6 hours; group reward once and only in the group", function()
		local d = Schema.template()
		local interval = Config.Gems.dailyIntervalSeconds
		expectEqual(Meta.claimDaily(d, 1000, interval, Config.Gems.daily), Config.Gems.daily, "first claim")
		expectEqual(Meta.claimDaily(d, 1000 + interval - 1, interval, Config.Gems.daily), nil, "too soon")
		expectEqual(Meta.dailyWait(d, 1000 + interval - 1, interval), 1, "one second left")
		expectEqual(Meta.claimDaily(d, 1000 + interval, interval, Config.Gems.daily), Config.Gems.daily, "ready")
		expectEqual(Meta.claimGroup(d, false, Config.Gems.groupOneTime), nil, "not in group")
		expectEqual(Meta.claimGroup(d, true, Config.Gems.groupOneTime), Config.Gems.groupOneTime, "joined")
		expectEqual(Meta.claimGroup(d, true, Config.Gems.groupOneTime), nil, "once")
		expectEqual(d.gems, 2 * Config.Gems.daily + Config.Gems.groupOneTime, "gems")
	end)

	test("login streak: day n pays 10 x n up to day 7, a missed day restarts, same day pays nothing", function()
		local d = Schema.template()
		local per, cap = Config.Gems.streakPerDay, Config.Gems.streakCapDays
		local paid = {}
		for day = 1, 9 do
			table.insert(paid, Meta.login(d, day * DAY + 5, per, cap))
		end
		expectEqual(table.concat(paid, ","), "10,20,30,40,50,60,70,70,70", "a week then capped")
		expectEqual(Meta.login(d, 9 * DAY + 100, per, cap), 0, "same day")
		expectEqual(Meta.login(d, 11 * DAY, per, cap), per, "missed a day")
		expectEqual(Meta.friendBonus(1, Config.Gems.friendBonusPerPlayer), 0, "solo")
		expectEqual(Meta.friendBonus(2, Config.Gems.friendBonusPerPlayer), Config.Gems.friendBonusPerPlayer, "party")
	end)

	test("class spin: costs 25, owns every class rolled, duplicates refund 10, odds follow the table", function()
		local d = Schema.template()
		d.gems = Config.Gems.classSpin * 2
		local id, isNew = Meta.spin(d, "Kid", Config.Gems.classSpin, Config.Gems.classDuplicateRefund)
		expectEqual(id, "Kid", "rolled")
		expectEqual(isNew, true, "new")
		expectEqual(d.activeClass, "Kid", "first class is picked")
		local _, again, refund = Meta.spin(d, "Kid", Config.Gems.classSpin, Config.Gems.classDuplicateRefund)
		expectEqual(again, false, "duplicate")
		expectEqual(refund, Config.Gems.classDuplicateRefund, "refund")
		expectEqual(d.gems, Config.Gems.classDuplicateRefund, "gems after two spins")
		expectEqual(Meta.spin(d, "Heir", Config.Gems.classSpin, Config.Gems.classDuplicateRefund), nil, "cannot afford")
		expectEqual(Meta.pickClass(d, "Heir"), false, "not owned")
		local rng, counts, n = Rng.new(9), {}, 100000
		for _ = 1, n do
			local c = Meta.rollClass(rng, Config.Classes, ORDER, Rng)
			counts[c] = (counts[c] or 0) + 1
		end
		for _, c in ORDER do
			local share = 100 * (counts[c] or 0) / n
			assert(math.abs(share - Config.Classes[c].odds) < 0.6, `{c}: {share}% vs {Config.Classes[c].odds}%`)
		end
	end)

	test("permanent track: level n costs first + step x (n - 1), Pockets 650 and Night Eyes 405 in all", function()
		for name, key in { pockets = "Pockets", nightEyes = "NightEyes" } do
			local line = Config.PermanentTrack[key]
			local d = Schema.template()
			d.gems = 100000
			local total = 0
			while true do
				local cost = Meta.trackCost(line, d.upgrades[name])
				if not cost then
					break
				end
				total += cost
				Meta.buyTrack(d, name, line)
			end
			expectEqual(d.upgrades[name], line.maxLevel, `{name} max`)
			expectEqual(total, if name == "pockets" then 650 else 405, `{name} total`)
		end
	end)

	test("shelf slots: 50 gems per 4, up to 24; Big Shelf gives 36", function()
		local d = Schema.template()
		d.gems = 1000
		expectEqual(Meta.buyShelfSlots(d, Config.Shelf), 16, "first 4")
		Meta.buyShelfSlots(d, Config.Shelf)
		expectEqual(Meta.buyShelfSlots(d, Config.Shelf), 24, "to 24")
		expectEqual(Meta.buyShelfSlots(d, Config.Shelf), nil, "gem cap")
		expectEqual(d.gems, 1000 - 3 * Config.Shelf.gemsPer4Slots, "paid")
		expectEqual(Meta.shelfCapacity(d, Config.Shelf, true), Config.Shelf.passSlotsMax, "pass")
	end)

	test("prestige: 3 runs at Birthday, shelf back to 12 with the rest vaulted, nothing else touched", function()
		local d = Schema.template()
		local tiers, need, max = Config.Tiers.order, Config.Tiers.completedRunsToPrestige, #Config.LaunchTiers
		d.gems, d.shelfSlots = 77, 16
		d.shelf = {
			{ giftId = "Sock", rarity = "Common", slotIndex = 1, count = 3 },
			{ giftId = "Rocket", rarity = "Mythic", slotIndex = 11, count = 1 },
			{ giftId = "Mug", rarity = "Common", slotIndex = 14, count = 1 },
		}
		d.index.Sock = { count = 3, firstDepth = 2, firstSeenAt = 1 }
		Meta.runCompleted(d, 1, Config.Tiers.vaultReclaimsPerRun)
		Meta.runCompleted(d, 1, Config.Tiers.vaultReclaimsPerRun)
		expectEqual(Meta.canPrestige(d, tiers, need, max), false, "two runs")
		Meta.runCompleted(d, 1, Config.Tiers.vaultReclaimsPerRun)
		expectEqual(Meta.canPrestige(d, tiers, need, max), true, "three runs")
		local moved = Meta.prestige(d, Config.Tiers.shelfSlotsAfterPrestige, SIZES)
		expectEqual(d.tier, 2, "Christmas")
		expectEqual(d.prestigeCount, 1, "count")
		expectEqual(d.shelfSlots, 12, "shelf shrinks")
		expectEqual(#moved, 2, "Rocket (slots 11-13) and Mug go to the vault")
		expectEqual(#d.shelf, 1, "Sock stays")
		expectEqual(#d.vault, 2, "vault")
		expectEqual(d.gems, 77, "gems untouched")
		expectEqual(d.index.Sock.count, 3, "index untouched")
		expectEqual(d.vaultReclaimsLeft, Config.Tiers.vaultReclaimsPerRun, "reclaims per run")
		expectEqual(Meta.canPrestige(d, tiers, need, max), false, "last launch tier")
		expectEqual(Meta.canRunTier(d, 1), true, "replay Birthday")
		expectEqual(Meta.canRunTier(d, 3), false, "not unlocked")
		Meta.runCompleted(d, 1, 3)
		expectEqual(d.tierCompletions["2"], nil, "a lower-tier run does not count toward prestige")
	end)
end
