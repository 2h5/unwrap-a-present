# CLAUDE.md — Unwrap A Present

Roblox game, Rojo + git. The plan is [docs/PLAN.md](docs/PLAN.md); every table and diagram is in
[docs/PLAN-TABLES.txt](docs/PLAN-TABLES.txt); the decisions log is
[docs/DECISIONS.md](docs/DECISIONS.md). Do not repeat plan content here.

**PLAN-TABLES.txt is the source for every number; PLAN.md is the source for every rule.** Do not try
to reconcile the two. If a number disagrees, PLAN-TABLES.txt wins.

## Run protocol (verbatim from PLAN.md)

1. Read, in order: How to use this plan, North Star, Invariants, Glossary. Then the current phase in
   Production roadmap and its acceptance criteria. Then only the mechanic or art sections that phase
   names. Skip everything else.
2. Before writing code, state in one line which acceptance criterion this run is closing. One run
   closes one criterion or fixes one bug. No run closes two phases.
3. If the work would touch an invariant, stop. Write a proposed decision in the decisions log with the
   reason, and end the run. A human approves it in the next run.
4. After the code: run that phase's test checklist, update the system README the code lives in, add
   one line to CHANGELOG, tick the criterion in the roadmap.
5. Last message of the run is three lines: what closed, what is half-done with file paths, what the
   next run should do first.
6. Never paste whole scripts into the plan or a README. Link to the file. A README over its line cap
   is split, never grown.

Drift check every fifth run or once a week: no features; re-read North Star, list anything built that
the plan does not describe, check Art bible B budgets, play one full run on a phone-sized viewport.

## Read order

1. `docs/PLAN.md` — first four sections in full, then the current phase only.
2. `docs/PLAN-TABLES.txt` — only the tables the system README lists under **Numbers**.
3. `docs/DECISIONS.md` — anything **Proposed** waiting on a human.
4. The `README.md` inside the system folder you are touching (`src/server/<System>/`, etc.).

Current phase: **Phase 0 — Tear greybox**, then Gate A (build order: PLAN-TABLES.txt Diagram E). No fixed dates.

## Layout

- `default.project.json` is the **run place**. The lobby place gets its own project file in Phase 3
  (two places; pads teleport parties into private reserved run servers).
- `src/server/` → ServerScriptService.Server (8 systems, each a folder with `README.md`)
- `src/shared/` → ReplicatedStorage.Shared (`Types`, `Config`, `Remotes`)
- `src/client/` → StarterPlayer.StarterPlayerScripts.Client (4 systems)
- `tests/` — Jest-Lua tests over pure-logic modules (no Roblox services), runnable from the command line

## Conventions

- Glossary words only (PLAN.md › Glossary). Invent no synonyms.
- Every script starts with a `--[=[ ]=]` header, max 15 lines: what it owns, what it must never do,
  which README to read first.
- System `README.md` cap: 80 lines. Purpose in two lines, public API, invariants, how to add a thing.
- Server folders also carry a `README.luau` pointer (one line of purpose + path). Client and shared
  folders do not — docs never replicate to the client.
- A README describing deleted code is deleted in the same commit.
- Numbers come from PLAN-TABLES.txt and live in `src/shared/Config`, never inline. Changing a number
  means changing PLAN-TABLES.txt and Config in the same commit.

## Commands

```bash
rojo serve            # live-sync to Studio (connect with the Rojo plugin)
rojo build -o UnwrapAPresent.rbxlx
rojo sourcemap -o sourcemap.json   # for luau-lsp
```

Test command: set up with the first test in Phase 0 (Jest-Lua; fallback Lune). Pure-logic modules only,
so tests run without Studio.
