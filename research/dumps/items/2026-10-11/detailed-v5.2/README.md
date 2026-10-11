# DD2 Equipment Research — Versioned Findings

**Current source of truth:** [Equipment Probe v1.1 complete findings](current/v1.1/FINDINGS.md) (live capture on **11 October 2026**).

The repository tracks **confirmed extracted observations, not guessed gear validity rules**. Latest files in `current/` supersede incomplete enhancement sampling, while the earlier A/B evidence is preserved in `history/`.

| Stage | Status | Reference | What changed |
| --- | --- | --- | --- |
| Data Dumper v5.2 | Base item parameters recorded | [Baseline audit](AUDIT.md), [initial findings](BASE_CATALOG_FINDINGS.md) | 2,152 sampled item IDs; base stats; zero-weight anomaly |
| Equipment Probe **v1.0** | **Superseded for enhancement *completeness*** | [Historical v1.0 findings](history/v1.0/FINDINGS.md) | A/B weight test; 180 weapon and 200/288 armor keys, only **6/13** elements each |
| Equipment Probe **v1.1** | **Current complete live enhancement capture** | [Current v1.1 findings](current/v1.1/FINDINGS.md) | **180/180 weapon + 288/288 armor arrays; 13/13 elements; 6,084 rows** |

## Current files actually committed

- [`current/v1.1/FINDINGS.md`](current/v1.1/FINDINGS.md) — analysis and limitations, including two enhancement IDs absent from the base catalog (1014, 2008).
- [`current/v1.1/SUMMARY.json`](current/v1.1/SUMMARY.json) — machine-readable verified counts and provenance.
- [`current/v1.1/INDEX_STATS.csv`](current/v1.1/INDEX_STATS.csv) — 13-index aggregate stat means computed from all 6,084 enhancement rows.
- [`current/v1.1/DATA_MANIFEST.md`](current/v1.1/DATA_MANIFEST.md) — which raw/derived datasets were produced, and which are **not stored in GitHub**.
- [`history/v1.0/FINDINGS.md`](history/v1.0/FINDINGS.md) — original first-probe findings, unchanged, including the paired weight experiment and its input hashes.
- [`BASE_CATALOG_FINDINGS.md`](BASE_CATALOG_FINDINGS.md) — original v5.2 base-item research, preserved.

## Important: full raw data

The complete **6,084-row CSV**, normalized per-item JSON, and user-provided original ZIP have been produced and verified offline but **are not yet committed here**. They must not be implied to exist merely because these summary files do. See [data manifest](current/v1.1/DATA_MANIFEST.md).

## Remaining questions

1. Confirm internal `app.EnhanceType` index-to-smithing-style mapping and increment/cumulative semantics.
2. Investigate `EquipmentAbilityData` settings, `ExItemParams`, and appraisal selection rules (only counts/types have been captured).
3. Use a clean mod environment for future canonical data dumps; `WeightSystemTweaks` can alter live `_Weight` values.

Keep historical results immutable. When v1.2 arrives, append a new versioned folder under `history/` and advance the `current/` reference, retaining hashes and dates.
