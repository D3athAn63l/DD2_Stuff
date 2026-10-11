# Dragon's Dogma 2 — Data Dumper v5.2 Experimental

**Status: simulated tests passed; no live v5.2 game validation yet.** Built from the user's known-working v5.1 script and 11 October 2026 runtime profile (TDB 83). The base item dictionary had 2,152 unique IDs: 495 weapon parameter objects, 669 armor objects, 988 consumable/data objects.

## What changed

- New **Export NEXT detailed batch (1000 IDs)**. Exports all scalar/enum-like fields that runtime reflection can access on each parameter object's class and parent classes. Uses the existing dictionary's *real* ID as its key; stores common and subtype fields separately.
- Explicit fallbacks for known fields, including `_PhysicalAttack`, `_MagicAttack`, `_Element`, `_StaminaReduce`, `_PhysicalDefence`, `_MagicDefence`, `_Special`, `_SpecialValue`, `_SpecialValue2`, `_SpecialValue3`, `_HealWhiteHp`, `_HealBlackHp` and other item data.
- New **Profile equipment / enhancement / drop type schemas** targets 26+ classes, including `app.WeaponEnhanceParam`, `app.ArmorEnhanceParam`, and several added/legacy item categories. This is schema *reflection*, not equipment enhancement / loot-table content extraction.
- Detailed export has its own checkpoint, **`DD2Dumper_v52_detail_progress.json`**. The existing `DD2Dumper_item_progress.json` (v5.1) is untouched, including its 2,152-item completed status. Can resume across sessions without relying on iteration order.
- Failed batch writes **do not** commit checkpoint IDs. A successful batch with failed checkpoint save can be imported from the recovery dropdown if the current checkpoint still has the matching `runId`.
- Bounded scanning at **16 dictionary entries per frame**, batches limited to 1000 new IDs. Heavy work only starts when the player presses a button. No `sdk.hook()`, `set_field`, `set*` calls, game-state writes or asset extraction.
- Python `tools/merge_detail.py` turns detailed batches (ZIP or JSON) into a single JSON, Excel-friendly CSV and an audit report, optionally comparing IDs against the old 2,152-item catalog.

## Install

1. Back up `reframework/data/` JSON exports, especially your v5.1 checkpoint and first catalog files.
2. **Replace**, don't duplicate, `reframework/autorun/DD2_DataDumper.lua` from v5.1. Do not run old DataScraper v4.5 alongside this.
3. Load a save; open the REFramework UI. Under **DD2 Data Dumper 5.2-experimental**, click **Export NEXT detailed batch (1000 IDs)**.
4. Repeat until exhausted. With exactly the 2,152 currently exposed items this should produce batches of 1,000 + 1,000 + 152; that's a *prediction* for your game, not a verified live result. Do not assume the dictionary is fixed across builds.
5. Optionally click **Profile equipment / enhancement / drop type schemas** for a separate class-level schema JSON.
6. Send the `DD2Dumper_v52_detail_*_batch_*.json`, `DD2Dumper_v52_detail_progress.json`, and the `types_equipment_deep` JSON if you want a full audit.

All output goes into `<DD2>/reframework/data/` as flat JSON files. The importer for *old v5.0/v5.1* item IDs still exists but is **not needed** for the new detailed export. Importing old IDs would skip the new data, so detailed exports **always use a separate checkpoint**.

## Example offline merge

```bash
python tools/merge_detail.py dd2_v52_dumps.zip --base DD2_Items_2152_Merged.json --output DD2_Detailed_Items
```

Creates `DD2_Detailed_Items.json`, `DD2_Detailed_Items.csv`, and `DD2_Detailed_Items.audit.txt`. It refuses to merge conflicting IDs, multiple run IDs or TDB mismatches and doesn't overwrite existing files. For reference-only community item names, you may optionally download an ID/name JSON from **xyzkljl1/MyDD2Mod** and pass `--names <file>`; community names are never presented as verified live-game data.

## Known limitations / safety

- Items are sampled as loaded in the current `app.ItemManager._ItemDataDict`. **Not** every game resource, shop stock, DLC content, enhancement recipe or valid random roll is guaranteed present.
- Item data classes may have inaccessible or nested non-scalar fields. Those are intentionally omitted, not flattened arbitrarily. Inspect `expectedMissing` and batch diagnostics. Enum fields are only emitted if REFramework returns primitive values.
- Item weight readings were **all zero** in the earlier basic catalog. v5.2 captures raw fields but cannot automatically determine whether those zeroes are game semantics, version changes or accessor limitations.
- The class profiler also finds *field and method types*, not whether their calls execute as desired. Real enhancement tables and roll validity need a future targeted, read-only resource investigation.
- Running game reflection against large classes can cause stutter; start with a single detailed batch and save afterward.
- The save-writing helper checks the return value of `json.dump_file`, and batch checkpoint recovery requires matching run IDs.

## Community references (not bundled)

1. [xyzkljl1/MyDD2Mod](https://github.com/xyzkljl1/MyDD2Mod) — item IDs/names including DLC, NPC/enemy CSVs, skill Action Rates.
2. [Armor / Item / Weapon Data spreadsheet discussion](https://www.nexusmods.com/dragonsdogma2/mods/350?tab=posts) — historical April 2024 dumps shared in Modding Haven Discord.
3. [RE_RSZ (rszdd2.json)](https://github.com/alphazolam/RE_RSZ) — schema for offline RE Engine assets.
4. [DD2-Editor](https://www.nexusmods.com/dragonsdogma2/mods/522) — user asset editor with pre-extracted names; September 2026 update.
5. [Skill Action Rate spreadsheet discussion](https://www.reddit.com/r/DragonsDogma/comments/1vkuwrv/dragons_dogma_2_skill_action_rates_extracted_data/) — community extraction with author's validation caveat.

Please credit community creators and observe each project's redistribution terms. Nothing from their repositories is bundled with this mod.
