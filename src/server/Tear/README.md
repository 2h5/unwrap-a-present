# Tear

Panel bitfields per layer, tool and action validation, panel timing, layer-cleared events.
Must never: Trust a client position or timer.

- **Built in:** Phase 0, build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Mechanics A (panels, tools, the Tear feel spec)
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 4 (layer actions, panel grid), Table 5 (tools), Table 15 (TearRequest rate)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Public API

_None yet._ List each public function here as it lands: signature, one line of what it does.

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Must never: Trust a client position or timer.

## How to add a new one

_Fill in when the first one exists (e.g. how to add a layer type, gift, entity, screen)._
