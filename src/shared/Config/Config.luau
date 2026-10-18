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
	Christmas = { layers = 9, nightSeconds = 110, presentStuds = 20 },
	Wedding = { layers = 12, nightSeconds = 130, presentStuds = 24 },
	ThePackage = { layers = 16, nightSeconds = 150, presentStuds = 28 },
	coreBoxStuds = 6, -- the last layer; shells between depth 0 and the core shrink evenly (N30)
	-- Prestige (PLAN-TABLES.txt TABLE 9). Tier numbers: Birthday 1, Christmas 2, Wedding 3, The Package 4.
	completedRunsToPrestige = { Birthday = 3, Christmas = 6, Wedding = 10 },
	vaultReclaimsPerRun = 3,
	shelfSlotsAfterPrestige = 12,
	lowerTierGemsPerRun = 1, -- any tier below your highest unlocked tier
}

-- Layer table: action, tool grade needed, weight per depth band (outer, middle, inner third).
-- A type can repeat but never twice in a row. Depth 0 is always Paper (N26). The last two layers are
-- always BoxLid, and at least one more BoxLid sits in the middle third (N27).
Config.LayerTable = {
	Paper = { action = "Tear", grade = 0, weights = { 50, 30, 20 } },
	Ribbon = { action = "Snip", grade = 1, weights = { 20, 20, 10 } },
	BubbleWrap = { action = "Pop", grade = 0, weights = { 0, 20, 20 } },
	Foil = { action = "Tear", grade = 0, weights = { 0, 15, 15 } },
	Chains = { action = "Cut", grade = 2, weights = { 0, 5, 20 } },
	Ice = { action = "Chip", grade = 2, weights = { 0, 5, 15 } },
	BoxLid = { action = "Lift", grade = 0, weights = { 0, 15, 20 }, twoPlayerFromTier = 2 }, -- prestige tier
}

-- Tape overlay (PLAN-TABLES.txt Table 4, TAPE OVERLAY RULES). Tape is never its own layer.
-- A seam is a full grid line across a face (n-1 across, n-1 down). Each strip is one panel; it runs its
-- full line and blocks every panel it touches until cut (N28). Depth 0 is never taped (N26).
Config.TapeOverlay = {
	action = "Cut",
	grade = 1,
	stripSeconds = { Scissors = 0.8, BoxCutter = 0.6, Chainsaw = 0.3 },
	paperChanceByBand = { 0.4, 0.6, 0.8 }, -- outer, middle, inner third
	seamFraction = { 0.25, 0.5 }, -- min, max share of a taped paper layer's seams, chosen from the seed
	boxLidFromTier = 2, -- BoxLid always taped at tier 2+, never at tier 1; lid cannot lift until cut
	boxLidStrips = 4, -- one per side across the lid seam (N36)
	layerTypes = { "Paper", "BoxLid" }, -- no other layer type takes tape
	stripStuds = 1, -- a strip's width; it runs the full line
}

-- Tiers this build ships (Content list): prestige stops at the last one.
Config.LaunchTiers = { "Birthday", "Christmas" }

-- Launch ships these (Content list) plus the tape overlay; post-launch updates add the rest, one per update.
Config.LaunchLayerTypes = { "Paper", "Ribbon", "BoxLid" }

-- Panels per face = clamp(floor(layer studs / panelStuds), minPerFace, maxPerFace), N30.
Config.Panels = {
	panelStuds = 4, -- a panel is about 4 studs, a thumb-sized target
	minPerFace = 3,
	maxPerFace = 6,
}

-- Ribbon: two bands crossing around the layer beneath plus a bow; one segment per face a band
-- crosses. 8 segments + 1 bow = 9 panels, all Snip (N29). No shell of its own.
Config.Ribbon = {
	bands = 2,
	facesPerBand = 4,
	bows = 1,
}

