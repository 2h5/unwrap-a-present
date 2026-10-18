# Tests

Runner: **Lune** (pinned in `rokit.toml`), the approved fallback for Jest-Lua, which needs the Roblox
engine to run (DECISIONS.md, 2026-10-17). Run from the repo root: `lune run tests/run`. Each spec
returns `function(test, expectEqual)` and is listed in [run.luau](run.luau).

Rule: every module under test is pure logic with no Roblox services (`game:GetService` etc.), so tests
run from the command line in every Claude Code run and in CI, not only inside Studio. Keep the Roblox
glue (remotes, parts, sounds) in a thin wrapper around the pure module.

Required automated tests (PLAN.md › Testing and telemetry):

- [x] Nest generation never repeats a type twice in a row and always ends in two lids ([Present/Nest.spec.luau](Present/Nest.spec.luau))
- [ ] Rarity tables sum to 100 per tier
- [x] Panel bitfield round-trips ([Tear/PanelGrid.spec.luau](Tear/PanelGrid.spec.luau))
- [ ] Naughty decay math
- [ ] Profile schema migration from version n-1
- [ ] Present parts at The Package tier ≤ 1,200 (performance budget)

