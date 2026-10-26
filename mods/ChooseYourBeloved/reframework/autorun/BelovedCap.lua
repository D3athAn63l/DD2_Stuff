-- =============================================================================
-- BelovedCap  v3.0.0
-- Caps locked NPCs at 199 by default; optional no-loss protection for all NPCs.
-- Reference: Affinity Bar v1.2.6 (game API patterns)
--
-- v3.0.0 STABLE: native prompt + speaker affinity are the only dialogue UI.
-- Retire custom floating bar, uncertain target inference and HUD controls.
-- Retain the separate Main Pawn affinity-change notification.
--
-- v2.9-alpha2: Add scoped native dialogue-speaker name affinity.
-- Native prompt was confirmed in-game in alpha1; dialogue name missing.
-- This new hook is separate from the already-working prompt hook.
--
-- v2.9-alpha1: Optional native interaction affinity label (disabled by default).
-- v2.8: Use one canonical unlock predicate for the UI, NPC cap enforcement,
-- cheat actions and HUD; normalize legacy truthy saved unlock values.
--
-- v2.7: Hide the conversational HUD and pawn change toast in game menus.
-- Preserve conversation targets and restore display when menu closes.
--
-- v2.6: Restores the original heart-and-bar visuals in the shared dialogue HUD.
-- Target detection, positioning, and short-dialogue timing remain unchanged.
--
-- v2.5: Fix HUD placement and generic short-NPC conversation visibility.
-- Centered default, configurable X/Y, one verified-talk grace window.
--
-- v2.4: One shared conversational NPC/Main Pawn HUD and pawn change toast.
-- Live talking-state gate plus observational interaction target tracking.
--
-- v2.3: Experimental overhead popup and talk timer (superseded).
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
local modVersion = "3.0.0"
local configPath = "BelovedCap.json"

