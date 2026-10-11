-- Mock-only test: no DD2 installation needed.
local targetMap = {
 ["app.CharacterManager"]={"get_ManualPlayer"},
 ["app.NPCManager"]={"getNPCHolder","onUpdate"},
 ["app.NPCHolder"]={"getSentimentInfo","get_Position","get_CachedCharacter","onUpdate_Sentiment","addSentimentValue","setSentimentValue"},
 ["app.GUIBase"]={"getName"},
 ["app.Character"]={"get_CharaID","get_GameObject"},
 ["via.GameObject"]={"get_Transform"},
 ["via.Transform"]={"get_Position","getJointByName"}
}
local function typeDef(name) return {get_full_name=function() return name end} end
local function method(name, paramTypes, opts)
  opts=opts or {}
  local params={}
  for _,p in ipairs(paramTypes) do params[#params+1]=typeDef(p) end
  local sequence=params
  if opts.zeroIndexed then
    -- A native-style proxy: ipairs reads index 1 first, but valid indices start at 0.
    sequence=setmetatable({}, {__index=function(_,i) return params[i+1] end})
  end
  return {
    get_name=function() return name end,
    get_num_params=function() return #paramTypes end,
    get_param_types=function() if opts.badParams then error('mock unsupported param access') end return sequence end,
    get_param_names=function() return {} end,
    get_return_type=function() return typeDef('System.Void') end,
    get_declaring_type=function() return typeDef('app.NPCHolder') end,
    is_static=function() return false end
  }
end
local methods={}
for name, names in pairs(targetMap) do
  methods[name]={}
  for _, methodName in ipairs(names) do
    local params={}
    if methodName=='getSentimentInfo' then params={'System.Int32','System.Boolean'} end
    if methodName=='setSentimentValue' then params={'System.Int32','System.Int32'} end
    if methodName=='getNPCHolder' then params={'System.Int32'} end
    methods[name][#methods[name]+1]=method(methodName, params, {
      zeroIndexed=(methodName=='getNPCHolder'),
      badParams=(methodName=='setSentimentValue')
    })
  end
end
methods['app.NPCHolder'][#methods['app.NPCHolder']+1]=method('getSentimentInfo', {'System.Int32'})
-- Inherited method resolved by direct lookup but not by type enumeration.
local inherited=methods['app.Character'][2]
table.remove(methods['app.Character'],2)
local player={get_CharaID=function() return 42 end}
local sentiment={Value=261}
local holder={getSentimentInfo=function() return sentiment end}
local holderArray={[0]=holder,get_Length=function() return 1 end}
sdk={
 get_tdb_version=function() return 83 end,
 get_managed_singleton=function(name)
   if name=='app.CharacterManager' then return {get_ManualPlayer=function() return player end} end
   if name=='app.NPCManager' then return {NPCHolderDic=holderArray} end
 end,
 find_type_definition=function(name)
   local list=methods[name]; if not list then return nil end
   return {
     get_methods=function() if name=='app.GUIBase' then error('mock enumeration unsupported') end return list end,
     get_method=function(_,methodName)
        if name=='app.Character' and methodName=='get_GameObject' then return inherited end
        for _,m in ipairs(list) do if m:get_name()==methodName then return m end end
        return nil
     end,
     get_field=function(_,field) if name=='app.NPCManager' and field=='NPCHolderDic' then return true end end
   }
 end,
 hook=function() error('SAFETY FAILURE sdk.hook called') end
}
re={on_draw_ui=function(fn) _G.probeUI=fn end,on_frame=function() end,on_script_reset=function() end}
imgui={tree_node=function() return true end,text=function() end,button=function() return true end,tree_pop=function() end,get_display_size=function() end}
draw={world_to_screen=function() end,filled_rect=function() end,filled_quad=function() end,text=function() end}
json={dump_file=function(path, data) _G.outputData=data;_G.savedName=path;return true end, load_file=function() end}
reframework={get_game_name=function() return 'dd2' end,get_commit_hash=function() return 'mock-revision' end}
local scriptPath=assert(_G.PROBE_PATH)
assert(loadfile(scriptPath))()
probeUI()
local snap=assert(outputData)
assert(snap.probeVersion=='1.2')
assert(snap.tdbVersion=='83')
assert(snap.runtime.sampleSentimentValueReadable)
assert(snap.engine.sdk.hook)
assert(snap.types['app.NPCHolder'].methodsFoundCount==7, 'must preserve overload')
assert(snap.types['app.NPCHolder'].methodNamesFoundCount==6)
assert(snap.types['app.NPCHolder'].overloadsByName['getSentimentInfo']==2)
local found={}
for _,m in ipairs(snap.types['app.NPCHolder'].methods) do
  if m.name=='getSentimentInfo' then
    assert(m.signatureStatus=='resolved')
    found[m.signature]=true
  elseif m.name=='setSentimentValue' then
    assert(m.signatureStatus=='unresolved')
    assert(m.parameterCount==2)
  end
end
assert(found['getSentimentInfo(System.Int32)'])
assert(found['getSentimentInfo(System.Int32, System.Boolean)'])
local n=snap.types['app.NPCManager'].methods[1]
assert(n.name=='getNPCHolder' and n.signature=='getNPCHolder(System.Int32)', 'zero-index native-like sequence fallback')
assert(snap.types['app.GUIBase'].enumerationStatus=='error')
assert(snap.types['app.GUIBase'].methodsFoundCount==1)
assert(snap.types['app.GUIBase'].missing[1]==nil)
local direct=false
for _,m in ipairs(snap.types['app.Character'].methods) do
 if m.name=='get_GameObject' and m.resolvedBy=='direct-lookup' then direct=true end
end
assert(direct)
assert(string.find(savedName,'Beloved_API_Probe_'))
print('PASS: v1.2 mock (overloads, signatures, zero-index proxies, failure states, safety, runtime reads)')
