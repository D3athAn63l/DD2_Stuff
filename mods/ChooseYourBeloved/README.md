# Choose Your Beloved v2.2 — Main Pawn Affinity Display (experimental)

This version preserves all v2.1 NPC caps, unlocks, anti-loss protection, manual edits, and the NPC heart overlay. It **adds a read-only view of Main Pawn favorability** on the game's native 0–1000 scale.

## Added

- **REFramework > BelovedCap > Main Pawn Affinity (Read-only):** displays the native Main Pawn FavorabilityRating, a threshold hint and an option for a small floating heart/bar over the pawn's head.
- **Show Floating Main Pawn Affinity:** independent of the existing NPC overlay checkbox; default ON. The pawn appears only when loaded, close (~8m) and near camera centre.
- Main Pawn affinity continues to display when **Enable Affinity Cap** is OFF; that switch only controls the NPC rules.
- When no pawn or data context is loaded, shows **unavailable**, never a fabricated zero or a stale value.

## Compatibility and boundaries

This implementation reads `app.PawnManager:get_MainPawn()`, `MainPawnDataContext` and `get_FavorabilityRating()` (with a read-only `_FavorabilityRating` fallback) on a 0.25-second cadence. It does **not** hook pawn-affinity methods, write pawn affinity, modify pawn timers or affect Johanne Affinity's rewards. If Johanne increases the pawn's native rating, this display should reflect the changed value on its next refresh. This is an architectural compatibility assessment, **not a live dual-mod test**.

The reported Main Pawn favorability range is **0–1000** and the reported blushing threshold is **620**, unlike NPC sentiment's 0–299 range. The threshold should be verified against current-game behavior; it does not change gameplay.

**Do not install AffinityAnywhere merely to show your pawn's rating.** It modifies pawn and NPC affinity gains/cooldowns and may overlap with other affection-changing mods. The attached third-party scripts were used as API references, not copied or bundled.

## Installation / rollback

1. Back up your save and `reframework/data/BelovedCap.json`.
2. Replace only your existing `reframework/autorun/BelovedCap.lua` with the v2.2 file; don't run two copies.
3. Restart DD2, enter a loaded save with your Main Pawn, and check the new **Main Pawn Affinity (Read-only)** section.
4. For full rollback, reinstall the known-working v2.1 Lua. The added config key (`ShowMainPawnFloatingBar`) will be ignored by v2.1.

No new binary dependencies or D2D plugins are needed.

## Testing status

- The original standalone accessor/HUD addition passed local Lua syntax and mocked read-only tests for native rating, updated values, missing pawn, optional HUD and fallback field reads.
- The integrated v2.2 still requires owner in-game regression testing: NPC locked/unlocked cap, anti-loss, NPC HUD, pawn live value, HUD positioning, cutscenes/scene transitions, and Johanne rewards.
- Exact installed Steam build ID is not recorded by the existing baseline. REFramework TDB 83 signature records do not prove runtime gameplay compatibility.
