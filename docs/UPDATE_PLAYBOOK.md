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
| Choose Your Beloved | Locked NPC <=199; unlocked NPC >199; anti-loss, manual changes, NPC HUD and cross-save safeguards; v2.6 read-only Main Pawn 0–1000 display, centered heart-and-bar NPC/pawn HUD, short-dialogue hold, no stale value after unload and no Johanne writer interference |
| CompleteHealthRestoration | Regular HP and reduced-max HP recovery, pawn toggles, combat/pause gating, saved settings after restart |
| Data Dumper | Bounded type scan, item export uniqueness, checkpoint resume, JSON writer errors, field coverage |
| Burden Reforged | Arisen + pawn carried weights and enable/disable, equip/unequip, dragonforging, Warfarer, per-item tooltip values, persisted settings and hot-reload restoration. Run `python mods/BurdenReforged/tests/run_lua.py` for mocked regressions; owner confirmed full-party toggle recovery in v0.1.1. |

Never test risky save mutations without a backup.

## 4. Patch and document
Make the smallest necessary code fix, run local tests, then validate in real DD2. Preserve the historical raw JSONs and publish a **new dated snapshot**. Record reproduction, environment, what changed, exact files, simulated tests and observed in-game results in the PR.

For repository layout changes use [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md). Do not merge without the owner's approval.
