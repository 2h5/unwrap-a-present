--[=[
	Config (shared)
	Owns: every tunable number from docs/PLAN-TABLES.txt, in one place. Systems read from here.
	Must never: contain logic, or a value the plan does not state (log a decision first).
	A number changed here is changed in PLAN-TABLES.txt in the same commit.
	Read first: src/shared/README.md
]=]

local Config = {}

-- Mechanics A: tiers and the Nest
Config.Tiers = {
	order = { "Birthday", "Christmas", "Wedding", "ThePackage" },
	Birthday = { layers = 6, nightSeconds = 90, presentStuds = 16 },
	Christmas = { layers = 9, nightSeconds = 110 },
	Wedding = { layers = 12, nightSeconds = 130 },
	ThePackage = { layers = 16, nightSeconds = 150, presentStuds = 28 },
	-- Prestige (PLAN-TABLES.txt TABLE 9). Tier numbers: Birthday 1, Christmas 2, Wedding 3, The Package 4.
	completedRunsToPrestige = { Birthday = 3, Christmas = 6, Wedding = 10 },
	vaultReclaimsPerRun = 3,
	shelfSlotsAfterPrestige = 12,
	lowerTierGemsPerRun = 1, -- any tier below your highest unlocked tier
}

-- Layer table: action, tool grade needed, weight per depth band (outer, middle, inner third).
-- A type can repeat but never twice in a row. The last two layers are always BoxLid.
Config.LayerTable = {
	Paper = { action = "Tear", grade = 0, weights = { 50, 30, 20 } },
	Ribbon = { action = "Snip", grade = 1, weights = { 20, 20, 10 } },
	BubbleWrap = { action = "Pop", grade = 0, weights = { 0, 20, 20 } },
	Foil = { action = "Tear", grade = 0, weights = { 0, 15, 15 } },
	Chains = { action = "Cut", grade = 2, weights = { 0, 5, 20 } },
	Ice = { action = "Chip", grade = 2, weights = { 0, 5, 15 } },
	BoxLid = { action = "Lift", grade = 0, twoPlayerFromTier = 2 }, -- prestige tier
}

-- Tape overlay (PLAN-TABLES.txt Table 4, TAPE OVERLAY RULES). Tape is never its own layer.
-- Each strip is one panel that blocks the two panels it spans until cut.
Config.TapeOverlay = {
	action = "Cut",
	grade = 1,
	stripSeconds = { Scissors = 0.8, BoxCutter = 0.6, Chainsaw = 0.3 },
	paperChanceByBand = { 0.4, 0.6, 0.8 }, -- outer, middle, inner third
	seamFraction = { 0.25, 0.5 }, -- min, max share of a taped paper layer's seams, chosen from the seed
	boxLidFromTier = 2, -- BoxLid always taped at tier 2+, never at tier 1; lid cannot lift until cut
	layerTypes = { "Paper", "BoxLid" }, -- no other layer type takes tape
}

-- Launch ships these (Content list) plus the tape overlay; post-launch updates add the rest, one per update.
Config.LaunchLayerTypes = { "Paper", "Ribbon", "BoxLid" }

Config.Panels = {
	gridPerFaceLowTier = 4, -- 4x4 per face, 6 faces = 96 panels, tiers 1-2
	gridPerFaceHighTier = 6, -- 6x6 at tiers 3-4
	highTierFrom = 3,
}

-- The Tick is a side box in one middle-third layer; 40% of nests fuse it across the lid seam.
Config.TickBlockingChance = 0.4

-- Tools: grade (0 hands to 3 chainsaw), per-panel seconds, and actions with optional per-action override seconds.
Config.Tools = {
	Hands = { grade = 0, seconds = 1.2, actions = { Tear = 1.2, Pop = 1.2, Lift = 1.2 } },
	Scissors = { grade = 1, seconds = 0.8, actions = { Cut = 0.8, Snip = 0.8, Tear = 1.0 }, pickupDepth = 1 },
	BoxCutter = { grade = 2, seconds = 0.6, actions = { Cut = 0.6, Chip = 0.6, Tear = 0.6 } },
	Chainsaw = { grade = 3, seconds = 0.3, actions = "All", areaPanels = 2 }, -- tears a 2x2
}

-- The Tear feel spec
Config.Tear = {
	flutterSeconds = 2,
	maxLiveDebris = 40,
	pitchVariance = 0.1,
	chainsawShakeSeconds = 0.1,
	maxRequestsPerSecond = 8, -- server-enforced
}

-- Mechanics B: rarity
Config.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Mythic", "Secret" }

Config.Rarity = {
	Common = { color = Color3.fromHex("#9AA0A6"), shelfSlots = 1, naughty = 1 },
	Uncommon = { color = Color3.fromHex("#4CC96B"), shelfSlots = 1, naughty = 2 },
	Rare = { color = Color3.fromHex("#3C8DFF"), shelfSlots = 2, naughty = 3 },
	Epic = { color = Color3.fromHex("#A857F0"), shelfSlots = 2, naughty = 4 },
	Mythic = { color = Color3.fromHex("#FFC23D"), shelfSlots = 3, naughty = 5 },
	Secret = { color = nil, shelfSlots = 4, naughty = nil }, -- animated hue sweep; cannot be stolen
}

