-- Spec for src/server/Loot/Rarity.luau. Numbers come from Config.

local Rarity = require("../../src/server/Loot/Rarity")
local Rng = require("../../src/shared/Rng/Rng")
local Config = require("../../src/shared/Config/Config")

local CONFIG = {
	order = Config.RarityOrder,
	odds = Config.RarityOdds,
	tiers = Config.Tiers.order,
	packageInnerSecretPercent = Config.Loot.packageInnerSecretPercent,
	firstRunMinRarity = Config.Loot.firstRunMinRarity,
	mutationChance = Config.Loot.mutationChance,
	mutationMinRarity = Config.Loot.mutationMinRarity,
	mutations = Config.Loot.launchMutations,
}

local N = 200000

local function shares(roll)
	local counts = {}
	for _ = 1, N do
		local r = roll()
		counts[r] = (counts[r] or 0) + 1
	end
	local out = {}
	for _, rarity in Config.RarityOrder do
		out[rarity] = 100 * (counts[rarity] or 0) / N
	end
	return out
end

local function near(actual, expected, tolerance, label)
	assert(math.abs(actual - expected) <= tolerance, `{label}: expected {expected}%, got {actual}%`)
end

return function(test, expectEqual)
	test("rarity tables sum to 100 per tier", function()
		for _, tier in Config.Tiers.order do
			assert(math.abs(Rarity.sum(Config.RarityOdds[tier]) - 100) < 1e-9, `{tier} sums to {Rarity.sum(Config.RarityOdds[tier])}`)
			for band = 1, 3 do
				local odds = Rarity.sideOdds(CONFIG, tier, band)
				assert(math.abs(Rarity.sum(odds) - 100) < 1e-9, `{tier} band {band} side odds do not sum to 100`)
			end
		end
	end)

	test("side-gift rolls match the tier's odds; the inner third rolls the next tier", function()
		local rng = Rng.new(1)
		local outer = shares(function()
			return Rarity.rollSide(rng, CONFIG, "Birthday", 1, false, Rng)
		end)
		local inner = shares(function()
			return Rarity.rollSide(rng, CONFIG, "Birthday", 3, false, Rng)
		end)
		for _, rarity in Config.RarityOrder do
			near(outer[rarity], Config.RarityOdds.Birthday[rarity], 0.5, `Birthday outer {rarity}`)
			near(inner[rarity], Config.RarityOdds.Christmas[rarity], 0.5, `Birthday inner {rarity}`)
		end
	end)

	test("The Package's inner third: Secret 2%, the extra taken from Common", function()
		local odds = Rarity.sideOdds(CONFIG, "ThePackage", 3)
		expectEqual(odds.Secret, Config.Loot.packageInnerSecretPercent, "Secret")
		expectEqual(odds.Common, Config.RarityOdds.ThePackage.Common - (Config.Loot.packageInnerSecretPercent - Config.RarityOdds.ThePackage.Secret), "Common")
		expectEqual(Config.RarityOdds.ThePackage.Secret, 1, "Config table untouched")
	end)

	test("Lucky rolls side-gifts twice and keeps the better, under 2x for every band", function()
		local rng = Rng.new(2)
		local plain = shares(function()
			return Rarity.rollSide(rng, CONFIG, "Birthday", 1, false, Rng)
		end)
		local lucky = shares(function()
			return Rarity.rollSide(rng, CONFIG, "Birthday", 1, true, Rng)
		end)
		local p = Config.RarityOdds.Birthday.Common / 100
		near(lucky.Common, 100 * p * p, 0.5, "lucky Common is both rolls Common")
		for _, rarity in { "Rare", "Epic", "Mythic" } do
			assert(lucky[rarity] < 2 * plain[rarity] + 0.3, `lucky {rarity} {lucky[rarity]}% is not under 2x {plain[rarity]}%`)
		end
	end)

	test("a first-ever run's core is never below Uncommon", function()
		local rng = Rng.new(3)
		local minRank = Rarity.rank(CONFIG, Config.Loot.firstRunMinRarity)
		for _ = 1, 20000 do
			local r = Rarity.rollCore(rng, CONFIG, "Birthday", true, Rng)
			assert(Rarity.rank(CONFIG, r) >= minRank, `first-run core rolled {r}`)
		end
	end)

	test("core rolls match the tier's odds", function()
		local rng = Rng.new(4)
		local core = shares(function()
			return Rarity.rollCore(rng, CONFIG, "Christmas", false, Rng)
		end)
		for _, rarity in Config.RarityOrder do
			near(core[rarity], Config.RarityOdds.Christmas[rarity], 0.5, `Christmas core {rarity}`)
		end
	end)

	test("mutations: only duplicates of Rare or above, about 20% of the time", function()
		local rng = Rng.new(5)
		expectEqual(Rarity.rollMutation(rng, CONFIG, "Epic", false, Rng), nil, "not a duplicate")
		for _ = 1, 1000 do
			expectEqual(Rarity.rollMutation(rng, CONFIG, "Uncommon", true, Rng), nil, "below Rare")
		end
		local hits = 0
		for _ = 1, N do
			local m = Rarity.rollMutation(rng, CONFIG, "Rare", true, Rng)
			if m then
				hits += 1
				assert(table.find(Config.Loot.launchMutations, m), `{m} is not a launch mutation`)
			end
		end
		near(100 * hits / N, 100 * Config.Loot.mutationChance, 0.5, "mutation rate")
	end)
end