-- Phase 0 greybox only (DECISIONS.md, Phase 0 greybox panels). Replaced by real layer meshes later.
Config.Greybox = {
	panelThickness = 0.2, -- studs
	ripLineWidth = 0.15, -- studs
	ripLineColor = "#2B1E14",
	panelColors = { "#A3A2A5", "#BDBCBF" }, -- Phase 0 checker (Phase 1 paper uses Config.Palette.paper)
	checkerLighten = 0.15, -- paper checker: the layer color and this much toward white
	pickupStuds = 2, -- the glowing tool pickup
	pickupColor = "#FFFFFF",
	sideGiftStuds = 1.5, -- Art bible A: a side-gift is 1 to 2 studs
	coreGiftStuds = 3, -- a core gift is 3 to 6 studs
	giftPopStuds = 3, -- a side-gift rises this far while it waits to fly
	giftLightRange = 8, -- the rarity glow (PointLight)
	secretHueSeconds = 2, -- one full hue sweep for Secret items
}

-- Layer palette (PLAN-TABLES.txt TABLE 12). Hex strings; the client and server convert with Color3.fromHex.
Config.Palette = {
	paper = { "#E23D3D", "#5FD3A0", "#2F5BD9", "#F2C230", "#F06BA8", "#2FB8C9" },
	tape = { color = "#FFF3C4", transparency = 0.35, reflectance = 0, material = "Glass" }, -- warm gloss, specular only
	ribbon = { color = "#E0B13A", colors = { "#E0B13A", "#B52A3C" }, reflectance = 0.6 }, -- satin gold, satin crimson
	cardboard = "#B98A52",
}

-- Present look (Phase 5, PLAN-TABLES.txt Table 12 build line). Each paper colour owns one pattern, in
-- Table 12's order. Until the 512 px tiles exist (Shared/Art), the client draws them in code.
Config.PaperLook = {
	patterns = { "Stripes", "PolkaDots", "Snowflakes", "Zigzag", "Stars", "Plaid" },
	repeatsPerPanel = 2, -- a drawn pattern repeats this often across one panel, so neighbours line up
	step = 0.22, -- the lighter and darker steps of the paper's own hue (never a second hue)
	seamTransparency = 0.55, -- each panel's edge in the darker step, so the grid of tear targets reads
	pixelsPerStud = 20, -- drawn patterns and prints
	maxDrawStuds = 160, -- drawn patterns fade out past this camera distance
	printColor = "#5A3B1E", -- cardboard print: arrows and a barcode
	bowLoopStuds = 0.7, -- each bow loop, as a share of the bow's width
}

-- Run room (PLAN-TABLES.txt DIAGRAM D): one interior, present centred, shop counter in one corner.
-- Build numbers (Phase 5, Diagram D build line): walls clear The Package's 28-stud present.
Config.RunRoom = {
	sizeStuds = 60,
	shopInsetStuds = 6, -- the counter sits this far in from its corner
	wallStuds = 36,
	wallThickness = 2,
	wainscotStuds = 7,
	beamStuds = 2,
	beamSpacingStuds = 15,
	window = { wall = "East", widthStuds = 30, heightStuds = 14, sillStuds = 7, mullions = 3 }, -- the one wide window
	door = { widthStuds = 6, heightStuds = 10 }, -- in the south wall, behind the spawn
	windowLight = { color = "#FFE2B0", brightness = 3, range = 60, angle = 80 },
	lampLight = { color = "#FFD7A0", brightness = 1.1, range = 34 },
	lampCount = 4,
	colors = {
		floor = "#B5793F",
		wall = "#EADBC0",
		wainscot = "#9A6438",
		trim = "#5C3A22",
		beam = "#6B4428",
		ceiling = "#C99A66",
		glass = "#CFE8F7",
		outside = "#6FBF4A",
	},
}

