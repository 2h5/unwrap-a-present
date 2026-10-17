# Lobby

Start pads, party of up to 4, teleport to run place, booths, lobby night clock.
Must never: Hold any loot or cash logic.

- **Built in:** Phase 3, build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Player journey; Art bible B
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 2 (player journey), Diagram D (lobby plan), Table 19 (keeping players playing)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Public API

_None yet._ List each public function here as it lands: signature, one line of what it does.

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Must never: Hold any loot or cash logic.

## How to add a new one

_Fill in when the first one exists (e.g. how to add a layer type, gift, entity, screen)._
