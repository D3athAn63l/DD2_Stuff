-- Pocket Universe v0.1.0-experimental (Dragon's Dogma 2 / REFramework)
-- One toggle; read-time overrides only. Does not modify saved items, pawns, or inventory fields.
-- Direct WeightDict access and other non-getter paths are not intercepted.
local NAME, VERSION = 'Pocket Universe', '0.1.0-experimental'
local FILE = 'PocketUniverse.json'
local function note(s)
    if log and log.info then log.info('[Pocket Universe] ' .. tostring(s)) end
end
local enabled, dirty = true, false
local ok, data = pcall(function() return json.load_file(FILE) end)
if ok and type(data) == 'table' and type(data.Enabled) == 'boolean' then
    enabled = data.Enabled
end
local hooks = { weight = 0, rank = 0 }
local function save()
    if not dirty then return end
    local saved, result = pcall(function()
        return json.dump_file(FILE, { Enabled = enabled })
    end)
    if saved and result == true then dirty = false
    else note('Failed saving configuration; retry at next config save') end
end
local function hook(signature, kind)
    local success, installed = pcall(function()
        local typ = sdk.find_type_definition('app.ItemManager')
        local method = typ and typ:get_method(signature)
        if not method then return false end
        sdk.hook(method, function() end, function(ret)
            if not enabled then return ret end
            if kind == 'float' then return sdk.float_to_ptr(0.0) end
            return sdk.to_ptr(0)
        end)
        return true
    end)
    if success and installed then
        if kind == 'rank' then hooks.rank = hooks.rank + 1
        else hooks.weight = hooks.weight + 1 end
    else note('Hook unavailable: ' .. signature) end
end
hook('getStorageWeight(app.Character)', 'float')
hook('getStorageWeight(app.CharacterID)', 'float')
hook('getStorageWeightInt(app.CharacterID)', 'int')
for _, sig in ipairs({
    'getWeightRank(System.Single, System.Single)',
    'getWeightRank(System.Single, System.Single, app.Character)',
    'getWeightRank(System.Single, System.Single, app.CharacterID, app.IEquipStorageDataGetter)',
    'getWeightRank(System.Single, app.Character)',
    'getWeightRank(app.Character)',
    'getWeightRank(app.CharacterID)',
}) do hook(sig, 'rank') end
re.on_draw_ui(function()
    if not imgui.tree_node(NAME) then return end
    local changed, nextValue = imgui.checkbox('Enable', enabled)
    if changed then
        enabled = nextValue == true
        dirty = true
        save()
        note('Enable = ' .. tostring(enabled))
    end
    imgui.text(string.format('%s | weight hooks %d/3 | rank hooks %d/6', VERSION, hooks.weight, hooks.rank))
    imgui.tree_pop()
end)
re.on_config_save(save)
re.on_script_reset(save)
note(VERSION .. ' | weight hooks ' .. hooks.weight .. '/3 | rank hooks ' .. hooks.rank .. '/6')
