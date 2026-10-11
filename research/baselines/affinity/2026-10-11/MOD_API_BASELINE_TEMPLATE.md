# Dragon's Dogma 2 Mod API Baseline — TEMPLATE

**Mod name / version:**  
**Baseline date / timezone:**  
**Game executable Steam build ID + SHA-256:**  
**REFramework revision / DLL SHA-256:**  
**RE Engine TDB version (`sdk.get_tdb_version()`):**  
**Mod's main Lua path + SHA-256:**  
**Status:** SOURCE-CONFIRMED / USER-OBSERVED / RUNTIME-VERIFIED / UNVERIFIED

## Purpose & user-visible behavior

Describe what it should do and what it deliberately should **not** do. Link a working screenshot/video/log where available.

## REFramework callbacks (not necessarily game hooks)

| Callback | Source file + line | Frequency / phase | Required? | Tested? |
|---|---|---|---|---|
| `re.on_frame` | | | | |
| `re.on_draw_ui` | | | | |

## `sdk.hook` / engine method interception (if any)

| Exact type | Method overload/signature | Pre/post args | Intended behavior | Verified on build | Fallback |
|---|---|---|---|---|---|

If **no game-method hooks**, explicitly record `NONE`. Never infer hook existence from a callback.

## RE Engine APIs / fields actually accessed

| Class / field / method | Call site | Return type / assumptions | Failure symptom | Tested on build |
|---|---|---|---|---|

## Configuration and game-save interactions

Document which values go to `reframework/data/*.json`, which mutate game-save state, how save/session switches are detected, and which data should never be copied across playthroughs.

## Compatibility / breakage checks

- [ ] Startup/script parse
- [ ] Managers and game types resolve
- [ ] Method signatures verified from runtime probe
- [ ] Read fields and objects resolve
- [ ] Write semantics verified **on backed-up save**
- [ ] Game-event handling/quest logic unchanged
- [ ] HUD visible / alignment correct
- [ ] Same-session save reload / new save / NG+
- [ ] Other mods disabled for isolation

## Regression evidence

| Date | Game build | REFramework hash | Probe or log path | Result / known limitation |
|---|---|---|---|---|

## Change history

Append changes, preserving the earlier known-good record unchanged.
