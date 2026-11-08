local ns, passed = {}, 0
local function eq(a,b) assert(a == b, tostring(a) .. ' ~= ' .. tostring(b)) end
local function test(name, fn)
    local ok, err = pcall(fn)
    assert(ok, name .. ': ' .. tostring(err))
    passed = passed + 1
end
assert(loadfile('Ranking.lua'))('SnackBar', ns)
test('normal food and drink amounts', function()
    local h,m = ns.Recovery({'Use: Restores 2,148 health over 30 sec.'},1000,2000)
    eq(h,2148); eq(m,0)
    h,m = ns.Recovery({'Restores 4200 mana over 30 sec.'},1000,2000)
    eq(h,0); eq(m,4200)
end)
test('combined food drink', function()
    local h,m = ns.Recovery({'Restores 7500 health and 7200 mana over 30 sec.'},1000,2000)
    eq(h,7500); eq(m,7200)
end)
test('percent of maximum each second', function()
    local h,m = ns.Recovery({'Restores 4% of your health and mana every 1 sec for 20 sec.'},1000,2000)
    eq(h,800); eq(m,1600)
end)
test('separate percentages and per second wording', function()
    local h,m = ns.Recovery({'Restores 2% health and 3% mana per second for 10 sec.'},1000,2000)
    eq(h,200); eq(m,600)
end)
test('well fed bonus not counted as restoration', function()
    local h,m = ns.Recovery({'Restores 61 health over 18 sec.','Increases health by 10000.'},1000,2000)
    eq(h,61); eq(m,0)
end)
test('unknown descriptions do not guess', function()
    local h,m = ns.Recovery({'Something delicious.','Requires Level 60'},1000,2000)
    eq(h,0); eq(m,0)
end)
test('ranking and exhausted stacks', function()
    local a={id=1,count=1,health=61,mana=0}
    local b={id=2,count=1,health=874,mana=0}
    eq(ns.Best({a,b},'health'),b)
    b.count=0; eq(ns.Best({a,b},'health'),a)
    eq(ns.Best({a,b},'mana'),nil)
end)
test('ties deterministic', function()
    eq(ns.Best({{id=3,count=5,health=61},{id=2,count=1,health=61}},'health').id,2)
end)

local state = {combat=false, level=30, health=1000, mana=2000, bags={}, items={}, timers={}, messages={}, requests={}, attributes=0}
local methods = {}
local function widget(name,parent)
    local w=setmetatable({scripts={}, attrs={}, name=name, parent=parent, shown=true}, {__index=methods})
    if name then _G[name]=w end
    return w
