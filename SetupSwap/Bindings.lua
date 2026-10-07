local AM=SetupSwap
-- Explicit profile restores should save through the client function available
-- before startup addons wrap SaveBindings (ConsolePort's calibration warning).
local saveBindings=SetupSwapEarlyLoader and SetupSwapEarlyLoader.saveBindings or SaveBindings
local function identity()
    return tostring(GetRealmName and GetRealmName() or '')..'/'..tostring(UnitName and UnitName('player') or '')
end
function AM:ValidateBindings(snapshot)
    if type(snapshot)~='table' or snapshot.version~=1 or type(snapshot.keys)~='table' then error('Invalid keybindings snapshot') end
    for key,command in pairs(snapshot.keys) do
        if type(key)~='string' or key=='' or type(command)~='string' or command=='' then error('Invalid saved keybinding') end
    end
end
function AM:CaptureBindings()
    if not GetNumBindings or not GetBinding then return nil end
    local snapshot={version=1,keys={},sourceSet=GetCurrentBindingSet and GetCurrentBindingSet() or nil}
    -- 3.3.5a returns command, key1, key2 (no modern category return).
    local function add(command,...)
        if type(command)~='string' or command=='' then return end
        for j=1,select('#',...) do
            local key=select(j,...)
            if type(key)=='string' and key~='' then snapshot.keys[key]=command end
        end
    end
    for i=1,GetNumBindings() do add(GetBinding(i)) end
    return snapshot
end
function AM:ApplyBindings(snapshot)
    self:ValidateBindings(snapshot)
    if InCombatLockdown() then error('Leave combat before restoring keybindings') end
    if not SetBinding or not saveBindings or not GetCurrentBindingSet then error('Client keybinding APIs unavailable') end
    local previous=self:CaptureBindings()
    if not previous then error('Client keybindings cannot be read') end
    local bindingSet=GetCurrentBindingSet()
    if bindingSet~=1 and bindingSet~=2 then error('Current binding set unavailable') end
    local function replace(values)
        local current=AM:CaptureBindings()
        for key in pairs(current.keys) do
            if not SetBinding(key) then error('Could not clear keybinding: '..key) end
        end
        for key,command in pairs(values.keys) do
            if not SetBinding(key,command) then error('Could not bind '..key..' to '..command) end
        end
    end
    local ok,err=pcall(function()
        replace(snapshot)
        local saved=saveBindings(bindingSet)
        if saved==false then error('Client refused to save keybindings') end
    end)
    if not ok then
        local rollbackOk,rollbackError=pcall(function() replace(previous);if saveBindings(bindingSet)==false then error('Client refused rollback save') end end)
        error(tostring(err)..(not rollbackOk and ('; rollback failed: '..tostring(rollbackError)) or ''))
    end
    local count=0;for _ in pairs(snapshot.keys) do count=count+1 end
    return count,bindingSet
end
local runner=CreateFrame('Frame')
local function update(frame,delta)
    if not frame.ready or not AM.db then return end
    local pending=AM.db.pendingBindings
    if not pending then frame:SetScript('OnUpdate',nil);return end
    if pending.character~=identity() then AM.db.pendingBindings=nil;frame:SetScript('OnUpdate',nil);return end
    if InCombatLockdown() or AM.db.pendingSettings or AM.followupReload then return end
    frame.elapsed=(frame.elapsed or 0)+delta
    if frame.elapsed<1 then return end
    AM.db.pendingBindings=nil;frame:SetScript('OnUpdate',nil)
    AM.operationContext='Restore keybindings for '..tostring(pending.name or 'backup')
    local ok,count,bindingSet=pcall(AM.ApplyBindings,AM,pending.value)
    AM.operationContext=nil
    AM.db.lastBindingRestore={name=pending.name,ok=ok,count=ok and count or nil,bindingSet=bindingSet,error=not ok and tostring(count) or nil}
    if not ok then AM:Print('Keybindings restore stopped: '..tostring(count)..'. Details: /ss log') end
end
function AM:StageBindings(snapshot,name)
    if not snapshot then return end -- Older profiles do not alter bindings.
    self:ValidateBindings(snapshot)
    self.db.pendingBindings={value=self:CopySettings(snapshot),name=name,character=identity()}
    runner.elapsed=0;runner:SetScript('OnUpdate',update)
end
runner:RegisterEvent('PLAYER_LOGIN')
runner:SetScript('OnEvent',function(frame)
    frame.ready=true;frame.elapsed=0;frame:SetScript('OnUpdate',update)
end)
