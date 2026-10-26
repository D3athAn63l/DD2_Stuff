# Choose Your Beloved release packaging notice

**20 October 2026:** v2.8 loose `BelovedCap.lua` fixes the reported Ulrika unlock issue in-game (owner-confirmed).

Both v2.8 manually assembled ZIP files continued producing CRC/extraction errors for the owner. **Do not use these v2.8 ZIPs for installation** until verified externally. Both archived manifests contain four text entries and **no Cover.png**. A missing/corrupt screenshot may cause a mod-manager metadata problem but cannot account directly for a CRC error in an absent ZIP member. Root cause remains unverified.

Recommended working source: `mods/ChooseYourBeloved/reframework/autorun/BelovedCap.lua`.

For future builds, use standard Python `zipfile`, run `testzip()`, verify extraction, and omit the image and dangling `screenshot=Cover.png` reference from standalone packaging unless the image has been verified.
