local script=assert(arg[1]); local saved={} ;local fail_any=false;local fail_manifest=false
local ui_cb, frame_cb, next_click, last_msg, requested_import
local function clone(x)
    if type(x)~='table' then return x end
    local t={};for k,v in pairs(x) do t[k]=clone(v) end;return t
end
json={
 dump_file=function(name,data)
   if fail_any or (fail_manifest and name=='DD2Dumper_item_progress.json') then return false end
   saved[name]=clone(data);return true
 end,
 load_file=function(name) return clone(saved[name]) end,
}
local function has(a,b) return string.find(a,b,1,true)~=nil end
imgui={tree_node=function() return true end,tree_pop=function() end,text=function() end,
 separator=function() end,input_text=function(_,s)
    if requested_import then local x=requested_import;requested_import=nil;return true,x end
    return false,s
 end,
 button=function(title)
   if next_click and has(title,next_click) then next_click=nil; return true end
   return false
 end}
re={on_draw_ui=function(cb) ui_cb=cb end,on_frame=function(cb) frame_cb=cb end}
local function td(n)
 return {get_full_name=function() return n end,get_parent_type=function() return nil end,
 get_fields=function() return {} end,get_methods=function() return {} end}
end
local function obj(t) return {get_type_definition=function() return td(t) end} end
local player=obj('app.Character')
function player:get_field(f) if f=='<Hit>k__BackingField' then return obj('app.HitController') end end
function player:call(m) if m=='get_Hp' then return 110 elseif m=='get_OriginalMaxHp' then return 160 elseif m=='get_ReducedMaxHp' then return 140 end end
local cm=obj('app.CharacterManager')
function cm:call(m) if m=='get_ManualPlayer' or m=='get_ManualPlayerHuman' then return player end end
local pm=obj('app.PawnManager')
local party=obj('System.Collections.Generic.List`1<app.Character>')
function party:call(m,...)
 if m=='get_Count' then return 1 end
 if has(m,'get_Item') then return player end
end
function pm:call(m) if m=='get_PawnCharacterList' then return party end end
local items={}
for i=1,3502 do items[i]={key=i,value={_Id=i,_BuyPrice=100+i,_Weight=i%5}} end
local reordered=0
local dict=obj('System.Collections.Generic.Dictionary`2<System.Int32,app.ItemCommonParam>')
function dict:call(m)
 if m=='get_Count' then return #items end
 if m=='GetEnumerator' then
    reordered=reordered+1
    local order={}
    -- rotate enumeration order on each new scan; never assume stable offsets
    for i=1,#items do order[i]=items[(i-1+reordered*271)%#items+1] end
    local n=0
    return {call=function(self,x)
      if x=='MoveNext' then n=n+1;return n<=#items end
      if x=='get_Current' then return {get_field=function(_,f) return order[n] and order[n][f] end} end
      if x=='Dispose' then return true end
    end}
 end
end
local im=obj('app.ItemManager')
function im:get_field(f) if f=='_ItemDataDict' then return dict end end
sdk={
 find_type_definition=function(name) return td(name) end,
 get_managed_singleton=function(name)
    if name=='app.ItemManager' then return im end
    if name=='app.PawnManager' then return pm end
    if name=='app.CharacterManager' then return cm end
 end,
 get_tdb_version=function() return 83 end
}
local function reload() dofile(script) end
local function click(text)
 next_click=text;ui_cb();assert(not next_click,'missing button '..text)
end
local function run_frames()
 for i=1,350 do frame_cb() end
end
local function count_batches()
 local total=0;local batchcount=0;local ids={}
 for name,data in pairs(saved) do
  if data.kind=='item-catalog-batch' then
   batchcount=batchcount+1
   total=total+#data.rows
   for _,r in ipairs(data.rows) do assert(not ids[r.id],'duplicate '..r.id);ids[r.id]=true end
  end
 end
 return total,batchcount,ids
end
saved['DD2Dumper_20261011_213538_002_items.json']={kind='item-catalog-best-effort',captured={tdbVersion=83},rows={}}
for i=1,1500 do saved['DD2Dumper_20261011_213538_002_items.json'].rows[i]={id=i,_Id=i} end
reload()
click('Capture live runtime')
click('Import item dump')
local progress=assert(saved['DD2Dumper_item_progress.json'])
assert(#progress.exportedIds==1500 and progress.batchNumber==0,'import progress')
click('Import item dump')
assert(#saved['DD2Dumper_item_progress.json'].exportedIds==1500,'repeat import should dedup')
click('Export NEXT item batch')
run_frames()
progress=assert(saved['DD2Dumper_item_progress.json'])
assert(#progress.exportedIds==3000 and progress.batchNumber==1,'first batch checkpoint')
assert(count_batches()==1500,'first batch rows')
reload() -- emulate game restart, dictionary order changes on next GetEnumerator
click('Export NEXT item batch')
run_frames()
progress=assert(saved['DD2Dumper_item_progress.json'])
assert(#progress.exportedIds==3502 and progress.batchNumber==2 and progress.completed==true,'restarted scan should complete')
local total,batches,ids=count_batches()
assert(total==2002 and batches==2,'batch totals incorrect '..total..' / '..batches)
for i=1,1500 do assert(not ids[i],'imported ID exported again '..i) end
for i=1501,3502 do assert(ids[i],'missing ID '..i) end
click('Export NEXT item batch')
assert(count_batches()==2002,'completed catalog should not write a third batch')
-- explicitly reset; old files retained
click('Reset catalog index')
click('CONFIRM start fresh catalog')
assert(#saved['DD2Dumper_item_progress.json'].exportedIds==0,'reset did not reset progress')
-- test failed batch save leaves checkpoint untouched
fail_any=true
click('Export NEXT item batch')
run_frames()
fail_any=false
assert(#saved['DD2Dumper_item_progress.json'].exportedIds==0,'failed save advanced checkpoint')
-- failed manifest after successful batch: can import batch to recover
fail_manifest=true
click('Export NEXT item batch')
run_frames()
fail_manifest=false
assert(#saved['DD2Dumper_item_progress.json'].exportedIds==0,'manifest failure advanced stored checkpoint')
local lastbatch
for path,d in pairs(saved) do if d.kind=='item-catalog-batch' and d.runId==saved['DD2Dumper_item_progress.json'].runId then lastbatch=path end end
assert(lastbatch,'failed manifest recovery batch must be saved')
requested_import=lastbatch
click('Import item dump')
assert(#saved['DD2Dumper_item_progress.json'].exportedIds==1500,'failed manifest batch recovery did not import')
assert(saved['DD2Dumper_item_progress.json'].batchNumber==1,'recovery should advance batch number')
-- source profiles API still available
click('Profile all known type groups')
run_frames()
local seen=false
for path,d in pairs(saved) do if d.kind=='profiles' and d.count>=158 then seen=true end end
assert(seen,'type profile regression')
print('PASS v5.1: legacy import, ID dedupe, rotating order, restart resume, end-of-dict, reset, failed batch/manifest saves, type profiling')
