# Economy

Cash, gems, shop, classes, prestige, gamepass checks, daily and group rewards.
Must never: Grant a gift for Robux.

- **Built in:** Phase 1 (run cash, shop), Phase 3 (the rest), build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Mechanics D, Mechanics E
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 7 (shop, cash, gems), Table 8 (classes), Table 9 (prestige), Table 10 (monetization), Table 19 (keeping players playing)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Public API

- `Economy.cashPerPanel(tier)`, `addCash(player, n)`, `getCash(player)` — run cash, kept as the player
  attribute `Cash` (Phase 1: Birthday only; other tiers not set yet).
- `Economy.resetRun(tierNumber)` — cash to 0 and run items cleared at run start (Table 7).
- `Economy.setupShop(roomCenter)` — the run room counter with a `ShopPrompt` ProximityPrompt.
- Up `ShopBuy(item)`: rate-limited; refused unless the item exists, its `minTier` is met, it is not
  owned this run, and cash covers it. Tools set `Tool_<name>`, the rest `Upgrade_<name>`.

## Invariants and rules

- Invariant 7: the server decides; the client only asks and animates.
- Must never: Grant a gift for Robux.
- Permanent track level n costs `costLevel1 + costStep * (n - 1)` gems (N1).
- Lucky gamepass: side-gift rolls happen twice and keep the better; never the core gift (N4,
  invariant 6: 2p − p² < 2p).
- Phase 1 shop effects: tools and grip tape work now; flashlight, spare lid and lucky bow are bought
  and kept as attributes until Night (Phase 4) and side-gifts (Phase 2) read them.

## How to add a new one

_Fill in when the first one exists (e.g. how to add a layer type, gift, entity, screen)._
