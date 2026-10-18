# Economy

Cash, gems, shop, classes, prestige, gamepass checks, daily and group rewards.
Must never: Grant a gift for Robux.

- **Built in:** Phase 1 (run cash, shop), Phase 3 (the rest), build order in [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt) Diagram E
- **Rules:** [PLAN.md](../../../docs/PLAN.md), Mechanics D, Mechanics E; Phase 3 economy rules in DECISIONS.md
- **Numbers:** [PLAN-TABLES.txt](../../../docs/PLAN-TABLES.txt), Table 7 (shop, cash, gems), Table 8 (classes), Table 9 (prestige), Table 10 (monetization), Table 19 (keeping players playing)
- **Code reads numbers from:** [Config.luau](../../shared/Config/Config.luau), never inline

## Public API

- [Meta.luau](Meta.luau) (pure, `tests/Economy`): daily, group, `login` (streak), `friendBonus`, `rollClass`,
  `spin`, `pickClass`, `trackCost`, `buyTrack`, `buyShelfSlots`, `shelfCapacity`, `prestigeNeed`,
  `canPrestige`, `prestige`, `runCompleted`, `canRunTier`. Each edits a profile table and returns what changed.
- Run cash: `cashPerPanel(tier)` (= tier number, N35), `addCash(player, n)` (Kid +5%, 2x Cash pass;
  fractions carry), `getCash`, `resetRun(tierNumber)` (cash 0, run items cleared, then each starting kit:
  Pockets cash + the class's cash, tools, upgrades; Sprinter's walk speed).
- `classOf(player)` — the run's class (player attribute `Class`, fixed at run start).
- `hasPass(player, name)`, `shelfCapacity(player, data)`, `bankRun(player, data, baseGems, partySize, tierNumber)`
  (Loot's bank: Collector +10%, bring-a-friend, prestige run count, vault reclaims), `nextRunTier()`,
  `refresh(player, message?)`, `onProfileChanged(fn)` (Loot resends the shelf).
- `setupShop(roomCenter)` — the run room counter. Up `ShopBuy(item)` while tearing is allowed.
- Up `EconomyRequest(kind, arg)`: DailyClaim, GroupClaim, ClassPick, TrackBuy, ShelfSlots, Prestige,
  TierPick, VaultReclaim. Up `ClassSpin()`. Down `ProfileState` (everything the Classes, Rewards and
  Shop screens show, with costs and waits computed here, and an optional message).

## Invariants and rules

- Invariant 6: products pay gems only; passes scale cash, shelf size or side-gift luck (Lucky: twice,
  keep the better, 2p − p² < 2p; party-wide, non-stacking), never the core and never a named gift.
  Tool Keeper: scissors in every starting kit, tools kept when downed (Phase 4). Heir's double core roll comes
  from a gem spin, not a pass.
- Invariant 7: the server decides; the client only asks and animates. Requests are rate-limited and
  refused in Building, Reveal and Bank.
- Receipts: a dev product is granted once (receipt ids kept in `purchases`) and saved at once.
- Ids still 0 (the gem products, the group) show as "Soon" in the Shop.
- Player attribute `Lucky` (set from the pass) draws the 🍀 by the owner's name on the party panel.
- Studio only: Workspace `DevGems` (adds gems), `DevPasses` ("DoubleCash,Lucky" pretends to own).

## How to add a new one

A class: add it to `Config.Classes` and `Config.ClassOrder` (odds must still sum to 100) with its perk
fields, then read the field where the perk acts. A gem sink: a pure function in Meta with a spec, a
kind in `EconomyRequest`, a row in the HUD's Rewards screen.
