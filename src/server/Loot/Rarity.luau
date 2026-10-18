--[=[
	Rarity (pure logic, server)
	Owns: rolling a rarity for a side-gift or the core gift, and the duplicate mutation roll.
	Rules (PLAN.md › Mechanics B; PLAN-TABLES.txt Table 6): odds per tier sum to 100; side-gifts in
	the inner third roll the next tier's table, and The Package's inner third rolls its own table with
	Secret at 2% (the extra taken from Common, as N3 does); Lucky rolls side-gifts twice and keeps the
	better, never the core (N4); a first-ever run's core is Uncommon or better; a duplicate core gift
	of Rare or above has a 20% mutation roll.
	Must never: run on the client, re-roll on request, or call game:GetService. Rng is passed in.
	Read first: src/server/Loot/README.md
]=]

export type Odds = { [string]: number }

export type LootConfig = {
	order: { string }, -- Config.RarityOrder, worst to best
	odds: { [string]: Odds }, -- Config.RarityOdds by tier
	tiers: { string }, -- Config.Tiers.order
	packageInnerSecretPercent: number,
	firstRunMinRarity: string,
	mutationChance: number,
	mutationMinRarity: string,
	mutations: { string },
}

export type RngApi = {
	next: (rng: any) -> number,
	int: (rng: any, lo: number, hi: number) -> number,
	weighted: (rng: any, entries: { { value: string, weight: number } }) -> string?,
}

local INNER = 3
local SECRET = "Secret"
local COMMON = "Common"

local Rarity = {}

function Rarity.sum(odds: Odds): number
	local total = 0
	for _, percent in odds do
		total += percent
	end
	return total
end

function Rarity.rank(config: LootConfig, rarity: string): number
	return table.find(config.order, rarity) or 0
end

-- The odds a side-gift rolls on at `band` (1 outer, 2 middle, 3 inner third) of a `tier` present.
function Rarity.sideOdds(config: LootConfig, tier: string, band: number): Odds
	if band < INNER then
		return config.odds[tier]
	end
	local i = table.find(config.tiers, tier) :: number
	local nextTier = config.tiers[i + 1]
	if nextTier then
		return config.odds[nextTier]
	end
	local odds = table.clone(config.odds[tier])
	local extra = config.packageInnerSecretPercent - odds[SECRET]
	odds[SECRET] += extra
	odds[COMMON] -= extra
	return odds
end

local function rollOn(rng: any, config: LootConfig, odds: Odds, minRank: number, Rng: RngApi): string
	local entries = {}
	for rank, rarity in config.order do
		if rank >= minRank then
			table.insert(entries, { value = rarity, weight = odds[rarity] or 0 })
		end
	end
	return Rng.weighted(rng, entries) :: string
end

function Rarity.rollSide(rng: any, config: LootConfig, tier: string, band: number, lucky: boolean, Rng: RngApi): string
	local odds = Rarity.sideOdds(config, tier, band)
	local first = rollOn(rng, config, odds, 1, Rng)
	if not lucky then
		return first
	end
	local second = rollOn(rng, config, odds, 1, Rng)
	return if Rarity.rank(config, second) > Rarity.rank(config, first) then second else first
end

-- The core gift. No luck parameter on purpose: invariant 6, the core is never boosted by Robux.
function Rarity.rollCore(rng: any, config: LootConfig, tier: string, firstRun: boolean, Rng: RngApi): string
	local minRank = if firstRun then Rarity.rank(config, config.firstRunMinRarity) else 1
	return rollOn(rng, config, config.odds[tier], minRank, Rng)
end

-- A duplicate core gift of the minimum rarity or above may come out mutated. Returns the mutation or nil.
function Rarity.rollMutation(rng: any, config: LootConfig, rarity: string, duplicate: boolean, Rng: RngApi): string?
	if not duplicate or Rarity.rank(config, rarity) < Rarity.rank(config, config.mutationMinRarity) then
		return nil
	end
	if Rng.next(rng) >= config.mutationChance then
		return nil
	end
	return config.mutations[Rng.int(rng, 1, #config.mutations)]
end

return Rarity