-- Odds in percent; each table sums to 100. Christmas and Wedding apply the shifts in PLAN.md
-- (Mechanics D › Prestige) to Birthday. How the shift is taken from Common/Uncommon is open:
-- log a decision in phase 2 before filling those two in.
Config.RarityOdds = {
	Birthday = { Common = 55, Uncommon = 28, Rare = 12, Epic = 4, Mythic = 0.9, Secret = 0.1 },
	ThePackage = { Common = 30, Uncommon = 30, Rare = 22, Epic = 12, Mythic = 5, Secret = 1 },
}

Config.TierShift = {
	Christmas = { Rare = 6, Epic = 3 },
	Wedding = { Rare = 10, Epic = 6, Mythic = 2 },
}

Config.Loot = {
	sideGiftsPerLayer = { 1, 3 },
	flyToBagDelay = 1,
	coreRevealSeconds = 3,
	firstRunMinRarity = "Uncommon",
	mutationChance = 0.2, -- duplicate core gift of Rare or above
	innerThirdRollsNextTier = true, -- side-gifts in the inner third roll the next tier's table
	packageInnerSecretPercent = 2, -- The Package inner third rolls its core table with Secret at 2%
	mutationMinRarity = "Rare",
	families = { "plush", "vehicle", "figure", "candy", "trinket", "tech", "odd", "seasonal" },
}

Config.Shelf = {
	startSlots = 12,
	gemSlotsMax = 24,
	passSlotsMax = 36,
	gemsPer4Slots = 50,
	stackMax = 9, -- duplicates stack on one slot; a steal takes one
}

Config.BankGems = { completed = 3, noDowns = 5, tickSurvived = 8 }

-- Mechanics C: Night, Jack, Steal, Krampus
Config.Night = {
	lightingScale = 0.3,
	jackStillSeconds = 3,
	jackLungeSeconds = 1.5,
	shutterMaxSeconds = 4,
	reviveHoldSeconds = 3,
	soloAutoReviveSeconds = 10,
}

Config.Steal = {
	holdSeconds = 6,
	offlineMaxRarity = "Uncommon",
	naughtyMax = 20,
	naughtyDecayPerDay = 3,
	naughtyShowAbove = 5,
	naughtyGlowAbove = 10,
}

Config.Krampus = {
	intervalSeconds = 20 * 60,
	visitSeconds = 60,
	targetNaughtyMin = 8,
	sackOpenNaughtyMax = 0,
}

-- Mechanics D: economy
Config.Shop = {
	Scissors = { cost = 30 },
	BoxCutter = { cost = 120 },
	Chainsaw = { cost = 400, minTier = 2 }, -- prestige tier
	GripTape = { cost = 60, panelTimeScale = 0.85 },
	Flashlight = { cost = 40, nightLightingScale = 0.6 },
	SpareLid = { cost = 80 },
	LuckyBow = { cost = 150, extraSideGifts = 1 },
}

Config.Gems = {
	daily = 35,
	dailyIntervalSeconds = 6 * 60 * 60,
	groupOneTime = 100,
	classSpin = 25,
	classDuplicateRefund = 10,
	streakPerDay = 10,
	streakCapDays = 7,
	friendBonusPerPlayer = 2, -- per run, party of 2 or more
}

-- Passives and starting kit: PLAN.md › Mechanics D › Classes. Players own every class they roll.
Config.Classes = {
	Kid = { rarity = "Common", odds = 40 },
	Wrapper = { rarity = "Uncommon", odds = 28 },
	Sprinter = { rarity = "Rare", odds = 16 },
	Collector = { rarity = "Epic", odds = 10 },
	Heir = { rarity = "Legendary", odds = 4.5 },
	KrampusKid = { rarity = "Mythic", odds = 1.5 },
}

Config.Gamepasses = {
	DoubleCash = { robux = 199 },
	BigShelf = { robux = 299 },
	ExtraToolSlot = { robux = 149 },
	Lucky = { robux = 399 }, -- side-gifts only, never the core (invariant 6)
}

-- Mechanics E: keeping players playing (PLAN-TABLES.txt TABLE 19)
Config.PermanentTrack = {
	Pockets = { startCashPerLevel = 10, maxLevel = 10 },
	NightEyes = { lightingPerLevel = 0.05, maxBonus = 0.3 },
	-- Gem cost per level: not set yet (open question in PLAN.md).
}

Config.RepeatPrestige = {
	secretOddsStepPercent = 0.5,
	secretOddsCapPercent = 3,
	mutationChanceCap = 0.3, -- step per repeat not set yet
	nightSecondsStep = 10,
	nightSecondsCap = 180,
}

Config.FeaturedModifiers = { "AllIce", "DoubleTick", "TapeEverywhere", "Giant", "Tiny", "GoldenHour", "SilentNight" }

Config.Leaderboards = { "FastestBirthdayRun", "MostMythics", "LongestStreak" }

return Config
