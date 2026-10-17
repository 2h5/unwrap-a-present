# Economy

Cash, gems, shop, classes, prestige, gamepass checks, daily and group rewards.
Must never: Grant a gift for Robux.

- **Built in:** Phase 3 (Nov 9–15), dates in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Mechanics D
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 7 (shop, cash, gems), Table 8 (classes), Table 9 (prestige), Table 10 (monetization)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Public API

_None yet._ List each public function here as it lands: signature, one line of what it does.

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Must never: Grant a gift for Robux.

## How to add a new one

_Fill in when the first one exists (e.g. how to add a layer type, gift, entity, screen)._
