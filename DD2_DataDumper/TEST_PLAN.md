# Quick runtime test plan

1. Back up the v5.1 catalog and completed checkpoint. Replace v5.1 script with v5.2.
2. With in-game gameplay loaded, click **Export NEXT detailed batch (1000 IDs)** once. Verify no stutter/crash. Check JSON `kind=item-detail-batch`, `capturedItems=1000` if enough items, and `typeCounts` shows item subtypes.
3. Inspect at least one `app.ItemWeaponParam` record for `_PhysicalAttack`, `_MagicAttack`, and one `app.ItemArmorParam` record for `_PhysicalDefence`, `_MagicDefence`. Confirm `expectedMissing` is short or empty. If fields are missing for all entries, stop and send one batch rather than repeating it.
4. Restart DD2 and export next batch; verify ID dedup and batch count, then repeat to dictionary end. Expect around 2,152 across the previous live snapshot, subject to changes.
5. Optionally run schema profile; check `equipment_deep` profile has found classes and relevant fields.
6. Run offline merger with `--base` and compare unique IDs, missing IDs, field coverage by subtype. Do not infer valid EX/passive gear rolls from these base stats.

Simulated checks: Lua compilation, unchanged v5.1 unit tests, v5.2 batch IDs/fields, reordered enumeration after restart, failed JSON writes, and recovery of a saved batch without a checkpoint update.
