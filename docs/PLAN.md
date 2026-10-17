# Unwrap A Present — Master Plan

Oct 17, 2026 · @AP Labs

This is the single source of truth for building Unwrap A Present from nothing to launch.
Every Claude Code run starts here and ends by writing to the decisions log.

> Export note: this file is the Markdown export of the Master Plan doc. Edit the doc, export,
> commit, in that order. Never edit this copy by hand.
>
> **[PLAN-TABLES.txt](PLAN-TABLES.txt) is the source for every number and diagram; this file is the
> source for every rule.** If a number here disagrees with PLAN-TABLES.txt, PLAN-TABLES.txt wins.

---

## How to use this plan

Every Claude Code run reads the first four sections in full, then only the phase it is working on,
and ends by writing to the decisions log. Nothing else is required reading, and that is what keeps a
40-run project from drifting.

**Run protocol** (copied verbatim into `CLAUDE.md`):

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

**Drift check**, every fifth run or once a week, whichever comes first: a run that writes no
features. It re-reads North Star, lists anything in the build that this plan does not describe
(delete it or log it), checks the performance budgets in Art bible B, and plays one full run start to
finish on a phone-sized viewport.

**Where the truth is.** This doc is the editing surface. It exports to Markdown as `docs/PLAN.md` in
the repo, and the repo copy is what Claude Code reads. Edit here, export, commit, in that order; never
edit the repo copy by hand.

---

## North Star

Unwrap A Present is a 1–4 player co-op run where you tear through a house-sized, nested present to
find out what is inside. Every layer you strip drops gifts, one box in the nest is hunting you, and
the thing at the center is a rarity roll you cannot see until the last lid lifts. Runs last 8–12
minutes, and what you find goes on a shelf other players can steal from.

**Player fantasy:** Christmas morning with no rules, at a scale where the present is bigger than your
house and the paper never stops coming.

**Three pillars.** Every feature must serve at least one; a feature that serves none is cut.

1. **The Tear.** Stripping a layer feels physical and loud: panels rip, paper flutters, something
   crinkles. This is the moment-to-moment verb and it must be satisfying with no reward attached.
2. **The Reveal.** Every layer answers "what is under this?" and the core gift answers "what was
   it?". Curiosity is the retention engine, not the economy.
3. **The Night.** One box is wrong. Tension turns a chore into a story and gives the clip a scream.

**The clip test.** A feature ships only if a 15-second phone recording of it, with no caption, makes
sense and makes someone want to try. The Tear, a mythic core reveal, a Krampus grab, and "it was a
sock" all pass. A settings menu, a quest board and a trading UI do not, and they are not in this plan.

**Who it is for.** Roblox players aged 9–15 on phones, playing with one to three friends, in sessions
of 15–30 minutes. Design for a thumb and a 6-inch screen first.

---

## Invariants

These do not change inside a run. Changing one needs a logged decision with a reason and a human
approval in the next run. Claude Code runs quote the invariant number when they decline a change.

1. **Name.** The game is Unwrap A Present. It is never renamed for a holiday and the word Christmas
   never appears in the title or icon.
2. **No licensed characters.** Krampus is folklore and allowed. The Grinch, Santa with a trademark
   look, Elf on the Shelf, any brand mascot, any Roblox UGC brand: never.
3. **Mobile first.** Every interaction works with one thumb and no keyboard. A feature that needs a
   keyboard shortcut is not done.
4. **Materials.** The world uses Roblox stock materials and low-poly meshes. Custom textures exist
   only on wrapping paper and loot. No stud or bevel-dot pattern on the world or the present; dots
   only on loot.
5. **Run length.** A normal run lands between 8 and 12 minutes for a party of 2. Tuning changes layer
   count, never the pace of the Tear.
6. **The core gift is never purchasable.** Robux buys speed, cosmetics, storage and luck boosts under
   2x. It never buys a specific gift or skips a layer.
7. **Server authority.** All tearing, loot rolls, Naughty changes and shelf changes are decided on
   the server. The client only asks and animates.
8. **Performance budgets** in Art bible B are hard limits, checked in every drift run.
9. **One present per run.** No side rooms, no quests, no second map. Depth comes from layers and
   tiers, not from breadth.
10. **Everything the player owns survives.** A crash or a disconnect never loses shelf items, gems or
    prestige. Run-only loot is the only thing a wipe can take.
11. **No feature without a clip.** See the clip test in North Star.
12. **Docs are code.** A run that changes behavior and does not update the system README is not
    finished.

---

## Glossary

Scripts, READMEs, data keys and UI text all use these exact words. A run that invents a synonym
renames it back.

| Term | Meaning | Code name |
|---|---|---|
| Present | The whole nested object a run is about. One per run. | `Present` |
| Layer | One wrapping shell: paper, ribbon, bubble wrap, foil, chains, ice, or a box. Layers nest from outside in. | `Layer`, `LayerType` |
| Overlay | Tape strips laid over a layer's seams; each strip is its own panel with action Cut; a strip blocks the panels it spans until cut; tape is the only overlay. | `Overlay`, `TapeStrip` |
| Panel | One tearable piece of a layer. A paper layer is a grid of panels; a box lid is one panel. | `Panel` |
| Depth | How many layers deep the team is. Depth 0 is the outside. | `depth` |
| Nest | The ordered list of layers in this present, generated at run start from a seed. | `Nest`, `seed` |
| Tool | What the player holds. Each tool has an action set and a grade. | `Tool`, `grade` |
| Grade | A tool's strength: Grade 0 hands, 1 scissors, 2 box cutter, 3 chainsaw. | `grade` |
| Action | Tear, Cut, Snip, Pop, Chip, Lift. Each layer type accepts exactly one. | `Action` |
| Side-gift | A loot item dropped by a layer. Has a rarity. Goes to the run bag. | `SideGift` |
| Core gift | The item at the center of the present. One per run, rolled on the server. | `CoreGift` |
| Run bag | Loot held during a run. Lost on a wipe. Banked at the end. | `RunBag` |
| Shelf | A player's persistent display of banked gifts in the lobby. Stealable. | `Shelf` |
| Index | The player's record of every gift type ever found. Never loses entries. | `Index` |
| Tick | A small ticking side box in one layer of the nest. Opening it starts the Night. May block a lid (`blocking`). | `TickBox` |
| Night | The phase after the Tick opens, until the entity is shut or the team reaches the core. | `NightPhase` |
| Jack | The entity released by the Tick. Hunts the team during Night. | `Jack` |
| Naughty | A per-player meter raised by stealing. Decays daily. Krampus targets by it. | `naughty` |
| Krampus | Lobby-side entity that visits at lobby night and takes from the naughtiest shelves. | `Krampus` |
| Tier | Prestige level only: Birthday 1, Christmas 2, Wedding 3, The Package 4, then The Package +1, +2, … Sets layer count and loot table. | `tier` |
| Wipe | All players in a run down at once. Run bag lost, present gone. | `Wipe` |
| Bank | Converting the run bag to shelf and index at run end. | `Bank` |
| Class | A perk set. A player owns every class they have rolled and picks one before a run. | `Class` |
| Cash, Gems | Run currency and meta currency. Cash buys tools and upgrades; gems buy class spins and cosmetics. | `cash`, `gems` |

