# Dragon's Dogma 2 — confirmed v1.2 API baseline

**Captured 11 October 2026, 17:23:58 MYT.**

This is the **reference baseline** for future DD2/REFramework compatibility checks, built around a live user-submitted API Probe **v1.2** snapshot. **Choose Your Beloved v2.1 is not modified and this archive is not a new version of the gameplay mod.**

## Summary

- **7/7** named game types found
- **15/15** targeted method names found
- **21/21** overload-specific method signatures successfully resolved
- **0** unresolved signatures
- Game TDB **83**; REFramework commit `d1461375aee4ec3f313170f8eaad12064eb542d9`
- Game executable version/Steam build **unknown**

## Files

- `snapshots/Beloved_API_Probe_20261011_172358.json` — authoritative **pre-update** JSON
- `RUNTIME_METHOD_SIGNATURES_2026-10-11.md` — readable method inventory from that JSON
- `snapshots/Beloved_API_Probe_20261011_*.json` — all four unchanged captures (old v1.0/v1.1 for history)
- `reframework/autorun/Beloved_API_Probe.lua` — optional read-only probe v1.2; may be removed from autorun after collecting the JSON
- `compare_probes_v12.py` — comparison of before/after captures
- `REGRESSION_CHECKLIST.md` — gameplay testing remains essential
- `NICKS_DEVTOOLS_REVIEW.md` — review of the supplied separate devtools package
- Other documents/tests are retained for future sessions; portions of the original docs predate the verified v1.2 capture, so prefer the newly confirmed method-signatures reference.

## After a future DD2 update

1. Back up your working mod and saves.
2. Run **the same v1.2 probe** after loading into gameplay.
3. Compare: `python compare_probes_v12.py snapshots/Beloved_API_Probe_20261011_172358.json NEW_CAPTURE.json`.
4. Check all original gameplay cases even if the comparator says unchanged.
5. If the probe fails because of new game changes, investigate REFramework first; do not blindly write affinity.

## Limits

Only method reflection and the read-only runtime checks were probed. This baseline does **not** test method-hook execution, actual method behavior, save isolation, affinity write persistence, or final Beloved decision logic.
