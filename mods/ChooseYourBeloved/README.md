# Choose Your Beloved v3.0.0 — Stable Native Affinity UI

**Stable feature scope, accepted by the owner on 26 October 2026.** The custom floating conversation HUD has been **fully removed**. Character affinity now appears inside DD2's own UI, without screen-position sliders or guessed dialogue targets.

## What it does

- **Before speaking:** DD2's native interaction prompt shows `Dahlia [1000]` or `The Dragonforged [187]` (native `app.ui021301` / `TxtTalk`).
- **During dialogue:** the actual native speaker-name field shows `Dahlia [1000]` or a matching NPC's affinity using a guarded `app.GUIBase.getName(app.CharacterID)` hook.
- **Main Pawn:** its separate `MainPawnDataContext:get_FavorabilityRating()` remains **read-only**, 0–1000, with an optional **screen-corner gain/loss notification**. This notification is **not** the retired conversation HUD.
- **NPC rules:** configurable locked cap (default 199), explicit unlock allowing up to 299, optional anti-loss, and opt-in manual adjustments. The **v2.8 Ulrika unlock fix remains unchanged**.
- **Menu protection:** native dialogue suffixes are guarded against blocking game menus. Native label and speaker affinity are enabled by default.

The native prompt and dialogue-speaker settings have separate checkboxes in **REFramework > BelovedCap**, but the speaker-name suffix currently requires the native Talk prompt option to be enabled (as in the owner-tested Alpha 2). Disable standalone **Show Name** and **Show Favorability** scripts when using these hooks, as they overlap.

## In-game evidence / meaning of Stable

- **20 Oct 2026:** owner confirmed v2.8 loose Lua resolved the Ulrika 199 Unlock defect.
- **26 Oct 2026:** owner confirmed native prompt for The Dragonforged before conversation.
- **26 Oct 2026:** owner screenshots confirmed Dahlia's `[1000]` in both native interaction and dialogue speaker fields.
- **26 Oct 2026:** owner confirmed The Dragonforged's native affinity label persisted through long conversations with multiple dialogue options.
- **26 Oct 2026:** owner explicitly accepted this coverage as sufficient for a stable feature release; exhaustive permutations of NPC, zone, quest, hour or combat are not release blockers.

This evidence supports the native approach's normal operation, **not** a guarantee against every edge case. In particular the pre-existing scoped native name hook may affect other name lookups while actively talking. Fix observed regressions as reported.

## Upgrade from v2.8 or v2.9-alpha2

1. Back up saves and `reframework/data/BelovedCap.json`.
2. Replace the old `reframework/autorun/BelovedCap.lua` with this release's single loose Lua, then **fully restart DD2**. Never run two copies.
3. Your `UnlockedNPCs`, cap, anti-loss and cheat settings remain. Native UI is **ON by default** for new configurations. An explicitly saved `NativePromptEnabled=false` from alpha builds remains respected; switch it on in REFramework.
4. `PawnHudSeconds` is migrated to `PawnToastSeconds` (only the independent notification duration). Old floating-bar switches, HUD X/Y coordinates and short-dialogue timers are removed from the configuration upon load.
5. The earlier v2.8 handmade ZIP releases produced owner-reported CRC errors and are **not recommended**. Install the stable **loose Lua** until a standard-packaged archive is independently validated.

The repository's historical Cover.png is intentionally **not referenced** in stable modinfo.ini; no PNG is required for the Lua mod.

## Quality checks

The v3.0 source is based on the owner-tested Alpha 2 native hooks with the floating renderer, guesses and controls removed. Source-level invariant checks verify the old HUD references are gone and that the native UI, NPC cap/unlock and pawn notifications remain. Regression scripts in `tests/` cover native character routing, NPC cap/unlock and read-only Main Pawn behavior; real-game validation of the **exact post-cleanup build** is still outstanding. This does not downgrade the owner's acceptance of the native feature itself.

No third-party mod code/assets from Show Name, Show Favorability or Affinity Bar have been incorporated.
