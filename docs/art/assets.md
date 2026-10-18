# Asset list (Phase 5)

Every image, model, sound and marketing asset the game uses, what stands in for it today, and what
replaces it. Rules: [PLAN.md](../PLAN.md) Art bibles A/B; numbers: [PLAN-TABLES.txt](../PLAN-TABLES.txt)
Tables 11–16; direction: [bible.md](bible.md). Reference screenshots in [refs/](refs/) are never assets.

**Status words.** *Built* = in the game, made in code from stock parts and materials, intended to
stay. *Placeholder* = works in the game now, to be replaced by the final asset named. *Missing* = not
made. *Unverified* = nobody has looked at it in Studio or on a phone yet (the final testing pass).
Everything on this page is **unverified** until that pass, whatever its other status.

## How a final asset goes in

- **Images:** upload, then paste the `rbxassetid://` id into its slot in
  [Art.luau](../../src/shared/Art/Art.luau). An empty slot keeps the code-drawn placeholder; no other
  code changes. Text, prices, odds and buttons stay live UI: never bake them into an image.
- **Models:** put a Model in `ReplicatedStorage.Assets.Gifts` (named by gift id) or
  `ReplicatedStorage.Assets.Tools` (Scissors, BoxCutter, Chainsaw); the code-built recipe steps aside.
  A `MeshPart` named `TornPanel` in `ReplicatedStorage.Assets` becomes the torn-paper debris piece.
  `Assets` lives in the place file, not in the Rojo tree.
- **Sounds:** replace the ids in `Config.Sounds` and the SFX line of PLAN-TABLES Table 14 together.

## Images (slots in Art.luau)

| Slot(s) | Used by | Placeholder now | Final wanted | Status |
|---|---|---|---|---|
| `PaperStripes` … `PaperPlaid` (6) | Present paper panels, the Tick box, the lobby's giant present and drifting paper | Code-drawn SurfaceGui pattern (Shared/Art/Patterns) in the paper's lighter and darker steps | One 512 px seamless tile per pattern: transparent, light marks white and dark marks black at partial opacity, so the part's own colour gives the hue (Night desaturation keeps working) | Placeholder |
| `CardboardPrint` | Box lids and walls, spare lids, vault crates | Code-drawn arrows and barcode | Transparent decal: two "this way up" arrows and a barcode, ink `#5A3B1E` | Placeholder |
| `LootDots` | Every gift's base blocks | None (flat colour) | Greyscale dot-relief tile, 4×4 dots per tile (0.25 studs per dot), for 50% overlay | Missing |
| `HoldRing` | The tool badge's hold ring | Two clipped UIStroke halves | White ring PNG, square, transparent centre (tinted and cut in code) | Placeholder |
| `IconShelf`, `IconShop`, `IconClasses`, `IconRewards` | Right-edge buttons | Code-drawn icons (HUD/Icons) | Square 512 px illustrations, bold outline, no text | Placeholder |
| `IconCash`, `IconGems` | Money pill, bank, Spin bar, shelf strip | Code-drawn coin and gem | Same style | Placeholder |
| `IconClose`, `IconStar`, `IconHands`, `IconDaily`, `IconGroup`, `IconStreak`, `IconPockets`, `IconNightEyes`, `IconBigShelf`, `IconPrestige`, `IconTier`, `IconVault` | Close button, Index, empty tool, Rewards cards | Code-drawn icons | Same style | Placeholder |
| `ClassKid` … `ClassKrampusKid` (6) | Classes screen (big card and grid), party badges | Code-drawn emblems: balloon, tape roll, bolt, magnifier, crown, horns | Square class illustrations, one shared style | Placeholder |
| `PassDoubleCash`, `PassBigShelf`, `PassToolKeeper`, `PassLucky` | Shop pass cards, Lucky badge | Code-drawn icons | Square card illustrations | Placeholder |
| `GemsGems100`, `GemsGems500`, `GemsGems1200` | Shop gem cards | One, three and a pile of gems | Square card illustrations; quantities stay live text | Placeholder |
| `ShopScissors` … `ShopLuckyBow` (7) | Run shop cards, tool badge | Code-drawn icons | Square card illustrations | Placeholder |
| `Gift<giftId>` (optional, 50) | Feed, bank, shelf, vault | The gift's code-built model in a ViewportFrame | Optional flat icon per gift (the viewport may simply stay) | Built |

Particle textures (`Art.particles`) use engine textures every client has: `sparkles_main.dds` for paper
flecks, confetti, the gift pop, the reveal drift and the lobby landmark's warm motes; `smoke_main.dds`
for Jack's dust, the lobby cottage's chimney smoke and (slot `snow`) the lobby snowfall. *Placeholder*;
finals would be a paper-scrap sprite, a soft dust puff, a four-point sparkle and a small soft snowflake.

## Models and builds

