# Choose Your Beloved — In-Game Regression Checklist

Use a **backed-up or disposable save**, preferably with another affinity mod disabled. Do not assume visual success means affinity semantics are unchanged. Record PASS / FAIL / NOT TESTED with date, installed game build, REFramework revision, and Lua SHA.

| # | Procedure | Expected v2.1 result | Status |
|---|---|---|---|
| 1 | Start DD2, load a save, open REFramework menu | BelovedCap menu appears; no startup Lua error | NOT TESTED IN THIS REFERENCE |
| 2 | Refresh NPC list after gaining any positive affinity | Familiar NPCs with `Value > 0` appear | NOT TESTED |
| 3 | Keep NPC **locked**, raise affinity above 199 in-game or via controlled tester | Next affinity scan clamps to 199, no lingering >199 | NOT TESTED |
| 4 | Unlock NPC, raise 199 → 205+ | Value above Love threshold is retained (up to game maximum) | NOT TESTED |
| 5 | For an NPC at 220, trigger an in-game negative event | Value restored to previously observed 220, protection ON | NOT TESTED |
| 6 | Use mod's Cheat Mode to lower an unlocked NPC 220 → 120 | Stays 120 and future loss reverses to 120; new gains stick | NOT TESTED |
| 7 | Relock an NPC at 250 | Cap applies (199 default) and protection cannot restore 250 | NOT TESTED |
| 8 | Approach NPC within ~8 m and centre camera near head | One floating heart/bar with number and LOCKED/UNLOCKED | User reported build working generally; specifics NOT TESTED |
| 9 | Test crowd, cutscene, photo mode, save/reload, fast travel | No crashes, stale HUD, or mod errors | NOT TESTED |
| 10 | Test New Game+ / load another save in the **same process** | Values come from the actual save, not the previous save's in-memory high-water map | NOT TESTED — important caveat |
| 11 | Quit DD2 and relaunch another save | Global unlocked config persists; in-memory maximum from prior run does NOT carry over | NOT TESTED |
| 12 | Run optional read-only API probe during gameplay | JSON contains current TDB version and runtime flags | **PASS (2026-10-11):** probe v1.1, TDB 83, all 7 game types and 15 target method names present. Full parameters/overloads **NOT VERIFIED** |

## When a test fails

Capture: (a) game build ID, (b) `DD2.exe` hash, (c) `dinput8.dll` hash and REFramework revision if known, (d) exact `BelovedCap.lua` SHA, (e) `re2_framework_log.txt`, (f) probe JSON before/after patch, (g) what triggered the failure. Keep old reference and new reference separately.

**Important nuance:** v2.1 scans every 0.25 seconds; a game callback can potentially process a transient over-cap affinity before it is reset. To prove a truly strict cap at the moment of a game event, additional event-hook testing would be necessary.
