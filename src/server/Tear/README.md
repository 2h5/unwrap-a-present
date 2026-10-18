# Tear

Panel bitfields per layer, tool and action validation, panel timing, layer-cleared events.
Must never: Trust a client position or timer.

- **Built in:** Phase 0, build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Mechanics A (panels, tools, the Tear feel spec)
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 4 (layer actions, panel grid), Table 5 (tools), Table 15 (TearRequest rate)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Public API

- `Tear.init()` — Phase 0: builds one greybox Paper layer (depth 0, tier 1) as `Workspace.Present`.
- `Tear.getGrid(depth): Grid?` — the panel grid for a layer.
- [PanelGrid.luau](PanelGrid.luau) (pure, tested in `tests/Tear`): `fromLayer(layer, layerStuds, Config.Panels)`,
  `gridPerFace`, `panelId`, `locate`, `isTorn`, `setTorn`, `encode`/`decode` (bitfield as a string),
  `placement(grid, id, size)` (panel centre, normal, width on a cube centred at the origin).
- [TearSession.luau](TearSession.luau) (pure, tested): `new(grid)`, `begin(session, holder, panelId, seconds, now)`
  returns seconds still needed or nil + reason, `release(session, holder, now)` keeps progress or tears,
  `fraction`, `holding`. [RateLimit.luau](RateLimit.luau) (pure, tested): `new(perSecond)`, `allow`, `forget`.

## TearRequest and TearState

- Up `TearRequest("Begin", depth, panelId, u, v)` and `TearRequest("End")`. Rate-limited to
  `Config.Tear.maxRequestsPerSecond`. Begin is refused unless the panel exists, is whole, is not held by
  another player, and is within `Config.Tear.reachStuds` of the server's character position.
- The server times every hold with its own clock and tears the panel when the time is reached; `u, v`
  (the touch point, 0..1 on the panel) only place the rip line, and the first touch point is kept.
- Down `TearState { depth, panelId, state = "Holding" | "Released" | "Torn", progress, seconds, u, v }`
  to every client.

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Must never: Trust a client position or timer.
- One holder per panel, one panel per holder. Early release keeps the seconds already torn.

## How to add a new one

A new panel-grid layer type: add it to `GRID_LAYER_TYPES` in PanelGrid.luau and a spec case in
`tests/Tear/PanelGrid.spec.luau`. Keep Roblox calls out of PanelGrid; they go in Tear.luau.
