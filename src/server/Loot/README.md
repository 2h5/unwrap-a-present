# Loot

Rarity rolls, side-gift spawn, RunBag, core gift, Bank, Index, Shelf state.
Must never: Roll on the client or re-roll on request.

- **Built in:** Phase 2, build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Mechanics B
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 6 (rarity), Table 9 (loot shift per tier)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Public API

_None yet._ List each public function here as it lands: signature, one line of what it does.

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Must never: Roll on the client or re-roll on request.
- Odds per tier come straight from `Config.RarityOdds` (all four tiers filled in; tier shifts came from
  Common, N3). There is no shift rule to apply at runtime.

## How to add a new one

_Fill in when the first one exists (e.g. how to add a layer type, gift, entity, screen)._
