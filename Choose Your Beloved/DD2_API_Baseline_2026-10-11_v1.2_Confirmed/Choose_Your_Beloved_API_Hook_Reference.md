# Dragon's Dogma 2 — Choose Your Beloved: API & Hook Compatibility Reference

**Baseline date:** 2026-10-11 (Malaysia, UTC+08)  
**Reference mod:** Choose Your Beloved / `BelovedCap.lua` v2.1 (experimental standalone)  
**Comparison source:** Affinity Bar v1.2.6 (supplied by user, not required at runtime)  
**Purpose:** When the next DD2 or REFramework update breaks a mod, compare the exact previously used classes/methods and current runtime evidence before changing code.

> **Evidence labels:** `USER-OBSERVED` = user ran the mod and reported it worked; `SOURCE-CONFIRMED` = method/call is present in the attached source; `UPSTREAM-REPORTED` = Affinity Bar author recorded an in-game observation; `RUNTIME-PROBED` = verified as exposed/readable by uploaded runtime JSON; `UNVERIFIED` = not actually checked in-game. **Code existing in Lua is not proof that a particular game method survives the next patch.**

## 1. Exact environment / snapshot boundaries

| Item | Reference value | Evidence |
|---|---|---|
| Date | 2026-10-11 | Session date |
| Installed DD2 build | **UNKNOWN** until the user captures local version | UNVERIFIED |
| Steam *public branch* build around this date | **25290080**, update posted 2026-10-08 | SteamDB: https://steamdb.info/patchnotes/25290080/ (NOT proof of installed local build) |
| Expansion context | Dark Arisen released ~2026-10-09 | Context only; not a binary compatibility guarantee |
| Choose Your Beloved Lua | v2.1, `BelovedCap.lua`, SHA-256 `0ed2565b4d054dadd1fcdd2f15e3736c102ceb1975b0bdf1d554bde30c0eddec` | Exact distributed file |
| Previously supplied original Lua | v2.0, SHA-256 `d09c0c00773858021449a367b80a96ea65c8f40456b7ca3f7f0770391d7c3a56` | Exact supplied archive |
| Affinity Bar reference | v1.2.6, SHA-256 `fe53c0927067f26ae62b381cb23c381c1ae70a46a2eea1006125d53c403949cf` | Exact supplied archive |
| **Installed REFramework revision** | `d1461375aee4ec3f313170f8eaad12064eb542d9` | **RUNTIME-PROBED**, v1.1 `reframeworkInfo.commitHash`; matches supplied ZIP revision |
| Supplied REFramework `dinput8.dll` SHA-256 | `14f4d6fd65218f850f39781fb53fb07ba28da6601c1954529098b91608e6ae88` | Supplied archive; verify installed hash separately |
| RE Engine TDB version | **83** at 2026-10-11 16:59:25 and 17:07:29 +0800 | RUNTIME-PROBED (probes v1.0 & v1.1) |
| Installed REFramework build timestamp | `16.09.2026 16:39`; game identifier `dd2` | RUNTIME-PROBED (v1.1) |
| API reflection name-level baseline | 7/7 types; 15/15 requested methods discovered | RUNTIME-PROBED (v1.1); **parameter signatures unresolved** |

**Captured runtime:** The v1.1 read-only capture on 2026-10-11 at 17:07:29 +0800 confirms TDB **83**, **all 7 requested game types**, **all 15 requested method names**, both manager singletons, NPC holder dictionary/count, one readable sentiment `Value`, and required HUD draw primitives. All seven method enumerations succeeded; the per-method **parameter lists are unresolved**. The original 16:59:25 v1.0 capture is preserved; its false `missing` arrays were a diagnostic defect, not a DD2 method disappearance. See `RUNTIME_METHOD_INVENTORY_2026-10-11.md` and `RUNTIME_CAPTURE_RESULTS_2026-10-11.md`.

**Reported live result:** User ran Choose Your Beloved v2.1 and reported that it worked; user noticed Wilhelmina at affinity 261 despite not yet encountering her in this playthrough. It was plausibly left in the **game save** by the old mod, but no save-file inspection has confirmed causation. General operation is `USER-OBSERVED`; individual hooks and edge cases below need independent testing.

## 2. Actual control architecture (v2.1)

**Important: Choose Your Beloved v2.1 installs ZERO `sdk.hook(...)` game-method hooks.** Its primary entry is `re.on_frame(function() ... end)`, with `re.on_draw_ui(...)` for settings and `re.on_script_reset(...)` for cleanup. `re.on_frame` is a **REFramework lifecycle callback**, not an interception of a DD2 method.

