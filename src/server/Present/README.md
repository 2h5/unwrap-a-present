# Present

Seed, Nest generation, layer table, Tick placement.
Must never: Be called by the client.

- **Built in:** Phase 1, build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Mechanics A (present generation)
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 4 (layer table), Diagram C (cross-section), Table 9 (layers per tier)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Public API

- `Present.init()` — until Lobby and Data exist (Phase 3), runs Birthday presents back to back.
- `Present.startRun(tier, seed?)` — Nest, `Nest.tape`, `Nest.sizes`, `Economy.resetRun`, `Tear.loadNest`.
  Studio only: Workspace attribute `NextSeed` replays a seed on the next run.
- `Present.newNest(tier, seed?): Nest` — builds the run's Nest from a server-rolled seed (or a given one).
- `Present.getNest(): Nest?` — the current run's Nest.
- [Nest.luau](Nest.luau) (pure, tested in `tests/Present`): `generate(seed, tier, config, Rng)`, `tape(...)`, `sizes(...)`, `band`.

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Must never: Be called by the client.
- The featured present modifier is chosen by the UTC calendar date, so every server shows the same
  one (N12). UTC midnight is 7–8 pm Eastern.
- Nest: tier sets the count; depth 0 is Paper (N26); other layers are picked by band weight from the
  build's layer types (`Config.LaunchLayerTypes`, in order); a type never follows itself; one BoxLid is
  guaranteed in the middle third (N27); the last two are BoxLid. Same seed and tier, same Nest.
- `Nest.sizes(nest, presentStuds, coreBoxStuds)`: shells shrink evenly; a ribbon takes the size of the
  layer it wraps (N29, N30).
- `Nest.tape(..., Rng, tierNumber?)`: paper tape from the seed; from tier 2 every BoxLid gets one strip
  per side across its seam (N36).

## How to add a new one

A new layer type: give it weights in `Config.LayerTable` and add it to `Config.LaunchLayerTypes`
(PLAN-TABLES Table 4 and Table 16 in the same commit). Nest picks it up; the specs cover all 7 types.
