-- Beloved API Probe v1.2 — October 2026
-- Read-only DD2/REFramework introspection for Choose Your Beloved.
-- Deliberately: no sdk.hook, no affinity writes, no save-game mutations.
-- Install: <game>/reframework/autorun/Beloved_API_Probe.lua
-- UI: REFramework > Script Generated UI > Beloved API Probe (read-only)
-- Output: <game>/reframework/data/Beloved_API_Probe_YYYYMMDD_HHMMSS.json

local VERSION = "1.2"
local status = "Not captured"
local targets = {
    ["app.CharacterManager"] = { "get_ManualPlayer" },
    ["app.NPCManager"] = { "getNPCHolder", "onUpdate" },
    ["app.NPCHolder"] = {
        "getSentimentInfo", "get_Position", "get_CachedCharacter",
        "onUpdate_Sentiment", "addSentimentValue", "setSentimentValue"
    },
    ["app.GUIBase"] = { "getName" },
    ["app.Character"] = { "get_CharaID", "get_GameObject" },
    ["via.GameObject"] = { "get_Transform" },
    ["via.Transform"] = { "get_Position", "getJointByName" }
}

local function invoke(fn)
    local ok, result = pcall(fn)
    if ok then return result, nil end
    return nil, tostring(result)
end

local function read(fn, fallback)
    local value, err = invoke(fn)
    if err ~= nil or value == nil then return fallback end
    return value
end

local function stableTypeName(typeDef)
    if type(typeDef) == "string" and typeDef ~= "" then return typeDef end
    if typeDef == nil then return nil end
    local name = read(function() return typeDef:get_full_name() end)
    if type(name) == "string" and name ~= "" then return name end
    -- Do not serialize tostring(userdata): those addresses vary between launches.
    return nil
end