---

## Player journey

A new player is tearing paper within 20 seconds of joining and sees their first reveal inside two
minutes. Everything in the first session exists to get to the Tear fast and to the shelf with
something on it.

| Minute | What happens | What the player learns |
|---|---|---|
| 0:00 | Spawn in the lobby facing the Start a Run pads. A present on the porch is already half torn, paper on the ground. One prompt: step on a pad. | This is a game about tearing presents open. |
| 0:20 | Teleport to the run room. A present fills the view. Hands are the tool. Tap and hold a panel: it rips, paper flutters, cash counter ticks. | The Tear. One thumb, no tutorial text. |
| 1:00 | First layer gone. Ribbon on the box underneath. Hands cannot cut it; a scissors pickup glows beside the present. | Layers need the right tool. Tools come from the room and the shop. |
| 2:00 | First box lid lifts with a sound sting. Two side-gifts drop and fly into the run bag with a rarity flash. | The Reveal. Loot comes from layers. |
| 4:00 | A box deeper in the nest is ticking. The team can route around it or open it. A new player opens it. | The Tick. Something is wrong with this present. |
| 4:30 | Jack is out. The team has 90 seconds of hide-or-shutter while continuing to tear. One player goes down; the others keep going. | The Night. Death is not the end of the run. |
| 7:00 | Core box. The whole team lifts the lid together. The core gift rolls on screen. First run is seeded to land Uncommon, never Common. | The core gift is the reason to run again. |
| 7:30 | Bank screen: run bag to shelf and index, gems earned, class spin offered. Teleport to lobby. | Progress persists. Gems buy spins. |
| 8:00 | The shelf in the lobby now shows the core gift. Another player walks past it. A prompt: Naughty players can tear into your shelf, and Krampus takes from Naughty players. | Steal exists, and it has a cost. |
| 9:00 | Rewards booth for the daily, Classes booth for the spin, pad again. | The loop is closed. |

The second session adds the first prestige prompt after three completed runs. The third session is
when a player first sees Krampus in the lobby, taking from a shelf that is not theirs.

---

## Systems architecture

Eight server systems own all state, one remotes layer carries validated requests up and replicated
state down, and four client systems do nothing but read input and draw. A run touches them in the
order the arrows show.

The node list and every edge are in [PLAN-TABLES.txt](PLAN-TABLES.txt), **Diagram A**. Source image:
[art/architecture.png](art/architecture.png).

Lobby starts a run and loads the profile; Present builds the Nest; Tear validates every panel and
tells Loot and Night what happened; Steal and Loot both end in Economy and Data. Nothing on the
client can change a number.

**Remotes** (`ReplicatedStorage/Shared/Remotes`) — Up: `TearRequest`, `LidLift`, `ShopBuy`,
`ClassSpin`, `StealRequest`, `Revive`. Down: `RunState`, `LootEvent`, `NightState`, `ShelfState`.

| System | Path | Owns | Must never |
|---|---|---|---|
| Lobby | `src/server/Lobby` | Start pads, party of up to 4, teleport to run place, booths, lobby night clock | Hold any loot or cash logic |
| Present | `src/server/Present` | Seed, Nest generation, layer table, Tick placement | Be called by the client |
| Tear | `src/server/Tear` | Panel bitfields per layer, tool and action validation, panel timing, layer-cleared events | Trust a client position or timer |
| Night | `src/server/Night` | Tick open, Jack AI, line of sight, downs, revives, wipe detection | Run in the lobby |
| Loot | `src/server/Loot` | Rarity rolls, side-gift spawn, RunBag, core gift, Bank, Index, Shelf state | Roll on the client or re-roll on request |
| Economy | `src/server/Economy` | Cash, gems, shop, classes, prestige, gamepass checks, daily and group rewards | Grant a gift for Robux |
| Steal | `src/server/Steal` | Shelf tear timers, Naughty meter and decay, Krampus walk and sack | Touch Secret items or a player below Naughty 8 |
| Data | `src/server/Data` | ProfileStore profiles, schema version, migration, session lock | Store run state |
| TearInput | `src/client/TearInput` | Hold detection, rip-line preview, TearRequest | Decide that a panel is gone |
| Debris | `src/client/Debris` | Torn-panel pool, 40 live max, physics, recycle | Exceed the budget |
| HUD | `src/client/HUD` | Cash, depth, Night timer, bank, shop, classes, rewards screens | Compute a value it displays |
| Shelf | `src/client/Shelf` | Lobby shelf rendering, steal prompt and 6-second timer display | Move an item |

---

## Run flow

A run has seven states and one losing exit. Unwrapping is where players spend most of the run; the
Night loops back into it; only a Wipe skips the bank.

The full state list and every transition are in [PLAN-TABLES.txt](PLAN-TABLES.txt), **Diagram B**.
Source image: [art/run-flow.png](art/run-flow.png).

The Tick is the only branch. A party that leaves a non-blocking Tick sealed never enters Night and reaches the core
with a smaller bag, because the Tick box drops the run's best side-gifts when opened. State lives on
the server as `RunState` (`Lobby`, `Building`, `Unwrapping`, `Night`, `CoreLid`, `Reveal`, `Bank`,
`Wipe`), replicated to the HUD, and every remote checks the current state before it does anything.

---

## Mechanics A: present, layers, tools, the tear

A present is a seeded list of layers, each layer is a grid of panels, and each panel accepts exactly
one action from exactly one tool class. That one rule drives the whole game.

