-- Mock REFramework/DD2. Only getter/reflection calls are supported.
local path = assert(PROBE_SOURCE)
local function mockTypeDef(name) return { get_full_name=function() return name end } end
local function meth(name, args, ret, declared, static)
    local types={}
    for _, p in ipairs(args or {}) do types[#types+1] = mockTypeDef(p) end
    return {
        get_name=function() return name end,
        get_num_params=function() return #types end,
        get_param_types=function() return types end,
        get_declaring_type=function() return mockTypeDef(declared or "app.Character") end,
        get_return_type=function() return mockTypeDef(ret or "System.Void") end,
        is_static=function() return static or false end
    }
end
local types={}
local function addClass(name, methodList, fields)
    local def={}
    function def:get_full_name() return name end
    function def:get_methods() return methodList end
    function def:get_method(target)
        for _, m in ipairs(methodList) do if m:get_name()==target then return m end end
    end
    function def:get_field(field) return fields and fields[field] or nil end
    types[name]=def
    return def
end
local function fieldRecord(typeName, declaring)
    return {
      get_type=function() return mockTypeDef(typeName) end,
      get_declaring_type=function() return mockTypeDef(declaring) end,
      is_static=function() return false end
    }
end
addClass('app.CharacterManager', {meth('get_ManualPlayer',{},'app.Character')}, {['<ManualPlayer>k__BackingField']=fieldRecord('app.Character','app.CharacterManager')})
addClass('app.Character', {
    meth('get_Valid',{},'System.Boolean'), meth('get_Hp',{},'System.Single'),
    meth('get_ReducedMaxHp',{},'System.Single'), meth('get_OriginalMaxHp',{},'System.Single'),
    meth('get_Hit',{},'app.character.HitController')
}, {['<Hit>k__BackingField']=fieldRecord('app.character.HitController','app.Character')})
addClass('app.character.HitController', {
    meth('set_ReducedMaxHp',{'System.Single'},'System.Void','app.character.HitController'),
    meth('setHpValue',{'System.Single','System.Boolean'},'System.Void','app.character.HitController'),
    meth('get_ReducedMaxHp',{},'System.Single','app.character.HitController')
})
addClass('app.PawnManager', {meth('get_PawnCharacterList',{},'System.Collections.Generic.List`1<app.Character>')})
addClass('app.GuiManager', {meth('isPausedGUI',{},'System.Boolean')})
addClass('app.BattleManager', {meth('get_BattleMode',{},'System.Int32')})
addClass('MockPawnList', {meth('get_Count',{},'System.Int32'),meth('get_Item',{'System.Int32'},'app.Character')})

local hit = {get_type_definition=function() return types['app.character.HitController'] end}
local function mkCharacter(hp, reduced, orig)
    local obj = {['<Hit>k__BackingField']=hit}
    function obj:get_type_definition() return types['app.Character'] end
    function obj:call(name)
        name=name:gsub('%(%)$','')
        if name=='get_Valid' then return true end
        if name=='get_Hp' then return hp end
        if name=='get_ReducedMaxHp' then return reduced end
        if name=='get_OriginalMaxHp' then return orig end
        if name=='get_Hit' then return hit end
    end
    return obj
end
local player=mkCharacter(300, 400, 1000)
local pawn=mkCharacter(150, 200, 500)
local list={}
function list:get_type_definition() return types['MockPawnList'] end
function list:call(name, idx)
    if name=='get_Count()' or name=='get_Count' then return 1 end
    if name=='get_Item(System.Int32)' or name=='get_Item' then
       if idx==0 then return pawn end
    end
end
local managers={
 ['app.CharacterManager'] = {call=function(_,name) if name=='get_ManualPlayer()' or name=='get_ManualPlayer' then return player end end},
 ['app.GuiManager']={call=function(_, name) if name=='isPausedGUI()' or name=='isPausedGUI' then return false end end},
 ['app.BattleManager']={call=function(_, name) if name=='get_BattleMode()' or name=='get_BattleMode' then return 0 end end},
 ['app.PawnManager']={call=function(_, name) if name=='get_PawnCharacterList()' or name=='get_PawnCharacterList' then return list end end}
}
sdk={
  find_type_definition=function(name) return types[name] end,
  get_managed_singleton=function(name) return managers[name] end,
  get_tdb_version=function() return 83 end,
  hook=function() error('SAFETY FAILURE: sdk.hook called') end
}
local drawing
re={
  on_draw_ui=function(fn) drawing=fn end,
  on_frame=function() error('SAFETY FAILURE: frame callback registered') end,
  on_application_entry=function() error('SAFETY FAILURE: application callback registered') end
}
imgui={
 tree_node=function() return true end,
 text=function() end,
 button=function() return true end,
 tree_pop=function() end
}
json={dump_file=function(filename,obj)
   _G.RESULT_FILENAME=filename
   _G.RESULT_JSON=obj
   return true
end}
reframework={
 get_game_name=function() return 'dd2' end,
 get_commit_hash=function() return 'mock-commit' end,
 get_build_date=function() return '2026-09-16' end,
 get_build_time=function() return '16:39' end
}
assert(loadfile(path))()
assert(type(drawing)=='function')
drawing()
assert(RESULT_FILENAME:match('Health_API_Probe_'))
local snapshot=assert(RESULT_JSON)
assert(snapshot.probeVersion=='1.0' and snapshot.tdbVersion=='83')
assert(snapshot.runtime.player.hp==300)
assert(snapshot.runtime.player.reducedMaxHp==400)
assert(snapshot.runtime.player.originalMaxHp==1000)
assert(snapshot.runtime.player.lossGaugeDeficit==600)
assert(snapshot.runtime.player.hitRuntimeType=='app.character.HitController')
assert(snapshot.runtime.pawnSamples[1].lossGaugeDeficit==300)
assert(snapshot.runtime.battleMode==0 and snapshot.runtime.paused==false)
local td=snapshot.types['app.character.HitController']
assert(td.exists==true and td.resolvedSignatureCount==3)
local found={}
for _, m in ipairs(td.methods) do found[m.signature] = true end
assert(found['set_ReducedMaxHp(System.Single)'])
assert(found['setHpValue(System.Single, System.Boolean)'])
assert(snapshot.types['app.Character'].fields['<Hit>k__BackingField'].type=='app.character.HitController')
print('Mock health API capture passed (player/pawn, dynamic Hit type, signatures, read-only)')
