-- Lightweight mocked hook regression test. Run via tests/run_lua.py
local calls, ui, saved = {}, nil, 0
local sigs = {
 'getStorageWeight(app.Character)',
 'getStorageWeight(app.CharacterID)',
 'getStorageWeightInt(app.CharacterID)',
 'getWeightRank(System.Single, System.Single)',
 'getWeightRank(System.Single, System.Single, app.Character)',
 'getWeightRank(System.Single, System.Single, app.CharacterID, app.IEquipStorageDataGetter)',
 'getWeightRank(System.Single, app.Character)',
 'getWeightRank(app.Character)',
 'getWeightRank(app.CharacterID)'
}
local methods = {}; for _,sig in ipairs(sigs) do methods[sig]=true end
sdk = {
 find_type_definition=function(name)
  assert(name=='app.ItemManager')
  return {get_method=function(_,sig) return methods[sig] and sig or nil end}
 end,
 hook=function(m,pre,post) assert(not calls[m]); calls[m]=post end,
 float_to_ptr=function(v) assert(v==0); return 'FLOATZERO' end,
 to_ptr=function(v) assert(v==0); return 'INTZERO' end
}
json={
 load_file=function() return nil end,
 dump_file=function(_,x) assert(type(x.Enabled)=='boolean'); saved=saved+1; return true end
}
log={info=function() end}
re={
 on_draw_ui=function(f) ui=f end,
 on_config_save=function() end,
 on_script_reset=function() end
}
local nextToggle
imgui={
 tree_node=function() return true end,
 checkbox=function(_,v) if nextToggle~=nil then local a=nextToggle; nextToggle=nil; return true,a end; return false,v end,
 text=function() end,
 tree_pop=function() end
}
dofile(arg[1])
for i,sig in ipairs(sigs) do
 assert(calls[sig],sig)
 assert(calls[sig]('ORIGINAL')==(i<=2 and 'FLOATZERO' or 'INTZERO'))
end
nextToggle=false; ui()
for _,sig in ipairs(sigs) do assert(calls[sig]('ORIGINAL')=='ORIGINAL') end
nextToggle=true; ui()
for i,sig in ipairs(sigs) do assert(calls[sig]('ORIGINAL')==(i<=2 and 'FLOATZERO' or 'INTZERO')) end
assert(saved==2)
print('PASS: nine overloads, return types, toggle OFF/ON, JSON save')
