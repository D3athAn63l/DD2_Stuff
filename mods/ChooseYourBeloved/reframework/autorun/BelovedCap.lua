-- =============================================================================
-- BelovedCap  v2.2
-- Caps locked NPCs at 199 by default; optional no-loss protection for all NPCs.
-- Reference: Affinity Bar v1.2.6 (game API patterns)
--
-- v2.2: Separate, read-only Main Pawn favorability menu/HUD; NPC rules unchanged.
--
-- v2.1: Keeps the core LOCK/UNLOCK model. Adds a compact built-in HUD above
-- the NPC closest to the camera centre, and opt-in affinity-loss protection
-- for ALL NPCs. Protection is session-only so it cannot import affinity from
-- another playthrough. Manual cheat-menu edits explicitly reset the baseline.
--
-- The HUD uses REFramework's built-in draw API: no Affinity Bar / D2D required.
-- BelovedCap.json from v2.0 is migrated (unlock list retained; persistent
-- UnlockedNPCMaxAffinity intentionally discarded because it is save-unsafe).
-- =============================================================================

local modName    = "BelovedCap"
local modVersion = "2.2"
local configPath = "BelovedCap.json"

-- ---------------------------------------------------------------------------
-- CONFIG
-- ---------------------------------------------------------------------------
local defaultConfig = {
    Enabled              = true,
    CapValue             = 199,
    UnlockedNPCs         = {},
    PreventDecay         = true,
    ShowFloatingBar      = true,
    ShowMainPawnFloatingBar = true,
    CheatModeEnabled     = false,
    ManualAffinityChange = 50,
}

local config = {}

local function validateConfig()
    if type(config.CapValue) == "number" then
        config.CapValue = math.max(0, math.min(math.floor(config.CapValue), 298))
    else
        config.CapValue = defaultConfig.CapValue
    end

    if type(config.ManualAffinityChange) == "number" then
        config.ManualAffinityChange = math.max(-299, math.min(math.floor(config.ManualAffinityChange), 299))
    else
        config.ManualAffinityChange = defaultConfig.ManualAffinityChange
    end

    for _, field in ipairs({ "Enabled", "PreventDecay", "CheatModeEnabled", "ShowFloatingBar", "ShowMainPawnFloatingBar" }) do
        if type(config[field]) ~= "boolean" then
            config[field] = defaultConfig[field]
        end
    end

    -- Tables must be tables
    if type(config.UnlockedNPCs) ~= "table" then
        config.UnlockedNPCs = {}
    end
end

local function saveConfig()
    json.dump_file(configPath, config)
end

local function loadConfig()
    -- Start from defaults so new keys are always present after upgrades
    for k, v in pairs(defaultConfig) do
        config[k] = type(v) == "table" and {} or v
    end

    local loaded = json.load_file(configPath)
    if loaded then
        -- Only accept keys that exist in defaultConfig (prevents JSON pollution)
        for k, v in pairs(loaded) do
            if defaultConfig[k] ~= nil then
                config[k] = v
            end
        end
        validateConfig()
        -- v2.0 saved high-water marks globally. Intentionally drop those values:
        -- restoring them in another save/new game could change quest outcomes.
        if loaded.UnlockedNPCMaxAffinity ~= nil then
            saveConfig()
        end
    else
        saveConfig()
    end
end
loadConfig()

-- ---------------------------------------------------------------------------
-- SINGLETON CACHE  (lazy getters — cleared on script reset)
-- ---------------------------------------------------------------------------
local _charMgr = nil
local _npcMgr  = nil

local function getCharacterManager()
    if not _charMgr then
        _charMgr = sdk.get_managed_singleton("app.CharacterManager")
    end
    return _charMgr
end

local function getNPCManager()
    if not _npcMgr then
        _npcMgr = sdk.get_managed_singleton("app.NPCManager")
    end
    return _npcMgr
end

-- ---------------------------------------------------------------------------
-- UTILITIES
-- ---------------------------------------------------------------------------

