local AM=SetupSwap
local MAX_SLOTS=144
local function normalSlot(slot) return slot<=120 or slot>=133 end
local function character()
    return tostring(GetRealmName() or '')..'/'..tostring(UnitName('player') or '')
end
local function spec() return GetActiveTalentGroup and GetActiveTalentGroup() or 1 end
function AM:ActionBarContext() return character()..'/'..tostring(spec()) end
local function temporaryBar()
    return (UnitInVehicle and UnitInVehicle('player')) or (HasVehicleActionBar and HasVehicleActionBar())
        or (IsPossessBarVisible and IsPossessBarVisible())
end
local function spellID(index)
    local link=GetSpellLink and GetSpellLink(index,BOOKTYPE_SPELL or 'spell')
    return type(link)=='string' and tonumber(link:match('spell:(%d+)')) or nil
end
local function read(slot)
    local kind,id,subtype=GetActionInfo(slot)
    if not kind then return {kind='empty'} end
    local entry={kind=kind}
    if kind=='spell' then
        entry.name,entry.rank=GetSpellName(id,BOOKTYPE_SPELL or 'spell')
        entry.rank=entry.rank or '';entry.spellID=spellID(id)
        if not entry.name then return {kind='unsupported',detail='Unreadable spell'} end
    elseif kind=='item' then entry.id=id
    elseif kind=='macro' then
        local name,_,body=GetMacroInfo(id)
        entry.name=name;entry.body=body
        entry.characterMacro=id>(MAX_ACCOUNT_MACROS or 36)
        if not entry.name or not entry.body then return {kind='unsupported',detail='Unreadable macro'} end
    elseif kind=='companion' and GetCompanionInfo then
        entry.subtype=subtype
        local _,name,spell=GetCompanionInfo(subtype,id)
        entry.name=name;entry.spellID=spell
        if not name or not spell then return {kind='unsupported',detail='Unreadable companion'} end
    elseif kind=='equipmentset' then entry.name=id
    else return {kind='unsupported',detail=tostring(kind)} end
    return entry
end
function AM:CaptureActionBars()
    if InCombatLockdown() then error('Leave combat before saving action bars') end
    if temporaryBar() then error('Leave the vehicle or possession before saving action bars') end
    if GetCursorInfo() then error('Put down the object on your cursor before saving action bars') end
    local result={version=1,context=self:ActionBarContext(),slots={}}
    for slot=1,MAX_SLOTS do if normalSlot(slot) then result.slots[slot]=read(slot) end end
    return result
end
local kinds={empty=true,spell=true,item=true,macro=true,companion=true,equipmentset=true,unsupported=true}
function AM:ValidateActionBars(value)
    if type(value)~='table' or value.version~=1 or type(value.context)~='string' or type(value.slots)~='table' then error('Invalid action-bar snapshot') end
    for slot=1,MAX_SLOTS do
        if normalSlot(slot) then
            local e=value.slots[slot]
            if type(e)~='table' or not kinds[e.kind] then error('Invalid saved action slot '..slot) end
            if e.kind=='spell' and (type(e.name)~='string' or type(e.rank)~='string') then error('Invalid saved spell') end
            if e.kind=='item' and (type(e.id)~='number' or e.id<1) then error('Invalid saved item') end
            if e.kind=='macro' and (type(e.name)~='string' or type(e.body)~='string' or type(e.characterMacro)~='boolean') then error('Invalid saved macro') end
            if e.kind=='equipmentset' and type(e.name)~='string' then error('Invalid saved equipment set') end
            if e.kind=='companion' and ((e.subtype~='MOUNT' and e.subtype~='CRITTER') or type(e.spellID)~='number') then error('Invalid saved companion') end
        end
    end
end
local function resolve(e)
    if e.kind=='empty' then return true end
    if e.kind=='unsupported' then return nil,'Unsupported action' end
    if e.kind=='spell' then
        local match
        for tab=1,GetNumSpellTabs() do
            local _,_,offset,count=GetSpellTabInfo(tab)
            for index=offset+1,offset+count do
                local name,rank=GetSpellName(index,BOOKTYPE_SPELL or 'spell')
                if (e.spellID and spellID(index)==e.spellID) or (not e.spellID and name==e.name and (rank or '')==e.rank) then
                    if match then return nil,'Ambiguous spell' end
                    match=index
                end
            end
        end
        return match,'Spell not learned'
    elseif e.kind=='item' then
        if GetItemCount(e.id)>0 then return e.id end
        return nil,'Item not in inventory'
    elseif e.kind=='macro' then
        local match
        local start=e.characterMacro and (MAX_ACCOUNT_MACROS or 36)+1 or 1
        local finish=e.characterMacro and (MAX_ACCOUNT_MACROS or 36)+(MAX_CHARACTER_MACROS or 18) or (MAX_ACCOUNT_MACROS or 36)
        for index=start,finish do
            local name,_,body=GetMacroInfo(index)
            if name==e.name and body==e.body then
                if match then return nil,'Ambiguous macro' end
                match=index
            end
        end
        return match,'Macro missing or edited'
    elseif e.kind=='companion' then
        for index=1,GetNumCompanions(e.subtype) do
            local _,_,spell=GetCompanionInfo(e.subtype,index)
            if spell==e.spellID then return index end
        end
        return nil,'Companion unavailable'
    elseif e.kind=='equipmentset' then
        for index=1,GetNumEquipmentSets() do
            if GetEquipmentSetInfo(index)==e.name then return index end
        end
        return nil,'Equipment set unavailable'
    end
