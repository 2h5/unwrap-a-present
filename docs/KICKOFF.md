# Unwrap A Present — Kickoff Notes

Oct 17, 2026 · @AP Labs

> Historical context. The [Master Plan](PLAN.md) supersedes these notes wherever they differ
> (for example, the docs convention below was replaced by the Rojo + git layout in PLAN.md).

## Concept

Unwrap A Present is a 1–4 player co-op chore-run: tear through a house-sized, nested present to find
out what is inside. Working title. It is deliberately not named for Christmas so it survives January.

**Why this game:** it is the purest form of the reveal mechanic that the biggest 2026 chore games run
on, every kid has the physical reference, the title is a complete sentence, and the holiday calendar
does the marketing. No existing Roblox game owns the lane (see Launch and marketing).

**Why now:** the Oct 16 trending page shows three waves at different ages. Steal-games are late-cycle,
chore-runs are mid-cycle and still producing new hits monthly, and the seasonal window opens in about
six weeks.

## Market read

The new entries on the trending page all come from one lineage: a single mundane chore with a hidden
payoff at the end, run-based, co-op, with one new layer added per hit. Each successful game added
exactly one thing: economy, then night horror, then layered lore. The reveal moment is the product.

| Game | Where it stands (Oct 16) | What to borrow |
|---|---|---|
| Steal An Egg | ~926K CCU, down from a 14.3M peak on Sep 19; still #1 but late-cycle | Persistent shelf of owned items, rarity index. Do not enter the steal genre directly. |
| Dig & Clean | Released Jul 2026, 270K peak in Aug | The reveal: dig up junk, spray it clean, find out what it is. Museum shelf, rarity hunt. |
| Sell Fries! [Anomaly] | Released Sep 2026, 57K all-time peak this month | Day/night loop, shutter counter to the window anomaly, class spin for 25 gems, cursed perks. |
| Drain the Lake | Released Jun 2026, 59K peak | Skill tree, checkpoint stations as you go deeper, run resets on exit. |
| Chop A Forest | 27.7K on the page, 91% rating | Lobby layout (Start a Run pads, Rewards, Classes), daily reward of 35 gems every 6 h, one-time group reward of 100. |
| Peel The Potato | Established; parent of the genre | Chore pile hides one key; cash buys faster tools; gems from completed runs. |
| Crack Verity | Released Sep 26, 2026 | Layers with a "LAYER DISCOVERED" prompt teasing something at the center; 4-player teams. |
| Evolve a Cell | Released Sep 26, 2026, 6.7K peak | Proof that new entries in this lane show up weekly. |

Two side observations from the page. Five of the roughly sixty icons were the same hourglass countdown
(24H, 1 DAY, NOW); that is an icon-swap hype tactic, not a genre, and it is worth copying for launch
week. And stud-textured retro games are at the backlash stage (TikTok has a "retroslop" tag); none of
the chore hits use that look.

## Core loop

One run: enter, strip layers, survive the night, reach the core gift, bank the loot. Target 8–12
minutes per run, 1–4 players.

1. **The run.** Players spawn facing a present the size of a house. Each wrapping layer is a grid of
   panels. Order rule: ribbon before tape before paper before lid. Tools scale hands → scissors → box
   cutter → chainsaw. Big lids need two players lifting.
2. **Nesting.** Every box holds a smaller box. Each layer is a different wrap with its own pattern and
   color family: paper, tape, bubble wrap, foil, chains, ice, cardboard. Layer count scales with
   prestige tier.
3. **The reveal.** Each layer drops side-gifts with rarities, common to mythic, logged in an index and
   displayed on the player's shelf in the lobby. The core gift of the run is a rarity roll; "it was a
   sock" is the meme clip, mythic is the chase.
4. **Night.** Partway through, one box in the nest starts ticking. A jack-in-the-box entity hunts the
   team; the counter is a hide-or-shutter mechanic, same beat as the Sell Fries window.
5. **Steal, with a twist.** Players can tear into other players' shelf presents (the white-elephant
   party rule). Doing so fills a Naughty meter, and Krampus hunts the naughtiest players at night.
   Krampus is Alpine folklore with no IP owner; do not use the Grinch. Griefing balances itself and
   generates clips.
6. **Economy.** Cash from scraps and side-gifts buys tools and upgrades. Gems come from completed runs
   and buy class spins (copy the 25-gem spin). Daily reward and one-time group reward in the lobby.
7. **Prestige.** Birthday → Christmas → Wedding → The Package, where the lore lives.
8. **After December.** The name is not Christmas-bound. January update is "Returns": take the sock
   back to the store.

