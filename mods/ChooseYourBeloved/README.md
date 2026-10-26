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

## v3.0.1 compatibility experiment — 26 October 2026

The owner reported three native UI gaps in v3.0:
- **Forced quest dialogue:** Glintt's speaker name appeared without affinity.
- **Main Pawn spontaneous chatter:** Dahlia's speaker name appeared without affinity.
- **Merchant before speaking:** `Hail (Hold to Talk)` was shown rather than the annotated native Talk prompt.

Source audit: v3.0 `currentDialogueSpeakerForID` requires BOTH `IsPlayerTalking=true` AND an explicit, recent `selectTalkEvent` involving the Arisen. The first two scenarios may skip one or both, even when the speaker name is rendered through `GUIBase.getName(app.CharacterID)`.

### Experimental option
New **Include Ambient/Forced Speaker Names (Experimental)** (default OFF) uses the **exact CharacterID requested by the game's native `GUIBase.getName` function** to read either main-pawn favorability (0–1000) or NPC sentiment and append `[value]`. It does **not** infer nearby targets and **never writes affinity**. The proven v3.0 strict dialogue path remains first priority.

**Tradeoff:** `getName` is a *shared name function*. This optional fallback may also add affinity to unrelated name labels in menus, quest UIs or elsewhere. Disable the experimental checkbox to restore v3.0 name behavior. This fallback does not guarantee that every ambient/quest subtitle uses `getName`.

### Hail/merchant diagnostic
The UI now displays cumulative `reqDisp` target callbacks, `reqDispCommon` text callbacks, and the last native prompt character ID. During a **Hail (Hold to Talk)** prompt, these numbers help determine whether it goes through the already-supported `app.ui021301` functions. If not, a separate targeted UI hook/probe will be needed; **no merchant-prompt fix is claimed in this release**.

### Test (single quick play session)
1. Back up your current v3.0 loose Lua and `BelovedCap.json`, replace the Lua and fully restart DD2.
2. Enable **Include Ambient/Forced Speaker Names (Experimental)** in REFramework > BelovedCap.
3. Stand near Dahlia until she speaks spontaneously, trigger a quest line if one occurs naturally, and approach a merchant. No need for separate saves or extensive NPC coverage.
4. For unchanged labels, report whether `Native dialogue ... ambient=N` increased. For merchant Hail, note whether `Prompt diagnostics: targets=N; common=N` rises. Disable the fallback if it adds affinity in places you don't want it.

v3.0 Stable is unchanged on `main`. The v3.0.1 compatibility branch requires a new live game test.


### Owner live-test results — 26 October 2026
- **CONFIRMED WORKING:** Forced quest dialogue now displays affinity using the optional native name fallback.
- **CONFIRMED WORKING:** Spontaneous Main Pawn dialogue, without an Arisen-initiated conversation, now displays affinity.
- **STILL MISSING:** Merchant `Hail (Hold to Talk)` prompt does not display merchant affinity.
- No prompt counter values (`targets`, `common`, `last ID`) have been supplied yet. **Merchant root cause remains undetermined**: alternative UI class, callback/target mismatch, or unavailable merchant sentiment are all possibilities. Avoid claiming a merchant fix or adding broad unsafe hooks before measuring.

Targeted next check: stand clear of interactables, note prompt counters, approach a merchant until Hail appears, note deltas plus `last ID`, then compare with a normal NPC Talk prompt. If `targets` and `common` don't change on Hail, instrument a separate native prompt path. If they do, inspect failed target/affinity resolution within the existing `ui021301` callbacks. No further broad regression matrix needed.
