-- Extract the actual v2.8 normalization and cap rule from BelovedCap.lua.
-- Run with: python mods/ChooseYourBeloved/tests/run_lua.py mods/ChooseYourBeloved/tests/test_unlock_rules.lua
local dir=debug.getinfo(1,"S").source:sub(2):match("^(.*)[/\\]") or "."
local f=assert(io.open(dir.."/../reframework/autorun/BelovedCap.lua","r"))
local text=f:read("*a");f:close()
local function extract(startMark,endMark)
 local a=assert(text:find(startMark,1,true),startMark)
 local b=assert(text:find(endMark,a+#startMark,true),endMark)
 return text:sub(a,b-1)
end
local cfg={}
local defs={CapValue=199,ManualAffinityChange=50,UnlockedNPCs={},Enabled=true,PreventDecay=true,
 CheatModeEnabled=false,ShowFloatingBar=true,ShowMainPawnFloatingBar=true,ShowPawnChangeToast=true,
 HideDuringGameMenus=true,PawnHudSeconds=5,HudXPercent=50,HudYPercent=12,DialogueMinSeconds=4}
local env={config=cfg,defaultConfig=defs,sessionHighs={}}
setmetatable(env,{__index=_G})
local normalization=extract("local function validateConfig()","local function saveConfig()")
assert(load(normalization.."\nreturn validateConfig","validator","t",env))()()
cfg.UnlockedNPCs={ ["123"]="true",["456"]=1,["789"]=true,["321"]="false",["654"]=0 }
assert(load(normalization.."\nreturn validateConfig","validator","t",env))()()
assert(cfg.UnlockedNPCs["123"]==true and cfg.UnlockedNPCs["456"]==true and cfg.UnlockedNPCs["789"]==true)
assert(cfg.UnlockedNPCs["321"]==nil and cfg.UnlockedNPCs["654"]==nil)
local pred=extract("local function isNPCUnlocked(key)","local function translateCharacterName")
local isUnlocked=assert(load(pred.."\nreturn isNPCUnlocked","predicate","t",env))()
assert(isUnlocked("123") and isUnlocked("456") and isUnlocked("789") and not isUnlocked("321"))
local cap=extract("local function applyCapAndProtection(info, key)","-- Compact, asset-free heart.")
local apply=assert(load(cap.."\nreturn applyCapAndProtection","apply","t",setmetatable({isNPCUnlocked=isUnlocked},{__index=env})))()
local u={Value=245};apply(u,"123");assert(u.Value==245,"an unlocked NPC must not be re-capped to 199")
local l={Value=245};apply(l,"321");assert(l.Value==199,"locked NPC must be clamped")
local rising={Value=199};apply(rising,"123");rising.Value=200;apply(rising,"123")
assert(rising.Value==200,"mod must allow an unlocked NPC to cross 199")
local noLoss={Value=230};apply(noLoss,"123");noLoss.Value=220;apply(noLoss,"123")
assert(noLoss.Value==230,"anti-loss must protect legitimate unlocked gains")
local lockAfter={Value=255};apply(lockAfter,"789");cfg.UnlockedNPCs["789"]=nil;apply(lockAfter,"789")
assert(lockAfter.Value==199,"relocking must restore mod cap")
print("PASS v2.8: saved unlock normalization, HUD/enforcement predicate, unlocked >199, locked clamp, anti-loss and relock")
