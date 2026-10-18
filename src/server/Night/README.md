# Night

Tick open, Jack AI, line of sight, downs, revives, wipe detection.
Must never: Run in the lobby (Main leaves it out of the lobby's boot order).

- **Built in:** Phase 4, build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Mechanics C (Tick, Night, Jack, downs and wipes); Q1, N17; Phase 4 build rules in DECISIONS.md
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 20 (Night and Jack, with the build line), Diagram B (run flow), Table 9 (Night length), Table 7 (Flashlight, Spare lid), Table 8 (Sprinter), Table 12 (Tick seams, Night palette), Table 14 (Night sounds)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau) (`Config.Night`, `Config.Tick`), never inline

## Public API

- `Night.startRun(roomCenter)` (Present) — no Night, nobody down; builds the Tick where `Nest.placeTick` put
  it (`Workspace.Night.Tick`: attributes `Depth`, `Blocking`, `Revealed`, `Volume`, `Opened`).
- `Night.openTick()` — the Tick opens: `Tear.openTick`, `Loot.tickOpened` (its side-gifts), then the Night.
- `Night.down(player)`, `Night.revive(player)`, `Night.endNight("timer" | "core" | "wipe")`, `Night.isActive()`.
- Pure, tested in `tests/Night`: [Sight](Sight.luau) (`aabb`, `crosses`, `blocked`, `inside`),
  [JackBrain](JackBrain.luau) (`new`, `eye`, `pickTarget`, `step`), [NightRules](NightRules.luau)
  (`isWipe`, `soloRevives`, `toolToDrop`, `holdDone`, `lighting`, `tickVolume`, `shutterSpot`).
- Down `NightState`: `{ secondsLeft = n }` when the Night starts (and to a player who joins during it),
  `{ secondsLeft = nil }` when it ends; events `{ kind = "Lunge" | "Down" | "Revive", userId? }`.
- Prompts (Custom style, drawn by the HUD's hold button, key E): `TickPrompt` (Open, 1.2 s),
  `ShutterPrompt` on every lid prop during the Night (hold up to 4 s), `RevivePrompt` on a downed
  player (3 s; `HideFor` keeps it off its owner's screen). The Up remote `Revive` is not used.
- Player attributes: `Down`, `NightLight` (this player's Night lighting, applied by HUD NightView).
- Studio only: Workspace `DevNight` (open the Tick), `DevDown` (down the first player), `DevWipe`.
- Look (Phase 5, `Config.JackLook`): Jack is a welded toy jack-in-the-box: patterned box with a cold rim
  light, two flaps, six spring rings that stretch while he lunges, a round head with a jester cap and
  bells, and a crank. `placeJack` moves the parts named `Box`, `Ring1`–`Ring6`, `Head`, `Arm`, `Knob`.
  The Tick box wears its layer's paper pattern; dropped tools are tool props; spare lids carry `Print`.

## Invariants and rules

- Invariant 7: every hold is timed on the server from `PromptButtonHoldBegan`; a `Triggered` without
  a full hold (less `holdSlackSeconds`) or out of reach is ignored.
- The Tick hides inside the outer layers until its own layer is current, and ticks from the start
  (`Volume` halves for each layer still in the way). Blocking: on its lid's top edge; the lid refuses
  "Open the Tick first". Not blocking: on the floor at its layer's corner, openable until the core lid.
- Night: `RunState` Night, Tier's Night length, Jack out of the Tick's spot. Jack (JackBrain): still
  3 s, then a 1.5 s lunge at the nearest player in sight; the current layer and every lid prop block
  sight and stop a lunge. A lunge that connects downs the player.
- Hide is standing behind a lid prop. Shutter: holders carry a lid that stands between them and Jack,
  for up to 4 s, then it drops where it is. Spare lid: one 6-stud lid stood up by its buyer.
- Down: can't move, sits, greyscale screen, holds ended, best tool dropped (not with Tool Keeper),
  `Loot.noteDown`. Revive: a teammate holds 3 s. Solo: auto-revive after 10 s, one Common side-gift lost.
- Wipe: every player down at once with two or more in the run (never solo): RunState Wipe, `Loot.wipe`.
- The Night ends on its timer (back to Unwrapping) or when the core lid is reached (stays CoreLid);
  both revive everyone and count the Tick as survived. The run room floor is at y = 0.

## How to add a new one

A new Night entity: a pure brain beside JackBrain (state, `step(dt, bodies, boxes)`), specs in
`tests/Night`, its numbers in `Config.Night` and Table 20, and its model built and stepped here.
