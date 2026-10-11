# DD2_Stuff

> Personal findings. May not be correct. Hi agents! 👋

A personal **Dragon's Dogma 2 / REFramework modding workshop**: playable Lua mods, experimental dumpers, game-API snapshots, and notes collected while figuring out how DD2 actually works.

**This is a workbench, not a verified game encyclopedia.** A class existing in REFramework does not prove a hook works, and a simulated test does not equal a successful in-game test.

## Start here

- [Repository map](docs/REPO_MAP.md) — which file is where, and what it is for.
- [Agent instructions](AGENTS.md) — how to research, edit, test and document changes.
- [Game-update playbook](docs/UPDATE_PLAYBOOK.md) — what to do when a DD2 or REFramework patch lands.

## Projects

| Project | Purpose | Snapshot status (11 Oct 2026) |
| --- | --- | --- |
| [Choose Your Beloved](Choose%20Your%20Beloved/) | NPC affinity Lock / Unlock: default cap 199, unlock allows 299; anti-loss and compact heart/bar overlay | v2.1; owner reported working in-game |
| [Loss Gauge / CompleteHealthRestoration](Loss%20Gauge/) | Gradual HP and Loss Gauge recovery with configurable Arisen/pawn settings | v2.0; owner reported working in-game |
| [DD2_DataDumper](DD2_DataDumper/) | Read-only type inspection, live catalog export, batchable item stats and offline merge tools | v5.1 basic item export tested in-game; v5.2 detailed export **experimental** |
| [WeightSystemTweaks](WeightSystemTweaks/) | Inventory/equipment weight behavior | Lua header says v3.0; mod metadata still says 2.2-GeminiFix. Runtime status not established here |

Each project may contain **three different things**: (1) editable mod source, (2) installable release archives, and (3) historical/reference data. See the [map](docs/REPO_MAP.md) before changing or installing anything.

## Known research baselines

- **Affinity:** 11 Oct 2026, RE Engine TDB **83**; **21/21** target overload signatures resolved. [Reference](Choose%20Your%20Beloved/DD2_API_Baseline_2026-10-11_v1.2_Confirmed/README.md).
- **Health:** 11 Oct 2026, TDB **83**; **19/19** target signatures resolved, with live player/pawn HP samples. [Reference](Loss%20Gauge/DD2_Health_API_Baseline_2026-10-11_Confirmed/README.md).
- **Items:** **2,152 unique item IDs** from the loaded `app.ItemManager._ItemDataDict` in the tested session. [Audit](DD2_DataDumper/Findings/DD2_Item_Catalog/AUDIT.md). This is **not proof of every item/resource in the game**.

Both API captures report REFramework commit `d1461375aee4ec3f313170f8eaad12064eb542d9`. The installed game's exact executable hash / Steam build remains **unverified**.

## Installing a mod

Install **only the desired mod's runnable files**, keeping the required `reframework/autorun/` path. Do **not** copy every nested `reframework/` directory from this repository: the baseline packs also contain optional diagnostic probes, which are not everyday gameplay mods.

Back up saves and `reframework/data/` settings before replacing scripts. The ZIPs are convenient distributions, but inspect the current loose source when planning code changes.

## Working together

Please keep personal observations, live-captured evidence, community references, and untested hypotheses clearly labeled. Preserve original JSON captures, avoid silent gameplay mutations in diagnostic tools, and prefer a **reviewable PR** over changing `main` when modifying this workshop.

Unofficial fan modding project; not affiliated with Capcom or the REFramework maintainers.
