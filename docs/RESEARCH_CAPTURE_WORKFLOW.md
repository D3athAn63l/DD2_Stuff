# Research Capture Workflow

Owner = in-game tester and final PR approver. Assistant = analysis, organization, documentation and PR preparation. **No merges without owner approval.** Work occurs in an active conversation, not unattended.

## Repeatable cycle

1. **Capture.** Record probe version, date, REFramework/TDB version, whether other mods were enabled, and relevant observations.
2. **ZIP original JSONs.** Do not manually edit game data. Send the ZIP for analysis.
3. **Audit.** Check file integrity, duplicate IDs, errors, array completeness, version changes and mod interference. Clearly label observed facts, hypotheses and unknowns.
4. **Organize.** Keep raw JSON bytes, a SHA-256 manifest, and derived tables separately. Older findings are preserved under history/<version> when a newer complete capture replaces them.
5. **Open a PR.** Include counts, anomalies, methods, provenance, exact files committed, outstanding files and verification performed.
6. **Owner reviews and merges.** Never overwrite or discard raw history silently.

## Recommended equipment locations

- Data Dumper v5.2 original detailed-item JSONs:
  research/dumps/items/2026-10-11/detailed-v5.2/base-v5.2/raw/
- Equipment Probe v1.0, including mod-enabled/disabled weight A/B captures:
  research/dumps/items/2026-10-11/detailed-v5.2/history/v1.0/raw/
- Equipment Probe v1.1 complete enhancement capture:
  research/dumps/items/2026-10-11/detailed-v5.2/current/v1.1/raw/
- Normalized enhancement JSON and 6,084-row CSV:
  research/dumps/items/2026-10-11/detailed-v5.2/current/v1.1/data/

These raw/data directories are proposals until the actual files are checked in.

## ZIP importer in a git checkout

Once the ZIP is accessible inside a local or cloud Git checkout, from the repository root run:

~~~sh
python tools/research/import_capture.py "EQ Prove v1.1.zip" --target research/dumps/items/2026-10-11/detailed-v5.2/current/v1.1/raw --dry-run
~~~

Review the output. Run again without --dry-run, adding --keep-zip if preserving the original upload in raw/originals/ is desired. The tool verifies source ZIP and JSON hashes, preserves original bytes, produces an IMPORT_<hash>.json manifest, refuses conflicting writes, rejects traversal/duplicate names and never commits or pushes automatically.

~~~sh
python -m unittest discover -s tools/research -p "test_*.py" -v
~~~

## Tooling limitation — no false claims

The assistant can directly analyze conversation ZIP uploads, and the connected GitHub tool can commit text and research documentation. It **does not currently provide a direct local-file-to-GitHub transfer route for multi-megabyte attached JSONs**.

The importer handles raw files after they are available in a Git checkout. Until that transfer occurs, reports must say the data was *captured and analyzed*, not *committed*. Full raw data cannot be claimed uploaded merely because the manifest or summary is in a PR. Never upload save files, personal credentials or sensitive logs unreviewed.
