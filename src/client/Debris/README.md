# Debris

Torn-panel pool, 40 live max, physics, recycle.
Must never: Exceed the budget.

- **Built in:** Phase 0, build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Mechanics A (on release); Art bible B (budgets)
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 5 (feel spec), Table 14 (Tear release VFX), Table 15 (budgets)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Public API

- `Debris.init()` — creates the local `Workspace.Debris` folder.
- `Debris.spawn(panel)` — swaps a torn panel for a piece: impulse away from the present, random spin,
  reduced gravity for `Config.Tear.flutterSeconds`, then it settles (anchored, no collision) and stays
  until recycled. Called by TearInput on `TearState` "Torn".
- `Debris.liveCount()` — live pieces, never above `Config.Tear.maxLiveDebris`.
- [DebrisPool.luau](DebrisPool.luau) (pure, tested in `tests/Debris`): `new(max)`, `acquire` (oldest
  recycled first), `release`, `liveCount`.

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Must never: Exceed the budget.
- Table 14: one mesh per tear. A piece is one part, never an assembly.
- Pieces are local to this client and excluded from TearInput's tap raycast.

## How to add a new one

The torn-edge mesh: import a single MeshPart named `TornPanel` into `ReplicatedStorage.Assets` in
Studio (outside Rojo's synced paths). Debris clones it instead of the greybox stand-in; no code change.