-- Extract a stable string key from a C# CharacterID (boxed enum / struct).
-- tonumber() returns nil for managed objects; :call("ToString") is the real path.
-- String keys are required because UnlockedNPCs/UnlockedNPCMaxAffinity are JSON-persisted.
local getCharaName = nil
local gui_base_type = sdk.find_type_definition("app.GUIBase")
if gui_base_type then
    getCharaName = gui_base_type:get_method("getName(app.CharacterID)")
end

local function getPermanentID(charaID)
    if not charaID then return "0" end
    local num = tonumber(charaID)
    if num then return tostring(num) end
    local ok, val = pcall(function() return charaID:call("ToString") end)
    if ok and val then return tostring(val) end
    return tostring(charaID)
end

local function translateCharacterName(charaID)
    if getCharaName then
        return getCharaName:call(nil, charaID) or "Unknown"
    end
    return "Unknown"
end

-- Styled button helper (avoids repeating push/pop × 3 everywhere)
local COLOR_BUTTON        = 0xFF006FC5
local COLOR_BUTTON_HOVER  = 0xFF2090E0
local COLOR_BUTTON_ACTIVE = 0xFFF58000

local function styledButton(label, callback)
    imgui.push_style_color(21,        COLOR_BUTTON)
    imgui.push_style_color(22,  COLOR_BUTTON_HOVER)
    imgui.push_style_color(23,   COLOR_BUTTON_ACTIVE)
    if imgui.button(label) then callback() end
    imgui.pop_style_color(3)
end

-- ---------------------------------------------------------------------------
-- SESSION-ONLY ANTI-LOSS BASELINES
-- Unlike the v2.0 persistent table, this cannot leak NPC values across saves.
-- The real game save remains the authority when a new player object is loaded.
-- We intentionally protect ALL NPCs, including locked ones (after their cap).
-- ---------------------------------------------------------------------------
local sessionHighs = {}
local baselinePlayerKey = nil
local checkTimer = 0
local checkInterval = 0.25
local lastFrameTime = os.clock()
local overlayTarget = nil

local function getDeltaTime()
    if reframework and type(reframework.get_delta_time) == "function" then
        local ok, dt = pcall(function() return reframework:get_delta_time() end)
        if ok and type(dt) == "number" and dt > 0 and dt <= 0.25 then return dt end
    end
    local now = os.clock()
    local dt = now - lastFrameTime
    lastFrameTime = now
    if dt <= 0 or dt > 0.25 then return 0.0167 end
    return dt
end

local function resetBaselines()
    sessionHighs = {}
    overlayTarget = nil
end

local function checkPlayerSession(player)
    -- Same approach as Affinity Bar 1.2.6: replace the high-water map when the
    -- player managed object changes, without clearing it on fast travel/scene
    -- transitions. The address check is a safety heuristic, not a save-slot ID.
    local ok, address = pcall(function() return player:get_address() end)
    local key = ok and address or tostring(player)
    if baselinePlayerKey ~= nil and baselinePlayerKey ~= key then resetBaselines() end
    baselinePlayerKey = key
end

local function applyCapAndProtection(info, key)
    local current = tonumber(info.Value)
    if current == nil then return end
    local isUnlocked = config.UnlockedNPCs[key] == true
    if not isUnlocked and current > config.CapValue then
        current = config.CapValue
        info.Value = current
    end
    if not config.PreventDecay then
        sessionHighs[key] = nil
        return
    end
    local remembered = sessionHighs[key]
    if not isUnlocked and remembered and remembered > config.CapValue then
        remembered = config.CapValue
        sessionHighs[key] = remembered
    end
    if remembered == nil or current > remembered then
        sessionHighs[key] = current
    elseif current < remembered then
        info.Value = remembered
    end
end