-- HUD (Table 13). Colours of the wooden chrome are in Config.UI.
Config.HUD = {
	toastSeconds = 2,
	feedSeconds = 3, -- a side-gift line in the loot feed
	tileTextMax = 22, -- shelf tiles share one text size cap
	nightTimerColor = "#E23D3D", -- Table 13: the Night timer is red (candy red from the palette)
}

-- UI style (Phase 5, PLAN-TABLES.txt Table 13 build line): wooden panels, rounded corners, one bold
-- rounded sans at three sizes, a twine gift-tag accent. Chrome never uses a present or rarity colour.
Config.UI = {
	font = "FredokaOne",
	textSizes = { 18, 26, 40 }, -- small, medium, large (pixels at most; text scales down on small screens)
	cornerPx = 14,
	strokePx = 3,
	woodDark = "#4A2E1C", -- outlines and text stroke
	woodMid = "#8B5A35", -- frames
	woodLight = "#C68E5A", -- panel faces
	parchment = "#F3E3C3", -- cards and slots
	ink = "#3B2416", -- text on parchment
	cream = "#FFF6E6", -- text on wood
	twine = "#E9D3A6", -- gift-tag string and the ribbon accent on titles
	action = "#E8803A", -- primary buttons
	close = "#B8432F",
	disabled = "#9A8A7A",
	keys = { Shelf = "F", Shop = "B", Classes = "C", Rewards = "R" }, -- the letter under each right-edge button
}

-- Lighting (Phase 5): the lobby at early winter dusk (cool sky light, a warm low sun, restrained bloom),
-- the run room in warm daylight. NightView scales exposure from the run room's.
Config.Lighting = {
	Lobby = {
		clockTime = 16.7,
		brightness = 2.1,
		ambient = "#6C7286",
		outdoorAmbient = "#8E98B2",
		colorShiftTop = "#FFC48F",
		colorShiftBottom = "#7A88B0",
		atmosphere = { density = 0.33, haze = 1.7, color = "#C9D4E8", decay = "#E6A27E", glare = 0.25 },
		bloom = { intensity = 0.35, size = 24, threshold = 1.5 },
		clouds = { cover = 0.55, density = 0.45, color = "#E8DCE6" },
	},
	Run = { clockTime = 14.5, brightness = 2.4, ambient = "#7E6A58", outdoorAmbient = "#9A8672", colorShiftTop = "#FFE2B8", atmosphere = { density = 0.2, haze = 0.8, color = "#F2D9B8", decay = "#B88E6A" } },
}

-- VFX (PLAN-TABLES.txt Table 14): every count is per emitter, per event.
Config.Vfx = {
	tearFlecks = 6,
	clearConfetti = 40,
	clearSeconds = 0.6,
	giftPop = 12,
	giftTrailSeconds = 0.8, -- the arc to the bag
	revealDrift = 30,
	revealShaftStuds = 24, -- the light shaft out of the core box
	revealShaftWidth = 5,
	lungePuffs = 8,
	tickShimmerTransparency = 0.9, -- the Tick's faint heat shimmer: a Neon shell, no particles
	clearLightBrightness = 3,
}

-- Cash (PLAN-TABLES.txt TABLE 7): per panel torn = the tier number (N35); per side-gift on pickup, paid
-- to the player it flies to (N32). Cash left at bank is gone.
Config.Cash = {
	perPanel = { Birthday = 1, Christmas = 2, Wedding = 3, ThePackage = 4 },
	perSideGift = { Common = 5, Uncommon = 12, Rare = 30, Epic = 75, Mythic = 200, Secret = 0 },
}

-- The Tick is a side box in one middle-third layer; 40% of nests fuse it across the lid seam.
Config.TickBlockingChance = 0.4

