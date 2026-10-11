-- =============================================================================
-- Weight System Tweaks  v3.0
-- Original v1.0 by xyzkljl1 (NexusMods mod #415) — core weight engine, SubCategory
--   toggles, removeEquip hook
-- Gemini v2.3 — visual tooltip database patch, dragon-forge weight, cleaner structure
-- This rewrite — bug fixes, restored features, session patterns
--
-- CHANGES FROM GEMINI v2.3
-- ────────────────────────
-- FIX (🔴): Pending save debounce moved to re.on_frame.
--   Debounce check was inside the imgui.tree_node block — any settings change made
--   before closing the menu was silently lost if the tree was collapsed before the
--   1-second timer fired. Save now persists regardless of UI state.
--
-- FIX (🔴): Dragon-forged 0.5× weight only applies when the mod is enabled.
--   The disabled path in RecalcWeight still ran the dragon-forge halving, meaning
--   disabling the mod kept dragon-forged equipment at half weight permanently.
--
-- FIX (🟡): loadConfig starts from defaults, copies only known keys.
--   Old approach iterated the loaded JSON and wrote every key. A corrupt or
--   hand-edited JSON (e.g. stale ItemCategory["5"]) could inject garbage values.
--
-- FIX (🟡): re.on_script_reset added — OriginalWeights and singleton caches are
--   cleared on REFramework hot-reload, preventing stale data being re-used.
--
-- RESTORED: ItemSubCategory granular toggles (Heal / Buff / Material / Special /
--   Quest / Book / Arrow / Custom Skill / Pawn Skill / Magic Book / Online).
--   Gemini v2.3 dropped this entire feature from the original mod.
--
-- RESTORED: removeEquip hook.
--   Gemini v2.3 dropped this. Without it, Warfarer weapon unequip does not always
--   trigger callEquipChangeFunc and the weight display falls behind.
--
-- IMPROVED: get_IsParam() guard replaces pcall around get_ItemParam().
--   get_IsParam() is a confirmed method (scraper-verified) that safely tests whether
--   an item has an ItemDataParam (cat 0/1/2) before calling get_ItemParam().
--
-- IMPROVED: get_IsWeaponData() replaces the <DataType>k__BackingField==2 hack.
--   Both are confirmed in scraper. The property method is cleaner and intent-clear.
--
-- IMPROVED: validateConfig() type-checks and clamps all fields on load.
--
-- CONFIRMED NON-BUGS (cross-checked against original and scraper):
--   _Weight is System.Int16; display kg = _Weight / 100 (e.g. 160 → 1.60 kg).
--   OriginalWeights keys are tostring(_Id) — Lua numbers, consistent across lookups.
--   _entries traversal via get_Count() + entries[i] is the confirmed working pattern.
--   sentimentInfo / direct field writes on managed objects propagate to the game.
-- =============================================================================

local modName    = "WeightSystemTweaks"
local modVersion = "3.0"
local configPath = modName .. ".json"

local function Log(msg)
    log.info("[" .. modName .. "] " .. msg)
end

-- =============================================================================
-- CONFIG
-- =============================================================================
local defaultConfig = {
    Enabled                        = true,
    NoUnequippedWeight             = true,
    WarfarerFix                    = true,
    NonEquipmentZeroWeight         = false,
    Visuals_ShowZeroForConsumables = true,
    Visuals_ShowZeroForMaterials   = true,
    Visuals_ShowZeroForEquipment   = false,
    ItemCategory = {
        ["0"] = true,   -- Consumables
        ["1"] = true,   -- Materials
        ["2"] = true,   -- Key / Other
        ["3"] = true,   -- Equipment
    },
    ItemSubCategory = {
        ["0"]  = true,  -- Heal
        ["1"]  = true,  -- Buff
        ["2"]  = true,  -- Material
        ["3"]  = true,  -- Special
        ["4"]  = false, -- Quest items (0-weight by design in vanilla)
        ["5"]  = true,  -- Books
        ["6"]  = true,  -- Arrows
        ["7"]  = true,  -- Custom Skills
        ["8"]  = true,  -- Pawn Skills
        ["9"]  = true,  -- Magic Books
        ["10"] = true,  -- Online
    },
}

local config = {}

local function validateConfig()
    local boolKeys = {
        "Enabled", "NoUnequippedWeight", "WarfarerFix", "NonEquipmentZeroWeight",
        "Visuals_ShowZeroForConsumables", "Visuals_ShowZeroForMaterials",
        "Visuals_ShowZeroForEquipment",
    }
    for _, k in ipairs(boolKeys) do
        if type(config[k]) ~= "boolean" then config[k] = defaultConfig[k] end
    end

    if type(config.ItemCategory)    ~= "table" then config.ItemCategory    = {} end
    if type(config.ItemSubCategory) ~= "table" then config.ItemSubCategory = {} end

    -- Fill any missing sub-keys from defaults (safe across version upgrades)
    for k, v in pairs(defaultConfig.ItemCategory)    do
        if config.ItemCategory[k]    == nil then config.ItemCategory[k]    = v end
    end
    for k, v in pairs(defaultConfig.ItemSubCategory) do
        if config.ItemSubCategory[k] == nil then config.ItemSubCategory[k] = v end
    end
end

local function saveConfig()
    json.dump_file(configPath, config)
end

local function loadConfig()
    -- Always start from defaults so new keys appear on upgrade
    config.ItemCategory    = {}
    config.ItemSubCategory = {}
    for k, v in pairs(defaultConfig) do
        if type(v) ~= "table" then config[k] = v end
    end
    for k, v in pairs(defaultConfig.ItemCategory)    do config.ItemCategory[k]    = v end
    for k, v in pairs(defaultConfig.ItemSubCategory) do config.ItemSubCategory[k] = v end

    local loaded = json.load_file(configPath)
    if loaded then
        -- Only copy scalar keys that exist in defaultConfig
        for k, v in pairs(loaded) do
            if k ~= "ItemCategory" and k ~= "ItemSubCategory" and defaultConfig[k] ~= nil then
                config[k] = v
            end
        end
        -- Only copy table sub-keys that exist in defaults
        if type(loaded.ItemCategory) == "table" then
            for k, v in pairs(loaded.ItemCategory) do
                if defaultConfig.ItemCategory[k] ~= nil then
                    config.ItemCategory[k] = v
                end
            end
        end
        if type(loaded.ItemSubCategory) == "table" then
            for k, v in pairs(loaded.ItemSubCategory) do
                if defaultConfig.ItemSubCategory[k] ~= nil then
                    config.ItemSubCategory[k] = v
                end
            end
        end
        validateConfig()
    else
        saveConfig()
    end
end
loadConfig()

-- =============================================================================
-- SINGLETON CACHE  (lazy getters — cleared on scene change and script reset)
-- =============================================================================
local _itemMgr = nil
local _charMgr = nil

local function getItemManager()
    if not _itemMgr then
        _itemMgr = sdk.get_managed_singleton("app.ItemManager")
    end
    return _itemMgr
end

local function getCharacterManager()
    if not _charMgr then
        _charMgr = sdk.get_managed_singleton("app.CharacterManager")
    end
    return _charMgr
end

-- =============================================================================
-- ORIGINAL WEIGHT CACHE
-- Keys: tostring(_Id)  (Lua numbers — System.Int32 via get_field unboxes cleanly)
-- Values: raw System.Int16 units  (display kg = value / 100, e.g. 160 → 1.60 kg)
-- All items stored, including those with weight 0, so restore is always accurate.
-- =============================================================================
local OriginalWeights = {}

local function ensureOriginalWeights()
    local itemMgr = getItemManager()
    if not itemMgr then return end

    local dict = itemMgr:get_field("_ItemDataDict")
    if not dict then return end

    local count   = dict:get_Count()
    local entries = dict:get_field("_entries")
    if not entries then return end

    for i = 0, count - 1 do
        local entry = entries[i]
        if entry then
            local param = entry:get_field("value")
            if param then
                local key = tostring(param._Id)
                if OriginalWeights[key] == nil then
                    -- Store all items (including 0-weight) so restore is lossless
                    OriginalWeights[key] = param._Weight
                end
            end
        end
    end
end

-- =============================================================================
-- VISUAL DATABASE PATCH
-- Writes zeroes into _ItemDataDict so the in-menu tooltip shows 0.00 kg.
-- RecalcWeight always reads from OriginalWeights — this does not affect physics.
-- Called on config change, scene entry, and startup.
-- =============================================================================
local function UpdateItemDatabase()
    ensureOriginalWeights()

    local itemMgr = getItemManager()
    if not itemMgr then return end

    local dict = itemMgr:get_field("_ItemDataDict")
    if not dict then return end

    local count   = dict:get_Count()
    local entries = dict:get_field("_entries")
    if not entries then return end

    for i = 0, count - 1 do
        local entry = entries[i]
        if entry then
            local param = entry:get_field("value")
            if param then
                local key    = tostring(param._Id)
                local origin = OriginalWeights[key]
                if origin ~= nil then
                    local cat    = tonumber(param._Category) or 0
                    local target = origin  -- default: always restore original

                    if config.Enabled then
                        if     cat == 0 and config.Visuals_ShowZeroForConsumables then
                            target = 0
                        elseif cat == 1 and config.Visuals_ShowZeroForMaterials then
                            target = 0
                        elseif cat == 2 and config.NonEquipmentZeroWeight then
                            -- Key items share the NonEquipmentZeroWeight toggle for visuals
                            target = 0
                        elseif cat == 3 and config.Visuals_ShowZeroForEquipment then
                            target = 0
                        end
                    end

                    param:set_field("_Weight", target)
                end
            end
        end
    end
end

-- =============================================================================
-- PHYSICS ENGINE
-- RecalcWeight always reads from OriginalWeights (not the potentially-patched
-- _Weight field), so visual and physics are fully decoupled.
--
-- SubCategory check uses get_IsParam() (scraper-confirmed) as a guard before
-- calling get_ItemParam(). Equipment (cat 3) never has ItemDataParam, so
-- SubCategory toggles only apply to cat 0/1/2.
--
-- WarfarerFix: weapons (get_IsWeaponData()) are tracked per equip slot; only
-- the heaviest main-hand and heaviest off-hand contribute to total weight.
-- This correctly handles Warfarer carrying multiple weapons simultaneously.
--
-- Dragon-forge: equipped gear at EnhanceStep >= 4 weighs half. Rounded to
-- nearest integer to handle odd Int16 values (e.g. _Weight=167 → 84, not 83).
-- ONLY applied when config.Enabled is true.
-- =============================================================================
local function RecalcWeight()
    local itemMgr = getItemManager()
    local charMgr = getCharacterManager()
    if not itemMgr or not charMgr then return end

    local player = charMgr:get_ManualPlayer()
    if not player then return end
    local charId = player:get_CharaID()

    local storageDict = itemMgr.StorageDict
    if not storageDict then return end
    local storageList = storageDict:get_Item(charId)
    if not storageList then return end

    local totalWeight  = 0
    local heaviestMain = 0
    local heaviestOff  = 0
    local count        = storageList:get_Count()

    for i = 0, count - 1 do
        local master = storageList:get_Item(i)
        if master then
            local data     = master._Param
            local itemData = data and data._ItemData
            if itemData then
                local catInt = tonumber(itemData._Category) or 0
                local catStr = tostring(catInt)

                -- ── Category toggle ───────────────────────────────────────
                if config.ItemCategory[catStr] == false then
                    -- skip this item
                else
                    -- ── SubCategory toggle (cat 0/1/2 only) ──────────────
                    local subCatBlocked = false
                    if catInt ~= 3 and itemData:get_IsParam() then
                        local subParam = itemData:get_ItemParam()
                        if subParam then
                            local subStr = tostring(tonumber(subParam._SubCategory) or 0)
                            if config.ItemSubCategory[subStr] == false then
                                subCatBlocked = true
                            end
                        end
                    end

                    if not subCatBlocked then
                        -- Base weight from original cache (not the patched tooltip value)
                        local baseWeight = OriginalWeights[tostring(itemData._Id)]
                        if baseWeight == nil then baseWeight = itemData._Weight end

                        -- ── Mod disabled: pure vanilla, no adjustments ────
                        if not config.Enabled then
                            totalWeight = totalWeight + baseWeight * data._Num

                        -- ── Non-equipment ─────────────────────────────────
                        elseif catInt ~= 3 then
                            if not config.NonEquipmentZeroWeight then
                                totalWeight = totalWeight + baseWeight * data._Num
                            end

                        -- ── Equipment ─────────────────────────────────────
                        else
                            local isEquipped = data._IsEquipped

                            -- Skip unequipped gear if Magic Pockets is on
                            if not (config.NoUnequippedWeight and not isEquipped) then
                                -- Dragon-forged: equipped gear at step 4+ weighs half
                                -- Using nearest-integer rounding for odd Int16 values
                                local step = data._EnhanceStep
                                if step and step >= 4 then
                                    baseWeight = math.floor(baseWeight * 0.5 + 0.5)
                                end

                                -- Warfarer fix: track heaviest weapon per hand slot
                                -- get_IsWeaponData() is scraper-confirmed (DataType 2)
                                if config.WarfarerFix and itemData:get_IsWeaponData() then
                                    local slot = data._EquipSlot
                                    if slot == 0 then
                                        if baseWeight > heaviestMain then
                                            heaviestMain = baseWeight
                                        end
                                    elseif slot == 1 then
                                        if baseWeight > heaviestOff then
                                            heaviestOff = baseWeight
                                        end
                                    end
                                else
                                    totalWeight = totalWeight + baseWeight
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Add heaviest weapons after loop (only when mod is on and WarfarerFix is on)
    if config.Enabled and config.WarfarerFix then
        totalWeight = totalWeight + heaviestMain + heaviestOff
    end

    local weightDict = itemMgr.WeightDict
    if weightDict then
        weightDict:set_Item(charId, totalWeight)
    end
end

-- =============================================================================
-- HOOKS
-- =============================================================================
local function safeHook(typeName, methodSig, post)
    local t = sdk.find_type_definition(typeName)
    if not t then
        Log("Hook: type not found — " .. typeName)
        return
    end
    local m = t:get_method(methodSig)
    if not m then
        Log("Hook: method not found — " .. methodSig)
        return
    end
    local ok, err = pcall(sdk.hook, m, function(args) end, post)
    if not ok then
        Log("Hook failed — " .. methodSig .. ": " .. tostring(err))
    end
end

-- Equipment changed (covers equip, swap, and most unequip cases)
safeHook("app.ItemManager",
    "callEquipChangeFunc(app.ItemDefine.StorageData, app.Character, app.EquipData.SlotEnum, System.Boolean, System.Boolean, System.Boolean)",
    function(ret) RecalcWeight(); return ret end)

-- Equipment explicitly removed (needed for Warfarer unequip edge case —
-- original v1.0 had this; Gemini v2.3 dropped it)
safeHook("app.ItemManager",
    "removeEquip(app.ItemDefine.StorageData, app.Character, System.Boolean, System.Boolean)",
    function(ret) RecalcWeight(); return ret end)

-- Item added or removed from inventory (pick up, sell, use, etc.)
safeHook("app.ItemManager",
    "addStorageEvent(app.ItemManager.StorageEventType, System.Int32, System.Int32, System.Int32, app.ItemCommonParam, app.CharacterID, app.Character, app.CharacterID)",
    function(ret) RecalcWeight(); return ret end)

-- Scene transition: clear stale singleton caches then re-init
safeHook("app.GuiManager",
    "OnChangeSceneType",
    function(ret)
        _itemMgr = nil
        _charMgr = nil
        ensureOriginalWeights()
        UpdateItemDatabase()
        RecalcWeight()
        return ret
    end)

-- Startup
ensureOriginalWeights()
UpdateItemDatabase()
RecalcWeight()

-- =============================================================================
-- PENDING SAVE  — debounce runs in re.on_frame, NOT inside the UI tree node.
-- Gemini v2.3 had the debounce check inside imgui.tree_node: if the user made a
-- change then closed the menu before 1 second elapsed, the write never fired.
-- =============================================================================
local pending_save   = false
local last_edit_time = 0
local SAVE_DEBOUNCE  = 1.0

re.on_frame(function()
    if pending_save and (os.clock() - last_edit_time) >= SAVE_DEBOUNCE then
        saveConfig()
        pending_save = false
    end
end)

local function markDirty()
    pending_save   = true
    last_edit_time = os.clock()
end

-- =============================================================================
-- UI
-- =============================================================================
local COLOR_BUTTON        = 0xFF006FC5
local COLOR_BUTTON_HOVER  = 0xFF2090E0
local COLOR_BUTTON_ACTIVE = 0xFFF58000

local function styledButton(label, callback)
    imgui.push_style_color(imgui.Col_Button,        COLOR_BUTTON)
    imgui.push_style_color(imgui.Col_ButtonHovered,  COLOR_BUTTON_HOVER)
    imgui.push_style_color(imgui.Col_ButtonActive,   COLOR_BUTTON_ACTIVE)
    if imgui.button(label) then callback() end
    imgui.pop_style_color(3)
end

re.on_draw_ui(function()
    if not imgui.tree_node("Weight System Tweaks") then return end

    local changed        = false
    local needs_db_patch = false
    local needs_recalc   = false

    -- ── Master toggle ────────────────────────────────────────────────────────
    changed, config.Enabled = imgui.checkbox("Enable Mod", config.Enabled)
    if changed then
        needs_db_patch = true
        needs_recalc   = true
        markDirty()
    end

    if config.Enabled then
        imgui.spacing()
        imgui.text_colored("Weight Rules", 0xFF00FFFF)
        imgui.separator()

        changed, config.NoUnequippedWeight = imgui.checkbox(
            "Magic Pockets  (Unequipped Gear Weighs 0)", config.NoUnequippedWeight)
        if changed then needs_recalc = true; markDirty() end

        changed, config.WarfarerFix = imgui.checkbox(
            "Warfarer Fix  (Only Count Heaviest Weapon Per Hand)", config.WarfarerFix)
        if changed then needs_recalc = true; markDirty() end

        changed, config.NonEquipmentZeroWeight = imgui.checkbox(
            "Make All Items & Materials Weightless", config.NonEquipmentZeroWeight)
        if changed then
            -- Sync visual flags to match bulk weightless toggle
            config.Visuals_ShowZeroForConsumables = config.NonEquipmentZeroWeight
            config.Visuals_ShowZeroForMaterials   = config.NonEquipmentZeroWeight
            needs_db_patch = true
            needs_recalc   = true
            markDirty()
        end

        -- ── Visual tooltip settings ──────────────────────────────────────────
        imgui.spacing()
        imgui.text_colored("Visual Settings  (Item Tooltip Display)", 0xFF00FFFF)
        if imgui.is_item_hovered() then
            imgui.set_tooltip(
                "Forces the in-menu item weight card to show 0.00 kg.\n" ..
                "Does not change the actual carried weight calculation.")
        end
        imgui.separator()

        changed, config.Visuals_ShowZeroForConsumables = imgui.checkbox(
            "Show 0.00 kg for Consumables", config.Visuals_ShowZeroForConsumables)
        if changed then needs_db_patch = true; markDirty() end

        changed, config.Visuals_ShowZeroForMaterials = imgui.checkbox(
            "Show 0.00 kg for Materials", config.Visuals_ShowZeroForMaterials)
        if changed then needs_db_patch = true; markDirty() end

        changed, config.Visuals_ShowZeroForEquipment = imgui.checkbox(
            "Show 0.00 kg for Unequipped Gear", config.Visuals_ShowZeroForEquipment)
        if changed then needs_db_patch = true; markDirty() end

        -- ── Category toggles ─────────────────────────────────────────────────
        imgui.spacing()
        imgui.text_colored("Category Toggles  (Include in Weight Total)", 0xFF00FFFF)
        imgui.separator()

        changed, config.ItemCategory["0"] = imgui.checkbox("Count Consumables",    config.ItemCategory["0"])
        if changed then needs_recalc = true; markDirty() end
        changed, config.ItemCategory["1"] = imgui.checkbox("Count Materials",      config.ItemCategory["1"])
        if changed then needs_recalc = true; markDirty() end
        changed, config.ItemCategory["2"] = imgui.checkbox("Count Key / Other",    config.ItemCategory["2"])
        if changed then needs_recalc = true; markDirty() end
        changed, config.ItemCategory["3"] = imgui.checkbox("Count Equipment",      config.ItemCategory["3"])
        if changed then needs_recalc = true; markDirty() end

        -- ── Sub-category toggles ─────────────────────────────────────────────
        imgui.spacing()
        imgui.text_colored("Sub-Category Toggles  (Include in Weight Total)", 0xFF00FFFF)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Fine-grained control within Consumables and Materials.\nHas no effect on Equipment (cat 3).")
        end
        imgui.separator()

        local subLabels = {
            {"0",  "Heal Items"},
            {"1",  "Buff Items"},
            {"2",  "Materials"},
            {"3",  "Special Items"},
            {"4",  "Quest Items"},
            {"5",  "Books"},
            {"6",  "Arrows"},
            {"7",  "Custom Skills"},
            {"8",  "Pawn Skills"},
            {"9",  "Magic Books"},
            {"10", "Online Items"},
        }
        for _, pair in ipairs(subLabels) do
            local k, label = pair[1], pair[2]
            changed, config.ItemSubCategory[k] = imgui.checkbox(label, config.ItemSubCategory[k])
            if changed then needs_recalc = true; markDirty() end
        end
    end

    -- ── Utility button ───────────────────────────────────────────────────────
    imgui.spacing()
    styledButton("Force Recalculate Weight Now", function()
        ensureOriginalWeights()
        UpdateItemDatabase()
        RecalcWeight()
    end)

    -- Apply any pending changes triggered this frame
    if needs_db_patch then UpdateItemDatabase() end
    if needs_recalc    then RecalcWeight()       end

    imgui.tree_pop()
end)

-- =============================================================================
-- PERSIST & CLEANUP
-- =============================================================================
re.on_config_save(function()
    saveConfig()
end)

re.on_script_reset(function()
    -- Clear original weight cache so next startup reads fresh values from game
    OriginalWeights = {}
    pending_save    = false
    _itemMgr        = nil
    _charMgr        = nil
    Log("Script reset — caches cleared.")
end)

Log("Loaded v" .. modVersion)
