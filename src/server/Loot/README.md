# Loot

Rarity rolls, side-gift spawn, RunBag, core gift, Bank, Index, Shelf state.
Must never: Roll on the client or re-roll on request.

- **Built in:** Phase 2, build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Mechanics B; N14, N31–N33; bank rules in DECISIONS.md
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 6 (rarity, sell rates), Table 7 (side-gift cash), Table 5 (greybox loot)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline
- **Gift names:** [Shared/Gifts](../../shared/Gifts/Gifts.luau)

## Public API

- [Rarity.luau](Rarity.luau) (pure, `tests/Loot`): `sideOdds`, `rollSide(rng, config, tier, band, lucky, Rng)`,
  `rollCore(rng, config, tier, firstRun, Rng)` (no luck parameter: invariant 6), `rollMutation`, `sum`, `rank`.
- [Shelf.luau](Shelf.luau) (pure): `place(shelf, gift, capacity, config)` → "stacked" / "placed" / "full",
  `preview`, `freeRun`, `usedSlots`, `removeAt`.
- [Index.luau](Index.luau) (pure): `key(giftId, mutation?)`, `record(index, key, depth, now, rarity?, order?)`, `has`.
- [Bank.luau](Bank.luau) (pure): `runGems(config, downs, tickSurvived, belowHighestTier)`, `sellGems(rates, rarity, count?)`.
- `Loot.startRun(nest, tierNumber)` (Present) — empty shared RunBag, fresh server seed; `stats.runs` +1.
- `Loot.getBag()`, `Loot.onBankDone(fn)` — the run is over (bank done, or a wipe's screen shown); Present
  sends the party to the lobby or starts the next run.
- Night → Loot: `tickOpened(depth)` (the Tick's side-gifts: `Config.Tick.sideGifts` from the inner-third
  table), `noteDown()`, `noteTickSurvived()`, `removeCommon()` (solo auto-revive), `wipe()` (bag lost,
  `stats.wipes`, `LootEvent Wipe`, run over after `Config.Night.wipeScreenSeconds`).
- Look (Phase 5): every gift in `Workspace.Gifts` is its toy model ([Shared/Art/GiftModels](../../shared/Art/GiftModels.luau),
  attributes `GiftId`, `Rarity`; core: `Kind = "Core"`) with a rarity glow and a trail lit during the
  0.8 s arc. The core rises out of its box; Mythic spins and bobs. Pop, shaft, drift, sting and the Secret
  sweep are drawn by the client (HUD LootView). Placeholder models: [assets.md](../../../docs/art/assets.md).
- Down `LootEvent`: `Side` (to all: giftId, rarity, to, toUserId, cash), `Core` (per player, with their
  mutation), `Bank` (items with outcome, gems, pending), `BankPending`, `Refused`, `Lost` (giftId,
  rarity), `Wipe` (seconds). Down `ShelfState`
  `{ capacity, items, gems, indexCount }`. Up `BankChoice("Sell", i)`, `("Replace", i, slotIndex)`, `("Done")`.

## Invariants and rules

- Invariant 7: every roll is made once on the server from a server-seeded Rng; the client is told.
- Each cleared layer but the last rolls 1–3 side-gifts (+1 per unused lucky bow) on its band's table;
  each pops, waits 1 s, flies to the nearest player, pays them its cash (N32) and joins the shared bag.
- The last layer is the core lid: CoreLid → Reveal (3 s + 1 s beat) → Bank. First-ever run (any
  player with no completions) rolls the core Uncommon or better. Mutation roll per player (DECISIONS).
- Index records on sight for everyone in the run; the shelf changes only at bank. Every finisher banks
  a copy of the bag and the core (N14). Overflow: sell (gems, N33) or replace; Secrets go to the vault.
- Lucky: any player in the run owning the pass makes side-gifts roll twice (party-wide, non-stacking).
- Bank gems use the run's downs and Tick (8 Tick survived, 5 no downs, 3 completed); a survived Tick
  adds `stats.ticksSurvived`.

## How to add a new one

A new gift: add it to its family (side) or band (core) in `Shared/Gifts`; ids are profile keys, so
never rename one. A new gift family: add it to `Gifts.families` and `Config.Loot.families`.
