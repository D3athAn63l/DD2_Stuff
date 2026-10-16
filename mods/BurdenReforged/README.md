# Burden Reforged — experimental 0.1.2

An independently authored, feature-oriented REFramework weight rule mod for Dragon's Dogma 2. Inspired by the gameplay idea behind **Weight System Tweaks** (original Nexus #415, by **lingsamuel**); does not include or claim authorship of the original source or images. Not affiliated with the original author.

**Status (16 October 2026):** **Owner confirmed v0.1.2 runs in DD2 without the repeating missing-key/`KeyNotFoundException` spam previously caused by Burden Reforged v0.1.1.** The owner had isolated v0.1.1 as the source by disabling that mod, then tested the v0.1.2 hotfix enabled and reported that the spam disappeared. This establishes the *reported log-noise fix*, not complete proof of every weight rule, pawn transition, or performance scenario. Previously, the owner confirmed v0.1.1 restored pawn carried weights when toggling the mod off, after v0.1.0 left stale zero weights. Other mechanics still need broader regression testing. Back up your DD2 save and `reframework/data` before changing mods.

## Installation

1. **Completely remove/disable** `reframework/autorun/weight_system_tweaks.lua` and any other inventory-weight mods before installing. Running both will conflict.
2. **Fully restart the game** (not just REFramework reload) to recover unmodified item weight parameters from previous mods.
3. Install `reframework/autorun/burden_reforged.lua` from this directory into the game directory.
4. Open REFramework's Script Generated UI → **Burden Reforged**.

The config is saved to `reframework/data/BurdenReforged.json`. If it doesn't exist, the mod imports known safe booleans from `WeightSystemTweaks.json`, leaving that legacy file untouched.

## Behavior and architecture

- Category/subcategory rules for carried items; non-equipment mass can be disabled.
- Unequipped equipment can be weightless; equipped dragonforged gear receives the usual 50% modifier in the override calculation.
- Warfarer counts only the heaviest equipped weapon for each known hand slot, not every equipped weapon. Unknown slots are counted rather than silently discarded.
- Optional tooltip zeroes are **cosmetic database edits** only. The equipment tooltip option affects *all* equipment item descriptions, including equipped items; per-item equipped-state tooltips are not supported by this implementation.
- Event hooks queue weight refresh for **the Arisen and current party pawns**; a once-per-0.75-second fallback refresh handles missed events. The item manager’s `getPartyList()` is used first and `getPartyCharaIds(true)` is a guarded fallback (both signatures are present in owner-recorded TDB 83 introspection). Original item mass is cached and re-used after optional cosmetic database edits.
- Visual database modifications are restored on script reset, before the cache is cleared. Because updates to item parameters conflict with other mods that also mutate those values, do not combine them unless you understand load order.

## Known limitations

- Upgraded-equipment weight semantics and interactions introduced in October 2026 are **not yet comprehensively validated**. The owner's October 16 v0.1.2 report specifically verifies disappearance of missing-key log spam, not every item-weight scenario.
- Item dictionary iteration uses native `_entries` as exposed by current REFramework. A new game build may change layout. The live 2026-10-11 TDB83 item dump confirms related field names but not arbitrary future compatibility.
- On first startup, weight rules may begin applying after item/character managers initialize. v0.1.2 tests dictionary membership before accessing a per-character inventory or weight entry, so normal missing pawn keys do not flood REFramework with managed exceptions. Transient misses retry on the periodic refresh rather than every frame. If dictionary ContainsKey is not supported, this hotfix skips unsafe reads and logs one warning; investigate the changed API rather than bypassing the guard. Pawn inventory lists can be temporarily unavailable while pawns load or depart; the UI now reports `Party weights refreshed: N/M` for diagnosis.
- Disabling the mod computes a simple unmodified-item-base-weight sum to restore baseline behavior; it does not reproduce undocumented game-side weight special cases.
- If the REFramework script is forcibly interrupted before `on_script_reset` runs, database tooltip patches can linger until the game fully restarts.

## Minimum game-side test plan

1. Start a fully restarted clean DD2 session and verify carried weight with one known consumable with mass > 0.
2. Toggle the master switch **with a full party**, and confirm the Arisen **and every pawn** return to expected carried weight after disabling (no stuck-at-zero pawns). Check the `Party weights refreshed: N/M` line in the mod UI; normally expect 4/4 with a full party.
3. Enable Magic Pockets, test equip/unequip, loot, consume, sell, deposit and withdraw.
4. Equip multiple Warfarer main-/off-hand weapons and verify the heaviest-per-hand behavior.
5. Dragonforge a weapon and verify effective weight vs unenhanced copy.
6. Toggle each tooltip option and verify displayed weight, then REFramework hot-reload and ensure original weight is intact.
7. Save/reload, switch scenes, and check `re2_framework_log.txt` for hook or field errors. **For the v0.1.2 regression:** keep Burden Reforged enabled and confirm the old `Dictionary<UInt32, List<StorageMasterData>>.get_Item` / `KeyNotFoundException` spam does not recur (owner confirmed this in the reported Oct 16 session). Also verify party inventory/weight values still update; clean logs alone cannot prove this.
8. Test with the October 2026 Dark Arisen expansion and Hard Mode. Verify pawn join/leave, transferring items between pawns, and restoring the native weights after disabling.

**License/provenance note:** The Nexus listing for Weight System Tweaks restricts redistribution and modification of that author's files. This package intentionally ships none of those files; do not reuse its screenshot or source code. Public GitHub access still counts as sharing source; make a repository private if you do not intend to publish it.
