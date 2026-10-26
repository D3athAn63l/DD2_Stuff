# DD2_Stuff

> Personal findings. May not be correct. Hi agents! 👋

A **Dragon's Dogma 2 / REFramework** modding workbench: playable mods, a staged data dumper, dated API baselines, in-game captures, and standalone release archives.

This is a research repository. **Read-only reflection is not a gameplay test**, and a field found in an item object does not automatically reveal a valid gameplay roll.

## Repository navigation

| Folder | Contains | Where to start |
|---|---|---|
| [`mods/`](mods/) | Playable mod Lua, assets and metadata | [Choose Your Beloved](mods/ChooseYourBeloved/), [CompleteHealthRestoration](mods/CompleteHealthRestoration/), [Burden Reforged](mods/BurdenReforged/) |
| [`tools/`](tools/) | Read-only data dumper, offline merge/comparison scripts, tests | [DD2 Data Dumper](tools/DD2DataDumper/README.md) |
| [`research/baselines/`](research/baselines/) | Known-working affinity and HP API captures, probes, references | [Affinity](research/baselines/affinity/2026-10-11/README.md), [Health](research/baselines/health/2026-10-11/README.md) |
| [`research/dumps/`](research/dumps/) | Raw type profiles, item catalogs, runtime data and audits | [Basic item catalog](research/dumps/items/2026-10-11/basic-catalog/AUDIT.md), [current equipment research (v1.1)](research/dumps/items/2026-10-11/detailed-v5.2/README.md) |
| [`releases/`](releases/) | Previously built ZIP distributions, separate from editable source | [Choose Your Beloved](releases/ChooseYourBeloved/), [Health](releases/CompleteHealthRestoration/), [Dumper](releases/DD2DataDumper/) |
| [`docs/`](docs/) | Navigation, agent guidance, update and migration instructions | [Map](docs/REPO_MAP.md), [update playbook](docs/UPDATE_PLAYBOOK.md), [migration guide](docs/MIGRATION_GUIDE.md), [capture/import workflow](docs/RESEARCH_CAPTURE_WORKFLOW.md) |

**Important:** Folder placement in GitHub is *not* the game installation path. Install the appropriate loose Lua under your DD2 `reframework/autorun/` or use a mod ZIP; don't extract all of `research/` into the game.

## Current project status (16 October 2026)

- **Choose Your Beloved v3.0.0 Stable:** owner-accepted native pre-talk and dialogue speaker affinity; floating conversation HUD fully removed, pawn gain/loss toast retained. Includes Ulrika unlock fix and NPC cap/anti-loss. [Mod guide](mods/ChooseYourBeloved/README.md). Use loose Lua (older handmade ZIPs have known CRC reports).
- **CompleteHealthRestoration v2.0:** HP and Loss Gauge recovery. Owner reports both work in-game.
- **Burden Reforged v0.1.2 experimental:** independent weight-rule implementation replacing the old WeightSystemTweaks files. Owner confirmed v0.1.1 restored pawn weights on disable and reported that v0.1.2 eliminates the repeated missing-key exceptions while enabled in-game (16 Oct). Other weight scenarios still require regression testing. [Source and tests](mods/BurdenReforged/README.md).
- **DD2 Data Dumper v5.2 experimental:** detailed catalog **now captured in-game**: 2,152 unique loaded dictionary IDs, including 495 weapon, 669 armor and 988 other parameter objects. Capture covers raw item fields; it does not establish valid EX/passive modifier combinations.

### Known environment evidence

- Affinity baseline: 21 resolved signatures, TDB 83, REFramework commit `d1461375...` (16 Sep 2026).
- Health baseline: 19 resolved signatures, same TDB/revision.
- Detailed item capture: TDB 83, REFramework commit `d052e8fd...` (11 Oct 2026).
- Installed DD2 executable/Steam build still unverified.

## For coding agents

Read [`AGENTS.md`](AGENTS.md) and [`docs/REPO_MAP.md`](docs/REPO_MAP.md) before editing. Preserve prior runtime JSON unchanged and work through a PR rather than merging directly without approval.

Unofficial fan workbench; not affiliated with Capcom or the REFramework maintainers.
