# Forgery AIO — October 16, 2026 compatibility baseline

**Scope:** documentation-only, deliberately not a public distribution of the private-use combined mod. This baseline preserves the observed breakage, the working replacement API strategy, the runtime context, and a replayable post-update test plan. It is **not** a raw TDB dump or a guaranteed future API contract.

## Provenance and confidence

- **Owner's live observation (16 Oct 2026):** Forgery AIO v0.9.0 produced the genuine/instant effects, but a ten-copy commission yielded **two items total**. After installing v0.9.1, the owner reports **all three features work**. Exact quantities/settings and the individual code path used for the successful claim are **not independently recorded** in the v0.9.1 log. Do not equate the report with a verified x10 inventory delta in the log.
- **Runtime log evidence:** v0.9.0 log starts 17:42; v0.9.1 log starts 18:08 (local, 16 Oct 2026). Both run REFramework commit `d052e8fd3fd41d0a1a33394fcf6e6c19be39b1ee`, advertised tag `v1.5.9.1`, master, build 2026-10-11 01:52, **TDB 83**. Exact DD2 executable/Steam build **not captured**. The owner had noted a game update on Oct 16, but that does not supply a reproducible Steam build ID.
- **Source inspection:** private-use Forgery AIO v0.9.1 Lua inspected, syntax checked with `texluac -p` in this work session. Prior v0.9.1 package states that REFramework mock tests passed, but mocks do **not** establish live behavior.
- **External reference:** `Zharay/DD2-LUAModFixes`, `reframework/autorun/carry_it_for_me.lua`, also targets modern `app.ItemManager.getItem` overloads (context/reference, not a claim that its game behavior matches the forgery shop).
- **No raw logs or private combined Lua are committed here**. The supplied logs contain local filesystem paths and noisy unrelated mod diagnostics. Third-party forgery mods have redistribution restrictions.

## The failed v0.9.0 route

The bulk-reward hook targeted this old seven-argument method:

```text
app.ItemManager.getItem(
  System.Int32, System.Int32, app.CharacterID,
  System.Boolean, System.Boolean, System.Boolean,
  app.ItemManager.GetItemEventType
)
```

**Observed failure**, from the v0.9.0 runtime log: `[Forgery AIO] Hook unavailable: itemGrant ... Missing method app.ItemManager.getItem(...)` (log line 3005). The separate claim hook `getFakeShopKeepedItemFake` and instant hook `isExistJunkData` did install, so genuine/instant features could still work. At 17:53:42 the mod logged `Requested 9 extra copies via fallback [item 350]`. This recorded an **attempt**, not proof of receipt. The owner counted x2 total, not the requested x10.

**Do not infer** from this failure that `getItem` as a whole is missing. Only this specific, previously assumed overload failed to resolve. Do not keep calling this obsolete signature as a bulk fallback: its return/side effects were not reliable in the reported test.

## The v0.9.1 compatibility fix

Inspect the exact **overload signature**, not just the method name. The replacement checks each of these `app.ItemManager` methods independently with `sdk.find_type_definition(...):get_method(signature)`, then attaches an `sdk.hook` to each present method:

```text
getItem(System.Int32, System.Int32, app.Character)
getItem(System.Int32, System.Int32, app.Character, app.ItemDefine.GetItemOption)
getItem(System.Int32, System.Int32, app.CharacterID)
getItem(System.Int32, System.Int32, app.CharacterID, app.ItemDefine.GetItemOption)
```

**New live log evidence:** REFramework reported successfully adding four distinct `getItem` hooks (IDs **22, 24, 26, 28**; log lines **2863–2886**). It additionally added `getFakeShopKeepedItemFake` (hook 30, lines 2887–2892), `isExistJunkData` (hook 32, lines 2893–2898), and scene-change hook(s). These are runtime *registration* results, not final grant-count telemetry.

### Grant-flow design (from inspected v0.9.1 integration)

1. Allow the game's original forgery claim (`app.ItemManager.getFakeShopKeepedItemFake`) to execute, preserving its normal claim bookkeeping. Do **not** use unconditional `SKIP_ORIGINAL` as a shortcut to multiply rewards.
2. On claim entry, establish a bounded active transaction context: manager identity, requested item ID, configured total count, eligible category and optional before-count from player storage.
3. If the nested `getItem` call matches **the same manager and item** and its original grant quantity is exactly **1**, replace that count with the configured total. Mark the first matched grant as handled; do not override nonstandard quantities or nested calls again.
4. If no matching nested item grant is observed, use one explicit `getItem(System.Int32, System.Int32, app.Character)` call for **N − 1** extras after the vanilla claim (or a matching `app.CharacterID` three-argument overload if needed). A method-call success is **not** equivalent to an inventory success.
5. Where possible, calculate before/after quantities from `getStorageList(app.Character, System.Predicate\`1<app.ItemManager.StorageMasterData>)` and `_ItemId` / `_Num`; distinguish **VERIFIED xN**, partial **Observed M/N**, and **unverified**. Never automatically retry after an uncertain result, because delayed inventory updates could duplicate valuable items.
6. If no compatible grant overload can be hooked, disable **bulk quantity and bulk pricing** instead of charging for copies the game might not award. Genuine and instant remain independently usable.