```text
re.on_frame (every frame)
  ├─ getDeltaTime() (reframework:get_delta_time() or os.clock() fallback)
  ├─ 0.25-second scan, only when enabled
  │   ├─ sdk.get_managed_singleton("app.CharacterManager")
  │   ├─ sdk.get_managed_singleton("app.NPCManager")
  │   ├─ CharacterManager:get_ManualPlayer()
  │   ├─ player:get_CharaID() and player:get_address()
  │   └─ npcMgr.NPCHolderDic (array-ish, :get_Length(), [i])
  │       └─ holder:getSentimentInfo(playerCharaID, false)
  │           ├─ Read sentimentInfo.Value
  │           ├─ LOCKED and > cap? Write sentimentInfo.Value = cap
  │           └─ Prevention ON and < session high? Restore Value
  └─ drawOverlay() using draw.world_to_screen / filled_rect / filled_quad / text

re.on_draw_ui
  ├─ Lock/Unlock NPC ID in BelovedCap.json
  ├─ Config toggles and NPC list
  └─ Cheat mode: explicit sentimentInfo.Value write, then update session high

re.on_script_reset
  └─ Clear Lua session tables / cached singleton references
```

### 2.1 DD2 game objects and fields this mod actually depends on

| Game type / API | Exact access in v2.1 | Use / expected result | Breakage symptom |
|---|---|---|---|
| `app.CharacterManager` | `sdk.get_managed_singleton("app.CharacterManager")` | Get player | No scans, no NPC list |
| `app.CharacterManager` | `charMgr:get_ManualPlayer()` | Player object | Nothing to scan at title/transition (normal); persistent nil in game is a breakage |
| `app.Character` | `player:get_CharaID()` | Target for sentiment toward player | NPC affinity reads absent |
| `app.Character` (REManagedObject) | `player:get_address()` | Session-change *heuristic*, not save identity | High-water mark may carry over on same-address reload |
| `app.NPCManager` | `sdk.get_managed_singleton("app.NPCManager")` | NPC access | Empty list and no enforcement |
| `app.NPCManager` | `npcMgr.NPCHolderDic` | Traverse NPC holders | Empty scan; may need changed collection type |
| Dictionary/array | `dic:get_Length()` and `dic[i]` | Iterate 0-based holder entries | Loop fails / missing NPCs |
| `app.NPCHolder` | `holder.CharaID` | Stable selection key | Unlock state applies to wrong/missing NPCs |
| `app.NPCHolder` | `holder:getSentimentInfo(playerID, false)` | Obtain current sentiment object | Cap, protection, numeric HUD fail |
| Sentiment info object | `info.Value` read & **direct write** | Enforce capped/protected value | Display may work while write is silently ineffective |
| `app.NPCManager` | `npcMgr:getNPCHolder(charaID)` | Find holder for manual edits/HUD | Manual adjustments fail |
| `app.GUIBase` | `sdk.find_type_definition("app.GUIBase"):get_method("getName(app.CharacterID)")` | Resolve NPC names in menu | Names become `Unknown` |
| NPC CharacterID | `tonumber(id)` else `id:call("ToString")` | JSON key for unlocks | Old unlock keys no longer resolve |

`info.Value` is a **game object field**, not a generic REFramework API. It is the most important semantic dependency: a game update could leave the name present but change how the game consumes or saves its value.

### 2.2 Built-in floating HUD dependency chain

| API / object | Operation | Failure symptom |
|---|---|---|
| `holder:get_CachedCharacter()` | Get instantiated NPC character | No target selection |
| `holder:get_Position()` | Within **8m** player radius | NPC never selected if position changed |
| `player:get_GameObject():get_Transform():get_Position()` | Player position | No target selection |
| `char:get_GameObject():get_Transform()` | Transform | HUD hidden |
| `transform:getJointByName("Head_0")` | Anchor above NPC head | HUD hidden (joint may change) |
| `joint:get_Position()` | 3D head position | HUD hidden |
| `draw.world_to_screen(pos)` | Project to 2D | HUD never appears |
| `imgui.get_display_size()` | Screen-centre proximity scoring | No target selection |
| `draw.filled_rect` / `draw.filled_quad` / `draw.text` | Bar, procedural heart, label | Missing shapes/text |

Drawing uses **built-in REFramework APIs**, no D2D plugin and no imported heart textures. The HUD chooses ONE character whose projected head is closest to the screen centre among candidates within 8m. It is not a precise raycast/interaction-target hook.

