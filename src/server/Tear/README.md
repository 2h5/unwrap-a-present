# Tear

Panel bitfields per layer, tool and action validation, panel timing, layer-cleared events.
Must never: Trust a client position or timer.

- **Built in:** Phase 0–1, build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Mechanics A (present, ribbon, tape, panels, tools, the Tear feel spec)
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 4 (layer table, panels, tape), Table 5 (tools, Tear numbers), Table 12 (palette), Table 15 (TearRequest rate)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Public API

- `Tear.loadNest(nest, sizes, tierNumber, base)` — replaces `Workspace.Present` with the run's layers
  (Present → Tear). Builds the current layer, the one inside it, and the layer a ribbon wraps.
- `Tear.onLayerCleared(fn(depth, layerType))`, `Tear.onRunComplete(fn())` — listeners (Loot in Phase 2).
- `Tear.getModel(depth): Model?` — a layer's LayerModel.
- Pure, tested in `tests/Tear`: [PanelGrid](PanelGrid.luau) (`gridPerFace(layerStuds)`, bitfield,
  `faceAxes`, `TOP`/`BOTTOM`), [LayerModel](LayerModel.luau) (`build`, `canStart`, `remaining`,
  `isCleared`, `dropBottom`), [LayerGeometry](LayerGeometry.luau) (`place`, `walls`),
  [TearSession](TearSession.luau), [LidSession](LidSession.luau), [Tools](Tools.luau) (`best`),
  [RateLimit](RateLimit.luau).

## Remotes

- Up `TearRequest("Begin", depth, panelId, u, v)` / `("End")` for panels, tape, ribbon; Up
  `LidLift("Begin", depth, panelId)` / `("End")` for box lids. Both rate-limited.
- Begin is refused unless: depth is the current layer, the item exists, it is not on the floor, every
  tape strip touching it is cut, the player's tools can do its action (`Tools.best`), and the panel is
  within max(`Config.Tear.reachMinStuds`, present studs + `reachPadStuds`) of the server's character
  position (N37).
- Down `TearState { depth, panelId, state, progress, seconds, u, v }` to everyone; state is
  "Holding" | "Released" | "Torn" | "Lifted". To one player: `{ state = "Refused", reason }`
  ("Needs scissors", "Cut the tape first", "Needs 2 players").

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Must never: Trust a client position or timer. Holds are timed on the server clock.
- One holder per panel, one panel per holder; early release keeps progress. Lids take
  `LidSession.requiredHolders` (two from tier 2, never more than the players present). From tier 2 a
  lid carries four tape strips (N36) and refuses "Cut the tape first" until all are cut.
- A layer clears when everything off the floor is done; its floor items drop with it. Then depth
  advances (`Present` attribute `CurrentDepth`), the next layers build, and cleared parts are
  destroyed after `Config.Tear.flutterSeconds`.
- Lifted lids become upright props (`Workspace.LidProps`) round the present, for the Night; the box
  walls go. The scissors pickup spawns when depth 0 clears (N26) and gives every player who touches it
  `Tool_Scissors`. Tools and upgrades are player attributes set by Economy or the pickup.
- Each finished item pays `Economy.cashPerPanel(tier)` to the player(s) who finished it.
- Greybox: server Parts (DECISIONS.md); real meshes come in Phase 5.

## How to add a new one

A new layer type: add a builder in LayerModel (items, action, grade, blockers), its shape in
LayerGeometry, a spec in `tests/Tear/Layer.spec.luau`, and its colors in `Config.Palette`.
