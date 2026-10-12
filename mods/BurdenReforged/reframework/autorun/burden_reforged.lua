-- Burden Reforged 0.1.1 (experimental)
-- Independent REFramework weight-rule implementation for Dragon's Dogma 2.
-- Inspired by the gameplay concept of "Weight System Tweaks" by lingsamuel.
-- This is a new implementation, not a modified copy or redistribution of that mod.
-- REFramework saves this configuration inside reframework/data/.

local NAME, VERSION = 'Burden Reforged', '0.1.1-experimental'
local FILE, LEGACY_FILE = 'BurdenReforged.json', 'WeightSystemTweaks.json'
local function note(message)
    if log and log.info then log.info('[Burden Reforged] ' .. tostring(message)) end
end

local defaults = {
    Enabled = true,
    NoUnequippedWeight = true,
    WarfarerFix = true,
    NonEquipmentZeroWeight = false,
    Visuals_ShowZeroForConsumables = true,
    Visuals_ShowZeroForMaterials = true,
    Visuals_ShowZeroForEquipment = false,
    ItemCategory = {['0']=true, ['1']=true, ['2']=true, ['3']=true},
    ItemSubCategory = {
        ['0']=true, ['1']=true, ['2']=true, ['3']=true, ['4']=false,
        ['5']=true, ['6']=true, ['7']=true, ['8']=true, ['9']=true, ['10']=true,
    },
}
local config = {}
local configDirty = false
local saveAt = 0

local function safeLoad(path)
    local ok, result = pcall(json.load_file, path)
    return ok and type(result) == 'table' and result or nil
end

local function importOptions(src)
    for name, fallback in pairs(defaults) do
        if type(fallback) == 'boolean' then
            if type(src[name]) == 'boolean' then config[name] = src[name]
            else config[name] = fallback end
        else
            config[name] = {}
            local nested = type(src[name]) == 'table' and src[name] or {}
            for key, value in pairs(fallback) do
                if type(nested[key]) == 'boolean' then config[name][key] = nested[key]
                else config[name][key] = value end
            end
        end
    end
end

local function persist()
    local ok, saved = pcall(json.dump_file, FILE, config)
    if ok and saved == true then
        configDirty = false
        return true
    end
    note('Could not write ' .. FILE .. '; settings remain dirty for retry')
    return false
end

local saved = safeLoad(FILE)
local migrated = false
if not saved then
    saved = safeLoad(LEGACY_FILE)
    migrated = saved ~= nil
end
importOptions(saved or {})
if migrated then note('Imported settings from ' .. LEGACY_FILE .. ' (legacy file preserved)') end
if migrated or not saved then persist() end

-- Mutable state is private to this script instance. Every database edit is tracked
-- so a script reset can restore the raw parameters before the cache disappears.
local state = {
    originals = {},  -- numeric weight per item ID (unmodified snapshot)
    entries = {},    -- ID -> {object, lastApplied}; only visual changes are tracked
    manager = nil,
    managerId = nil,
    indexed = false,
    weightDirty = true,
    visualsDirty = true,
    refreshAt = 0,
    lastFailure = '',
    partySeen = 0,
    partySynced = 0,
}

local function warnOnce(message)
    if state.lastFailure ~= message then
        state.lastFailure = message
        note(message)
    end
end

local function objField(object, name)
    if not object then return nil end
    local ok, value = pcall(function() return object[name] end)
    return ok and value or nil
end

local function writeWeight(param, value)
    local ok = pcall(function() param:set_field('_Weight', value) end)
    return ok
end

local function restoreVisuals()
    for id, record in pairs(state.entries) do
        if record.lastApplied ~= nil then
            local current = objField(record.object, '_Weight')
            -- Avoid overwriting another mod's subsequent change to this object.
            if current == record.lastApplied then
                pcall(writeWeight, record.object, state.originals[id])
            end
            record.lastApplied = nil
        end
    end
end

local function getItemManager()
    local ok, manager = pcall(sdk.get_managed_singleton, 'app.ItemManager')
    return ok and manager or nil
end