## 3. Game logic baseline (v2.1)

- **LOCKED is default for every NPC**: if not in `config.UnlockedNPCs`, their **positive affinity cannot remain above 199** (or user-customized `CapValue`).
- **UNLOCK**: whitelists an NPC key and allows affinity up to the game's reported NPC maximum, **299**. Unlock does NOT force affinity to 299.
- **Affinity protection default ON**: both locked and unlocked NPCs can gain affinity, but decreases are restored to their most recently seen session-high, unless changed manually via the mod. This includes intentional *in-game* penalties, not just daily decay.
- **Manual adjustment through mod menu**: writes `info.Value` and resets that NPC's `sessionHighs[key]` to the new value. Cheat UI clamps lower bound to 0 and upper bound to 199/299 depending on lock state.
- **Persistence**: `BelovedCap.json` holds config/unlocked IDs; **sessionHighs are NOT persisted**. The game save retains its own current sentiment, which can include changes previously written by older versions of the mod.
- **Session-reset caveat**: high-water tracking resets when the player's managed pointer/address changes or Lua scripts reset. This is NOT guaranteed to distinguish save slots when an address is reused; same-process save reload/NG+ remains UNVERIFIED.
- **Polling window**: caps/anti-loss are re-applied on roughly **0.25-second** scan intervals, not on every sentiment write. A game event occurring between scans could observe an over-cap value first; this has not been tested.
- **Menu NPC list limitation**: current refresh shows NPCs with `Value > 0` or already unlocked, so locked NPCs at 0 or negative affinity are omitted. This is a known v2.1 limitation, NOT a game API failure.

### Game affinity tiers — reference attribution

Affinity Bar v1.2.6's author records the following game-side tiers, **reported as read live on title update 3.2**, not freshly proven here on the October 8 build:

| Sentiment | Reported rank |
|---:|---|
| ≤ -101 | Kill |
| -100 to -31 | Hate |
| -30 to 99 | Normal |
| 100 to 199 | Like |
| **200 to 299** | **Love** |

**Why the default 199 cap matters:** It stops locked NPCs one point below the *reported* Love threshold of 200. Distinguish Love **eligibility** from the game's eventual choice of final beloved, which may depend on additional gameplay logic.

## 4. Game-method `sdk.hook` candidates — NOT used in our v2.1

Affinity Bar v1.2.6 contains a more invasive optional mechanism for distinguishing passive decay from gameplay penalties. These are **REFERENCE-ONLY candidate hooks** for future work, not hooks currently proven/required for Choose Your Beloved:

| Type / method name | Reported role | Evidence / caution |
|---|---|---|
| `app.NPCHolder.onUpdate_Sentiment` | Tick during which time-based decay is processed | Affinity Bar author reports live TU 3.2 validation (source lines ~4647–4682) |
| `app.NPCHolder.addSentimentValue` (all overloads) | Writes sentiment deltas | Affinity Bar scans overloads with `get_methods()` and `sdk.hook` |
| `app.NPCHolder.setSentimentValue` (all overloads) | Writes absolute values | Same; inspect overloads after each update |
| `app.GUIBase.getName(app.CharacterID)` | Name lookup (not installed as hook) | Choose Your Beloved uses `get_method` and `:call` directly |
| `app.NPCManager.onUpdate(System.Single)` | An update hook Affinity Bar uses for optional teleport handling | **Not related to Choose Your Beloved affinity control** |

Affinity Bar distinguishes `onUpdate_Sentiment` writes from event writes using `thread.get_hook_storage()`, `sdk.to_int64(args[2])`, overload-argument mapping and `sdk.to_managed_object(args[2])` (source lines ~4654–4712). **Do not copy these argument offsets blindly across game updates.** The 5-parameter `addSentimentValue` overload uses a different target-character argument position from shorter overloads.

Our requested behavior is **block ALL loss**, so this event-attribution hook system is currently unnecessary and would introduce extra breakage surface. Retain `re.on_frame` + direct `Value` writes unless evidence demands otherwise.

## 5. How to investigate the next game update

