-- Health API Probe v1.0 — DD2 / REFramework (2026-10-11)
-- Safe by construction: inspection + getter calls only; no setter invocation,
-- sdk.hook, save edits, or gameplay callbacks. Manual capture from REFramework UI.
-- Output: reframework/data/Health_API_Probe_YYYYMMDD_HHMMSS.json

local VERSION = "1.0"
local status = "No capture yet"
local TARGETS = {
    ["app.CharacterManager"] = { methods = {"get_ManualPlayer"}, fields = {"<ManualPlayer>k__BackingField"} },
    ["app.Character"] = {methods = {"get_Valid", "get_Hp", "get_ReducedMaxHp", "get_OriginalMaxHp", "get_Hit", "get_Human"}, fields = {"<Hit>k__BackingField"}},
    ["app.PawnManager"] = {methods = {"get_PawnCharacterList"}},
    ["app.GuiManager"] = {methods = {"isPausedGUI"}},
    ["app.BattleManager"] = {methods = {"get_BattleMode", "get_IsBattleMode"}},
}
local HIT_METHODS = {"get_Hp", "get_ReducedMaxHp", "get_OriginalMaxHp", "set_ReducedMaxHp", "setHpValue"}
local HUMAN_METHODS = {"get_Hit"}
local LIST_METHODS = {"get_Count", "get_Item"}

local function attempt(fn)
    local ok, result = pcall(fn)
    if ok then return result, nil end
    return nil, tostring(result)
end
local function get(fn)
    local result = attempt(fn)
    return result
end
local function typeName(def)
    if type(def) == "string" and def ~= "" then return def end
    if def == nil then return nil end
    local name = get(function() return def:get_full_name() end)
    if type(name) == "string" and name ~= "" then return name end
    return nil
