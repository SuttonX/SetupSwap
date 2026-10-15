local AM = SetupSwap
local function label(parent, text, font)
    local fs=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontNormal')
    fs:SetText(text);fs:SetJustifyH('LEFT');return fs
end
local function button(parent, text, handler)
    local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
    b:SetText(text);b:SetScript('OnClick',handler);return b
end
local function edit(parent)
    local e=CreateFrame('EditBox',nil,parent,'InputBoxTemplate')
    e:SetAutoFocus(false)
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
    f.draft.customize=self:HasCharacterOverrides(stored)
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
    copy[self.name]=true
    if not self.db.profiles[name] then stored.addons=self:Snapshot() end
    self:SaveAddonSelection(stored,copy,f.draft.customize)
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
        self:Print('Addon list saved. After addon or layout changes, activate '..name..', arrange the UI and abilities, then Save Addon Settings + Positions again.')
        if isNew then StaticPopup_Show('SETUPSWAP_NEW_PROFILE',name,nil,name) end
    end
end
function AM:RequestSettingsSave()
    if not self:CanStartOperation() then return false end
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
        prompt=prompt..'\n\nSave + Switch saves the shown addon list and activates it without capturing settings. After switching, arrange the UI and abilities, then click Save Addon Settings + Positions to capture them.'
        if profile then
            prompt=prompt..'\n\nOverwrite replaces "'..name..'" addon settings, positions, and chat with the CURRENT in-game setup. Its saved addon list is kept; no profile switch occurs.'
        else
            prompt=prompt..'\n\nSave this new profile first. Overwrite is available only for an existing saved profile.'
        end
        local dialog=StaticPopup_Show('SETUPSWAP_SETTINGS_MISMATCH',prompt,nil,{name=name,addons=addons,captureSettings=self.ui.draft.captureSettings==true,customize=self.ui.draft.customize==true})
        if dialog then dialog:ClearAllPoints();dialog:SetPoint('CENTER',UIParent,'CENTER',0,UIParent:GetHeight()*.18) end
        return false
    end
    self.db.active=name
    profile.captureSettings=true; self.ui.draft.captureSettings=true
    self:RefreshUI()
    return self:BeginSettingsCapture(name,false)
end
function AM:RequestActionBarsSave()
    local name,err=self:ValidName(self.ui.profileName:GetText())
    if not name then self:Print(err);return false end
    if not self:SaveActionBarsOnly(name) then return false end
    self.ui.draft.captureSettings=true
    self:RefreshUI()
    return true
end
function AM:ConfirmSettingsOverwrite(data)
    if not self:CanStartOperation() then return false end
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
    if self:HasCharacterOverrides(stored)~=(self.ui.draft.customize==true) then return true end
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
    StaticPopup_Show('SETUPSWAP_SAVE_AND_SWITCH',prompt,nil,{name=name or '',addons=addons,captureSettings=f.draft.captureSettings==true,customize=f.draft.customize==true})
    return false
end
function AM:ConfirmSwitch(data, text)
    if not self:CanStartOperation() then return false end
    if InCombatLockdown() then self:Print('Leave combat, then switch again. Nothing changed.'); return false end
    local name,err=self:ValidName(text)
    if not name then self:Print(err); return false end
    self.ui.profileName:SetText(name)
    self.ui.draft={addons=data.addons,captureSettings=data.captureSettings==true,customize=data.customize==true}
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
    self:SaveAddonSelection(self.db.profiles[created],self.ui.draft.addons,self.ui.draft.customize)
    self.ui.selected=created; self.ui.draftName=nil
    self:RefreshUI()
    return created