1. **Record game identifiers BEFORE updating:** Steam `appmanifest_2054970.acf` `buildid`, game executable SHA-256, REFramework DLL SHA-256 and TDB version. Preserve v2.1 Lua SHA.
2. **Name-level reference baseline successfully captured:** `snapshots/Beloved_API_Probe_20261011_170729.json` (probe v1.1; TDB 83; 7/7 classes, 15/15 target method names; installed REFramework commit recorded). Preserve `snapshots/Beloved_API_Probe_20261011_165925.json` separately as an earlier diagnostic with erroneous `missing` statuses. Method parameter signatures are **not** available from these captures.
3. **After patch:** run the same probe and `python compare_probes.py before.json after.json`. Changes in signatures or missing classes narrow down the breakage. A signature match **does not** guarantee old behavior.
4. **Test an actual NPC on a backed-up save**, using `REGRESSION_CHECKLIST.md`. Capture the exact UI output and REFramework log on any failure.
5. **Diagnose in dependency order:** REFramework loaded → singletons → player → `NPCHolderDic` length → holder → `getSentimentInfo` → `Value` read → direct write persistence → cap/anti-loss → HUD projection. **Do not replace everything if only the overlay broke.**
6. **If introducing new `sdk.hook`s:** enumerate method overloads and parameter types from the new game; verify pre/post callback invocation at runtime; document any `sdk.to_int64`/`sdk.to_managed_object` conversions and thread-local state before modifying arguments.
7. **Update this file:** date, executable hash, Steam build, TDB version, REFramework revision, new probe, test results, and any changed signatures.

## 6. Known limitations / failure patterns to preserve

| Symptom | First thing to inspect |
|---|---|
| HUD gone, cap still works | `Head_0`, `get_CachedCharacter`, `draw.world_to_screen`, projection/display-size |
| NPC list empty | Player availability, manager singletons, `NPCHolderDic`, menu's `Value > 0` filter |
| Locked NPC reaches ≥200 | `getSentimentInfo`, writable `Value`, scan actually runs; polling race possible |
| NPC falls from remembered affinity | player-pointer reset, `sessionHighs` cleared, timer, read/write semantics |
| NPCs already high at beginning of save | **Saved game value** may already contain an old mod's writes; v2.1 no longer stores persistent maxima |
| Values from Save A appear in Save B | Test game save content versus mod config and pointer-reuse/session heuristic; verify no other affinity mods |
| Multiple mods keep undoing values | Check simultaneous affinity/decay managers; keep Affinity Bar disabled for isolated tests |
| No `Beloved_API_Probe` button | Check probe file location, REFramework UI, script load errors |
| Probe v1.0 says missing method but mod works | **Ignore `missing` array** from capture 2026-10-11 16:59:25; v1.0 could not enumerate methods and created false negatives. The 17:07:29 v1.1 capture resolves 15/15 targeted names |
| Future probe shows method name but changed behavior | Signature parameters were unresolved in baseline; inspect overloads, game-side semantics, and actual method execution separately |

## 7. Source pointers & documents

**Local attached source lines (1-based):** `BelovedCap.lua` v2.1: singleton getters ~96–107, ID resolution ~118–137, high-water/cap ~158–214, projection ~219–247, drawing ~250–312, scan ~314–360, NPC menu ~368–555, reset ~560–568. Affinity Bar v1.2.6: rank constants ~12–37, hook dedup helper ~1455–1494, decay ratchet ~1960–2056, source attribution hooks ~4647–4712.

**Public REFramework API references:**
- https://cursey.github.io/reframework-book/api/sdk.html — `sdk.get_managed_singleton`, `sdk.find_type_definition`, `sdk.hook`, `sdk.get_tdb_version`.
- https://cursey.github.io/reframework-book/api/re.html — frame/UI/reset callbacks.
- https://cursey.github.io/reframework-book/api/draw.html — projection/drawing methods.
- https://cursey.github.io/reframework-book/api/json.html — `json.dump_file` relative to `reframework/data`.
- https://steamdb.info/patchnotes/25290080/ — public Steam build shown on 2026-10-08; **not proof** of user's installed game build.

## 8. Future change log (append, never overwrite baseline)

| Date | Installed build / TDB | REFramework revision/hash | Probe | In-game regression verdict | Changes |
|---|---|---|---|---|---|
| 2026-10-11 16:59:25 +0800 | Installed build unknown / **TDB 83** | Bundled ref `d1461375...` (installed then unknown) | **Probe 1.0 captured**, methods falsely flagged missing | v2.1 user-reported working; Wilhelmina 261 anomaly | Original capture preserved |
| **2026-10-11 17:07:29 +0800** | Installed build unknown / **TDB 83** | **Running REFramework `d1461375...` confirmed** | **Probe 1.1 captured**, 7/7 types, 15/15 target method names; signatures unresolved | Live read-only introspection passes; affinity-write/hook behavior untested by probe | Preferred pre-patch name-level baseline |

*Reference created from the supplied source archives and a user report. No DD2 process was attached for runtime verification during this documentation pass.*
