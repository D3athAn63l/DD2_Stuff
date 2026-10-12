# Folder Migration Guide — 11 October 2026

This proposal moves files **without changing their contents**. GitHub file URLs and clone paths will change after merging; installed DD2 mod paths **do not** change.

## Old path → new path
| Before | After |
|---|---|
| `Choose Your Beloved/reframework/autorun/BelovedCap.lua` | `mods/ChooseYourBeloved/reframework/autorun/BelovedCap.lua` |
| `Loss Gauge/CompleteHealthRestoration.lua` | `mods/CompleteHealthRestoration/reframework/autorun/CompleteHealthRestoration.lua` |
| `WeightSystemTweaks/reframework/autorun/weight_system_tweaks.lua` | `mods/WeightSystemTweaks/reframework/autorun/weight_system_tweaks.lua` |
| `DD2_DataDumper/reframework/autorun/DD2_DataDumper.lua` | `tools/DD2DataDumper/reframework/autorun/DD2_DataDumper.lua` |
| `DD2_DataDumper/tools/*` | `tools/DD2DataDumper/tools/*` |
| `Choose Your Beloved/DD2_API_Baseline_2026-10-11_v1.2_Confirmed/*` | `research/baselines/affinity/2026-10-11/*` |
| `Loss Gauge/DD2_Health_API_Baseline_2026-10-11_Confirmed/*` | `research/baselines/health/2026-10-11/*` |
| `DD2_DataDumper/Findings/DD2_Item_Catalog/*` | `research/dumps/items/2026-10-11/basic-catalog/*` |
| `DD2_DataDumper/Findings/DD2Dumper_*.*` | `research/dumps/runtime/2026-10-11/DD2Dumper_*.*` |
| Old mod ZIPs stored inside project folders | `releases/<respective-project>/*` |

The affinity baseline's redundant ZIP was placed next to its extracted contents under `research/baselines/affinity/2026-10-11/`. The health baseline's ZIP was originally nested inside the extracted folder; it remains there. The old Python bytecode cache is preserved in research history, but `.gitignore` prevents additional caches being committed accidentally.

## After merge
- Update local clone via `git pull` before editing; do not merge old project copies into new paths manually.
- Revise any personal scripts or bookmarked links that hardcode the old GitHub path.
- Install only the **individual mod ZIP** or the corresponding loose Lua. Never install raw research captures or probes by bulk-copying the repo.
- Existing local `reframework/data/` configurations are not moved or modified by this GitHub refactor.

## What was not changed
No Lua code, binary assets, baseline JSON, or ZIP bytes were rewritten by the relocation. The previous metadata version mismatch for WeightSystemTweaks is intentionally still open.

## 12 October 2026 — Weight mod replacement (separate change)

`mods/WeightSystemTweaks/` has been removed from the maintained project tree in favor of **independently implemented** `mods/BurdenReforged/` (v0.1.1 experimental). This is a gameplay implementation replacement, **not** a source-file rename; see the new mod's README and changelog.

On an installed game, remove `reframework/autorun/weight_system_tweaks.lua`, then fully restart and install `reframework/autorun/burden_reforged.lua`. Only run one weight mod. Existing `reframework/data/WeightSystemTweaks.json` is left intact for one-time compatible boolean-settings import into `BurdenReforged.json`.

This removes the old files from the branch's current tree only. Existing Git history and the 11 October 2026 weight-mod on/off research captures remain untouched. The historical version mismatch mentioned above applies to the removed mod, not to Burden Reforged.
