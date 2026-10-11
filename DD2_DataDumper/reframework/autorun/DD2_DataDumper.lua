-- DD2 Data Dumper v5.2 Experimental
-- Read-only, on-demand, throttled REFramework inspector.
-- Output: REFramework/reframework/data/DD2Dumper_*.json (flat paths; no subdirs required).
-- No sdk.hook, set_field, set_*, create_userdata, or arbitrary method fuzzing.

local VERSION = "5.2-experimental"
local PREFIX = "DD2Dumper_"
local ITEM_BATCH_SIZE = 1500
local ITEM_PROGRESS_FILE = "DD2Dumper_item_progress.json"
local ITEMS_PER_FRAME = 40
local log_entries, last_report = {}, "Ready (no work on load)"
local current = nil
local sequence = 0

local function attempt(fn)
    local ok, value = pcall(fn)
    if ok then return value, nil end
    return nil, tostring(value)
end
local function note(msg)
    msg = tostring(msg)
    log_entries[#log_entries + 1] = os.date("%H:%M:%S") .. " | " .. msg
    if #log_entries > 80 then table.remove(log_entries, 1) end
    print("[DD2Dumper] " .. msg)
end
local function name_of(td)
    if not td then return nil end
    return attempt(function() return td:get_full_name() end)
end
local function primitive(value)
    local kind = type(value)
    if kind == "number" or kind == "boolean" or kind == "string" then return value end
    if value == nil then return nil end
    local n = attempt(function() return value:get_field("value__") end)
    if type(n) == "number" then return n end
    return nil
end
local function get_field(obj, field)
    if not obj then return nil end
    local v = attempt(function() return obj:get_field(field) end)
    if v ~= nil then return v end
    return attempt(function() return obj[field] end)
end
local function invoke(obj, method, ...)
    if not obj then return nil end
    local args = {...}
    return attempt(function() return obj:call(method, table.unpack(args)) end)
end
local function type_of(obj)
    if not obj then return nil end
    return name_of(attempt(function() return obj:get_type_definition() end))
end
local function save(suffix, data)
    local filename = PREFIX .. suffix .. ".json"
    local result, err = attempt(function() return json.dump_file(filename, data, 2) end)
    if result ~= true then
        note("SAVE FAILED: " .. filename .. " (" .. tostring(err or result) .. ")")
        return false, filename
    end
    note("Saved " .. filename)
    return true, filename
end
local function stamp()
    sequence = sequence + 1
    return os.date("%Y%m%d_%H%M%S") .. "_" .. string.format("%03d", sequence)
end
local function environment()
    local data = {
        probeVersion = VERSION,
        capturedLocalTime = os.date("%Y-%m-%d %H:%M:%S %z"),
        gameBuild = "UNVERIFIED: capture Steam build ID separately",
        tdbVersion = attempt(function() return sdk.get_tdb_version() end),
        reframework = {},
    }
    if reframework then
        for key, method in pairs({
            gameName = "get_game_name", commitHash = "get_commit_hash",
            buildDate = "get_build_date", buildTime = "get_build_time",
        }) do
            data.reframework[key] = attempt(function() return reframework[method](reframework) end)
        end
    end
    return data
end

-- Preserves type signatures and overloads. Values from unknown native objects are never serialized.
local function inspect_type(type_name, include_enum_values)
    local td, find_err = attempt(function() return sdk.find_type_definition(type_name) end)
    local result = { name = type_name, exists = td ~= nil }
    if not td then
        result.reason = find_err or "type not exposed by this TDB"
        return result
    end
    result.name = name_of(td) or type_name
    local parent = attempt(function() return td:get_parent_type() end)
    result.parent = name_of(parent)
    result.methods, result.fields = {}, {}
    local methods, m_err = attempt(function() return td:get_methods() end)
    if not methods then result.methodError = m_err or "get_methods unavailable" end
    if methods then
        local iter_ok, iter_err = pcall(function()
            for _, m in ipairs(methods) do
                local method = {
                    name = attempt(function() return m:get_name() end),
                    returnType = name_of(attempt(function() return m:get_return_type() end)),
                    declaringType = name_of(attempt(function() return m:get_declaring_type() end)),
                    isStatic = attempt(function() return m:is_static() end),
                    parameterTypes = {},
                }
                local p, p_err = attempt(function() return m:get_param_types() end)
                if p then
                    local ok, list_err = pcall(function()
                        for _, arg in ipairs(p) do
                            method.parameterTypes[#method.parameterTypes + 1] = name_of(arg) or "<unresolved>"
                        end
                    end)
                    if not ok then method.paramError = tostring(list_err) end
                else
                    method.paramError = p_err or "param type access failed"
                end
                local count = attempt(function() return m:get_num_params() end)
                method.parameterCount = count
                if count ~= nil and #method.parameterTypes ~= count then
                    method.paramError = method.paramError or "parameter count mismatch"
                end
                method.signature = tostring(method.name) .. "(" .. table.concat(method.parameterTypes, ", ") .. ")"
                result.methods[#result.methods + 1] = method
            end
        end)
        if not iter_ok then result.methodError = tostring(iter_err) end
    end
    local fields, f_err = attempt(function() return td:get_fields() end)
    if not fields then result.fieldError = f_err or "get_fields unavailable" end
    if fields then
        local ok, iter_err = pcall(function()
            for _, f in ipairs(fields) do
                local frow = {
                    name = attempt(function() return f:get_name() end),
                    type = name_of(attempt(function() return f:get_type() end)),
                    isStatic = attempt(function() return f:is_static() end),
                }
                if include_enum_values and frow.isStatic then
                    local v = attempt(function() return f:get_data(nil) end)
                    frow.value = primitive(v)
                end
                result.fields[#result.fields + 1] = frow
            end
        end)
        if not ok then result.fieldError = tostring(iter_err) end
    end
    table.sort(result.methods, function(a,b)
        local sa = tostring(a.signature) .. tostring(a.returnType)
        local sb = tostring(b.signature) .. tostring(b.returnType)
        return sa < sb
    end)
    table.sort(result.fields, function(a,b) return tostring(a.name) < tostring(b.name) end)
    result.methodCount = #result.methods
    result.fieldCount = #result.fields
    return result
end

-- A curated v4.5-compatible target index. Missing types are preserved as explicit misses.
local GROUPS = {
    { id="items", title="Items and Equipment", types={
        "app.ItemManager", "app.ItemData", "app.ItemCommonParam", "app.ItemWeaponParam",
        "app.ItemArmorParam", "app.ItemDataParam", "app.ItemCategory", "app.ItemDataType",
        "app.EquipCategory", "app.ItemEquipCategory", "app.WeaponType", "app.ArmorType",
    }},
    { id="enemies", title="Enemies", types={
        "app.EnemyManager", "app.Enemy", "app.EnemyCharacter", "app.EnemyData",
        "app.HumanEnemyBrain", "app.EnemyBrain",
    }},
    { id="combat", title="Combat", types={
        "app.BattleManager", "app.HitManager", "app.HitController", "app.HitController.DamageInfo",
        "app.AttackUserData", "app.CharacterCommonDamageParameter", "app.StatusConditionCtrl",
        "app.StatusConditionInfo", "app.PlayerDamageCalculator", "app.ExceptPlayerDamageCalculator",
        "app.HateSystem", "app.AttackUserData.ElementType", "app.AttackUserData.DamageTypeEnum",
    }},
    { id="characters", title="Characters and Equipment", types={
        "app.CharacterManager", "app.PawnManager", "app.Character", "app.Human",
        "app.CharacterData", "app.EquipData", "app.EquipParam", "app.HumanParameter",
        "app.Character.JobEnum", "app.WeaponEnhanceParam", "app.ArmorEnhanceParam",
    }},
    { id="performance", title="Rendering and Generation", types={
        "app.GenerateManager", "app.UpperBodyTransformerLODProcessor", "app.CharacterJointConstraintsLODProcessor",
        "app.CharacterFacialLODProcessor", "app.CharacterMeshVisibleToggler", "via.render.Renderer",
        "via.render.RenderOutput", "via.effect.QualitySettings", "via.dynamics.Ragdoll", "via.motion.Chain",
    }},
    { id="shops", title="Shops", types={"app.ItemShopParam", "app.ItemShopData", "app.ItemManager"}},
    { id="enhance", title="Enhancements", types={
        "app.WeaponEnhanceParam", "app.ArmorEnhanceParam", "app.EquipSpecial", "app.EquipEnchantType",
    }},
    { id="singletons", title="Managers", types={
        "app.ItemManager", "app.EnemyManager", "app.CharacterManager", "app.PawnManager", "app.QuestManager",
        "app.GimmickManager", "app.InteractManager", "app.BattleManager", "app.HitManager", "app.TimeManager",
        "app.WeatherManager", "app.CameraManager", "app.NetworkManager", "app.NPCManager", "app.TalkManager",
        "app.CampManager", "app.MovieManager", "app.AIManager", "app.NavigationManager", "app.GuiManager",
        "app.SoundVoiceManager", "app.GenerateManager", "app.EnvironmentLoadManager", "app.SuddenQuestManager",
        "app.TalkEventManager",
    }},
    { id="enums", title="Enums", enum=true, types={
        "app.ItemCategory", "app.ItemDataType", "app.EquipCategory", "app.ItemEquipCategory",
        "app.WeaponType", "app.ArmorType", "app.Character.JobEnum", "app.ElementType", "app.DamageType",
        "app.ItemIDEnum", "app.EquipData.SlotEnum", "app.QuestType", "app.QuestState",
        "app.ItemAttrBits", "app.EquipSpecial", "app.EquipEnchantType", "app.HumanCustomSkillID",
    }},
    { id="quests", title="Quests", types={
        "app.QuestManager", "app.QuestType", "app.QuestState", "app.QuestData",
    }},
    { id="vocation", title="Vocations and Skills", types={
        "app.JobParameter", "app.HumanStaminaParameter", "app.LVupParameterUserData",
        "app.HumanCustomSkillID", "app.AbilityParameter", "app.HumanActionParameter",
        "app.HumanSkillAvailability", "app.HumanSkillContext", "app.Character.JobEnum",
    }},
    { id="warfarer", title="Warfarer", types={
        "app.PlayerInputProcessor", "app.HumanSkillContext", "app.HumanSkillAvailability",
        "app.Job10WeaponManager", "app.Human", "app.EquipData", "app.HumanCustomSkillID",
    }},
    { id="pawn_ai", title="Pawn Brain and AI", types={
        "app.PawnBrain", "app.HumanEnemyBrain", "app.HumanBrain", "app.CharacterBrain", "app.AIBrain",
        "app.EnemyBrain", "app.HumanActionSelector", "app.PawnActionSelector", "app.EnemyActionSelector",
        "app.CharacterActionSelector", "app.CommonActionSelector", "app.HumanActionController",
        "app.PawnActionController", "app.PawnSkillContext", "app.HumanSkillContext",
        "app.HumanSkillAvailability", "app.HateSystem", "app.HateController", "app.ThreatTable",
        "app.ThreatController", "app.AggroSystem", "app.AIManager", "app.AIController",
    }},
    { id="health", title="Health and Loss Gauge", types={
        "app.Character", "app.HitController", "app.Human", "app.BattleManager",
        "app.GuiManager", "app.PawnManager", "app.CharacterManager",
    }},
    { id="affinity", title="Affinity and Beloved", types={
        "app.CharacterManager", "app.NPCManager", "app.NPCHolder", "app.SentimentInfo",
        "app.GUIBase", "app.Character", "via.Transform",
    }},
}
local group_index = {}
for _, group in ipairs(GROUPS) do group_index[group.id] = group end

local function start_profiles(groups)
    if current then note("A job is running. Cancel first."); return end
    local total = 0
    for _, g in ipairs(groups) do total = total + #g.types end
    current = {
        kind="profiles", id=stamp(), groups=groups, groupNum=1, typeNum=1,
        total=total, complete=0, found=0, written=0,
        rows={}, errors={}, started=os.date("%Y-%m-%d %H:%M:%S %z"),
    }
    note("Started type profile: " .. total .. " type lookups across " .. #groups .. " groups")
end
local function profile_tick()
    if not current or current.kind ~= "profiles" then return end
    local g = current.groups[current.groupNum]
    if not g then
        local job = current
        local report = { kind=job.kind, id=job.id, captured=environment(),
            started=job.started, count=job.complete, found=job.found,
            filesWritten=job.written, errors=job.errors,
        }
        save(job.id .. "_report", report)
        last_report = "Profile finished: " .. job.found .. "/" .. job.complete .. " types found"
        current = nil
        note(last_report)
        return
    end
    local tn = g.types[current.typeNum]
    if not tn then
        local data = { kind="type-profile", group=g.id, title=g.title,
            captured=environment(), rows=current.rows }
        local ok = save(current.id .. "_types_" .. g.id, data)
        if ok then current.written = current.written + 1 end
        current.rows = {}
        current.groupNum = current.groupNum + 1
        current.typeNum = 1
        return
    end
    local ok, row = pcall(inspect_type, tn, g.enum == true)
    if not ok then
        current.errors[#current.errors+1] = tn .. ": " .. tostring(row)
        row = { name=tn, exists=false, error=tostring(row) }
    end
    if row.exists then current.found = current.found + 1 end
    current.rows[#current.rows + 1] = row
    current.typeNum = current.typeNum + 1
    current.complete = current.complete + 1
end

local function safe_number(obj, meth)
    local v = invoke(obj, meth)
    return type(v) == "number" and v or nil
end
local function sample_char(obj)
    if not obj then return { available=false } end
    local out = {
        available=true, type=type_of(obj),
        hp=safe_number(obj,"get_Hp"),
        originalMaxHp=safe_number(obj,"get_OriginalMaxHp"),
        reducedMaxHp=safe_number(obj,"get_ReducedMaxHp"),
    }
    local hit = get_field(obj, "<Hit>k__BackingField") or invoke(obj,"get_Hit")
    out.hitType = type_of(hit)
    if out.originalMaxHp and out.reducedMaxHp then
        out.lossGaugeDeficit = out.originalMaxHp - out.reducedMaxHp
    end
    return out
end
local MANAGERS = group_index.singletons.types
local function capture_runtime()
    if current then note("A job is running. Cancel first."); return end
    local id = stamp()
    local output = { kind="runtime-readonly", captured=environment(), managers={}, party={} }
    for _, name in ipairs(MANAGERS) do
        local obj, err = attempt(function() return sdk.get_managed_singleton(name) end)
        output.managers[#output.managers + 1] = { name=name, available=obj~=nil, type=type_of(obj), error=err }
    end
    local cm = attempt(function() return sdk.get_managed_singleton("app.CharacterManager") end)
    output.party.player = sample_char(invoke(cm,"get_ManualPlayer"))
    local pm = attempt(function() return sdk.get_managed_singleton("app.PawnManager") end)
    local p_list = invoke(pm,"get_PawnCharacterList")
    output.party.listType = type_of(p_list)
    local count = safe_number(p_list,"get_Count") or 0
    output.party.pawnCount = count
    output.party.pawns = {}
    for i=0, math.min(count-1, 7) do
        local obj = invoke(p_list,"get_Item(System.Int32)",i) or invoke(p_list,"get_Item",i)
        output.party.pawns[#output.party.pawns + 1] = sample_char(obj)
    end
    local bm = attempt(function() return sdk.get_managed_singleton("app.BattleManager") end)
    output.battleMode = primitive(invoke(bm,"get_BattleMode"))
    local gm = attempt(function() return sdk.get_managed_singleton("app.GuiManager") end)
    output.paused = primitive(invoke(gm,"isPausedGUI"))
    local human = invoke(cm,"get_ManualPlayerHuman")
    output.warfarer = { humanType=type_of(human) }
    if human then
        local props = {"get_SkillContext", "get_SkillAvailability", "get_Job10WeaponManager", "get_EquipItemCtrl"}
        for _, getter in ipairs(props) do
            output.warfarer[getter] = type_of(invoke(human,getter))
        end
    end
    local ok, filename = save(id .. "_runtime", output)
    last_report = (ok and "Runtime snapshot saved: " or "Runtime snapshot FAILED: ") .. filename
end

-- Item catalog v5.1: fresh bounded enumeration per batch, persistent ID-based dedup.
-- Dictionary enumerator order is NOT sorted by item ID and may change after reload;
-- never rely on array offset or "last item ID" as a cross-session cursor.
local ITEM_FIELDS = {"_Id","_SortNo","_Category","_SubCategory","_Attr","_ModelId",
    "_IconNo","_Weight","_BuyPrice","_SellPrice","_StackNum","_Worth","_Favor","_ItemDropId"}
local import_filename = "DD2Dumper_20261011_213538_002_items.json" -- editable in UI
local reset_armed = false
local function read_keyvalue(cur, field)
    return get_field(cur, field) or invoke(cur, "get_" .. field)
end
local function item_key(v)
    local n = primitive(v)
    if type(n) == "number" and n == math.floor(n) then return tostring(n), n end
    return nil, nil
end
local function make_progress(previous)
    local generation = ((previous and previous.generation) or 0) + 1
    return {
        kind="item-export-progress", schema=1, dumperVersion=VERSION,
        runId=stamp() .. "_g" .. string.format("%03d",generation), generation=generation,
        batchNumber=0, exportedIds={}, importedFiles={},
        exportedCount=0, completed=false,
        tdbVersion=attempt(function() return sdk.get_tdb_version() end),
        started=os.date("%Y-%m-%d %H:%M:%S %z"),
    }
end
local function load_progress()
    local p, err = attempt(function() return json.load_file(ITEM_PROGRESS_FILE) end)
    if p == nil or p == false then
        if err then note("No readable checkpoint (" .. tostring(err) .. "); starting blank only if none exists") end
        return nil
    end
    if type(p) ~= "table" or p.kind ~= "item-export-progress" or p.schema ~= 1 or
       type(p.exportedIds) ~= "table" or type(p.batchNumber) ~= "number" or
       type(p.runId) ~= "string" then
        note("INVALID item checkpoint; cannot safely resume. Back it up before resetting.")
        return false
    end
    local this_tdb = attempt(function() return sdk.get_tdb_version() end)
    if p.tdbVersion ~= nil and this_tdb ~= nil and p.tdbVersion ~= this_tdb then
        note("Checkpoint TDB mismatch: "..tostring(p.tdbVersion).." vs "..tostring(this_tdb))
        note("To avoid mixing game versions, reset the index or restore the previous version.")
        return false
    end
    return p
end
local function save_progress(p)
    local ok = save("item_progress", p)
    if not ok then note("CHECKPOINT SAVE FAILED: do not restart until resolved") end
    return ok
end
local function indexed_set(p)
    local ids = {}
    for _, v in ipairs(p.exportedIds) do ids[tostring(v)] = true end
    return ids
end
local function validate_name(file)
    -- File names only, always within REFramework's data folder; no external paths.
    return type(file)=="string" and #file > 5 and #file < 220 and
        file:match("^[%w_%.%-]+%.json$") and not file:find("..",1,true)
end
local function import_items()
    if current then note("Cannot import during a running job"); return end
    if not validate_name(import_filename) then note("Import expects a JSON filename, no directory path"); return end
    local existing, err = attempt(function() return json.load_file(import_filename) end)
    if type(existing) ~= "table" or type(existing.rows) ~= "table" then
        note("IMPORT FAILED: could not read item rows in "..import_filename.." ("..tostring(err)..")")
        return
    end
    if existing.kind ~= "item-catalog-best-effort" and existing.kind ~= "item-catalog-batch" then
        note("IMPORT FAILED: not a supported item dump"); return
    end
    local p = load_progress()
    if p == false then return end
    if not p then p = make_progress() end
    local source_tdb = existing.captured and existing.captured.tdbVersion
    if p.tdbVersion and source_tdb and p.tdbVersion ~= source_tdb then
        note("IMPORT BLOCKED: source TDB "..tostring(source_tdb).." differs from progress TDB "..tostring(p.tdbVersion))
        return
    end
    local seen = indexed_set(p)
    local added, invalid = 0, 0
    local ids = {}
    for _, row in ipairs(existing.rows) do
        local key,n = item_key(row.id or row._Id)
        if not key then invalid=invalid+1
        elseif not seen[key] then
            seen[key]=true
            ids[#ids+1]=n
            added=added+1
        end
    end
    if invalid > 0 then
        note("IMPORT FAILED: "..invalid.." item IDs missing/invalid; refusing partial import")
        return
    end
    for _, n in ipairs(ids) do p.exportedIds[#p.exportedIds+1] = n end
    -- If recovering a batch from this same run after a failed checkpoint write,
    -- advance the sequence too, so the next export cannot overwrite that file.
    if existing.kind=="item-catalog-batch" and existing.runId==p.runId and
       type(existing.batchNumber)=="number" then
        p.batchNumber=math.max(p.batchNumber,existing.batchNumber)
    end
    p.exportedCount = #p.exportedIds
    p.importedFiles = p.importedFiles or {}
    p.importedFiles[#p.importedFiles+1] = { filename=import_filename, rowCount=#existing.rows, newIds=added }
    p.completed = false
    if save_progress(p) then
        note("Imported "..added.." previously unseen IDs from "..import_filename.." (indexed total "..p.exportedCount..")")
        last_report = "Imported "..added.." IDs; next batch will skip them"
    end
end
local function start_items()
    if current then note("A job is running. Cancel first."); return end
    local p = load_progress()
    if p == false then return end
    if not p then p = make_progress() end
    if p.completed then
        note("Dictionary was exhausted in previous successful scan. Reset index to rescan.")
        last_report = "Item catalog complete ("..#p.exportedIds.." unique IDs)"
        return
    end
    local mgr = attempt(function() return sdk.get_managed_singleton("app.ItemManager") end)
    if not mgr then note("Cannot catalog items: app.ItemManager unavailable"); return end
    local dict = get_field(mgr,"_ItemDataDict")
    if not dict then
        save(stamp() .. "_items_diagnostic", {
            captured=environment(), ok=false, reason="_ItemDataDict not accessible",
            managerType=type_of(mgr), managerProfile=inspect_type("app.ItemManager",false),
        })
        note("Item dictionary unavailable; diagnostic saved")
        return
    end
    local dict_type = type_of(dict)
    if p.dictionaryType and p.dictionaryType ~= dict_type then
        note("Dictionary type CHANGED! Old: "..p.dictionaryType.." New: "..tostring(dict_type))
        note("Export blocked. Reset the index only after verifying this game update.")
        return
    end
    local en, err = attempt(function() return dict:call("GetEnumerator") end)
    if not en then en,err = attempt(function() return dict:GetEnumerator() end) end
    if not en then note("Item enumerator unavailable: " .. tostring(err)); return end
    local count = invoke(dict, "get_Count")
    current = {
        kind="items", id=stamp(), enumerator=en, rows={}, ids={}, errors={},
        visited=0, reused=0, skipped=0, limit=ITEM_BATCH_SIZE,
        old=p, known=indexed_set(p), dictCount=type(count)=="number" and count or nil,
        itemDictType=dict_type, itemManagerType=type_of(mgr), sampleItemType=nil,
        started=os.date("%Y-%m-%d %H:%M:%S %z"),
    }
    note("Started batch "..(p.batchNumber+1)..": "..#p.exportedIds.." IDs already exported; "..ITEM_BATCH_SIZE.." new records maximum")
end
local function finish_items(job, reason)
    if job.enumerator then
        attempt(function() job.enumerator:call("Dispose") end)
        job.enumerator = nil
    end
    local p = job.old
    local exported_count = #job.rows
    local complete = reason == "end-of-dictionary" and job.skipped == 0
    if exported_count == 0 then
        if complete then
            p.completed=true
            p.lastReason=reason
            p.lastUpdated=os.date("%Y-%m-%d %H:%M:%S %z")
            if save_progress(p) then
                last_report="Item catalog complete: "..#p.exportedIds.." unique IDs (0 new this scan)"
                note(last_report)
            end
        else
            last_report="0 items saved ("..reason.."); see diagnostics"
            note(last_report)
        end
        current=nil
        return
    end
    local batch_index = p.batchNumber + 1
    local batch_file = "items_"..p.runId.."_batch_"..string.format("%04d",batch_index)
    local expected_name = PREFIX .. batch_file .. ".json"
    local previously_written = attempt(function() return json.load_file(expected_name) end)
    if previously_written ~= nil and previously_written ~= false then
        last_report="Batch target ALREADY EXISTS; import "..expected_name.." before resuming"
        note(last_report); current=nil; return
    end
    local out = {
        captured=environment(), kind="item-catalog-batch", runId=p.runId,
        batchNumber=batch_index, started=job.started, stopReason=reason,
        reader="app.ItemManager._ItemDataDict (in-game managed dictionary)",
        managerType=job.itemManagerType, dictionaryType=job.itemDictType,
        dictionaryCount=job.dictCount, itemValueType=job.sampleItemType,
        alreadyIndexedBeforeBatch=#p.exportedIds, scannedEntries=job.visited,
        previouslyExportedSkipped=job.reused, invalidSkipped=job.skipped,
        capturedItems=exported_count, errors=job.errors, rows=job.rows,
    }
    local ok = save(batch_file, out)
    if not ok then
        last_report="Batch save FAILED; checkpoint unchanged so no records are lost"
        note(last_report); current=nil; return
    end
    -- Only commit IDs after the batch itself has been saved successfully.
    for _, v in ipairs(job.ids) do p.exportedIds[#p.exportedIds+1]=v end
    p.batchNumber=batch_index
    p.dictionaryType=job.itemDictType
    p.exportedCount=#p.exportedIds
    p.completed=complete
    p.lastReason=reason
    p.lastUpdated=os.date("%Y-%m-%d %H:%M:%S %z")
    p.lastBatchFile=PREFIX..batch_file..".json"
    if save_progress(p) then
        last_report="Saved batch "..batch_index..": "..exported_count.." new, "..#p.exportedIds.." total"
        if complete then last_report=last_report.." - dictionary exhausted" end
        note(last_report)
    else
        last_report="Batch data saved but CHECKPOINT FAILED; import "..p.lastBatchFile.." before resuming!"
        note(last_report)
    end
    current=nil
end
local function item_tick()
    local job=current
    if not job or job.kind~="items" then return end
    for _=1,ITEMS_PER_FRAME do
        if #job.rows >= job.limit then finish_items(job,"batch-size-reached"); return end
        local advanced, move_err = attempt(function() return job.enumerator:call("MoveNext") end)
        if advanced==nil then advanced,move_err=attempt(function() return job.enumerator:MoveNext() end) end
        if advanced==nil then
            job.errors[#job.errors+1]="MoveNext failed: "..tostring(move_err)
            finish_items(job,"enumeration-error"); return
        elseif advanced==false then finish_items(job,"end-of-dictionary"); return end
        job.visited=job.visited+1
        local ok, err=pcall(function()
            local cur=invoke(job.enumerator,"get_Current") or get_field(job.enumerator,"Current")
            if not cur then error("Current not readable") end
            local key,n = item_key(read_keyvalue(cur,"key") or read_keyvalue(cur,"Key"))
            if not key then error("Item ID unavailable; cannot safely deduplicate") end
            if job.known[key] then
                job.reused=job.reused+1
                return
            end
            local val=read_keyvalue(cur,"value") or read_keyvalue(cur,"Value")
            if not val then error("Value not readable") end
            job.sampleItemType=job.sampleItemType or type_of(val)
            local row={index=job.visited, id=n, valueType=type_of(val)}
            for _,fname in ipairs(ITEM_FIELDS) do row[fname]=primitive(get_field(val,fname)) end
            job.rows[#job.rows+1]=row
            job.ids[#job.ids+1]=n
            job.known[key]=true
        end)
        if not ok then
            job.skipped=job.skipped+1
            if #job.errors<25 then job.errors[#job.errors+1]="entry "..job.visited..": "..tostring(err) end
        end
    end
end
local function reset_item_index()
    if current then note("Cannot reset while a job runs"); return end
    local previous=load_progress()
    if previous == false then return end
    local p=make_progress(previous)
    if save_progress(p) then
        last_report="New catalog run initialized; old batch JSON files were NOT deleted"
        note(last_report)
    end
end

-- v5.2 detailed item-parameter export. Separate checkpoint from v5.1's completed ID catalog.
-- Strictly read only; no hooks and no setters. All record keys come from the live dictionary.
local DETAIL_PROGRESS_FILE = "DD2Dumper_v52_detail_progress.json"
local DETAIL_BATCH_SIZE = 1000
local DETAIL_PER_FRAME = 16
local DETAIL_SCHEMA = 2
local COMMON_PARAM_FIELDS = {
    "_Id", "_SortNo", "_Category", "_Attr", "_ModelId", "_IconNo", "_Weight",
    "_BuyPrice", "_SellPrice", "_StackNum", "_Worth", "_Favor", "_ItemDropId",
    "_Material", "_FieldModelId", "_AutoSellPrio", "_StolenPrio", "_FavoriteAttr",
    "WarehouseMaxStackNum", "<DataType>k__BackingField",
}
local SPECIFIC_EXPECTED = {
    ["app.ItemWeaponParam"] = {"_PhysicalAttack", "_MagicAttack", "_Element", "_StaminaReduce", "_WeaponId", "_WeaponName"},
    ["app.ItemArmorParam"] = {"_PhysicalDefence", "_MagicDefence", "_Special", "_SpecialValue", "_SpecialValue2", "_SpecialValue3"},
    ["app.ItemDataParam"] = {"_HealWhiteHp", "_HealBlackHp", "_HealStamina", "_HealBlackStamina", "_UseEffect"},
}
local DETAIL_TYPES = {
    "app.ItemCommonParam", "app.ItemWeaponParam", "app.ItemArmorParam", "app.ItemDataParam",
    "app.ItemManager", "app.ItemData", "app.ItemParameters", "app.ItemIDEnum",
    "app.WeaponEnhanceParam", "app.ArmorEnhanceParam", "app.EquipData",
    "app.EquipmentAbilityData", "app.WeaponID", "app.EquipSpecial",
    "app.ArmorSpecialEfficacyParameter", "app.JewelryAdditionalData",
    "app.ArmorAdditionalData", "app.AppraisalItemInfoManager",
    "app.ItemShopAdditionalData", "app.ItemShopParam", "app.ItemShopData",
    "app.ExtendedItemDropData.TableData", "app.ItemDropParam",
    "app.ItemUseEffect", "app.ItemSubCategory", "app.ItemCategory", "app.ItemDataType",
}
local detail_reset_armed = false
local detail_cache = {}
local function detail_checkpoint(previous)
    local generation = ((previous and previous.generation) or 0) + 1
    return {kind="detailed-item-progress", schema=DETAIL_SCHEMA, version=VERSION,
        generation=generation, runId=stamp() .. "_d" .. generation,
        exportedIds={}, exportedCount=0, batchNumber=0,
        completed=false, tdbVersion=attempt(function() return sdk.get_tdb_version() end),
        started=os.date("%Y-%m-%d %H:%M:%S %z")}
end
local function load_detail_progress()
    local p,err=attempt(function() return json.load_file(DETAIL_PROGRESS_FILE) end)
    if p==nil or p==false then
        if err then note("Detailed checkpoint unreadable: "..tostring(err)) end
        return nil
    end
    if type(p)~="table" or p.schema~=DETAIL_SCHEMA or p.kind~="detailed-item-progress"
        or type(p.runId)~="string" or type(p.batchNumber)~="number"
        or type(p.exportedIds)~="table" then
        note("INVALID detailed checkpoint: back it up, then reset if necessary")
        return false
    end
    local tdb=attempt(function() return sdk.get_tdb_version() end)
    if p.tdbVersion~=nil and tdb~=nil and p.tdbVersion~=tdb then
        note("Detailed checkpoint TDB mismatch; start a new generation for the new game build")
        return false
    end
    return p
end
local function save_detail_progress(p)
    local ok=save("v52_detail_progress",p)
    if not ok then note("Detailed checkpoint SAVE FAILED; preserve last batch for recovery") end
    return ok
end
local function is_field_scalar_type(t)
    if type(t)~="string" then return true end -- fallback for unavailable metadata
    if t=="System.String" or t=="System.Boolean" or t=="System.Char" then return true end
    -- Lua patterns have no alternation! Separate numeric cases below.
    if t:match("^System%.Int%d+$") or t:match("^System%.UInt%d+$") or
       t=="System.Byte" or t=="System.SByte" or t=="System.Single" or t=="System.Double" then return true end
    if t:match("^app%.[%w_%.]+$") then return true end -- enums will be tested by primitive()
    return false
end
local function detail_fields(type_name)
    if detail_cache[type_name] then return detail_cache[type_name] end
    local fields,seen = {},{}
    local td=attempt(function() return sdk.find_type_definition(type_name) end)
    local chain=0
    while td and chain<6 do
        chain=chain+1
        local owner=name_of(td) or "?"
        local list=attempt(function() return td:get_fields() end)
        if list then
            pcall(function()
                for _,field in ipairs(list) do
                    local name=attempt(function() return field:get_name() end)
                    local ft=name_of(attempt(function() return field:get_type() end))
                    local static=attempt(function() return field:is_static() end)
                    if type(name)=="string" and not seen[name] and static~=true and is_field_scalar_type(ft) then
                        seen[name]=true
                        fields[#fields+1]={name=name,type=ft,declaredBy=owner}
                    end
                end
            end)
        end
        td=attempt(function() return td:get_parent_type() end)
    end
    table.sort(fields,function(a,b) return a.name<b.name end)
    detail_cache[type_name]=fields
    return fields
end
local function detail_read_scalar(obj,field)
    local v=get_field(obj,field)
    local n=primitive(v)
    -- nil genuinely means unavailable / non-scalar, not zero. Do not invent values.
    if type(n)=="number" or type(n)=="boolean" or type(n)=="string" then return n end
    return nil
end
local function detailed_item_row(id,obj)
    local typename=type_of(obj) or "<unknown>"
    local result={id=id, valueType=typename, common={}, specific={}}
    local read,found = {},{}
    for _,entry in ipairs(detail_fields(typename)) do
        local v=detail_read_scalar(obj,entry.name)
        if v~=nil then
            local target=entry.declaredBy=="app.ItemCommonParam" and result.common or result.specific
            target[entry.name]=v
            read[entry.name]=true
        end
        found[entry.name]=true
    end
    -- Direct lookups remain a fallback when get_fields misses inherited members.
    for _,name in ipairs(COMMON_PARAM_FIELDS) do
        if not read[name] then
            local v=detail_read_scalar(obj,name)
            if v~=nil then result.common[name]=v; read[name]=true end
        end
    end
    local expected=SPECIFIC_EXPECTED[typename]
    if expected then
        for _,name in ipairs(expected) do
            if not read[name] then
                local v=detail_read_scalar(obj,name)
                if v~=nil then result.specific[name]=v; read[name]=true end
            end
        end
    end
    result.fieldCount=0
    for _ in pairs(read) do result.fieldCount=result.fieldCount+1 end
    result.expectedMissing={}
    if expected then
        for _,name in ipairs(expected) do
            if not read[name] then result.expectedMissing[#result.expectedMissing+1]=name end
        end
    end
    return result
end
local function start_detail_items()
    if current then note("A job is running; cancel first"); return end
    local p=load_detail_progress()
    if p==false then return end
    if not p then p=detail_checkpoint() end
    if p.completed then
        note("Detailed export already complete: "..#p.exportedIds.." IDs. Reset detailed index only to recapture.")
        return
    end
    local mgr=attempt(function() return sdk.get_managed_singleton("app.ItemManager") end)
    local dict=get_field(mgr,"_ItemDataDict")
    if not dict then note("Detailed export unavailable: app.ItemManager._ItemDataDict missing"); return end
    local dict_type=type_of(dict)
    if p.dictionaryType and dict_type~=p.dictionaryType then
        note("BLOCKED: detailed dictionary type changed; start a fresh generation after verification")
        return
    end
    local en=attempt(function() return dict:call("GetEnumerator") end)
    if not en then en=attempt(function() return dict:GetEnumerator() end) end
    if not en then note("Detailed export cannot acquire dictionary enumerator"); return end
    current={kind="detail", started=os.date("%Y-%m-%d %H:%M:%S %z"),
        old=p, enumerator=en, dictionaryType=dict_type,
        dictionaryCount=safe_number(dict,"get_Count"), known=indexed_set(p),
        rows={}, ids={}, scanned=0, reused=0, skipped=0, errors={}, typeCounts={},
        limit=DETAIL_BATCH_SIZE}
    note("Detailed item batch started: "..#p.exportedIds.." indexed; up to "..DETAIL_BATCH_SIZE.." enriched rows")
end
local function finish_detail(job,reason)
    if job.enumerator then attempt(function() job.enumerator:call("Dispose") end); job.enumerator=nil end
    local p=job.old
    local full=reason=="end-of-dictionary" and job.skipped==0
    if #job.rows==0 then
        if full then
            p.completed=true;p.lastReason=reason
            if save_detail_progress(p) then last_report="Detailed catalog exhausted: "..#p.exportedIds.." IDs" end
        else note("Detailed batch: 0 rows, "..reason.." (errors="..#job.errors..")") end
        current=nil;return
    end
    local nb=p.batchNumber+1
    local suffix="v52_detail_"..p.runId.."_batch_"..string.format("%04d",nb)
    local name=PREFIX..suffix..".json"
    local previous=attempt(function() return json.load_file(name) end)
    if previous~=nil and previous~=false then
        note("BLOCKED: detailed batch file already exists: "..name..". Recover its checkpoint before retrying.")
        current=nil; return
    end
    local out={kind="item-detail-batch",schema=DETAIL_SCHEMA,captured=environment(),
        source="live app.ItemManager._ItemDataDict",runId=p.runId,batchNumber=nb,
        dictionaryType=job.dictionaryType,dictionaryCount=job.dictionaryCount,
        stopReason=reason,scannedEntries=job.scanned,alreadyExported=job.reused,
        invalidSkipped=job.skipped,typeCounts=job.typeCounts,
        capturedItems=#job.rows,errors=job.errors,rows=job.rows,
        caveats={"Read-only runtime fields; enhancement roll validity is NOT inferred",
                 "Item weight units and meaning have not been verified",
                 "Missing fields may be unavailable via reflection, not absent in game"}}
    if not save(suffix,out) then
        note("Detailed batch NOT SAVED; checkpoint unchanged");current=nil;return
    end
    for _,id in ipairs(job.ids) do p.exportedIds[#p.exportedIds+1]=id end
    p.exportedCount=#p.exportedIds;p.batchNumber=nb;p.dictionaryType=job.dictionaryType
    p.completed=full;p.lastBatchFile=name;p.lastReason=reason
    p.lastUpdated=os.date("%Y-%m-%d %H:%M:%S %z")
    if save_detail_progress(p) then
        last_report="Detailed batch "..nb..": "..#job.rows.." exported, "..p.exportedCount.." unique total"
        if full then last_report=last_report.."; dictionary exhausted" end
        note(last_report)
    else note("Saved "..name.." but checkpoint failed. Recover using import before another batch") end
    current=nil
end
local function detail_tick()
    local job=current
    if not job or job.kind~="detail" then return end
    for _=1,DETAIL_PER_FRAME do
        if #job.rows>=job.limit then finish_detail(job,"batch-size-reached");return end
        local advanced,err=attempt(function() return job.enumerator:call("MoveNext") end)
        if advanced==nil then advanced,err=attempt(function() return job.enumerator:MoveNext() end) end
        if advanced==nil then
            job.errors[#job.errors+1]="MoveNext: "..tostring(err)
            finish_detail(job,"enumeration-error");return
        elseif advanced==false then finish_detail(job,"end-of-dictionary");return end
        job.scanned=job.scanned+1
        local ok,why=pcall(function()
            local entry=invoke(job.enumerator,"get_Current") or get_field(job.enumerator,"Current")
            if not entry then error("dictionary entry unavailable") end
            local key,id=item_key(read_keyvalue(entry,"key") or read_keyvalue(entry,"Key"))
            if not key then error("item key unavailable") end
            if job.known[key] then job.reused=job.reused+1;return end
            local value=read_keyvalue(entry,"value") or read_keyvalue(entry,"Value")
            if not value then error("item value unavailable") end
            local row=detailed_item_row(id,value)
            if row.fieldCount==0 then error("no scalar item fields readable for "..row.valueType) end
            job.rows[#job.rows+1]=row;job.ids[#job.ids+1]=id;job.known[key]=true
            job.typeCounts[row.valueType]=(job.typeCounts[row.valueType] or 0)+1
        end)
        if not ok then
            job.skipped=job.skipped+1
            if #job.errors<50 then job.errors[#job.errors+1]="entry "..job.scanned..": "..tostring(why) end
        end
    end
end
local function reset_detail_progress()
    if current then note("Cannot reset during a job");return end
    local p=load_detail_progress()
    if p==false then
        note("INVALID checkpoint: manual backup/removal may be necessary; no files changed");return
    end
    local next=detail_checkpoint(p)
    if save_detail_progress(next) then note("Detailed checkpoint reset (old JSON batches untouched)") end
end
local detail_import_filename=""
local function recover_detail_batch()
    if current then note("Cannot recover during a job");return end
    if not validate_name(detail_import_filename) then note("Enter a detail batch JSON filename only");return end
    local d=attempt(function() return json.load_file(detail_import_filename) end)
    if type(d)~="table" or d.kind~="item-detail-batch" or d.schema~=DETAIL_SCHEMA or type(d.rows)~="table" then
        note("Recovery FAILED: not a v5.2 detail batch");return
    end
    local p=load_detail_progress();if p==false then return end
    if not p then note("Recovery needs its original checkpoint/run ID; refusing to combine unrelated runs");return end
    if d.runId~=p.runId then note("Recovery BLOCKED: runId mismatch");return end
    if p.tdbVersion and d.captured and d.captured.tdbVersion and p.tdbVersion~=d.captured.tdbVersion then
        note("Recovery BLOCKED: TDB mismatch");return
    end
    local seen=indexed_set(p);local add={}
    for _,row in ipairs(d.rows) do
        local key,id=item_key(row.id)
        if not key then note("Recovery BLOCKED: invalid item ID");return end
        if not seen[key] then seen[key]=true;add[#add+1]=id end
    end
    for _,id in ipairs(add) do p.exportedIds[#p.exportedIds+1]=id end
    p.exportedCount=#p.exportedIds
    p.batchNumber=math.max(p.batchNumber,d.batchNumber or 0)
    p.completed=d.stopReason=="end-of-dictionary" and d.invalidSkipped==0
    p.lastBatchFile=detail_import_filename
    if save_detail_progress(p) then note("Recovered "..#add.." detailed IDs from "..detail_import_filename) end
end

local function discover_equipment_types()
    if current then note("Cancel current job first");return end
    local group={id="equipment_deep",title="Equipment / enhancements / drops (runtime types)",types=DETAIL_TYPES}
    start_profiles({group})
end

local function cancel_job()
    if not current then return end
    local job = current
    if job.kind == "items" then
        finish_items(job,"user-cancelled")
        return
    end
    if job.kind=="detail" then finish_detail(job,"user-cancelled"); return end
    note("Cancelled incomplete profile job. Completed groups were saved.")
    last_report = "Cancelled profile job ("..job.complete.."/"..job.total..")"
    current = nil
end

-- Minimal predictable integration points. No work runs on script load.
re.on_frame(function()
    if not current then return end
    if current.kind == "profiles" then profile_tick()
    elseif current.kind == "items" then item_tick()
    elseif current.kind == "detail" then detail_tick() end
end)
re.on_draw_ui(function()
    if not imgui.tree_node("DD2 Data Dumper " .. VERSION .. " (read-only)") then return end
    imgui.text("Output: reframework/data/DD2Dumper_*.json")
    imgui.text("No hooks, gameplay writes, or automatic scans")
    imgui.separator()
    if current then
        if current.kind=="profiles" then
            imgui.text("Profiling: "..current.complete.." / "..current.total.." types")
        elseif current.kind=="items" then
            imgui.text("Item batch: "..#current.rows.." / "..current.limit.." new IDs")
            imgui.text("Dictionary scanned: "..current.visited.." | already indexed: "..current.reused)
        elseif current.kind=="detail" then
            imgui.text("Detailed batch: "..#current.rows.." / "..current.limit)
            imgui.text("Scanned "..current.scanned.." | already indexed "..current.reused.." | invalid "..current.skipped)
        end
        if imgui.button("Cancel current job") then cancel_job() end
    else
        if imgui.button("Capture live runtime") then capture_runtime() end
        if imgui.button("Export NEXT item batch (1500 new IDs)") then start_items() end
        imgui.separator()
        imgui.text("v5.2 DETAILED ITEM STATS (separate from completed v5.1 catalog)")
        if imgui.button("Export NEXT detailed batch (1000 IDs)") then start_detail_items() end
        if imgui.button("Profile equipment / enhancement / drop type schemas") then discover_equipment_types() end
        if imgui.tree_node("Import old item dump / catalog control") then
            imgui.text("Import existing v5.0 or v5.1 items JSON from reframework/data")
            if imgui.input_text then
                local changed, value=imgui.input_text("Item dump filename",import_filename)
                if changed and type(value)=="string" then import_filename=value end
            end
            if imgui.button("Import item dump (skip its IDs next time)") then import_items() end
            if not reset_armed then
                if imgui.button("Reset catalog index (confirm required)") then reset_armed=true end
            else
                imgui.text("This starts a NEW run. Existing batch files are preserved.")
                if imgui.button("CONFIRM start fresh catalog") then reset_item_index(); reset_armed=false end
                if imgui.button("Keep current catalog") then reset_armed=false end
            end
            imgui.tree_pop()
        end
        if imgui.tree_node("Detailed export checkpoint / recovery") then
            imgui.text("Progress file: "..DETAIL_PROGRESS_FILE)
            if imgui.input_text then
                local changed,value=imgui.input_text("Recover detail batch filename",detail_import_filename)
                if changed and type(value)=="string" then detail_import_filename=value end
            end
            if imgui.button("Recover saved detail batch into checkpoint") then recover_detail_batch() end
            if detail_reset_armed then
                imgui.text("Start fresh detailed run? Existing batch files remain untouched.")
                if imgui.button("CONFIRM reset detailed index") then reset_detail_progress();detail_reset_armed=false end
                if imgui.button("Cancel detailed reset") then detail_reset_armed=false end
            else
                if imgui.button("Reset detailed index (requires confirmation)") then detail_reset_armed=true end
            end
            imgui.tree_pop()
        end
        if imgui.button("Profile all known type groups (throttled)") then start_profiles(GROUPS) end
        if imgui.tree_node("Individual type groups") then
            for _, g in ipairs(GROUPS) do
                if imgui.button(g.title .. " ("..#g.types..")") then start_profiles({g}) end
            end
            imgui.tree_pop()
        end
    end
    imgui.separator()
    imgui.text(last_report)
    if imgui.tree_node("Diagnostics log") then
        for _, entry in ipairs(log_entries) do imgui.text(entry) end
        imgui.tree_pop()
    end
    imgui.tree_pop()
end)
note("Loaded v"..VERSION..". Idle until button pressed.")
