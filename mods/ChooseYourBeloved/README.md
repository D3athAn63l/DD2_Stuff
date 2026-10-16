# Choose Your Beloved v2.6 — Classic Affinity Heart HUD (experimental)

The owner confirmed v2.5 conversation handling, HUD location and short NPC responses work in-game. This revision restores the recognizable **heart-and-affinity-bar styling** without changing any of that behavior.

## Restored appearance
- Layered translucent background with a fine border and character-specific accent stripe.
- The original procedural heart to the **left**, softer text and a thin highlighted affinity bar.
- Displays the name, number, and status (NPC CAPPED/FREE, Main Pawn BOND).
- Retains the 200 NPC Love threshold marker and Main Pawn 620 reference marker.
- Keeps NPC negative/locked/unlocked/Love colors and Main Pawn cyan/purple colors.
- Long character names are shortened on the visual HUD only (never in saved data or affinity rules).

## Preserved v2.5 behavior
- Single screen-fixed contextual HUD for either current conversational NPC or Main Pawn.
- 50% horizontal and 12% vertical default position; user X/Y sliders unchanged.
- 4-second minimum for short NPC conversations; same configurable timer and guarded target detection.
- Separate off-screen Main Pawn +X/-X notification and live read-only 0–1000 menu.
- NPC cap 199/unlock 299, anti-loss, manual affinity editing and existing JSON migration unchanged.

## Installation and verification
1. Back up your save and `reframework/data/BelovedCap.json`.
2. Replace the existing `reframework/autorun/BelovedCap.lua` with v2.6 and fully restart DD2. Only one installed copy.
3. Speak with a normal NPC, a short-dialogue NPC, and your Main Pawn. Confirm hearts, colors, names, values and bar placement look right and timing stays as in v2.5.
4. If needed, reinstall v2.5 to roll back the presentation only. Config is compatible.

## Tests
- Standalone Lua 5.4 renderer mock passed: classic heart, panel, NPC/Pawn colors, threshold markers, HUD position settings and status labels.
- Integrated test assertions include hearts and character-specific colors. **Live v2.6 visual check still pending.**
- Built-in REFramework draw API only. No new textures/fonts/hooks, and no third-party mod code or assets bundled.
