# DD2 Health / Loss Gauge — Confirmed Live API Snapshot

**Capture:** 2026-10-11 18:02:52 +0800  
**Game:** `dd2`  
**RE Engine TDB:** `83`  
**REFramework commit:** `d1461375aee4ec3f313170f8eaad12064eb542d9` (built 16.09.2026 16:39)  
**Steam/game binary build:** **unverified**  
**Probe:** `1.0` / **read-only**  
**Original captured JSON:** `baseline/Health_API_Probe_20261011_180252.json`  
**JSON SHA-256:** `60ccdb9bdd34f1a7a10690f2f66e0fd387a5dc83bc1e883d5de5426f7d9926b3`

## Results

- **8/8 target runtime classes / types found**; all listed method enumerations successful.
- **19/19 selected method overloads have resolved signatures** (return type, parameter types and count).
- **0 unresolved or missing targeted methods** in this snapshot.
- `app.Character.<Hit>k__BackingField`: **present**, declared as `app.HitController`.
- Live Hit controller on Arisen and sampled pawns: `app.HitController`.
- `app.Human.get_Hit()` exists, but a direct field literally named `Hit` was **not found** on `app.Human` via the probe's field search. This alone does not prove older mod routes cannot work.
- Party list is `System.Collections.Generic.List`1<app.Character>` and contained **2** sampled pawn entries at capture.
- All four manager singletons present; battle mode **0**, pause value **No** at this particular capture (not fixed API constants).

## Live read-only health-state sample

| Sample | Current HP | Original maximum | Reduced maximum | Lost maximum (deficit) |
| --- | ---: | ---: | ---: | ---: |
| Arisen | 640.89 | 773.30 | 674.53 | 98.77 |
| Pawn sample 1 | 556.09 | 637.00 | 598.47 | 38.53 |
| Pawn sample 2 | 578.00 | 578.00 | 578.00 | 0.00 |

Those HP numbers are **observed gameplay state**, not stable comparison keys. Presence of a nonzero Loss Gauge deficit confirms that the probe sampled a genuinely reduced maximum HP; it does **not** establish setter effects by itself.

## Critical restoration access and method signatures

```lua
-- Snapshot reports these getter paths (not invoked below as a probe):
character:call("get_Hp()")
character:call("get_OriginalMaxHp()")
character:call("get_ReducedMaxHp()")

-- Controller access verified as readable in the runtime snapshot:
local hit = character["<Hit>k__BackingField"]  -- app.HitController

-- These are the mod's write calls. They were NOT executed by the read-only probe:
hit:set_ReducedMaxHp(value)         -- set_ReducedMaxHp(System.Single) -> System.Void
hit:setHpValue(value, false)       -- setHpValue(System.Single, System.Boolean) -> System.Void
```

**Evidentiary distinction:** The user separately confirmed that **CompleteHealthRestoration v2.0** works in their game. The probe confirms the **API shapes and read paths**; it does not call write methods, test behavior after scene transitions or verify that configuration settings persist after restarting.

## Complete selected signature inventory

| Looked-up type | Signature | Return type | Dispatch | Declaring type |
| --- | --- | --- | --- | --- |
| `System.Collections.Generic.List`1<app.Character>` | `get_Count()` | `System.Int32` | instance | `System.Collections.Generic.List`1<app.Character>` |
| `System.Collections.Generic.List`1<app.Character>` | `get_Item(System.Int32)` | `app.Character` | instance | `System.Collections.Generic.List`1<app.Character>` |
| `app.BattleManager` | `get_BattleMode()` | `app.BattleManager.BattleModeEnum` | instance | `app.BattleManager` |
| `app.BattleManager` | `get_IsBattleMode()` | `System.Boolean` | instance | `app.BattleManager` |
| `app.Character` | `get_Hit()` | `app.HitController` | instance | `app.Character` |
| `app.Character` | `get_Hp()` | `System.Single` | instance | `app.Character` |
| `app.Character` | `get_Human()` | `app.Human` | instance | `app.Character` |
| `app.Character` | `get_OriginalMaxHp()` | `System.Single` | instance | `app.Character` |
| `app.Character` | `get_ReducedMaxHp()` | `System.Single` | instance | `app.Character` |
| `app.Character` | `get_Valid()` | `System.Boolean` | instance | `via.Component` |
| `app.CharacterManager` | `get_ManualPlayer()` | `app.Character` | instance | `app.CharacterManager` |
| `app.GuiManager` | `isPausedGUI()` | `System.Boolean` | instance | `app.GuiManager` |
| `app.HitController` | `get_Hp()` | `System.Single` | instance | `app.HitController` |
| `app.HitController` | `get_OriginalMaxHp()` | `System.Single` | instance | `app.HitController` |
| `app.HitController` | `get_ReducedMaxHp()` | `System.Single` | instance | `app.HitController` |
| `app.HitController` | `setHpValue(System.Single, System.Boolean)` | `System.Void` | instance | `app.HitController` |
| `app.HitController` | `set_ReducedMaxHp(System.Single)` | `System.Void` | instance | `app.HitController` |
| `app.Human` | `get_Hit()` | `app.HitController` | instance | `app.Human` |
| `app.PawnManager` | `get_PawnCharacterList()` | `System.Collections.Generic.List`1<app.Character>` | instance | `app.PawnManager` |

## Future compatibility procedure

1. Keep this exact v1.0 JSON as **before-patch baseline**; ideally also record the game's exact executable hash or Steam build ID when convenient.
2. After a DD2/REFramework update, launch **the same read-only `Health_API_Probe.lua` v1.0**, while in gameplay.
3. Run `python compare_health_probes.py baseline/Health_API_Probe_20261011_180252.json NEW_CAPTURE.json`.
4. Review differences in type inventory, signature set, return types, Hit backing-field metadata, and read-access paths. Runtime HP and current battle mode are intentionally ignored.
5. **Run `REGRESSION_CHECKLIST.md` even if the API comparison reports no changes**. Especially test gauge recovery across multiple ticks, pawn recovery and settings persistence after a restart.
6. If a method moved or changed signature, update the mod using the new API snapshot. Do not assume a name match guarantees compatible behavior.

**Do not call this a game-build-specific fingerprint yet** because the installed game's Steam build ID and executable hash are not in the snapshot.

## Source/probe integrity

- `Health_API_Probe.lua` SHA-256: `{probe_hash}`
- User-confirmed working `CompleteHealthRestoration.lua` v2.0 SHA-256: `{mod_hash}` (recorded only; the working mod is **not** replaced or modified by this package).
- Original JSON SHA-256: `{raw_hash}`