-- REFramework may return a Lua table OR a native sequence proxy (userdata).
-- v1.1 incorrectly required type(get_param_types()) == "table" and discarded
-- every sequence proxy, leading to '<parameters-unresolved>' on every method.
local function readSequence(sequence, expectedCount)
    if sequence == nil then return nil, "nil-sequence" end
    local values = {}
    local ok, err = pcall(function()
        for _, value in ipairs(sequence) do
            values[#values + 1] = value
        end
    end)
    if ok and (expectedCount == nil or #values == expectedCount) then
        return values, "ipairs"
    end
    -- Some bound arrays are zero-indexed, or do not implement ipairs.
    if expectedCount ~= nil and expectedCount >= 0 and expectedCount <= 128 then
        for _, startIndex in ipairs({1, 0}) do
            local candidate = {}
            local success = true
            for i = startIndex, startIndex + expectedCount - 1 do
                local item, itemErr = invoke(function() return sequence[i] end)
                if itemErr or item == nil then success = false; break end
                candidate[#candidate + 1] = item
            end
            if success then return candidate, startIndex == 1 and "index-1" or "index-0" end
        end
    end
    if ok then
        return values, "ipairs-incomplete"
    end
    return nil, "unreadable-sequence: " .. tostring(err)
end

local function methodMetadata(method, name, source, ordinal)
    local out = { name = name, resolvedBy = source, overloadOrdinal = ordinal }
    local n = read(function() return method:get_num_params() end)
    if type(n) == "number" and n >= 0 and n <= 128 and n % 1 == 0 then
        out.parameterCount = n
    end
    out.isStatic = read(function() return method:is_static() end)
    out.returnType = stableTypeName(read(function() return method:get_return_type() end))
    out.declaringType = stableTypeName(read(function() return method:get_declaring_type() end))

    local rawParams, paramError = invoke(function() return method:get_param_types() end)
    local params, iteration = readSequence(rawParams, out.parameterCount)
    out.parameterReadMethod = iteration
    if paramError then out.parameterReadError = paramError end
    local formatted = {}
    if params then
        for _, def in ipairs(params) do
            formatted[#formatted + 1] = stableTypeName(def) or "<type-unresolved>"
        end
    end
    out.parameterTypes = formatted

    local count = out.parameterCount
    -- Never claim that an empty sequence means zero parameters without
    -- independent get_num_params() confirmation.
    if count ~= nil and count == #formatted then
        local complete = true
        for _, value in ipairs(formatted) do
            if value == "<type-unresolved>" then complete = false end
        end
        if complete then
            out.signatureStatus = "resolved"
            out.signature = name .. "(" .. table.concat(formatted, ", ") .. ")"
        end
    end
    if not out.signature then
        out.signatureStatus = "unresolved"
        out.signature = name .. "(<parameters-unresolved>)"
    end

    -- Parameter *names* are useful context but are not required for signatures.
    local rawNames = read(function() return method:get_param_names() end)
    local paramNames = readSequence(rawNames, count)
    if paramNames and count ~= nil and #paramNames == count then
        local clean = {}
        local valid = true
        for _, item in ipairs(paramNames) do
            if type(item) ~= "string" then valid = false; break end
            clean[#clean + 1] = item
        end
        if valid then out.parameterNames = clean end
    end
    return out
end

local function inspectType(name, wanted)
    local info = {
        exists = false, enumerationStatus = "not-attempted", methods = {},
        missing = {}, unresolved = {}, errors = {}, fields = {},
        methodNamesFoundCount = 0, methodsFoundCount = 0,
        resolvedSignatureCount = 0, unresolvedSignatureCount = 0,
        overloadsByName = {}
    }
    local td, err = invoke(function() return sdk.find_type_definition(name) end)
    if err then info.errors[#info.errors + 1] = "find_type_definition: " .. err end
    if not td then return info end
    info.exists = true
    local wantedSet = {}
    for _, item in ipairs(wanted) do wantedSet[item] = true end
    local found = {}
    local function add(method, fallback, source)
        local methodName = read(function() return method:get_name() end, fallback)
        if type(methodName) ~= "string" or not wantedSet[methodName] then return end
        found[methodName] = true
        local ordinal = (info.overloadsByName[methodName] or 0) + 1
        info.overloadsByName[methodName] = ordinal
        info.methods[#info.methods + 1] = methodMetadata(method, methodName, source, ordinal)
    end

    local methods, enumErr = invoke(function() return td:get_methods() end)
    if enumErr then
        info.enumerationStatus = "error"
        info.errors[#info.errors + 1] = "get_methods: " .. enumErr
    elseif methods == nil then
        info.enumerationStatus = "nil-result"
    else
        local count = 0
        local ok, itErr = pcall(function()
            for _, m in ipairs(methods) do
                count = count + 1
                add(m, nil, "enumeration")
            end
        end)
        info.enumeratedMethodCount = count
        if ok then
            info.enumerationStatus = count > 0 and "ok" or "empty"
        else
            info.enumerationStatus = "iteration-error"
            info.errors[#info.errors + 1] = "iterate get_methods: " .. tostring(itErr)
        end
    end

    -- Direct lookups only for names NOT found in enumeration. Inherited
    -- methods may resolve this way; keep those separate from overload counts.
    for _, methodName in ipairs(wanted) do
        if not found[methodName] then
            local method, lookupErr = invoke(function() return td:get_method(methodName) end)
            if method then
                add(method, methodName, "direct-lookup")
            elseif lookupErr then
                info.unresolved[#info.unresolved + 1] = methodName
                info.errors[#info.errors + 1] = "get_method(" .. methodName .. "): " .. lookupErr
            elseif info.enumerationStatus == "ok" then
                info.missing[#info.missing + 1] = methodName
            else
                info.unresolved[#info.unresolved + 1] = methodName
            end
        end
    end
    for _ in pairs(found) do info.methodNamesFoundCount = info.methodNamesFoundCount + 1 end
    info.methodsFoundCount = #info.methods
    for _, method in ipairs(info.methods) do
        if method.signatureStatus == "resolved" then
            info.resolvedSignatureCount = info.resolvedSignatureCount + 1
        else
            info.unresolvedSignatureCount = info.unresolvedSignatureCount + 1
        end
    end
    table.sort(info.methods, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        if a.signature ~= b.signature then return a.signature < b.signature end
        return a.overloadOrdinal < b.overloadOrdinal
    end)
    table.sort(info.missing)
    table.sort(info.unresolved)
    if name == "app.NPCManager" then
        local field, fieldError = invoke(function() return td:get_field("NPCHolderDic") end)
        info.fields.NPCHolderDic = field ~= nil
        if fieldError then info.errors[#info.errors + 1] = "get_field: " .. fieldError end
    end
    return info
end

local function existsFunction(root, name)
    return type(read(function() return root[name] end)) == "function"
end

local function snapshot()
    local s = {
        probeVersion = VERSION,
        capturedLocalTime = read(function() return os.date("%Y-%m-%d %H:%M:%S %z") end, "unknown"),
        source = "REFramework runtime reflection (read-only)",
        gameBuild = "UNVERIFIED: capture Steam build/executable separately",
        tdbVersion = tostring(read(function() return sdk.get_tdb_version() end, "unavailable")),
        reframeworkInfo = {
            gameName = read(function() return reframework:get_game_name() end, "unavailable"),
            commitHash = read(function() return reframework:get_commit_hash() end, "unavailable"),
            buildDate = read(function() return reframework:get_build_date() end, "unavailable"),
            buildTime = read(function() return reframework:get_build_time() end, "unavailable")
        },
        engine = {}, types = {}, runtime = {},
        warnings = {
            "Reflection confirms exposed methods, not successful execution or affinity write persistence.",
            "Do not compare unresolved overload signatures as though they were complete.",
            "Same-session save reload and final beloved selection are not tested.",
            "Installed game build ID/executable hash still needs separate verification."
        }
    }
    s.engine.sdk = {
        find_type_definition = existsFunction(sdk, "find_type_definition"),
        get_managed_singleton = existsFunction(sdk, "get_managed_singleton"),
        get_tdb_version = existsFunction(sdk, "get_tdb_version"),
        hook = existsFunction(sdk, "hook")
    }
    s.engine.re = {
        on_frame = existsFunction(re, "on_frame"),
        on_draw_ui = existsFunction(re, "on_draw_ui"),
        on_script_reset = existsFunction(re, "on_script_reset")
    }
    s.engine.draw = {
        world_to_screen = existsFunction(draw, "world_to_screen"),
        filled_rect = existsFunction(draw, "filled_rect"),
        filled_quad = existsFunction(draw, "filled_quad"),
        text = existsFunction(draw, "text")
    }
    s.engine.imgui = { get_display_size = existsFunction(imgui, "get_display_size") }
    s.engine.json = { dump_file = existsFunction(json, "dump_file"), load_file = existsFunction(json, "load_file") }
    s.engine.reframework = { get_delta_time = existsFunction(reframework, "get_delta_time") }

    local names = {}
    for name in pairs(targets) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do s.types[name] = inspectType(name, targets[name]) end

    -- Only get/read operations: do not store identifiable NPC IDs or affinity values.
    local cm = read(function() return sdk.get_managed_singleton("app.CharacterManager") end)
    local nm = read(function() return sdk.get_managed_singleton("app.NPCManager") end)
    local player = cm and read(function() return cm:get_ManualPlayer() end)
    s.runtime.characterManagerAvailable = cm ~= nil
    s.runtime.npcManagerAvailable = nm ~= nil
    s.runtime.playerAvailable = player ~= nil
    local playerID = player and read(function() return player:get_CharaID() end)
    s.runtime.playerCharacterIDReadable = playerID ~= nil
    local holders = nm and read(function() return nm.NPCHolderDic end)
    s.runtime.npcHolderDictionaryReadable = holders ~= nil
    local count = holders and read(function() return holders:get_Length() end)
    s.runtime.npcHolderCountReadable = type(count) == "number"
    s.runtime.sampleSentimentInfoAvailable = false
    s.runtime.sampleSentimentValueReadable = false
    if playerID and type(count) == "number" then
        for i = 0, math.min(count, 1000) - 1 do
            local holder = read(function() return holders[i] end)
            local info = holder and read(function() return holder:getSentimentInfo(playerID, false) end)
            if info then
                s.runtime.sampleSentimentInfoAvailable = true
                s.runtime.sampleSentimentValueReadable = read(function() return tonumber(info.Value) end) ~= nil
                break
            end
        end
    end
    return s
end

re.on_draw_ui(function()
    if not imgui.tree_node("Beloved API Probe (read-only) v1.2") then return end
    imgui.text("Capture method overloads, parameter types, return types, and REFramework state.")
    imgui.text("READ ONLY: does not hook methods or change NPC affinity.")
    imgui.text("Capture during gameplay, not the title screen.")
    if imgui.button("Capture API Snapshot") then
        local ok, result = pcall(snapshot)
        if not ok then
            status = "Capture failed: " .. tostring(result)
        else
            local stamp = read(function() return os.date("%Y%m%d_%H%M%S") end, "unknown")
            local filename = "Beloved_API_Probe_" .. stamp .. ".json"
            local wrote, writeError = invoke(function() return json.dump_file(filename, result, 4) end)
            if writeError or not wrote then
                status = "JSON save failed: " .. tostring(writeError or "unknown error")
            else
                status = "Saved: reframework/data/" .. filename
            end
        end
    end
    imgui.text(status)
    imgui.tree_pop()
end)
