# Equipment Enhancement v1.1 — Data Manifest

Captured 11 October 2026 in DD2 using Equipment Research Probe v1.1.

| Artifact | Size / rows | Status |
| --- | --- | --- |
| `EQ Prove v1.1.zip` | 57,363 bytes, four captured JSONs | **Original owner upload; not committed** |
| `DD2_Enhancement_468_Items.json` | 2,032,465 bytes, 468 items | Normalized, **not committed** |
| `DD2_Enhancement_6084_Parameters.csv` | 520,475 bytes, 6,084 rows | Flattened, **not committed** |
| `SUMMARY.json` | Verified counts | **Committed** in this folder |
| `INDEX_STATS.csv` | 13 rows of averages by enhancement index | **Committed** in this folder |
| `FINDINGS.md` | Source-grounded audit | **Committed** in this folder |

- **Source ZIP SHA-256:** `a0536ba99aaa23ea6f39e5a61d2bf1c14ccbe288bf2b8d0bfed17a34c0e3f3bf`
- RE Engine TDB: **83**.
- REFramework commit: `d052e8fd3fd41d0a1a33394fcf6e6c19be39b1ee`.
- Full CSV index labels are *hypotheses*, not guaranteed enum mappings; avoid treating names as confirmed internal values.
- No game-state writing or item injection occurred during the read-only probe.

For complete row-by-row reuse, the original ZIP or derived full catalogs must be uploaded separately. The present GitHub notes do not replace the uncommitted raw evidence.
