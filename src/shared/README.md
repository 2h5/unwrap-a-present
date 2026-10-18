# Shared

Code both sides can require. Lives in `ReplicatedStorage.Shared`, so everything here replicates to
the client: no secrets, no server-only rules, no docs modules.

- [Types](Types/Types.luau) — the glossary as Luau types. Names match PLAN.md › Glossary.
- [Config](Config/Config.luau) — every tunable number from [PLAN-TABLES.txt](../../docs/PLAN-TABLES.txt).
  Change a number there and here in the same commit, never inline.
- [Remotes](Remotes/Remotes.luau) — RemoteEvent names. Up = requests, Down = replicated state.
- [Sfx](Sfx/Sfx.luau) — client-side: plays one `Config.Sounds` clip at a position, pitch randomized; preloads all.
- [Rng](Rng/Rng.luau) — seeded xorshift32 (pure): `new(seed)`, `next`, `int`, `weighted`. Seeds are rolled on the server.
- [Gifts](Gifts/Gifts.luau) — the launch gift catalogue (N31): 32 side-gifts in 8 families, 18 core gifts
  by band; `byId`, `displayName(giftId, mutation?)`, `corePool(rarity, tier)`. Names only; Loot rolls.
- Art (Phase 5; every placeholder and its final: [assets.md](../../docs/art/assets.md)):
  - [Art](Art/Art.luau) — the one image registry: `images` slots (empty = code-drawn placeholder),
    `particles`, `image(slot)`, `giftImage(giftId)`.
  - [Patterns](Art/Patterns.luau) — paper patterns and the cardboard print on a part's front face:
    `apply(part, name, repeats?)`, `print`, `copy`, `clear`, `setVisible`, `steps(color)`.
  - [GiftModels](Art/GiftModels.luau) — the 50 launch toys: `build(giftId, rarity, { studs, mutation?, static? })`
    (a Model with an anchored `Root`), `has`, `baseParts`. `ReplicatedStorage.Assets.Gifts` overrides.
  - [ToolModels](Art/ToolModels.luau) — `build(tool, studs)`, `dress(pickup, tool)`; `Assets.Tools` overrides.
  - [Props](Art/Props.luau) — world-tier kit (stock materials): `part`, `trim`, `wedge`, `tree`, `fir`
    (snowy), `bush`, `snow` (soft snow on a top), `bow`, `present`, `lantern(…, lit?)`, `hangingLantern`,
    `bench`, `fence`, `tag` (gift-tag sign), `twine`, `sway`/`pulse` (marks the lobby client animates),
    `applyLighting(name)` (plus the lobby's bloom and clouds), `clearTemplate`.

## Rules

- Invariant 7: a value in Config is a *display* hint on the client. The server re-reads it and decides.
- A number the plan does not state goes into `docs/DECISIONS.md` before it goes into Config.
- Config holds no Roblox types: only numbers, strings, booleans and tables. Colors are hex strings;
  the client converts them with `Color3.fromHex`. This keeps pure-logic modules runnable under
  Lune and command-line Jest-Lua.
- Adding a remote: add the name to `Remotes.Up` or `Remotes.Down`, validate `RunState` first on the
  server handler, and rate-limit anything a player can spam.