-- Choose a single nearby NPC whose head is close to the screen centre.
-- Screen centre is a cheap, hook-free approximation for 'NPC I'm facing'.
-- A selected NPC is cached only until the next 0.25s scan.
local function findOverlayTarget(holder, playerPos, screenW, screenH, best)
    local char = holder:get_CachedCharacter()
    if not char then return best end
    local holderPos = holder:get_Position()
    if not holderPos or not playerPos then return best end
    local dx = holderPos.x - playerPos.x
    local dy = holderPos.y - playerPos.y
    local dz = holderPos.z - playerPos.z
    local distSquared = dx * dx + dy * dy + dz * dz
    if distSquared > 64 then return best end -- 8m max
    local go = char:get_GameObject()
    local transform = go and go:get_Transform()
    if not transform then return best end
    local joint = transform:getJointByName("Head_0")
    local pos = joint and joint:get_Position()
    if not pos then return best end
    pos.y = pos.y + 0.65
    local pt = draw.world_to_screen(pos)
    if not pt then return best end
    local nx = math.abs(pt.x - screenW / 2) / screenW
    local ny = math.abs(pt.y - screenH / 2) / screenH
    if nx > 0.28 or ny > 0.34 then return best end
    local score = nx * nx * 3 + ny * ny + distSquared / 700
    if not best or score < best.score then
        return { character = char, id = getPermanentID(holder.CharaID), score = score }
    end
    return best
end

-- Compact, asset-free heart. Heart outline follows the usual parametric curve;
-- built-in draw.filled_quad supplies the triangle-fan pieces.
local function drawHeart(cx, cy, size, color)
    local pts = {}
    local n = 24
    for i = 0, n - 1 do
        local t = (i / n) * math.pi * 2
        local st = math.sin(t)
        pts[#pts + 1] = {
            cx + (16 * st * st * st) * size / 34,
            cy - (13 * math.cos(t) - 5 * math.cos(2 * t)
                - 2 * math.cos(3 * t) - math.cos(4 * t)) * size / 34
        }
    end
    for i = 1, n, 2 do
        local a, b, c = pts[i], pts[i % n + 1], pts[(i + 1) % n + 1]
        draw.filled_quad(cx, cy, a[1], a[2], b[1], b[2], c[1], c[2], color)
    end
end

-- ---------------------------------------------------------------------------
-- MAIN PAWN FAVORABILITY (read-only; deliberately separate from NPC sentiment)
-- Uses the native MainPawnDataContext rating. No setters, rewards, cap or
-- anti-decay logic is ever applied to the Main Pawn. Plays nicely with mods
-- such as Johanne Affinity that award legitimate in-game favorability.
-- ---------------------------------------------------------------------------
local PAWN_FAVORABILITY_MAX = 1000
local PAWN_BLUSH_THRESHOLD = 620
local pawnState = { value = nil, character = nil, name = "Main Pawn", status = "Not checked" }

local function safePawnAccess(callback)
    local ok, value = pcall(callback)
    if ok then return value end
    return nil
end

local function refreshMainPawnStatus()
    -- Always replace state: do not display a value from the previous save,
    -- an absent pawn, or a failed scene-transition read as if it were current.
    local state = { value = nil, character = nil, name = "Main Pawn", status = "Main Pawn unavailable" }
    pawnState = state
    local manager = safePawnAccess(function()
        return sdk.get_managed_singleton("app.PawnManager")
    end)
    if not manager then return end

    local mainPawn = safePawnAccess(function() return manager:get_MainPawn() end)
        or safePawnAccess(function() return manager:call("get_MainPawn") end)
    if not mainPawn then return end

    state.character = safePawnAccess(function() return mainPawn:get_CachedCharacter() end)
        or safePawnAccess(function() return mainPawn:call("get_CachedCharacter") end)
    if state.character then
        local id = safePawnAccess(function() return state.character:get_CharaID() end)
        if id then
            local resolved = safePawnAccess(function() return translateCharacterName(id) end)
            if type(resolved) == "string" and resolved ~= "" and resolved ~= "Unknown" then
                state.name = resolved
            end
        end
    end

    local context = safePawnAccess(function() return mainPawn.MainPawnDataContext end)
        or safePawnAccess(function() return mainPawn:get_field("MainPawnDataContext") end)
        or safePawnAccess(function() return mainPawn:call("get_MainPawnDataContext") end)
    if not context then
        state.status = "Main Pawn data is not loaded"
        return
    end

    local raw = safePawnAccess(function() return context:get_FavorabilityRating() end)
        or safePawnAccess(function() return context:call("get_FavorabilityRating") end)
        or safePawnAccess(function() return context:get_field("_FavorabilityRating") end)
    local value = tonumber(raw)
    if not value or value ~= value or math.abs(value) >= 1000000 then
        state.status = "FavorabilityRating unavailable"
        return
    end
    state.value = math.floor(value + 0.5)
    state.status = "OK"
