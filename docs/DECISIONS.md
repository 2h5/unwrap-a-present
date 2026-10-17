# Decisions log

Runs append here, newest first. A decision that touches an invariant is written as **Proposed** and
waits for a human to mark it **Approved** in the next run before anything is built.

| Date | Decision | Reason | By | Status |
|---|---|---|---|---|
| 2026-10-17 | **[Glossary]** P1. Tier means prestige only: Birthday=1, Christmas=2, Wedding=3, The Package=4. Panel grids 4×4 at tiers 1–2, 6×6 at tiers 3–4. The tool scale is renamed **grade** (Grade 0 hands → Grade 3 chainsaw, code `grade`) | "Tier" meant two things | Human | Approved |
| 2026-10-17 | P2. Prestige vault reclaims 3 items per run. Prestige only shrinks the shelf to 12; the vault is a visible crate on the porch. Index, gems, classes, passes and stats are never touched | Prestige must not feel like losing things | Human | Approved |
| 2026-10-17 | P3. Players can run any unlocked tier. Gems pay full only at your highest tier; lower tiers pay a flat 1. Loot tables stay per tier | Lets players farm easy runs without breaking the gem curve | Human | Approved |
| 2026-10-17 | P4. Prestige needs 3 / 6 / 10 completed runs (Birthday→Christmas, Christmas→Wedding, Wedding→The Package). No Index requirement | 3 runs everywhere was too fast; gating on a rare roll frustrates kids | Human | Approved |
| 2026-10-17 | **[Invariant 5]** P5. No permanent tear-speed upgrade; tear speed stays per run (tools, grip tape). Permanent gem track with two lines: Pockets (+10 starting cash per level, 10 levels) and Night Eyes (+5% Night lighting per level, cap 30%) | Invariant 5 protects the feel of the Tear | Human | Approved |
| 2026-10-17 | P6. Players own every class they roll and pick one before a run; a duplicate roll refunds 10 gems | Matches the classes array in the schema | Human | Approved |
| 2026-10-17 | P7. Side-gifts in the outer and middle thirds roll the current tier's table; the inner third rolls the next tier's table. The Package's inner third rolls its core table with Secret at 2% | Going deeper always pays more, using tables that already exist | Human | Approved |
| 2026-10-17 | P8. Completing an Index family gives a wrapping-paper pattern for the shelf plus a badge | Collector goal stealing cannot touch | Human | Approved |
| 2026-10-17 | P9. One Index for side-gifts and core gifts; core gifts are starred | One book is simpler | Human | Approved |
| 2026-10-17 | P10. Duplicates stack on their existing shelf slot up to ×9; selling gives cash; a steal takes one from the stack | Full shelves stop being a wall | Human | Approved |
| 2026-10-17 | P11. Shelf likes: one like button per shelf and one lobby board of most-liked shelves. No comments | Status without moderation load | Human | Approved |
| 2026-10-17 | P12. Start pads are solo / party / join anyone | Most kids play solo; matchmaking matters most | Human | Approved |
| 2026-10-17 | R1. Featured present of the day, built in Phase 6: one modifier per calendar day, server-synced. Seed list: All Ice, Double Tick, Tape Everywhere, Giant (2× panels), Tiny (half), Golden Hour (Mythic odds 2×), Silent Night (Night from depth 1) | Daily variety inside one present per run (invariant 9) | Human | Approved |
| 2026-10-17 | R2. Secret items are lore clues; each Secret is one line of the Sender's letter. Lore drafted now in docs/LORE.md, ships with the first Secret | Gives players a mystery to chase | Human | Approved |
| 2026-10-17 | R3. Limited gift families ship with post-launch content; retired entries stay in the Index | Reason to come back each update | Human | Approved |
| 2026-10-17 | R4. Login streak: +10 gems per consecutive day, capped at day 7 | Daily return | Human | Approved |
| 2026-10-17 | R5. Leaderboards in Phase 6: fastest Birthday run, most Mythics, longest streak | Cheap status | Human | Approved |
| 2026-10-17 | R6. Bring-a-friend: +2 gems per run for every player in a party of 2+ | Pushes co-op | Human | Approved |
| 2026-10-17 | R7. Server-wide counter event comes with post-launch content, not the launch build | Needs a global counter the launch build does not have | Human | Approved |
| 2026-10-17 | **[Invariant 5]** P13. Repeatable prestige after The Package (Package +1, +2, …). Each repeat: Secret odds +0.5% (cap 3%), mutation chance rises from 20% toward a 30% cap (step per repeat not set yet), Night +10 s (cap 180 s), a star on the nameplate. Never adds layers, so runs stay 8–12 minutes | The game has no end; invariant 5 holds | Human | Approved |
| 2026-10-17 | No fixed dates. Phases run in order and each starts when the one before it is done and its gate passes; launch happens when Phase 5 is done. Supersedes the Nov 25 launch target (the generic name and Krampus-not-Grinch parts still stand). | Team wants to build at its own pace | Human | Approved |
| 2026-10-17 | Tape is an overlay on a layer, never its own layer; LayerType is Paper, Ribbon, BubbleWrap, Foil, Chains, Ice, BoxLid (7 types) | Tape sits over paper seams and lid seams physically, and the adjacency rule in Mechanics A requires it to be on top of the panels it blocks | Human, resolving the Mechanics A vs cross-section conflict | Approved |
| 2026-10-17 | `docs/PLAN-TABLES.txt` is the plain-text form of every table and diagram and the source for every number; PLAN.md is the source for every rule. Decisions stay only in DECISIONS.md. | One readable form for people and Claude Code; PDF tables did not extract cleanly | Team | Approved |
| 2026-10-17 | Rojo + git from day one; repo at github.com/2h5/unwrap-a-present | Plan recommendation; diffs, images and Claude Code all need files | Team | Approved |
| 2026-10-17 | System pages live as `README.md` beside the code in `src/<side>/<System>/`; `docs/systems/README.md` is only a map to them | One copy per system avoids two pages drifting apart | Scaffold run | Proposed |
| 2026-10-17 | Art: smooth low-poly world, patterned present, dotted toy loot. No dots on world or present. | Dots are the Grow a Garden brand mark and fight paper patterns | Plan v1 | Approved |
| 2026-10-17 | Docs move to an Obsidian vault in the repo; Studio READMEs become pointers | Images and Claude Code both need files | Plan v1 | Approved |
| 2026-10-17 | Launch target Nov 25, generic name, Krampus not Grinch | Seasonal window, invariants 1 and 2 | Plan v1 | Approved |
| 2026-10-17 | One present per run, no side content | Depth from layers and tiers, scope control | Plan v1 | Approved |
