-- Complete Health Restoration v2.0 (DD2 / REFramework)
-- Original concept and user options retained. Updated loss-gauge access and config persistence.
-- Standalone. No dependency on SmoothAutoRestoreHP.

local sdk, imgui, json, re = sdk, imgui, json, re

-- REFramework json.load_file / dump_file paths are relative to reframework/data.
local SETTINGS_FILE = "CompleteHealthRestoration.json"
local LEGACY_FILES = {
    "renpyon\\CompleteHealthRestoration.json",
    "renpyon/CompleteHealthRestoration.json",
}

local defaults = {
    GaugeHealEnabled = true,
    GaugeHealPerc = 0.2,                  -- percent of ORIGINAL max HP restored to gauge per second
    GaugeHealInBattle = false,
    GaugeHealArisen = true,
    GaugeHealPawn = true,
    AutoHealEnable = true,
    AutoHealPerc = 1.0,                   -- percent of target HP healed per second
    AutoHealToMaxHP = false,
    AutoHealBattleRatio = 0.2,
    AutoHealTargetHP = 100.0,
    AutoHealArisen = true,
    AutoHealPawn = true,
}
local config = {}
local save_status = "Not saved in this session"
local config_source = "defaults"
local diagnostics = {
    gaugeWrites = 0,
    gaugeWriteErrors = 0,
    hpWrites = 0,
    lastGaugeStatus = "No gauge restoration attempted yet",
    lastPlayerHp = nil,
    lastPlayerGauge = nil,
    lastPlayerOriginal = nil,
    lastError = nil,
}

local function log_message(message)
    if log and type(log.info) == "function" then
        pcall(log.info, "[CompleteHealthRestoration] " .. tostring(message))
    end
end

local function load_table(path)
    local ok, data = pcall(json.load_file, path)
    if ok and type(data) == "table" then return data end
    return nil
end

local function load_config()
    local data = load_table(SETTINGS_FILE)
    if data then
        config_source = SETTINGS_FILE
    else
        for _, path in ipairs(LEGACY_FILES) do
            data = load_table(path)
            if data then config_source = path; break end
        end
    end
    for key, default in pairs(defaults) do
        local value = nil
        if data ~= nil then value = data[key] end
        if type(default) == "boolean" and type(value) == "boolean" then
            config[key] = value
        elseif type(default) == "number" and type(value) == "number" and
            value == value and value ~= math.huge and value ~= -math.huge then
            config[key] = value
        else
            config[key] = default
        end
    end
    config.GaugeHealPerc = math.max(0, math.min(100, config.GaugeHealPerc))
    config.AutoHealPerc = math.max(0, math.min(100, config.AutoHealPerc))
    config.AutoHealBattleRatio = math.max(0, math.min(1, config.AutoHealBattleRatio))
    config.AutoHealTargetHP = math.max(1, math.min(100, config.AutoHealTargetHP))
end

local function save_config()
    -- json.dump_file returns false without raising for some filesystem errors.
    local ok, result = pcall(json.dump_file, SETTINGS_FILE, config, 4)
    if ok and result == true then
        save_status = "Saved: reframework/data/" .. SETTINGS_FILE
        return true
    end
    save_status = "SAVE FAILED - check re2_framework_log.txt / file permissions"
    diagnostics.lastError = tostring(ok and "json.dump_file returned false" or result)
    log_message(save_status .. ": " .. tostring(diagnostics.lastError))
    return false
end

load_config()
-- Migrate old settings on load; never overwrite an existing v2 settings file.
if config_source ~= SETTINGS_FILE then save_config() end

local function method(obj, name, ...)
    if obj == nil then return nil, false end
    local ok, result = pcall(obj.call, obj, name, ...)
    if ok then return result, true end
    return nil, false
end

local function first_method(obj, names, ...)
    for _, name in ipairs(names) do
        local result, ok = method(obj, name, ...)
        if ok and result ~= nil then return result end
    end
    return nil
end

local function field(obj, name)
    if obj == nil then return nil end
    local ok, value = pcall(function() return obj:get_field(name) end)
    if ok and value ~= nil then return value end
    ok, value = pcall(function() return obj[name] end)
    if ok then return value end
    return nil
end

local function manager(name)
    local ok, value = pcall(sdk.get_managed_singleton, name)
    if ok then return value end
    return nil
end

local function valid_character(character)
    if not character then return false end
    local result = first_method(character, {"get_Valid()", "get_Valid"})
    return result ~= false
end

local function hit_controller(character)
    -- Current-game reference: Hit backing field belongs to app.Character.
    local hit = field(character, "<Hit>k__BackingField")
    if not hit then hit = first_method(character, {"get_Hit()", "get_Hit"}) end
    if hit then return hit end
    -- Legacy access pattern from CompleteHealthRestoration v1.
    local human = first_method(character, {"get_Human()", "get_Human"})
    return field(human, "Hit")
end

