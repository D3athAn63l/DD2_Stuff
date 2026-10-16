# Choose Your Beloved v2.7 — Menu HUD Guard (experimental)

The user's v2.6 affinity heart HUD works, but stays visible over **merchant Buy/Sell** menus because `app.InteractManager.IsPlayerTalking` may remain true while shopping.

This release adds **Hide Affinity HUD in Game Menus** (default ON) in REFramework > BelovedCap. During a blocking UI the classic shared NPC/Main Pawn heart bar and optional screen-corner pawn change toast are both suppressed. NPC cap/unlock/anti-loss and Main Pawn affinity tracking continue unchanged.

## Implementation
Checks `app.GuiManager:isPausedGUI()`, `get_IsLoadGui()`, `app.PauseManager:isPausedAny()`, and the photo-mode flag. Missing managers/methods are handled safely. This is a display-only guard; it does not reset a remembered conversation target. The existing dialogue checker runs again when the menu closes and shows the bar **if** the conversation remains valid.

The settings menu displays `Menu checker:` and its reason (`GUI paused`, `full-screen GUI`, `game paused`, `photo mode`, `no blocking menu` or `GUI state unavailable`). If an ordinary NPC dialogue is suppressed incorrectly, switch **Hide Affinity HUD in Game Menus** off and report the diagnostic.

## Install & test
Back up your DD2 save and `reframework/data/BelovedCap.json`. Replace `reframework/autorun/BelovedCap.lua` from the ZIP, fully restart DD2, and check an ordinary NPC, Main Pawn, and merchant. The bar should hide while Buy/Sell is open and can reappear if the conversation persists after returning. Verify the original heart style, centered X/Y position and one-line NPC grace period are unchanged.

## Evidence and status
The available Affinity Bar and DD2 menu-state reference scripts support these API checks; no third-party source or assets were copied. An isolated Lua 5.4 simulation passed all menu-flag, toggle, restoration and absent-manager cases. **Whether the current merchant screen sets one of these flags still needs confirmation in-game.**
