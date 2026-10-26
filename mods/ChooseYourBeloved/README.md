# Choose Your Beloved v2.8 — Unlock consistency fix (Ulrika verified in-game)

The user reported **Ulrika displaying UNLOCKED but remaining at affinity 199**. **20 October 2026: owner confirmed the v2.8 loose `BelovedCap.lua` fixes this issue in-game.** This verifies the reported Ulrika scenario; exact affinity values and the game build were not recorded.

## Distinguish two separate 199 caps

1. **Mod cap**: Locked NPCs are clamped at 199 by Choose Your Beloved; UNLOCKED NPCs are **not** clamped by the mod and can reach 299.
2. **Vanilla game soft cap**: DD2 itself reportedly holds many NPCs at 199 from ordinary interactions until a gift, escort or quest reward pushes them above the threshold. Changing our unlock entry does not automatically bypass the game rule.

The audit also found a real inconsistency: the mod's list/UI interpreted truthy legacy JSON values such as `"true"` as UNLOCKED, while the mod's affinity enforcement accepted only the boolean `true`. v2.8 canonicalizes the saved unlock map and uses a single `isNPCUnlocked()` check everywhere (UI, HUD, scans, cheat controls).

## In-game verification for Ulrika

1. Back up your DD2 save and `reframework/data/BelovedCap.json`; replace `reframework/autorun/BelovedCap.lua` with v2.8 and fully restart DD2.
2. **REFramework → BelovedCap → Refresh NPC List**, find Ulrika. Her **UNLOCKED** status tooltip will say whether the **mod cap is INACTIVE** and show the ID used in our code.
3. Save and give a gift that she likes / complete an appropriate quest or escort, respecting the game's gift cooldown. If affinity exceeds 199, the mod is working.
4. To test without waiting, on a **backup save only**, turn on Cheat Mode, choose **+1** or **+10**, and press Apply for Ulrika. A rise above 199 that persists for a few seconds shows our own cap isn't pulling it back. Do not use cheats on your actual save if you want natural progression.
5. If the value climbs above 199 but snaps back, send the `BelovedCap.json` file and REFramework log (redact private data) so we can investigate another write path or mod conflict. If it remains >199, the issue was the vanilla soft cap / gain mechanism.

## Compatibility and scope

No additional romance, affinity gain or cooldown overrides are installed. The anti-loss rule retains its previous behavior for both locked and unlocked NPCs. Main Pawn native FavorabilityRating stays read-only; classic conversation HUD, menu guard, 4-second short-NPC hold and saved HUD location remain unchanged.

### Testing
Owner-confirmed successful in-game Ulrika unlock test on 20 October 2026 using the loose Lua. Other NPC cases and the regression harness still require separate validation.

**Packaging warning:** Both handmade v2.8 ZIP downloads caused extraction/CRC errors for the owner. Neither contains `Cover.png`; thus a corrupt PNG cannot directly explain errors for entries in those specific ZIPs. The archive problem remains unresolved. Install the confirmed-working loose Lua instead.

## v2.9-alpha1: Native interaction UI — opt-in test

Read-only probe v0.2, 26 Oct 2026: 431 prompt target and 431 native UI callbacks; TxtTalk was present on all 431 calls; six unique actors, including Main Pawn Dahlia (1000), Luz (42), Sigurd (199), The Dragonforged (187) and a generic NPC. The original TxtTalk message was readable 0/431 times.

This experimental mode updates the *native Talk prompt* through TxtTalk:set_Message(), using a **scoped** current character ID obtained from reqDisp (no global GUIBase name hook). It shows labels such as `Dahlia [1000]` or `Ulrika [245]`.

- Enable **REFramework > BelovedCap > Native Talk Affinity (Experimental)** to test. **Default is OFF**.
- When enabled and native hook installs, the custom floating dialogue HUD is hidden; the Main Pawn affinity change toast remains independent.
- Disable standalone Show Name and Show Favorability scripts for this test (same native UI functions).
- The original Talk message could not be read, so **this alpha cannot preserve the vanilla verb/action label**. Test a generic NPC, your Main Pawn and merchant, and look for incorrect replacement of Buy/Sell, Give Gift or other action text. Disable immediately if misleading.
- The v2.8 Ulrika unlock enforcement, NPC anti-loss, read-only pawn values and menu guard are unchanged. Save config and saves before testing.
- Diagnostic line shows hook status, successful setter calls, failures, and last label; provide screenshots if UI truncates or fails.
- No in-game write validation yet; the new behavior remains experimental even though all read-only native hooks were confirmed.

## v2.9 Alpha 2 — Conversation speaker native affinity (26 Oct 2026)

The owner confirmed alpha1's **native pre-talk interaction prompt** works in-game (e.g. `The Dragonforged [187]`), but the dialogue subtitle still showed only `The Dragonforged`. This is expected because `ui021301.TxtTalk` belongs to the interaction prompt, not the dialogue speaker name.

Alpha2 adds a separate *optional* `app.GUIBase.getName(app.CharacterID)` post-hook to decorate the **current dialogue speaker** as `The Dragonforged [187]`, but only when ALL conditions hold:

- Native Talk Affinity is enabled (default OFF).
- **Show Affinity on Native Dialogue Speaker** is enabled (default ON, but inert without Native Talk Affinity).
- `app.InteractManager.IsPlayerTalking` reports true and the last confirmed `selectTalkEvent` target is recent.
- The requested CharacterID matches that exact speaker's ID.
- A blocking game menu has not been detected.

Original GUI names for unrelated characters are returned unchanged. A reentrancy guard prevents modifying our own name-resolution calls. The hook reads native NPC sentiment or the Main Pawn's 0–1000 rating; it never writes affinity. The known-working prompt modification, v2.8 Ulrika fix, classic HUD fallback and pawn change toast remain intact.

**Still experimental:** We verified the older Show Favorability mod used this exact name hook, but alpha2's scoped hook requires live testing. The global name function may also be used by other UI while a conversation is open; do not run Show Favorability simultaneously. Watch **Native dialogue: hooked, names=N, failures=N** while speaking and report the resulting screenshot.

### Owner's in-game Alpha 2 confirmation — 26 October 2026

The owner supplied two screenshots from the live game confirming **both native affinity surfaces work for the Main Pawn** in v2.9-alpha2:

- **Before conversation:** the interaction prompt displays `Dahlia [1000]` using native `TxtTalk` text.
- **During conversation:** the native dialogue speaker label displays `Dahlia [1000]` above the unchanged dialogue subtitle.
- Previously, Alpha 1 was owner-confirmed to show `The Dragonforged [187]` **before talking**; it did not yet decorate the active dialogue name. The Alpha 2 Dahlia conversation screenshot confirms this second path works for the pawn.

These are specific live UI confirmations, not proof that every NPC, merchant option, one-line conversation, or save transition is regression-safe. The experimental toggle remains default OFF, rollback remains available, and standalone Show Name / Show Favorability should stay disabled during this test.
