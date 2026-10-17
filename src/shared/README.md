# Shared

Code both sides can require. Lives in `ReplicatedStorage.Shared`, so everything here replicates to
the client: no secrets, no server-only rules, no docs modules.

- [Types](Types/Types.luau) — the glossary as Luau types. Names match PLAN.md › Glossary.
- [Config](Config/Config.luau) — every tunable number from [PLAN-TABLES.txt](../../docs/PLAN-TABLES.txt).
  Change a number there and here in the same commit, never inline.
- [Remotes](Remotes/Remotes.luau) — RemoteEvent names. Up = requests, Down = replicated state.

## Rules

- Invariant 7: a value in Config is a *display* hint on the client. The server re-reads it and decides.
- A number the plan does not state goes into `docs/DECISIONS.md` before it goes into Config.
- Config holds no Roblox types: only numbers, strings, booleans and tables. Colors are hex strings;
  the client converts them with `Color3.fromHex`. This keeps pure-logic modules runnable under
  Lune and command-line Jest-Lua.
- Adding a remote: add the name to `Remotes.Up` or `Remotes.Down`, validate `RunState` first on the
  server handler, and rate-limit anything a player can spam.
