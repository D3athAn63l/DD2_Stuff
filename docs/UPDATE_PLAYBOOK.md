# DD2 / REFramework Update Playbook

Use this after a game patch, a REFramework update, or a previously working mod regression.

## 1. Freeze and identify the environment

Record the date, Steam game build/executable version or hash, REFramework revision, RE Engine TDB, relevant Lua/mod versions, and crash/reproduction steps. Back up saves and `reframework/data/` before modifying files. The 11 October 2026 reference has **TDB 83** and REFramework `d1461375aee4ec3f313170f8eaad12064eb542d9`; the installed DD2 executable build was **not** established.

## 2. Compare APIs without modifying game state

For **affinity**, reuse `Choose Your Beloved/DD2_API_Baseline_2026-10-11_v1.2_Confirmed/reframework/autorun/Beloved_API_Probe.lua` and compare with `snapshots/Beloved_API_Probe_20261011_172358.json` using `compare_probes_v12.py`.

For **HP/Loss Gauge**, reuse `Loss Gauge/DD2_Health_API_Baseline_2026-10-11_Confirmed/reframework/autorun/Health_API_Probe.lua` and compare with `baseline/Health_API_Probe_20261011_180252.json` using `compare_health_probes.py`.

Do not infer that a method vanished if enumeration failed. Compare identical probe versions where possible; a changed probe can reveal metadata previously hidden without any game change.

## 3. Reproduce gameplay separately

| System | Minimum behavioral checks |
| --- | --- |
| Beloved | Locked NPC capped at 199; unlocked NPC can exceed 199; anti-loss and manual reductions; HUD; save reload/new playthrough isolation |
| Health | Regular HP regeneration; reduced-max HP recovery; pawn toggles; combat and pause settings; settings persist after restart |
| Dumper | Single bounded profile; small item batch; ID dedup/restart resume; JSON write failure reported; detailed export coverage before bulk use |
| Weight | Default and modified weights; equip/unequip, Warfarer; dragonforging behavior; changing config and restarting |

A matching API snapshot **does not** certify these outcomes. Use expendable test saves for risky changes.

## 4. Change narrowly, verify, record

Patch the smallest broken path, retain config compatibility, run available Lua syntax/mock tests, and then have the owner verify the actual DD2 session. Capture errors and before/after behavior. Don't silently change gameplay balance or mix in unrelated feature additions.

Record findings in an issue/PR with: build identifiers, precise script paths, API delta, reproduction, observed results, tests performed, remaining uncertainty and any migration steps. Add a new dated baseline rather than altering the original snapshot.

## 5. Review before release

Keep README, changelog and mod metadata aligned; check installation paths, dependencies, credits, and archive contents. Prefer a reviewable PR; do not merge without the owner's approval.
