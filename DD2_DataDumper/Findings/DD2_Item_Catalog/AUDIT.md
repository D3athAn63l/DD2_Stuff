# DD2 Data Dumper v5.1 — In-game Audit

Capture: 2026-10-11, TDB 83, using the user's `dd2_dumper2.zip`.

## Item enumeration

- Runtime collection: `System.Collections.Generic.Dictionary`2<System.Int32,app.ItemCommonParam>` (from `app.ItemManager._ItemDataDict`).
- First export: 1500 item IDs (`max-record-limit`).
- Resumed export: 652 additional item IDs (`end-of-dictionary`).
- Dictionary count: 2152; scanned entries: 2152; known skipped: 1500; invalid skipped: 0.
- Unique IDs: 2152; duplicates: 0; checkpoint contains every ID; completed=true.
- Source IDs have been merged and sorted ascending, without changing source field values.

This proves full enumeration of **that live dictionary at the time of capture**, not necessarily every game item, obtainable item, expansion entry, or archived resource.

## Item runtime types

- `app.ItemDataParam`: 988
- `app.ItemArmorParam`: 669
- `app.ItemWeaponParam`: 495

## Class lookup coverage

120 / 158 attempted lookups worked. There are 113 unique target names: 83 found, 30 absent from reflection under the exact names queried. Some names are repeated between categories; an absent guessed name does not establish that a system is absent.

| Group | Found | Targeted |
|---|---:|---:|
| affinity | 7 | 7 |
| characters | 11 | 11 |
| combat | 13 | 13 |
| enemies | 1 | 6 |
| enhance | 3 | 4 |
| enums | 9 | 17 |
| health | 7 | 7 |
| items | 9 | 12 |
| pawn_ai | 5 | 23 |
| performance | 10 | 10 |
| quests | 1 | 4 |
| shops | 3 | 3 |
| singletons | 25 | 25 |
| vocation | 9 | 9 |
| warfarer | 7 | 7 |

## Known limitations / next work

- Item rows include generic common fields but **do not contain subtype fields** such as weapon `_PhysicalAttack` / `_MagicAttack`, armor `_PhysicalDefence` / `_MagicDefence` / `_Special`, or consumable healing properties. The type-profile metadata confirms these fields exist, but individual values have not been exported.
- All 2,152 `_Weight` values in this export are 0. Treat weight values as unverified pending a direct field/accessor comparison in-game; do not interpret as true zero weights.
- The dump contains numeric IDs, not verified display names, descriptions, enhancement stats, modifier roll rules, or item validity/obtainability flags.
- Some missing class names look like guessed or older-style names: `app.WeaponType` and `app.ArmorType` are not exposed under those exact names. Use field-derived type discovery for the next revision.

**Recommendation:** do not reset the checkpoint or repeatedly export the same dictionary. For v5.2 add an explicit *Subtype Stat Pass* keyed by ID, optionally with separate output so the complete metadata corpus need not be dumped again.
