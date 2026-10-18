--[=[
	Art (shared)
	Owns: every image the game shows, by slot name, in one table. An empty id means the slot still uses
	its code-drawn placeholder (Patterns, GiftModels, HUD Icons); filling the id swaps in the final
	image with no other code change. The list of slots, placeholders and intended finals:
	docs/art/assets.md.
	Must never: hold a screenshot crop, a reference image or baked text (text, prices, odds and buttons
	stay live UI). Ids are uploaded by a human; nothing here uploads.
	Read first: src/shared/README.md
]=]

local Art = {}

-- rbxassetid:// ids, "" until the final image is uploaded.
Art.images = {
	-- Present tier (Table 11): one 512 px tile per launch paper, the cardboard print.
	PaperStripes = "",
	PaperPolkaDots = "",
	PaperSnowflakes = "",
	PaperZigzag = "",
	PaperStars = "",
	PaperPlaid = "",
	CardboardPrint = "",
	-- Loot tier: the one dot relief tile shared by all loot (0.25 studs per dot).
	LootDots = "",
	-- UI: the hold ring (white, tinted in code) and the icons. Every icon is a square 512 px PNG on a
	-- transparent background; any HUD icon without its own slot below looks for Icon<Name>.
	HoldRing = "",
	IconShelf = "",
	IconShop = "",
	IconClasses = "",
	IconRewards = "",
	IconCash = "",
	IconGems = "",
	IconClose = "",
	IconStar = "",
	IconHands = "",
	IconDaily = "",
	IconGroup = "",
	IconStreak = "",
	IconPockets = "",
	IconNightEyes = "",
	IconBigShelf = "",
	IconPrestige = "",
	IconTier = "",
	IconVault = "",
	-- UI cards: one illustration per class, pass, gem pack and run-shop item (the same square slot).
	ClassKid = "",
	ClassWrapper = "",
	ClassSprinter = "",
	ClassCollector = "",
	ClassHeir = "",
	ClassKrampusKid = "",
	PassDoubleCash = "",
	PassBigShelf = "",
	PassToolKeeper = "",
	PassLucky = "",
	GemsGems100 = "",
	GemsGems500 = "",
	GemsGems1200 = "",
	ShopScissors = "",
	ShopBoxCutter = "",
	ShopChainsaw = "",
	ShopGripTape = "",
	ShopFlashlight = "",
	ShopSpareLid = "",
	ShopLuckyBow = "",
}

-- Particle textures. Placeholders are engine textures every client already has.
Art.particles = {
	fleck = "rbxasset://textures/particles/sparkles_main.dds", -- paper flecks and confetti
	dust = "rbxasset://textures/particles/smoke_main.dds", -- Jack's landing puffs
	sparkle = "rbxasset://textures/particles/sparkles_main.dds", -- gift pop, reveal drift, the landmark's motes
	snow = "rbxasset://textures/particles/smoke_main.dds", -- lobby snowfall (a soft round puff, small and white)
}

-- The final image for `slot`, or nil while the code-drawn placeholder is in use.
function Art.image(slot: string): string?
	local id = Art.images[slot]
	return if id and id ~= "" then id else nil
end

-- Gift icons follow the same rule: `Gift<giftId>` slots are optional; without one the HUD shows the
-- gift's code-built model in a viewport.
function Art.giftImage(giftId: string): string?
	return Art.image(`Gift{giftId}`)
end

return Art
