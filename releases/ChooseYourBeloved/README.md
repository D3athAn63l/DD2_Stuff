# Choose Your Beloved release packaging notice

**20 October 2026:** v2.8 loose `BelovedCap.lua` fixes the reported Ulrika unlock issue in-game (owner-confirmed).

Both v2.8 manually assembled ZIP files continued producing CRC/extraction errors for the owner. **Do not use these v2.8 ZIPs for installation** until verified externally. Both archived manifests contain four text entries and **no Cover.png**. A missing/corrupt screenshot may cause a mod-manager metadata problem but cannot account directly for a CRC error in an absent ZIP member. Root cause remains unverified.

Recommended working source: `mods/ChooseYourBeloved/reframework/autorun/BelovedCap.lua`.

For future builds, use standard Python `zipfile`, run `testzip()`, verify extraction, and omit the image and dangling `screenshot=Cover.png` reference from standalone packaging unless the image has been verified.

## v3.0.0 Stable native UI (26 Oct 2026)
The owner accepted the native UI solution after Main Pawn and Dragonforged dialogue testing. Install the **loose Lua source** from `mods/ChooseYourBeloved/reframework/autorun/BelovedCap.lua` until a new archive made with a standard ZIP library has been verified. Do not relabel the earlier CRC-failing v2.8 ZIPs as stable. The Cover.png in the repository is historical and no longer referenced by the stable modinfo.ini.
