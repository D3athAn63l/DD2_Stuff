# DD2 / REFramework Update Playbook

## 1. Freeze the environment
Before changing Lua, record the game's exact executable or Steam build, REFramework commit, RE Engine TDB version, reproducer and whether older captures were made on a different revision. Back up saves and `reframework/data/`.

As of 11 Oct 2026, the verified affinity/health baselines used TDB 83, REFramework `d1461375...` (16 Sep); the new item dump also used TDB 83 but REFramework `d052e8fd...` (11 Oct). The actual game's executable build remains unverified.

## 2. Run the *same* read-only probes
- Affinity: `research/baselines/affinity/2026-10-11/reframework/autorun/Beloved_API_Probe.lua`. Compare with `research/baselines/affinity/2026-10-11/snapshots/Beloved_API_Probe_20261011_172358.json` using `compare_probes_v12.py` in that baseline folder.
- HP / Loss Gauge: `research/baselines/health/2026-10-11/reframework/autorun/Health_API_Probe.lua`. Compare with `research/baselines/health/2026-10-11/baseline/Health_API_Probe_20261011_180252.json` using `compare_health_probes.py` from there.
- DataDumper: use `tools/DD2DataDumper/reframework/autorun/DD2_DataDumper.lua` only when needed. Inspect output for actual new field types, completeness and write errors.

A missing method reported by a failed enumeration is unresolved, *not proven removed*. Unchanged signatures do not guarantee working game behavior.

## 3. Behavioral regression checklist
| Component | Minimum hands-on verification |
|---|---|
| Choose Your Beloved | Stable v3.0 native interaction/dialogue speaker affinity (NPC + Main Pawn), no floating heart HUD; owner-accepted previous Alpha 2 in-game. Locked NPC <=199; unlocked NPC 199→299 exemption including Ulrika fix, anti-loss/manual settings; Main Pawn 0–1000 remains read-only; standalone pawn toast, menu guard and legacy config migration. Run `test_main_pawn.lua`, `test_unlock_rules.lua`, `test_native_ui.lua` via `tests/run_lua.py`. |
| CompleteHealthRestoration | Regular HP and reduced-max HP recovery, pawn toggles, combat/pause gating, saved settings after restart |
| Data Dumper | Bounded type scan, item export uniqueness, checkpoint resume, JSON writer errors, field coverage |
| Burden Reforged | Arisen + pawn carried weights and enable/disable, equip/unequip, dragonforging, Warfarer, per-item tooltip values, persisted settings and hot-reload restoration. Run `python mods/BurdenReforged/tests/run_lua.py` for mocked regressions; owner confirmed full-party toggle recovery in v0.1.1 and reported that v0.1.2 eliminates the repeating missing-key exceptions. |

### Burden Reforged managed-dictionary regression (16 October 2026)

- **Failure, v0.1.1:** `StorageDict:get_Item(characterID)` could be called for a pawn whose ID was present in a party list but absent from `StorageDict`. A managed `Dictionary<UInt32, List<app.ItemManager.StorageMasterData>>.get_Item` `KeyNotFoundException` still appeared in the REFramework log despite surrounding Lua `pcall`. Partial refresh also left `weightDirty` set, leading to repeated work every frame.
- **Fix, v0.1.2:** Check `ContainsKey` before `get_Item` on both storage and weight dictionaries; initialize missing weight entries using `set_Item`; let missing storage entries retry on the normal 0.25/0.75-second refresh interval rather than every frame. Unknown dictionary membership fails closed instead of probing an unsafe key.
- **Owner verification:** A/B isolation showed v0.1.1 was responsible for the exception flood. After installing v0.1.2, the owner reported normal operation with **no more missing-key spam** on 16 October 2026. No post-fix raw log is attached to this documentation; do not infer broader performance or complete weight-rule validation.
- **Future game update test:** With Burden Reforged enabled, inspect the log across game startup and pawn joins/leaves, compare exception counts, verify `Party weights refreshed: N/M`, and confirm the Arisen and each available pawn's *actual* carried weight changes correctly. A clean error log is necessary but not sufficient for full behavioral verification.

Never test risky save mutations without a backup.

## 4. Patch and document
Make the smallest necessary code fix, run local tests, then validate in real DD2. Preserve the historical raw JSONs and publish a **new dated snapshot**. Record reproduction, environment, what changed, exact files, simulated tests and observed in-game results in the PR.

For repository layout changes use [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md). Do not merge without the owner's approval.
