# Paired Equipment Research Probe v1.0 results — 11 October 2026

Two live-captured ZIPs compared: `EQ Probe v1.zip` (23:19–23:20 MYT) and `EQ Probe v1_WeightModDisabled.zip` (23:23 MYT). The original ZIPs are **not committed** by this PR. Both were made under TDB **83**, REFramework `d052e8fd3fd41d0a1a33394fcf6e6c19be39b1ee`.

## Weight A/B comparison

The two weight snapshots sampled **the same 100 item IDs in the same order**: 35 weapons, 35 armor, 30 other.

| Outcome | Normal modded run | WeightModDisabled run |
|---|---:|---:|
| `_Weight == 0` | 100 / 100 | 2 / 100 |
| `_Weight != 0` | 0 / 100 | 98 / 100 |
| Largest raw weight | 0 | 659 (getter = 6.59 kg) |
| Item ID 600 | 0 | 15 (getter = 0.15 kg) |

All three access paths agreed within each run: raw `_Weight`, `get_Weight()`, and `get_WeightF()` (the float gives kg). The only items still zero in the disabled run were **armor IDs 6120 and 6121**.

**Inference:** this strongly supports the active weight-changing mod (or its interaction with other mods/settings) causing the earlier all-zero item dump. It does *not* isolate the particular setting or prove how the process was restarted. The current `WeightSystemTweaks` source writes `_Weight` in the same live `_ItemDataDict`.

## Enhancement dictionaries

Both captures produced **identical sampled enhancement rows**. These are meaningful stat increments, not just reflection signatures.

| Field | Weapon enhancements | Armor enhancements |
|---|---:|---:|
| Dictionary entries available | 180 | 288 |
| Dictionary keys captured by v1.0 | **180** | **200** |
| Elements per entry reported | **13** | **13** |
| Elements captured per entry | **6** | **6** |
| Stop reason | `dictionary-exhausted` | `sample-cap-reached` |

v1.0 therefore captured 1,080 weapon parameter elements and 1,200 armor elements. It omitted 1,260 more weapon and 2,544 armor elements from the observed tables. **Not complete** for enhancement content.

A new **v1.1 experimental probe** was prepared offline to capture up to 500 dictionary entries and up to 32 elements each (expected 180×13 and 288×13), 4 keys/frame, with per-array completeness diagnostics. It passed Lua syntax and simulated 288×13 testing; **it is not yet verified in-game, and its source/release is not committed by this PR**.

## Other equipment data (presence and sizes only)

- `EquipmentAbilityData`: `AbilityNum=176`, `Settings` array **97**.
- `WeaponSpecialEfficacyParam`: **12** entries; `ArmorSpecialEfficacyParam`: **3** entries.
- `AllAppraisalItemSet`: **69**; `EquipAppraisalItemSet`: **67**.
- `ExItemParams`, `AppraisalItemInfo`, and `AppraisalItemDropWeight`: objects exist but their contents were not extracted.

These are **investigation targets**, not evidence of valid random EX/passive rolls, offline recipe requirements, or online pawn eligibility.

## Provenance

- `EQ Probe v1.zip` SHA-256: `b865d9c142d314b929c29e514caa0c70c2740e55697075015d7d074f8a9c9173`
- `EQ Probe v1_WeightModDisabled.zip` SHA-256: `cb444087ed5e1517e2a63c1dc20c5612458ad685925efe1b685ba0261aaf76cf`

Keep the two original files for future comparisons. The read-only probe never invoked game setters. Installed DD2 executable/Steam build remains unverified.
