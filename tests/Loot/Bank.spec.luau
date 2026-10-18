-- Spec for src/server/Loot Shelf, Index, Bank and src/shared/Gifts. Numbers come from Config.

local Shelf = require("../../src/server/Loot/Shelf")
local Index = require("../../src/server/Loot/Index")
local Bank = require("../../src/server/Loot/Bank")
local Gifts = require("../../src/shared/Gifts/Gifts")
local Config = require("../../src/shared/Config/Config")

local SIZES = {}
for rarity, entry in Config.Rarity do
	SIZES[rarity] = entry.shelfSlots
end
local SHELF = { slotSizes = SIZES, stackMax = Config.Shelf.stackMax }
local CAP = Config.Shelf.startSlots
local GEMS = {
	completed = Config.BankGems.completed,
	noDowns = Config.BankGems.noDowns,
	tickSurvived = Config.BankGems.tickSurvived,
	lowerTier = Config.Tiers.lowerTierGemsPerRun,
}

return function(test, expectEqual)
	test("catalogue: 8 families of 4 side-gifts, 3 core gifts per band, unique ids, no rarity on side-gifts", function()
		local side, core, ids = 0, 0, {}
		expectEqual(#Gifts.families, #Config.Loot.families, "families")
		for _, family in Gifts.families do
			expectEqual(#Gifts.side[family], 4, family)
			for _, gift in Gifts.side[family] do
				side += 1
				assert(not ids[gift.id], `duplicate {gift.id}`)
				ids[gift.id] = true
				expectEqual(gift.rarity, nil, `{gift.id} has a rarity`)
			end
		end
		for _, rarity in Config.RarityOrder do
			expectEqual(#Gifts.core[rarity], 3, rarity)
			for _, gift in Gifts.core[rarity] do
				core += 1
				assert(not ids[gift.id], `duplicate {gift.id}`)
				ids[gift.id] = true
			end
		end
		expectEqual(side, 32, "side-gifts")
		expectEqual(core, 18, "core gifts")
		expectEqual(Gifts.corePool("Secret", "Birthday")[1].id, "BlankGiftTag", "Birthday's own Secret")
		expectEqual(#Gifts.corePool("Secret", "ThePackage"), 3, "no own Secret yet: any")
		expectEqual(Gifts.displayName("Robot", "Golden"), "Golden Robot", "mutation name")
	end)

	test("shelf: duplicates stack to x9, then take a new slot", function()
		local shelf = {}
		local mug = { giftId = "Mug", rarity = "Common" }
		expectEqual(Shelf.place(shelf, mug, CAP, SHELF), "placed", "first")
		for i = 2, Config.Shelf.stackMax do
			expectEqual(Shelf.place(shelf, mug, CAP, SHELF), "stacked", `copy {i}`)
		end
		expectEqual(shelf[1].count, Config.Shelf.stackMax, "stack")
		expectEqual(Shelf.place(shelf, mug, CAP, SHELF), "placed", "tenth")
		expectEqual(#shelf, 2, "two slots")
		expectEqual(Shelf.place(shelf, { giftId = "Mug", rarity = "Uncommon" }, CAP, SHELF), "placed", "other rarity")
		expectEqual(Shelf.place(shelf, { giftId = "Mug", rarity = "Common", mutation = "Golden" }, CAP, SHELF), "placed", "mutation")
	end)

	test("shelf: items take slots by rarity and a full shelf refuses", function()
		local shelf = {}
		expectEqual(Shelf.place(shelf, { giftId = "BrassKey", rarity = "Secret" }, CAP, SHELF), "placed", "secret")
		expectEqual(Shelf.place(shelf, { giftId = "Rocket", rarity = "Mythic" }, CAP, SHELF), "placed", "mythic")
		expectEqual(shelf[2].slotIndex, 1 + SIZES.Secret, "after the Secret")
		expectEqual(Shelf.usedSlots(shelf, SHELF), SIZES.Secret + SIZES.Mythic, "used")
		for _ = 1, CAP - SIZES.Secret - SIZES.Mythic do
			Shelf.place(shelf, { giftId = "Sock", rarity = "Common", mutation = tostring(#shelf) }, CAP, SHELF)
		end
		expectEqual(Shelf.usedSlots(shelf, SHELF), CAP, "full")
		expectEqual(Shelf.place(shelf, { giftId = "Robot", rarity = "Rare" }, CAP, SHELF), "full", "refused")
		local removed = Shelf.removeAt(shelf, 1)
		expectEqual(removed and removed.giftId, "BrassKey", "removed")
		expectEqual(Shelf.place(shelf, { giftId = "Robot", rarity = "Rare" }, CAP, SHELF), "placed", "fits now")
		expectEqual(Shelf.preview(shelf, { giftId = "Robot", rarity = "Rare" }, CAP, SHELF), "stacked", "preview")
	end)

	test("index: counts finds, never forgets, keeps the best side-gift rarity, a mutation is its own entry", function()
		local index = {}
		expectEqual(Index.record(index, "Marble", 2, 100, "Rare", Config.RarityOrder), true, "new")
		expectEqual(Index.record(index, "Marble", 4, 200, "Common", Config.RarityOrder), false, "seen")
		expectEqual(index.Marble.count, 2, "count")
		expectEqual(index.Marble.firstDepth, 2, "first depth")
		expectEqual(index.Marble.firstSeenAt, 100, "first seen")
		expectEqual(index.Marble.bestRarity, "Rare", "best kept")
		Index.record(index, "Marble", 1, 300, "Epic", Config.RarityOrder)
		expectEqual(index.Marble.bestRarity, "Epic", "better replaces")
		expectEqual(Index.has(index, "Robot"), false, "unseen")
		Index.record(index, Index.key("Robot", "Golden"), 5, 1)
		expectEqual(Index.has(index, "Robot:Golden"), true, "mutation entry")
		expectEqual(Index.has(index, "Robot"), false, "plain entry separate")
	end)

	test("bank: run gems and sell rates", function()
		expectEqual(Bank.runGems(GEMS, 1, false, false), Config.BankGems.completed, "completed")
		expectEqual(Bank.runGems(GEMS, 0, false, false), Config.BankGems.noDowns, "no downs")
		expectEqual(Bank.runGems(GEMS, 2, true, false), Config.BankGems.tickSurvived, "Tick survived")
		expectEqual(Bank.runGems(GEMS, 0, true, true), Config.Tiers.lowerTierGemsPerRun, "lower tier")
		expectEqual(Bank.sellGems(Config.Loot.sellGems, "Mythic", 3), 3 * Config.Loot.sellGems.Mythic, "mythic x3")
		expectEqual(Bank.sellGems(Config.Loot.sellGems, "Secret"), nil, "Secret cannot be sold")
	end)
end
