# Shelf

Lobby shelf rendering, steal prompt and 6-second timer display.
Must never: Move an item.

- **Built in:** Phase 6, build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Mechanics B (Shelf); Mechanics C (Steal)
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 6 (shelf slot sizes), Diagram D (shelf row), Table 14 (Steal success VFX)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Public API

_None yet._ List each public function here as it lands: signature, one line of what it does.

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Must never: Move an item.

## How to add a new one

_Fill in when the first one exists (e.g. how to add a layer type, gift, entity, screen)._