-- ---------------------------------------------------------------------------
-- CONFIG
-- ---------------------------------------------------------------------------
local defaultConfig = {
    Enabled              = true,
    CapValue             = 199,
    UnlockedNPCs         = {},
    PreventDecay         = true,
    PawnToastSeconds     = 5,
    ShowPawnChangeToast  = true,
    HideDuringGameMenus  = true,
    NativePromptEnabled  = true,
    NativeDialogueAffinity = true,
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

    for _, field in ipairs({ "Enabled", "PreventDecay", "CheatModeEnabled", "ShowPawnChangeToast", "HideDuringGameMenus", "NativePromptEnabled", "NativeDialogueAffinity" }) do
        if type(config[field]) ~= "boolean" then
            config[field] = defaultConfig[field]
        end
    end

    if type(config.PawnToastSeconds) ~= "number"
        or config.PawnToastSeconds ~= config.PawnToastSeconds then
        config.PawnToastSeconds = defaultConfig.PawnHudSeconds
    else
        config.PawnToastSeconds = math.max(2, math.min(12, math.floor(config.PawnToastSeconds)))
    end

    -- Legacy JSON configurations may encode unlocks as "true" or 1.
    -- The old UI interpreted any truthy value as UNLOCKED, while the cap
    -- enforcement required == true. Canonicalize once to real booleans.
    if type(config.UnlockedNPCs) ~= "table" then
        config.UnlockedNPCs = {}
    else
        local normalized = {}
        for key, value in pairs(config.UnlockedNPCs) do
            if value == true or value == 1 or value == "true" or value == "1" then
                normalized[tostring(key)] = true
            end
        end
        config.UnlockedNPCs = normalized
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
        -- Migrate the pawn notification delay; obsolete floating HUD settings
        -- are deliberately discarded while preserving NPC unlocks.
        if loaded.PawnToastSeconds == nil and type(loaded.PawnHudSeconds) == "number" then
            config.PawnToastSeconds = loaded.PawnHudSeconds
        end
        validateConfig()
        -- v2.0 saved high-water marks globally. Intentionally drop those values:
        -- restoring them in another save/new game could change quest outcomes.
        if loaded.UnlockedNPCMaxAffinity ~= nil
            or loaded.ShowFloatingBar ~= nil
            or loaded.ShowMainPawnFloatingBar ~= nil
            or loaded.HudXPercent ~= nil
            or loaded.HudYPercent ~= nil
            or loaded.DialogueMinSeconds ~= nil
            or loaded.PawnHudSeconds ~= nil then
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

-- Single source of truth for unlock status in menu, HUD and enforcer.
local function isNPCUnlocked(key)
    return config.UnlockedNPCs[tostring(key)] == true
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
    local isUnlocked = isNPCUnlocked(key)
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


-- Native affinity target helpers and Main Pawn change notifications.
local pawnHud = { previous = nil, delta = 0, changeEnds = 0, pawnKey = nil }
local talkTracker = { eventTarget = nil, eventAt = 0, hookStatus = "Not installed" }

local function hudNow()
    -- Monotonic precision is not exposed by all DD2 REFramework builds. A
    -- wall-clock seconds timer gives reliable expiry without os.clock CPU drift.
    return os.time()
end

local function characterKey(character)
    if not character then return nil end
    local id = safePawnAccess(function() return character:get_CharaID() end)
    if not id then return nil end
    return getPermanentID(id)
end

local function sameHudCharacter(a, b)
    if not a or not b then return false end
    if a == b then return true end
    local ak, bk = characterKey(a), characterKey(b)
    return ak ~= nil and bk ~= nil and ak == bk
end

local function trackMainPawnChanges()
    local value = pawnState.value
    local key = characterKey(pawnState.character)
    if value == nil or not key then
        pawnHud.previous = nil
        pawnHud.pawnKey = nil
        pawnHud.delta = 0
        pawnHud.changeEnds = 0
        return
    end
    if pawnHud.pawnKey ~= key then
        pawnHud.previous = value  -- a fresh pawn/save read is a baseline, not a gain
        pawnHud.pawnKey = key
        pawnHud.changeEnds = 0
        pawnHud.delta = 0
        return
    end
    if pawnHud.previous ~= nil and pawnHud.previous ~= value then
        pawnHud.delta = value - pawnHud.previous
        pawnHud.changeEnds = hudNow() + config.PawnToastSeconds
    end
    pawnHud.previous = value
end

local function safeHook(method, before)
    if not method or type(sdk.hook) ~= "function" then return false end
    local success = pcall(function()
        sdk.hook(method, function(args)
            pcall(before, args)
        end, function(retval) return retval end)
    end)
    return success
end

local nativePrompt = {
    target=nil, ui=nil, installed=false, written=0, skipped=0,
    failures=0, last="not installed"
}

local function installConversationObservers()
    local installed, promptInstalled = 0, false
    -- Source identity via selectTalkEvent: only recognize a conversation when
    -- one explicit speaker/listener is the Arisen. No reward/cooldown hooks.
    local talkType = safePawnAccess(function()
        return sdk.find_type_definition("app.TalkEventManager")
    end)
    if talkType then
        local methods = safePawnAccess(function() return talkType:get_methods() end)
        if methods then
            for _, method in ipairs(methods) do
                if safePawnAccess(function() return method:get_name() end) == "selectTalkEvent" then
                    if safeHook(method, function(args)
                        if not args then return end
                        local first = sdk.to_managed_object(args[3])
                        local second = sdk.to_managed_object(args[4])
                        local manager = getCharacterManager()
                        local player = manager and manager:get_ManualPlayer()
                        if not player then return end
                        local target = nil
                        if sameHudCharacter(first, player) and second then target = second end
                        if sameHudCharacter(second, player) and first then target = first end
                        if target and characterKey(target) then
                            talkTracker.eventTarget = target
                            talkTracker.eventAt = hudNow()
                            -- Native speaker identification only; no HUD target guess.
                        end
                    end) then installed = installed + 1 end
                end
            end
        end
    end
    -- Observe the current native interaction prompt target only.
    local uiType = safePawnAccess(function()
        return sdk.find_type_definition("app.ui021301")
    end)
    local charType = safePawnAccess(function()
        return sdk.find_type_definition("app.Character")
    end)
    if uiType and charType then
        local method = safePawnAccess(function()
            return uiType:get_method("reqDisp(via.GameObject, System.Single, System.Guid)")
        end)
        promptInstalled = safeHook(method, function(args)
            if not args then return end
            local obj = sdk.to_managed_object(args[3])
            if not obj then return end
            local rt = charType:get_runtime_type()
            local target = obj:call("getComponent(System.Type)", rt)
            -- Pair this object with the following reqDispCommon callback.
            -- Never reuse a prior character for unrelated prompt refreshes.
            nativePrompt.target = target and characterKey(target) and target or nil

        end)
    end
    talkTracker.hookStatus = string.format("talk: %d, prompt: %s", installed,
        promptInstalled and "yes" or "no")
end
installConversationObservers()

-- ---------------------------------------------------------------------------
-- v2.9-alpha2: NATIVE DIALOGUE SPEAKER TEXT (not the interaction prompt)
-- ShowFavorability demonstrates that GUIBase.getName(app.CharacterID) returns
-- the managed speaker name. Our hook restricts replacements to the exact
-- character identified by the confirmed Arisen/speaker dialogue event.
-- This is NOT a global suffix operation on every NPC name lookup.
-- ---------------------------------------------------------------------------
local nativeDialogue = {
    installed = false, renamed = 0, skipped = 0, failures = 0,
    last = "not installed", blocked = false, depth = 0, callStack = {}
}

local function dialogueSpeakerValue(character)
    if not character then return nil end
    if pawnState.character and sameHudCharacter(character, pawnState.character) then
        return tonumber(pawnState.value)
    end
    local id = safePawnAccess(function() return character:get_CharaID() end)
    local cm = getCharacterManager()
    local player = cm and safePawnAccess(function() return cm:get_ManualPlayer() end)
    if not id or not player or sameHudCharacter(character, player) then return nil end
    local nm = getNPCManager()
    local holder = nm and safePawnAccess(function() return nm:getNPCHolder(id) end)
    local sentiment = holder and safePawnAccess(function()
        return holder:getSentimentInfo(player:get_CharaID(), false)
    end)
    return sentiment and tonumber(sentiment.Value) or nil
end

local function currentDialogueSpeakerForID(charaID)
    if nativeDialogue.depth > 0 or not config.NativePromptEnabled
        or not config.NativeDialogueAffinity or nativeDialogue.blocked then return nil end
    local mgr = safePawnAccess(function()
        return sdk.get_managed_singleton("app.InteractManager")
    end)
    local isTalking = mgr and safePawnAccess(function()
        return mgr:get_field("IsPlayerTalking")
    end) == true
    if not isTalking then return nil end

    -- Require an *explicit* talk event. Mere proximity/target prompts don't
    -- authorize modifying speaker names during a conversation.
    if not talkTracker.eventTarget or not talkTracker.eventAt
        or talkTracker.eventAt <= 0
        or hudNow() - talkTracker.eventAt > 120 then return nil end
    local speaker = talkTracker.eventTarget
    local speakerID = safePawnAccess(function() return speaker:get_CharaID() end)
    if not speakerID or not charaID then return nil end
    if getPermanentID(speakerID) ~= getPermanentID(charaID) then return nil end
    return speaker
end

local function installNativeDialogueNameHook()
    local td = safePawnAccess(function()
        return sdk.find_type_definition("app.GUIBase")
    end)
    local method = td and safePawnAccess(function()
        return td:get_method("getName(app.CharacterID)")
    end)
    if not method or type(sdk.hook) ~= "function"
        or type(sdk.to_int64) ~= "function"
        or type(sdk.create_managed_string) ~= "function"
        or type(sdk.to_ptr) ~= "function" then
        nativeDialogue.last = "GUIBase name APIs unavailable"
        return
    end
    local ok = pcall(function()
        sdk.hook(method, function(args)
            -- The static method's CharacterID is args[2]. Pair each pre/post
            -- with a stack so nested name lookups don't steal each other.
            local requested = args and safePawnAccess(function()
                return sdk.to_int64(args[2])
            end)
            local target = currentDialogueSpeakerForID(requested)
            local stack = nativeDialogue.callStack
            stack[#stack + 1] = target or false
        end, function(retval)
            local stack = nativeDialogue.callStack
            local target = stack[#stack]
            stack[#stack] = nil
            if not target then return retval end

            -- No writes to NPC SentimentInfo, pawn rating or save data.
            local okReplace, result = pcall(function()
                local raw = sdk.to_managed_object(retval)
                local name = raw and raw:ToString()
                if type(name) ~= "string" or name == "" then return nil end
                -- Don't duplicate a suffix if another hook already supplied one.
                if name:match("%s%[%-?%d+%]$") then return nil end
                local affinity = dialogueSpeakerValue(target)
                if not affinity or affinity ~= affinity then return nil end
                local label = name .. " [" .. tostring(math.floor(affinity + 0.5)) .. "]"
                local managed = sdk.create_managed_string(label)
                if not managed then return nil end
                nativeDialogue.renamed = nativeDialogue.renamed + 1
                nativeDialogue.last = label
                return sdk.to_ptr(managed)
            end)
            if not okReplace then
                nativeDialogue.failures = nativeDialogue.failures + 1
                nativeDialogue.last = "dialogue name hook exception"
                return retval
            end
            if result then return result end
            nativeDialogue.skipped = nativeDialogue.skipped + 1
            return retval
        end)
    end)
    nativeDialogue.installed = ok
    if not ok then nativeDialogue.last = "GUIBase name hook failed" end
end
installNativeDialogueNameHook()

-- v2.9 ALPHA: NATIVE INTERACTION TEXT. Scope: current reqDisp target ONLY.
-- The v0.2 report found TxtTalk 431/431 times, but original get_Message()
-- failed 431/431 times. Never try to preserve unknown prompt strings.
-- ---------------------------------------------------------------------------
local function nativePromptLabel(character)
    if not character then return nil end
    local id = safePawnAccess(function() return character:get_CharaID() end)
    if not id then return nil end
    -- Keep internal name lookups vanilla even when the current dialogue
    -- speaker matches the prompt target; prevents duplicated [affinity] tags.
    nativeDialogue.depth = nativeDialogue.depth + 1
    local name = safePawnAccess(function() return translateCharacterName(id) end)
    nativeDialogue.depth = nativeDialogue.depth - 1
    if type(name) ~= "string" or name == "" or name == "Unknown" then return nil end
    local number
    if pawnState.character and sameHudCharacter(character, pawnState.character) then
        number = pawnState.value
    else
        local manager = getCharacterManager()
        local player = manager and safePawnAccess(function() return manager:get_ManualPlayer() end)
        if not player or sameHudCharacter(character, player) then return nil end
        local npcManager = getNPCManager()
        local holder = npcManager and safePawnAccess(function()
            return npcManager:getNPCHolder(id)
        end)
        local sentiment = holder and safePawnAccess(function()
            return holder:getSentimentInfo(player:get_CharaID(), false)
        end)
        number = sentiment and tonumber(sentiment.Value)
    end
    number = tonumber(number)
    if not number or number ~= number then return nil end
    if #name > 22 then name = name:sub(1,19) .. "..." end
    -- ASCII is used until the native prompt's available font/width is tested.
    return name .. " [" .. tostring(math.floor(number + 0.5)) .. "]"
end

local function installNativePromptHook()
    local td = safePawnAccess(function() return sdk.find_type_definition("app.ui021301") end)
    local method = td and safePawnAccess(function()
        return td:get_method("reqDispCommon(System.Single, System.Guid)")
    end)
    if not method or type(sdk.hook) ~= "function" then
        nativePrompt.last = "missing reqDispCommon"
        return
    end
    local success = pcall(function()
        sdk.hook(method, function(args)
            nativePrompt.ui = args and safePawnAccess(function()
                return sdk.to_managed_object(args[2])
            end)
        end, function(retval)
            local target, ui = nativePrompt.target, nativePrompt.ui
            nativePrompt.target, nativePrompt.ui = nil, nil
            if config.NativePromptEnabled and target and ui then
                local ok = pcall(function()
                    local label = nativePromptLabel(target)
                    local text = label and (safePawnAccess(function() return ui.TxtTalk end)
                        or safePawnAccess(function() return ui:get_field("TxtTalk") end))
                    if not text then
                        nativePrompt.skipped = nativePrompt.skipped + 1
                        return
                    end
                    text:set_Message(label)
                    nativePrompt.written = nativePrompt.written + 1
                    nativePrompt.last = label
                end)
                if not ok then
                    nativePrompt.failures = nativePrompt.failures + 1
                    nativePrompt.last = "set_Message failed"
                end
            end
            return retval
        end)
    end)
    nativePrompt.installed = success
    if not success then nativePrompt.last = "hook failed" end
end
installNativePromptHook()

local function drawPawnChangeToast()
    if not config.ShowPawnChangeToast or pawnState.value == nil then return end
    if pawnHud.delta == 0 or hudNow() >= pawnHud.changeEnds then return end
    if not draw or not draw.filled_rect or not draw.text then return end
    pcall(function()
        local size = imgui.get_display_size()
        if not size or not size.x or size.x < 350 then return end
        local x, y = size.x - 290, 65
        local sign = pawnHud.delta > 0 and "+" or ""
        local color = pawnHud.delta > 0 and 0xFF84CE95 or 0xFF5A5ADD
        draw.filled_rect(x - 7, y - 8, 263, 37, 0xD0181818)
        draw.text("MAIN PAWN  " .. sign .. tostring(pawnHud.delta)
            .. "  (" .. tostring(pawnState.value) .. "/1000)", x, y, color)
    end)
end
-- End of native UI and pawn-notification helpers.

-- v2.7: DD2 shop/buy/sell/pause menu overlay suppression.
-- Do not clear the dialogue target or alter NPC/pawn values while suppressed.
local menuGuard = { active = false, reason = "none", available = false }
local function menuFlag(object, method)
    if not object then return false end
    local ok, result = pcall(function() return object:call(method) end)
    return ok and result == true
end
local function updateMenuGuard()
    menuGuard.active, menuGuard.reason, menuGuard.available = false, "none", false
    if not config.HideDuringGameMenus then return false end
    local gui = safePawnAccess(function()
        return sdk.get_managed_singleton("app.GuiManager")
    end)
    local pause = safePawnAccess(function()
        return sdk.get_managed_singleton("app.PauseManager")
    end)
    menuGuard.available = gui ~= nil or pause ~= nil
    if menuFlag(gui, "isPausedGUI") then
        menuGuard.active, menuGuard.reason = true, "GUI paused"
    elseif menuFlag(gui, "get_IsLoadGui") then
        menuGuard.active, menuGuard.reason = true, "full-screen GUI"
    elseif menuFlag(pause, "isPausedAny") then
        menuGuard.active, menuGuard.reason = true, "game paused"
    else
        local photo = safePawnAccess(function()
            return gui and gui:get_field("<IsDispPhotoModeAll>k__BackingField")
        end)
        if photo == true then
            menuGuard.active, menuGuard.reason = true, "photo mode"
        end
    end
    return menuGuard.active
end

local function runAffinityScan()
    local charMgr, npcMgr = getCharacterManager(), getNPCManager()
    if not charMgr or not npcMgr then return end
    local player = charMgr:get_ManualPlayer()
    if not player then return end
    checkPlayerSession(player)
    local playerID = player:get_CharaID()
    local dic = npcMgr.NPCHolderDic
    if not dic then return end

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
        end)
    end
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
        trackMainPawnChanges()
        if config.Enabled then pcall(runAffinityScan) end
    end
    -- The only custom overlay is the independent Main Pawn gain/loss toast.
    local blocked = updateMenuGuard()
    nativeDialogue.blocked = blocked
    if not blocked then drawPawnChangeToast() end
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
                or isNPCUnlocked(getPermanentID(npcHolder.CharaID))) then
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

    changed, config.NativePromptEnabled = imgui.checkbox(
        "Show Affinity in Native Talk Prompt", config.NativePromptEnabled)
    if changed then nativePrompt.target = nil; saveConfig() end
    if imgui.is_item_hovered() then
        imgui.set_tooltip("Display name and affinity in the native Talk prompt.")
    end
    changed, config.NativeDialogueAffinity = imgui.checkbox(
        "Show Affinity on Native Dialogue Speaker", config.NativeDialogueAffinity)
    if changed then saveConfig() end
    if imgui.is_item_hovered() then
        imgui.set_tooltip("Show affinity beside the native dialogue speaker name.")
    end
    imgui.text("Native prompt: " .. (nativePrompt.installed and "hooked" or "unavailable")
        .. "; writes=" .. tostring(nativePrompt.written)
        .. "; failures=" .. tostring(nativePrompt.failures))
    imgui.text("Native dialogue: " .. (nativeDialogue.installed and "hooked" or "unavailable")
        .. "; names=" .. tostring(nativeDialogue.renamed)
        .. "; failures=" .. tostring(nativeDialogue.failures))
    if not nativePrompt.installed or not nativeDialogue.installed then
        imgui.text("Native UI unavailable; check REFramework / game update.")
    end
    changed, config.HideDuringGameMenus = imgui.checkbox(
        "Hide Affinity HUD in Game Menus", config.HideDuringGameMenus)
    if changed then saveConfig() end
    if imgui.is_item_hovered() then
        imgui.set_tooltip("Hide the HUD and affinity toast in shop, inventory and pause menus.\nThe conversation target is preserved when a menu opens.")
    end
    imgui.text("Menu checker: " .. (
        not config.HideDuringGameMenus and "OFF" or
        (menuGuard.active and menuGuard.reason or
            (menuGuard.available and "no blocking menu" or "GUI state unavailable"))
    ))

    imgui.spacing()

    -- Main Pawn uses native FavorabilityRating (0..1000), NOT NPC SentimentInfo.
    -- Its UI remains available even when NPC affinity capping is disabled.
    imgui.separator()
    if imgui.tree_node("Main Pawn Affinity (Read-only)") then

        changed, config.ShowPawnChangeToast = imgui.checkbox(
            "Notify on Main Pawn Affinity Change", config.ShowPawnChangeToast)
        if changed then saveConfig() end
        changed, config.PawnToastSeconds = imgui.slider_int(
            "Notification seconds", config.PawnToastSeconds, 2, 12)
        if changed then saveConfig() end
        imgui.text("Native affinity display; Main Pawn favorability is read-only.")
        imgui.text("Dialogue observer: " .. talkTracker.hookStatus)
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
    imgui.text("UNLOCKED bypasses this mod's cap, not DD2's own 199 soft cap.")

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
                local isUnlocked = isNPCUnlocked(npc.strID)

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
                    if imgui.is_item_hovered() then
                        imgui.set_tooltip("Mod 199 cap: INACTIVE for this NPC (ID: " .. npc.strID ..
                            "). DD2 may independently hold affinity at 199 until a gift or quest.")
                    end
                else
                    imgui.text_colored("CAPPED",   0xFF60609C)
                    if imgui.is_item_hovered() then
                        imgui.set_tooltip("Mod cap active: " .. tostring(config.CapValue) ..
                            " (NPC ID: " .. npc.strID .. ")")
                    end
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
                        -- Start a fresh anti-loss baseline on transition from
                        -- a locked 199 state to the unlocked rule.
                        sessionHighs[npc.strID] = nil
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
                                        local maxVal = isNPCUnlocked(npc.strID) and 299 or config.CapValue
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
    pawnHud         = { previous = nil, delta = 0, changeEnds = 0, pawnKey = nil }
    talkTracker     = { eventTarget = nil, eventAt = 0,
        hookStatus = talkTracker.hookStatus }
    nativePrompt.target, nativePrompt.ui = nil, nil
    nativeDialogue.callStack, nativeDialogue.depth, nativeDialogue.blocked = {}, 0, false
end)