end

local function drawMainPawnAffinity()
    if not config.ShowMainPawnFloatingBar or not pawnState.character or not pawnState.value then return end
    if not draw or not draw.world_to_screen or not draw.filled_rect or not draw.text then return end
    -- We only overlay when facing a nearby pawn; off-screen, loading or
    -- despawned characters are harmlessly skipped without modifying game data.
    pcall(function()
        local manager = getCharacterManager()
        local player = manager and manager:get_ManualPlayer()
        if not player then return end
        local playerPos = player:get_GameObject():get_Transform():get_Position()
        local pawnTransform = pawnState.character:get_GameObject():get_Transform()
        local pawnPos = pawnTransform:get_Position()
        if not playerPos or not pawnPos then return end
        local dx = pawnPos.x - playerPos.x
        local dy = pawnPos.y - playerPos.y
        local dz = pawnPos.z - playerPos.z
        if dx * dx + dy * dy + dz * dz > 64 then return end
        local head = pawnTransform:getJointByName("Head_0")
        if not head then return end
        local headPos = head:get_Position()
        if not headPos then return end
        headPos.y = headPos.y + 0.65
        local pt = draw.world_to_screen(headPos)
        local size = imgui.get_display_size()
        if not pt or not size or not size.x or not size.y or size.x <= 0 or size.y <= 0 then return end
        local nx = math.abs(pt.x - size.x * 0.5) / size.x
        local ny = math.abs(pt.y - size.y * 0.5) / size.y
        if nx > 0.28 or ny > 0.34 then return end

        local value = pawnState.value
        local ratio = math.max(0, math.min(1, value / PAWN_FAVORABILITY_MAX))
        local tint = value >= PAWN_BLUSH_THRESHOLD and 0xFF9C74E9 or 0xFF92C9D6
        local x, y = pt.x - 63, pt.y
        draw.filled_rect(x - 3, y - 3, 132, 16, 0xD0181818)
        draw.filled_rect(x, y, 126, 10, 0xFF424242)
        if ratio > 0 then draw.filled_rect(x, y, 126 * ratio, 10, tint) end
        draw.filled_rect(x + 126 * PAWN_BLUSH_THRESHOLD / PAWN_FAVORABILITY_MAX,
            y - 2, 2, 14, 0xCCB5B5B5)
        draw.text("MAIN PAWN " .. tostring(value) .. " / " .. tostring(PAWN_FAVORABILITY_MAX),
            x, y - 18, 0xFFF8F5EB)
        if draw.filled_quad then drawHeart(x - 14, y + 4, 23, tint) end
    end)
end

