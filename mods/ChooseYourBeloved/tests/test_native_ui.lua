-- v3.0 stable native UI / retired-HUD regression (Lua 5.4).
-- python mods/ChooseYourBeloved/tests/run_lua.py mods/ChooseYourBeloved/tests/test_native_ui.lua
local dir=debug.getinfo(1,"S").source:sub(2):match("^(.*)[/\\]") or "."
local f=assert(io.open(dir.."/../reframework/autorun/BelovedCap.lua","r"))
local source=f:read("*a");f:close()
local function has(s) return source:find(s,1,true)~=nil end
assert(has('local modVersion = "3.0.0"'))
assert(has('NativePromptEnabled  = true'))
assert(has('NativeDialogueAffinity = true'))
for _,retired in ipairs({
    "drawGlobalAffinityHUD", "activeTalkTarget", "readGlobalAffinity",
    "drawHeart", "ShowFloatingBar", "ShowMainPawnFloatingBar",
    "HudXPercent", "HudYPercent", "DialogueMinSeconds"
}) do
    -- Configuration migration may mention legacy keys in loaded.* only.
    assert(not has(retired) or source:find("loaded%."..retired),
        "retired HUD symbol not removed: "..retired)
end
local function extract(startMark,endMark)
    local a=assert(source:find(startMark,1,true),"start missing: "..startMark)
    local b=assert(source:find(endMark,a+#startMark,true),"end missing: "..endMark)
    return source:sub(a,b-1)
end
local player={get_CharaID=function()return 1 end}
local pawn={get_CharaID=function()return 2 end}
local npc={get_CharaID=function()return 3 end}
local nativeDialogue={depth=0,blocked=false}
local talkTracker={eventTarget=npc,eventAt=100}
local talking=true
local time=110
local env={
  pawnState={value=1000,character=pawn}, nativeDialogue=nativeDialogue,
  config={NativePromptEnabled=true,NativeDialogueAffinity=true},
  talkTracker=talkTracker,
  safePawnAccess=function(fn)local ok,v=pcall(fn);if ok then return v end end,
  sameHudCharacter=function(a,b)return a==b end,
  getCharacterManager=function()return {get_ManualPlayer=function()return player end}end,
  getNPCManager=function()return {getNPCHolder=function(_,id)
      return id==3 and {getSentimentInfo=function()return {Value=187}end} or nil
  end}end,
  translateCharacterName=function(id)return ({[1]="Arisen",[2]="Dahlia",[3]="The Dragonforged"})[id]end,
  getPermanentID=tostring,
  hudNow=function()return time end,
  sdk={get_managed_singleton=function(_,name)
    return {get_field=function()return talking end}
  end}
}
setmetatable(env,{__index=_G})
local promptBody=extract("local function nativePromptLabel(character)","local function installNativePromptHook()")
local prompt=assert(load(promptBody.."\nreturn nativePromptLabel","prompt","t",env))()
assert(prompt(pawn)=="Dahlia [1000]","pawn native prompt")
assert(prompt(npc)=="The Dragonforged [187]","NPC native prompt")
assert(prompt(player)==nil,"Arisen never gets affinity prompt")
assert(nativeDialogue.depth==0,"internal name lookup guard balanced")
local readBody=extract("local function dialogueSpeakerValue(character)","local function currentDialogueSpeakerForID(")
local speakerValue=assert(load(readBody.."\nreturn dialogueSpeakerValue","speakerValue","t",env))()
assert(speakerValue(pawn)==1000 and speakerValue(npc)==187 and speakerValue(player)==nil)
local whichBody=extract("local function currentDialogueSpeakerForID(charaID)","local function installNativeDialogueNameHook()")
local current=assert(load(whichBody.."\nreturn currentDialogueSpeakerForID","speakerMatcher","t",env))()
assert(current(3)==npc,"matched NPC speaker")
assert(current(2)==nil,"non-speaker ID must not be relabeled")
nativeDialogue.blocked=true;assert(current(3)==nil,"GUI menu suppression")
nativeDialogue.blocked=false;talking=false;assert(current(3)==nil,"not talking")
talking=true;time=225;assert(current(3)==nil,"expired talk-event guard")
print("PASS: stable native labels, Main Pawn isolation, scoped dialogue IDs, GUI guard, retired HUD")
