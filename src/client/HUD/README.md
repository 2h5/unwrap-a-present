# HUD

Cash, depth, Night timer, bank, shop, classes, rewards screens.
Must never: Compute a value it displays.

- **Built in:** Phase 1 (run cash, shop), Phase 2 (loot feed, reveal, bank, shelf), Phase 3 (the rest), build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Art bible B (UI style, HUD)
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 13 (HUD), Table 12 (rarity and layer colors)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Public API

- `HUD.init()` — top bar (cash, layer n / count, tools) from player and `Present` attributes; the run
  room shop, opened by the counter's `ShopPrompt`, Buy sends `ShopBuy`.
- `HUD.toast(text)` — a short message for `Config.HUD.toastSeconds` (TearInput shows refusals here).
- [LootScreens.luau](LootScreens.luau) (Phase 2): loot feed (side-gifts, 3 s a line), core reveal banner,
  bank screen (outcomes, gems, Sell / Replace… / Done as `BankChoice`) and the Shelf button and screen
  (slots by rarity, ★ on core gifts, gems, Index count). Reads `LootEvent`, `ShelfState`, `RunState`.

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Must never: Compute a value it displays.

## How to add a new one

_Fill in when the first one exists (e.g. how to add a layer type, gift, entity, screen)._