end
for _, method in ipairs({'SetBackdrop','SetBackdropColor','SetBackdropBorderColor','SetJustifyH','SetWordWrap','SetWidth','SetHeight','SetFrameStrata','EnableMouse','RegisterForDrag','SetHighlightTexture','SetFontObject','HighlightText','SetOwner','AddLine','SetHyperlink','SetDesaturated','SetMovable','SetClampedToScreen'}) do methods[method]=function() end end
function methods:SetSize(w,h) self.w=w;self.h=h end
function methods:SetPoint(...) self.point={...} end
function methods:GetPoint() return 'CENTER',UIParent,'CENTER',5,6 end
function methods:ClearAllPoints() self.point=nil end
function methods:StartMoving() assert(not state.combat); self.moving=true end
function methods:StopMovingOrSizing() assert(not state.combat); self.moving=false end
function methods:SetScript(k,f) self.scripts[k]=f end
function methods:HookScript(k,f) local old=self.scripts[k]; self.scripts[k]=function(...) if old then old(...) end; f(...) end end
function methods:RegisterEvent(e) self[e]=true end
function methods:SetText(s) self.text=s end
function methods:SetTexture(s) self.texture=s end
function methods:CreateFontString() return widget(nil,self) end
function methods:CreateTexture() return widget(nil,self) end
function methods:RegisterForClicks(...) self.clicks={...} end
function methods:SetAttribute(k,v) assert(not state.combat,'secure attribute changed in combat'); self.attrs[k]=v; state.attributes=state.attributes+1 end
function methods:Show() assert(not state.combat,'show in combat'); self.shown=true end
function methods:Hide() assert(not state.combat,'hide in combat'); self.shown=false end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
UIParent=widget()
GameTooltip=widget()
DEFAULT_CHAT_FRAME={AddMessage=function(_,s) state.messages[#state.messages+1]=s end}
SlashCmdList={}
NUM_BAG_SLOTS=4
function CreateFrame(_,name,parent,template) local w=widget(name,parent); w.template=template; return w end
function InCombatLockdown() return state.combat end
function UnitLevel() return state.level end
function UnitHealthMax() return state.health end
function UnitPowerMax() return state.mana end
C_Timer={After=function(_,fn) state.timers[#state.timers+1]=fn end}
C_Item={
    GetItemInfo=function(id)
        local i=state.items[id]
        if not i or i.uncached then return end
        return i.name,'item:'..id,1,1,i.level or 1,'Consumable','Food',20,'',123,1,i.class or 0,i.subclass or 5
    end,
    RequestLoadItemDataByID=function(id) state.requests[id]=true end,
    IsUsableItem=function(id) return not state.items[id].unusable end,
}
C_Container={
    GetContainerNumSlots=function(bag) return #(state.bags[bag] or {}) end,
    GetContainerItemInfo=function(bag,slot) return state.bags[bag][slot] end,
}
C_TooltipInfo={GetBagItem=function(bag,slot)
    local i=state.items[state.bags[bag][slot].itemID]
    if i.noTooltip then return end
    return {lines={{leftText=i.description}}}
end}
local function add(id,amount,description,extra)
    local item=extra or {}; item.name='Food '..id; item.description=description
    state.items[id]=item; state.bags[0]=state.bags[0] or {}
    table.insert(state.bags[0],{itemID=id,stackCount=amount})
end
local function drain()
    for n=1,20 do
        if #state.timers==0 then return end
        local queue=state.timers; state.timers={}; for _,f in ipairs(queue) do f() end
    end
    error('unbounded timers')
end
assert(loadfile('Recoup.lua'))('SnackBar',ns)
add(1,4,'Restores 61 health over 18 sec.')
add(2,2,'Restores 874 health over 27 sec.')
add(3,5,'Restores 1200 mana over 30 sec.')
add(4,2,'Restores 10000 health over 30 sec.',{level=60})
add(5,2,'Restores 10000 health.',{subclass=1})
add(6,2,'Restores 10000 health over 30 sec.',{unusable=true})
test('scans usable carried foods only',function()
    local list=ns.Scan(); eq(#list,3)
    eq(ns.Best(list,'health').id,2); eq(ns.Best(list,'mana').id,3)
end)
test('initializes secure click buttons without consuming',function()
    SnackBarDB={position={point='CENTER',relPoint='CENTER',x=12,y=34},locked=true}
    local _,_,events=ns.Internals(); events.scripts.OnEvent(events,'PLAYER_LOGIN')
    local frame,buttons=ns.Internals()
    eq(buttons.health.attrs.type1,'item'); eq(buttons.health.attrs.item,'item:2')
    eq(buttons.mana.attrs.item,'item:3'); eq(buttons.health.attrs.useOnKeyDown,false)
    eq(buttons.health.scripts.OnClick,nil)
    assert(buttons.health.template:find('SecureActionButtonTemplate',1,true))
    eq(RecoupDB.position.x,12); eq(RecoupDB.locked,true)
    RecoupDB.position.x=15; eq(SnackBarDB.position.x,12)
    eq(buttons.bandage.attrs.unit,'player')
end)
test('bandages rank separately from food and target the player',function()
    add(20,5,'Use: Heals 400 damage over 8 sec.',{subclass=7})
    add(21,2,'Use: Heals 2,000 damage over 8 sec.',{subclass=7})
    add(22,1,'Use: Heals 5000 damage over 8 sec.',{subclass=7,unusable=true})
    ns.Refresh(); local _,buttons=ns.Internals()
    eq(buttons.bandage.attrs.item,'item:21')
    eq(buttons.bandage.item.bandage,2000)
    eq(buttons.health.attrs.item,'item:2')
    eq(buttons.mana.attrs.item,'item:3')
    for _,slot in ipairs(state.bags[0]) do if slot.itemID==21 then slot.stackCount=0 end end
    ns.Refresh(); eq(buttons.bandage.attrs.item,'item:20')
end)
test('aggregates duplicate stacks and falls back when depleted',function()
    state.bags[1]={{itemID=2,stackCount=3}}
    ns.Refresh(); local _,buttons=ns.Internals(); eq(buttons.health.item.count,5)
    state.bags[1]={}; state.bags[0][2].stackCount=0
    ns.Refresh(); eq(buttons.health.attrs.item,'item:1')
end)
test('reselects after bag events',function()
    state.bags[0][2].stackCount=1
    local _,buttons,events=ns.Internals()
    events.scripts.OnEvent(events,'BAG_UPDATE_DELAYED'); drain()
    eq(buttons.health.attrs.item,'item:2')
end)
test('defers protected changes during combat',function()
    state.combat=true; local count=state.attributes
    state.bags[0][2].stackCount=0
    ns.Refresh(); SlashCmdList.SNACKBAR('reset'); eq(state.attributes,count)
    state.combat=false; local _,buttons,events=ns.Internals()
    events.scripts.OnEvent(events,'PLAYER_REGEN_ENABLED')
    eq(buttons.health.attrs.item,'item:1')
end)
test('uncached data retries without unlimited requests',function()
    add(7,2,'Restores 2000 health over 30 sec.',{uncached=true})
    ns.Refresh(); drain(); eq(state.requests[7],true)
    state.items[7].uncached=false
    local _,buttons,events=ns.Internals()
    events.scripts.OnEvent(events,'ITEM_DATA_LOAD_RESULT',7); drain()
    eq(buttons.health.attrs.item,'item:7')
end)
test('empty bags clear secure actions',function()
    state.bags={}; ns.Refresh()
    local _,buttons=ns.Internals()
    eq(buttons.health.attrs.item,nil); eq(buttons.mana.attrs.item,nil)
    eq(buttons.bandage.attrs.item,nil)
end)
test('visibility and position controls',function()
    SlashCmdList.SNACKBAR(''); eq(RecoupDB.hidden,true)
    SlashCmdList.SNACKBAR('reset'); eq(RecoupDB.hidden,false)
    SlashCmdList.SNACKBAR('lock'); eq(RecoupDB.locked,true)
    SlashCmdList.SNACKBAR('unlock'); eq(RecoupDB.locked,false)
    for _,s in ipairs(state.messages) do assert(not s:find('Error:',1,true),s) end
end)
test('dedicated left-mouse move handle saves and locks position',function()
    SlashCmdList.SNACKBAR('move')
    local frame=ns.Internals()
    eq(SnackBarMoveHandle.shown,true)
    SnackBarMoveHandle.scripts.OnMouseDown(SnackBarMoveHandle,'LeftButton')
    eq(frame.moving,true)
    SnackBarMoveHandle.scripts.OnMouseUp(SnackBarMoveHandle,'LeftButton')
    eq(frame.moving,false); eq(RecoupDB.position.x,5); eq(RecoupDB.position.relPoint,'CENTER')
    SlashCmdList.SNACKBAR('lock')
    eq(SnackBarMoveHandle.shown,false); eq(RecoupDB.locked,true)
end)
print(passed .. ' tests passed')
