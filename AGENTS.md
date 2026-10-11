# Agent instructions — DD2_Stuff

These instructions apply across the repository. Read a project's README, live source and baseline docs before editing it. Preserve the mod's intended scope; **do not add features merely because they are technically possible**.

## Source-of-truth hierarchy
1. **Current source code** in each project's loose `*.lua` files describes what the repository actually runs. Check metadata versions separately; don't assume they agree.
2. **Original, dated runtime JSON snapshots** support observed type signatures and read paths for the captured game/REFramework revision.
3. **Owner's documented in-game test results** support specific gameplay behavior, not every possible save/scene.
4. Mock tests support only the simulated cases exercised.
5. Old ZIPs, community mods, forum posts and inferred names are references, not automatically current facts.

Never turn a missing reflection result into "removed by Capcom" without checking probe errors and enumeration status. An unchanged signature doesn't guarantee unchanged game behavior.

## Repo layout and ownership
- `Choose Your Beloved/reframework/autorun/BelovedCap.lua` — beloved Lock/Unlock, 199 locked cap, 299 unlocked, anti-loss + HUD.
- `Loss Gauge/CompleteHealthRestoration.lua` — HP/Loss Gauge recovery and JSON settings.
- `DD2_DataDumper/reframework/autorun/DD2_DataDumper.lua` — optional read-only diagnostics and bounded exports.
- `WeightSystemTweaks/reframework/autorun/weight_system_tweaks.lua` — weight mod; note version discrepancy.
- `docs/REPO_MAP.md` — complete navigation and reference provenance.

Do not install baseline `reframework/autorun/*Probe.lua` files permanently by accident, or deploy archives and loose files together as duplicates.

## REFramework coding
- Prefer exact `sdk.find_type_definition()` results and overload-specific `get_method()` lookups where needed; validate type, parameters and return type on the running game's TDB.
- Distinguish `re.on_frame`, `re.on_draw_ui`, and application-entry callbacks from actual `sdk.hook()` interception.
- Never assume a `pcall` alone proves `json.dump_file` saved anything: check for a `false` return and keep prior config safely.
- Avoid heavy whole-dictionary or reflection sweeps in one frame; use bounded stages and permit cancellation.
- Treat userdata, collections, and scene transitions as potentially invalid/volatile. Check availability before dereferencing.
- Diagnostic/probe code should default to **read-only**; do not install hooks, write fields, call game setters, or change saves unless the owner explicitly requests that functionality.
- Back up game saves and configuration before mutating character, affinity, item or quest state.
- Separate vanilla data, DLC/modded data, and community mappings. Preserve source revision and capture timestamp.
- Do not call a value a valid in-game equipment roll based only on a reflected field or unsourced table.

## Editing workflow
1. Inspect existing functionality and identify which tests or snapshots support it.
2. Make narrowly scoped changes; preserve user-facing settings and backwards-compatible config behavior where possible.
3. Run Lua syntax checks and the project's relevant mock tests; mention if any were unavailable.
4. For game-facing changes, provide a reproducible in-game test plan with expected/actual observations. **Never claim runtime validation from mock tests.**
5. For breaking patches, follow `docs/UPDATE_PLAYBOOK.md` and compare captured API snapshots first.
6. Keep scripts, changelog and `modinfo.ini` consistent; flag mismatches rather than guessing which version is authoritative.
7. Prefer a PR for review and **never merge without the owner's request**. Don't rewrite historical snapshots or release archives as part of documentation cleanup.

## Testing commands and limitations
- The DataDumper tools expect a Linux environment with `liblua5.4.so.0`, e.g.:
  - `python DD2_DataDumper/tools/check_lua.py DD2_DataDumper/reframework/autorun/DD2_DataDumper.lua`
  - `python DD2_DataDumper/tools/run_mock_tests.py`
  - `python DD2_DataDumper/tools/run_detail_tests.py`
- Other baseline folders include their own probe and comparator tests; inspect their READMEs.
- Actual in-game behavior requires the owner's running DD2 + REFramework build. Do not assume a full game runtime is available inside CI or an agent sandbox.

## Integrity and safety
- Original capture JSONs and their manifests are immutable evidence; add new captures rather than overwriting.
- Never commit user saves, private account identifiers, personal configuration, crash dumps with sensitive paths, or injected executable binaries without an explicit reason.
- Do not prune existing archived ZIPs or large findings merely to make the repo look clean. Discuss proposed reorganization first.
- Use links to exact files and state uncertainty precisely. A game patch can break behavior without changing method signatures.