**Present generation.** At run start the server rolls a seed and builds the Nest: tier sets the layer
count (Birthday 6, Christmas 9, Wedding 12, The Package 16), the layer table sets which types can
appear at which depth, and the Tick is placed at a random depth in the middle third. The last two
layers are always a box lid over the core box. The client receives the Nest as data and builds the
meshes; it never decides what a layer is.

**Layer table.** Weights are per depth band; a type can repeat but never twice in a row.

| Layer type | Action | Tool grade needed | Outer third | Middle third | Inner third |
|---|---|---|---|---|---|
| Paper | Tear | 0 (hands) | 50 | 30 | 20 |
| Ribbon and bow | Snip | 1 | 20 | 20 | 10 |
| Bubble wrap | Pop | 0 | 0 | 20 | 20 |
| Foil | Tear | 0 | 0 | 15 | 15 |
| Chains | Cut | 2 (box cutter) | 0 | 5 | 20 |
| Ice | Chip | 2 | 0 | 5 | 15 |
| Box lid | Lift | 0, two players on tier 2+ | Always last two layers; taped at tier 2 and above | | |

**Tape overlay rules.** A Paper layer is taped with chance by depth band: outer third 40%, middle
third 60%, inner third 80%. A taped paper layer tapes 25% to 50% of its seams, chosen from the seed.
Each tape strip is one panel: action Cut, tool grade 1 (scissors), 0.8 s per strip with scissors, 0.6 s
with box cutter, 0.3 s with chainsaw. A strip blocks the two paper panels it spans until it is cut.
BoxLid layers are taped always at tier 2 and above, never at tier 1; the lid cannot lift until its
tape is cut. No other layer type takes tape.

**Panels.** A paper layer is a 4×4 grid per face (6 faces, 96 panels) at tiers 1–2, 6×6 at tiers 3–4.
Tape panels sit on seams and must be cut before the two paper panels beside them can tear; this is
the ordering puzzle. Panel state is a bitfield on the server; the client renders from it.

**Tools.** Hands → Scissors → Box cutter → Chainsaw. Each tool has a grade, an action set, a per-panel
time, and a hold-to-use input. Tools are bought with cash in the run room shop (prices in Mechanics D)
and found as glowing pickups in the room at a fixed depth so a fresh party is never stuck.

| Tool | Grade | Actions | Seconds per panel | Notes |
|---|---|---|---|---|
| Hands | 0 | Tear, Pop, Lift | 1.2 | Always equipped as fallback |
| Scissors | 1 | Cut, Snip, Tear at 1.0 | 0.8 | First pickup, depth 1 |
| Box cutter | 2 | Cut, Chip, Tear at 0.6 | 0.6 | Shop only |
| Chainsaw | 3 | Everything at 0.3, tears a 2×2 of panels | 0.3 | Shop, prestige tier 2+, loud |

**The Tear, feel spec.** This is pillar one and gets the most polish time.

- **Input:** press and hold on a panel. A tear line grows from the touch point along the panel for
  the panel time, then the panel releases. Release early and the line stays as a visible rip on the
  panel, so progress is never lost.
- **On release:** the panel mesh swaps to a torn-edge variant (jagged alpha on the edge), detaches
  with a small impulse away from the present, flutters under physics for 2 seconds, then returns to
  the pool. Maximum 40 live debris pieces per client; the oldest is recycled first.
- **Audio:** one crinkle on hold start, one rip on release, a soft thud when the piece lands. Three
  variants each, pitch randomized within 10%.
- **Camera:** no shake on single panels. A 2×2 chainsaw tear gives one 0.1-second shake.
- **Haptics on mobile:** one light tap on release.
- **Feedback the team sees:** a panel another player is tearing shows the growing rip line to
  everyone.

**Why this is satisfying without reward.** The rip line answers the touch instantly, the release has
weight and sound, and the debris is the proof of work lying on the floor. If a greybox with no
textures does not feel good to tap for a minute, nothing later in this plan will fix it. That is why
it is phase 0.

---

## Mechanics B: reveal, loot, rarity

Every layer pays out, the core gift is the headline, and nothing the player sees is decided on the
client. Rarity is six bands with fixed odds; tier shifts the table toward the top, Robux luck never
more than doubles a band.

**Side-gifts.** When a layer's last panel goes, the server rolls 1–3 side-gifts from that tier's table
and spawns them as physical items that fly into the nearest player's run bag after 1 second. The bag
is shared by the party. Side-gifts are small toy objects (see Art bible A) in 8 families at launch:
plush, vehicle, figure, candy, trinket, tech, odd, seasonal. Going deeper pays more: layers in the
inner third roll the next tier's table instead of the current one (exact rule in PLAN-TABLES.txt,
TABLE 6).

**Core gift.** Rolled when the core lid lifts, using the same bands with the tier's core table. The
lid lift is a 3-second shared animation: all living players hold the lid, light spills from the box,
the item rises with its rarity color and name, then the room goes quiet for one beat before the bank
screen. A first-ever run is seeded to land Uncommon or better.

| Rarity | Color | Odds, Birthday tier | Odds, The Package | Shelf slot size | Example core gifts |
|---|---|---|---|---|---|
| Common | Grey | 55% | 30% | 1 | Sock, mug, paperclip box |
| Uncommon | Green | 28% | 30% | 1 | Yo-yo, model car, snow globe |
| Rare | Blue | 12% | 22% | 2 | Robot, guitar, tiny tree |
| Epic | Purple | 4% | 12% | 2 | Go-kart, arcade cabinet, puppy crate |
| Mythic | Gold | 0.9% | 5% | 3 | Golden goose, rocket, the Jack's own box |
| Secret | Prismatic | 0.1% | 1% | 4 | One per tier, lore items, never shown in the index until found |

**Index.** Every gift type the player has ever found, with a count and the depth it was first seen.
The index never loses entries, even when the shelf item is stolen. Side-gifts and core gifts share one
Index; core gifts are starred. Completing a family unlocks a wrapping-paper pattern for the shelf and a
badge, which gives collectors a goal that stealing cannot touch.

**Shelf.** Each player has a shelf in the lobby with 12 slots at start, upgradeable to 24 with gems
and to 36 with a gamepass. Items occupy slots by rarity. Duplicates stack on the slot they already
hold, up to ×9. A full shelf forces a choice at the bank screen: replace or sell. Sold items become
cash at a flat rate per rarity. Each shelf has one like button; the lobby shows a board of the
most-liked shelves. No comments.

