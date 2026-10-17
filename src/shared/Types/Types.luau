--[=[
	Types (shared)
	Owns: the glossary as Luau types and string enums. Names match PLAN.md › Glossary exactly.
	Must never: hold values or logic. Numbers belong in Config.
	Read first: src/shared/README.md
]=]

export type RunState = "Lobby" | "Building" | "Unwrapping" | "Night" | "CoreLid" | "Reveal" | "Bank" | "Wipe"

export type LayerType = "Paper" | "Ribbon" | "BubbleWrap" | "Foil" | "Chains" | "Ice" | "BoxLid"

-- Tape is an overlay on a layer, never its own layer (DECISIONS.md, 2026-10-17).
export type Overlay = "Tape"

export type TapeStrip = {
	seamIndex: number,
	cut: boolean,
}

export type Action = "Tear" | "Cut" | "Snip" | "Pop" | "Chip" | "Lift"

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Mythic" | "Secret"

-- Tier is prestige only (1 Birthday … 4 The Package, then repeats). Tools use Grade.
export type Tier = "Birthday" | "Christmas" | "Wedding" | "ThePackage"

export type Grade = number -- 0 hands, 1 scissors, 2 box cutter, 3 chainsaw

export type Mutation = "Giant" | "Golden" | "Frosted" | "Glitched"

export type Layer = {
	layerType: LayerType,
	depth: number,
	isTick: boolean,
	tapeStrips: { TapeStrip }?,
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