local function health_number(character, hit, property)
    local value = first_method(character, {"get_" .. property .. "()", "get_" .. property})
    if type(value) ~= "number" then
        value = first_method(hit, {"get_" .. property .. "()", "get_" .. property})
    end
    if type(value) == "number" and value == value and value ~= math.huge then return value end
    return nil
end

local function set_reduced_max(hit, amount)
    if not hit then return false end
    -- Current reference uses HitController:set_ReducedMaxHp(amount).
    local ok = pcall(function() hit:set_ReducedMaxHp(amount) end)
    if ok then return true end
    -- Compatibility fallback for REFramework versions requiring method signatures.
    local _, called = method(hit, "set_ReducedMaxHp(System.Single)", amount)
    if called then return true end
    _, called = method(hit, "set_ReducedMaxHp", amount)
    return called
end

local function set_hp(hit, amount)
    if not hit then return false end
    local ok = pcall(function() hit:setHpValue(amount, false) end)
    if ok then return true end
    local _, called = method(hit, "setHpValue(System.Single, System.Boolean)", amount, false)
    if called then return true end
    _, called = method(hit, "setHpValue", amount, false)
    return called
end

local function restore(character, is_pawn, dt, in_battle)
    if not valid_character(character) then return end
    local hit = hit_controller(character)
    if not hit then return end
    local hp = health_number(character, hit, "Hp")
    if not hp or hp <= 0 then return end -- Respect death/down state.
    local reduced = health_number(character, hit, "ReducedMaxHp")
    local original = health_number(character, hit, "OriginalMaxHp")
    if not reduced or not original or original <= 0 then return end
    if reduced <= 0 then return end
    reduced = math.min(reduced, original)

    if not is_pawn then
        diagnostics.lastPlayerHp = hp
        diagnostics.lastPlayerGauge = reduced
        diagnostics.lastPlayerOriginal = original
    end

    local gauge_allowed = config.GaugeHealEnabled and (not in_battle or config.GaugeHealInBattle)
        and ((is_pawn and config.GaugeHealPawn) or (not is_pawn and config.GaugeHealArisen))

    if gauge_allowed and reduced < original - 0.0001 and config.GaugeHealPerc > 0 then
        -- Original v1 used % of the *missing* gauge, making its 0.2 default nearly invisible.
        -- v2's 0.2 means 0.2% of original max HP per SECOND, independent of deficit size.
        local restored = math.min(original, reduced + original * (config.GaugeHealPerc / 100) * dt)
        if restored > reduced then
            if set_reduced_max(hit, restored) then
                diagnostics.gaugeWrites = diagnostics.gaugeWrites + 1
                -- For HP heal target, use the effective game value if it can be read back.
                local observed = health_number(character, hit, "ReducedMaxHp")
                if observed and observed > reduced + 0.0001 then
                    reduced = math.min(original, observed)
                    diagnostics.lastGaugeStatus = "Gauge increased (readback confirmed)"
                else
                    diagnostics.lastGaugeStatus = "Gauge setter called; no immediate readback change"
                end
                if not is_pawn then diagnostics.lastPlayerGauge = reduced end
            else
                diagnostics.gaugeWriteErrors = diagnostics.gaugeWriteErrors + 1
                diagnostics.lastGaugeStatus = "Gauge setter unavailable; see log"
                if diagnostics.gaugeWriteErrors == 1 then
                    log_message("Loss gauge setter failed. Please provide the game log and API probe.")
                end
            end
        end
    end

    local hp_allowed = config.AutoHealEnable and
        ((is_pawn and config.AutoHealPawn) or (not is_pawn and config.AutoHealArisen))
    if hp_allowed and config.AutoHealPerc > 0 then
        local hp_cap = config.AutoHealToMaxHP and original or reduced
        local hp_target = hp_cap * (config.AutoHealTargetHP / 100)
        if hp < hp_target - 0.0001 then
            local rate = config.AutoHealPerc / 100
            local scale = in_battle and config.AutoHealBattleRatio or 1
            local amount = hp_target * rate * dt * scale
            if amount > 0 and set_hp(hit, math.min(hp_target, hp + amount)) then
                diagnostics.hpWrites = diagnostics.hpWrites + 1
            end
        end
    end
end

local function combat_state(battle)
    if not battle then return false end
    -- SmoothAutoRestoreHP v1.1 uses get_BattleMode(), returning 0 when idle.
    local mode = first_method(battle, {"get_BattleMode()", "get_BattleMode"})
    if type(mode) == "number" then return mode ~= 0 end
    if type(mode) == "boolean" then return mode end
    -- Compatibility with the original implementation.
    local boolean = first_method(battle, {"get_IsBattleMode()", "get_IsBattleMode"})
    if type(boolean) == "boolean" then return boolean end
    return false
end