**Bank.** At run end the run bag converts: side-gifts and the core gift go to shelf and index, cash is
kept, gems are awarded (3 for a completed run, 5 with no downs, 8 with the Tick survived; a flat 1 at
any tier below your highest unlocked tier). On a wipe
the run bag is gone and the index still records what was seen, so even a wiped run teaches the player
what exists.

**Duplicates.** A duplicate core gift of Rare or above gives a mutation roll: 20% chance the item
comes out with a visual variant (frosted, giant, glitched, golden) that counts as its own index entry.
This is the long-tail chase and the trading-talk generator without any trading UI.

---

## Mechanics C: night, Jack, steal, Krampus

There is one threat in the run (Jack) and one in the lobby (Krampus), and both are predictable enough
to be played around and scary enough to clip. Neither ends a run on its own; a wipe needs every
player down at once.

**The Tick.** The Tick is always a side box: about the size of a side-gift, wrapped in the same paper as
the layer it sits in, placed in one layer in the middle third. It ticks, its neon seams pulse faintly,
and the audio gets louder as players tear toward it. One flag decides how it sits: **not blocking**
(60% of nests) it sits beside the path and the team can leave it sealed; **blocking** (40%) it is fused
across that layer's lid seam and the lid cannot lift until the Tick is opened. Opening it starts the
Night and drops the run's best side-gifts. One object, one flag, one Night system.

**Night phase.** Lights drop to 30%, the paper patterns desaturate, and Jack is out for 90 seconds at
tier 1, scaling to 150 seconds at The Package. Tearing continues; the present does not stop. The
Night ends when the timer runs out or the team reaches the core lid, whichever first.

**Jack.** A jack-in-the-box body on a spring, head the size of a player, moving in bursts: 3 seconds
still with its crank turning, then a 1.5-second lunge toward the nearest player in line of sight. It
cannot see through layers, so a torn-open box is cover. A lunge that connects downs the player.

**Counter: hide or shutter.** Each box lid the team has lifted stays in the room as a prop. A player
can crouch behind a lid (hide) or hold a lid up as a shield (shutter) for up to 4 seconds, which
breaks Jack's line of sight. Shutter is the clip: two players holding a lid between them while a third
tears.

**Downs and wipes.** A downed player drops their held tool and can be revived by a teammate holding E
for 3 seconds. A solo player who goes down is revived automatically after 10 seconds with one Common
side-gift removed from the bag. A wipe is every living player down at once: the run ends, the run bag
is lost, the index keeps what was seen.

> Note for implementers: "holding E" must also be a hold-to-use touch button (invariant 3).

**Steal.** In the lobby, any player can walk to another player's shelf and tear into a displayed gift,
6 seconds of holding, interruptible by the owner tapping it. A successful steal moves the item (one
from a stack) to the thief's shelf and raises the thief's Naughty by the item's rarity band (Common 1 to Mythic 5). Secret
items cannot be stolen. Offline players' shelves can be stolen from, but only Common and Uncommon
items, so a returning player never finds their best thing gone.

**Naughty.** 0–20, decays by 3 per real day, shown as a small meter on the nameplate once above 5.
Above 10 the player's shelf glows red in the lobby. It is public on purpose: the social pressure is
the mechanic.

**Krampus.** The lobby has its own clock: every 20 minutes the sky dims for 60 seconds and Krampus
walks the shelf row. He takes one item from each shelf whose owner is at Naughty 8 or above, highest
rarity first, and drops it in a sack that any player at Naughty 0 can open after he leaves. Then he is
gone. Krampus never touches a player below 8, never takes Secret items, and never enters a run.

---

## Mechanics D: economy, classes, prestige, monetization, data

Cash is earned and spent inside a run, gems carry between runs, and Robux buys time and cosmetics,
never a gift. The numbers below are starting values for phase 3 tuning; the shapes are fixed.

**Cash (run currency).** Earned per panel torn (1 at tier 1, scaling with tier), per side-gift banked
(5–200 by rarity), and from selling shelf overflow. Spent in the run room shop. Cash resets to 0 at
run start, so every run begins with hands.

| Shop item | Cost | Effect |
|---|---|---|
| Scissors | 30 | Grade 1 tool, if not picked up |
| Box cutter | 120 | Grade 2 tool |
| Chainsaw | 400, prestige tier 2+ only | Grade 3 tool |
| Grip tape | 60 | Panel time −15% for this run |
| Flashlight | 40 | Night lighting 30% → 60% for the holder |
| Spare lid | 80 | One extra shutter prop |
| Lucky bow | 150 | Next layer rolls one extra side-gift |

**Gems (meta currency).** 3–8 per completed run (Mechanics B), 35 from the daily reward every 6 hours,
a login streak, a bring-a-friend bonus, 100 one-time for joining the group and liking. Spent on class
spins (25), shelf slots (50 per 4 slots, to 24), the permanent track, and cosmetics (50–500). Amounts
in PLAN-TABLES.txt, TABLES 7 and 19.

**Permanent track.** Gem upgrades that never reset: Pockets (more starting cash) and Night Eyes
(brighter Night). There is never a permanent tear-speed upgrade: tear speed comes only from the run's
tools and grip tape (invariant 5).

**Classes.** Rolled with a 25-gem spin. A player owns every class they have rolled and picks one before
each run; a duplicate roll refunds gems. Copying the shape that works in Sell Fries.

| Class | Rarity, odds | Passive | Starts with |
|---|---|---|---|
| Kid | Common, 40% | +5% cash | Nothing |
| Wrapper | Uncommon, 28% | Tape panels take grade 0 | 20 cash |
| Sprinter | Rare, 16% | +3 walk speed, Jack lunges 25% slower at you | A flashlight |
| Collector | Epic, 10% | +1 side-gift on every box lid, +10% gems | Scissors, 50 cash |
| Heir | Legendary, 4.5% | Core gift rolls twice, keep the better | Box cutter, 100 cash |
| Krampus's Kid | Mythic, 1.5% | Immune to Krampus, Naughty does not rise from your steals | Nothing, and everyone can see it |

