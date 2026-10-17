# Tests

Runner: **Jest-Lua** (DECISIONS.md, 2026-10-17). Fallback if setup takes more than a day: **Lune** with
plain assertions over the same modules.

Rule: every module under test is pure logic with no Roblox services (`game:GetService` etc.), so tests
run from the command line in every Claude Code run and in CI, not only inside Studio. Keep the Roblox
glue (remotes, parts, sounds) in a thin wrapper around the pure module.

Required automated tests (PLAN.md › Testing and telemetry):

- [ ] Nest generation never repeats a type twice in a row and always ends in two lids
- [ ] Rarity tables sum to 100 per tier
- [ ] Panel bitfield round-trips
- [ ] Naughty decay math
- [ ] Profile schema migration from version n-1
- [ ] Present parts at The Package tier ≤ 1,200 (performance budget)

Setup lands with the first test in Phase 1; the test command then goes into `CLAUDE.md`.
