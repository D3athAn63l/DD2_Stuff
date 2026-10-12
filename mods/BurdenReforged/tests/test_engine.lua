local here = debug.getinfo(1, 'S').source:sub(2):match('^(.*)[/\\]')
local SCRIPT = here .. '/../reframework/autorun/burden_reforged.lua'
local callbacks, hooks, config, saves, items, weightDict
local function makeItem(id,category,sub,mass,num,equipped,slot,step,weapon)
    local p={_Id=id,_Weight=mass,_Category=category}
    function p:get_IsParam() return category~=3 end
    function p:get_ItemParam() return {_SubCategory=sub} end
    function p:get_IsWeaponData() return weapon or false end
    function p:set_field(k,v) self[k]=v end
    return {obj=p,row={_Param={_ItemData=p,_Num=num or 1,_IsEquipped=equipped,_EquipSlot=slot or 0,_EnhanceStep=step or 0}}}
end
local function setup(options, array, pawnGroups, useFallback)
    callbacks, hooks, config, saves = {}, {}, options or {}, {}
    items=array
    pawnGroups=pawnGroups or {}
    local allItems={}
    for _,item in ipairs(items) do allItems[#allItems+1]=item end
    for _,group in ipairs(pawnGroups) do
        for _,item in ipairs(group) do allItems[#allItems+1]=item end
    end
    local entries={}
    for i,item in ipairs(allItems) do
        entries[i-1]={get_field=function(_,key) if key=='value' then return item.obj end end}
    end
    local dict={get_Count=function() return #allItems end,get_field=function(_,key) if key=='_entries' then return entries end end}
    local function storageFor(group)
        return {get_Count=function() return #group end,get_Item=function(_,i) return group[i+1] and group[i+1].row end}
    end
    local inventories={[123]=storageFor(items)}
    local partyCharacters={}
    local partyIds={}
    for i,group in ipairs(pawnGroups) do
        local id=123+i
        inventories[id]=storageFor(group)
        partyIds[i-1]=id
        partyCharacters[i]={get_CharaID=function() return id end}
    end
    weightDict={value=-1,values={['123']=-1}}
    for i=1,#pawnGroups do weightDict.values[tostring(123+i)]=0 end
    function weightDict:set_Item(id,w)
        self.values[tostring(id)]=w
        if id==123 then self.value=w end
        self.writes=(self.writes or 0)+1
    end
    function weightDict:get_Item(id) return self.values[tostring(id)] end
    local itemMgr={WeightDict=weightDict,StorageDict={get_Item=function(_,id) return inventories[id] end},
      get_field=function(_,key) if key=='_ItemDataDict' then return dict end end,
      getPartyList=function()
          if useFallback then error('party list temporarily unavailable') end
          return {get_Count=function() return #partyCharacters end, get_Item=function(_,i) return partyCharacters[i+1] end}
      end,
      getPartyCharaIds=function()
          return setmetatable({get_Length=function() return #pawnGroups end}, {__index=function(_,index) return partyIds[index] end})
      end}
    local chars={get_ManualPlayer=function() return {get_CharaID=function() return 123 end} end}
    sdk={get_managed_singleton=function(name) if name=='app.ItemManager' then return itemMgr else return chars end end,
        find_type_definition=function() return {get_method=function(_,x) return x end} end,
        hook=function(name,pre,post) hooks[name]=post end}
    re={on_frame=function(fn) callbacks.frame=fn end,on_draw_ui=function(fn) callbacks.ui=fn end,
        on_config_save=function(fn) callbacks.save=fn end,on_script_reset=function(fn) callbacks.reset=fn end}
    log={info=function() end}
    json={load_file=function(name) return name=='WeightSystemTweaks.json' and config or nil end,
        dump_file=function(name, cfg) saves[name]=cfg return true end}
    imgui={tree_node=function() return false end}
end
local function start() assert(loadfile(SCRIPT))();callbacks.frame() end
local function eq(a,b,name) assert(a==b, name..' expected '..tostring(b)..', got '..tostring(a)) end

-- Disabled should ignore category exclusions.
setup({Enabled=false,ItemCategory={['0']=false}}, {makeItem(100,0,0,50,2,false)})
start();eq(weightDict.value,100,'disabled-category');eq(items[1].obj._Weight,50,'disabled-visual')

-- Visual zero should not lose original on reload within the same process.
setup({Enabled=true,Visuals_ShowZeroForConsumables=true}, {makeItem(100,0,0,50,2,false)})
start();eq(weightDict.value,100,'original-mass');eq(items[1].obj._Weight,0,'visual-zero')
callbacks.reset();eq(items[1].obj._Weight,50,'reset-restores-db')
start();eq(weightDict.value,100,'reload-original');eq(items[1].obj._Weight,0,'reload-visual')
callbacks.reset()

-- Subcategory exclusions are respected only when enabled.
setup({Enabled=true,ItemSubCategory={['0']=false}}, {makeItem(100,0,0,50,2,false)})
start();eq(weightDict.value,0,'exclude-healing')

-- Equipped/unequipped equipment and dragonforged half weight.
setup({Enabled=true,NoUnequippedWeight=true,WarfarerFix=false}, {
    makeItem(1000,3,0,201,1,true,0,4,true),makeItem(1001,3,0,150,1,false,1,0,true)})
start();eq(weightDict.value,101,'dragonforged-half-and-unequipped')

-- Heaviest equipped per hand, unknown slot must be counted.
setup({Enabled=true,WarfarerFix=true,NoUnequippedWeight=true}, {
    makeItem(1000,3,0,150,1,true,0,0,true),makeItem(1001,3,0,200,1,true,0,0,true),
    makeItem(1002,3,0,170,1,true,1,0,true),makeItem(1003,3,0,40,1,true,7,0,true)})
start();eq(weightDict.value,410,'warfarer-heaviest')

-- Unequipped weapons must count individually when Magic Pockets is off,
-- even if the Warfarer heaviest-equipped-weapon rule is enabled.
setup({Enabled=true,WarfarerFix=true,NoUnequippedWeight=false}, {
    makeItem(1010,3,0,100,1,true,0,0,true),makeItem(1011,3,0,50,1,false,0,0,true),
    makeItem(1012,3,0,70,1,false,0,0,true)})
start();eq(weightDict.value,220,'unequipped-when-magic-pockets-off')

-- New JSON should win over legacy JSON and reject malicious type values.
setup({Enabled='notBool', ItemCategory={['0']='no'}}, {makeItem(100,0,0,50,2,false)})
start();eq(weightDict.value,100,'config-sanitization')

-- Multiple event hooks only mark dirty; on-frame performs actual work.
local addEventHook
for name,fn in pairs(hooks) do if name:find('addStorageEvent',1,true) then addEventHook=fn end end
assert(addEventHook, 'storage hook registered')
local before=weightDict.writes
items[1].row._Param._Num=3
addEventHook(nil)
-- Value is stale until frame, which is the requested event coalescing.
eq(weightDict.value,100,'hook-deferred')
callbacks.frame();eq(weightDict.value,150,'hook-applied')
assert((weightDict.writes or 0)==before+1)

-- Regression: all party members must receive weight overrides and restore on disable.
-- The old engine refreshed the Arisen only; pawns remained at zero after a global
-- tooltip patch had zeroed the source ItemCommonParam values.
setup({Enabled=true,Visuals_ShowZeroForConsumables=true,NonEquipmentZeroWeight=true},
    {makeItem(100,0,0,50,2,false)},
    {{makeItem(101,0,0,45,3,false)},
     {makeItem(102,0,0,30,4,false)},
     {makeItem(103,0,0,15,5,false)}})
start()
for id=123,126 do eq(weightDict.values[tostring(id)],0,'enabled-party-'..id) end
-- Toggle the master checkbox via the same UI callback used in-game.
imgui={tree_node=function() return true end,
       text=function() end, separator=function() end, tree_pop=function() end,
       button=function() return false end,
       checkbox=function(label, current)
           if label=='Enable weight rules' then return true,false end
           return false,current
       end}
callbacks.ui();callbacks.frame()
eq(weightDict.values['123'],100,'disabled-arisen-recalculate')
eq(weightDict.values['124'],135,'disabled-pawn-1-recalculate')
eq(weightDict.values['125'],120,'disabled-pawn-2-recalculate')
eq(weightDict.values['126'],75,'disabled-pawn-3-recalculate')
for _,item in ipairs(items) do eq(item.obj._Weight,50,'disabled-visual-restoration') end

-- Fallback through getPartyCharaIds(true) when getPartyList is unavailable.
setup({Enabled=false}, {makeItem(200,0,0,20,1,false)},
      {{makeItem(201,0,0,33,2,false)}, {makeItem(202,0,0,41,3,false)}}, true)
start()
eq(weightDict.values['123'],20,'fallback-arisen')
eq(weightDict.values['124'],66,'fallback-pawn1')
eq(weightDict.values['125'],123,'fallback-pawn2')

-- A pawn disappearing mid-transition does not prevent the Arisen refresh.
setup({Enabled=false}, {makeItem(200,0,0,20,2,false)},
      {{makeItem(201,0,0,33,2,false)}})
start()
eq(weightDict.values['123'],40,'transition-arisen')
local transientManager=sdk.get_managed_singleton('app.ItemManager')
local getStorage=transientManager.StorageDict.get_Item
transientManager.StorageDict.get_Item=function(_,id)
    if id==124 then error('pawn inventory has not loaded yet') end
    return getStorage(nil,id)
end
items[1].row._Param._Num=3
local post
for name,fn in pairs(hooks) do if name:find('addStorageEvent',1,true) then post=fn end end
post(nil);callbacks.frame()
eq(weightDict.values['123'],60,'missing-pawn-arisen-still-updates')

print('PASS: 11 independent cases including 3-pawn enable/disable, fallback, hot reload and deferred hooks')
