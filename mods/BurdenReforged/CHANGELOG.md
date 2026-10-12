# Changelog

## 0.1.1-experimental — 12 October 2026

- **Fix:** Recalculate carried-weight entries for the Arisen and active pawns, rather than the Arisen alone. Restoring weights on mod disable now updates the whole party.
- Use reflected `ItemManager:getPartyList()` with a guarded `getPartyCharaIds(true)` fallback during scene transitions.
- Isolate failures per party member so one unavailable pawn inventory cannot block the rest.
- Add UI diagnostic `Party weights refreshed: N/M`.
- Add full-party enable/disable regression tests and party-list fallback cases.
- Owner confirmed v0.1.1 fixes all-party carried-weight restoration on disabling the mod in-game. Other gameplay paths still require validation.


## 0.1.0-experimental — 12 October 2026

- New source implementation of configurable carry-weight rules for Dragon's Dogma 2 / REFramework.
- Legacy `WeightSystemTweaks.json` options imported once when no native config exists.
- Inventory hooks mark a dirty flag instead of calculating carried weight synchronously.
- Lightweight periodic consistency pass handles events not intercepted by the hooks.
- Excluded categories ignored when master enable is off.
- Mutable tooltip-weight fields tracked and restored before REFramework hot reload clears the cached originals.
- Handles unsupported Warfarer equipment slots by including their mass instead of silently dropping it.
- Rejects non-boolean config values, including nested category toggles.
- Added headless Lua tests for disabled state, hot reload, category rules, equipment, dragonforging, Warfarer, and queued events.

**Not yet tested in game.** This is not a verified replacement for the original mod.
