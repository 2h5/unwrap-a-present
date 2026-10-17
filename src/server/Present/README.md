# Present

Seed, Nest generation, layer table, Tick placement.
Must never: Be called by the client.

- **Built in:** Phase 1, build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Mechanics A (present generation)
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 4 (layer table), Diagram C (cross-section), Table 9 (layers per tier)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Public API

_None yet._ List each public function here as it lands: signature, one line of what it does.

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Must never: Be called by the client.

## How to add a new one

_Fill in when the first one exists (e.g. how to add a layer type, gift, entity, screen)._
