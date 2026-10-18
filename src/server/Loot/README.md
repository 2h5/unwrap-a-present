# Loot

Rarity rolls, side-gift spawn, RunBag, core gift, Bank, Index, Shelf state.
Must never: Roll on the client or re-roll on request.

- **Built in:** Phase 2, build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Mechanics B
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 6 (rarity, with the Christmas and Wedding odds rows; Table 9 loot shift is history, N3)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Public API

- [Rarity.luau](Rarity.luau) (pure, tested in `tests/Loot`): `sideOdds(config, tier, band)`,
  `rollSide(rng, config, tier, band, lucky, Rng)`, `rollCore(rng, config, tier, firstRun, Rng)` (no luck
  parameter: invariant 6), `rollMutation(rng, config, rarity, duplicate, Rng)`, `sum`, `rank`.

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Must never: Roll on the client or re-roll on request.
- Odds per tier come straight from `Config.RarityOdds` (all four tiers filled in; tier shifts came from
  Common, N3). There is no shift rule to apply at runtime.
- The Package's inner third: its own table with Secret at 2%, the extra 1% taken from Common (as N3).
- Rolls happen on the server from a server-seeded Rng, once per gift; nothing re-rolls on request.

## How to add a new one

_Fill in when the first one exists (e.g. how to add a layer type, gift, entity, screen)._