-- The Tick's build numbers (PLAN-TABLES.txt TABLE 20, build line; DECISIONS.md).
Config.Tick = {
	studs = 1, -- side-gift sized (Art bible A: 1 to 2 studs); small enough to hide between shells
	openSeconds = 1.2, -- hold to open: the hands time, it is wrapped in paper
	promptStuds = 3, -- the Open prompt hangs this high under the Tick (prompts off screen are hidden)
	sideGifts = 3, -- opening it drops the run's best side-gifts: the most a layer rolls ...
	sideGiftBand = 3, -- ... from the inner-third table (the run's best)
	seamColor = "#FF4D2E", -- Table 12: Neon seams
	seamPulseSeconds = 0.8,
	volumeMax = 0.8, -- ticking at its own layer
	volumeFalloff = 0.5, -- each layer still between the team and the Tick halves it
	volumeMin = 0.05,
	rimLightColor = "#7FD8FF", -- the cold rim light from the Tick box (ice inner Neon, Table 12)
	rimLightRange = 16,
	rimLightBrightness = 2,
}

-- Tools: grade (0 hands to 3 chainsaw), per-panel seconds, and actions with optional per-action override seconds.
Config.Tools = {
	Hands = { grade = 0, seconds = 1.2, actions = { Tear = 1.2, Pop = 1.2, Lift = 1.2 } },
	Scissors = { grade = 1, seconds = 0.8, actions = { Cut = 0.8, Snip = 0.8, Tear = 1.0 }, pickupDepth = 1 }, -- spawns as depth 1 is revealed
	BoxCutter = { grade = 2, seconds = 0.6, actions = { Cut = 0.6, Chip = 0.6, Tear = 0.6 } },
	Chainsaw = { grade = 3, seconds = 0.3, actions = "All", areaPanels = 2 }, -- tears a 2x2
}

-- The Tear feel spec
Config.Tear = {
	flutterSeconds = 2, -- then the piece settles where it lies and stays until recycled
	debrisImpulse = 8, -- studs per second, away from the present
	debrisSpinMax = 4, -- radians per second, random per axis
	debrisFallScale = 0.35, -- share of gravity a piece feels while it flutters
	maxLiveDebris = 40,
	pitchVariance = 0.1,
	chainsawShakeSeconds = 0.1,
	maxRequestsPerSecond = 8, -- server-enforced
	reachMinStuds = 20, -- server-enforced reach = max(reachMinStuds, present studs + reachPadStuds) (N37)
	reachPadStuds = 4,
}

-- Sounds (PLAN-TABLES.txt TABLE 14, SFX launch set). Three variants each; pitch randomized by Config.Tear.pitchVariance.
-- Roblox-licensed ProSoundEffects clips, free for any experience.
Config.Sounds = {
	tearHoldStart = { "rbxassetid://9113248978", "rbxassetid://9113249956", "rbxassetid://9113249814" },
	tearRelease = { "rbxassetid://9125724621", "rbxassetid://9117624703", "rbxassetid://9117624735" },
	paperLand = { "rbxassetid://9114121637", "rbxassetid://15675037413", "rbxassetid://9125723208" },
	-- Night: APM "Ticking (b)", ProSoundEffects toy wind-up, comic ratchet and wood impact (Roblox-licensed).
	tickLoop = { "rbxassetid://1839847326" },
	jackCrank = { "rbxassetid://9120225609" },
	jackLunge = { "rbxassetid://9118043063" },
	playerDown = { "rbxassetid://9120915492" },
	-- Phase 5, completing the 24-clip launch set (ProSoundEffects, Roblox-licensed): cloth-rip zips for
	-- tape, squeaky scissor snips for ribbon, cardboard box slides for lids, mouth pops for side-gifts.
	tapeCut = { "rbxassetid://9113836687", "rbxassetid://9113836714" },
	ribbonSnip = { "rbxassetid://9118831072", "rbxassetid://9118831088" },
	lidLift = { "rbxassetid://9113578867", "rbxassetid://9114054266", "rbxassetid://9113578876" },
	giftPop = { "rbxassetid://9117847793", "rbxassetid://9117848338", "rbxassetid://9117848644" },
	-- Placeholder until a licensed sting is chosen: Daily Sounds "Coin Pickup" (synthesized, free).
	coreSting = { "rbxassetid://130378474223829" },
}

-- Mechanics B: rarity
Config.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Mythic", "Secret" }

Config.Rarity = {
	-- Hex strings, not Color3: Config holds no Roblox types. The client converts with Color3.fromHex.
	Common = { color = "#9AA0A6", shelfSlots = 1, naughty = 1 },
	Uncommon = { color = "#4CC96B", shelfSlots = 1, naughty = 2 },
	Rare = { color = "#3C8DFF", shelfSlots = 2, naughty = 3 },
	Epic = { color = "#A857F0", shelfSlots = 2, naughty = 4 },
	Mythic = { color = "#FFC23D", shelfSlots = 3, naughty = 5 },
	Secret = { color = nil, shelfSlots = 4, naughty = nil }, -- animated hue sweep; cannot be stolen
}

-- Odds in percent; each table sums to 100.
Config.RarityOdds = {
	Birthday = { Common = 55, Uncommon = 28, Rare = 12, Epic = 4, Mythic = 0.9, Secret = 0.1 },
	Christmas = { Common = 46, Uncommon = 28, Rare = 18, Epic = 7, Mythic = 0.9, Secret = 0.1 },
	Wedding = { Common = 37, Uncommon = 28, Rare = 22, Epic = 10, Mythic = 2.9, Secret = 0.1 },
	ThePackage = { Common = 30, Uncommon = 30, Rare = 22, Epic = 12, Mythic = 5, Secret = 1 },
}

Config.Loot = {
	sideGiftsPerLayer = { 1, 3 },
	flyToBagDelay = 1,
	flySeconds = 0.8, -- the arc to the bag (Table 14: beam 0.8 s)
	coreRevealSeconds = 3,
	revealBeatSeconds = 1, -- the quiet beat between the reveal and the bank screen
	firstRunMinRarity = "Uncommon",
	mutationChance = 0.2, -- duplicate core gift of Rare or above
	innerThirdRollsNextTier = true, -- side-gifts in the inner third roll the next tier's table
	packageInnerSecretPercent = 2, -- The Package inner third rolls its core table with Secret at 2%
	mutationMinRarity = "Rare",
	families = { "plush", "vehicle", "figure", "candy", "trinket", "tech", "odd", "seasonal" },
	launchMutations = { "Giant", "Golden" }, -- Content list: frosted and glitched come in updates
	sellGems = { Common = 1, Uncommon = 2, Rare = 4, Epic = 8, Mythic = 20 }, -- N33; Secret cannot be sold
}

-- Jack's model (Phase 5, Table 20 build line): a toy jack-in-the-box, mild (N17).
Config.JackLook = {
	face = "#FFF3DC",
	blush = "#F4A6A0",
	nose = "#D9453B",
	ink = "#2B1E14",
	collar = "#B52A3C",
	hat = { "#B52A3C", "#E0B13A" },
	spring = "#E0B13A",
	springDark = "#B8902E",
	crank = "#C9CED6",
	springRings = 6,
	springStuds = 1.1, -- ring diameter
	flapOpenDegrees = 50,
	lungeStretch = 1.35, -- the spring stretches this much while he lunges
}

-- Tool props (Phase 5): the scissors pickup and a dropped tool lie on a soft glowing ring.
Config.ToolLook = { metal = "#C9CED6", grip = "#D9573B", body = "#E8A33A", ink = "#2B1E14", glow = "#FFF6E6" }

-- Loot look (Phase 5, PLAN-TABLES.txt Table 12 build line): chunky toys in their rarity colour plus one
-- accent, built from blocks and balls (Shared/Art/GiftModels) until the commissioned models exist (N7).
Config.LootLook = {
	sideGiftStuds = 1.5, -- Art bible A: 1 to 2 studs
	coreGiftStuds = 4, -- Art bible A: 3 to 6 studs
	shelfFill = 0.8, -- a gift fills this share of its shelf cell
	accent = "#FFF3DC", -- the one accent on every toy
	ink = "#2B1E14", -- eyes, wheels, buttons
	shade = 0.25, -- the rarity colour's darker step for a second body colour
	golden = { color = "#E0B13A", reflectance = 0.5 }, -- mutation Golden
	giantScale = 2, -- mutation Giant
	mythicSpinSeconds = 6, -- Mythic core gifts turn slowly (idle animation)
	mythicBobStuds = 0.3,
	glowRange = 8, -- the rarity glow (PointLight)
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
	-- Build numbers (PLAN-TABLES.txt TABLE 20, build line; DECISIONS.md)
	desaturate = 0.4, -- Table 12: paper desaturated 40% at Night
	nightRibbonReflectance = 0.2,
	jackLungeSpeed = 16, -- studs per second, a walking player's speed: a lunge covers 24 studs
	jackHitStuds = 3, -- a lunge connects within this far (floor distance) of a player
	jackRadiusStuds = 1.5, -- Jack stops short of the present and of lids by this much
	jackHeadStuds = 5, -- Jack looks from this height (head the size of a player, on a spring)
	jackBoxStuds = 2.5,
	shutterOffsetStuds = 3, -- a held lid stands this far from its holders, toward Jack
	reachStuds = 10, -- revive and shutter prompts
	holdSlackSeconds = 0.25, -- a prompt hold may finish this much early (network), never more
	wipeScreenSeconds = 4,
	downGrey = -1, -- the downed player's screen saturation (greyscale)
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
Config.ClassOrder = { "Kid", "Wrapper", "Sprinter", "Collector", "Heir", "KrampusKid" }
Config.Classes = {
	Kid = { rarity = "Common", odds = 40, name = "Kid", cashBonus = 0.05 },
	Wrapper = { rarity = "Uncommon", odds = 28, name = "Wrapper", startCash = 20, tapeGrade = 0 },
	Sprinter = { rarity = "Rare", odds = 16, name = "Sprinter", walkSpeedBonus = 3, jackLungeScale = 0.75, startUpgrades = { "Flashlight" } },
	Collector = { rarity = "Epic", odds = 10, name = "Collector", lidSideGifts = 1, gemBonus = 0.1, startCash = 50, startTools = { "Scissors" } },
	Heir = { rarity = "Legendary", odds = 4.5, name = "Heir", coreRolls = 2, startCash = 100, startTools = { "BoxCutter" } },
	KrampusKid = { rarity = "Mythic", odds = 1.5, name = "Krampus's Kid" }, -- Krampus immunity and steal rules: Phase 6
}

-- Gamepass and dev product ids are created on Roblox by a human; 0 = not created yet (shown, not buyable).
Config.Gamepasses = {
	DoubleCash = { robux = 199, id = 2039841362, name = "2x Cash", cashScale = 2 },
	BigShelf = { robux = 299, id = 2037525496, name = "Big Shelf" },
	-- Tools are never dropped when downed (Phase 4); every run starts with these in hand. No gift impact.
	ToolKeeper = { robux = 149, id = 2037021484, name = "Tool Keeper", keepToolsWhenDowned = true, startTools = { "Scissors" } },
	-- Side-gift rolls happen twice, keep the better rarity; never the core (invariant 6: 2p - p^2 < 2p).
	-- Party-wide and non-stacking: one owner in the run is enough, two owners change nothing.
	Lucky = { robux = 399, id = 2040345077, name = "Lucky", rollTwice = true },
}
Config.GamepassOrder = { "DoubleCash", "BigShelf", "ToolKeeper", "Lucky" }

-- Dev products (Table 10). Gems only: no product grants a gift (invariant 6). Paper packs wait for cosmetics.
Config.DevProducts = {
	Gems100 = { robux = 99, id = 3719386348, gems = 100 },
	Gems500 = { robux = 399, id = 3719386432, gems = 500 },
	Gems1200 = { robux = 799, id = 3719386483, gems = 1200 },
}
Config.DevProductOrder = { "Gems100", "Gems500", "Gems1200" }
Config.PurchaseHistoryMax = 50 -- receipt ids kept in the profile to never grant one twice

-- The group for the one-time reward (Table 7); 0 = not created yet.
Config.Group = { id = 0 }

-- Data (N34): one ProfileStore profile per player, key = keyPrefix .. UserId.
Config.Data = {
	storeName = "PlayerData",
	keyPrefix = "Player_",
}

-- Place ids (experience 10771563436); 0 = not created yet. Teleports are skipped in Studio or while 0.
-- Which place this is comes from the Workspace attribute PlaceKind ("Lobby"; absent = the run place).
Config.Places = { lobby = 96472302491903, run = 98807937316780 }

-- Lobby: Unwrapping Plaza, a snowy gift village at early dusk (Diagram D as revised 2026-10-18,
-- DECISIONS.md). x grows east, z grows south; the plaza's centre is (0, 0, 0). A bearing is degrees
-- clockwise from north (-z).
Config.Lobby = {
	plazaRadius = 46, -- the paved plaza, ribbon inlay crossing at its centre
	spawn = { 0, 24 }, -- south of centre, facing north: the pads, then the giant present behind them
	padsZ = -12, -- the three Start a Run pads in a row before the giant present
	padsX = { -14, 0, 14 }, -- solo, party, join anyone
	padStuds = 8,
	padColors = { "#5FD3A0", "#2F5BD9", "#F2C230" }, -- solo, party, join anyone
	-- The signature landmark: a half-unwrapped present on a round terrace north of the pads (decor only).
	landmark = { center = { 0, -46 }, terraceRadius = 18, terraceStuds = 3, presentStuds = 20, yawDeg = 10, lidLiftDeg = 20, paper = 6, glowRange = 28, glowBrightness = 1.1 },
	-- Pavilions: { bearing, distance from the centre }; each faces the centre.
	pavilions = { Rewards = { 270, 36 }, Classes = { 90, 36 }, Shop = { 135, 36 } },
	house = { -40, -40 }, -- the cottage, porch on its south side facing the plaza (vault crates, tier decoration)
	updateBoard = { 28, -30 }, -- beside the pads, room for the leaderboards later (Table 19)
	-- The shelf gallery: a covered lane running west from the plaza, shelves on both sides facing the lane;
	-- the lane's middle is the Krampus walk. Slot 1 is nearest the plaza, odd slots north, even south.
	gallery = { startX = -40, z = 24, laneStuds = 12, bayStuds = 7, bays = 12, roofStuds = 10 }, -- 24 shelves under roof
	-- A raised snowy terrace ring framing the plaza, open where the landmark, cottage and gallery meet it.
	terrace = { outer = 62, heightStuds = 2.5, gaps = { { 292, 25 }, { 214, 264 } }, steps = { 180, 60 } },
	village = { houses = 9, ring = { 80, 118 } }, -- backdrop cottages, windows lit, nobody goes in
	forest = { trees = 50, ring = { 68, 165 } },
	hills = { count = 16, ring = { 190, 300 }, radius = { 30, 55 } }, -- terrain snow hills
	mountains = { count = 11, ring = { 430, 560 } }, -- far peaks, hazed by the atmosphere
	snowfieldStuds = 1600, -- terrain snow under everything
	padPollSeconds = 0.25,
	tokenSeconds = 120, -- a party token lives this long in MemoryStore (N9)
	arrivalWaitSeconds = 15, -- the run place waits this long for the whole party before starting
	colors = { house = "#E8D9C0", roof = "#8E3B2F", tree = "#2E7D4F" }, -- world tier, stock materials
	-- Client motion (Shelf/Ambience): snow around the camera, a few drifting paper scraps, tags and
	-- ribbons that sway, the pads' rims and the landmark's glow breathing.
	ambience = {
		snowRate = 40, -- flakes per second from one emitter that follows the camera
		snowLifetime = { 7, 9 },
		snowSpeed = { 3, 5 },
		snowSize = 0.28,
		snowBoxStuds = 110,
		snowHeightStuds = 36,
		paperMax = 3, -- drifting paper scraps alive at once
		paperEverySeconds = { 5, 9 },
		paperFallSeconds = 8,
		paperRadiusStuds = 30,
		swaySeconds = 3.2, -- one full swing of a tag or ribbon
		pulseSeconds = 2.4, -- pads' rims and the landmark's glow
	},
	dress = {
		wood = "#9A6438",
		woodDark = "#5C3A22",
		plank = "#C08A55",
		wall = "#D9B88A",
		trim = "#F3E3C3",
		leaves = { "#3E9A4F", "#4FB35A", "#2E7D4F" }, -- the run room garden's trees (Props.tree)
		trunk = "#6B4428",
		lantern = "#FFC97A",
		sign = "#E9C99A",
		ink = "#3B2416",
		glass = "#BFE3F2", -- house windows
		chimney = "#8E6E5A",
		gem = "#7FD8FF", -- the gem cluster on the Shop booth
		-- Snowy village (2026-10-18): cool blue-white snow, warm windows, red / gold / teal gift accents.
		snow = "#EEF3FA",
		snowShade = "#D5DEEC", -- snow in shadow and on the far peaks
		stone = "#A7A29C", -- retaining walls, terraces
		stoneDark = "#7E7A78",
		paving = "#C6C0B8",
		pavingBand = "#B2ABA2",
		ribbonRed = "#B52A3C", -- the plaza's ribbon inlay (Table 12 crimson)
		ribbonGold = "#E0B13A", -- its edging and the landmark's ribbon (Table 12 gold)
		teal = "#2FB8C9",
		red = "#E23D3D",
		cream = "#F3E3C3",
		fir = { "#2C5A45", "#346B50", "#25503D" },
		window = "#FFC46B", -- lit windows (Neon)
		walls = { "#D9B88A", "#C9A27A", "#E2CDB0", "#B98B6A" }, -- backdrop cottages
		roofs = { "#8E3B2F", "#5E4A6E", "#3F5E6E", "#7A4A32" },
		rock = "#8C8F96",
		glow = "#FFC873", -- the warm light inside the landmark
	},
}

-- Two places (DECISIONS.md N10, N11)
Config.Run = {
	rejoinWindowSeconds = 120,
}

Config.Matchmaking = {
	waitSeconds = 20,
	maxParty = 4,
}

-- Mechanics E: keeping players playing (PLAN-TABLES.txt TABLE 19)
-- Level n costs costLevel1 + costStep * (n - 1) gems.
Config.PermanentTrack = {
	Pockets = { startCashPerLevel = 10, maxLevel = 10, costLevel1 = 20, costStep = 10 },
	NightEyes = { lightingPerLevel = 0.05, maxBonus = 0.3, maxLevel = 6, costLevel1 = 30, costStep = 15 },
}

Config.RepeatPrestige = {
	runsPerRepeat = 10,
	secretOddsStepPercent = 0.5,
	secretOddsCapPercent = 3,
	mutationChanceStep = 0.02,
	mutationChanceCap = 0.3,
	nightSecondsStep = 10,
	nightSecondsCap = 180,
	cosmeticEveryRepeats = 3, -- a paper pack cosmetic every third repeat
	starCap = 10,
}

Config.FeaturedModifiers = { "AllIce", "DoubleTick", "TapeEverywhere", "Giant", "Tiny", "GoldenHour", "SilentNight" }

Config.Leaderboards = { "FastestBirthdayRun", "MostMythics", "LongestStreak", "MostRepeats" }

return Config