local function restore_party(dt)
    if not config.AutoHealEnable and not config.GaugeHealEnabled then return end
    local gui = manager("app.GuiManager")
    local paused = first_method(gui, {"isPausedGUI()", "isPausedGUI"})
    if paused == true then return end

    local cm = manager("app.CharacterManager")
    local pawn_manager = manager("app.PawnManager")
    local battle = manager("app.BattleManager")
    local player = first_method(cm, {"get_ManualPlayer()", "get_ManualPlayer"})
    if not player then player = field(cm, "<ManualPlayer>k__BackingField") end
    if not player then return end

    local in_battle = combat_state(battle)
    restore(player, false, dt, in_battle)

    local pawns = first_method(pawn_manager, {"get_PawnCharacterList()", "get_PawnCharacterList"})
    if not pawns then return end
    local count = first_method(pawns, {"get_Count()", "get_Count"})
    if type(count) ~= "number" then return end
    for index = 0, math.min(count, 16) - 1 do
        local pawn = first_method(pawns, {"get_Item(System.Int32)", "get_Item"}, index)
        if pawn and pawn ~= player then restore(pawn, true, dt, in_battle) end
    end
end

-- Rate limiting: limit calls and suppress enormous recovery on loading/unpausing.
local UPDATE_INTERVAL = 0.10
local previous_clock = os.clock()
local accumulated = 0
local last_late_update = nil
local function update()
    local now = os.clock()
    local elapsed = now - previous_clock
    previous_clock = now
    if elapsed <= 0 or elapsed > 2 then accumulated = 0; return end
    accumulated = math.min(accumulated + elapsed, 0.5)
    if accumulated < UPDATE_INTERVAL then return end
    local dt = math.min(accumulated, 0.35)
    accumulated = 0
    restore_party(dt)
end

-- Current working reference uses LateUpdateBehavior; on_frame remains a fallback.
if type(re.on_application_entry) == "function" then
    re.on_application_entry("LateUpdateBehavior", function()
        last_late_update = os.clock()
        update()
    end)
end
re.on_frame(function()
    if last_late_update == nil or os.clock() - last_late_update > 2 then update() end
end)

local function checkbox(label, key)
    local changed, value = imgui.checkbox(label, config[key])
    if changed then config[key] = value; return true end
    return false
end
local function float_option(label, key, speed, low, high)
    local changed, value = imgui.drag_float(label, config[key], speed, low, high)
    if changed then config[key] = math.max(low, math.min(high, value)); return true end
    return false
end

re.on_draw_ui(function()
    if not imgui.tree_node("Complete Health Restoration v2.0") then return end
    local dirty = false
    imgui.text("Standalone HP + Loss Gauge regeneration")
    dirty = checkbox("Loss Gauge restoration enabled", "GaugeHealEnabled") or dirty
    dirty = checkbox("HP healing enabled", "AutoHealEnable") or dirty
    imgui.spacing()
    if imgui.tree_node("Loss Gauge Settings") then
        dirty = checkbox("Loss Gauge: Arisen", "GaugeHealArisen") or dirty
        dirty = checkbox("Loss Gauge: Pawns", "GaugeHealPawn") or dirty
        dirty = checkbox("Loss Gauge: During battle", "GaugeHealInBattle") or dirty
        imgui.text("Loss gauge restored per second (% original maximum HP)")
        dirty = float_option("Gauge rate (%)", "GaugeHealPerc", 0.05, 0, 100) or dirty
        imgui.tree_pop()
    end
    if imgui.tree_node("HP Healing Settings") then
        dirty = checkbox("HP healing: Arisen", "AutoHealArisen") or dirty
        dirty = checkbox("HP healing: Pawns", "AutoHealPawn") or dirty
        dirty = checkbox("Use original maximum HP for heal target", "AutoHealToMaxHP") or dirty
        imgui.text("Game may still clamp HP to the active loss gauge")
        dirty = float_option("Battle heal multiplier", "AutoHealBattleRatio", 0.01, 0, 1) or dirty
        dirty = float_option("HP regeneration per second (%)", "AutoHealPerc", 0.1, 0, 100) or dirty
        dirty = float_option("Stop healing at (%)", "AutoHealTargetHP", 1, 1, 100) or dirty
        imgui.tree_pop()
    end
    if dirty then save_config() end
    imgui.spacing()
    imgui.text("Config: " .. save_status)
    imgui.text("Loaded from: " .. config_source)
    if imgui.button("Save settings now") then save_config() end
    if imgui.tree_node("Diagnostics (read-only)") then
        local function num(n) return n and string.format("%.2f", n) or "not available" end
        imgui.text("Arisen HP: " .. num(diagnostics.lastPlayerHp))
        imgui.text("Arisen max gauge: " .. num(diagnostics.lastPlayerGauge) .. " / " .. num(diagnostics.lastPlayerOriginal))
        imgui.text("Loss-gauge writes: " .. diagnostics.gaugeWrites)
        imgui.text("Loss-gauge setter failures: " .. diagnostics.gaugeWriteErrors)
        imgui.text("HP writes: " .. diagnostics.hpWrites)
        imgui.text(diagnostics.lastGaugeStatus)
        imgui.text("Setter calls alone do not prove gauge persistence; verify in-game.")
        imgui.tree_pop()
    end
    imgui.tree_pop()
end)
