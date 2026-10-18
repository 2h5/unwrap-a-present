# Present

Seed, Nest generation, layer table, Tick placement.
Must never: Be called by the client.

- **Built in:** Phase 1, build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Mechanics A (present generation)
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 4 (layer table), Diagram C (cross-section), Table 9 (layers per tier)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Public API

- `Present.init()` — until Lobby and Data exist (Phase 3), rolls one Birthday Nest per server and prints it.
- `Present.newNest(tier, seed?): Nest` — builds the run's Nest from a server-rolled seed (or a given one).
- `Present.getNest(): Nest?` — the current run's Nest.
- [Nest.luau](Nest.luau) (pure, tested in `tests/Present`): `generate(seed, tier, config, Rng)`, `band(depth, n)`.

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Must never: Be called by the client.
- The featured present modifier is chosen by the UTC calendar date, so every server shows the same
  one (N12). UTC midnight is 7–8 pm Eastern.
- Nest: tier sets the count; each layer is picked by its band weight from the build's layer types
  (`Config.LaunchLayerTypes`, in that order); a type never follows itself; the last two are BoxLid and
  are exempt from the no-repeat rule. Same seed and tier always give the same Nest.

## How to add a new one

A new layer type: give it weights in `Config.LayerTable` and add it to `Config.LaunchLayerTypes`
(PLAN-TABLES Table 4 and Table 16 in the same commit). Nest picks it up; the specs cover all 7 types.
