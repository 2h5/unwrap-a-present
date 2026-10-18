# Shelf

Lobby shelf rendering, steal prompt and 6-second timer display.
Must never: Move an item.

- **Built in:** Phase 3 (shelf row drawing, porch decoration), Phase 6 (steal), build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Mechanics B (Shelf); Mechanics C (Steal)
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 6 (shelf slot sizes), Table 21 (steal hold, Naughty glow), Diagram D (shelf row), Table 14 (Steal success VFX)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Public API

- `Shelf.init()` — lobby place only. Draws every board in `Workspace.Lobby.Shelves` from its attributes
  (Items JSON, Capacity, OwnerName): one block per item by slot, 6 slots a row, rarity colour, name and
  ×count on the front, Secret sweeping its hue. Puts this player's tier decoration on the porch
  (Table 9: balloons at Birthday, a tree from Christmas), from `ProfileState.tier`.

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Must never: Move an item.

## How to add a new one

_Fill in when the first one exists (e.g. how to add a layer type, gift, entity, screen)._
