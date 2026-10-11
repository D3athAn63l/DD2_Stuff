# Equipment Research Probe v1.1 — complete enhancement table capture

**Captured in DD2 on 11 October 2026, 23:34 MYT.** User-provided `EQ Prove v1.1.zip`, SHA-256 `a0536ba99aaa23ea6f39e5a61d2bf1c14ccbe288bf2b8d0bfed17a34c0e3f3bf`. Original raw ZIP and derived CSV/JSON are **not yet committed to GitHub**; this audit describes them. TDB **83**, REFramework `d052e8fd3fd41d0a1a33394fcf6e6c19be39b1ee`.

## Complete and reconciled

| Result | Weapon | Armor | Total |
|---|---:|---:|---:|
| Dictionary keys | **180 / 180** | **288 / 288** | **468 / 468** |
| Array elements per key | **13 / 13** | **13 / 13** | — |
| Exported element records | 2,340 | 3,744 | **6,084** |
| Incomplete/truncated arrays | 0 | 0 | 0 |
| Missing elements / extraction errors | 0 | 0 | 0 |
| Keys also in v5.2 item catalog | **178 / 180** | **288 / 288** | **466 / 468** |

Both dictionaries stopped at `dictionary-exhausted`, not a sampling cap. The 180 shared weapon entries and 200 previously sampled armor entries have **identical first six element field values** to the owner's v1.0 weight-mod-disabled probe.

**Cross-dataset difference:** enhancement dictionary contains **weapon keys 1014 and 2008** that are not in the sampled 2,152-entry `_ItemDataDict`. Their 13-element enhancement arrays are complete. This may reflect out-of-scope, unspawned or otherwise absent base items; their status is *unverified*, and they must not be dropped or invented in the merged base catalog.

## Enhancement index structure (hypothesis, not proven enum mapping)

The 13 elements show a strong **4 × 3 + 1** layout:

| Array indices (zero-based) | Likely style | Observed stat pattern |
|---|---|---|
| 0–2 | Vermundian | Balanced physical and magick increases |
| 3–5 | Battahli | Physical-focused |
| 6–8 | Elven | Magick-focused |
| 9–11 | Dwarven | Significant `_Blow` / `_Shake` or `_BlowResistRate` additions |
| 12 | Wyrmfire | Separate larger physical/magick / defense increases |

Names are **inferences**: the patterns agree with the four smithing styles and Wyrmfire enhancement described by [RPG Site](https://www.rpgsite.net/guide/15664-dragons-dogma-2-equipment-enhancement-smithing-styles-you) and [Game8](https://game8.co/games/Dragons-Dogma-2/archives/448486). Before treating these labels as exact internal data, probe the `app.EnhanceType` enum and the game's array indexing / application logic or validate a known item against the upgrade UI.

**Do not sum all 13 records**. They represent alternative enhancement parameters. Whether each level is an incremental addition or cumulative total requires runtime validation. There are no material/currency recipes or EX/passive validity rules in this capture.

## Weight repeatability and system inventory

The probe's new 100-item weight sample exactly matches the prior **weight-mod-disabled** capture, including the same two zero-weight armor IDs, **6120 and 6121**. The other 98 are nonzero. This reinforces the paired A/B evidence in [EQUIPMENT_PROBE_V1_AUDIT.md](EQUIPMENT_PROBE_V1_AUDIT.md), rather than requiring a third weight experiment.

The systems inventory is unchanged: `EquipmentAbilityData` (176 reported abilities, 97 settings), 12 weapon and 3 armor special efficacy entries, appraisal item sets (69 all / 67 equipment), and an accessible `ExItemParams` object. **Only types/presence/counts have been captured** for these systems.

## Next investigation

Read-only extraction of:
1. `EquipmentAbilityData.Setting[]` entries (97) and relevant enum/static identifiers.
2. `ExItemParams` and appraisal tables, using introspection and bounded samples without arbitrary method calls.
3. Enhancement type enum and one known in-game enhancement to establish array index mapping and cumulative/incremental semantics.

Keep the v1.1 raw archive and normalized derived catalog unchanged as evidence. Installed DD2 Steam/executable build ID remains unverified.
