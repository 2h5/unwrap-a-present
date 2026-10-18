# Unwrap A Present

A 1–4 player co-op Roblox run: tear through a house-sized, nested present to find out what is inside.

- **Plan:** [docs/PLAN.md](docs/PLAN.md) — source for every rule
- **Tables and diagrams:** [docs/PLAN-TABLES.txt](docs/PLAN-TABLES.txt) — source for every number
- **Visual direction and reference images:** [docs/art/bible.md](docs/art/bible.md) — read before Phase 5 art, environment or UI work
- **Kickoff notes:** [docs/KICKOFF.md](docs/KICKOFF.md)
- **Decisions:** [docs/DECISIONS.md](docs/DECISIONS.md)
- **For Claude Code runs:** [CLAUDE.md](CLAUDE.md)

## Setup

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then in this folder run `rokit install`
   (installs the pinned Rojo version from `rokit.toml`).
2. In Roblox Studio, install the **Rojo** plugin (Plugins → Manage Plugins, or `rojo plugin install`).
3. In VS Code, install the recommended extensions (Rojo, Luau LSP, StyLua).
4. Run `rojo serve`, open a place in Studio, click **Connect** in the Rojo plugin.

Code in `src/` now live-syncs into Studio. Edit code in VS Code, build the world in Studio.

## Layout

```
src/server/   → ServerScriptService.Server      Present Tear Loot Night Steal Economy Lobby Data
src/shared/   → ReplicatedStorage.Shared        Types Config Remotes
src/client/   → StarterPlayerScripts.Client     TearInput Debris HUD Shelf
docs/         → Obsidian vault (Markdown + PNG; never synced into the place)
tests/        → automated tests
```
