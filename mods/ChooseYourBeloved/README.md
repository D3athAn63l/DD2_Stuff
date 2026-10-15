# Choose Your Beloved v2.4 — one global affinity HUD (experimental)

The Main Pawn reader in v2.2 was confirmed working by the owner. Version 2.4 consolidates conversational affinity into **one shared screen-fixed HUD**, for an NPC OR Main Pawn, and adds independent off-screen affinity change notifications.

## How the shared HUD works

- Only shown when `app.InteractManager.IsPlayerTalking` reports true **and** a conversation target can be identified. Disappears when the talking flag becomes false.
- Observational `app.TalkEventManager.selectTalkEvent` hook identifies the Arisen's conversational partner. A recent `app.ui021301.reqDisp(via.GameObject, ...)` character prompt is a guarded fallback.
- The HUD uses a shared layout and still selects distinctive colors per target: Main Pawn cyan/purple (620 reference threshold); NPC uses capped/unlocked/negative colors. No more always-on HUD just because your pawn follows you.
- `ShowFloatingBar` controls NPC conversation affinity; `ShowMainPawnFloatingBar` controls pawn conversation affinity. Main Pawn's live 0–1000 value remains readable through the REFramework menu independently of NPC enable/disable.

## Main Pawn affinity toast

- Optional screen-fixed `MAIN PAWN +5 (625/1000)` appears even when the pawn is off-screen. Display lasts 2–12 seconds (default five).
- `ShowPawnChangeToast` is enabled by default. Initial read, absent data, and pawn unload do not generate false changes.
- This only **reads** the native `FavorabilityRating`; Johanne Affinity remains free to award points. No affinity setter, gameplay hook, modifier, cooldown, or NPC cap is added.

## Migration and testing

Back up your save and `reframework/data/BelovedCap.json`. Replace the old `reframework/autorun/BelovedCap.lua`, then fully restart DD2. Previous unlock settings and HUD on/off toggles persist. The experimental v2.3 `PawnHudMode` setting is intentionally ignored in favor of actual dialogue state plus independent toast.

To test: speak to an ordinary NPC and then your Main Pawn; verify each appears in the same HUD location, with correct color and value. End the conversations and confirm the HUD goes away. Use a Johanne combat reward to verify the off-screen pawn change toast. The REFramework Main Pawn menu shows hook diagnostics (observers/target source). If a game build doesn't expose target information, the bar hides rather than guessing.

## Evidence

The new contextual block passed 12 mocked Lua 5.4 behavior checks (talk gate, NPC/pawn identity, prompt fallback, change+expiry, unloaded pawn). The separate integrated Main Pawn test has updated assertions. **Live dialogue hooking and the combined mod remain unverified in your game.** Affinity Bar and AffinityAnywhere were consulted only for API behavior; their code and assets are not bundled or copied.
