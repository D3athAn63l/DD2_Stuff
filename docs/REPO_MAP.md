# Repository Map — DD2_Stuff

All paths are relative to the repository root. Updated for the folder-only refactor on 11 October 2026. **Source, diagnostics, captures and ZIPs have different purposes.**

## Playable mods (`mods/`)

| Mod | Working/source entry | Other files |
|---|---|---|
| Choose Your Beloved | [`BelovedCap.lua`](../mods/ChooseYourBeloved/reframework/autorun/BelovedCap.lua) | `mods/ChooseYourBeloved/modinfo.ini`, `CHANGELOG_v2.1.txt`, `Cover.png` |
| CompleteHealthRestoration | [`CompleteHealthRestoration.lua`](../mods/CompleteHealthRestoration/reframework/autorun/CompleteHealthRestoration.lua) | Original release ZIPs live in `releases/CompleteHealthRestoration/` |
| WeightSystemTweaks | [`weight_system_tweaks.lua`](../mods/WeightSystemTweaks/reframework/autorun/weight_system_tweaks.lua) | `modinfo.ini`, `Cover.png`; Lua header v3.0 conflicts with metadata v2.2-GeminiFix |

The Lua paths inside the mod folders mirror the real `reframework/autorun/` location used inside the game. The Health mod's loose file was normalized to that layout without changing its contents.

## Data dumper and its tools (`tools/`)

- [Dumper README](../tools/DD2DataDumper/README.md) and [test plan](../tools/DD2DataDumper/TEST_PLAN.md).
- Executable inspector script: `tools/DD2DataDumper/reframework/autorun/DD2_DataDumper.lua`.
- Offline scripts/test harnesses: `tools/DD2DataDumper/tools/`.
- Mod metadata: `tools/DD2DataDumper/modinfo.ini`.
- The first simple item catalog used v5.1, **tested in-game**. v5.2 detailed extraction subsequently succeeded; see [v5.2 audit](../research/dumps/items/2026-10-11/detailed-v5.2/AUDIT.md).

## Confirmed API baselines (`research/baselines/`)

| Domain | Baseline directory | Authoritative live JSON | Comparison script |
|---|---|---|---|
| Affinity | [affinity/2026-10-11](../research/baselines/affinity/2026-10-11/README.md) | `snapshots/Beloved_API_Probe_20261011_172358.json` | `compare_probes_v12.py` |
| HP / Loss Gauge | [health/2026-10-11](../research/baselines/health/2026-10-11/README.md) | `baseline/Health_API_Probe_20261011_180252.json` | `compare_health_probes.py` |

Read-only probes are stored in each baseline's `reframework/autorun/` directory. They are **not gameplay-mod dependencies**. TDB 83 and the September 2026 REFramework revision were captured; no exact Steam build ID was recorded.

## Captured research (`research/dumps/`)

- Original type profiler outputs: `research/dumps/runtime/2026-10-11/DD2Dumper_20261011_215132_004_types_*.json` and adjacent reports.
- 2,152-ID basic catalog: [`research/dumps/items/2026-10-11/basic-catalog/`](../research/dumps/items/2026-10-11/basic-catalog/AUDIT.md) with `DD2_Items_2152_Merged.json`, `DD2_Items_2152_Catalog.csv`, profiling result tables and source ZIP.
- New detailed capture (user supplied): [`research/dumps/items/2026-10-11/detailed-v5.2/AUDIT.md`](../research/dumps/items/2026-10-11/detailed-v5.2/AUDIT.md). The original user-uploaded `DataDump_v5.2.zip` is **not yet committed** to GitHub; this is its audit.
- The loaded dictionary is not guaranteed to contain every DLC, offline resource, enhancement recipe or valid EX/passive modifier.

## Release artifacts (`releases/`)

`releases/ChooseYourBeloved/`, `releases/CompleteHealthRestoration/`, `releases/DD2DataDumper/`. These contain the **existing, unchanged** installation and source/test ZIPs. They are historical artifacts and may be experimental; consult the loose Lua code before modifications.

## Before/after update

Follow [UPDATE_PLAYBOOK](UPDATE_PLAYBOOK.md), not only method-name checks. For previous folder locations, see [MIGRATION_GUIDE](MIGRATION_GUIDE.md). Do not install every probe or dump as a gameplay mod.
