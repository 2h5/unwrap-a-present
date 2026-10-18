# Data

ProfileStore profiles, schema version, migration, session lock.
Must never: Store run state.

- **Built in:** Phase 2, build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Mechanics D (data schema); invariant 10; N19, N20, N34
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 10 (data schema)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## ProfileStore (vendored)

[ProfileStore/ProfileStore.luau](ProfileStore/ProfileStore.luau) by loleris (MadStudioRoblox), copied
untouched from commit `45c9847cbcf1fc260369c50eb335aba7c35aecdd` (2025-07-31). Licence: Apache 2.0,
kept beside it in [ProfileStore/LICENSE](ProfileStore/LICENSE). To update: copy the new file and
LICENSE from github.com/MadStudioRoblox/ProfileStore and change the hash here, in one commit.

In Studio without "Enable Studio Access to API Services" ProfileStore runs on a mock: profiles load
and save in memory and are gone when the play session stops. The toggle is a human task (N34).

## Public API

- [Schema.luau](Schema.luau) (pure, tested in `tests/Data`): `VERSION`, `template()`,
  `migrations[n]` (n−1 → n), `migrate(data)` (false for a profile from a newer build), `reconcile`.
- `Data.get(player)` — the profile data table, or nil while loading. Owners edit it in place.
- `Data.onLoaded(fn(player, data))` — every profile that loads, and those already loaded.
- `Data.beforeRelease(fn(player, data))` — on leave, before the profile is saved and released.
- `Data.storeState()` — "Access", "NoAccess", "NoInternet" or "NotReady".

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Invariant 10: a crash or disconnect never loses shelf items, gems or prestige. ProfileStore saves
  on an interval and on leave, and holds a session lock: a second server cannot load the same
  profile until the first releases it.
- Must never: Store run state (RunBag, panel bitfields, Nest, Night timer).
- One store (`Config.Data.storeName`), key `Config.Data.keyPrefix .. UserId`.

## How to add a new one

A new profile field: add it to `Schema.template()`. If old profiles need more than the default,
bump `Schema.VERSION`, append a migration, and add the n−1 case to `tests/Data/Schema.spec.luau`.
Update the data schema in PLAN-TABLES.txt Table 10 in the same commit.