end
local function readSequence(seq, expected)
    if seq == nil then return nil, "nil-sequence" end
    local result = {}
    local ok = pcall(function()
        for _, value in ipairs(seq) do result[#result+1] = value end
    end)
    if ok and (expected == nil or #result == expected) then return result, "ipairs" end
    if type(expected) == "number" and expected >= 0 and expected <= 64 then
        for _, base in ipairs({1,0}) do
            local tmp, complete = {}, true
            for idx = base, base + expected - 1 do
                local value, err = attempt(function() return seq[idx] end)
                if err or value == nil then complete = false; break end
                tmp[#tmp+1] = value
            end
            if complete then return tmp, "index-" .. tostring(base) end
        end
    end
    return nil, "parameter-sequence-unresolved"
end
local function methodRecord(m, name, origin)
    local out = {name=name, resolvedBy=origin}
    local n = get(function() return m:get_num_params() end)
    if type(n) == "number" and n >= 0 and n <= 64 and n % 1 == 0 then out.parameterCount = n end
    out.declaringType = typeName(get(function() return m:get_declaring_type() end))
    out.returnType = typeName(get(function() return m:get_return_type() end))
    out.isStatic = get(function() return m:is_static() end)
    local raw, err = attempt(function() return m:get_param_types() end)
    local params, mode = readSequence(raw, out.parameterCount)
    out.parameterReadMethod = mode
    if err then out.parameterReadError = err end
    local names = {}
    if params then
        for _, item in ipairs(params) do names[#names+1] = typeName(item) or "<type-unresolved>" end
    end
    if out.parameterCount and #names == out.parameterCount then
        local valid = true
        for _, item in ipairs(names) do if item == "<type-unresolved>" then valid = false end end
        if valid then
            out.signatureStatus = "resolved"
            out.signature = name .. "(" .. table.concat(names, ", ") .. ")"
        end
    end
    out.signatureStatus = out.signatureStatus or "unresolved"
    out.signature = out.signature or (name .. "(<parameters-unresolved>)")
    out.parameterTypes = names
    return out
end
local function inspectType(td, wantedMethods, wantedFields)
    local info = {
        exists = td ~= nil, enumerationStatus = "not-attempted",
        methods = {}, fields = {}, missing = {}, unresolved = {}, errors = {},
        overloadsByName = {}, methodNamesFoundCount = 0, methodsFoundCount = 0,
        resolvedSignatureCount = 0, unresolvedSignatureCount = 0
    }
    if not td then return info end
    local wantedSet, found = {}, {}
    for _, name in ipairs(wantedMethods or {}) do wantedSet[name] = true end
    local function addMethod(m, name, from)
        if not m then return end
        local actualName = get(function() return m:get_name() end) or name
        if not wantedSet[actualName] then return end
        found[actualName] = true
        info.methods[#info.methods+1] = methodRecord(m, actualName, from)
        info.overloadsByName[actualName] = (info.overloadsByName[actualName] or 0) + 1
    end
    local all, err = attempt(function() return td:get_methods() end)
    if all == nil then
        info.enumerationStatus = err and "error" or "nil-result"
        if err then info.errors[#info.errors+1] = "get_methods: " .. err end
    else
        local count = 0
        local ok, iterationError = pcall(function()
            for _, m in ipairs(all) do
                count = count + 1
                addMethod(m, nil, "enumeration")
            end
        end)
        info.enumeratedMethodCount = count
        info.enumerationStatus = ok and "ok" or "iteration-error"
        if not ok then info.errors[#info.errors+1] = "iterate get_methods: " .. tostring(iterationError) end
    end
    for _, name in ipairs(wantedMethods or {}) do
        if not found[name] then
            local m, lookupError = attempt(function() return td:get_method(name) end)
            if m then
                addMethod(m, name, "direct-lookup")
            elseif info.enumerationStatus == "ok" and not lookupError then
                info.missing[#info.missing+1] = name
            else
                info.unresolved[#info.unresolved+1] = name
                if lookupError then info.errors[#info.errors+1] = "get_method " .. name .. ": " .. lookupError end
            end
        end
    end
    for _, name in ipairs(wantedFields or {}) do
        local f, fieldErr = attempt(function() return td:get_field(name) end)
        local record = {exists = f ~= nil}
        if f then
            record.type = typeName(get(function() return f:get_type() end))
            record.declaringType = typeName(get(function() return f:get_declaring_type() end))
            record.isStatic = get(function() return f:is_static() end)
        elseif fieldErr then
            record.status = "lookup-error"
            info.errors[#info.errors+1] = "get_field " .. name .. ": " .. fieldErr
        else
            record.status = "not-found"
        end
        info.fields[name] = record
    end
    for _ in pairs(found) do info.methodNamesFoundCount = info.methodNamesFoundCount + 1 end
    info.methodsFoundCount = #info.methods
    for _, m in ipairs(info.methods) do
        if m.signatureStatus == "resolved" then
            info.resolvedSignatureCount = info.resolvedSignatureCount + 1
        else
            info.unresolvedSignatureCount = info.unresolvedSignatureCount + 1
        end
    end
    table.sort(info.methods, function(a,b)
        if a.name ~= b.name then return a.name < b.name end
        return a.signature < b.signature
    end)
    table.sort(info.missing)
    table.sort(info.unresolved)
    return info
end
local function resolveType(name, defs)
    if not name or type(name) ~= "string" then return nil end
    if defs and defs[name] then return defs[name] end
    return get(function() return sdk.find_type_definition(name) end)
end
local function objectTypeName(obj)
    if not obj then return nil end
    return typeName(get(function() return obj:get_type_definition() end))
end
local function readField(obj, name)
    if not obj then return nil end
    local value = get(function() return obj:get_field(name) end)
    if value ~= nil then return value end
    return get(function() return obj[name] end)
end
local function readMethod(obj, names, ...)
    if not obj then return nil end
    local args = {...}
    for _, name in ipairs(names) do
        local value = get(function() return obj:call(name, table.unpack(args)) end)
        if value ~= nil then return value, name end
    end
    return nil
end
local function finiteNumber(n)
    if type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge then return n end
    return nil
end
local function sampleCharacter(character)
    if not character then return {available=false} end
    local result = {available=true, class=objectTypeName(character)}
    local valid, validPath = readMethod(character, {"get_Valid()", "get_Valid"})
    if type(valid) == "boolean" then result.valid = valid; result.validRead = validPath end
    for _, spec in ipairs({{"hp", "get_Hp"},{"reducedMaxHp", "get_ReducedMaxHp"},{"originalMaxHp", "get_OriginalMaxHp"}}) do
        local value, path = readMethod(character, {spec[2] .. "()", spec[2]})
        result[spec[1]] = finiteNumber(value)
        if path then result[spec[1] .. "Read"] = "character:" .. path end
    end
    local hit = readField(character, "<Hit>k__BackingField")
    result.hitBackingFieldAccessible = hit ~= nil
    if hit then result.hitAccessPath = "character.<Hit>k__BackingField" end
    if not hit then
        hit = readMethod(character, {"get_Hit()", "get_Hit"})
        if hit then result.hitAccessPath = "character.get_Hit" end
    end
    if not hit then
        local human = readMethod(character, {"get_Human()", "get_Human"})
        hit = readField(human, "Hit")
        if hit then result.hitAccessPath = "character.get_Human().Hit" end
    end
    result.hitAvailable = hit ~= nil
    result.hitRuntimeType = objectTypeName(hit)
    if hit then
        for _, spec in ipairs({{"hp", "get_Hp"},{"reducedMaxHp", "get_ReducedMaxHp"},{"originalMaxHp", "get_OriginalMaxHp"}}) do
            if result[spec[1]] == nil then
                local v, path = readMethod(hit, {spec[2] .. "()", spec[2]})
                result[spec[1]] = finiteNumber(v)
                if path then result[spec[1] .. "Read"] = "hit:" .. path end
            end
        end
    end
    if result.reducedMaxHp ~= nil and result.originalMaxHp ~= nil then
        result.lossGaugeDeficit = finiteNumber(math.max(0, result.originalMaxHp - result.reducedMaxHp))
        result.lossGaugeRatio = (result.originalMaxHp > 0) and finiteNumber(result.reducedMaxHp / result.originalMaxHp) or nil
    end
    return result, hit
end
local function getSingleton(name)
    return get(function() return sdk.get_managed_singleton(name) end)
end
local function snapshot()
    local captured = {
        probeVersion = VERSION,
        scope = "HP / Loss Gauge runtime + method/field reflection",
        source = "Read-only REFramework runtime inspection; no setters invoked",
        capturedLocalTime = get(function() return os.date("%Y-%m-%d %H:%M:%S %z") end) or "unknown",
        gameBuild = "UNVERIFIED: capture Steam build ID or executable hash separately",
        tdbVersion = tostring(get(function() return sdk.get_tdb_version() end) or "unavailable"),
        reframeworkInfo = {
            gameName = get(function() return reframework:get_game_name() end),
            commitHash = get(function() return reframework:get_commit_hash() end),
            buildDate = get(function() return reframework:get_build_date() end),
            buildTime = get(function() return reframework:get_build_time() end)
        },
        engine = {
            sdk = {find_type_definition = type(sdk.find_type_definition)=="function", get_managed_singleton=type(sdk.get_managed_singleton)=="function"},
            re = {on_frame=type(re.on_frame)=="function", on_application_entry=type(re.on_application_entry)=="function", on_draw_ui=type(re.on_draw_ui)=="function"},
            json = {dump_file=type(json.dump_file)=="function"}
        },
        types = {}, runtime = {},
        warnings = {
            "Method signature availability does not prove behavior or hook execution.",
            "Character HP values depend on damage, equipment and scene; compare availability/path, not numeric equality.",
            "Inspecting a setter's signature DOES NOT invoke the setter.",
            "An unchanged API does not guarantee that loss-gauge writes will work after a game update.",
            "The live probe samples current HP and loss gauge; no character identities are collected."
        }
    }
    local resolved = {}
    local names = {}
    for name in pairs(TARGETS) do names[#names+1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local def = resolveType(name, resolved)
        if def then resolved[name] = def end
        captured.types[name] = inspectType(def, TARGETS[name].methods, TARGETS[name].fields)
    end
    local cm = getSingleton("app.CharacterManager")
    local gui = getSingleton("app.GuiManager")
    local battle = getSingleton("app.BattleManager")
    local pm = getSingleton("app.PawnManager")
    captured.runtime.managers = {character=cm~=nil,gui=gui~=nil,battle=battle~=nil,pawn=pm~=nil}
    local paused, pausedPath = readMethod(gui, {"isPausedGUI()", "isPausedGUI"})
    if type(paused) == "boolean" then captured.runtime.paused = paused; captured.runtime.pausedReadPath = pausedPath end
    local battleMode, battlePath = readMethod(battle, {"get_BattleMode()", "get_BattleMode"})
    if type(battleMode)=="number" or type(battleMode)=="boolean" then
        captured.runtime.battleMode = battleMode
        captured.runtime.battleModeReadPath = battlePath
    else
        local legacy, legacyPath = readMethod(battle, {"get_IsBattleMode()", "get_IsBattleMode"})
        if type(legacy)=="boolean" then captured.runtime.battleMode=legacy; captured.runtime.battleModeReadPath=legacyPath end
    end
    local player, playerPath = readMethod(cm, {"get_ManualPlayer()", "get_ManualPlayer"})
    if not player then
        player = readField(cm, "<ManualPlayer>k__BackingField")
        if player then playerPath = "<ManualPlayer>k__BackingField" end
    end
    captured.runtime.playerReadPath = playerPath
    local playerRecord, playerHit = sampleCharacter(player)
    captured.runtime.player = playerRecord
    local hitTypeName = playerRecord.hitRuntimeType
    if not hitTypeName then
        local chardef = resolveType("app.Character", resolved)
        local fieldDef = chardef and get(function() return chardef:get_field("<Hit>k__BackingField") end)
        hitTypeName = typeName(fieldDef and get(function() return fieldDef:get_type() end))
    end
    captured.runtime.hitControllerTypeResolved = hitTypeName
    if hitTypeName then
        local td = get(function() return playerHit:get_type_definition() end)
        if not td then td = resolveType(hitTypeName, resolved) end
        captured.types[hitTypeName] = inspectType(td, HIT_METHODS, {})
        captured.types[hitTypeName].discovery = "character.<Hit>k__BackingField runtime type / field metadata"
    else
        captured.runtime.hitControllerNote = "Hit controller class not resolvable in this scene; inspect player after loading gameplay"
    end
    local pawns, pawnPath = readMethod(pm, {"get_PawnCharacterList()", "get_PawnCharacterList"})
    captured.runtime.pawnListAvailable = pawns ~= nil
    captured.runtime.pawnListReadPath = pawnPath
    local count, countPath = readMethod(pawns, {"get_Count()", "get_Count"})
    captured.runtime.pawnListCount = finiteNumber(count)
    captured.runtime.pawnListCountReadPath = countPath
    captured.runtime.pawnSamples = {}
    if pawns and type(count)=="number" and count>=0 then
        for i = 0, math.min(count, 3) - 1 do
            local pawn = readMethod(pawns, {"get_Item(System.Int32)", "get_Item"}, i)
            captured.runtime.pawnSamples[#captured.runtime.pawnSamples+1] = sampleCharacter(pawn)
        end
    end
    -- List type can be constructed generically. Reflect actual runtime type, not guess names.
    local listType = objectTypeName(pawns)
    captured.runtime.pawnListType = listType
    if listType then
        local td = get(function() return pawns:get_type_definition() end)
        if td and not captured.types[listType] then
            captured.types[listType] = inspectType(td, LIST_METHODS, {})
            captured.types[listType].discovery = "app.PawnManager.get_PawnCharacterList runtime type"
        end
    end
    -- Only inspect the legacy Human class when the live Character getter identifies it.
    local human = player and readMethod(player, {"get_Human()", "get_Human"})
    local humanName = objectTypeName(human)
    if humanName and not captured.types[humanName] then
        captured.types[humanName] = inspectType(get(function() return human:get_type_definition() end), HUMAN_METHODS, {"Hit"})
        captured.types[humanName].discovery = "app.Character.get_Human legacy path"
    end
    return captured
end

re.on_draw_ui(function()
    if not imgui.tree_node("Health API Probe (read-only) v1.0") then return end
    imgui.text("Reflect HP/Loss Gauge classes, Hit setter signatures, and party state.")
    imgui.text("Only getters and reflection are called. No HP changes or hooks.")
    imgui.text("Load into gameplay before capture (preferably with injured HP gauge).")
    if imgui.button("Capture Health API Snapshot") then
        local result, err = attempt(snapshot)
        if err then
            status = "CAPTURE ERROR: " .. err
        else
            local stamp = get(function() return os.date("%Y%m%d_%H%M%S") end) or "unknown"
            local file = "Health_API_Probe_" .. stamp .. ".json"
            local wrote, saveErr = attempt(function() return json.dump_file(file, result, 4) end)
            if wrote == true then
                status = "Saved: reframework/data/" .. file
            else
                status = "SAVE FAILED: " .. tostring(saveErr or "json.dump_file returned false/nil")
            end
        end
    end
    imgui.text(status)
    imgui.tree_pop()
end)
