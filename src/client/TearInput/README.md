# TearInput

Hold detection, rip-line preview, TearRequest.
Must never: Decide that a panel is gone.

- **Built in:** Phase 0, build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Mechanics A (the Tear feel spec)
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 5 (tools, feel spec), Table 13 (Tool hold ring)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Public API

_None yet._ List each public function here as it lands: signature, one line of what it does.

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Must never: Decide that a panel is gone.

## How to add a new one

_Fill in when the first one exists (e.g. how to add a layer type, gift, entity, screen)._
