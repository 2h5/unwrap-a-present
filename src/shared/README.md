# Shared

Code both sides can require. Lives in `ReplicatedStorage.Shared`, so everything here replicates to
the client: no secrets, no server-only rules, no docs modules.

- [Types](Types/Types.luau) — the glossary as Luau types. Names match PLAN.md › Glossary.
- [Config](Config/Config.luau) — every tunable number from the plan. Change a number here, not inline.
- [Remotes](Remotes/Remotes.luau) — RemoteEvent names. Up = requests, Down = replicated state.

## Rules

- Invariant 7: a value in Config is a *display* hint on the client. The server re-reads it and decides.
- A number the plan does not state goes into `docs/DECISIONS.md` before it goes into Config.
- Adding a remote: add the name to `Remotes.Up` or `Remotes.Down`, validate `RunState` first on the
  server handler, and rate-limit anything a player can spam.
