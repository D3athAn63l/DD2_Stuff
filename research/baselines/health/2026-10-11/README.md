# DD2 Health / Loss Gauge — Confirmed Reference Pack

**11 October 2026 — captured in-game at 18:02:52 +0800**  
**Status:** 8/8 game/runtime types discovered, **19/19** targeted signatures fully resolved. Live Arisen, 2 pawn samples, damaged Loss Gauge observed.  
**RE Engine TDB:** 83  
**REFramework:** `d1461375aee4ec3f313170f8eaad12064eb542d9` (16 Sep 2026)  
**Installed DD2 build ID / executable hash:** not yet verified.

This pack documents the *currently working* CompleteHealthRestoration v2.0 API environment. The original Health API Probe v1.0 source and user capture are included unchanged. **No gameplay changes are made.**

## Start here

- **`reference/HEALTH_API_REFERENCE.md`**: verified baseline, read paths, Hit-controller signatures, complete 19-signature inventory and evidence limitations.
- **`baseline/Health_API_Probe_20261011_180252.json`**: exact original live JSON, unchanged.
- **`REGRESSION_CHECKLIST.md`**: behavior checks after future patches.
- **`compare_health_probes.py`**: compares this v1.0 capture with another v1.0 capture, ignoring fluctuating HP.
- **`reframework/autorun/Health_API_Probe.lua`**: same v1.0 read-only probe; install only for future captures and remove afterward.
- **`tests/`**: offline simulated REFramework test and comparator tests.

## Later after a game patch

1. Run the same probe in-game (ideally with player and pawns present).
2. Save and provide its generated JSON.
3. Compare the new capture locally:

```shell
python compare_health_probes.py baseline/Health_API_Probe_20261011_180252.json NEW_CAPTURE.json
```

4. Check actual HP, Loss Gauge, pawn healing and config saves in-game even when signatures are unchanged.

The snapshot **does not prove** setter behavior, update-loop execution, save persistence, or installed Steam build identity. The owner's report of successful v2.0 in-game healing is independent behavioral evidence, not a result of this probe.
