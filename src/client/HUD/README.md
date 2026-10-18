# HUD

Cash, depth, Night timer, bank, shop, classes, rewards screens.
Must never: Compute a value it displays.

- **Built in:** Phase 1 (run cash, shop), Phase 2 (loot feed, reveal, bank, shelf), Phase 3 (the rest), build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Art bible B (UI style, HUD)
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 13 (HUD), Table 12 (rarity and layer colors)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Public API

- `HUD.init()` — builds every screen; the run room shop (`RunShop`), opened by the counter's `ShopPrompt`,
  Buy sends `ShopBuy`. `HUD.hold(progress?, seconds?)` drives the hold ring.
- `HUD.toast(text)` — a short message for `Config.HUD.toastSeconds` (TearInput shows refusals here).
- [LootScreens.luau](LootScreens.luau) (Phase 2): loot feed (side-gifts, 3 s a line), core reveal banner,
  bank screen (outcomes, gems, Sell / Replace… / Done as `BankChoice`) and the Shelf button and screen
  (slots by rarity, ★ on core gifts, gems, Index count). Reads `LootEvent`, `ShelfState`, `RunState`.
- [MetaScreens.luau](MetaScreens.luau) (Phase 3): Shop (Robux passes and gem products), Classes (spin, pick)
  and Rewards (daily, group, streak, track, shelf slots, prestige, next tier, vault) screens from
  `ProfileState`; taps send `EconomyRequest` / `ClassSpin`. Right-edge buttons: Shelf, Shop, Classes, Rewards.
- [Status.luau](Status.luau) (Table 13): cash top left; depth top centre as coloured bars (Present
  attribute `LayerColors`, set by Tear); Night timer in red over the depth line while `NightState` carries
  `{ secondsLeft }`; tool bottom centre (player attribute `Tool`) with the hold ring (`HUD.hold`, from
  TearInput); party on the left edge (name, 🍀 for `Lucky`, `Class`, `Down`); prompts with Custom style drawn in the bottom
  third, tap or key.
- [Widgets.luau](Widgets.luau): shared builders (`make`, `text`, `button`, `enable`, `list`, `screen`, `row`).

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Must never: Compute a value it displays.

## How to add a new one

_Fill in when the first one exists (e.g. how to add a layer type, gift, entity, screen)._