**Prestige.** Unlocked after a number of completed runs at the current tier that grows each tier (no
Index requirement). Prestiging only shrinks the shelf to 12 slots; the rest go to a vault shown as a
crate on the porch, so items look stored, not gone, and a few can be reclaimed each run. Index, gems,
classes, passes, stats and the permanent track are never touched. It unlocks the next tier's present,
loot table and lobby decoration. Players can run any tier they have unlocked; full gems only at the
highest.

**After The Package.** Prestige repeats forever (The Package +1, +2, …). Each repeat slightly raises
Secret odds, the mutation chance and Night length, up to caps, and adds a star to the nameplate. It
never adds layers, so runs stay 8–12 minutes (invariant 5). The game has no end. Numbers in
PLAN-TABLES.txt, TABLE 9.

| Tier | Layers | Night length | Loot table shift | Lobby change |
|---|---|---|---|---|
| Birthday | 6 | 90 s | Base | Balloons on the porch |
| Christmas | 9 | 110 s | Rare +6%, Epic +3% | Snow, tree, lights |
| Wedding | 12 | 130 s | Rare +10%, Epic +6%, Mythic +2% | White drapes, cake on the porch |
| The Package | 16 | 150 s | Core table only, Secret 1% | Brown paper, barcode, no decoration |

**Monetization.** All of it respects invariant 6.

| Product | Type | Price (Robux) | What it does |
|---|---|---|---|
| 2x Cash | Gamepass | 199 | Doubles cash in runs |
| Big Shelf | Gamepass | 299 | 36 shelf slots |
| Extra Tool Slot | Gamepass | 149 | Hold two tools, swap with one tap |
| Lucky | Gamepass | 399 | Rarity table shifted one step up for side-gifts only, never the core |
| Gems 100 / 500 / 1200 | Dev products | 99 / 399 / 799 | Gems |
| Paper packs | Dev products | 49–199 | Cosmetic wrapping patterns for your shelf and nameplate |

**Data schema** (ProfileStore, one profile per player, server-only):

- `tier`, `prestigeCount`, `gems`, `naughty`, `naughtyUpdatedAt`
- `shelf`: array of `{giftId, rarity, mutation, slotIndex, count}` (count stacks duplicates, up to 9)
- `vault`: array of the same shape
- `index`: map of `giftId → {count, firstDepth, firstSeenAt}`
- `classes`: array of owned class ids; `activeClass`
- `passes`: map of gamepass id → boolean, re-checked on join
- `stats`: `runs`, `completions`, `wipes`, `ticksSurvived`, `stolen`, `stolenFrom`, `mythicsFound`, `fastestBirthdayRunSeconds`
- `upgrades`: `{pockets, nightEyes}` levels
- `streak`: `{days, lastLoginDay}`
- `likesReceived`, `likedShelves`
- `dailyClaimedAt`, `groupClaimed`

Run state (`RunBag`, panel bitfields, Nest, Night timer) lives in server memory only and is never
written to the profile.

---

## Mechanics E: keeping players playing

The game has no end. Every feature here gives a reason to come back without adding a second map, a
quest board or anything else invariant 9 rules out. Numbers in PLAN-TABLES.txt, TABLE 19.

- **Featured present of the day.** One modifier per calendar day, the same on every server (All Ice,
  Double Tick, Tape Everywhere, Giant, Tiny, Golden Hour, Silent Night). Still one present per run. The
  first retention feature to build.
- **Login streak.** Gems for each day in a row, capped at a week.
- **Bring-a-friend.** Extra gems for every player in a party of 2 or more.
- **Leaderboards.** Fastest Birthday run, most Mythics, longest streak.
- **Shelf likes.** See Mechanics B, Shelf.
- **Lore.** Each Secret item is one line of the Sender's letter. Draft in [LORE.md](LORE.md).
- **Limited gift families.** Available for a while, then retired; retired entries stay in the Index.
- **Server-wide counter event.** Comes with post-launch content.
- **Repeatable prestige.** See Mechanics D, After The Package.

Start pads are **solo**, **party** (friends) and **join anyone** (matchmakes strangers). Most players
come alone, so join anyone matters most.

---

## Art bible A: pillars, tiers, the present

The art has one job: make the present the loudest thing on screen and make every layer tell the player
what to do with it from across the room. Three visual tiers, each with its own surface language, keep
that true.

**Visual pillars.**

1. **Readable at thumb distance.** A layer type is identifiable by silhouette and color alone on a
   6-inch screen. If a player has to walk up to know whether it is tape or ribbon, the layer fails.
2. **Chunky and saturated.** Big simple forms, no fine detail, saturated colors with warm light. The
   world reads at 60 fps on a mid-range phone.
3. **The present is the hero.** The room around it is quiet. Nothing in the environment competes with
   the paper.
4. **Toys look like toys.** Loot has the chunky bevel-dot look (the Grow a Garden surface) so it reads
   as a toy against smooth paper and a smooth room. That look appears nowhere else.

**Three tiers.**

| Tier | Surface language | Materials | Custom textures |
|---|---|---|---|
| World (room, lobby, props) | Smooth low-poly, stock materials, Chop a Forest look | Grass, WoodPlanks, roof tiles, Fabric, SmoothPlastic | None |
| Present (layers) | Patterned, glossy, high contrast between layer types | SmoothPlastic + pattern tile, Glass, Fabric, Cardboard, Foil, Metal, Ice, Neon | One 512 px pattern tile per paper, one dot tile for bubble wrap |
| Loot (side-gifts, core gifts) | Chunky toy, bevel-dot relief, flat bright colors | SmoothPlastic + dot relief tile | One dot relief tile shared by all loot |

**Present cross-section** — seven layer types plus the tape overlay, outside-in. Read from the outside in. A player meets ring 1
first and ring 7 last; the core is only ever seen in the 3-second reveal animation.

Ring by ring: [PLAN-TABLES.txt](PLAN-TABLES.txt), **Diagram C**. Source image: [art/layers.png](art/layers.png).

Launch ships rings 1, 2 and 7 plus the tape overlay. Post-launch updates add 3 to 6, one per update. The Tick is any ring in the
middle third, same look, ticking.

**Layer palette.** Each layer owns a color family so a thumbnail of any depth is identifiable. Hex
values are the base color; patterns use one lighter and one darker step of the same hue, never a
second hue.

