# Steal

Shelf tear timers, Naughty meter and decay, Krampus walk and sack.
Must never: Touch Secret items or a player below Naughty 8.

- **Built in:** Phase 6, build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Mechanics C (Steal, Naughty, Krampus)
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 21 (Steal, Naughty, Krampus), Diagram D (Krampus walk down the shelf gallery lane), Table 8 (Krampus's Kid)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Public API

_None yet._ List each public function here as it lands: signature, one line of what it does.

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Must never: Touch Secret items or a player below Naughty 8.
- The Krampus clock runs per lobby server (N12); Krampus never enters a run.

## How to add a new one

_Fill in when the first one exists (e.g. how to add a layer type, gift, entity, screen)._
