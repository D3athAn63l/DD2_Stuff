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
| Choose Your Beloved | Locked NPC <=199; unlocked NPC >199; anti-loss, manual changes, NPC HUD and cross-save safeguards; v2.7 read-only Main Pawn 0–1000 display, centered heart-and-bar NPC/pawn HUD, short-dialogue hold, shop/menu suppression, no stale value after unload and no Johanne writer interference |
| CompleteHealthRestoration | Regular HP and reduced-max HP recovery, pawn toggles, combat/pause gating, saved settings after restart |
| Data Dumper | Bounded type scan, item export uniqueness, checkpoint resume, JSON writer errors, field coverage |
| Pocket Universe | Confirm 3 weight getter hooks + 6 rank hooks install; toggle ON/OFF across full party, item pickup and transfers, native restoration, no repeating errors, and whether overflow still sends loot to storage. Run `python mods/PocketUniverse/tests/run_lua.py`. Online safety and storage redirection remain unverified. |

### Historical Burden Reforged managed-dictionary regression (16 October 2026; archived under history/BurdenReforged/v0.1.2/)

- **Failure, v0.1.1:** `StorageDict:get_Item(characterID)` could be called for a pawn whose ID was present in a party list but absent from `StorageDict`. A managed `Dictionary<UInt32, List<app.ItemManager.StorageMasterData>>.get_Item` `KeyNotFoundException` still appeared in the REFramework log despite surrounding Lua `pcall`. Partial refresh also left `weightDirty` set, leading to repeated work every frame.
- **Fix, v0.1.2:** Check `ContainsKey` before `get_Item` on both storage and weight dictionaries; initialize missing weight entries using `set_Item`; let missing storage entries retry on the normal 0.25/0.75-second refresh interval rather than every frame. Unknown dictionary membership fails closed instead of probing an unsafe key.
- **Owner verification:** A/B isolation showed v0.1.1 was responsible for the exception flood. After installing v0.1.2, the owner reported normal operation with **no more missing-key spam** on 16 October 2026. No post-fix raw log is attached to this documentation; do not infer broader performance or complete weight-rule validation.
- **Future game update test:** With Burden Reforged enabled, inspect the log across game startup and pawn joins/leaves, compare exception counts, verify `Party weights refreshed: N/M`, and confirm the Arisen and each available pawn's *actual* carried weight changes correctly. A clean error log is necessary but not sufficient for full behavioral verification.

Never test risky save mutations without a backup.

## 4. Patch and document
Make the smallest necessary code fix, run local tests, then validate in real DD2. Preserve the historical raw JSONs and publish a **new dated snapshot**. Record reproduction, environment, what changed, exact files, simulated tests and observed in-game results in the PR.

For repository layout changes use [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md). Do not merge without the owner's approval.

### Pocket Universe runtime override test (18 October 2026)

- The new implementation hooks two `getStorageWeight` float overloads, one integer weight getter, and six rank overloads without editing `WeightDict` or item parameters. Some game logic may bypass these methods.
- Earlier owner-tested rank-hook prototype changed all four party rank labels at 60/61/90/91 thresholds and to Very Heavy at 0/0/0/5. **This is not a live test of the new Pocket Universe weight hooks.**
- Verify item pickup over-cap and actual storage redirection, and inspect log after pawn load/unload. Disable in REFramework and verify native results, then fully restart when changing older mods that changed item definitions.
