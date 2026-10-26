-- Bounded, deduplicated merchant-prompt capture regression.
-- python mods/ChooseYourBeloved/tests/run_lua.py mods/ChooseYourBeloved/tests/test_hail_prompt_sampling.lua
local dir = debug.getinfo(1,"S").source:sub(2):match("^(.*)[/\\]") or "."
local file=assert(io.open(dir.."/../reframework/autorun/BelovedCap.lua","r"))
local source=file:read("*a");file:close()
local start=assert(source:find("-- Targeted prompt sampling, replacing",1,true))
local stop=assert(source:find("local function installConversationObservers()",start+1,true))
local segment=source:sub(start,stop-1)
local now=100
local nameCalls=0
local env={
    os={time=function()return now end},
    characterKey=function(actor)return actor.id end,
    translateCharacterName=function(id)nameCalls=nameCalls+1;return "NPC "..tostring(id)end,
    safePawnAccess=function(f)local ok,v=pcall(f);if ok then return v end end
}
setmetatable(env,{__index=_G})
local compiled=assert(load(segment..[[
return {
  state=hailProbe, begin=hailProbeBegin, stop=hailProbeStop, current=hailProbeCurrent,
  target=hailProbeObserveTarget, common=hailProbeObserveCommon, outcome=hailProbeObserveOutcome
}
]],"hail-sampler","t",env))
local h=compiled()
local merchant={id="239",get_CharaID=function()return 239 end}
local regular={id="71",get_CharaID=function()return 71 end}
h.begin("idle")
for i=1,900 do h.target(nil);h.common(nil,{}) end
assert(h.state.active.unresolved==900 and h.state.active.commonCalls==900)
assert(#h.state.active.idOrder==0 and h.state.active.labelWrites==0)
now=112
assert(h.current()==nil and h.state.results.idle.duration==12)
h.begin("talk")
for i=1,480 do h.target(regular);h.common(regular,{});h.outcome(regular,"write") end
assert(#h.state.active.idOrder==1 and nameCalls==1,"repeated frames must not trigger repeated identity lookups")
assert(h.state.active.labelWrites==480)
h.stop()
assert(h.state.results.talk.ids["71"].writes==480)
h.begin("hail")
h.target(merchant);h.common(merchant,{});h.outcome(merchant,"skip")
h.target(nil);h.common(nil,nil)
h.target(merchant);h.common(merchant,{});h.outcome(merchant,"write")
assert(h.state.active.resolved==2 and h.state.active.unresolved==1)
assert(h.state.active.commonWithUI==2 and h.state.active.commonWithTarget==2)
assert(#h.state.active.idOrder==1 and h.state.active.ids["239"].calls==2)
assert(h.state.active.labelWrites==1 and h.state.active.labelSkips==1)
h.stop()
local previous=h.state.results.hail.targetCalls
h.target(merchant)
assert(h.state.results.hail.targetCalls==previous and h.state.active==nil,
    "non-capture frames must not accumulate")
h.begin("hail")
for i=1,25 do
    local actor={id=tostring(i),get_CharaID=function()return i end}
    h.target(actor)
end
assert(#h.state.active.idOrder==12,"cardinality cap")
h.stop()
print("PASS: 12s idle/talk/hail bounded captures, distinct IDs, native writes, zero idle logging and max records")
