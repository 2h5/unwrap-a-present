# Decisions log

Runs append here, newest first. A decision that touches an invariant is written as **Proposed** and
waits for a human to mark it **Approved** in the next run before anything is built.

| Date | Decision | Reason | By | Status |
|---|---|---|---|---|
| 2026-10-17 | No fixed dates. Phases run in order and each starts when the one before it is done and its gate passes; launch happens when Phase 5 is done. Supersedes the Nov 25 launch target (the generic name and Krampus-not-Grinch parts still stand). | Team wants to build at its own pace | Human | Approved |
| 2026-10-17 | Tape is an overlay on a layer, never its own layer; LayerType is Paper, Ribbon, BubbleWrap, Foil, Chains, Ice, BoxLid (7 types) | Tape sits over paper seams and lid seams physically, and the adjacency rule in Mechanics A requires it to be on top of the panels it blocks | Human, resolving the Mechanics A vs cross-section conflict | Approved |
| 2026-10-17 | `docs/PLAN-TABLES.txt` is the plain-text form of every table and diagram and the source for every number; PLAN.md is the source for every rule. Decisions stay only in DECISIONS.md. | One readable form for people and Claude Code; PDF tables did not extract cleanly | Team | Approved |
| 2026-10-17 | Rojo + git from day one; repo at github.com/2h5/unwrap-a-present | Plan recommendation; diffs, images and Claude Code all need files | Team | Approved |
| 2026-10-17 | System pages live as `README.md` beside the code in `src/<side>/<System>/`; `docs/systems/README.md` is only a map to them | One copy per system avoids two pages drifting apart | Scaffold run | Proposed |
| 2026-10-17 | Art: smooth low-poly world, patterned present, dotted toy loot. No dots on world or present. | Dots are the Grow a Garden brand mark and fight paper patterns | Plan v1 | Approved |
| 2026-10-17 | Docs move to an Obsidian vault in the repo; Studio READMEs become pointers | Images and Claude Code both need files | Plan v1 | Approved |
| 2026-10-17 | Launch target Nov 25, generic name, Krampus not Grinch | Seasonal window, invariants 1 and 2 | Plan v1 | Approved |
| 2026-10-17 | One present per run, no side content | Depth from layers and tiers, scope control | Plan v1 | Approved |