end
function AM:RefreshUI()
    local f=self.ui; if not f then return end
    if not f.draft then self:LoadDraft() end
    f.status:SetText('Last applied: '..(self.db.active or 'none')..'  |  Saved profiles: '..#self:ProfileNames())
    if f.characterOnly then f.characterOnly:SetChecked(f.draft.customize==true) end
    if f.scope then f.scope:SetText(f.draft.customize and ('Character overrides: '..self:CharacterKey()) or 'Shared addon selection') end
    if f.saveProfile then f.saveProfile:SetText(f.draft.customize and 'Save overrides' or 'Save shared') end
    if f.includeSettings then f.includeSettings:SetChecked(f.draft.captureSettings==true) end
    self:LayoutUI()
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
    FauxScrollFrame_Update(f.scroll,#list,f.visibleRows or #f.rows,f.rowHeight or 1)
    local offset=FauxScrollFrame_GetOffset(f.scroll)
    local profile=f.draft
    if not profile then return end
    for i,row in ipairs(f.rows) do
        local entry=i<=(f.visibleRows or #f.rows) and list[offset+i] or nil
        if entry then
            row.entry=entry; row.check:SetChecked(self:EffectiveState(profile,entry))
            row.blocked=entry.name~=self.name and self:BlockedDependencies(profile,entry,byName)
            row.title:SetText((entry.title:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')))
            local shade=row.blocked and .45 or 1
            row.title:SetTextColor(shade,shade,shade)
            row.check:SetAlpha(shade)
            row.folder:SetText(entry.name..(f.draft.customize and AM.db.profiles[f.selected] and ((f.draft.addons[entry.name]==true)~=(AM.db.profiles[f.selected].addons[entry.name]==true)) and ' [override]' or '')..(IsAddOnLoadOnDemand(entry.name) and ' (on demand)' or ''))
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
    self:RefreshUI();if self.ApplyElvUISkin then self:ApplyElvUISkin(self.ui) end;self.ui:Show()
end
function AM:FitUIToScreen()
    local f=self.ui;if not f or not UIParent then return end
    local height=UIParent:GetHeight()*.65
    local width=math.min(UIParent:GetWidth()*.90,height*1.08)
    if width<=0 or height<=0 then return end
    f:SetSize(width,height)
    self:LayoutUI()
end
function AM:LayoutUI()
    local f=self.ui
    if not f or not f.guidance or f.layingOut then return end
    local width,height=f:GetWidth(),f:GetHeight()
    if not width or not height or width<=0 or height<=0 then return end
    f.layingOut=true
    local unit=math.min(width,height)*.017
    local pad=width*.035
    local gap=unit*.55
    local content=width-pad*2
    local buttonHeight=unit*2.3
    local checkSize=unit*2.1
    local y=height*.025
    local function font(object,size)
        local E=f.elvUISkinned and type(_G.ElvUI)=='table' and _G.ElvUI[1]
        if E and E.db and E.db.general and object.FontTemplate then object:FontTemplate(nil,size);return end
        local path,_,flags=object:GetFont()
        object:SetFont(path or STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF',size,flags)
    end
    local function rect(object,x,top,w,h,parent)
        object:ClearAllPoints()
        object:SetPoint('TOPLEFT',parent or f,'TOPLEFT',x,-top)
        object:SetWidth(w);object:SetHeight(h)
    end
    local function text(object,size,w)
        font(object,size or unit)
        object:SetWidth(w or content);object:SetHeight(0)
        local h=math.max(unit,object:GetStringHeight())
        object:SetHeight(h);return h
    end
    local function flow(object,size,indent)
        indent=indent or 0
        local h=text(object,size,content-indent)
        rect(object,pad+indent,y,content-indent,h)
        y=y+h+gap
    end
    local function controls(container,objects,shares,top)
        rect(container,pad,top,content,buttonHeight)
        local available=content-gap*(#objects-1)
        local x=0
        for i,object in ipairs(objects) do
            local w=available*shares[i]
            rect(object,x,0,w,buttonHeight,container)
            local fs=object.GetFontString and object:GetFontString() or object
            font(fs,unit)
            if fs.SetWordWrap then fs:SetWordWrap(false) end
            if fs.GetStringWidth then
                local measured=fs:GetStringWidth()
                if measured>w-gap*2 then font(fs,unit*(w-gap*2)/measured) end
            end
            x=x+w+gap
        end
    end
    local function checkbox(check,caption)
        local h=text(caption,unit,content-checkSize-gap)
        h=math.max(checkSize,h)
        rect(check,pad,y,checkSize,checkSize)
        rect(caption,pad+checkSize+gap,y+(h-caption:GetHeight())/2,content-checkSize-gap,caption:GetHeight())
        y=y+h+gap
    end
    f.close:ClearAllPoints();f.close:SetPoint('TOPRIGHT',f,'TOPRIGHT',-pad*.3,-height*.008)
    f.close:SetSize(unit*2.5,unit*2.5)
    flow(f.heading,unit*1.5)
    for _,step in ipairs(f.steps) do flow(step) end
    flow(f.status)
    flow(f.profileLabel)
    controls(f.profileControls,{f.profileName,f.saveProfile,f.selectProfile,f.deleteProfile},{.40,.20,.25,.15},y)
    f.placeholder:ClearAllPoints();f.placeholder:SetPoint('LEFT',f.profileName,'LEFT',gap,0)
    font(f.placeholder,unit);f.placeholder:SetWidth(f.profileName:GetWidth()-gap*2)
    y=y+buttonHeight+gap
    flow(f.selectionHint)
    flow(f.addonWarning)
    checkbox(f.includeSettings,f.includeLabel)
    checkbox(f.characterOnly,f.characterLabel)
    flow(f.scope,unit,checkSize+gap)
    controls(f.captureControls,{f.saveSettings,f.barsOnly},{.5,.5},y)
    y=y+buttonHeight+gap
    flow(f.legend)

    -- Bottom controls reserve their space; the list takes the remaining height.
    local guidanceHeight=text(f.guidance)
    local guidanceTop=height-height*.025-guidanceHeight
    rect(f.guidance,pad,guidanceTop,content,guidanceHeight)
    local footerTop=guidanceTop-gap-buttonHeight
    controls(f.footerControls,{f.useCurrent,f.selectAll,f.deselectAll,f.switchProfile},{.23,.19,.20,.38},footerTop)
    local listHeight=math.max(0,footerTop-gap-y)
    f.rowHeight=unit*2.2
    f.visibleRows=math.min(#f.rows,math.max(1,math.floor(listHeight/f.rowHeight)))
    local listWidth=content-unit*2.2 -- room for the native scrollbar
    rect(f.scroll,pad,y,listWidth,listHeight)
    for i,row in ipairs(f.rows) do
        rect(row,0,(i-1)*f.rowHeight,listWidth,f.rowHeight,f.scroll)
        rect(row.check,0,(f.rowHeight-checkSize)/2,checkSize,checkSize,row)
        local remaining=listWidth-checkSize-gap*2
        rect(row.title,checkSize+gap,0,remaining*.52,f.rowHeight,row)
        rect(row.folder,checkSize+gap+remaining*.52+gap,0,remaining*.48,f.rowHeight,row)
        font(row.title,unit);font(row.folder,unit)
        for _,fs in ipairs({row.title,row.folder}) do
            if fs.SetWordWrap then fs:SetWordWrap(false) end
        end
        if i>f.visibleRows then row:Hide() end
    end
    if self.LayoutElvUISkin then self:LayoutElvUISkin(f,unit) end
    f.layingOut=nil
end
function AM:BuildUI()
    local f=CreateFrame('Frame','SetupSwapWindow',UIParent)
    self.ui=f; f.selected=nil;f:Hide()
    f:SetPoint('CENTER'); f:SetFrameStrata('DIALOG');f:SetClampedToScreen(true)
    f:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=32,insets={left=11,right=12,top=12,bottom=11}})
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag('LeftButton')
    f:SetScript('OnDragStart',function(self) self:StartMoving() end)
    f:SetScript('OnDragStop',function(self) self:StopMovingOrSizing() end)
    tinsert(UISpecialFrames,'SetupSwapWindow')
    f.close=CreateFrame('Button',nil,f,'UIPanelCloseButton')
    local version=tostring(GetAddOnMetadata(self.name,'Version') or 'unknown'):gsub('^v','')
    f.heading=label(f,'SetupSwap v'..(version:match('^%d+%.%d+%.%d+') or version),'GameFontNormalLarge')
    f.steps={
        label(f,'1. Save shared / Save overrides saves addon choices. Switch + Reload activates them.','GameFontHighlightSmall'),
        label(f,'2. Activate a profile, then save its settings or just this character\'s bars/macros.','GameFontHighlightSmall'),
    }
    f.status=label(f,'','GameFontHighlightSmall')
    f.profileLabel=label(f,'Profile name (quick switch with /ss followed by this name):','GameFontHighlightSmall')
    f.profileControls=CreateFrame('Frame',nil,f)
    f.profileName=edit(f)
    f.placeholder=f.profileName:CreateFontString(nil,'OVERLAY','GameFontDisableSmall')
    f.placeholder:SetText('ex: desktop, gamepad, raiding')
    f.profileName:SetScript('OnTextChanged',function(self)
        if self:GetText()=='' then f.placeholder:Show() else f.placeholder:Hide() end
    end)
    f.saveProfile=button(f,'Save profile',function() AM:RequestSave() end)
    f.selectProfile=button(f,'Select profile',function(self) AM:ShowProfileMenu(self) end)
    f.deleteProfile=button(f,'Delete',function()
        local name=AM:ValidName(f.profileName:GetText())
        if not name or not AM.db.profiles[name] then AM:Print('Enter a saved profile name to delete.');return end
        StaticPopup_Show('SETUPSWAP_DELETE_PROFILE',name,nil,name)
    end)
    f.selectionHint=label(f,'Current matching profile opens automatically. Select another to edit it.','GameFontHighlightSmall')
    f.addonWarning=label(f,'New addons: save the addon list, then SWITCH TO THE PROFILE before capturing settings. Saving or selecting here does not activate it. A full settings save replaces the shared layout.','GameFontHighlightSmall')
    f.includeSettings=CreateFrame('CheckButton',nil,f,'UICheckButtonTemplate')
    f.includeLabel=label(f,'Restore saved settings when switching','GameFontHighlightSmall')
    f.includeSettings:SetScript('OnClick',function(self) f.draft.captureSettings=self:GetChecked() and true or false end)
    f.includeSettings:SetScript('OnEnter',function(self)
        GameTooltip:SetOwner(self,'ANCHOR_RIGHT'); GameTooltip:SetText('Restore saved settings when switching')
        GameTooltip:AddLine('Save profile stores the addon list only. Save Addon Settings + Positions captures addon settings, positions and chat, preserving saved bars/macros. Unchecking this and saving removes this profile\'s settings snapshot.',1,1,1,true)
        GameTooltip:AddLine('Saving settings reloads once. Profile switches attempt one reload with the startup helper; a second reload is requested if early restoration is unavailable. /ss undo restores the last settings backup.',1,.82,0,true)
        GameTooltip:AddLine('Action bars are saved separately for each character and talent spec. Missing or ambiguous actions leave their slots unchanged; /ss log lists them.',1,1,1,true)
        GameTooltip:AddLine('Macros keep their current contents. Tracked ordinary macros support blank names and editing commands, names or icons without resaving. Keep SetupSwap enabled to track changes. Managed macros such as SmartTravel also check stable ownership.',1,1,1,true)
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
    f.characterOnly=CreateFrame('CheckButton',nil,f,'UICheckButtonTemplate')
    f.characterLabel=label(f,'Customize addons for this specific character','GameFontHighlightSmall')
    f.scope=label(f,'','GameFontHighlightSmall')
    f.characterOnly:SetScript('OnClick',function(self)
        local enabled=self:GetChecked() and true or false
        local stored=AM.db.profiles[f.selected]
        if not enabled then
            f.draft.addons={}
            for addon,value in pairs(stored and stored.addons or AM:Snapshot()) do f.draft.addons[addon]=value end
            f.draft.addons[AM.name]=true
        end
        f.draft.customize=enabled;AM:RefreshUI()
    end)
    f.characterOnly:SetScript('OnEnter',function(self)
        GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText('Customize addons for this specific character')
        GameTooltip:AddLine('Save only this character\'s addon differences for this profile. Other characters keep the shared selection. Shared changes still apply to addons you have not overridden.',1,1,1,true)
        GameTooltip:AddLine('Uncheck and save to remove this character\'s overrides. Addon settings, positions and chat remain shared; abilities are separate by character and talent spec. SetupSwap does not save or restore WoW keybindings.',1,1,1,true)
        GameTooltip:Show()
    end)
    f.characterOnly:SetScript('OnLeave',function() GameTooltip:Hide() end)
    f.captureControls=CreateFrame('Frame',nil,f)
    f.legend=label(f,'Checked = enabled. Gray = blocked by a requirement.','GameFontHighlightSmall')
    local barsOnly=button(f,'Save Action Bars / Macros',function() AM:RequestActionBarsSave() end)
    f.barsOnly=barsOnly
    barsOnly:SetScript('OnEnter',function(self)
        GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText('Save Action Bars / Macros')
        GameTooltip:AddLine('Save ability and macro placements for this character and talent spec without changing shared addon settings, positions, chat or addon selections. Activate the profile first. No reload is needed.',1,1,1,true)
        GameTooltip:Show()
    end)
    barsOnly:SetScript('OnLeave',function() GameTooltip:Hide() end)
    f.saveSettings=button(f,'Save Addon Settings + Positions',function() AM:RequestSettingsSave() end)
    f.saveSettings:SetScript('OnEnter',function(self)
        GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText('Save Addon Settings + Positions')
        GameTooltip:AddLine('Capture shared addon settings, window positions and chat. Saved action bars and macros for every character/spec are preserved. Reloads once to flush addon settings.',1,1,1,true)
        GameTooltip:Show()
    end)
    f.saveSettings:SetScript('OnLeave',function() GameTooltip:Hide() end)
    f.scroll=CreateFrame('ScrollFrame','SetupSwapAddonScroll',f,'FauxScrollFrameTemplate')
    f.scroll:SetScript('OnVerticalScroll',function(self,offset) FauxScrollFrame_OnVerticalScroll(self,offset,f.rowHeight or 1,function() AM:RefreshRows() end) end)
    f.rows={}
    for i=1,20 do
        local row=CreateFrame('Frame',nil,f)
        row.check=CreateFrame('CheckButton',nil,row,'UICheckButtonTemplate')
        row.title=label(row,'','GameFontHighlightSmall')
        row.folder=label(row,'','GameFontDisableSmall')
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
    f.footerControls=CreateFrame('Frame',nil,f)
    f.useCurrent=button(f,'Use current',function() f.draft.addons=AM:LoadedSnapshot();AM:RefreshRows() end)
    f.selectAll=button(f,'Select all',function() AM:SelectAll(true) end)
    f.deselectAll=button(f,'Deselect all',function() AM:SelectAll(false) end)
    f.switchProfile=button(f,'Switch + Reload',function() AM:RequestSwitch() end)
    f.guidance=label(f,'Addon settings saves update the shared layout. Bars/macros saves this character/spec.\nActivate the profile before capturing. Editing a tracked macro needs no new save.','GameFontHighlightSmall')
    f:SetScript('OnSizeChanged',function() AM:LayoutUI();if f.draft then AM:RefreshRows() end end)
    f:RegisterEvent('DISPLAY_SIZE_CHANGED');f:RegisterEvent('UI_SCALE_CHANGED')
    f:SetScript('OnEvent',function() AM:FitUIToScreen() end)
    self:FitUIToScreen()
    if self.ApplyElvUISkin then self:ApplyElvUISkin(f) end
    StaticPopupDialogs.SETUPSWAP_SAVE_AND_SWITCH={
        text='%s',button1='Save + Switch',button2='Cancel',hasEditBox=true,
        timeout=0,whileDead=true,hideOnEscape=true,
        OnShow=function(self) self.editBox:SetText(self.data.name); self.editBox:SetFocus() end,
        OnAccept=function(self,data) AM:ConfirmSwitch(data or self.data,self.editBox:GetText()) end,
        EditBoxOnEnterPressed=function(self) self:GetParent().button1:Click() end,
        EditBoxOnEscapePressed=function(self) self:GetParent():Hide() end,
    }
    StaticPopupDialogs.SETUPSWAP_NEW_PROFILE={
        text='Profile "%s" saved: enabled/disabled addons only. Settings, positions and action bars have not been captured.\n\nEnable its addons now so you can arrange the UI and abilities?\n\nAfter reload, arrange that setup, reopen /ss and click Save Addon Settings + Positions. This captures addon settings, positions and chat. Use Save Action Bars / Macros separately for ability placements.',
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
        text='Delete SetupSwap profile "%s" and its overrides for every character?',button1='Delete',button2='Cancel',timeout=0,whileDead=true,hideOnEscape=true,
        OnAccept=function(self,data)
            local name=data or self.data
            local ok,err=AM:DeleteProfile(name); if not ok then AM:Print(err) end
            if ok and f.selected==name then f.selected=nil; f.draft=nil; f.profileName:SetText('') end
            AM:RefreshUI()
        end,
    }
end
