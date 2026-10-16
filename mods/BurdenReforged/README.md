# Burden Reforged — experimental 0.1.2

An independently authored, feature-oriented REFramework weight rule mod for Dragon's Dogma 2. Inspired by the gameplay idea behind **Weight System Tweaks** (original Nexus #415, by **lingsamuel**); does not include or claim authorship of the original source or images. Not affiliated with the original author.

**Status:** v0.1.2 hotfix candidate: guarded party storage/weight dictionary lookups and throttled retries for pawn transition states. Owner confirmation in live game is pending. Owner confirmed basic master enable/disable worked in v0.1.0, but reported stale zero pawn weights when disabled. **Owner confirmed v0.1.1 now restores pawns' carried weights correctly when toggled off in-game.** Other features remain subject to further hands-on regression tests. Back up your DD2 save and `reframework/data` first.

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

- The game may report original mass differently for upgraded equipment and changes introduced in October 2026; runtime behavior is **not tested**.
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
7. Save/reload, switch scenes, and check `re2_framework_log.txt` for hook or field errors.
8. Test with the October 2026 Dark Arisen expansion and Hard Mode. Verify pawn join/leave, transferring items between pawns, and restoring the native weights after disabling.

**License/provenance note:** The Nexus listing for Weight System Tweaks restricts redistribution and modification of that author's files. This package intentionally ships none of those files; do not reuse its screenshot or source code. Public GitHub access still counts as sharing source; make a repository private if you do not intend to publish it.
