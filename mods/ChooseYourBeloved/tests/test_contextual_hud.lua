local now = 100
os.time = function() return now end
local player = { id = 1 }
local pawn = { id = 2 }
local npc = { id = 3 }
for _, obj in ipairs({player,pawn,npc}) do function obj:get_CharaID() return self.id end end
local manager = { get_ManualPlayer = function() return player end }
local npcHolder = { getSentimentInfo=function(_, pid, _) assert(pid==1); return {Value=195} end }
local npcManager = { getNPCHolder=function(_,id) return id==3 and npcHolder or nil end }
local talking = false
local trackerFns={}
local method = {get_name=function() return 'selectTalkEvent' end}
local disp = {get_name=function() return 'reqDisp' end}
local registered={}
local sdk = {
 get_managed_singleton=function(name)
    if name=='app.InteractManager' then return {get_field=function() return talking end} end
 end,
 find_type_definition=function(name)
    if name=='app.TalkEventManager' then return {get_methods=function() return {method} end} end
    if name=='app.ui021301' then return {get_method=function() return disp end} end
    if name=='app.Character' then return {get_runtime_type=function() return 'char' end} end
 end,
 to_managed_object=function(x) return x end,
 hook=function(m,pre,post) registered[m]=pre end
}
local colors={};local rendered={}
local draw={filled_rect=function() end,text=function(s) rendered[#rendered+1]=s end,filled_quad=function() end}
local imgui={get_display_size=function() return {x=1400,y=900} end}
local pawnState={value=600,character=pawn,name='Gwendolyn'}
local config={Enabled=true,ShowFloatingBar=true,ShowMainPawnFloatingBar=true,ShowPawnChangeToast=true,PawnHudSeconds=3,CapValue=199,UnlockedNPCs={}}
local PAWN_FAVORABILITY_MAX=1000;local PAWN_BLUSH_THRESHOLD=620
local function safePawnAccess(fn) local ok,res=pcall(fn);if ok then return res end end
local function getCharacterManager()return manager end
local function getNPCManager()return npcManager end
local function getPermanentID(id)return tostring(id)end
local function translateCharacterName(id)return id==3 and 'Test NPC' or '?'end
local function drawHeart()end
local function clear()for i=#rendered,1,-1 do rendered[i]=nil end end
local env = {
 sdk=sdk, draw=draw, imgui=imgui, pawnState=pawnState, config=config,
 PAWN_FAVORABILITY_MAX=PAWN_FAVORABILITY_MAX, PAWN_BLUSH_THRESHOLD=PAWN_BLUSH_THRESHOLD,
 safePawnAccess=safePawnAccess, getCharacterManager=getCharacterManager,
 getNPCManager=getNPCManager, getPermanentID=getPermanentID,
 translateCharacterName=translateCharacterName, drawHeart=drawHeart
}
setmetatable(env,{__index=_G})
local dir = debug.getinfo(1,'S').source:sub(2):match('^(.*)[/\\]') or '.'
local path = dir .. '/../reframework/autorun/BelovedCap.lua'
local fp=assert(io.open(path,'r'));local script=fp:read('*a');fp:close()
local beginTag='-- BEGIN CONTEXTUAL HUD v2.4'
local endTag='-- END CONTEXTUAL HUD v2.4'
local bi=assert(script:find(beginTag,1,true),'contextual extension missing')
local ei=assert(script:find(endTag,bi+1,true),'contextual extension end missing')
local content=script:sub(bi,ei+#endTag-1)
content=content..'\nreturn {pawnHud=pawnHud,talkTracker=talkTracker,trackMainPawnChanges=trackMainPawnChanges,drawGlobalAffinityHUD=drawGlobalAffinityHUD,drawPawnChangeToast=drawPawnChangeToast}\n'
local f=assert(load(content,'mock contextual', 't', env))
local api=f()
local pawnHud,talkTracker,trackMainPawnChanges,drawGlobalAffinityHUD,drawPawnChangeToast=api.pawnHud,api.talkTracker,api.trackMainPawnChanges,api.drawGlobalAffinityHUD,api.drawPawnChangeToast

assert(talkTracker.hookStatus=='talk: 1, prompt: yes')
trackMainPawnChanges(); assert(pawnHud.delta==0,'first read must not notify')
pawnState.value=603;trackMainPawnChanges();assert(pawnHud.delta==3)
drawPawnChangeToast(); assert(table.concat(rendered):find('MAIN PAWN  +3',1,true))
clear(); now=104;drawPawnChangeToast();assert(#rendered==0,'toast must expire')
-- Not talking: no global bar even though pawn is nearby
clear();drawGlobalAffinityHUD();assert(#rendered==0)
-- A verified pawn talk event + talking flag displays Main Pawn
registered[method]({[3]=player,[4]=pawn})
talking=true;clear();drawGlobalAffinityHUD();assert(table.concat(rendered):find('PAWN Gwendolyn',1,true));assert(talkTracker.source=='talk event')
-- During conversation, switch to NPC and display NPC using exact same renderer
registered[method]({[3]=npc,[4]=player});clear();drawGlobalAffinityHUD();assert(table.concat(rendered):find('NPC Test NPC',1,true));assert(not table.concat(rendered):find('PAWN Gwendolyn',1,true))
-- On conversation end no HUD; never rely on a fixed talk timer
clear();talking=false;drawGlobalAffinityHUD();assert(#rendered==0);assert(talkTracker.target==nil)
-- Prompt-only fallback also requires actual talking flag
local gameObject={call=function(self,method,arg) assert(method=='getComponent(System.Type)');return npc end}
registered[disp]({[3]=gameObject});clear();drawGlobalAffinityHUD();assert(#rendered==0)
talking=true;clear();drawGlobalAffinityHUD();assert(table.concat(rendered):find('NPC Test NPC',1,true));assert(talkTracker.source=='interaction prompt')
-- Main Pawn never goes through NPC holder
clear();registered[method]({[3]=player,[4]=pawn});drawGlobalAffinityHUD();assert(table.concat(rendered):find('PAWN Gwendolyn',1,true))
-- Disable pawn overlay but keep current NPC available
config.ShowMainPawnFloatingBar=false;clear();drawGlobalAffinityHUD();assert(#rendered==0)
-- No false notification after temporary unload
pawnState.value=nil;trackMainPawnChanges();assert(pawnHud.delta==0)
pawnState.value=650;config.ShowMainPawnFloatingBar=true;trackMainPawnChanges();assert(pawnHud.delta==0)
print('PASS: 12 contextual HUD regressions (conversation gating, NPC/pawn target, toast, expiry, read-only, unload)')
