# Lobby

Start pads, party of up to 4, teleport to run place, booths, lobby night clock.
Must never: Hold any loot or cash logic.

- **Built in:** Phase 3, build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E; Phase 5 look rebuilt as Unwrapping Plaza (2026-10-18)
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Player journey; Art bible B; N9–N11, N13, N19, P12; DECISIONS "Lobby revamp" (supersedes the old field layout)
- **Visual direction:** [art bible](../../../docs/art/bible.md), "The lobby: Unwrapping Plaza"; never restore the old fenced field
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 2 (player journey), Diagram D (lobby plan, revised), Table 9 (tier decoration), Table 14 (lobby ambience), Table 19 (keeping players playing)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau) (`Config.Lobby`, `Config.Lighting.Lobby`), never inline

## Two places, one codebase

`lobby.project.json` builds the lobby place (Workspace attribute `PlaceKind = "Lobby"`);
`default.project.json` builds the run place (no attribute). `Main.server.luau` boots the lobby's
systems (Data, Economy, Loot, Steal, Lobby) or the run's. Place ids live in `Config.Places`. In Studio
(which cannot teleport), or while an id is 0, everything falls back to local play: pads say so and the
run place loops runs. To try the lobby in Studio, set Workspace `PlaceKind` to "Lobby" before Play.
The whole lobby, terrain included, is built by code at server start; nothing is saved in the place.

## Public API

- [Party.luau](Party.luau) (pure, `tests/Lobby`): `fromPad(host, standing, isFriend, max)`, `newQueue`,
  `join`, `leave`, `waitLeft`, `take(queue, now, max, wait)`, `admits(members, userId)`.
- [Field.luau](Field.luau): `build()` returns `{ pads, booths, porch, shelves, board, folder }`; builds
  the spawn (`LobbySpawn` on a dais south of centre, facing north) and the three pads (`Pad1`–`Pad3`
  with rims that breathe and tags whose SurfaceGui is the pad's `Label`), then calls the builders.
  `shelfSpot(i)` returns a CFrame (+X out of the shelf's front), `dressShelf(model, board)` dresses a
  mirrored shelf in its own frame, `label` (a wooden chip), `prompt`.
- [Village.luau](Village.luau): terrain snow, the plaza and ribbon inlay, the terrace ring, the shelf
  gallery (`shelfSpot`), the cottage (`House`, its `Porch` and `PorchBeam` by name for Shelf), backdrop.
- [Landmark.luau](Landmark.luau): the giant half-unwrapped present and its terrace; decoration only.
- [Pavilions.luau](Pavilions.luau): Rewards, Classes and Shop (counters `RewardsBooth`, `ClassesBooth`,
  `ShopBooth`), the live odds board, the update board, present stacks; `frame(bearing, distance)`.
- Swaying tags, bunting and ribbon carry `Props.sway` marks; rims and the landmark's glow `Props.pulse`;
  the client Shelf system's [Ambience](../../client/Shelf/Ambience.luau) animates them.
- `Lobby.waitForParty()` (run place) — yields until the party is here or `arrivalWaitSeconds` pass;
  returns the run's tier name, or nil in local play. `Lobby.runEnded()` — after the bank, sends
  everyone to the lobby; false in local play. `Lobby.isLobby()`.
- Up `LobbyRequest("Rejoin")`. Pads and booths are ProximityPrompts (Custom style, drawn by the HUD):
  SoloPrompt, PartyPrompt, AnyPrompt, RewardsPrompt, ClassesPrompt, StorePrompt, VaultPrompt.

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Must never: Hold any loot or cash logic. Shelves are mirrored for display (Model `Shelf_<userId>`,
  attributes Items, Capacity, OwnerName); the client Shelf system draws them.
- Pads: solo goes alone; party = the host plus friends standing on the party pad, up to 4; join
  anyone waits up to 20 s from the first player, then launches whoever stayed near the pad (N11).
  The run's tier is the starter's pick, else their own tier (N13).
- Launch: reserve a run server, store a party token `{ userIds, tier }` in MemoryStore for
  `tokenSeconds`, write the access code to each profile's `rejoin`, release each profile (N19), then
  teleport with `{ token }`. A failed teleport reloads the profiles.
- Run place (N9): a player is admitted only if a valid token names them, or they are already in this
  run's party (late arrival or rejoin, N10); anyone else is sent to the lobby. Leaving mid-run opens
  the 2-minute rejoin window; the lobby shows "Rejoin run (m:ss)".
- Scenery never blocks a route, a prompt, the gallery lane (Krampus walk) or a shelf's front; signs
  that hang are non-colliding. Few PointLights (11 now); Neon glows for the rest.

## How to add a new one

A booth: add it in `Pavilions.build` with a counter part and a sign, a prompt in `initLobby`, then map
the prompt name to a screen in the HUD's `BOOTHS` table. A pad kind: a pure rule in Party with a
spec, a pad in Field, a prompt here. Scenery: a builder in Village, numbers in `Config.Lobby` and the
Diagram D build line together.