| Layer | Color family | Base hex | Pattern | Night version |
|---|---|---|---|---|
| Paper, launch set | Candy red, mint, royal blue, sun yellow, pink, teal | `#E23D3D` `#5FD3A0` `#2F5BD9` `#F2C230` `#F06BA8` `#2FB8C9` | Stripes, polka dots, snowflakes, zigzag, stars, plaid | Desaturated 40%, pattern unchanged |
| Tape | Clear with warm gloss | `#FFF3C4` at 35% transparency | None, specular only | Gloss off |
| Ribbon and bow | Satin gold, satin crimson | `#E0B13A` `#B52A3C` | None, reflectance 0.6 | Reflectance 0.2 |
| Bubble wrap | Milky white | `#F4F7FA` at 50% transparency | Dot tile, 8 px bubbles | Unchanged |
| Foil | Silver, with a rose and a blue variant | `#C9CED6` `#D9A9A0` `#A9C4E0` | Roblox Foil material | Darker ambient only |
| Chains | Dark iron | `#4A4F57` | Roblox Metal | Unchanged |
| Ice | Pale blue, lit from inside | `#BFE6F7`, inner Neon `#7FD8FF` | Roblox Ice | Inner glow brighter |
| Cardboard | Kraft brown | `#B98A52` | Roblox Cardboard, printed arrows and a barcode decal | Unchanged |
| Tick box | Same as its ring | Same | Neon seams `#FF4D2E` pulsing 0.8 s | Seams at full brightness |

**Rarity colors**, used on loot glow, nameplates, the bank screen and the shelf: Common `#9AA0A6`,
Uncommon `#4CC96B`, Rare `#3C8DFF`, Epic `#A857F0`, Mythic `#FFC23D`, Secret: animated hue sweep, never
a fixed color.

**Loot style.** One dot relief tile at 0.25 studs per dot, flat base colors from the rarity family plus
one accent, no gradients, no fine geometry. A side-gift is 1 to 2 studs, a core gift 3 to 6 studs, a
Mythic core gift gets a slow idle animation (bob, spin or breathe). Mutations: Giant is 2x scale,
Golden swaps the base color for `#E0B13A` with reflectance 0.5, Frosted adds an Ice shell, Glitched
offsets the UV every 0.5 s.

**Reference board.** Keep `docs/art/refs/` with screenshots of: the Chop a Forest lobby (world tier),
the Dig & Clean reveal moment (loot pop), the Sell Fries night lighting, and a real photo of a stack of
wrapped presents for color. Study only, never copied into the game.

---

## Art bible B: lobby, UI, VFX, SFX, budgets

The lobby is one open field where everything a new player needs is visible from spawn, the UI is the
Chop a Forest wooden-panel style with the present's colors on top, and every effect in the game is on
one list with a budget.

**Lobby plan**, spawn facing the pads. Zones and positions: [PLAN-TABLES.txt](PLAN-TABLES.txt), **Diagram D**.
Spawn faces the pads so the first prompt is a walk, not a menu. The shelf row and the porch sit on the
left where a returning player looks for their stuff; the booths are straight ahead; the update board
is beside the pads where everyone queues.

**Run room.** A single interior, 60 by 60 studs, warm wood floor, one wide window with daylight, the
present centered and scaled to the tier (Birthday 16 studs across, The Package 28). The room has no
props except the shop counter in one corner and the lid props the team creates. Night drops the window
light and adds a cold rim light from the Tick box.

**UI style.** Wooden panels with rounded corners, a leaf or ribbon accent on tabs, big round icon
buttons on the right edge (Shelf, Shop, Classes, Rewards) with the key letter under each, Chop a Forest
proportions. Text is one bold rounded sans at 3 sizes. Present colors appear only on rarity and layer
indicators, never on panel chrome.

| HUD element | Where | Shows |
|---|---|---|
| Cash | top left | run cash, ticks up per panel |
| Depth | top center | layer n of N as a vertical stack of colored bars |
| Night timer | top center, replaces depth during Night | seconds left, red |
| Tool | bottom center | current tool, hold ring fills during a tear |
| Party | left edge | up to 4 names, down state, class icon |
| Prompt | bottom third | one line, one key, never two prompts at once |

**VFX list** (all particle counts are per emitter, per event):

| Event | Effect | Budget |
|---|---|---|
| Tear release | torn panel detach, 6 paper flecks | 1 mesh + 6 particles |
| Layer cleared | ring of confetti in the layer's color, light pulse | 40 particles, 0.6 s |
| Side-gift drop | spawn pop, rarity glow, arc to bag | 12 particles, beam 0.8 s |
| Core reveal | light shaft from the box, slow 30-particle drift, rarity color | 30 particles, 3 s |
| Tick found | seam neon pulse, faint heat shimmer | 0 particles, Neon only |
| Jack lunge | spring stretch, 8 dust puffs on land | 8 particles |
| Player down | greyscale vignette for that player | post-process only |
| Krampus walk | footprints that fade, sack jingle | 2 decals per step |
| Steal success | item lifts, red flash on the victim's shelf | 1 flash |

**SFX list**, launch set of 24: tear hold start ×3, tear release ×3, paper land ×3, tape cut ×2, ribbon
snip ×2, lid lift ×3, side-gift pop ×3, core reveal sting ×1, Tick ticking loop ×1, Jack crank ×1, Jack
lunge ×1, player down ×1. All under 2 seconds except the two loops. Pitch randomized within 10% on
every play.

**Thumbnail and icon rules.** The icon is the hero present with one layer half torn and a rarity glow
leaking out, on a plain warm background, no text. Thumbnails show one moment each: a tear, a reveal,
Jack. The countdown icon swaps in for update weeks only and always returns to the hero icon within 24
hours of the update.

**Performance budgets** (hard limits, invariant 8):

| Budget | Limit | Checked by |
|---|---|---|
| Parts in the run room, present included | 2,500 | drift run |
| Present parts, The Package tier | 1,200 | automated test |
| Live debris pieces per client | 40 | Debris module |
| Particle emitters active at once | 12 | drift run |
| Texture memory, run room | 48 MB | Studio MicroProfiler |
| Frame time, mid-range phone, 4 players, Night | 16 ms | playtest |
| Server step, 4 players tearing | 4 ms | MicroProfiler |
| TearRequest rate per player | 8 per second, server-enforced | Tear module |
| Place file size | 25 MB | CI check |

---

## Content list

