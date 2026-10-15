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
local colors={};local rendered={};local rectangles={}
local draw={filled_rect=function(x,y,w,h,col) rectangles[#rectangles+1]={x=x,y=y,w=w,h=h} end,text=function(s) rendered[#rendered+1]=s end,filled_quad=function() end}
local imgui={get_display_size=function() return {x=1400,y=900} end}
local pawnState={value=600,character=pawn,name='Gwendolyn'}
local config={Enabled=true,ShowFloatingBar=true,ShowMainPawnFloatingBar=true,ShowPawnChangeToast=true,PawnHudSeconds=3, DialogueMinSeconds=4, HudXPercent=50, HudYPercent=12,CapValue=199,UnlockedNPCs={}}
local PAWN_FAVORABILITY_MAX=1000;local PAWN_BLUSH_THRESHOLD=620
local function safePawnAccess(fn) local ok,res=pcall(fn);if ok then return res end end
local function getCharacterManager()return manager end
local function getNPCManager()return npcManager end
local function getPermanentID(id)return tostring(id)end
local function translateCharacterName(id)return id==3 and 'Test NPC' or '?'end
local hearts = {}
local function drawHeart(x, y, size, tint)
 hearts[#hearts+1]={x=x,y=y,size=size,tint=tint}
end
local function clear()for i=#rendered,1,-1 do rendered[i]=nil end;for i=#rectangles,1,-1 do rectangles[i]=nil end end
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
local bi=assert(script:find('-- BEGIN CONTEXTUAL HUD v2.6',1,true),'v2.5 block missing')
local ei=assert(script:find('-- END CONTEXTUAL HUD v2.6',bi+1,true),'v2.5 end missing')
local content=script:sub(bi,ei+#'-- END CONTEXTUAL HUD v2.6'-1)
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
assert(#hearts==1 and hearts[1].tint==0xFF92C9D6,'cyan heart restored')
assert(table.concat(rendered):find('BOND',1,true),'pawn status restored')
-- During conversation, switch to NPC and display NPC using exact same renderer
registered[method]({[3]=npc,[4]=player});clear();drawGlobalAffinityHUD();assert(table.concat(rendered):find('NPC Test NPC',1,true));assert(not table.concat(rendered):find('PAWN Gwendolyn',1,true))
assert(hearts[#hearts].tint==0xFFBBB9A9,'NPC locked affinity color retained')
assert(table.concat(rendered):find('CAPPED',1,true),'NPC lock status retained')
-- A short conversation must stay visible for at least four seconds.
clear();talking=false;drawGlobalAffinityHUD();assert(table.concat(rendered):find('NPC Test NPC',1,true),'short NPC line survives temporary IsPlayerTalking=false')
now=109;clear();drawGlobalAffinityHUD();assert(#rendered==0,'short conversation duration expired')
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
-- Exact x-coordinate at 1400px width defaults to centered 50%, y=12%.
config.ShowMainPawnFloatingBar=true
now=110;talking=false
registered[method]({[3]=player,[4]=npc});clear();drawGlobalAffinityHUD()
assert(#rectangles>0,'event-only generic NPC conversation must show')
assert(rectangles[1].x >= 590 and rectangles[1].x <= 620,'HUD center x was not calculated: '..tostring(rectangles[1].x))
assert(rectangles[1].y >= 70 and rectangles[1].y <= 100,'HUD top y was not calculated: '..tostring(rectangles[1].y))
now=113;clear();drawGlobalAffinityHUD();assert(#rendered>0,'event-only notification should remain for 4 seconds')
now=114;clear();drawGlobalAffinityHUD();assert(#rendered==0,'event-only notification must expire')
-- The HUD can be moved without altering per-target colors or event rules.
config.HudXPercent=25;config.HudYPercent=30
now=120;registered[method]({[3]=player,[4]=npc});clear();drawGlobalAffinityHUD()
assert(rectangles[1].x > 230 and rectangles[1].x < 280,'HUD X position slider')
assert(rectangles[1].y > 225 and rectangles[1].y < 250,'HUD Y position slider')
-- Mere nearby prompts, without talking or an Arisen dialogue event, stay hidden.
now=125;clear();drawGlobalAffinityHUD();assert(#rendered==0,'prompt proximity alone cannot trigger HUD')
print('PASS: contextual HUD v2.6 classic heart, talk/grace expiry, color, placement, no ghost prompt')
