# v5.2 Experimental — 11 October 2026

- Added new independent, resumable **detailed item-parameter exporter** (1,000 new records per batch, 16 entries processed/frame).
- Retrieves primitive public/field values from item subtype + base class, with known critical-field fallbacks.
- Added separate v5.2 checkpoint, recovery for successful-batch/failed-checkpoint writes, and reset confirmation.
- Added targeted equipment / enhancement / drop schema profiling.
- Bundled offline merged JSON + CSV + coverage audit tool for ZIP or JSON batches; optional external item-name mapping.
- Kept v5.1 item-catalog exporter and all profile groups unchanged.
- Fixed UI input ordering to preserve legacy-import workflow.

**Not yet tested in running DD2.** The known-working base library had 2,152 item IDs at last capture. v5.2 does *not* dump equipment-affix validity pools, enhancement recipe values or other assets beyond loaded item parameter primitives.