| Asset | Where | Now | Replacement | Status |
|---|---|---|---|---|
| 32 side-gift and 18 core gift models | [GiftModels.luau](../../src/shared/Art/GiftModels.luau) | Code-built chunky toys from blocks, balls, cylinders and wedges in the rarity colour plus one accent; Giant and Golden mutations | Commissioned models (N7) in `Assets.Gifts`; recipes follow the N31 names, which DECISIONS still lists as **Proposed** | Placeholder |
| Scissors, box cutter, chainsaw | [ToolModels.luau](../../src/shared/Art/ToolModels.luau) | Code-built props on a glowing ring | Models in `Assets.Tools` | Placeholder |
| Jack | `Night.buildJack` ([Night.luau](../../src/server/Night/Night.luau)) | Welded toy jack-in-the-box: patterned box, flaps, 6 spring rings, head with cap, bells, crank | A final model needs a code change: `placeJack` moves parts named `Box`, `Ring1`–`Ring6`, `Head`, `Arm`, `Knob` | Placeholder |
| Torn paper piece | `Debris` | A flat part with the panel's pattern | `Assets.TornPanel` MeshPart with a ragged edge | Placeholder |
| Lobby, Unwrapping Plaza (2026-10-18): plaza and ribbon inlay, spawn dais, pads with rims and tag posts, the giant half-unwrapped present, Rewards / Classes / Shop pavilions, update board, shelf gallery and shelf cabinets, cottage and porch, terrace ring, steps, benches, bollards, lanterns, backdrop cottages, firs, far peaks | [Field](../../src/server/Lobby/Field.luau), [Village](../../src/server/Lobby/Village.luau), [Landmark](../../src/server/Lobby/Landmark.luau), [Pavilions](../../src/server/Lobby/Pavilions.luau), [Props](../../src/shared/Art/Props.luau) | Code-built from stock parts and materials (Snow, Slate, Pavement, Rock, WoodPlanks, Wood, RoofShingles, Cardboard, Glass, Neon); no meshes were available | None planned; low-poly meshes for the firs or peaks could replace the stacked parts later if a budget check asks for fewer parts | Built |
| Lobby snow banks, mounds, terrace fill and hills | [Village.terrain](../../src/server/Lobby/Village.luau) | Terrain Snow, filled at server start | None planned | Built |
| Lobby ambience: snowfall, drifting paper, swaying tags and ribbon, breathing rims and glow | Client [Ambience.luau](../../src/client/Shelf/Ambience.luau) | Code; snowfall on the engine puff texture | A snowflake sprite in `Art.particles.snow` | Built (snowfall texture: Placeholder) |
| Run room (walls, wainscot, beams, window, door, lamps, garden outside, counter) | [Room.luau](../../src/server/Present/Room.luau), Economy | Code-built, stock materials | None planned | Built |
| Tier decorations (Birthday balloons; Christmas tree, porch lights and door wreath) | Client [Shelf.luau](../../src/client/Shelf/Shelf.luau) | Code-built | None planned | Built |

## Sounds (Table 14, 24 clips)

All 24 are chosen in `Config.Sounds`; 23 are Roblox-licensed ProSoundEffects or APM clips. The core
reveal sting (`130378474223829`, Daily Sounds "Coin Pickup", synthesized) is a **placeholder**: no
licensed sting suited the reveal. Tick loop, Jack crank, Jack lunge and player down keep their Phase 4
picks. No clip has been heard in the game yet.

## Marketing (Missing)

- **Icon** (512×512): the hero present with one layer half torn and a rarity glow leaking out, on a
  plain warm background, no text. Stage in the lobby: the giant present behind the pads, camera low.
- **Three thumbnails** (1920×1080, no text): a tear (a player holding a panel, flecks flying), a reveal
  (core box open, light shaft in a rarity colour), Jack (Night lighting, Jack mid-lunge, a lid
  shutter). Stage in Studio: Workspace `NextTier` and `NextSeed` pick the present, `DevNight` opens the
  Tick at once, `DevClear` clears layers to reach the core.
- Still to make (bible.md): `palette.png`, `loot-sheet.png`, `ui-sheet.png`.

## Lobby checks still to do (final testing pass)

None of these has been done; each stays open until someone does it in Studio or on a device.

- **Visual:** the lobby at dusk in Studio from the spawn, the pads, the gallery and the porch: signs
  and pad tags legible, the landmark and its "Start a Run" tag clear from spawn, bloom and Neon
  restrained, snow varied rather than slabbed, no baseplate edge or empty horizon, peaks streamed in.
- **Mobile:** a phone-sized viewport: thumb reach to every prompt, text sizes, snowfall and drifting
  paper not hiding signs or players.
- **Performance:** frame time and memory on a mid-range phone against Table 15; part count (about
  2,200 with 24 shelves), 11 PointLights, 3 emitters; how long the terrain takes at server start.
- **Multiplayer:** solo, party and join-anyone pads with 2 to 4 players on the new layout; a full
  server's shelves in the gallery and vault crates on the porch; walking on steps, round bollards
  and benches.

## Known gaps

- Legendary (the Heir class's rarity) has no Table 12 colour; its chip uses dark wood.
- Krampus, steal and paper-pack art are Phase 6 or post-launch and are not built here.