local function drawOverlay()
    if not config.Enabled or not config.ShowFloatingBar or not overlayTarget then return end
    if not draw or not draw.filled_rect or not draw.world_to_screen then return end
    local ok, err = pcall(function()
        local char = overlayTarget.character
        local go = char and char:get_GameObject()
        local tf = go and go:get_Transform()
        local head = tf and tf:getJointByName("Head_0")
        if not head then return end
        local p = head:get_Position()
        p.y = p.y + 0.65
        local pt = draw.world_to_screen(p)
        if not pt then return end
        local npcMgr = getNPCManager()
        local charMgr = getCharacterManager()
        local player = charMgr and charMgr:get_ManualPlayer()
        local holder = npcMgr and npcMgr:getNPCHolder(char:get_CharaID())
        local info = holder and player and holder:getSentimentInfo(player:get_CharaID(), false)
        if not info then return end
        local key = overlayTarget.id
        local unlocked = config.UnlockedNPCs[key] == true
        local max = unlocked and 299 or config.CapValue
        local val = tonumber(info.Value) or 0
        -- Range for non-negative affection is 0..299 (or 0..cap).
        -- Negative sentiment is shown by a red bar with magnitude up to -199.
        local ratio = val >= 0 and math.min(1, val / math.max(1, max))
            or math.min(1, -val / 199)
        local label = (unlocked and "UNLOCKED " or "LOCKED ")
            .. tostring(math.floor(val)) .. " / " .. tostring(max)
        local x, y = pt.x - 63, pt.y
        local background, border = 0xD0181818, 0xCCB5B5B5
        local fill = (val < 0) and 0xFF5A5ADD
            or ((val >= 200) and 0xFF9C74E9 or (unlocked and 0xFF84CE95 or 0xFFBBB9A9))
        draw.filled_rect(x - 3, y - 3, 132, 16, background)
        draw.filled_rect(x, y, 126, 10, 0xFF424242)
        if ratio > 0 then draw.filled_rect(x, y, 126 * ratio, 10, fill) end
        -- 200 is where DD2's NPC Love rank starts. Mark it only for unlocked NPCs.
        if unlocked then draw.filled_rect(x + 126 * 200 / 299, y - 2, 2, 14, border) end
        draw.text(label, x, y - 18, 0xFFF8F5EB)
        drawHeart(x - 14, y + 4, 23, fill)
    end)
    -- A despawned game object can make the cached target invalid. Hide it
    -- until the next scan instead of filling the REFramework log every frame.
    if not ok then overlayTarget = nil end
end

