# Choose Your Beloved v2.8 — Unlock consistency fix (experimental)

The user reported **Ulrika displaying UNLOCKED but remaining at affinity 199**.

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
A mock Lua regression test is supplied for unlock normalization and cap enforcement. Its result is not an in-game test; verify on Ulrika before merging.