local function snapshotItems(manager)
    if not manager then return false end
    local dict = objField(manager, '_ItemDataDict')
    if not dict then
        local ok, field = pcall(function() return manager:get_field('_ItemDataDict') end)
        if ok then dict = field end
    end
    if not dict then return false end
    local ok, count = pcall(function() return dict:get_Count() end)
    if not ok or type(count) ~= 'number' then return false end
    local okEntries, entries = pcall(function() return dict:get_field('_entries') end)
    if not okEntries or not entries then return false end
    -- Use array capacity when exposed: Dictionary.Count can omit valid slots
    -- after deletions. Bounds prevent accidental unbounded work on bad metadata.
    local capacity = count
    local lengthOk, length = pcall(function() return entries:get_Length() end)
    if lengthOk and type(length) == 'number' and length >= count then
        capacity = length
    elseif type(entries) == 'table' then
        local maxKey = -1
        for k in pairs(entries) do
            if type(k) == 'number' and k >= 0 and k > maxKey then maxKey = k end
        end
        capacity = math.max(count, maxKey + 1)
    end
    capacity = math.min(capacity, 50000)
    local found = 0
    for index = 0, capacity - 1 do
        local present, entry = pcall(function() return entries[index] end)
        if present and entry then
            local valid, param = pcall(function() return entry:get_field('value') end)
            if valid and param then
                local id, weight = objField(param, '_Id'), objField(param, '_Weight')
                if id ~= nil and type(weight) == 'number' then
                    id = tostring(id)
                    if state.originals[id] == nil then state.originals[id] = weight end
                    state.entries[id] = state.entries[id] or {}
                    state.entries[id].object = param
                    found = found + 1
                end
            end
        end
    end
    state.indexed = found > 0
    return state.indexed
end

local function visualTarget(param, base)
    if not config.Enabled then return base end
    local category = tonumber(objField(param, '_Category'))
    if category == 0 and config.Visuals_ShowZeroForConsumables then return 0 end
    if category == 1 and config.Visuals_ShowZeroForMaterials then return 0 end
    if category == 2 and config.NonEquipmentZeroWeight then return 0 end
    if category == 3 and config.Visuals_ShowZeroForEquipment then return 0 end
    return base
end

local function refreshVisuals()
    if not state.indexed then return false end
    for id, record in pairs(state.entries) do
        local param, base = record.object, state.originals[id]
        if param and base ~= nil then
            local requested = visualTarget(param, base)
            local current = objField(param, '_Weight')
            if requested ~= current then
                if writeWeight(param, requested) then
                    record.lastApplied = requested
                else
                    warnOnce('Could not update tooltip weights (object may be unloading)')
                end
            elseif requested == base then
                record.lastApplied = nil
            end
        end
    end
    state.visualsDirty = false
    return true
end

local function itemKind(param)
    return tonumber(objField(param, '_Category'))
end

local function isIncluded(param, category)
    if not config.Enabled then return true end
    if category ~= nil and config.ItemCategory[tostring(category)] == false then return false end
    if category == 3 then return true end
    -- Not all items expose app.ItemDataParam, and unknown subcategories count.
    local ok, isParam = pcall(function() return param:get_IsParam() end)
    if not ok or not isParam then return true end
    local success, inner = pcall(function() return param:get_ItemParam() end)
    if not success or not inner then return true end
    local subcategory = tonumber(objField(inner, '_SubCategory'))
    return subcategory == nil or config.ItemSubCategory[tostring(subcategory)] ~= false
end

local function computeWeight(list)
    local total, main, off = 0, 0, 0
    local count = list:get_Count()
    if type(count) ~= 'number' or count < 0 or count > 100000 then return nil end
    for index = 0, count - 1 do
        local row = list:get_Item(index)
        local data = objField(row, '_Param')
        local item = objField(data, '_ItemData')
        if data and item then
            local category, id = itemKind(item), tostring(objField(item, '_Id'))
            if isIncluded(item, category) then
                local mass = state.originals[id]
                if mass == nil then
                    mass = tonumber(objField(item, '_Weight'))
                    if mass ~= nil then state.originals[id] = mass end
                end
                if mass ~= nil then
                    local quantity = math.max(0, tonumber(objField(data, '_Num')) or 1)
                    if not config.Enabled then
                        total = total + mass * quantity
                    elseif category ~= 3 then
                        if not config.NonEquipmentZeroWeight then
                            total = total + mass * quantity
                        end
                    elseif not (config.NoUnequippedWeight and not objField(data, '_IsEquipped')) then
                        local step = tonumber(objField(data, '_EnhanceStep')) or 0
                        if step >= 4 then mass = math.floor(mass / 2 + 0.5) end
                        local isWeapon = false
                        local ok, result = pcall(function() return item:get_IsWeaponData() end)
                        if ok then isWeapon = result == true end
                        if config.WarfarerFix and isWeapon and objField(data, '_IsEquipped') then
                            local slot = tonumber(objField(data, '_EquipSlot'))
                            if slot == 0 then main = math.max(main, mass)
                            elseif slot == 1 then off = math.max(off, mass)
                            else total = total + mass end -- unknown slots must not vanish
                        else
                            total = total + mass
                        end
                    end
                end
            end
        end
    end
    if config.Enabled and config.WarfarerFix then total = total + main + off end
    return math.floor(math.max(0, math.min(total, 2147483647)))
