-- Mock tests for v3.0.1 opt-in native-name fallback (Lua 5.4).
-- python mods/ChooseYourBeloved/tests/run_lua.py mods/ChooseYourBeloved/tests/test_ambient_name_fallback.lua
local dir=debug.getinfo(1,"S").source:sub(2):match("^(.*)[/\\]") or "."
local f=assert(io.open(dir.."/../reframework/autorun/BelovedCap.lua","r"))
local source=f:read("*a");f:close()
assert(source:find("NativeAmbientAffinity = false",1,true),"must default OFF")
assert(source:find("internalNameDepth = internalNameDepth + 1",1,true),"internal name protection absent")
assert(not source:find("drawGlobalAffinityHUD",1,true),"floating HUD must not return")

local function extract(first,last)
    local a=assert(source:find(first,1,true),"missing: "..first)
    local b=assert(source:find(last,a+#first,true),"missing: "..last)
    return source:sub(a,b-1)
end
local player={get_CharaID=function()return 10 end}
local pawn={get_CharaID=function()return 20 end}
local sentiment={Value=187}
local holder={getSentimentInfo=function(_,id,create)
    assert(id==10 and create==false)
    return sentiment
end}
local nManager={getNPCHolder=function(_,id)
    return id==30 and holder or nil
end}
local config={NativeAmbientAffinity=true,NativePromptEnabled=true,NativeDialogueAffinity=true}
local dialogue={blocked=false,depth=0}
local env={
    config=config,nativeDialogue=dialogue,internalNameDepth=0,
    pawnState={character=pawn,value=1000},
    characterKey=function(ch)return tostring(ch:get_CharaID())end,
    getPermanentID=tostring,
    getCharacterManager=function()return {get_ManualPlayer=function()return player end}end,
    getNPCManager=function()return nManager end,
    safePawnAccess=function(fn)local ok,x=pcall(fn);if ok then return x end end,
}
setmetatable(env,{__index=_G})
local part=extract("local function ambientAffinityForID(charaID)","local function currentDialogueSpeakerForID(charaID)")
local get=assert(load(part.."\nreturn ambientAffinityForID","ambient-test","t",env))()
assert(get(20)==1000,"Main Pawn direct favorability")
assert(get(30)==187,"NPC direct sentiment")
assert(get(10)==nil,"player not annotated")
assert(get(99)==nil,"unknown NPC not annotated")
config.NativeAmbientAffinity=false;assert(get(20)==nil,"explicit opt-out")
config.NativeAmbientAffinity=true
config.NativePromptEnabled=false;assert(get(20)==nil,"native prompt toggle gates fallback")
config.NativePromptEnabled=true
config.NativeDialogueAffinity=false;assert(get(30)==nil,"speaker toggle gates fallback")
config.NativeDialogueAffinity=true
dialogue.blocked=true;assert(get(30)==nil,"blocking menu guard")
dialogue.blocked=false;dialogue.depth=1;assert(get(30)==nil,"reentrant hook guard")
dialogue.depth=0;env.internalNameDepth=1;assert(get(30)==nil,"internal getName guard")
env.internalNameDepth=0;assert(get(30)==187,"restored after guard")
sentiment.Value=206;assert(get(30)==206,"uses live affinity, not cached guesses")
print("PASS: ambient native affinity ID routing, read-only pawn/NPC, opt-outs, guards")