local function runAffinityScan()
    local charMgr, npcMgr = getCharacterManager(), getNPCManager()
    if not charMgr or not npcMgr then overlayTarget = nil; return end
    local player = charMgr:get_ManualPlayer()
    if not player then overlayTarget = nil; return end
    checkPlayerSession(player)
    local playerID = player:get_CharaID()
    local dic = npcMgr.NPCHolderDic
    if not dic then overlayTarget = nil; return end

    local playerPos, size
    if config.ShowFloatingBar and draw and draw.world_to_screen then
        pcall(function() playerPos = player:get_GameObject():get_Transform():get_Position() end)
        pcall(function() size = imgui.get_display_size() end)
    end
    local best = nil
    local okLen, length = pcall(function() return dic:get_Length() end)
    if not okLen or not length then return end
    for i = 0, length - 1 do
        -- NPC holders can change while loading; never let a missing index kill
        -- the entire on_frame handler (or other mods' frame callbacks).
        pcall(function()
            local holder = dic[i]
            if not holder then return end
            local key = getPermanentID(holder.CharaID)
            local info = holder:getSentimentInfo(playerID, false)
            if info then applyCapAndProtection(info, key) end
            if info and playerPos and size and size.x and size.y
                and size.x > 0 and size.y > 0 then
                best = findOverlayTarget(holder, playerPos, size.x, size.y, best)
            end
        end)
    end
    overlayTarget = best
end

re.on_frame(function()
    local dt = getDeltaTime()
    checkTimer = checkTimer + dt
    if checkTimer >= checkInterval then
        checkTimer = 0
        -- Read the Main Pawn even if the NPC affinity cap is disabled.
        local ok = pcall(refreshMainPawnStatus)
        if not ok then
            pawnState = { value = nil, character = nil, name = "Main Pawn", status = "Read error" }
        end
        if config.Enabled then
            local scanOK = pcall(runAffinityScan)
            if not scanOK then overlayTarget = nil end
        else
            overlayTarget = nil
        end
    end
    if config.Enabled then drawOverlay() end
    drawMainPawnAffinity()
end)

-- ---------------------------------------------------------------------------
-- NPC LIST
-- ---------------------------------------------------------------------------
local npcDataArray   = {}
local npcSearchFilter = ""

local function refreshNPCList()
    npcDataArray = {}

    local charMgr = getCharacterManager()
    local npcMgr  = getNPCManager()
    if not charMgr or not npcMgr then return end

    local player = charMgr:get_ManualPlayer()
    if not player then return end
    local playerCharaID = player:get_CharaID()

    local npcHolderDic = npcMgr.NPCHolderDic
    if not npcHolderDic then return end

    for i = 0, npcHolderDic:get_Length() - 1 do
        local npcHolder = npcHolderDic[i]
        if npcHolder then
            local sentimentInfo = npcHolder:getSentimentInfo(playerCharaID, false)
            if sentimentInfo and (sentimentInfo.Value > 0
                or config.UnlockedNPCs[getPermanentID(npcHolder.CharaID)]) then
                table.insert(npcDataArray, {
                    name    = translateCharacterName(npcHolder.CharaID),
                    charaID = npcHolder.CharaID,
                    strID   = getPermanentID(npcHolder.CharaID),
                    affinity = sentimentInfo.Value,
                })
            end
        end
    end

    table.sort(npcDataArray, function(a, b) return a.affinity > b.affinity end)
end

-- ---------------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------------
re.on_draw_ui(function()
    if not imgui.tree_node(modName) then return end

    local changed = false

    changed, config.Enabled = imgui.checkbox("Enable Affinity Cap", config.Enabled)
    if changed then saveConfig() end

    changed, config.CapValue = imgui.slider_int("Max Affinity Limit", config.CapValue, 0, 298)
    if changed then saveConfig() end
    if imgui.is_item_hovered() then
        imgui.set_tooltip("Locked NPCs cannot gain affinity above this value.")
    end

    changed, config.PreventDecay = imgui.checkbox("Prevent Affinity Loss (All NPCs)", config.PreventDecay)
    if changed then resetBaselines(); saveConfig() end
    if imgui.is_item_hovered() then
        imgui.set_tooltip("Natural decay and ALL other decreases are reversed for both LOCKED and UNLOCKED NPCs.\nNatural increases remain allowed. Manual changes via this menu become the new baseline.")
    end

    changed, config.ShowFloatingBar = imgui.checkbox("Show Floating Heart + Affinity Bar", config.ShowFloatingBar)
    if changed then overlayTarget = nil; saveConfig() end
    if imgui.is_item_hovered() then
        imgui.set_tooltip("Small relationship bar above the nearby NPC closest to screen centre.\nBuilt-in overlay: no extra mods or Direct2D plugins needed.")
    end

    imgui.spacing()

    -- Main Pawn uses native FavorabilityRating (0..1000), NOT NPC SentimentInfo.
    -- Its UI remains available even when NPC affinity capping is disabled.
    imgui.separator()
    if imgui.tree_node("Main Pawn Affinity (Read-only)") then
        changed, config.ShowMainPawnFloatingBar = imgui.checkbox(
            "Show Floating Main Pawn Affinity", config.ShowMainPawnFloatingBar)
        if changed then saveConfig() end
        if pawnState.value ~= nil then
            imgui.text(pawnState.name .. ": " .. pawnState.value .. " / " .. PAWN_FAVORABILITY_MAX)
            if pawnState.value >= PAWN_BLUSH_THRESHOLD then
                imgui.text_colored("Blushing threshold reached (620)", 0xFF9C74E9)
            else
                imgui.text("Until blushing threshold: " .. (PAWN_BLUSH_THRESHOLD - pawnState.value))
            end
        else
            imgui.text("Main Pawn affinity unavailable (" .. pawnState.status .. ")")
        end
        imgui.text("Display only. NPC caps, anti-loss and cheat controls do not apply to your pawn.")
        imgui.tree_pop()
    end
    -- ── Cheat Mode ──────────────────────────────────────────────────────────
    if imgui.tree_node("Cheat Mode Settings") then
        imgui.text_colored("Warning: Modifying affinity directly.", 0xFF60609C)

        changed, config.CheatModeEnabled = imgui.checkbox("Enable Cheat Mode", config.CheatModeEnabled)
        if changed then saveConfig() end

        if config.CheatModeEnabled then
            changed, config.ManualAffinityChange = imgui.slider_int(
                "-/+ Affinity Amount", config.ManualAffinityChange, -299, 299)
            if changed then saveConfig() end
        end

        imgui.tree_pop()
    end

    imgui.spacing()
    imgui.separator()
    imgui.text_colored("Beloved Exception List", 0xFF00FFFF)
    imgui.spacing()

    styledButton("Refresh NPC List", refreshNPCList)

    if #npcDataArray == 0 then
        imgui.text("Press 'Refresh NPC List' to view characters.")
        imgui.tree_pop()
        return
    end

    changed, npcSearchFilter = imgui.input_text("Search by Name", npcSearchFilter)
    imgui.spacing()

    local filterLower  = string.lower(npcSearchFilter)
    local numColumns   = config.CheatModeEnabled and 5 or 4

    if imgui.begin_table("BelovedCapTable", numColumns) then
        imgui.table_setup_column("Name")
        imgui.table_setup_column("Affinity")
        imgui.table_setup_column("Status")
        imgui.table_setup_column("Action")
        if config.CheatModeEnabled then
            imgui.table_setup_column("Cheat")
        end
        imgui.table_headers_row()

        for _, npc in ipairs(npcDataArray) do
            local passFilter = npcSearchFilter == ""
                or string.find(string.lower(npc.name), filterLower, 1, true)
            if passFilter then
                imgui.table_next_row()
                local isUnlocked = config.UnlockedNPCs[npc.strID]

                -- Name
                imgui.table_next_column()
                imgui.text(npc.name)

                -- Affinity
                imgui.table_next_column()
                imgui.text(tostring(npc.affinity))

                -- Status
                imgui.table_next_column()
                if isUnlocked then
                    imgui.text_colored("UNLOCKED", 0xFF8AD950)
                else
                    imgui.text_colored("CAPPED",   0xFF60609C)
                end

                -- Lock / Unlock
                imgui.table_next_column()
                if isUnlocked then
                    if imgui.button("Lock##"   .. npc.strID) then
                        config.UnlockedNPCs[npc.strID]          = nil
                        -- A newly locked NPC gets re-baselined after the cap
                        -- is applied. Do not trust the cached UI affinity.
                        sessionHighs[npc.strID] = nil
                        saveConfig()
                    end
                else
                    if imgui.button("Unlock##" .. npc.strID) then
                        config.UnlockedNPCs[npc.strID] = true
                        saveConfig()
                    end
                end

                -- Cheat column
                if config.CheatModeEnabled then
                    imgui.table_next_column()
                    local sign  = config.ManualAffinityChange >= 0 and "+" or ""
                    local label = "Apply " .. sign .. config.ManualAffinityChange .. "##Cheat" .. npc.strID

                    if imgui.button(label) then
                        local charMgr = getCharacterManager()
                        local npcMgr  = getNPCManager()
                        if charMgr and npcMgr then
                            local player = charMgr:get_ManualPlayer()
                            if player then
                                local npcHolder = npcMgr:getNPCHolder(npc.charaID)
                                if npcHolder then
                                    local sentiment = npcHolder:getSentimentInfo(player:get_CharaID(), false)
                                    if sentiment then
                                        local maxVal = config.UnlockedNPCs[npc.strID] and 299 or config.CapValue
                                        local newVal = math.max(0, math.min(sentiment.Value + config.ManualAffinityChange, maxVal))
                                        sentiment.Value = newVal
                                        -- Explicit exception: a deliberate manual decrease (or
                                        -- increase) is immediately accepted as the new floor.
                                        sessionHighs[npc.strID] = newVal
                                        saveConfig()

                                        refreshNPCList()
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        imgui.end_table()
    end

    imgui.tree_pop()
end)

-- ---------------------------------------------------------------------------
-- CLEANUP on script reset / reload
-- ---------------------------------------------------------------------------
re.on_script_reset(function()
    checkTimer      = 0
    resetBaselines()
    baselinePlayerKey = nil
    npcDataArray    = {}
    npcSearchFilter = ""
    _charMgr        = nil
    _npcMgr         = nil
    pawnState       = { value = nil, character = nil, name = "Main Pawn", status = "Not checked" }
end)
