# DD2 Data Dumper v5.2 — Equipment Findings (11 Oct 2026)

## Provenance and limits

Based on the owner's **live in-game** `DataDump_v5.2.zip` (captures at 22:45–22:47 MYT). The original raw ZIP and full derived datasets were analyzed offline but **are not uploaded by this PR**; do not represent this file as a complete, checked-in item catalog. Existing [base catalog](../basic-catalog/AUDIT.md) remains the cross-check. RE Engine TDB **83**; REFramework commit `d052e8fd3fd41d0a1a33394fcf6e6c19be39b1ee` (11 Oct 2026); installed DD2 Steam build still unverified.

## Verified v5.2 output

- **2,152 distinct item IDs** across 3 detailed batches (**1000 + 1000 + 152**); completed checkpoint, zero ID duplicates and reported errors.
- Runtime parameter types: **495** `app.ItemWeaponParam`, **669** `app.ItemArmorParam`, **988** `app.ItemDataParam`.
- **27/27** additional equipment type names found by the `equipment_deep` profile. A class being exposed does not guarantee a live data table or safe modifier assignment.

| Field | Nonzero records | Raw value range |
|---|---:|---:|
| Weapon `_PhysicalAttack` | 429/495 | 0–1350 |
| Weapon `_MagicAttack` | 230/495 | 0–1370 |
| Weapon `_Element` | 18/495 | 0–4 |
| Armor `_PhysicalDefence` | 484/669 | 0–560 |
| Armor `_MagicDefence` | 485/669 | 0–590 |
| Armor `_Special` | **74/669** | 0–59 |
| Armor `_SpecialValue` | 54/669 | 0–200 |

Those **74 armor items with nonzero `_Special`** are worth investigating. Reflection identifies `_Special` as `app.EquipSpecial`; it does **not** yet tell us the UI labels, whether the effect is randomized, or if it occupies a Dark Arisen EX/passive roll slot. Example: item **10400** has 480 physical defense, 430 magick defense, `_Special=12` and `_SpecialValue=200` in the captured base parameters.

## The zero-weight anomaly

**All 2,152 raw `common._Weight` values are zero**. The class profile confirms `app.ItemCommonParam._Weight : System.Int16` and both getters:

- `get_Weight() -> System.Int32`
- `get_WeightF() -> System.Single`

The live `WeightSystemTweaks` source (in `mods/WeightSystemTweaks/`) **writes** `_Weight` on the same `_ItemDataDict` entries to change tooltip display. If a weight/tooltip mod was active, captured values could already have been modified; the current source's default options do not alone explain *all* equipment being zero. **Hypothesis, not an established cause.**

Follow-up: compare raw field and both getters in a fresh game restart with and without weight-altering mods. Do not assume the existing zeroes are canonical weights.

## Actual enhancement data sources discovered

The v5.2 **type inventory** (not runtime dictionary contents) reveals:

- `app.ItemManager._WeaponEnhanceDict : Dictionary<System.Int32, app.WeaponEnhanceParam[]>`
- `app.ItemManager._ArmorEnhanceDict : Dictionary<System.Int32, app.ArmorEnhanceParam[]>`
- `getWeaponEnhanceData(System.Int32, app.EnhanceType, System.Int32) -> app.WeaponEnhanceParam`
- `getArmorEnhanceData(System.Int32, app.EnhanceType, System.Int32) -> app.ArmorEnhanceParam`

Weapon enhancement param types expose 18 stat fields and armor enhancement types expose 22. Those data-table contents are **not** in the existing v5.2 export.

## Additional relevant leads (not validated roll rules)

`app.ItemManager` also exposes `EquipmentAbilityData`, `AppraisalItemInfo`, `EquipAppraisalItemSet`, `AppraisalItemDropWeight`, `CrystalWeaponParamSeedDict`, and `ExItemParams`. These identify promising areas for future read-only targeted dumps. They **do not prove** valid EX/passive equipment slot combinations or online validation rules.

## Recommended next experiment

Use a **separate on-demand, read-only probe** for (1) 100 sampled item weight getters, (2) bounded weapon and armor enhancement dictionary samples, and (3) equipment ability/appraisal table *presence and sizes*. Preserve v5.2, avoid gameplay setters/hooks, and do not attempt arbitrary gear edits while validity conditions remain unknown.

See [v5.2 AUDIT](AUDIT.md), and the [repository map](../../../../../docs/REPO_MAP.md). No Lua gameplay changes in this research note.