Launch ships the smallest set that makes every pillar visible; each post-launch update adds one layer type and one
gift family so each update is a new thumbnail. Counts are the build target, not a wish list.

| Content | Launch | After post-launch updates | Notes |
|---|---|---|---|
| Layer types | 3: paper, ribbon, box lid, plus the tape overlay | 7: + bubble wrap, foil, chains, ice | One new type per update |
| Paper patterns | 6 | 14 | One 512 px tile each; each owns a color family |
| Tools | 3: hands, scissors, box cutter | 4: + chainsaw | Chainsaw lands with chains |
| Side-gift models | 32 (8 families × 4) | 64 | Chunky toy style, dots allowed |
| Core gift models | 18 (3 per rarity band) | 36 | Secret: 1 per tier |
| Mutations | 2: giant, golden | 4: + frosted, glitched | Visual variants only |
| Tiers | 2: Birthday, Christmas | 4: + Wedding, The Package | Wedding first, then The Package |
| Entities | Jack | Jack, Krampus | Krampus in the first update if not ready at launch |
| Classes | 6 | 6 | Balance only |
| Lobby decorations | Birthday, Christmas | 4 | Swap with tier |
| Shop items | 7 | 9 | + two Night items |
| Gamepasses | 4 | 4 | No new passes in post-launch updates |
| Paper packs (cosmetic) | 3 | 8 | One per update |
| Sound set | 24 clips | 40 | Tear 9, lid 3, gift 6, Jack 6 at launch |
| UI screens | 6: HUD, shop, bank, shelf, classes, rewards | 8: + index, settings | Index can wait; players ask for it soon after launch |

---

## Production roadmap

Seven phases and two hard gates, with no fixed dates: a phase starts when the one before it is done. Each phase is a list of acceptance criteria
a Claude Code run can tick one at a time; a phase is done when every criterion is ticked and the gate's
human playtest passes.

Build order and gates: [PLAN-TABLES.txt](PLAN-TABLES.txt), **Diagram E**.

Gate A is the only point where the whole plan can be cancelled cheaply: if tapping a greybox present is
not fun for a minute, stop and redesign the Tear before anything else is built. Gate B is the point
after which art and content can start in parallel with systems.

### Phase 0: Tear greybox
One paper layer on one cube, no textures, no loot.

- [ ] Panel grid generated from a layer definition, 4×4 per face
- [ ] Hold-to-tear with a growing rip line, server-validated, progress kept on early release
- [ ] Torn-edge mesh swap, physics flutter, pool of 40, recycle oldest
- [ ] Three tear sounds, pitch randomized
- [ ] Works with touch on a phone-sized viewport
- [ ] **Gate A playtest:** three people tap for one minute each and want to keep going

### Phase 1: Nest and tools
- [ ] Nest generation from seed, layer table weights, never the same type twice in a row, last two layers are lids
- [ ] Tape panels block the paper panels beside them
- [ ] Ribbon layer and box lid with the two-player lift
- [ ] Hands, scissors, box cutter with per-panel times; scissors pickup at depth 1
- [ ] Run room shop with the launch item list
- [ ] Automated tests for Nest rules

### Phase 2: Loot, bank, data
- [ ] Rarity tables per tier, summing to 100, server rolls only
- [ ] Side-gift spawn, fly-to-bag, shared RunBag
- [ ] Core lid reveal animation and core roll, first-run seed to Uncommon or better
- [ ] Bank screen, shelf with 12 slots, index, duplicate mutation roll
- [ ] Shelf duplicates stack to ×9; one Index with core gifts starred; inner-third side-gifts roll the next tier's table
- [ ] ProfileStore profile with the schema in Mechanics D, session lock, rejoin test
- [ ] **Gate B playtest:** a party of 2 completes a run end to end and sees their shelf

### Phase 3: Lobby, economy
- [ ] Lobby built to the plan in Art bible B; pads, party of 4, teleport
- [ ] Cash, gems, daily and group rewards, class spin with the launch odds
- [ ] Gamepasses and dev products wired, with the invariant 6 check in code review
- [ ] HUD complete per the table in Art bible B
- [ ] Prestige to Christmas tier
- [ ] Start pads: solo, party, join anyone
- [ ] Owned classes with pick-before-run and duplicate refund
- [ ] Permanent track (Pockets, Night Eyes), login streak, bring-a-friend gems
- [ ] Prestige run counts per tier, vault crate with reclaims, replay any unlocked tier at reduced gems

### Phase 4: Night and Jack
- [ ] Tick side box placement (blocking and non-blocking) and ticking audio ramp
- [ ] Night lighting, Jack movement, line of sight blocked by lids
- [ ] Hide and shutter, downs, revives, auto-revive solo, wipe
- [ ] Night ends on timer or core reached
- [ ] **Playtest:** Night survived using shutter only

### Phase 5: Art and polish
Runs in parallel with phase 4.

- [ ] Six paper patterns and the full layer palette from Art bible A
- [ ] 32 side-gift and 18 core gift models in the loot style
- [ ] VFX list and the 24-clip sound set
- [ ] Icon and three thumbnails
- [ ] Every performance budget met on a mid-range phone
- [ ] Full playtest checklist passes

### Phase 6: Steal and Krampus
Starts right after launch.

- [ ] Shelf tear with 6-second timer and owner interrupt
- [ ] Naughty meter, nameplate display, daily decay
- [ ] Krampus lobby clock, walk, sack, rules from Mechanics C
- [ ] Offline shelf protection for Rare and above
- [ ] Featured present of the day, server-synced, with the seed modifier list
- [ ] Leaderboards: fastest Birthday run, most Mythics, longest streak
- [ ] Shelf likes and the most-liked board

### Post-launch content
One layer type and one gift family per update, Wedding tier, then The Package, as listed in Content
list. Also: limited gift families, repeatable prestige once The Package ships, and the server-wide
counter event (Mechanics E).

---

## Testing and telemetry

Five numbers decide whether the game works, and every phase gate reads at least one of them.
Everything else is diagnostic.

| Metric | Target at launch | Why it matters | Where it is logged |
|---|---|---|---|
| Time to first tear | under 20 s from join | Pillar one, onboarding | AnalyticsService custom event `first_tear` |
| Run completion rate | over 60% of started runs | Difficulty and length tuning | `run_end` with outcome |
| Median run length | 8–12 min, party of 2 | Invariant 5 | `run_end` duration |
| Day-1 return | over 30% | The Reveal is working | Roblox analytics |
| Clip rate proxy | over 5% of runs end with a Mythic, Night survival, or a steal | Pillar three, marketing | `run_end` flags |