end

-- Party weight is stored per CharacterID. Updating only get_ManualPlayer()
-- leaves pawn WeightDict values stale (typically zero after visual DB patches).
-- ItemManager's getPartyList() and getPartyCharaIds(bool) are present in the
-- owner's DD2 TDB 83 captured signatures (2026-10-11). Either may be unavailable
-- during scene changes, so each access is guarded and bounded.
local function collectPartyIds(manager)
    local ids, seen = {}, {}
    local function add(id)
        if not id or #ids >= 16 then return end
        local key = tostring(id)
        if seen[key] then return end
        seen[key] = true
        ids[#ids+1] = id
    end

    local okChars, chars = pcall(sdk.get_managed_singleton, 'app.CharacterManager')
    if okChars and chars then
        local okPlayer, player = pcall(function() return chars:get_ManualPlayer() end)
        if okPlayer and player then
            local okId, id = pcall(function() return player:get_CharaID() end)
            if okId then add(id) end
        end
    end

    -- Primary: actual party characters; add player separately above, because
    -- the party list's inclusion of the Arisen is build/context-dependent.
    local foundOther = false
    local okParty, party = pcall(function() return manager:getPartyList() end)
    if okParty and party then
        local okCount, count = pcall(function() return party:get_Count() end)
        if okCount and type(count) == 'number' and count >= 0 and count <= 16 then
            for i = 0, count - 1 do
                local okMember, member = pcall(function() return party:get_Item(i) end)
                if okMember and member then
                    local okId, id = pcall(function() return member:get_CharaID() end)
                    if okId and id then add(id); foundOther = true end
                end
            end
        end
    end

    -- Fallback for builds/contexts where the party list cannot be read.
    if not foundOther then
        local okIds, array = pcall(function() return manager:getPartyCharaIds(true) end)
        if okIds and array then
            local okLength, length = pcall(function() return array:get_Length() end)
            if okLength and type(length) == 'number' and length >= 0 and length <= 16 then
                for i = 0, length - 1 do
                    local okId, id = pcall(function() return array[i] end)
                    if okId then add(id) end
                end
            end
        end
    end
    return ids
end

local function synchronize()
    local manager = getItemManager()
    if not manager then return false end
    local key
    if sdk.to_ptr then
        local ok, pointer = pcall(sdk.to_ptr, manager)
        if ok and pointer then key = tostring(pointer) end
    end
    key = key or tostring(manager)
    if key ~= state.managerId then
        if state.manager then restoreVisuals() end
        state.manager = manager
        state.managerId = key
        state.indexed = false
        state.entries = {}
        state.originals = {}
        state.visualsDirty = true
    end
    if not state.indexed then
        if not snapshotItems(manager) then return false end
        state.visualsDirty = true
    end
    -- Restore cosmetic original weights before recalculating every character.
    if state.visualsDirty then refreshVisuals() end

    local stores, weightDict = objField(manager, 'StorageDict'), objField(manager, 'WeightDict')
    if not stores or not weightDict then return false end
    local ids = collectPartyIds(manager)
    state.partySeen = #ids
    state.partySynced = 0
    if #ids == 0 then return false end

    for _, id in ipairs(ids) do
        -- Pawns joining/leaving can temporarily lack a storage list. Do not let
        -- a failed pawn lookup prevent the Arisen or other pawns from syncing.
        local okList, list = pcall(function() return stores:get_Item(id) end)
        if okList and list then
            local okMass, newWeight = pcall(computeWeight, list)
            if okMass and newWeight ~= nil then
                local okOld, oldWeight = pcall(function() return weightDict:get_Item(id) end)
                if not okOld or oldWeight ~= newWeight then
                    local okWrite = pcall(function() weightDict:set_Item(id, newWeight) end)
                    if okWrite then state.partySynced = state.partySynced + 1 end
                else
                    state.partySynced = state.partySynced + 1
                end
            end
        end
    end

    state.weightDirty = state.partySynced < state.partySeen
    if state.partySynced == 0 then
        warnOnce('No party inventory weights could be refreshed yet')
        return false
    end
    state.lastFailure = ''
    return true
end

-- All hooks are O(1): no inventory traversal or engine mutation inside hooks.
local function scheduleRecalc()
    state.weightDirty = true
end

local function registerHook(typeName, signature, postAction)
    local ok, result = pcall(function()
        local definition = sdk.find_type_definition(typeName)
        if not definition then return false end
        local method = definition:get_method(signature)
        if not method then return false end
        sdk.hook(method, function() end, function(resultValue)
            postAction()
            return resultValue
        end)
        return true
    end)
    if not ok or not result then note('Hook unavailable: ' .. typeName .. '.' .. signature) end
end

registerHook('app.ItemManager',
    'addStorageEvent(app.ItemManager.StorageEventType, System.Int32, System.Int32, System.Int32, app.ItemCommonParam, app.CharacterID, app.Character, app.CharacterID)', scheduleRecalc)
registerHook('app.ItemManager',
    'callEquipChangeFunc(app.ItemDefine.StorageData, app.Character, app.EquipData.SlotEnum, System.Boolean, System.Boolean, System.Boolean)', scheduleRecalc)
registerHook('app.ItemManager',
    'removeEquip(app.ItemDefine.StorageData, app.Character, System.Boolean, System.Boolean)', scheduleRecalc)
registerHook('app.GuiManager', 'OnChangeSceneType', function()
    state.weightDirty = true
    state.visualsDirty = true
    state.refreshAt = 0
end)

local function changed()
    state.weightDirty = true
    configDirty = true
    saveAt = os.clock() + 1
end

re.on_frame(function()
    local now = os.clock()
    if (state.weightDirty or state.visualsDirty or now >= state.refreshAt) then
        -- One inventory traversal per frame maximum, plus an infrequent safety refresh.
        local ok, done = pcall(synchronize)
        if not ok then warnOnce('Refresh failed: ' .. tostring(done)) end
        state.refreshAt = now + (done and 0.75 or 0.25)
    end
    if configDirty and now >= saveAt then persist() end
end)

local function check(label, section, key, isVisual)
    local changedNow, value = imgui.checkbox(label, section[key])
    if changedNow then
        section[key] = value
        changed()
        if isVisual then state.visualsDirty = true end
    end
    return changedNow
end

local categories = {
    {'0', 'Consumables'}, {'1', 'Materials'}, {'2', 'Key / Other'}, {'3', 'Equipment'},
}
local subcategories = {
    {'0','Healing'}, {'1','Buffs'}, {'2','Materials'}, {'3','Special'},
    {'4','Quest'}, {'5','Books'}, {'6','Arrows'}, {'7','Custom Skills'},
    {'8','Pawn Skills'}, {'9','Magic Books'}, {'10','Online'},
}

re.on_draw_ui(function()
    if not imgui.tree_node(NAME) then return end
    imgui.text('Burden Reforged ' .. VERSION)
    imgui.text('Party weights refreshed: ' .. state.partySynced .. '/' .. state.partySeen)
    check('Enable weight rules', config, 'Enabled', true)
    if config.Enabled then
        imgui.separator()
        check('Unequipped equipment weighs nothing', config, 'NoUnequippedWeight')
        check('Warfarer: count heaviest weapon in each hand', config, 'WarfarerFix')
        local toggled = check('All non-equipment items weigh nothing', config, 'NonEquipmentZeroWeight', true)
        if toggled then
            config.Visuals_ShowZeroForConsumables = config.NonEquipmentZeroWeight
            config.Visuals_ShowZeroForMaterials = config.NonEquipmentZeroWeight
            state.visualsDirty = true
        end
        imgui.separator()
        imgui.text('Tooltip appearance (changes global item parameters)')
        check('Display 0 for consumables', config, 'Visuals_ShowZeroForConsumables', true)
        check('Display 0 for materials', config, 'Visuals_ShowZeroForMaterials', true)
        check('Display 0 for ALL equipment (including equipped)', config, 'Visuals_ShowZeroForEquipment', true)
        imgui.separator()
        imgui.text('Count these item categories')
        for _, option in ipairs(categories) do
            check(option[2], config.ItemCategory, option[1])
        end
        imgui.separator()
        imgui.text('Count these subcategories')
        for _, option in ipairs(subcategories) do
            check(option[2] .. '##sub_' .. option[1], config.ItemSubCategory, option[1])
        end
    end
    if imgui.button('Recalculate now') then
        state.weightDirty = true
        state.visualsDirty = true
        state.refreshAt = 0
    end
    imgui.tree_pop()
end)

re.on_config_save(function() if configDirty then persist() end end)
re.on_script_reset(function()
    if configDirty then persist() end
    restoreVisuals() -- Must restore BEFORE clearing original-weight snapshots.
    state.entries = {}
    state.originals = {}
    state.manager = nil
    state.managerId = nil
    state.indexed = false
end)

note(VERSION .. ' loaded; restart game before replacing an older weight mod')
