--[=[
	Gifts (shared)
	Owns: the launch gift catalogue (N31): 32 side-gifts in 8 families of 4, and 18 core gifts, 3 per
	rarity band. Display names for the HUD; ids for the profile. Generic objects only: no brands, no
	characters (invariant 2).
	Rules: a side-gift's rarity is its own roll, so a side-gift entry has no rarity. A core gift is
	tied to its band. A Secret core gift is one per tier; a tier without its own Secret yet uses any.
	Must never: hold odds or prices (Config) or roll anything (Loot rolls on the server).
	Read first: src/shared/README.md
]=]

export type SideGift = { id: string, name: string, family: string }
export type CoreGift = { id: string, name: string, rarity: string, tier: string? }

local Gifts = {}

Gifts.families = { "plush", "vehicle", "figure", "candy", "trinket", "tech", "odd", "seasonal" }

Gifts.side = {
	plush = {
		{ id = "PlushBear", name = "Plush bear" },
		{ id = "PlushBunny", name = "Plush bunny" },
		{ id = "PlushWhale", name = "Plush whale" },
		{ id = "PlushDragon", name = "Plush dragon" },
	},
	vehicle = {
		{ id = "ToyTruck", name = "Toy truck" },
		{ id = "ToyPlane", name = "Toy plane" },
		{ id = "ToyBoat", name = "Toy boat" },
		{ id = "ToyTrain", name = "Toy train" },
	},
	figure = {
		{ id = "ToySoldier", name = "Toy soldier" },
		{ id = "ToyKnight", name = "Toy knight" },
		{ id = "ToyAstronaut", name = "Toy astronaut" },
		{ id = "ToyDinosaur", name = "Toy dinosaur" },
	},
	candy = {
		{ id = "CandyCane", name = "Candy cane" },
		{ id = "Lollipop", name = "Lollipop" },
		{ id = "Gumdrop", name = "Gumdrop" },
		{ id = "ChocolateCoin", name = "Chocolate coin" },
	},
	trinket = {
		{ id = "Marble", name = "Marble" },
		{ id = "Keychain", name = "Keychain" },
		{ id = "SpinningTop", name = "Spinning top" },
		{ id = "MusicBox", name = "Music box" },
	},
	tech = {
		{ id = "WalkieTalkie", name = "Walkie-talkie" },
		{ id = "ToyCamera", name = "Toy camera" },
		{ id = "PocketGame", name = "Pocket game" },
		{ id = "Calculator", name = "Calculator" },
	},
	odd = {
		{ id = "RubberDuck", name = "Rubber duck" },
		{ id = "WhoopeeCushion", name = "Whoopee cushion" },
		{ id = "WindUpTeeth", name = "Wind-up teeth" },
		{ id = "LuckyRock", name = "Lucky rock" },
	},
	seasonal = {
		{ id = "Bauble", name = "Bauble" },
		{ id = "JingleBell", name = "Jingle bell" },
		{ id = "PartyHat", name = "Party hat" },
		{ id = "PaperCrown", name = "Paper crown" },
	},
}

-- Examples from PLAN-TABLES Table 6 become the core gifts. Secrets are lore items (docs/LORE.md);
-- The Package's own Secret ships with The Package tier.
Gifts.core = {
	Common = {
		{ id = "Sock", name = "Sock" },
		{ id = "Mug", name = "Mug" },
		{ id = "PaperclipBox", name = "Box of paperclips" },
	},
	Uncommon = {
		{ id = "YoYo", name = "Yo-yo" },
		{ id = "ModelCar", name = "Model car" },
		{ id = "SnowGlobe", name = "Snow globe" },
	},
	Rare = {
		{ id = "Robot", name = "Robot" },
		{ id = "Guitar", name = "Guitar" },
		{ id = "TinyTree", name = "Tiny tree" },
	},
	Epic = {
		{ id = "GoKart", name = "Go-kart" },
		{ id = "ArcadeCabinet", name = "Arcade cabinet" },
		{ id = "PuppyCrate", name = "Puppy crate" },
	},
	Mythic = {
		{ id = "GoldenGoose", name = "Golden goose" },
		{ id = "Rocket", name = "Rocket" },
		{ id = "JacksBox", name = "The Jack's own box" },
	},
	Secret = {
		{ id = "BlankGiftTag", name = "Blank gift tag", tier = "Birthday" },
		{ id = "WaxSealedEnvelope", name = "Wax-sealed envelope", tier = "Christmas" },
		{ id = "BrassKey", name = "Brass key", tier = "Wedding" },
	},
}

-- id -> { name, kind = "Side" | "Core", family?, rarity? }
Gifts.byId = {}
for family, list in Gifts.side do
	for _, gift in list do
		gift.family = family
		Gifts.byId[gift.id] = { name = gift.name, kind = "Side", family = family }
	end
end
for rarity, list in Gifts.core do
	for _, gift in list do
		gift.rarity = rarity
		Gifts.byId[gift.id] = { name = gift.name, kind = "Core", rarity = rarity, tier = gift.tier }
	end
end

-- A display name, with the mutation in front when there is one ("Golden Robot").
function Gifts.displayName(giftId: string, mutation: string?): string
	local gift = Gifts.byId[giftId]
	local name = if gift then gift.name else giftId
	return if mutation and mutation ~= "" then `{mutation} {name}` else name
end

-- The core gifts a `rarity` roll at `tier` can give: a Secret is the tier's own when it has one.
function Gifts.corePool(rarity: string, tier: string): { CoreGift }
	local list = Gifts.core[rarity]
	if rarity ~= "Secret" then
		return list
	end
	local own = {}
	for _, gift in list do
		if gift.tier == tier then
			table.insert(own, gift)
		end
	end
	return if #own > 0 then own else list
end

return Gifts
