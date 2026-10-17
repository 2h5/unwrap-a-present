# Lobby

Start pads, party of up to 4, teleport to run place, booths, lobby night clock.
Must never: Hold any loot or cash logic.

- **Built in:** Phase 3, build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Player journey; Art bible B
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 2 (player journey), Diagram D (lobby plan), Table 19 (keeping players playing)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Public API

_None yet._ List each public function here as it lands: signature, one line of what it does.

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Must never: Hold any loot or cash logic.
- Two places (N9): the run place accepts only players whose teleport data carries a valid party token
  issued here; anyone else is sent back to the lobby. The reserved run server shuts down when its last
  player leaves.
- Rejoin (N10): the reserved server access code goes into the profile at teleport; the lobby shows
  "Rejoin run (m:ss)" until `Config.Run.rejoinWindowSeconds` runs out. After that, nothing banks.
- Join anyone (N11): wait up to `Config.Matchmaking.waitSeconds` to fill `maxParty`, then start with
  whoever is there. No backfill into a running run.

## How to add a new one

_Fill in when the first one exists (e.g. how to add a layer type, gift, entity, screen)._
