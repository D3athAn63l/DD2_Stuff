# AGENTS.md — DD2_Stuff

Scope: all repository files. Use [docs/REPO_MAP.md](docs/REPO_MAP.md) for the definitive source and evidence paths. Do not modify original captures or release ZIPs during ordinary code refactors.

## Evidence hierarchy
1. Current **loose Lua** in `mods/` or `tools/DD2DataDumper/` defines what this repo currently contains.
2. Original **dated JSON captures** in `research/` establish what one running game exposed at that time.
3. Reported owner in-game outcomes establish *specific* behavior only.
4. Mock tests establish simulated behavior, not runtime safety.
5. External mods, community data and older ZIPs are secondary references, never automatically the latest game truth.

Never declare a method missing just because reflection enumeration failed. Unchanged signatures do not guarantee unchanged engine semantics.

## Project entry points
- Beloved gameplay: `mods/ChooseYourBeloved/reframework/autorun/BelovedCap.lua`.
- Health gameplay: `mods/CompleteHealthRestoration/reframework/autorun/CompleteHealthRestoration.lua`.
- Weight gameplay: `mods/BurdenReforged/reframework/autorun/burden_reforged.lua` (source, notes and mock tests in this mod folder).
- Data dumper: `tools/DD2DataDumper/reframework/autorun/DD2_DataDumper.lua`.
- Tool tests and offline data processors: `tools/DD2DataDumper/tools/`.
- Baselines and read-only probe scripts: `research/baselines/`; captured catalog and schemas: `research/dumps/`.
- Distributions: `releases/` — not authoritative editable source.

## Coding and safety
- Maintain intended mod features and user-facing settings unless explicitly asked to change them.
- Prefer method/signature evidence from TDB reflection, but verify behavior in game before claiming a fix.
- Distinguish frame callbacks from installed `sdk.hook()` hooks.
- Guard against invalid objects during loading and scene transitions.
- When `json.dump_file` is used, verify its boolean result; a successful `pcall` may still return `false`.
- Avoid unsafe unbounded work in one frame; use incremental, cancellable exports and persistent checkpoints.
- Keep probe/dumper code read-only unless the owner explicitly authorizes gameplay mutation.
- Never assume base item stats reveal valid affix/picker rolls.
- Preserve exact snapshots, their dates, the actual TDB/REFramework revision, and community data provenance.

## Testing
- Run a Lua syntax check and the relevant mock tests when available.
- The DataDumper tools expect Python and, for Lua test harnesses, Linux `liblua5.4.so.0`:
  `python tools/DD2DataDumper/tools/check_lua.py tools/DD2DataDumper/reframework/autorun/DD2_DataDumper.lua`
  `python tools/DD2DataDumper/tools/run_mock_tests.py`
  `python tools/DD2DataDumper/tools/run_detail_tests.py`
- Burden Reforged regression cases: `python mods/BurdenReforged/tests/run_lua.py` (Lua 5.4 shared library needed).
- Other comparisons and tests are located inside their corresponding `research/baselines/{affinity,health}/2026-10-11/` directories.
- Tests inside a GitHub/cloud environment cannot replace validation in the owner's actual DD2 installation.

## Changing paths
- Read [docs/MIGRATION_GUIDE.md](docs/MIGRATION_GUIDE.md); GitHub paths are not game install paths.
- After future restructures, update root README, AGENTS, map, update playbook and applicable test/document links together.
- Do not mix cleanup/reorganization with Lua behavior changes in the same commit.
- Do not restore the removed `mods/WeightSystemTweaks/` files in normal updates; `BurdenReforged` is an independently authored successor with separate provenance and metadata. Leave historical A/B weight research unchanged.

## Research capture handoff
For owner-submitted ZIPs, follow [docs/RESEARCH_CAPTURE_WORKFLOW.md](docs/RESEARCH_CAPTURE_WORKFLOW.md): audit, hash, version, preserve raw bytes, create a reviewable PR, and distinguish locally analyzed data from bytes actually committed to GitHub.

## Collaboration
Create reviewable PRs; do not merge without the owner's approval. Preserve source contributor credits and community redistribution restrictions. Never commit personal saves, credentials, local account files or sensitive diagnostics.
