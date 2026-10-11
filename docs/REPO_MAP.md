# DD2_Stuff — Repository Map

Navigation for future ChatGPT/Codex sessions. **Paths below were checked on the repository's `main` branch on 11 October 2026.** This is an index, not a substitute for reading the code.

## Projects at a glance

| Area | Editable Lua | Notes / references | Installable archive |
| --- | --- | --- | --- |
| Choose Your Beloved | [BelovedCap.lua](../Choose%20Your%20Beloved/reframework/autorun/BelovedCap.lua) | [Affinity baseline](../Choose%20Your%20Beloved/DD2_API_Baseline_2026-10-11_v1.2_Confirmed/README.md) | `Choose Your Beloved/Choose_Your_Beloved_v2.1_Standalone_Experimental.zip` |
| Complete Health Restoration | [CompleteHealthRestoration.lua](../Loss%20Gauge/CompleteHealthRestoration.lua) | [Health baseline](../Loss%20Gauge/DD2_Health_API_Baseline_2026-10-11_Confirmed/README.md) | `Loss Gauge/CompleteHealthRestoration_v2.0_Standalone_Experimental.zip` |
| DD2 Data Dumper | [DD2_DataDumper.lua](../DD2_DataDumper/reframework/autorun/DD2_DataDumper.lua) | [Project README](../DD2_DataDumper/README.md), [test plan](../DD2_DataDumper/TEST_PLAN.md) | `DD2_DataDumper/DD2_DataDumper_v5.2_Experimental_Installable.zip` |
| WeightSystemTweaks | [weight_system_tweaks.lua](../WeightSystemTweaks/reframework/autorun/weight_system_tweaks.lua) | `WeightSystemTweaks/modinfo.ini` | No separate ZIP visible at audit |

## Affinity / Choose Your Beloved

The gameplay script is **not** the same thing as the read-only probe.

- Main source: `Choose Your Beloved/reframework/autorun/BelovedCap.lua`.
- Metadata and release notes: `Choose Your Beloved/modinfo.ini`, `CHANGELOG_v2.1.txt`.
- **Authoritative pre-update runtime snapshot:** `Choose Your Beloved/DD2_API_Baseline_2026-10-11_v1.2_Confirmed/snapshots/Beloved_API_Probe_20261011_172358.json`.
- Reflective probe: the same baseline's `reframework/autorun/Beloved_API_Probe.lua`.
- Comparison tool: `compare_probes_v12.py`; gameplay checklist: `REGRESSION_CHECKLIST.md`.
- Metadata: TDB 83, 21 targeted overload signatures resolved, REFramework commit `d1461375...`. Final beloved-selection logic and cross-save safety are **not proved by reflection**.

## HP / Loss Gauge

- Gameplay source: `Loss Gauge/CompleteHealthRestoration.lua` (v2.0).
- **Authoritative read-only capture:** `Loss Gauge/DD2_Health_API_Baseline_2026-10-11_Confirmed/baseline/Health_API_Probe_20261011_180252.json`.
- Reference: `reference/HEALTH_API_REFERENCE.md` inside that baseline.
- Probe: `reframework/autorun/Health_API_Probe.lua`; comparator: `compare_health_probes.py`.
- TDB 83, 19 targeted overload signatures resolved; actual recovery reported working by owner, not invoked by the read-only probe.
- Note that the loose Lua file is directly in `Loss Gauge/`; the ZIP uses its own installable layout.

## DD2 Data Dumper / findings

- Main script: `DD2_DataDumper/reframework/autorun/DD2_DataDumper.lua` (v5.2 experimental).
- Usage instructions: `DD2_DataDumper/README.md`; tests: `TEST_PLAN.md`.
- Offline merger and comparator scripts: `DD2_DataDumper/tools/` (especially `merge_items.py`, `merge_detail.py`, `compare_profiles.py`, `run_mock_tests.py`, `run_detail_tests.py`).
- Large runtime/type snapshots: `DD2_DataDumper/Findings/DD2Dumper_20261011_215132_004_types_*.json`; an accompanying run report is also present.
- Basic item catalog: `DD2_DataDumper/Findings/DD2_Item_Catalog/DD2_Items_2152_Merged.json` and `DD2_Items_2152_Catalog.csv`; [catalog audit](../DD2_DataDumper/Findings/DD2_Item_Catalog/AUDIT.md).
- Observed in v5.1: **2,152 unique dictionary entries** (495 weapon-type, 669 armor-type, 988 other item-data objects). Not an exhaustive claim about assets or DLC.
- v5.2 detailed item export has **not been validated in the live game** in this snapshot. Do not treat reflected field names as actual modifier pools or valid roll combinations.

## WeightSystemTweaks

- Source: `WeightSystemTweaks/reframework/autorun/weight_system_tweaks.lua`.
- Metadata: `WeightSystemTweaks/modinfo.ini`.
- **Mismatch needing audit:** source header says v3.0; metadata says `2.2-GeminiFix`. Avoid guessing which should be released.
- Original/contributor credit is described in the Lua header; preserve attribution if modifying this project.

## What gets installed?

- Runnable gameplay mods are the source Lua files in each respective project, installed under the target game's `reframework/autorun/` (or their distribution ZIPs).
- Read-only probes inside baseline archives are **diagnostic tools**, not dependencies for the gameplay mods.
- `Findings/`, `tools/`, CSV/JSON captures, and documentation are not game installation requirements.
- Avoid copying whole repository folders to the game installation indiscriminately.

## After a game update

See [UPDATE_PLAYBOOK.md](UPDATE_PLAYBOOK.md). First collect the exact game build + REFramework version, rerun the existing probes, compare like versions, then test *behavior* in game. Preserve both old and new captures.
