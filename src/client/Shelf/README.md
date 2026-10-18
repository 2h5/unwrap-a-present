# Shelf

Lobby shelf rendering, steal prompt and 6-second timer display.
Must never: Move an item.

- **Built in:** Phase 3 (shelf drawing, porch decoration), Phase 5 (lobby ambience), Phase 6 (steal), build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Mechanics B (Shelf); Mechanics C (Steal)
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 6 (shelf slot sizes), Table 21 (steal hold, Naughty glow), Diagram D (shelf gallery), Table 9 (tier decoration), Table 14 (Steal success VFX, lobby ambience)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Public API

- `Shelf.init()` — lobby place only. Draws every board in `Workspace.Lobby.Shelves` from its attributes
  (Items JSON, Capacity, OwnerName), in the board's own frame (items on its +X side, so both rows of
  the shelf gallery face the lane): planks per row, 6 slots a row; each item is its toy model
  (`Shared/Art/GiftModels`, static) on a rarity-coloured plate with a ×count badge; Secret sweeps its
  hue and Mythic toys turn. The owner's name hangs on a gift tag. Puts this player's tier decoration on
  the porch (Table 9: balloons on twine at Birthday; a tree with a star, porch lights and a wreath on
  the cottage door from Christmas; snow is everyone's), from `ProfileState.tier`. Toy placeholders and
  finals: [assets.md](../../../docs/art/assets.md).
- [Ambience.luau](Ambience.luau) `init()` — lobby place only, started by `Shelf.init`: snowfall from one
  emitter that follows the camera, up to 3 drifting paper scraps (patterns drawn by Debris/PaperLook),
  swings models tagged `Sway` (attributes `SwayHinge`, `SwayAxis`, `SwayDegrees`) with one bulk move a
  frame, and breathes parts tagged `Pulse` (`PulseLow`, `PulseHigh`) and any light in them. Numbers:
  `Config.Lobby.ambience`, PLAN-TABLES Table 14's lobby line. Adds no lights.

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Must never: Move an item.

## How to add a new one

_Fill in when the first one exists (e.g. how to add a layer type, gift, entity, screen)._
