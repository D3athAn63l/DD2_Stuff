# DD2 Data Dumper v5.2 — live capture audit

**Input:** owner-supplied `DataDump_v5.2.zip` from 11 October 2026; capture spans 22:45–22:47 MYT. **Raw uploaded ZIP is not in the repository yet.** Original archive SHA-256: `5e7a022fa382671c7e3f1d739be7f73414593149844ff603b1034f70f978527e`.

## Results

| Measurement | Observed |
|---|---:|
| Loaded item dictionary entries | 2,152 |
| Distinct exported IDs | 2,152 |
| Detailed batch sizes | 1,000 + 1,000 + 152 |
| Duplicate IDs | 0 |
| Invalid/skipped entries | 0 |
| Extraction errors | 0 |
| Checkpoint | `completed = true`; `exportedCount = 2152` |
| `app.ItemWeaponParam` | 495 |
| `app.ItemArmorParam` | 669 |
| `app.ItemDataParam` | 988 |
| Basic type profile | 120 / 158 targeted names resolved |
| Equipment deep profile | 27 / 27 targeted names resolved |
| RE Engine TDB | 83 |

The checkpoint's exported ID list matches the exact 2,152 IDs across all three detailed batches. Every record has separate `common` and `specific` scalar field tables, and `expectedMissing` is null for all records.

**Field coverage:** 20 common fields per record; 24 weapon-specific fields (total 44), 31 armor-specific fields (total 51), and 13 other-item-specific fields (total 33). Weapon physical/magic attack fields are present on all 495 weapons; physical/magic defense fields are present on all 669 armor records.

**Unresolved:** raw `common._Weight` is **zero for all 2,152 records**, even where the other stats are meaningful. This is not evidence that DD2 gear is truly weightless; check alternate getter `app.ItemCommonParam.get_WeightF()`, runtime item overrides or manager behavior in a later focused diagnostic.

**Important mod-interference hypothesis:** the repo's `mods/WeightSystemTweaks/reframework/autorun/weight_system_tweaks.lua` calls `param:set_field("_Weight", target)` on entries in the **same** `_ItemDataDict` collection, with zero targets controlled by the `Visuals_ShowZeroFor*` settings. If this or another inventory/weight mod was installed while dumping, the exported values could be *post-mutation runtime values* rather than vanilla data. Defaults in that script do not zero all equipment, so this does **not** establish the cause. For a clean reference, compare a short read-only weight sample with the weight mod disabled and avoid bulk re-export until behavior is understood.

## Environment

The capture reports **REFramework `d052e8fd3fd41d0a1a33394fcf6e6c19be39b1ee`**, built **11 October 2026 01:52**—newer than the September `d1461375...` used by the affinity and health baselines. TDB is unchanged at 83. The Steam/executable build ID is still unverified.

## Limits

This is **every entry exposed by the sampled live `app.ItemManager._ItemDataDict`**, not a guarantee of every bundled asset, DLC item, enhancement table, or EX/passive affix option. Type profiles identify API shapes, not necessarily valid gameplay combinations.

## Proposed storage for the raw data

Add the original owner-provided `DataDump_v5.2.zip` under this directory, or commit its three detailed batch JSONs plus checkpoint and type-profile JSONs. Keep the original bytes and hash. A merged, normalized catalog should be a **derived** file stored alongside it, never a silent replacement.
