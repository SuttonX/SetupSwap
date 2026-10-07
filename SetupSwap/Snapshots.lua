local AM=SetupSwap
local function identity()
    return tostring(GetRealmName and GetRealmName() or '')..'/'..tostring(UnitName and UnitName('player') or '')
end
local function primitive(value,budget)
    local kind=type(value)
    if kind=='nil' or kind=='boolean' then return value end
    if kind=='number' then
        if value~=value or value==math.huge or value==-math.huge then error('non-finite number') end
        return value
    end
    if kind=='string' then budget.bytes=budget.bytes+#value;return value end
    error('non-saved value: '..kind)
end
function AM:CopySettings(value,budget)
    budget=budget or {nodes=0,bytes=0}
    if type(value)~='table' then return primitive(value,budget) end
    local result={}
    local active={[value]=true}
    local pending={{source=value,destination=result}}
    -- Iterative traversal has no artificial byte, entry, or nesting limit.
    -- Active-path tracking rejects cycles while preserving serializable sharing.
    while #pending>0 do
        local current=pending[#pending]
        local key,item=next(current.source,current.key)
        current.key=key
        if key==nil then
            active[current.source]=nil
            pending[#pending]=nil
        else
            if type(key)~='string' and type(key)~='number' then error('unsupported table key') end
            budget.nodes=budget.nodes+1
            local copiedKey=primitive(key,budget)
            if type(item)=='table' then
                if active[item] then error('cyclic table') end
                local destination={}
                current.destination[copiedKey]=destination
                active[item]=true
                pending[#pending+1]={source=item,destination=destination}
            else current.destination[copiedKey]=primitive(item,budget) end
        end
    end
    return result
end
function AM:SettingsDeclarations(addon)
    local list,seen={},{}
    local function add(name,scope)
        if name~='SetupSwapAccountDB' and name~='SetupSwapDB' and name~='_G' and not seen[name] then
            seen[name]=true; list[#list+1]={name=name,scope=scope,addon=addon}
        end
    end
    for _,scope in ipairs({'SavedVariables','SavedVariablesPerCharacter'}) do
        local metadata=GetAddOnMetadata(addon,scope) or GetAddOnMetadata(addon,'X-'..scope)
        for name in tostring(metadata or ''):gmatch('[%a_][%w_]*') do add(name,scope) end
        for _,name in ipairs((self.SettingsCatalog and self.SettingsCatalog[addon] or {})[scope] or {}) do add(name,scope) end
    end
    local base=addon:gsub('[-_]%d[%d%.]*$',''):lower():gsub('[^%w]','')
    for key,object in pairs(_G) do
        if type(key)=='string' and type(object)=='table' and key:lower():gsub('[^%w]','')==base then
            local db=rawget(object,'db') or rawget(object,'DB')
            if type(db)=='table' and type(rawget(db,'sv'))=='table' then
                for variable,value in pairs(_G) do
                    if type(variable)=='string' and value==db.sv then add(variable,'AceDB') end
                end
            end
        end
    end
    -- Older clients do not expose every TOC header. Do not sweep arbitrary globals:
    -- infer only conventional settings names that belong to this addon prefix.
    do
        local base=addon:lower():gsub('[-_]%d[%d%.]*$','')
        local prefix=base:gsub('[^%w]','')
        local suffixes={db=true,chardb=true,accountdb=true,config=true,configuration=true,
            settings=true,options=true,vars=true,savedvariables=true,savedvars=true,data=true}
        for name,value in pairs(_G) do
            if type(name)=='string' and type(value)=='table' then
                local normalized=name:lower():gsub('[^%w]','')
                if normalized:sub(1,#prefix)==prefix and suffixes[normalized:sub(#prefix+1)] then add(name,'inferred') end
            end
        end
    end
    return list
end
function AM:AceDatabase(variable)
    if not LibStub then return end
    local ok,lib=pcall(function() return LibStub('AceDB-3.0',true) end)
    if not ok or not lib or type(lib.db_registry)~='table' then return end
    for db in pairs(lib.db_registry) do
        if db.sv==_G[variable] and type(db.GetCurrentProfile)=='function' and type(db.SetProfile)=='function' then return db end
    end
end
function AM:AceSnapshot(db,budget)
    local result={profile=self:CopySettings(db.profile,budget),namespaces={},scopes={}}
    for _,scope in ipairs({'char','global','realm','faction','factionrealm'}) do
        if type(db[scope])=='table' then result.scopes[scope]=self:CopySettings(db[scope],budget) end
    end
    for name,child in pairs(db.children or {}) do
        result.namespaces[name]=self:CopySettings(child.profile,budget)
        result.namespaceScopes=result.namespaceScopes or {}
        result.namespaceScopes[name]={}
        for _,scope in ipairs({'char','global','realm','faction','factionrealm'}) do
            if type(child[scope])=='table' then result.namespaceScopes[name][scope]=self:CopySettings(child[scope],budget) end
        end
    end
    return result
end
local function inject(destination,source)
    local pending={{destination=destination,source=source}}
    while #pending>0 do
        local current=pending[#pending]
        pending[#pending]=nil
        for key in pairs(current.destination) do
            if current.source[key]==nil then rawset(current.destination,key,nil) end
        end
        for key,value in pairs(current.source) do
            if type(value)=='table' then
                local child=rawget(current.destination,key)
                if type(child)~='table' then child={};rawset(current.destination,key,child) end
                pending[#pending+1]={destination=child,source=value}
            else rawset(current.destination,key,value) end
        end
    end
end
function AM:CaptureSettings(profile)
    local snapshot={version=1,variables={},character=identity(),addons=0,skipped={}}
    local seen={}
    for _,entry in ipairs(self:Inventory()) do
        if entry.name~=self.name and profile.addons[entry.name]==true then
            if IsAddOnLoaded(entry.name) then
                local captured=false
                for _,declaration in ipairs(self:SettingsDeclarations(entry.name)) do
                    if not seen[declaration.name] then
                        seen[declaration.name]=true
                        local value=_G[declaration.name]
                        local db=self:AceDatabase(declaration.name)
                        local ok,result
                        local budget={nodes=0,bytes=0}
                        if db then ok,result=pcall(self.AceSnapshot,self,db,budget)
                        else ok,result=pcall(self.CopySettings,self,value,budget) end
                        if ok then
                            declaration.present=value~=nil; declaration.value=result; declaration.mode=db and 'ace' or 'flat'
                            snapshot.variables[#snapshot.variables+1]=declaration; captured=true
                        else
                            snapshot.skipped[#snapshot.skipped+1]=entry.name..'/'..declaration.name..': '..tostring(result)
                        end
                    end
                end
                if captured then snapshot.addons=snapshot.addons+1
                elseif #self:SettingsDeclarations(entry.name)==0 then snapshot.skipped[#snapshot.skipped+1]=entry.name..' (no discoverable saved settings)' end
            else snapshot.skipped[#snapshot.skipped+1]=entry.name..' (not loaded)' end
        end
    end
    return snapshot
end
function AM:BeginSettingsCapture(name,switchAfter)
    if not self:CanStartOperation() then return false end
    if self.db.pendingBindings then self:Print('Wait for this profile\'s keybindings to finish restoring, then save settings.'); return false end
    if InCombatLockdown() then self:Print('Leave combat before saving a settings snapshot.'); return false end
    local profile=self.db.profiles[name]
    if not profile then self:Print('Unknown profile. Nothing changed.'); return false end
    local layouts=self.CaptureFrameLayouts and profile and self:CaptureFrameLayouts(profile) or nil
    self.db.lastCapture={name=name,windows=layouts}
    self.db.pendingSettings={kind='capture',name=name,character=identity(),switchAfter=switchAfter and true or false,layouts=layouts,chat=self.CaptureChatLayout and self:CaptureChatLayout(),native=self.CaptureNativeState and self:CaptureNativeState(),coverage=self.lastFrameCoverage,bindings=self.CaptureBindings and self:CaptureBindings()}
    self:Print('Saving settings: reloading once to flush addon settings, then capturing the profile and restoring its windows.')
    ReloadUI(); return true
end
function AM:PrepareSettingsSwitch(name)
    local profile=self.db.profiles[name]
    if profile and profile.captureSettings and type(profile.settings)=='table'
        and ((type(profile.settings.variables)=='table' and #profile.settings.variables>0)
        or (type(profile.settings.layouts)=='table' and #profile.settings.layouts>0) or type(profile.settings.chat)=='table' or type(profile.settings.bindings)=='table') then
        self.db.pendingSettings={kind='restore',name=name,character=identity(),early=SetupSwapEarlyLoader~=nil}
        return true
    end
    return false
end
-- The helper registers its login handler before target addons. All addon files
-- and ADDON_LOADED handlers have completed by this point, so their saved globals
-- exist. AceDB objects that are created at PLAYER_LOGIN are seeded through their
-- native saved tables before that initialization runs.
function AM:TryEarlySettingsRestore(loader)
    local db=SetupSwapAccountDB
    local pending=type(db)=='table' and db.pendingSettings
    if not pending or pending.kind~='restore' or not pending.early then return false end
    if pending.character~=identity() or InCombatLockdown() then return false end
    local profile=type(db.profiles)=='table' and db.profiles[pending.name]
    local snapshot=profile and profile.settings
    if not snapshot then return false end
    -- An earlier addon can already have registered its login handler. Preserve
    -- the old path rather than claiming that its initialization was intercepted.
    for _,item in ipairs(snapshot.variables or {}) do
        if loader.alreadyLoaded[item.addon] then
            pending.earlyFallback='Startup helper loaded after '..tostring(item.addon)
            return false
        end
    end
    self.db=db
    self.operationContext='Early settings restore for '..tostring(pending.name)
    local previousBackup=db.settingsBackup
    local ok,count=pcall(self.ApplySettings,self,snapshot,true,pending.name,true)
    pending.earlyBackupAvailable=db.settingsBackup~=previousBackup
    self.operationContext=nil
    if not ok then
        pending.earlyFallback=tostring(count)
        return false
    end
    pending.earlyFallback=nil
    pending.earlyApplied=true
    pending.earlyCount=count
    db.lastEarlyRestore={name=pending.name,count=count,character=identity(),seeded=self.earlyRawAce}
    db.lastRestoreMode={name=pending.name,mode='single reload',count=count,seeded=self.earlyRawAce}
    return true
end

-- AceDB stores an uninitialized database as an ordinary SavedVariables table.
-- Seed that native structure when an addon creates its AceDB object at login.
-- Preserve other native profiles/characters; apply scopes for the current user.
function AM:PrepareRawAceSettings(value,target,current)
    if type(value)~='table' or type(value.profile)~='table' then error('Invalid native settings snapshot') end
    if current~=nil and type(current)~='table' then error('Invalid native SavedVariables table') end
    local result=self:CopySettings(current or {})
    local realm=tostring(GetRealmName() or '')
    local character=tostring(UnitName('player') or '')..' - '..realm
    local faction=UnitFactionGroup and UnitFactionGroup('player')
    local keys={char=character,realm=realm,faction=faction,factionrealm=faction and (faction..' - '..realm)}
    local function populate(destination,profile,scopes)
        destination.profiles=destination.profiles or {}
        destination.profiles[target]=self:CopySettings(profile)
        for scope,settings in pairs(scopes or {}) do
            if scope=='global' then destination.global=self:CopySettings(settings)
            elseif keys[scope] then
                destination[scope]=destination[scope] or {}
                destination[scope][keys[scope]]=self:CopySettings(settings)
            else error('Native settings scope key unavailable: '..tostring(scope)) end
        end
    end
    populate(result,value.profile,value.scopes)
    result.profileKeys=result.profileKeys or {}
    result.profileKeys[character]=target
    for name,profile in pairs(value.namespaces or {}) do
        result.namespaces=result.namespaces or {}
        result.namespaces[name]=result.namespaces[name] or {}
        populate(result.namespaces[name],profile,(value.namespaceScopes or {})[name])
    end
    return result
end

local function validateAceSnapshot(value)
    if type(value)~='table' or type(value.profile)~='table' then error('Invalid native settings snapshot') end
    local validScopes={char=true,global=true,realm=true,faction=true,factionrealm=true}
    local function scopes(values)
        if values==nil then return end
        if type(values)~='table' then error('Invalid native settings scopes') end
        for scope,settings in pairs(values) do
            if not validScopes[scope] or type(settings)~='table' then error('Invalid native settings scope: '..tostring(scope)) end
        end
    end
    scopes(value.scopes)
    if value.namespaces~=nil and type(value.namespaces)~='table' then error('Invalid native settings namespaces') end
    if value.namespaceScopes~=nil and type(value.namespaceScopes)~='table' then error('Invalid native namespace scopes') end
    for name,profile in pairs(value.namespaces or {}) do
        if type(name)~='string' or type(profile)~='table' then error('Invalid native settings namespace') end
    end
    for name,settings in pairs(value.namespaceScopes or {}) do
        if not (value.namespaces and value.namespaces[name]) then error('Native namespace scopes lack a profile') end
        scopes(settings)
    end
end

-- SetProfile emits live UI callbacks. At early login the target UI may not yet
-- exist (Questie's tracker, for example). Select the profile silently in this
-- startup-only path, then let the addon's normal initialization read it.
local function selectStartupProfile(db,target)
    local saved,visited,pending={},{},{db}
    local silent={Fire=function() end}
    while #pending>0 do
        local current=pending[#pending];pending[#pending]=nil
        if not visited[current] then
            visited[current]=true
            saved[#saved+1]={db=current,callbacks=current.callbacks}
            current.callbacks=silent
            for _,child in pairs(current.children or {}) do pending[#pending+1]=child end
        end
    end
    local ok,err=pcall(db.SetProfile,db,target)
    for _,item in ipairs(saved) do item.db.callbacks=item.callbacks end
    if not ok then error(err) end
end

-- Addons initialized during ADDON_LOADED may cache db.profile or create UI
-- before PLAYER_LOGIN. Refresh them once startup has finished, using their
-- native profile callback rather than an addon-specific window integration.
function AM:RefreshStartupSettings()
    local pending=self.startupSettingsCallbacks or {}
    self.startupSettingsCallbacks=nil
    local count=0
    for _,item in ipairs(pending) do
        if item.db.callbacks and type(item.db.callbacks.Fire)=='function' then
            item.db.callbacks:Fire('OnProfileChanged',item.db,item.target)
            count=count+1
        end
    end
    self.db.lastStartupRefresh=count
    return count
end

function AM:ApplySettings(snapshot,makeBackup,profileName,early)
    local assignments,backup={}, {version=1,variables={},character=identity()}
    if snapshot.bindings and self.ValidateBindings then self:ValidateBindings(snapshot.bindings) end
    if makeBackup and snapshot.bindings and self.CaptureBindings then backup.bindings=self:CopySettings(self.db.pendingBindingBackup or self:CaptureBindings()) end
    if makeBackup and self.CaptureFrameLayouts and snapshot.layouts then
        local selection={addons={}}
        for _,item in ipairs(snapshot.layouts) do selection.addons[item.addon]=true end
        backup.layouts=self:CaptureFrameLayouts(selection)
    end
    if makeBackup and self.CaptureNativeState then backup.native=self:CaptureNativeState() end
    if makeBackup and snapshot.chat and self.CaptureChatLayout then backup.chat=self:CaptureChatLayout() end
    local _,inventory=self:Inventory()
    -- Validate and copy everything before touching any other addon's globals.
    for _,item in ipairs(snapshot.variables or {}) do
        local allowed=false
        if item.addon~=self.name and inventory[item.addon] and IsAddOnLoaded(item.addon) then
            for _,declaration in ipairs(self:SettingsDeclarations(item.addon)) do
                if declaration.name==item.name and declaration.scope==item.scope then allowed=true; break end
            end
        end
        if allowed then
            if item.mode=='ace' then
                validateAceSnapshot(item.value)
                if item.restoreProfile~=nil and type(item.restoreProfile)~='string' then error('Invalid native restore profile name') end
            end
            local db=item.mode=='ace' and self:AceDatabase(item.name) or nil
            if item.mode=='ace' and not db and not early then error('Native settings database is not ready for '..tostring(item.addon)) end
            if item.mode~='ace' or db or early then
                local target=item.restoreProfile or ('SetupSwap-'..tostring(profileName or 'restored'))
                local rawAce=item.mode=='ace' and not db
                local value=rawAce and self:PrepareRawAceSettings(item.value,target,_G[item.name]) or self:CopySettings(item.value)
                assignments[#assignments+1]={name=item.name,value=value,
                    db=db,target=target,rawAce=rawAce}

                if makeBackup then
                    backup.variables[#backup.variables+1]={addon=item.addon,name=item.name,scope=item.scope,
                        mode=db and 'ace' or 'flat',restoreProfile=db and db:GetCurrentProfile() or nil,
                        present=_G[item.name]~=nil,value=db and self:AceSnapshot(db) or self:CopySettings(_G[item.name])}
                end
            end
        end
    end
    if makeBackup then self.db.settingsBackup=backup;self.db.pendingBindingBackup=nil end
    local function apply(logout)
        for _,item in ipairs(assignments) do
            if item.db then
                if not logout then
                    if early then selectStartupProfile(item.db,item.target)
                    else item.db:SetProfile(item.target) end
                end
                inject(item.db.profile,item.value.profile)
                for scope,values in pairs(item.value.scopes or {}) do
                    if type(item.db[scope])=='table' then inject(item.db[scope],values) end
                end
                for name,values in pairs(item.value.namespaces or {}) do
                    local child=item.db.children and item.db.children[name]
                    if child then
                        inject(child.profile,values)
                        for scope,scopeValues in pairs((item.value.namespaceScopes or {})[name] or {}) do
                            if type(child[scope])=='table' then inject(child[scope],scopeValues) end
                        end
                        if child.defaults and type(child.RegisterDefaults)=='function' then child:RegisterDefaults(child.defaults) end
                    end
                end
                -- Older captures can lack keys introduced by an addon update.
                -- Restore AceDB's defaults and nested default metatables after injection.
                if item.db.defaults and type(item.db.RegisterDefaults)=='function' then item.db:RegisterDefaults(item.db.defaults) end
                if not logout and not early and item.db.callbacks then item.db.callbacks:Fire('OnProfileChanged',item.db,item.target) end
            elseif type(_G[item.name])=='table' and type(item.value)=='table' then
                inject(_G[item.name],item.value)
            else _G[item.name]=AM:CopySettings(item.value) end
        end
    end
    apply(false)
    if early then
        self.earlyRawAce=0
        self.startupSettingsCallbacks={}
        local seen={}
        for _,item in ipairs(assignments) do
            if item.rawAce then self.earlyRawAce=self.earlyRawAce+1 end
            if item.db then
                local pending={item.db}
                while #pending>0 do
                    local db=pending[#pending];pending[#pending]=nil
                    if not seen[db] then
                        seen[db]=true
                        self.startupSettingsCallbacks[#self.startupSettingsCallbacks+1]={db=db,target=item.target}
                        for _,child in pairs(db.children or {}) do pending[#pending+1]=child end
                    end
                end
            end
        end
    end
    -- Reapply at logout after addons have had a chance to flush runtime caches.
    -- Register this frame just before reloading, after startup initialization.
    if #assignments>0 and not early then
        local tail=CreateFrame('Frame')
        tail:RegisterEvent('PLAYER_LOGOUT'); tail:SetScript('OnEvent',function() apply(true) end)
    end
    return #assignments
end
function AM:UndoSettings()
    if not self:CanStartOperation() then return false end
    if InCombatLockdown() then self:Print('Leave combat before restoring the settings backup.'); return false end
    if not self.db.settingsBackup then self:Print('No settings backup available.'); return false end
    if self.db.settingsBackup.character~=identity() then self:Print('This settings backup belongs to a different character.'); return false end
    if self.PrepareNativeState then self:PrepareNativeState({captureSettings=true,settings=self.db.settingsBackup,addons=self:Snapshot()}) end
    self.db.pendingBindings=nil
    self.db.pendingSettings={kind='undo',character=identity()}
    self:Print('Loading the settings backup; this may require two reloads.')
    ReloadUI(); return true
end
function AM:FinishSettingsOperation()
    local pending=self.db.pendingSettings
    if not pending then return end
    if pending.character~=identity() then
        self.db.pendingSettings=nil; self:Print('Pending settings operation canceled: a different character logged in.'); return
    end
    if InCombatLockdown() then return end
    -- Clear before processing so failures cannot cause an automatic reload loop.
    self.db.pendingSettings=nil
    local profile=self.db.profiles[pending.name]
    if pending.kind=='capture' then
        if not profile then self:Print('Snapshot canceled: profile no longer exists.'); return end
        local snapshot=self:CaptureSettings(profile)
        snapshot.layouts=pending.layouts
        snapshot.chat=pending.chat
        snapshot.native=pending.native
        snapshot.bindings=pending.bindings
        snapshot.coverage=pending.coverage
        self.db.lastCapture={name=pending.name,windows=snapshot.layouts,chat=snapshot.chat}
        profile.settings=snapshot
        if self.StageFrameLayouts then self:StageFrameLayouts(pending.name,snapshot.layouts) end
        if self.StageChatLayout then self:StageChatLayout(snapshot.chat) end
        if self.ApplyFrameLayouts then self:ApplyFrameLayouts(snapshot.layouts,profile) end
        self:Print('Captured '..snapshot.addons..' addons ('..#snapshot.variables..' variables); '..#snapshot.skipped..' skipped.')
        for _,reason in ipairs(snapshot.skipped) do self:Print('Skipped '..reason) end
        if pending.switchAfter then
            -- Snapshot is already the current settings; only apply addon flags.
            self:RequestFollowupReload('Settings captured. Continue reload to activate the profile.',pending.name)
        else
            self:Print('Settings saved for '..pending.name..'. No further reload is needed.')
        end
    elseif pending.kind=='restore' or pending.kind=='undo' then
        if pending.kind=='restore' and pending.earlyApplied then
            -- Confirm that late-created native databases actually selected the
            -- seeded profile. If startup replaced it, retain the old fallback.
            for _,item in ipairs((profile and profile.settings and profile.settings.variables) or {}) do
                if item.mode=='ace' and IsAddOnLoaded(item.addon) then
                    local db=self:AceDatabase(item.name)
                    local target=item.restoreProfile or ('SetupSwap-'..tostring(pending.name))
                    local ok,current=false,nil
                    if db then ok,current=pcall(db.GetCurrentProfile,db) end
                    if not ok or current~=target then
                        pending.earlyApplied=nil
                        pending.earlyFallback='Native settings did not initialize with the saved profile for '..tostring(item.addon)
                        break
                    end
                end
            end
        end
        if pending.kind=='restore' and pending.earlyApplied then
            local ok,err=pcall(self.RefreshStartupSettings,self)
            if not ok then
                pending.earlyApplied=nil
                pending.earlyFallback='Native startup refresh failed: '..tostring(err)
            end
        else self.startupSettingsCallbacks=nil end
        if pending.kind=='restore' and pending.earlyApplied then
            local snapshot=profile and profile.settings
            if not snapshot then self:Print('Settings operation canceled: snapshot unavailable.'); return end
            if self.StageBindings then self:StageBindings(snapshot.bindings,pending.name) end
            if self.StageFrameLayouts then self:StageFrameLayouts(pending.name,snapshot.layouts) end
            if self.StageChatLayout then self:StageChatLayout(snapshot.chat) end
            if self.ApplyFrameLayouts then self:ApplyFrameLayouts(snapshot.layouts,profile) end
            self:Print('Profile ready: restored '..tostring(pending.earlyCount or 0)..' settings variables during startup.')
            return
        end
        if pending.kind=='restore' then
            self.db.lastRestoreMode={name=pending.name,mode='two reloads',reason=pending.earlyFallback or 'Startup helper unavailable'}
        end
        if pending.earlyFallback then
            self:Print('Using the two-reload restore: '..pending.earlyFallback)
        end
        local snapshot=pending.kind=='undo' and self.db.settingsBackup or (profile and profile.settings)
        if not snapshot then self:Print('Settings operation canceled: snapshot unavailable.'); return end
        self.operationContext='Restore saved variables for '..tostring(pending.name or 'backup')
        local ok,count=pcall(self.ApplySettings,self,snapshot,pending.kind=='restore' and not pending.earlyBackupAvailable,pending.name)
        self.operationContext=nil
        if not ok then self:Print('Settings restore stopped: '..tostring(count)); return end
        if self.StageBindings then self:StageBindings(snapshot.bindings,pending.name) end
        if self.StageFrameLayouts then self:StageFrameLayouts(pending.name,snapshot.layouts) end
        if self.StageChatLayout then self:StageChatLayout(snapshot.chat) end
        if self.ApplyFrameLayouts then self:ApplyFrameLayouts(snapshot.layouts,profile) end
        if count>0 then
            self:RequestFollowupReload('Restored '..count..' settings variables. Continue reload to initialize addons with them.')
        else
            if self.ApplyFrameLayouts then
                self:ApplyFrameLayouts(snapshot.layouts,profile); self.db.pendingFrameLayouts=nil
            end
            self:Print('No saved settings variables matched; available window positions applied.')
        end
    end
end
local runner=CreateFrame('Frame')
runner:RegisterEvent('PLAYER_LOGIN')
runner:SetScript('OnEvent',function(self)
    local elapsed=0
    self:SetScript('OnUpdate',function(frame,delta)
        if not AM.db then return end
        if not AM.db.pendingSettings then frame:SetScript('OnUpdate',nil); return end
        if InCombatLockdown() then return end
        elapsed=elapsed+delta
        if elapsed>=1 then
            frame:SetScript('OnUpdate',nil); AM:FinishSettingsOperation()
        end
    end)
end)

function AM:RequestFollowupReload(message,switchName)
    self.followupReload=true;self.followupSwitch=switchName
    self:Print(message)
    if StaticPopup_Show then
        local dialog=StaticPopup_Show('SETUPSWAP_CONTINUE_RELOAD',message)
        if dialog then dialog:ClearAllPoints();dialog:SetPoint('CENTER',UIParent,'CENTER',0,UIParent:GetHeight()*.18) end
    end
end
if StaticPopupDialogs then
    StaticPopupDialogs.SETUPSWAP_CONTINUE_RELOAD={
        text='%s',button1='Continue reload',timeout=0,whileDead=true,hideOnEscape=false,preferredIndex=3,
        OnShow=function(frame)
            frame:ClearAllPoints();frame:SetPoint('CENTER',UIParent,'CENTER',0,UIParent:GetHeight()*.18)
        end,
        OnAccept=function()
            if InCombatLockdown() then AM:RequestFollowupReload('Leave combat, then continue reload.',AM.followupSwitch);return end
            AM.followupReload=nil
            if AM.followupSwitch then
                local name=AM.followupSwitch;AM.followupSwitch=nil;AM.skipSettingsOnce=true;AM:Switch(name);AM.skipSettingsOnce=nil
            else ReloadUI() end
        end,
    }
end
