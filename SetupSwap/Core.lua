local ADDON = ...
if type(ADDON) ~= 'string' then ADDON = 'SetupSwap' end
SetupSwap = {name = ADDON, aliases = {}}
local AM = SetupSwap
local function trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end
local function on(v) return v ~= nil and v ~= false and v ~= 0 end
function AM:Print(text)
    DEFAULT_CHAT_FRAME:AddMessage('|cff67c9ffSetupSwap:|r '..tostring(text))
end
-- A reload-backed operation owns its queued work until every restore finishes.
function AM:OperationBusy()
    local db=self.db or {}
    return db.pendingSettings or db.pendingBindings or db.pendingFrameLayouts
        or db.pendingChatLayout or self.followupReload or self.operationContext
end
function AM:CanStartOperation()
    if self:OperationBusy() then
        self:Print('Wait for the current settings operation to finish; complete any Continue reload prompt first. Nothing changed.')
        return false
    end
    return true
end
function AM:Inventory()
    local list, byName = {}, {}
    for i = 1, GetNumAddOns() do
        local name, title, notes, enabled, loadable, reason = GetAddOnInfo(i)
        if name and name~='!SetupSwapLoader' then
            local entry = {name=name, title=title or name, notes=notes, enabled=on(enabled),
                loadable=loadable, reason=reason, dependencies={GetAddOnDependencies(i)}}
            list[#list+1] = entry; byName[name] = entry
        end
    end
    table.sort(list, function(a,b) return a.name:lower() < b.name:lower() end)
    return list, byName
end
function AM:Snapshot()
    local states = {}
    for _, entry in ipairs(self:Inventory()) do states[entry.name] = entry.enabled end
    states[self.name] = true
    return states
end
function AM:LoadedSnapshot()
    -- Compatibility name retained: current selection means enabled flags,
    -- including enabled on-demand addons that have not entered memory yet.
    return self:Snapshot()
end
function AM:ValidName(name)
    name = trim(name):lower()
    if name == '' or #name > 24 or not name:match('^[a-z][a-z0-9_%-]*$') then
        return nil, 'Use 1-24 letters, digits, hyphens, or underscores; start with a letter.'
    end
    local reserved={config=true,settings=true,switch=true,save=true,new=true,command=true,list=true,undo=true,log=true,diagnostics=true}
    if reserved[name] then return nil, 'That name is reserved for a SetupSwap command.' end
    return name
end
function AM:CreateProfile(name, command)
    if not self:CanStartOperation() then return nil, 'A settings operation is still in progress.' end
    local valid, err = self:ValidName(name)
    if not valid then return nil, err end
    if self.db.profiles[valid] then return nil, 'That profile already exists.' end
    self.db.profiles[valid] = {addons=self:Snapshot(), command=command}
    return valid
end
function AM:RenameProfile(oldName,newName)
    if not self:CanStartOperation() then return nil, 'A settings operation is still in progress.' end
    local name,err=self:ValidName(newName)
    if not name then return nil,err end
    if not self.db.profiles[oldName] then return nil,'Unknown profile.' end
    if name==oldName then return name end
    if self.db.profiles[name] then return nil,'That profile already exists.' end
    self.db.profiles[name]=self.db.profiles[oldName]
    self.db.profiles[oldName]=nil
    if self.db.active==oldName then self.db.active=name end
    self:RegisterCommands()
    return name
end
function AM:EffectiveState(profile, entry)
    if entry.name == self.name then return true end
    local state = profile.addons[entry.name]
    -- A saved profile is a complete selection: absent addons are not selected.
    return state == true
end
function AM:Plan(name)
    local profile = self.db.profiles[name]
    if not profile then return nil, 'Unknown profile: '..tostring(name) end
    local list = self:Inventory()
    local target = {}
    -- Apply enabled flags exactly; dependency loadability belongs to the client.
    for _, entry in ipairs(list) do target[entry.name] = self:EffectiveState(profile, entry) end
    local changes = {}
    for _, entry in ipairs(list) do
        if entry.name ~= self.name and target[entry.name] ~= entry.enabled then
            changes[#changes+1] = {name=entry.name, enabled=target[entry.name]}
        end
    end
    return {changes=changes, target=target}
end
function AM:SetSelection(name, addon, enabled, draft)
    local profile = draft or self.db.profiles[name]
    if not profile then return nil, 'Unknown profile.' end
    if addon == self.name and not enabled then return nil, 'SetupSwap must stay enabled.' end
    local list, byName = self:Inventory()
    if not byName[addon] then return nil, 'Addon not installed: '..addon end
    -- Checking selects installed requirements as a convenience, without rejecting
    -- missing/cyclic TOCs. Unchecking preserves every dependent selection.
    local edits, visited = {}, {}
    local function enable(current)
        if visited[current] or not byName[current] then return end
        visited[current] = true
        edits[current] = true
        for _, dep in ipairs(byName[current].dependencies) do
            if dep and dep ~= '' then enable(dep) end
        end
    end
    if enabled then enable(addon) else edits[addon] = false end
    for key, value in pairs(edits) do profile.addons[key] = value end
    profile.addons[self.name] = true
    return true
end
function AM:Switch(name)
    if not self:CanStartOperation() then return nil, 'A settings operation is still in progress.' end
    name = trim(name):lower()
    if InCombatLockdown() then self:Print('Leave combat, then run the command again. Nothing changed.'); return false end
    local plan, err = self:Plan(name)
    if not plan then self:Print(err..' Nothing changed.'); return false end
    self.db.pendingBindings=nil
    local targetProfile=self.db.profiles[name]
    self.db.pendingBindingBackup=(targetProfile.captureSettings and targetProfile.settings and targetProfile.settings.bindings and self.CaptureBindings) and self:CaptureBindings() or nil
    local helperName,_,_,helperEnabled=GetAddOnInfo('!SetupSwapLoader')
    if helperName and helperEnabled~=nil and not on(helperEnabled) then EnableAddOn(helperName) end
    if self.PrepareNativeState then self:PrepareNativeState(self.db.profiles[name]) end
    for _, change in ipairs(plan.changes) do
        if change.enabled then EnableAddOn(change.name) else DisableAddOn(change.name) end
    end
    if self.PrepareSettingsSwitch and not self.skipSettingsOnce then self:PrepareSettingsSwitch(name) end
    self.db.active = name
    local profile=self.db.profiles[name]
    if not profile.settings then self.db.setupReminder=name end
    self:Print('Switching to '..name..'; reloading the UI.')
    ReloadUI()
    return true
end
function AM:SaveCurrent(name)
    if not self:CanStartOperation() then return nil, 'A settings operation is still in progress.' end
    name = trim(name):lower()
    if not self.db.profiles[name] then
        local result, err = self:CreateProfile(name)
        if not result then self:Print(err); return false end
    end
    self.db.profiles[name].addons = self:Snapshot()
    self:Print('Captured current addon enable states in '..name..'.')
    return true
end
function AM:CommandAvailable(command, ownKey)
    for key in pairs(SlashCmdList) do
        if key ~= ownKey then
            local i = 1
            while _G['SLASH_'..key..i] do
                if tostring(_G['SLASH_'..key..i]):lower() == '/'..command then return false end
                i = i+1
            end
        end
    end
    return true
end
function AM:SetCommand(name, command)
    local profile = self.db.profiles[name]
    if not profile then return nil, 'Unknown profile.' end
    command = trim(command):lower():gsub('^/', '')
    if command ~= '' and (not command:match('^[a-z][a-z0-9]*$') or #command > 24) then
        return nil, 'Command: 1-24 letters/digits, starting with a letter; no spaces.'
    end
    if command == 'ss' or command == 'setupswap' then return nil, 'That command belongs to SetupSwap.' end
    for other, p in pairs(self.db.profiles) do
        if other ~= name and p.command == command and command ~= '' then return nil, 'Another profile uses that command.' end
    end
    local ownKey = self.aliases[name]
    if command ~= '' and not self:CommandAvailable(command, ownKey) then return nil, 'That command is already used by another addon.' end
    profile.command = command ~= '' and command or nil
    self:RegisterCommands()
    return true
end
function AM:RegisterCommands()
    for _, key in pairs(self.aliases) do SlashCmdList[key] = nil; _G['SLASH_'..key..'1'] = nil end
    self.aliases = {}
    local names = {}; for name in pairs(self.db.profiles) do names[#names+1] = name end; table.sort(names)
    for i, name in ipairs(names) do
        local command = self.db.profiles[name].command
        if command and command ~= '' then
            local key = 'SETUPSWAPPROFILE'..i
            if self:CommandAvailable(command) then
                self.aliases[name] = key; _G['SLASH_'..key..'1'] = '/'..command
                local profileName = name
                SlashCmdList[key] = function() AM:Switch(profileName) end
            else self:Print('/'..command..' is already in use. Use /setupswap switch '..name..' instead.') end
        end
    end
    -- The 3.3.5 chat handler caches aliases; invalidate it when profiles change.
    if hash_SlashCmdList then wipe(hash_SlashCmdList) end
end
function AM:DeleteProfile(name)
    if not self:CanStartOperation() then return nil, 'A settings operation is still in progress.' end
    if not self.db.profiles[name] then return nil, 'Unknown profile.' end
    self.db.profiles[name] = nil
    if self.db.active == name then self.db.active = nil end
    self:RegisterCommands()
    return true
end
function AM:HandleCommand(message)
    local op, rest = trim(message):match('^(%S*)%s*(.-)$'); op=op:lower()
    if op == '' or op == 'config' or op == 'settings' then self:ShowUI(); return end
    if op == 'switch' then self:Switch(rest)
    elseif op == 'save' then self:SaveCurrent(rest)
    elseif op == 'new' then
        local name, err=self:CreateProfile(rest); self:Print(name and ('Created '..name..'. Configure it with /setupswap.') or err)
    elseif op == 'command' then
        local name, command=rest:match('^(%S+)%s*(.-)$')
        local ok, err=self:SetCommand((name or ''):lower(), command or '')
        self:Print(ok and 'Profile command saved.' or err)
    elseif op == 'undo' and self.UndoSettings then self:UndoSettings()
    elseif op == 'log' or op == 'diagnostics' then
        if self.ShowDiagnostics then self:ShowDiagnostics()
        else self:Print('SetupSwap log module unavailable. Reinstall both addon folders from the complete ZIP. Version: '..tostring(GetAddOnMetadata and GetAddOnMetadata(self.name,'Version') or 'unknown')) end
    elseif op == 'list' then
        local names={}; for name,p in pairs(self.db.profiles) do names[#names+1]=name..(p.command and ' (/'..p.command..')' or '') end
        table.sort(names); self:Print(table.concat(names, ', '))
    elseif self.db.profiles[op] then self:Switch(op)
    else self:Print('/setupswap opens the editor. Commands: switch NAME, save NAME, new NAME, command NAME SHORTCUT, list, log. Switching reloads the UI. Profiles never apply automatically.') end
end
function AM:Initialize()
    SetupSwapAccountDB = type(SetupSwapAccountDB)=='table' and SetupSwapAccountDB or {}
    self.db=SetupSwapAccountDB
    if type(self.db.profiles)~='table' then self.db.profiles={} end
    -- One-time import for each old character. Existing account names win.
    -- Keep the legacy variable declared so the client can load it for migration.
    if type(SetupSwapDB)=='table' and not SetupSwapDB.accountMigrated then
        local migrationFailed=false
        if type(SetupSwapDB.profiles)=='table' then
            for name,profile in pairs(SetupSwapDB.profiles) do
                if not self.db.profiles[name] and type(profile)=='table' then
                    -- Preserve settings, capture flags and future profile fields.
                    local ok,imported=pcall(self.CopySettings,self,profile)
                    if not ok then
                        self:Print('Legacy profile '..tostring(name)..' could not be imported: '..tostring(imported))
                        migrationFailed=true -- Retain migration eligibility for a later retry.
                    end
                    if ok then self.db.profiles[name]=imported end
                end
            end
        end
        if not self.db.minimapPosition and type(SetupSwapDB.minimapPosition)=='table' then
            self.db.minimapPosition={x=SetupSwapDB.minimapPosition.x,y=SetupSwapDB.minimapPosition.y}
        end
        if not migrationFailed then SetupSwapDB.accountMigrated=true end
    end
    for name, profile in pairs(self.db.profiles) do
        if type(name)~='string' or type(profile)~='table' then
            self.db.profiles[name]=nil
        else
        if type(profile.addons)~='table' then profile.addons={} end
        profile.addons[self.name]=true
        end
    end
    SLASH_SETUPSWAP1='/setupswap'
    SlashCmdList.SETUPSWAP=function(message) AM:HandleCommand(message) end
    if self:CommandAvailable('ss') then SLASH_SETUPSWAP2='/ss' end
    self:RegisterCommands()
    if self.CreateMinimapButton then self:CreateMinimapButton() end
    if self.RestoreMatchingWindowsOnLogin then self:RestoreMatchingWindowsOnLogin() end
    local reminder=self.db.setupReminder
    self.db.setupReminder=nil
    if reminder and reminder==self.db.active then
        self:Print('Profile '..reminder..' is active. Arrange the UI and any keybind changes, reopen /ss, select '..reminder..', then click Save settings & positions. Settings, positions, chat, and keybindings have not been captured yet.')
    end
end
local frame=CreateFrame('Frame')
frame:RegisterEvent('PLAYER_LOGIN')
frame:SetScript('OnEvent', function() AM:Initialize() end)
