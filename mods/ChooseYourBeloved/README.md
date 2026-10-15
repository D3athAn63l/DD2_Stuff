# Choose Your Beloved v2.3 — contextual Main Pawn affinity HUD (experimental)

Maintains the known-working v2.2 native, read-only Main Pawn favorability display (0–1000) and all v2.1 NPC features unchanged. Owner tested v2.2 successfully in-game on 15 October 2026 and asked to avoid a permanently visible pawn bar.

## Visibility modes

- **Changes (default):** floating bar appears for 5 seconds (configurable 2–12) when the loaded Main Pawn's numeric FavorabilityRating actually changes. Displays the delta (+/-) and current total. Initial load, unavailable pawn, and scene transition don't cause a false popup.
- **Talk:** short temporary window after a matching Arisen ↔ Main Pawn `app.TalkEventManager.selectTalkEvent` hook. Experimental: it detects the start of dialogue, not precisely when the conversation ends. The hook must be available on your REFramework/TDB build; diagnostic appears in REFramework.
- **Either:** trigger on change OR Arisen↔Pawn talk event.
- **Always:** previous v2.2 behavior (nearby and camera-centred).

Main Pawn HUD remains optionally disabled via **Show Floating Main Pawn Affinity**, independently of these modes. The always-accessible numeric value is displayed in the REFramework > BelovedCap > Main Pawn Affinity (Read-only) menu regardless of HUD mode. Range, 620 reference threshold, and NPC features are preserved.

## Implementation

The native reader still polls every ~0.25 seconds. No pawn favorability values, cooldowns, NPC caps or save slots are changed by the new feature. The conversation trigger installs an **observational** SDK hook for reflected `selectTalkEvent` overloads, checks that the speaker/listener are the Arisen and Main Pawn, and starts a configurable wall-clock time window. The hook does not alter arguments or return values. If the dialogue API is unavailable, Changes and Always still work.

Johanne Affinity can continue to grant Main Pawn affinity; Changes watches the final native rating rather than individual events. AffinityAnywhere is not required and is not bundled. Original reference source is not copied.

## Installation / rollback

1. Back up saves and `reframework/data/BelovedCap.json`.
2. Replace `reframework/autorun/BelovedCap.lua` from the ZIP (don't install two copies).
3. Fully restart DD2 and open **REFramework > BelovedCap > Main Pawn Affinity (Read-only)** to cycle modes.
4. To roll back, restore v2.2 Lua and choose the old Show Floating option; newer config keys are ignored by v2.2.

## Testing status

- v2.2 Main Pawn read/display: **owner confirmed working in game**, including alongside their stated mod setup.
- v2.3 event-driven HUD, live Talk hook, overlays during dialogue and multi-save transitions: **unverified in-game**. These require a fresh on-device test before merge.
- For changes, first establish a baseline after loading. Then cause a genuine +1/+2/etc affinity event (for example via Johanne's gameplay actions); check that the bar disappears automatically afterward.
- Talk windows may be invisible in dialogue scenes if the game's world-to-screen rendering is suppressed; use the diagnostic to distinguish hook absence from overlay visibility.
