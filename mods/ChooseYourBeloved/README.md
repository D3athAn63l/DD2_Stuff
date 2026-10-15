# Choose Your Beloved v2.5 — HUD position and short NPC dialogue fix (experimental)

The user's screenshots confirmed that v2.4 put the global affinity HUD near the far-left edge (X=42 pixels) and showed it only momentarily for generic NPCs who have a one-line response.

### Fixes
- Defaults to a screen-centered global affinity HUD at **50% horizontal** and **12% vertical** rather than X=42 pixels. The same bar handles NPCs or Main Pawn (colors retained).
- Configurable REFramework sliders: horizontal **10–90%**, vertical **5–85%**. The bar is clamped within the display.
- Generic short conversations remain visible for a minimum of **4 seconds**, configurable between **2 and 8 seconds**. Long conversations still close normally after their minimum period.
- A verified Arisen dialogue event can trigger the short HUD even when `IsPlayerTalking` never remains true for a rendered frame. A proximity/interaction prompt alone does not show the HUD.
- The separate Main Pawn change toast remains active when Johanne awards affection. Main Pawn rating is read-only; NPC 199/299 cap, anti-loss and cheat controls stay unchanged.

### Test
Back up saves and `reframework/data/BelovedCap.json`. Replace `reframework/autorun/BelovedCap.lua`, restart DD2, speak to Dahlia and a one-line NPC, and check the bar position/timing. Change HUD X/Y in REFramework > BelovedCap to taste. An in-game replay is needed to validate timing on this installed build.

### Provenance
Our Lua 5.4 mock verified positioning, short dialogue, event-only talk, NPC/Pawn selection, expiry, and no proximity-only ghost UI. The third-party Affinity Bar and AffinityAnywhere were used as API references only, not copied.
