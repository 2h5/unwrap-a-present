# Night

Tick open, Jack AI, line of sight, downs, revives, wipe detection.
Must never: Run in the lobby.

- **Built in:** Phase 4, build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Mechanics C (Tick, Night, Jack, downs and wipes)
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 20 (Night and Jack), Diagram B (run flow), Table 9 (Night length), Table 7 (Flashlight, Spare lid), Table 8 (Sprinter)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Public API

_None yet._ List each public function here as it lands: signature, one line of what it does.

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Must never: Run in the lobby.

## How to add a new one

_Fill in when the first one exists (e.g. how to add a layer type, gift, entity, screen)._
