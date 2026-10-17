--[=[
	Types (shared)
	Owns: the glossary as Luau types and string enums. Names match PLAN.md › Glossary exactly.
	Must never: hold values or logic. Numbers belong in Config.
	Read first: src/shared/README.md
]=]

export type RunState = "Lobby" | "Building" | "Unwrapping" | "Night" | "CoreLid" | "Reveal" | "Bank" | "Wipe"

export type LayerType = "Paper" | "Tape" | "Ribbon" | "BubbleWrap" | "Foil" | "Chains" | "Ice" | "BoxLid"

export type Action = "Tear" | "Cut" | "Snip" | "Pop" | "Chip" | "Lift"

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Mythic" | "Secret"

export type Tier = "Birthday" | "Christmas" | "Wedding" | "ThePackage"

export type Mutation = "Giant" | "Golden" | "Frosted" | "Glitched"

export type Layer = {
	layerType: LayerType,
	depth: number,
	isTick: boolean,
}

export type Nest = {
	seed: number,
	tier: Tier,
	layers: { Layer },
}

export type ShelfItem = {
	giftId: string,
	rarity: Rarity,
	mutation: Mutation?,
	slotIndex: number,
}

export type IndexEntry = {
	count: number,
	firstDepth: number,
	firstSeenAt: number,
}

return {}
