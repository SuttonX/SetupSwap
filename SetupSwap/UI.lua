local AM = SetupSwap
local function label(parent, text, x, y, font)
    local fs=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontNormal')
    fs:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y); fs:SetText(text); return fs
end
local function button(parent, text, width, x, y, handler)
    local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
    b:SetSize(width,24); b:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y); b:SetText(text); b:SetScript('OnClick',handler)
    return b
end
local function edit(parent, width, x, y)
    local e=CreateFrame('EditBox',nil,parent,'InputBoxTemplate')
    e:SetSize(width,24); e:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y); e:SetAutoFocus(false)
    e:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
    e:SetScript('OnEnterPressed',function(self) self:ClearFocus() end)
    return e
end
function AM:ProfileNames()
    local names={}; for name in pairs(self.db.profiles) do names[#names+1]=name end
    table.sort(names); return names
end
function AM:ProfileMatchesEnabled(name)
    local profile=self.db.profiles[name]
    if not profile then return false end
    for _,entry in ipairs(self:Inventory()) do
        if self:EffectiveState(profile,entry)~=entry.enabled then return false end
    end
    return true
end
function AM:MatchingEnabledProfile()
    local match
    for _,name in ipairs(self:ProfileNames()) do
        if self:ProfileMatchesEnabled(name) then
            if match then return nil end -- Addon flags cannot distinguish layouts.
            match=name
        end
    end
    return match
end
function AM:LoadDraft()
    local f=self.ui; local stored=self.db.profiles[f.selected]
    f.draft={addons={}}
    if stored then
        for name,value in pairs(stored.addons) do f.draft.addons[name]=value end
        for _,entry in ipairs(self:Inventory()) do
            f.draft.addons[entry.name]=self:EffectiveState(stored,entry)
        end
    else
        f.draft.addons=self:LoadedSnapshot()
    end
    f.draft.captureSettings=stored and stored.captureSettings==true or false
    f.draft.addons[self.name]=true
    f.draftName=f.selected
end
function AM:SaveDraft()
    if not self:CanStartOperation() then return false end
    local f=self.ui
    local name,err=self:ValidName(f.profileName and f.profileName:GetText() or f.selected)
    if not name then self:Print(err); return nil end
    if not f.draft then return nil end
    local stored=self.db.profiles[name] or {}
    local copy={}; for addon,value in pairs(f.draft.addons) do copy[addon]=value end
    copy[self.name]=true; stored.addons=copy
    stored.captureSettings=f.draft.captureSettings==true
    if not stored.captureSettings then stored.settings=nil end
    self.db.profiles[name]=stored; f.selected=name; f.draftName=name
    if f.profileName then f.profileName:SetText(name) end
    self:RefreshUI()
    self:Print('Saved '..name..'. Switch with /ss '..name..'. No addons switched.')
    return name
end
function AM:RequestSave()
    local requested=self:ValidName(self.ui.profileName:GetText())
    local isNew=requested and not self.db.profiles[requested]
    local name=self:SaveDraft()
    if name then
        self:Print('Addon list saved. After addon or layout changes, activate '..name..', arrange the UI and any keybind changes, then Save settings & positions again.')
        if isNew then StaticPopup_Show('SETUPSWAP_NEW_PROFILE',name,nil,name) end
    end
end
function AM:RequestSettingsSave()
    if not self:CanStartOperation() then return false end
    if self.db.pendingBindings then self:Print('Wait for keybindings restoration to finish before saving settings.'); return false end
    if InCombatLockdown() then self:Print('Leave combat before saving settings.'); return false end
    local name,err=self:ValidName(self.ui.profileName:GetText())
    if not name then self:Print(err); return false end
    local profile=name and self.db.profiles[name]
    local mismatch=not profile or not self:ProfileMatchesEnabled(name)
    for _,entry in ipairs(self:Inventory()) do
        if not profile or self:EffectiveState(profile,entry)~=self:EffectiveState(self.ui.draft,entry) then
            mismatch=true
        end
    end
    if mismatch then
        local addons={}; for addon,value in pairs(self.ui.draft.addons) do addons[addon]=value end
        local current=self:MatchingEnabledProfile()
        local prompt='The selected profile "'..name..'" or its edited addon list does not match the addons currently enabled in game.'
        if current then prompt=prompt..'\n\nCurrent matching profile: '..current..'.' end
        prompt=prompt..'\n\nSave + Switch saves the shown addon list and activates it without capturing settings. After switching, arrange the UI and any keybind changes, then click Save settings & positions to capture them.'
        if profile then
            prompt=prompt..'\n\nOverwrite replaces "'..name..'" settings, positions, chat, and keybindings with the CURRENT in-game setup. Its saved addon list is kept; no profile switch occurs.'
        else
            prompt=prompt..'\n\nSave this new profile first. Overwrite is available only for an existing saved profile.'
        end
        local dialog=StaticPopup_Show('SETUPSWAP_SETTINGS_MISMATCH',prompt,nil,{name=name,addons=addons,captureSettings=self.ui.draft.captureSettings==true})
        if dialog then dialog:ClearAllPoints();dialog:SetPoint('CENTER',UIParent,'CENTER',0,UIParent:GetHeight()*.18) end
        return false
    end
    self.db.active=name
    profile.captureSettings=true; self.ui.draft.captureSettings=true
    self:RefreshUI()
    return self:BeginSettingsCapture(name,false)
end
function AM:ConfirmSettingsOverwrite(data)
    if not self:CanStartOperation() then return false end
    if self.db.pendingBindings then self:Print('Wait for keybindings restoration to finish before saving settings.'); return false end
    if InCombatLockdown() then self:Print('Leave combat before saving settings.'); return false end
    local name=data and self:ValidName(data.name)
    local profile=name and self.db.profiles[name]
    if not profile then self:Print('Save the profile first before overwriting its settings.'); return false end
    -- Explicitly overwrite only the snapshot. Keep the saved addon selection and
    -- active-profile identity; this action does not activate the selected setup.
    profile.captureSettings=true
    if self.ui and self.ui.selected==name then self.ui.draft.captureSettings=true;self:RefreshUI() end
    return self:BeginSettingsCapture(name,false)
end
function AM:DraftDiffers(name)
    local stored=self.db.profiles[name]
    if not stored then return true end
    if (stored.captureSettings==true)~=(self.ui.draft.captureSettings==true) then return true end
    for _,entry in ipairs(self:Inventory()) do
        if self:EffectiveState(stored,entry)~=self:EffectiveState(self.ui.draft,entry) then return true end
    end
    return false
end
function AM:RequestSwitch()
    if not self:CanStartOperation() then return false end
    if InCombatLockdown() then self:Print('Leave combat, then switch again. Nothing changed.'); return false end
    local f=self.ui
    local text=f.profileName:GetText()
    local name,err=self:ValidName(text)
    if not name and text:match('%S') then self:Print(err); return false end
    if name and not self:DraftDiffers(name) then return self:Switch(name) end
    local addons={}; for addon,value in pairs(f.draft.addons) do addons[addon]=value end
    local prompt=name and self.db.profiles[name] and ('Save changes to "'..name..'" before switching?')
        or 'Save this selection as a profile before switching. Enter a profile name:'
    StaticPopup_Show('SETUPSWAP_SAVE_AND_SWITCH',prompt,nil,{name=name or '',addons=addons,captureSettings=f.draft.captureSettings==true})
    return false
end
function AM:ConfirmSwitch(data, text)
    if not self:CanStartOperation() then return false end
    if InCombatLockdown() then self:Print('Leave combat, then switch again. Nothing changed.'); return false end
    local name,err=self:ValidName(text)
    if not name then self:Print(err); return false end
    self.ui.profileName:SetText(name)
    self.ui.draft={addons=data.addons,captureSettings=data.captureSettings==true}
    local saved=self:SaveDraft()
    return saved and self:Switch(saved) or false
end
function AM:LoadNamedProfile(selectedName)
    local f=self.ui; local name,err=self:ValidName(selectedName or f.profileName:GetText())
    if not name then self:Print(err); return end
    if not self.db.profiles[name] then self:Print('No saved profile named '..name..'. Use Save profile to create it.'); return end
    f.selected=name; f.draftName=nil; self:LoadDraft(); f.profileName:SetText(name); self:RefreshUI()
end
function AM:ShowProfileMenu(anchor)
    local f=self.ui
    if not f.profileMenu then
        f.profileMenu=CreateFrame('Frame','SetupSwapProfileMenu',UIParent,'UIDropDownMenuTemplate')
    end
    local menu={}
    for _,name in ipairs(self:ProfileNames()) do
        local profileName=name
        menu[#menu+1]={text=profileName,notCheckable=true,
            func=function() AM:LoadNamedProfile(profileName) end}
    end
    if #menu==0 then
        menu[1]={text='No saved profiles',disabled=true,notCheckable=true}
    end
    EasyMenu(menu,f.profileMenu,anchor,0,0,'MENU')
end
function AM:SelectAll(enabled)
    local f=self.ui
    for _,entry in ipairs(self:Inventory()) do f.draft.addons[entry.name]=enabled end
    f.draft.addons[self.name]=true
    self:RefreshRows()
end
function AM:CreateFromEditor(name)
    local created,err=self:CreateProfile(name)
    if not created then return nil,err end
    for addon,value in pairs(self.ui.draft.addons) do self.db.profiles[created].addons[addon]=value end
    self.db.profiles[created].addons[self.name]=true
    self.ui.selected=created; self.ui.draftName=nil
    self:RefreshUI()
    return created
end
function AM:RefreshUI()
    local f=self.ui; if not f then return end
    if not f.draft then self:LoadDraft() end
    f.status:SetText('Last applied: '..(self.db.active or 'none')..'  |  Saved profiles: '..table.concat(self:ProfileNames(),', '))
    if f.includeSettings then f.includeSettings:SetChecked(f.draft.captureSettings==true) end
    self:RefreshRows()
end
function AM:BlockedDependencies(profile, entry, byName, visiting)
    visiting=visiting or {}
    if visiting[entry.name] then return true end
    visiting[entry.name]=true
    for _,dep in ipairs(entry.dependencies) do
        if dep and dep~='' then
            local required=byName[dep]
            if not required or not self:EffectiveState(profile,required) or self:BlockedDependencies(profile,required,byName,visiting) then
                visiting[entry.name]=nil; return true
            end
        end
    end
    visiting[entry.name]=nil; return false
end
function AM:RefreshRows()
    local f=self.ui; if not f then return end
    local list,byName=self:Inventory()
    f.entries=list
    FauxScrollFrame_Update(f.scroll,#list,#f.rows,26)
    local offset=FauxScrollFrame_GetOffset(f.scroll)
    local profile=f.draft
    if not profile then return end
    for i,row in ipairs(f.rows) do
        local entry=list[offset+i]
        if entry then
            row.entry=entry; row.check:SetChecked(self:EffectiveState(profile,entry))
            row.blocked=entry.name~=self.name and self:BlockedDependencies(profile,entry,byName)
            row.title:SetText((entry.title:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')))
            local shade=row.blocked and .45 or 1
            row.title:SetTextColor(shade,shade,shade)
            row.check:SetAlpha(shade)
            row.folder:SetText(entry.name..(IsAddOnLoadOnDemand(entry.name) and ' (on demand)' or ''))
            if entry.name==self.name then
                row.check:Disable(); row.folder:SetText(entry.name..' (always on; protected)')
            else row.check:Enable() end
            row:Show()
        else row:Hide(); row.entry=nil end
    end
end
function AM:ShowUI()
    if not self.db then return end
    if not self.ui then self:BuildUI() end
    if not self.ui:IsShown() then
        self.ui.selected=self:MatchingEnabledProfile()
        self.ui.draft=nil;self:LoadDraft()
        self.ui.profileName:SetText(self.ui.selected or '')
    end
    self:RefreshUI(); self.ui:Show()
end
function AM:BuildUI()
    local f=CreateFrame('Frame','SetupSwapWindow',UIParent)
    self.ui=f; f.selected=nil;f:Hide()
    f:SetSize(690,658); f:SetPoint('CENTER'); f:SetFrameStrata('DIALOG')
    f:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=32,insets={left=11,right=12,top=12,bottom=11}})
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag('LeftButton')
    f:SetScript('OnDragStart',function(self) self:StartMoving() end)
    f:SetScript('OnDragStop',function(self) self:StopMovingOrSizing() end)
    tinsert(UISpecialFrames,'SetupSwapWindow')
    local close=CreateFrame('Button',nil,f,'UIPanelCloseButton'); close:SetPoint('TOPRIGHT',-6,-6)
    label(f,'SetupSwap '..(GetAddOnMetadata(self.name,'Version') or '1.0.0'),22,-20,'GameFontNormalLarge')
    label(f,'1. Save profile ONLY saves enabled/disabled addons. Switch + Reload activates it.',22,-48,'GameFontHighlightSmall')
    label(f,'2. Save AND switch first. Arrange UI and any keybind changes, then Save settings & positions.',22,-65,'GameFontHighlightSmall')
    f.status=label(f,'',22,-86,'GameFontHighlightSmall')
    label(f,'Profile name (quick switch with /ss followed by this name):',22,-108,'GameFontHighlightSmall')
    f.profileName=edit(f,260,26,-130)
    local placeholder=f.profileName:CreateFontString(nil,'OVERLAY','GameFontDisableSmall')
    placeholder:SetPoint('LEFT',f.profileName,'LEFT',2,0)
    placeholder:SetText('ex: desktop, gamepad, raiding, questing')
    f.profileName:SetScript('OnTextChanged',function(self)
        if self:GetText()=='' then placeholder:Show() else placeholder:Hide() end
    end)
    button(f,'Save profile',125,300,-130,function() AM:RequestSave() end)
    button(f,'Select profile',145,430,-130,function(self) AM:ShowProfileMenu(self) end)
    button(f,'Delete',85,580,-130,function()
        local name=AM:ValidName(f.profileName:GetText())
        if not name or not AM.db.profiles[name] then AM:Print('Enter a saved profile name to delete.'); return end
        StaticPopup_Show('SETUPSWAP_DELETE_PROFILE',name,nil,name)
    end)
    label(f,'Current matching profile opens automatically. Select another to edit it.',22,-164,'GameFontHighlightSmall')
    local addonWarning=label(f,'New addons: save the profile, then SWITCH TO IT before saving settings.\nSaving/selecting here does not activate it, you must click Switch and Reload.\nOtherwise, saving settings overwrites that profile with the current setup.',22,-178,'GameFontHighlightSmall')
    addonWarning:SetWidth(630);addonWarning:SetJustifyH('LEFT')
    f.includeSettings=CreateFrame('CheckButton',nil,f,'UICheckButtonTemplate')
    f.includeSettings:SetSize(24,24); f.includeSettings:SetPoint('TOPLEFT',22,-230)
    label(f,'Restore saved settings when switching',52,-236,'GameFontHighlightSmall')
    f.includeSettings:SetScript('OnClick',function(self) f.draft.captureSettings=self:GetChecked() and true or false end)
    f.includeSettings:SetScript('OnEnter',function(self)
        GameTooltip:SetOwner(self,'ANCHOR_RIGHT'); GameTooltip:SetText('Restore saved settings when switching')
        GameTooltip:AddLine('Save profile stores the addon list only. Save settings & positions captures addon settings, positions, chat and current WoW keybindings. Unchecking this and saving removes this profile\'s settings snapshot.',1,1,1,true)
        GameTooltip:AddLine('After changing keybindings, save settings again for each active profile. Older profiles keep current bindings until captured.',1,1,1,true)
        GameTooltip:AddLine('Saving settings reloads once. Profile switches attempt one reload with the startup helper; a second reload is requested if early restoration is unavailable. /ss undo restores the last settings backup.',1,.82,0,true)
        local profile=AM.db.profiles[f.selected]
        local saved=profile and profile.settings
        if saved then
            GameTooltip:AddLine('Saved: '..tostring(saved.addons or 0)..' addons, '..tostring(#(saved.layouts or {}))..' movable windows.',.6,1,.6,true)
            if #(saved.skipped or {})>0 then
                GameTooltip:AddLine('Settings not captured: '..#saved.skipped,1,.4,.2,true)
                for i=1,math.min(8,#saved.skipped) do GameTooltip:AddLine(saved.skipped[i],1,.7,.5,true) end
            end
            local coverage=saved.coverage
            if coverage then
                GameTooltip:AddLine('Protected movable frames: '..coverage.protected..'; unnamed movable frames: '..coverage.unnamed..'. These require addon settings or integrations.',1,.82,0,true)
            end
        end
        GameTooltip:Show()
    end)
    f.includeSettings:SetScript('OnLeave',function() GameTooltip:Hide() end)
    label(f,'Checked = enabled. Gray = blocked by a requirement.',22,-262,'GameFontHighlightSmall')
    button(f,'Save settings & positions',205,435,-248,function() AM:RequestSettingsSave() end)
    f.scroll=CreateFrame('ScrollFrame','SetupSwapAddonScroll',f,'FauxScrollFrameTemplate')
    f.scroll:SetPoint('TOPLEFT',22,-284); f.scroll:SetSize(622,286)
    f.scroll:SetScript('OnVerticalScroll',function(self,offset) FauxScrollFrame_OnVerticalScroll(self,offset,26,function() AM:RefreshRows() end) end)
    f.rows={}
    for i=1,11 do
        local row=CreateFrame('Frame',nil,f); row:SetPoint('TOPLEFT',22,-284-(i-1)*26); row:SetSize(615,26)
        row.check=CreateFrame('CheckButton',nil,row,'UICheckButtonTemplate'); row.check:SetSize(24,24); row.check:SetPoint('LEFT',0,0)
        row.title=row:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall'); row.title:SetPoint('LEFT',30,0); row.title:SetWidth(290); row.title:SetJustifyH('LEFT')
        row.folder=row:CreateFontString(nil,'OVERLAY','GameFontDisableSmall'); row.folder:SetPoint('LEFT',325,0); row.folder:SetWidth(280); row.folder:SetJustifyH('LEFT')
        row.check:SetScript('OnClick',function(self)
            if not row.entry then return end
            local ok,err=AM:SetSelection(f.selected,row.entry.name,self:GetChecked() and true or false,f.draft)
            if not ok then AM:Print(err) end
            AM:RefreshRows()
        end)
        row:EnableMouse(true)
        row:SetScript('OnEnter',function(self)
            if not self.entry then return end
            GameTooltip:SetOwner(self,'ANCHOR_RIGHT'); GameTooltip:SetText(self.entry.name)
            if self.entry.notes then GameTooltip:AddLine(self.entry.notes,1,1,1,true) end
            if #self.entry.dependencies>0 then GameTooltip:AddLine('Requires: '..table.concat(self.entry.dependencies,', '),1,.82,0,true) end
            if self.blocked then GameTooltip:AddLine('Inactive: required dependency unchecked or unavailable. Your selection is retained; restore the requirement to load this addon.',.65,.65,.65,true) end
            GameTooltip:Show()
        end)
        row:SetScript('OnLeave',function() GameTooltip:Hide() end)
        f.rows[i]=row
    end
    button(f,'Use current',110,22,-588,function() f.draft.addons=AM:LoadedSnapshot(); AM:RefreshRows() end)
    button(f,'Select all',95,142,-588,function() AM:SelectAll(true) end)
    button(f,'Deselect all',100,247,-588,function() AM:SelectAll(false) end)
    button(f,'Switch + Reload',155,487,-588,function() AM:RequestSwitch() end)
    local guidance=label(f,'Save the profile, then switch to it. Saving alone does not activate it.\nSave settings includes positions, chat, and keybindings. Save only while that profile is active.',22,-618,'GameFontHighlightSmall')
    guidance:SetWidth(610);guidance:SetJustifyH('LEFT')
    StaticPopupDialogs.SETUPSWAP_SAVE_AND_SWITCH={
        text='%s',button1='Save + Switch',button2='Cancel',hasEditBox=true,
        timeout=0,whileDead=true,hideOnEscape=true,
        OnShow=function(self) self.editBox:SetText(self.data.name); self.editBox:SetFocus() end,
        OnAccept=function(self,data) AM:ConfirmSwitch(data or self.data,self.editBox:GetText()) end,
        EditBoxOnEnterPressed=function(self) self:GetParent().button1:Click() end,
        EditBoxOnEscapePressed=function(self) self:GetParent():Hide() end,
    }
    StaticPopupDialogs.SETUPSWAP_NEW_PROFILE={
        text='Profile "%s" saved: enabled/disabled addons only. Settings, positions and keybindings have not been captured.\n\nEnable its addons now so you can arrange the UI and any keybind changes?\n\nAfter reload, arrange that setup, reopen /ss and click Save settings & positions. This captures addon settings, positions, chat, and keybindings.',
        button1='Enable + Reload',button2='Later',timeout=0,whileDead=true,hideOnEscape=true,
        OnAccept=function(self,data) AM:Switch(data or self.data) end,
    }
    StaticPopupDialogs.SETUPSWAP_SETTINGS_MISMATCH={
        text='%s',button1='Save + Switch',button2='Overwrite',button3='Cancel',timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3,
        OnShow=function(self)
            self:ClearAllPoints();self:SetPoint('CENTER',UIParent,'CENTER',0,UIParent:GetHeight()*.18)
            if AM.db.profiles[self.data.name] then self.button2:Enable() else self.button2:Disable() end
        end,
        OnAccept=function(self,data)
            local selection=data or self.data
            AM:ConfirmSwitch(selection,selection.name)
        end,
        OnCancel=function(self,data,reason)
            -- Button 2 is Overwrite; Escape/replacement must remain cancellation.
            if reason=='clicked' then AM:ConfirmSettingsOverwrite(data or self.data) end
        end,
    }
    StaticPopupDialogs.SETUPSWAP_DELETE_PROFILE={
        text='Delete SetupSwap profile "%s"?',button1='Delete',button2='Cancel',timeout=0,whileDead=true,hideOnEscape=true,
        OnAccept=function(self,data)
            local name=data or self.data
            local ok,err=AM:DeleteProfile(name); if not ok then AM:Print(err) end
            if ok and f.selected==name then f.selected=nil; f.draft=nil; f.profileName:SetText('') end
            AM:RefreshUI()
        end,
    }
end
