# DD2 verified method-signature reference — 2026-10-11

**Source:** user-provided live REFramework v1.2 snapshot, captured at `2026-10-11 17:23:58 +0800` (Malaysia). The original JSON is preserved unmodified at `snapshots/Beloved_API_Probe_20261011_172358.json`.

- Probe 1.2, RE Engine TDB 83, game `dd2`.
- REFramework commit `d1461375aee4ec3f313170f8eaad12064eb542d9`, DLL build `16.09.2026 16:39`.
- Seven game types successfully enumerated; all 15 targeted method **names** present, with **21 complete signatures** across overloads; no unresolved signatures.
- NPC managers, NPC holder dictionary and count, player/CharacterID, sample NPC sentiment object and numeric value were readable.
- `draw.text`, `draw.filled_rect`, `draw.filled_quad`, and `draw.world_to_screen` present.
- `reframework.get_delta_time` was absent in this runtime; do not rely on it unconditionally.
- DD2 executable version / Steam build ID still **not captured**.

> These are reflected signatures. They do **not** prove that hooks execute, that affinity writes survive a reload, or that final beloved selection follows the same rules. Avoid inferring semantic meaning from Boolean flags without actual behavior tests.

## Verified method signatures

### `app.Character`

- `get_CharaID() -> app.CharacterID` (instance; declared on `app.Character`)
- `get_GameObject() -> via.GameObject` (instance; declared on `via.Component`)

### `app.CharacterManager`

- `get_ManualPlayer() -> app.Character` (instance; declared on `app.CharacterManager`)

### `app.GUIBase`

- `getName(app.Character) -> System.String` (static; declared on `app.GUIBase`)
- `getName(app.CharacterID) -> System.String` (static; declared on `app.GUIBase`)
- `getName(app.CharacterID, app.PawnDataContext, System.Boolean, System.Boolean) -> System.String` (static; declared on `app.GUIBase`)
- `getName(app.CharacterID, app.PlayerPersonalDataContext, System.Boolean) -> System.String` (static; declared on `app.GUIBase`)
- `getName(app.GUIBase.CharaData) -> System.String` (static; declared on `app.GUIBase`)

### `app.NPCHolder`

- `addSentimentValue(System.Int32, app.CharacterID, System.Boolean, System.Boolean, System.Boolean) -> System.Void` (instance; declared on `app.NPCHolder`)
- `addSentimentValue(app.CharacterID, app.SentimentInfo, System.Int32, System.Boolean) -> System.Void` (instance; declared on `app.NPCHolder`)
- `getSentimentInfo(app.CharacterID, System.Boolean) -> app.SentimentInfo` (instance; declared on `app.NPCHolder`)
- `get_CachedCharacter() -> app.Character` (instance; declared on `app.NPCHolder`)
- `get_Position() -> via.vec3` (instance; declared on `app.NPCHolder`)
- `onUpdate_Sentiment(System.Int32) -> System.Void` (instance; declared on `app.NPCHolder`)
- `setSentimentValue(app.CharacterID, System.Int32, System.Boolean) -> System.Void` (instance; declared on `app.NPCHolder`)
- `setSentimentValue(app.CharacterID, app.SentimentInfo, System.Int32, System.Boolean) -> System.Void` (instance; declared on `app.NPCHolder`)

### `app.NPCManager`

- `getNPCHolder(app.CharacterID) -> app.NPCHolder` (instance; declared on `app.NPCManager`)
- `onUpdate(System.Single) -> System.Void` (instance; declared on `app.NPCManager`)

### `via.GameObject`

- `get_Transform() -> via.Transform` (instance; declared on `via.GameObject`)

### `via.Transform`

- `getJointByName(System.String) -> via.Joint` (instance; declared on `via.Transform`)
- `get_Position() -> via.vec3` (instance; declared on `via.Transform`)

## Important comparison guidance

Compare a post-update capture using **probe v1.2** to this saved **pre-update v1.2** snapshot:

```bash
python compare_probes_v12.py snapshots/Beloved_API_Probe_20261011_172358.json NEW_CAPTURE.json
```

The comparator against the older v1.1 (17:07:29) returned **no detectable API/environment changes under comparable fields**. The richer v1.2 metadata must not be mistaken for a game patch.

Treat changes in API reflection as a triage signal, not proof of gameplay regression. Manually test 199 locked cap, >199 unlocked growth, anti-loss, floating HUD, save/load, and deliberate manual decrease after game updates.