**Events to log**, all server-side, one line each: `join`, `first_tear`, `layer_cleared` (depth, type,
seconds), `tick_opened`, `player_down`, `revive`, `wipe`, `core_reveal` (rarity), `bank` (gems, items),
`steal` (rarity, success), `krampus_take`, `purchase`, `class_spin`, `prestige`.

**Playtest checklist**, run by a human at every phase gate and by the drift run every fifth run:

- [ ] Phone-sized viewport, touch only, no keyboard
- [ ] Join to first tear under 20 seconds with no reading
- [ ] Tear a full paper layer solo; it still feels good at panel 90
- [ ] Tape blocks paper; scissors fix it; the order is obvious without text
- [ ] Lid lift with two players syncs within 0.2 s
- [ ] Open the Tick, survive the Night using shutter only
- [ ] Go down, get revived, finish the run; bag intact
- [ ] Wipe; index updated, shelf untouched
- [ ] Bank, spin a class, see it on the nameplate
- [ ] Steal from a shelf; Naughty rises; Krampus visits and takes from the right player
- [ ] Disconnect mid-run and rejoin; profile intact
- [ ] Frame time under 16 ms on a mid-range phone with 40 debris pieces live
- [ ] No client can tear, roll or bank by firing a remote with fake arguments

**Automated tests** (Jest-Lua over pure-logic modules with no Roblox services, run from the command line; fallback Lune): Nest generation never repeats
a type twice in a row and always ends in two lids; rarity tables sum to 100 per tier; panel bitfield
round-trips; Naughty decay math; profile schema migration from version n-1.

---

## Where the docs live

Move the notes to a docs folder of Markdown and PNG files inside the git repo and keep Studio READMEs
as short pointers. Obsidian is optional: a vault is only a folder, and VS Code, GitHub and Claude Code
read the same files. Rojo syncs only script, JSON, text, CSV and model files, so Markdown and images
beside the code stay out of the place file.

Studio cannot show images in a script, so any doc that needs a picture cannot live in Studio, and
Claude Code reads files, not Studio instances. An Obsidian vault is just a folder of Markdown with
images beside it, which is exactly what a Claude Code run wants.

**Repo layout** (Rojo project; the vault is the `docs/` folder, opened in Obsidian as a vault):

```
unwrap-a-present/
  CLAUDE.md               run protocol (section 1 of this plan, verbatim) + read order
  CHANGELOG.md            date · change · who, newest first
  default.project.json    Rojo mapping
  src/
    server/               ServerScriptService
      Present/ Tear/ Loot/ Night/ Steal/ Economy/ Lobby/ Data/
    shared/               ReplicatedStorage
      Types/ Config/ Remotes/
    client/               StarterPlayerScripts
      TearInput/ Debris/ HUD/ Shelf/
  docs/                   Obsidian vault
    PLAN.md               export of this doc; canonical copy for runs
    DECISIONS.md          the decisions log, appended by runs
    systems/              one page per system, mirrors src/server folders
    art/
      bible.md            Art bible A and B, with images
      palette.png layers.png lobby.png loot-sheet.png ui-sheet.png
      refs/               reference screenshots, named by what they show
  tests/
```

**Rules.**

- Each `src/server/<System>/` folder has a `README.md` next to its scripts; Rojo ignores it, Claude Code
  reads it. The Studio-side README ModuleScript in that folder holds only: one line of purpose and the
  path to the real page. Nothing else.
- Images are PNG, under 1 MB, named by what they show. A Markdown page embeds them with
  `![[palette.png]]` (Obsidian) or `![](art/palette.png)`; use the second form so GitHub and Claude Code
  render them too.
- Reference screenshots of other games go in `docs/art/refs/` for study only and are never committed
  into the game or used as textures.
- This plan is edited here, exported to `docs/PLAN.md`, committed. The export is the first step of any
  run that follows a plan change.
- `CLAUDE.md` stays under 80 lines: the run protocol, the read order, the test command, and nothing that
  is already in `PLAN.md`.

**Why not Studio-only.** READMEs as ModuleScripts bloat the place file, cannot hold images, cannot be
diffed, and live in a tree that Claude Code cannot read without a Studio session. The Studio tools
connected to this chat can still read them for quick lookups, which is why the pointer stays.

---

## Decisions log and open questions

Runs append to docs/DECISIONS.md, newest first. The table below is the seed copy from plan v1 and is not updated after export. A decision that touches an invariant waits in DECISIONS.md for a human before it is built.

| Date | Decision | Reason | By |
|---|---|---|---|
| 2026-10-17 | Art: smooth low-poly world, patterned present, dotted toy loot. No dots on world or present. | Dots are the Grow a Garden brand mark and fight paper patterns | Plan v1 |
| 2026-10-17 | Docs move to an Obsidian vault in the repo; Studio READMEs become pointers | Images and Claude Code both need files | Plan v1 |
| 2026-10-17 | Launch target Nov 25, generic name, Krampus not Grinch | Seasonal window, invariants 1 and 2 | Plan v1 |
| 2026-10-17 | One present per run, no side content | Depth from layers and tiers, scope control | Plan v1 |

**Open questions** (answer before phase 1 starts):

- [ ] Final name: Unwrap A Present or Unwrap The Present
- [ ] Does Jack ship at launch or in the first update if phase 4 slips
- [x] Rojo + git from day one (recommended) or Studio-only for phase 0 — **Rojo + git** (repo created 2026-10-17)
- [x] Which test runner the repo adopts — **Jest-Lua**, pure-logic modules, fallback Lune
- [ ] Who owns art assets: in-house, commissioned, or a mix per tier
- [ ] In-app search for "unwrap" and "present" done and clear
- [ ] Gem cost per level of Pockets and Night Eyes
- [ ] Completed runs needed per repeat of The Package, and the mutation-chance step per repeat
- [ ] How tier shifts (Christmas, Wedding) and the Lucky gamepass take odds from the lower bands
- [x] How a party "routes around" the Tick box — **side box with a `blocking` flag**
- [x] Lobby and run as one place or two — **two places**, private reserved run servers
- [x] ProfileService or ProfileStore — **ProfileStore**
