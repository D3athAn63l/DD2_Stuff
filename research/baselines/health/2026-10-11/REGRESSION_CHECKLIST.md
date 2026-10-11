# CompleteHealthRestoration — Post-update regression checklist

Use after a future DD2 patch even if the health probe shows no API changes.

- [ ] REFramework starts; no new Lua errors in `re2_framework_log.txt`.
- [ ] `Health_API_Probe.lua` saves a JSON with a valid player and Hit controller class after entering gameplay.
- [ ] Compare latest snapshot against the **same-version** v1.0 baseline; investigate method signatures, field types, and access paths that change.
- [ ] HP heals while out of combat, with `AutoHealEnable` on.
- [ ] HP heals at the intended combat multiplier (if the option is on).
- [ ] A damaged **Loss Gauge** recovers toward the original maximum, not just current HP.
- [ ] Reduced maximum HP stays recovered after multiple in-game update ticks.
- [ ] Pawn HP and gauge recovery work (Arisen/pawn toggles independent).
- [ ] No healing occurs for incapacitated characters (zero HP).
- [ ] Pause gating and battle restrictions behave as configured.
- [ ] Disable HP healing and check it really stops; keep gauge on and check it still works.
- [ ] Disable gauge restoration and check that only normal HP restoration occurs.
- [ ] Change a setting, exit/relaunch DD2, and check persistence from `reframework/data/CompleteHealthRestoration.json`.
- [ ] Ensure no competing HP-regeneration mod is loaded during testing.

**Interpretation:** Passing API reflection does not replace live behavior testing. The probe deliberately does not invoke setters, install hooks, or alter settings.


## Confirmed pre-patch fingerprint (2026-10-11)

- Probe version: **1.0**; **8 types / 19 resolved method signatures**.
- TDB: **83**; REFramework commit `d1461375aee4ec3f313170f8eaad12064eb542d9`.
- Hit controller: `app.Character.<Hit>k__BackingField` → `app.HitController`.
- Loss Gauge setter: `app.HitController.set_ReducedMaxHp(System.Single) → System.Void`.
- HP setter: `app.HitController.setHpValue(System.Single, System.Boolean) → System.Void`.
- Captured original JSON: `baseline/Health_API_Probe_20261011_180252.json`.
- **Known gap:** installed DD2 executable/Steam build ID not captured; Settings persistence must be verified through a restart, not reflection.