end
local function same(a,b)
    if a.kind~=b.kind then return false end
    if a.kind=='empty' then return true end
    if a.kind=='spell' then return a.name==b.name and a.rank==b.rank and (not b.spellID or a.spellID==b.spellID) end
    if a.kind=='item' then return a.id==b.id end
    if a.kind=='macro' then return a.name==b.name and a.body==b.body and a.characterMacro==b.characterMacro end
    if a.kind=='companion' then return a.subtype==b.subtype and a.spellID==b.spellID end
    if a.kind=='equipmentset' then return a.name==b.name end
    return false
end
local function place(slot,e,index)
    if e.kind=='empty' then
        if GetActionInfo(slot) then PickupAction(slot);ClearCursor() end
    else
        if e.kind=='spell' then PickupSpell(index,BOOKTYPE_SPELL or 'spell')
        elseif e.kind=='item' then PickupItem(index)
        elseif e.kind=='macro' then PickupMacro(index)
        elseif e.kind=='companion' then PickupCompanion(e.subtype,index)
        elseif e.kind=='equipmentset' then PickupEquipmentSet(index) end
        if GetCursorInfo()~=e.kind then ClearCursor();error('Could not pick up '..e.kind..' for slot '..slot) end
        PlaceAction(slot);ClearCursor()
    end
    if not same(read(slot),e) then error('Client did not restore slot '..slot) end
end
function AM:ApplyActionBars(value)
    self:ValidateActionBars(value)
    if value.context~=self:ActionBarContext() then error('Action bars belong to another character or talent spec') end
    local before=self:CaptureActionBars()
    local plan,skipped={},{}
    -- Resolve targets and rollback actions before making any changes. Missing
    -- abilities/macros/items leave their destination slots untouched.
    for slot=1,MAX_SLOTS do
        if normalSlot(slot) and not same(before.slots[slot],value.slots[slot]) then
            local e=value.slots[slot]
            local target,reason=resolve(e)
            local previous,previousReason=resolve(before.slots[slot])
            if target and previous then
                plan[#plan+1]={slot=slot,entry=e,index=target,previous=before.slots[slot],previousIndex=previous}
            else skipped[#skipped+1]='Slot '..slot..': '..tostring(not target and reason or ('Current action cannot be backed up: '..tostring(previousReason))) end
        end
    end
    local attempted={}
    local ok,err=pcall(function()
        for _,item in ipairs(plan) do
            attempted[#attempted+1]=item
            place(item.slot,item.entry,item.index)
        end
    end)
    if not ok then
        ClearCursor()
        local failures={}
        for index=#attempted,1,-1 do
            local item=attempted[index]
            local restored,why=pcall(place,item.slot,item.previous,item.previousIndex)
            if not restored then failures[#failures+1]=tostring(why) end
        end
        error(tostring(err)..(#failures>0 and ('; rollback errors: '..table.concat(failures,'; ')) or '; prior bars restored'))
    end
    return #plan,skipped
end
function AM:SavedActionBars(snapshot)
    if type(snapshot)~='table' or type(snapshot.actionBars)~='table' then return nil end
    return snapshot.actionBars[self:ActionBarContext()]
end
local runner=CreateFrame('Frame')
local function update(frame,delta)
    if not frame.ready or not AM.db then return end
    local pending=AM.db.pendingActionBars
    if not pending then frame:SetScript('OnUpdate',nil);return end
    if pending.value.context~=AM:ActionBarContext() then
        AM.db.pendingActionBars=nil;frame:SetScript('OnUpdate',nil)
        AM:Print('Action-bar restore canceled: character or talent spec changed.');return
    end
    if InCombatLockdown() or temporaryBar() or GetCursorInfo() or AM.db.pendingSettings or AM.followupReload or AM.db.pendingBindings then return end
    frame.elapsed=(frame.elapsed or 0)+delta
    if frame.elapsed<1 then return end
    AM.db.pendingActionBars=nil;frame:SetScript('OnUpdate',nil)
    AM.operationContext='Restore action bars for '..tostring(pending.name or 'backup')
    local ok,count,skipped=pcall(AM.ApplyActionBars,AM,pending.value)
    AM.operationContext=nil
    AM.db.lastActionBarRestore={name=pending.name,ok=ok,count=ok and count or nil,skipped=ok and skipped or nil,error=not ok and tostring(count) or nil}
    if not ok then AM:Print('Action-bar restore stopped: '..tostring(count)..'. Details: /ss log')
    elseif #skipped>0 then AM:Print('Action bars restored with '..#skipped..' unchanged slots. Details: /ss log') end
end
function AM:StageActionBars(snapshot,name)
    local value=self:SavedActionBars(snapshot)
    if not value then return end -- Older profiles/unsaved characters keep bars.
    self:ValidateActionBars(value)
    self.db.pendingActionBars={value=self:CopySettings(value),name=name}
    runner.elapsed=0;runner:SetScript('OnUpdate',update)
end
runner:RegisterEvent('PLAYER_LOGIN')
runner:SetScript('OnEvent',function(frame)
    frame.ready=true;frame.elapsed=0;frame:SetScript('OnUpdate',update)
end)