**Important unknown:** With `verboseLogging=false`, the v0.9.1 log does not identify whether the owner-successful commission used the nested quantity interception or the N−1 fallback. Do not document either route as proven solely by these logs.

### Other two working behaviors / update-sensitive points

- **Genuine result:** for entries identified as forgeable by `get_IsEnableFake`, cache the untouched item data and change `get_ItemParam()._FakeItemId` to the entry's own item ID. Retain the **original** eligibility flag; changing an item's fake mapping can change a subsequent eligibility query. Restore cached original values when toggled off, on script reset, and when requested in the UI.
- **Instant completion:** hook `app.ItemManager.isExistJunkData`, use the managed singleton, and call `set_FakeShopCompleteTime(System.Int32)` with zero. Hook success and the owner's live result support this implementation for the tested run; revalidate after updates.
- **Bulk fee:** rebase on the originally observed `_FakePrice`, not an already adjusted value: `multiplier = 1 + (N - 1) * extraCostPercent / 100`. Price changes only for eligible allowed categories while the claim/grant hooks exist. Restore prices when the feature is off. Do not assume the current numeric category mapping is future-proof.

## Hashes / immutable identification (analyzed locally, **not uploaded**)

| Artifact | SHA-256 |
|---|---|
| Original v0.9.0 beta ZIP | `3385d7a9126069dc5a4033c6bb44a4f8a4f41e0f3ebe9adbadc115e840f8e8a3` |
| v0.9.0 `forgery_aio.lua` (inside ZIP) | `02948ea831ef57270da311e99ed8724536ae35ef6b3efc795a53966ac2867661` |
| Working owner-tested v0.9.1 beta ZIP | `02a4ed32d883e7ebe79fae666f3e2f1aff6d4a42fd4230cf473ab02c88cff73f` |
| v0.9.1 `forgery_aio.lua` (inside ZIP) | `72b147af115c368f111e0ecf6f37c8c848e7750925ae4485bcd6634f55e41318` |
| Supplied failure log `re2_framework_log(3).txt` | `907186da7eb3490770cd08d94f71b8c803885a6baf9b97fce0fc493bd15f919a` |
| Supplied follow-up log `re2_framework_log(4).txt` | `716e8d8db44c793d39ed66514c5e1fe1ecc574e49007f49ce65c530ee1aa0f1f` |

Hash the original local archive before comparing it to this baseline. These strings identify owner-provided/tested artifacts, **not** repository content. Neither ZIP nor either complete log is contained in this PR.

## Noise to keep separate

The follow-up log contains **8,788** `KeyNotFoundException` name lines (many paired with the corresponding invoke error), beginning almost immediately after script initialization, including `Dictionary<UInt32, List<StorageMasterData>>.get_Item`. Burden Reforged v0.1.1-experimental also logged `No party inventory weights could be refreshed yet`, but **causality is unproven**. Investigate the inventory mods separately, ideally via A/B disable tests. There are also unrelated `LooseTextureLoader` / `FaultyFileDetector` initialization errors. None of those by itself proves Forgery AIO quantity failure.

## Next game update: reproducible smoke test

1. Record actual game build/Steam manifest or DD2.exe hash, REFramework full commit, TDB version, mod version/hash, and enabled mod list. Back up the save first.
2. Resolve the **four explicit** `getItem` overloads and `getFakeShopKeepedItemFake`, `isExistJunkData`, `app.GuiManager.OnChangeSceneType`. Note which ones fail *at runtime*; reflection-only failure is not definitive.
3. Confirm each hook's **live invocation**, not merely registration. Enable verbose diagnostics for one commission, then turn it off; note intercept vs fallback path.
4. Test one **cheap consumable/material** with bulk off (vanilla x1), then bulk x3 and x10. Record **pre/post inventory quantities**, actual items received, and any partial delivery. Test a duplicate commission to rule out extra grants or retained transaction state.
5. Test genuine-copy ID and instant completion **independently**, including disable/restore and restart. Do not test fragile key items/equipment until the basic flow passes.
6. Test fee percent `0` and `100` against expected base pricing without repeated compounding; verify that fees are unchanged if the bulk grant hook cannot be installed.
7. Compare failures to this **specific** 2026-10-16 baseline and open a new dated research entry. Preserve prior findings, and keep game-induced changes separate from unrelated inventory-mod errors.

## Credit / redistribution boundary

Private-use design draws on the owner's supplied `Forgery Real Item` (lingsamuel / aRed), `Instant Fake Item` (lingsamuel; Nexus 251), and `More Fake Items` (Kalivos; Nexus 600). Their redistribution/modification terms must be reviewed with the original authors before publishing derived source, assets, or install ZIPs to this public repository. This PR intentionally includes **only independently written findings, signatures, analysis and testing guidance**.