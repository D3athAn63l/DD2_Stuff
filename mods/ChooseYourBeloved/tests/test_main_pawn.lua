-- Run from this file's directory using the bundled run_lua.py launcher.
-- Exercises the integrated BelovedCap.lua against fake REFramework managers.
local dir = debug.getinfo(1, 'S').source:sub(2):match('^(.*)[/\\]') or '.'
local target = dir .. '/../reframework/autorun/BelovedCap.lua'
local draws, messages = {}, {}
local frames, menus, resets = {}, {}, {}
local rating = 609
local livePawn = true
local writes = 0
local context = {
    get_FavorabilityRating = function() return rating end,
    set_field = function() writes = writes + 1; error('pawn rating should be read-only') end,
}
local playerTransform = {get_Position=function()return {x=0,y=0,z=0}end}
local head = {get_Position=function()return {x=1,y=2,z=0}end}
local pawnTransform = {
    get_Position=function()return {x=1,y=0,z=0}end,
    getJointByName=function(_,name) return name=='Head_0' and head or nil end,
}
local function gameObject(transform)
    return {get_Transform=function()return transform end}
end
local player = {
    get_CharaID=function()return 10 end,
    get_GameObject=function()return gameObject(playerTransform)end,
    get_address=function()return 12345 end,
}
local pawnCharacter = {
    get_CharaID=function()return 20 end,
    get_GameObject=function()return gameObject(pawnTransform)end,
}
local pawn = {MainPawnDataContext=context,get_CachedCharacter=function()return pawnCharacter end}
local pawnManager = {get_MainPawn=function()return livePawn and pawn or nil end}
local charManager = {get_ManualPlayer=function()return player end}
local npcManager = {NPCHolderDic={get_Length=function()return 0 end}}

sdk={
    get_managed_singleton=function(name)
        if name=='app.PawnManager' then return pawnManager end
        if name=='app.CharacterManager' then return charManager end
        if name=='app.NPCManager' then return npcManager end
    end,
    find_type_definition=function(name)
        if name=='app.GUIBase' then
            return {get_method=function(_,signature)
                if signature=='getName(app.CharacterID)' then
                    return {call=function(_,_,id) return id==20 and 'Johanne' or 'Unknown' end}
                end
            end}
        end
    end,
}
json={dump_file=function()return true end,load_file=function()return {Enabled=false,ShowMainPawnFloatingBar=true} end}
re={
    on_frame=function(f) frames[#frames+1]=f end,
    on_draw_ui=function(f) menus[#menus+1]=f end,
    on_script_reset=function(f) resets[#resets+1]=f end,
}
reframework={get_delta_time=function()return 0.25 end}
imgui={
    tree_node=function(name) return name=='BelovedCap' or name=='Main Pawn Affinity (Read-only)' end,
    checkbox=function(_,value)return false,value end,
    slider_int=function(_,value)return false,value end,
    is_item_hovered=function()return false end,
    get_display_size=function()return {x=1920,y=1080} end,
    spacing=function()end,separator=function()end,tree_pop=function()end,
    push_style_color=function()end,pop_style_color=function()end,
    button=function()return false end,
    text=function(value)messages[#messages+1]=tostring(value)end,
    text_colored=function(value)messages[#messages+1]=tostring(value)end,
}
draw={
    world_to_screen=function()return {x=960,y=540}end,
    filled_rect=function()end,filled_quad=function()end,
    text=function(value)draws[#draws+1]=tostring(value)end,
}

dofile(target)
assert(#frames>0 and #menus>0 and #resets>0,'callbacks installed')
local function messageContains(query)
    for _,s in ipairs(messages)do if s:find(query,1,true)then return true end end
    return false
end
local function drawContains(query)
    for _,s in ipairs(draws)do if s:find(query,1,true)then return true end end
    return false
end
frames[1](); menus[1]()
assert(messageContains('Johanne: 609 / 1000'),'main pawn live menu value with cap disabled')
assert(drawContains('MAIN PAWN 609 / 1000'),'floating pawn bar with cap disabled')
rating=624;draws={};messages={};frames[1]();menus[1]()
assert(messageContains('Johanne: 624 / 1000'),'value changes reflected')
assert(messageContains('Blushing threshold reached'),'threshold label')
livePawn=false;messages={};draws={};frames[1]();menus[1]()
assert(messageContains('Main Pawn affinity unavailable'),'no stale values after unload')
assert(#draws==0,'no pawn overlay when unloaded')
assert(writes==0,'read-only Main Pawn behavior')
resets[1]()
print('PASS: integrated read-only Main Pawn menu/HUD + load/unload and cap-independent display')
