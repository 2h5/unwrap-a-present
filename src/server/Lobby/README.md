# Lobby

Start pads, party of up to 4, teleport to run place, booths, lobby night clock.
Must never: Hold any loot or cash logic.

- **Built in:** Phase 3, build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Player journey; Art bible B; N9–N11, N13, N19, P12
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 2 (player journey), Diagram D (lobby plan), Table 19 (keeping players playing)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Two places, one codebase

`lobby.project.json` builds the lobby place (Workspace attribute `PlaceKind = "Lobby"`);
`default.project.json` builds the run place (no attribute). `Main.server.luau` boots the lobby's
systems (Data, Economy, Loot, Steal, Lobby) or the run's. Place ids live in `Config.Places`; while
they are 0 everything falls back to local play: pads say "The run place is not set up yet" and the
run place loops runs. To try the lobby in Studio, set Workspace `PlaceKind` to "Lobby" before Play.

## Public API

- [Party.luau](Party.luau) (pure, `tests/Lobby`): `fromPad(host, standing, isFriend, max)`, `newQueue`,
  `join`, `leave`, `waitLeft`, `take(queue, now, max, wait)`, `admits(members, userId)`.
- [Field.luau](Field.luau): `build()` (the greybox lobby to Diagram D), `shelfSpot(i)`, `label`, `prompt`.
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

## How to add a new one

A booth: add it in `Field.build` with a label and a prompt, then map the prompt name to a screen in
the HUD's `BOOTHS` table. A pad kind: a pure rule in Party with a spec, a pad in Field, a prompt here.
