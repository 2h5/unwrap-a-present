# HUD

Cash, depth, Night timer, bank, shop, classes, rewards screens.
Must never: Compute a value it displays.

- **Built in:** Phase 1 (run cash, shop), Phase 2 (loot feed, reveal, bank, shelf), Phase 3 (the rest), Phase 4 (Night), Phase 5 (wooden UI pass, icons, loot effects; [assets.md](../../../docs/art/assets.md)), build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Art bible B (UI style, HUD)
- **Visual direction:** [art bible and supplied references](../../../docs/art/bible.md) — original icons, wooden framing and ribbon accents; follow our HUD placement and mobile rules
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 13 (HUD), Table 12 (rarity and layer colors)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Public API

- `HUD.init()` — builds every screen; the run room shop (`RunShop`: seven cards with picture, effect and a
  cash price; owned, locked by tier or too dear greyed), opened by the counter's `ShopPrompt`, Buy sends
  `ShopBuy`. `HUD.hold(progress?, seconds?)` drives the hold ring.
- `HUD.toast(text)` — a parchment card for `Config.HUD.toastSeconds` (TearInput shows refusals here).
- [LootScreens.luau](LootScreens.luau): loot feed (a card per side-gift with its toy, 3 s, five at most),
  core reveal banner (gift tag over a turning rarity burst, top of screen), `Wipe` banner, bank screen
  (gift cards with outcome, gems, Sell / Replace… / Done as `BankChoice`; closing is Done) and the Shelf
  screen (slot grid of toys, ★ core, ×count, a detail card, replace mode). Reads `LootEvent`, `ShelfState`.
- [MetaScreens.luau](MetaScreens.luau): Shop (Passes / Gems tabs, one row of illustrated cards, R$ buttons),
  Classes (the chosen class big with passive and kit, six cards with odds, Spin; a new class from a spin
  is shown big) and Rewards (cards: daily with a live countdown, group, streak pips, Pockets, Night Eyes,
  shelf slots, prestige progress, next-run tier chips, vault with toys) from `ProfileState`; taps send
  `EconomyRequest` / `ClassSpin`. Rejoin button top centre.
- [Status.luau](Status.luau) (Table 13): cash pill top left (gems in the lobby, from `ProfileState`), counting
  up; depth plaque top centre with the coloured bars under it (`LayerColors`), the red Night timer on it;
  the round tool badge bottom centre with the hold ring (`HUD.hold`, or a hold prompt); party cards on
  the left (class icon, name, Lucky icon, DOWN); one prompt button in the bottom third with its key chip
  (press and hold works by touch, invariant 3); a prompt tagged `HideFor` = not offered to this player.
- [NightView.luau](NightView.luau): Night exposure at `NightLight`, the run room's window light off,
  paper desaturated, ribbon dulled, tape gloss off (Table 12); the Tick's ticking, pulsing seams and
  Neon heat shimmer; Jack's crank, lunge and 8 landing dust puffs; the down sound; greyscale while `Down`.
- [LootView.luau](LootView.luau): the side-gift pop (12 sparkles, pop clip), the core reveal's light shaft,
  30-sparkle drift and sting, and the Secret hue sweep on gift models (Table 14).
- [Widgets.luau](Widgets.luau): the wooden kit (`Config.UI`): `wood`, `card`, `button` (action / wood / close
  / chip, pressed edge), `enable`, `chip`, `tag`, `ring`, `icon`, `gift` (toy viewport), `screen` (returns
  frame, title, body, close; one screen at a time), `rowCard`, `sideButton`, `onKey`, `scroll`, `list`.
- [Icons.luau](Icons.luau): original code-drawn icons; `Widgets.icon` uses the Art slot instead once filled.

## Keys and buttons

Right edge, top to bottom: Shelf (F), Shop (B), Classes (C), Rewards (R). Key chips show only with a
keyboard; every screen also opens from its button and its lobby booth. Prompts keep E.

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Must never: Compute a value it displays. Prices, odds and effect lines are live text from Config.
- Chrome is wood, parchment and the action orange; present colours only on rarity and layer indicators.

## How to add a new one

A screen: `Widgets.screen(gui, name, title)`, fill its body when shown, add `Widgets.sideButton` and
`Widgets.onKey` with a key in `Config.UI.keys`. An icon: a `DRAW` entry in Icons and an `Icon<Name>` slot
in [Art.luau](../../shared/Art/Art.luau); list it in [assets.md](../../../docs/art/assets.md).
