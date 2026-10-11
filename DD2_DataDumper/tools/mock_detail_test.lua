local script=assert(arg[1]);local saved={}
local ui_cb,frame_cb,next_click,fail_batch,fail_progress,recovery_name
local function clone(x) if type(x)~='table' then return x end local t={} for k,v in pairs(x) do t[k]=clone(v) end return t end
json={dump_file=function(name,d)
 if (fail_batch and name:find('v52_detail_') and name:find('_batch_')) or
    (fail_progress and name=='DD2Dumper_v52_detail_progress.json') then return false end
 saved[name]=clone(d);return true
 end,load_file=function(name) return clone(saved[name]) end}
local function has(a,b) return a:find(b,1,true)~=nil end
imgui={tree_node=function() return true end,tree_pop=function() end,text=function() end,separator=function() end,
 input_text=function(label,val)
  if recovery_name and has(label,'Recover detail') then local result=recovery_name;recovery_name=nil;return true,result end
  return false,val
 end,
 button=function(title) if next_click and has(title,next_click) then next_click=nil;return true end return false end}
re={on_draw_ui=function(fn) ui_cb=fn end,on_frame=function(fn) frame_cb=fn end}
local function def(n)
 local o={}
 function o:get_full_name() return n end
 function o:get_parent_type() if n=='app.ItemWeaponParam' or n=='app.ItemArmorParam' or n=='app.ItemDataParam' then return def('app.ItemCommonParam') end end
 local names={
 ['app.ItemCommonParam']={_Id='System.Int32',_BuyPrice='System.Int32',_Weight='System.Int16'},
 ['app.ItemWeaponParam']={_PhysicalAttack='System.Int16',_MagicAttack='System.Int16',_Element='app.AttackUserData.ElementType',_WeaponName='System.String'},
 ['app.ItemArmorParam']={_PhysicalDefence='System.Int16',_Special='app.EquipSpecial',_SpecialValue='System.Int16'},
 ['app.ItemDataParam']={_HealWhiteHp='System.Int16',_UseEffect='app.ItemUseEffect'}
 }
 function o:get_fields()
  local list={}
  for field,tn in pairs(names[n] or {}) do
   list[#list+1]={get_name=function() return field end,get_type=function() return def(tn) end,is_static=function() return false end}
  end
  return list
 end
 function o:get_methods() return {} end
 return o
end
local function object(t,data)
 local o={}
 function o:get_type_definition() return def(t) end
 function o:get_field(k) return data and data[k] end
 return o
end
local items={}
for i=1,2152 do
 local tp=(i%3==1 and 'app.ItemWeaponParam') or (i%3==2 and 'app.ItemArmorParam') or 'app.ItemDataParam'
 local val={_Id=i,_BuyPrice=1000+i,_Weight=0}
 if tp=='app.ItemWeaponParam' then val._PhysicalAttack=40+i;val._MagicAttack=3;val._Element=0;val._WeaponName='Wpn '..i end
 if tp=='app.ItemArmorParam' then val._PhysicalDefence=100+i;val._Special=2;val._SpecialValue=7 end
 if tp=='app.ItemDataParam' then val._HealWhiteHp=20;val._UseEffect=3 end
 items[i]={key=i,value=object(tp,val)}
end
local scans=0
local dict=object('System.Collections.Generic.Dictionary`2<System.Int32,app.ItemCommonParam>')
function dict:call(m)
 if m=='get_Count' then return #items end
 if m=='GetEnumerator' then
  scans=scans+1;local n=0;local order={}
  for i=1,#items do order[i]=items[(i-1+scans*113)%#items+1] end
  return {call=function(self,name)
   if name=='MoveNext' then n=n+1;return n<=#items end
   if name=='get_Current' then return object('KeyValuePair',{key=order[n] and order[n].key,value=order[n] and order[n].value}) end
   if name=='Dispose' then return true end
  end}
 end
end
local item_mgr=object('app.ItemManager',{_ItemDataDict=dict})
sdk={get_tdb_version=function() return 83 end, find_type_definition=function(n) return def(n) end,
 get_managed_singleton=function(n) if n=='app.ItemManager' then return item_mgr end end}
local function reload() dofile(script) end
local function click(t) next_click=t;ui_cb();assert(not next_click,'not clicked '..t) end
local function frames() for i=1,280 do frame_cb() end end
local function all_detail()
 local by_id={} local total=0 local batches=0
 for name,data in pairs(saved) do
  if data.kind=='item-detail-batch' then
   batches=batches+1;total=total+#data.rows
   for _,r in ipairs(data.rows) do assert(not by_id[r.id], 'duplicate '..r.id);by_id[r.id]=r end
  end
 end
 return by_id,total,batches
end
reload()
click('Export NEXT detailed batch');frames()
local p=assert(saved['DD2Dumper_v52_detail_progress.json'])
assert(p.exportedCount==1000 and p.batchNumber==1 and not p.completed,'batch 1')
reload()
click('Export NEXT detailed batch');frames()
p=assert(saved['DD2Dumper_v52_detail_progress.json'])
assert(p.exportedCount==2000 and p.batchNumber==2,'batch 2')
reload()
click('Export NEXT detailed batch');frames()
p=assert(saved['DD2Dumper_v52_detail_progress.json'])
assert(p.exportedCount==2152 and p.batchNumber==3 and p.completed,'batch 3')
local by_id,total,n=all_detail()
assert(total==2152 and n==3,'all batches')
for i=1,2152 do
 local row=assert(by_id[i],'missing '..i)
 assert(row.common._Id==i and row.common._BuyPrice==1000+i,'common fields '..i)
 if i%3==1 then assert(row.specific._PhysicalAttack==i+40 and row.specific._WeaponName=='Wpn '..i,'weapon '..i)
 elseif i%3==2 then assert(row.specific._PhysicalDefence==i+100 and row.specific._Special==2,'armor '..i)
 else assert(row.specific._HealWhiteHp==20,'consumable '..i) end
end
-- Further exports after exhaustion should not add files.
click('Export NEXT detailed batch');local _,still,bn=all_detail();assert(still==2152 and bn==3)
-- Start fresh detailed run without losing old batches.
click('Reset detailed index');click('CONFIRM reset detailed index')
p=assert(saved['DD2Dumper_v52_detail_progress.json'])
assert(p.exportedCount==0 and not p.completed,'reset')
-- save failure must not advance checkpoint
fail_batch=true
click('Export NEXT detailed batch');frames();fail_batch=false
assert(saved['DD2Dumper_v52_detail_progress.json'].exportedCount==0,'batch failure')
-- failed manifest requires recovery of last batch
fail_progress=true
click('Export NEXT detailed batch');frames();fail_progress=false
assert(saved['DD2Dumper_v52_detail_progress.json'].exportedCount==0,'manifest failure')
local target,run_id
run_id=saved['DD2Dumper_v52_detail_progress.json'].runId
for path,data in pairs(saved) do
 if data.kind=='item-detail-batch' and data.runId==run_id then target=path end
end
assert(target,'missing recovery batch')
recovery_name=target
click('Recover saved detail batch')
assert(saved['DD2Dumper_v52_detail_progress.json'].exportedCount==1000,'failed recovery')
print('PASS v5.2 detail: 2,152 unique IDs; 3 batches; subclass fields; zero preservation; resume/reorder; reset; failed saves and recovery')
