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
- `Loot.getBag()`, `Loot.onBankDone(fn)` (Present starts the next run until Lobby exists).
- Down `LootEvent`: `Side` (to all: giftId, rarity, to, toUserId, cash), `Core` (per player, with their
  mutation), `Bank` (items with outcome, gems, pending), `BankPending`, `Refused`. Down `ShelfState`
  `{ capacity, items, gems, indexCount }`. Up `BankChoice("Sell", i)`, `("Replace", i, slotIndex)`, `("Done")`.

## Invariants and rules

- Invariant 7: every roll is made once on the server from a server-seeded Rng; the client is told.
- Each cleared layer but the last rolls 1–3 side-gifts (+1 per unused lucky bow) on its band's table;
  each pops, waits 1 s, flies to the nearest player, pays them its cash (N32) and joins the shared bag.
- The last layer is the core lid: CoreLid → Reveal (3 s + 1 s beat) → Bank. First-ever run (any
  player with no completions) rolls the core Uncommon or better. Mutation roll per player (DECISIONS).
- Index records on sight for everyone in the run; the shelf changes only at bank. Every finisher banks
  a copy of the bag and the core (N14). Overflow: sell (gems, N33) or replace; Secrets go to the vault.
- Lucky gamepass is `false` until gamepasses are wired (Phase 3). Shelf capacity is 12 until then.

## How to add a new one

A new gift: add it to its family (side) or band (core) in `Shared/Gifts`; ids are profile keys, so
never rename one. A new gift family: add it to `Gifts.families` and `Config.Loot.families`.