## Art direction

Quiet low-poly world, loud patterned present, toy-style loot. Three visual tiers so the reveal lands:
the environment stays out of the way, the present is the one busy object, and loot reads as "toy"
against both.

**Studs rule.** No stud dots (the Grow a Garden bevel pattern) on the world or the present. Stud dots
only on loot. Dots mean toy. Reason: the dot pattern is a brand mark of the Grow a Garden / Steal a
Brainrot lineage, and it fights wrapping-paper patterns, which are where this game's surface detail
lives.

**World.** Copy Chop a Forest's lobby approach: stock Grass ground, WoodPlanks and roof tiles on
buildings, Fabric on soft props, low-poly SmoothPlastic trees. Almost nothing custom. Lighting bright,
warm, saturated, soft shadows, mild bloom.

**Present.** Spend the whole texture budget here. Material is the mechanic: the player must read at a
glance which action a surface wants. Most layers map to materials Roblox already ships.

| Layer | Material | Finish | Action |
|---|---|---|---|
| Wrapping paper | SmoothPlastic + tiled pattern texture | One 512 px tile per paper type (stripes, dots, snowflakes); each layer owns a color family | Tear |
| Tape | Glass | Light tint, high reflectance, laid across seams | Cut |
| Ribbon and bow | Fabric, or SmoothPlastic with reflectance for satin | Saturated single color | Snip |
| Cardboard | Cardboard (built-in since 2022) | Default | Lift lid (two players on big boxes) |
| Foil | Foil | Default | Tear |
| Bubble wrap | Glass + dot pattern | Translucent | Pop |
| Chains / crate | Metal, DiamondPlate | Default | Cut with upgraded tool |
| Ice | Ice or Glacier | Default | Chip |
| Ticking box | Neon seams under the paper | Pulsing | Avoid / hide |

Eight layer types, roughly two custom textures total.

**Loot.** Side-gifts and core gifts are chunky toy objects with the bevel-dot relief, so they read as
toys against the smooth world and smooth paper.

**The tear.** The one place to spend real effort. Each paper layer is a grid of panels; a panel pops off
with a torn-edge mesh (jagged alpha), flutters with physics for about two seconds, then despawns from a
pool. Add a crinkle sound. This is the ASMR beat that gets clipped, the same job Dig & Clean's spray
bottle does.

**Mobile-first.** Most players in this genre are on phones. Low-poly plus stock materials keeps load
times short and the frame rate stable with paper debris flying.

## Launch and marketing

Launch Thanksgiving week, ride December, keep the name generic. That gives about five weeks of build
time from today.

1. **Nov 20, 2026** — swap the game icon to an hourglass countdown ("UNWRAPS IN 5 DAYS") and start a
   party-of-friends teaser in the lobby. Same icon-swap tactic five games on the Oct 16 trending page
   were using.
2. **Nov 25, 2026** — launch with the first three layer types, the reveal, and the lobby. Night entity
   can ship in week two if it is not ready.
3. **December** — one new layer type per week, each with its own pattern and color family so every
   update is visibly different in a thumbnail.
4. **Jan 8, 2027** — "Returns" update so the game is not stranded by the end of the season.

**Existence check (Oct 16).** Web search plus RoWatcher and Bloxodes, which together track about 6.5M
Roblox experiences, turned up no unwrap or present chore-run. The closest matches are leftovers from
last year's steal-clone wave: Don't Steal the Present (Nov 2025, all-time peak 188) and Steal Gifts From
Grinch (Nov 2025, all-time peak 3). Both dead, both the wrong genre.

Caveat: emoji-heavy titles hide from web indexes. Search "unwrap" and "present" in the Roblox app before
committing.

Ideas checked and dropped because the lane is taken: Drain A Lake (Drain the Lake exists, June 2026), a
dig-your-backyard concept (Dig & Clean owns it).

## Project docs convention (superseded)

The kickoff proposed Studio-side README ModuleScripts (index README ≤60 lines in ServerStorage, one
system README ≤80 lines per system folder, `--[=[ ]=]` script headers ≤15 lines, a CHANGELOG module),
with the rule: "If more than two people are editing, move to Rojo + git." The Master Plan adopted
Rojo + git; the caps and script-header rule carry over (see `CLAUDE.md`).

## Next steps (from kickoff)

Build the tear first, with no art, and decide within a week whether it is satisfying. Everything else is
known-good from the comparables; the tear is the only unproven part. These map onto Phases 0–6 in
[PLAN.md](PLAN.md#production-roadmap).
