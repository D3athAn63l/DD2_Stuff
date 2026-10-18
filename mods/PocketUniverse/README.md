# Pocket Universe — v0.1.0 experimental

*A World Within. A Burden Without.*

Minimal REFramework weight mod for Dragon's Dogma 2. **Exactly one user-facing control: Enable**. When enabled, it overrides returned carried weight to zero for the known `getStorageWeight` and `getStorageWeightInt` getters and forces `getWeightRank` to return enum 0 (Very Light). It does **not** rewrite individual item definitions, per-pawn `WeightDict` entries, inventory data, or saved character fields.

## Install
1. **Back up saves and `reframework/data/`**. Remove/disable the old `reframework/autorun/burden_reforged.lua`, `weight_rank_2026_compat.lua`, `weight_rank_tweak.lua`, and any competing weight scripts. Do not run together.
2. Fully restart the game after old weight scripts, especially ones that changed tooltip item definitions.
3. Copy `reframework/autorun/pocket_universe.lua` to the corresponding DD2 directory.
4. Open REFramework > Script Generated UI > Pocket Universe > **Enable**. The default is ON. Config: `reframework/data/PocketUniverse.json`.

**Disabling:** immediately returns the native results through these hooks. If other mods previously modified managed dictionaries or item parameters, restart the game to clear those unrelated changes.

## Technical scope
- Two `getStorageWeight` float overloads are overridden using `sdk.float_to_ptr(0.0)`; `getStorageWeightInt` returns integer zero.
- Six `getWeightRank` overloads return enum 0. The 3-/4-argument signatures had live calls in an October 18, 2026 probe. The other signatures are guarded for future contexts.
- No per-frame inventory walks; no direct dictionary lookup, storage mutations, global item changes or cached-value writes.
- The inventory progress bar may remain proportional to actual physical item totals and vanilla boundaries; only getters/ranks are targeted.

## Unverified
- **Inventory overflow or transfer-to-storage prevention is NOT established**. Internal systems may read `WeightDict`, raw item weights, or capacity directly instead of calling hooked getters. Actual pickup/transfer behavior needs an owner-run test.
- Online pawn-sharing safety cannot be guaranteed; this implementation deliberately avoids persistent item/pawn changes but cannot prove every online serialization path.
- The weight getter hooks, unlike the rank-hook prototype, have not yet been exercised in the owner's current game build. Hook installation and mocked tests are not live validation.
- Depending on game update semantics, returned zero weight may not reach every UI or gameplay subsystem.

Historical Burden Reforged v0.1.2 and its tests preserved unchanged in `history/BurdenReforged/v0.1.2/` (Git history also remains intact). Pocket Universe is a different gameplay implementation, not a rename of third-party Weight System Tweaks. No third-party code redistributed.

## Validation checklist
- Verify REFramework reports weight hooks 3/3 and rank hooks 6/6.
- With full party and mod enabled, inspect displayed carried weight and category; then toggle OFF and ON again.
- Pick up and transfer heavy items; confirm whether inventory overflow still diverts items to storage.
- Check pawn joins/leaves, save/reload, and REFramework logs for new errors.
