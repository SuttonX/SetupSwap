local AM=SetupSwap
local recent={}
function AM:DiagnosticsText()
    local lines={}
    local function line(text) lines[#lines+1]=tostring(text) end
    for _,notice in ipairs((self.db and self.db.unsupportedChatNotices) or {}) do
        line('Unsupported channel notice: '..notice.notice..' / '..notice.channel)
    end
    local entries=self.db and self.db.blockedActions or recent
    if #entries==0 then line('No blocked addon actions recorded.') end
    for i=math.max(1,#entries-9),#entries do
        local item=entries[i]
        line(item.event..': '..item.addon..' -> '..item.operation..(item.context and (' ['..item.context..']') or ''))
        if item.stack then line(item.stack) end
    end
    line('SetupSwap version: '..tostring(GetAddOnMetadata and GetAddOnMetadata(self.name,'Version') or 'unknown'))
    line('Options window ElvUI skin: '..tostring(self.ui and self.ui.elvUISkinned or false))
    if self.elvUISkinError then line('ElvUI skin error: '..self.elvUISkinError) end
    line('Startup native refresh callbacks: '..tostring(self.db and self.db.lastStartupRefresh or 'none'))
    line('Startup helper: '..(SetupSwapEarlyLoader and 'loaded' or 'unavailable'))
    line('Observed minimap mask: '..tostring(self.minimapMask or (SetupSwapEarlyLoader and SetupSwapEarlyLoader.minimapMask) or 'not observed'))
    local macroBook=self.db and self.db.macroIdentities
    if macroBook then
        local accountCount,characterCount=0,0
        for _ in pairs(macroBook.account or {}) do accountCount=accountCount+1 end
        for _ in pairs(macroBook.characters and macroBook.characters[self:CharacterKey()] or {}) do characterCount=characterCount+1 end
        line('Tracked native macros: account='..accountCount..'; current character='..characterCount)
    end
    if type(TomTom)=='table' and TomTom.db then
        line('TomTom settings cache: '..tostring(TomTom.profile==TomTom.db.profile)..'; persistence='..type(TomTom.profile and TomTom.profile.persistence))
        local arrow=TomTom.db.profile and TomTom.db.profile.arrow
        local position=arrow and arrow.position
        line('TomTom native arrow anchor: '..tostring(position and position.point)..'; '..tostring(position and position.relativeTo)..'; x='..tostring(position and position.x)..'; y='..tostring(position and position.y))
        if TomTomCrazyArrow and TomTomCrazyArrow.GetPoint then
            local point,relative,rel,x,y=TomTomCrazyArrow:GetPoint(1)
            line('TomTom live arrow anchor: '..tostring(point)..'; '..tostring(relative and relative.GetName and relative:GetName())..'; '..tostring(rel)..'; x='..tostring(x)..'; y='..tostring(y))
        end
    end
    local mode=self.db and self.db.lastRestoreMode
    if mode then line('Last settings restore: '..tostring(mode.name)..'; '..tostring(mode.mode)..(mode.reason and ('; '..mode.reason) or '')..(mode.seeded and ('; seeded native databases='..mode.seeded) or '')) end
    local windows=self.db and self.db.lastWindowRestore
    local chat=self.db and self.db.lastChatRestore
    if windows then line('Last window restore: '..tostring(windows.name)..'; applied='..tostring(windows.count)) end
    if chat then line('Last chat restore: '..(chat.ok and 'completed' or tostring(chat.error))) end
    local actions=self.db and self.db.lastActionBarRestore
    if actions then
        line('Last action-bar restore: '..tostring(actions.name)..'; '..(actions.ok and ('changed slots='..tostring(actions.count)) or tostring(actions.error)))
        for _,reason in ipairs(actions.skipped or {}) do line('  '..reason) end
    end
    line('Active profile: '..tostring(self.db and self.db.active or 'none'))
    local names={}
    for name in pairs(self.db and self.db.profiles or {}) do names[#names+1]=name end
    table.sort(names)
    for _,name in ipairs(names) do
        local profile=self.db.profiles[name]
        local snapshot=profile.settings or {}
        line(name..': addon selection='..(self:HasCharacterOverrides(profile) and ('character overrides ('..self:CharacterKey()..')') or 'shared'))
        line('  Action bars for current character/spec: '..(self:SavedActionBars(snapshot) and 'captured' or 'not captured'))
        line(name..': restore='..tostring(profile.captureSettings)..'; addon windows='..#(snapshot.layouts or {})..'; chat windows='..#(snapshot.chat and snapshot.chat.windows or {}))
        for _,layout in ipairs(snapshot.layouts or {}) do
            line('  '..layout.name..' '..tostring(layout.point)..'/'..tostring(layout.relativePoint)..' x='..tostring(layout.x)..' y='..tostring(layout.y))
        end
        for _,chat in ipairs(snapshot.chat and snapshot.chat.windows or {}) do
            if chat.id==1 or chat.shown then line('  Chat '..chat.id..' '..tostring(chat.name)..' shown='..tostring(chat.shown)..' x='..tostring(chat.x)..' y='..tostring(chat.y)) end
        end
    end
    return table.concat(lines,'\n')
end

function AM:ShowDiagnostics(report,titleText,refreshReport)
    local f=self.diagnosticsWindow
    if not f then
        f=CreateFrame('Frame','SetupSwapDiagnosticsWindow',UIParent)
        self.diagnosticsWindow=f
        local height=UIParent:GetHeight()*.80
        f:SetSize(math.min(UIParent:GetWidth()*.90,height*1.4),height)
        f:SetPoint('CENTER');f:SetFrameStrata('DIALOG');f:SetClampedToScreen(true)
        f:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',
            edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=32,
            insets={left=11,right=12,top=12,bottom=11}})
        f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag('LeftButton')
        f:SetScript('OnDragStart',function(self) self:StartMoving() end)
        f:SetScript('OnDragStop',function(self) self:StopMovingOrSizing() end)
        local title=f:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
        title:SetPoint('TOPLEFT',f,'TOPLEFT',f:GetWidth()*.03,-f:GetHeight()*.035);title:SetText('SetupSwap log');f.title=title
        local instruction=f:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
        instruction:SetPoint('TOPLEFT',f,'TOPLEFT',f:GetWidth()*.03,-f:GetHeight()*.085);instruction:SetWidth(f:GetWidth()*.91);instruction:SetText('Click the text, Ctrl+A to select all, then Ctrl+C to copy.')
        local close=CreateFrame('Button',nil,f,'UIPanelCloseButton')
        close:SetPoint('TOPRIGHT',f,'TOPRIGHT',-f:GetWidth()*.01,-f:GetHeight()*.01)
        close:SetSize(f:GetWidth()*.04,f:GetHeight()*.06)
        close:SetScript('OnClick',function() f:Hide() end)
        local scroll=CreateFrame('ScrollFrame','SetupSwapDiagnosticsScroll',f,'UIPanelScrollFrameTemplate')
        scroll:SetPoint('TOPLEFT',f,'TOPLEFT',f:GetWidth()*.03,-f:GetHeight()*.135);scroll:SetPoint('BOTTOMRIGHT',f,'BOTTOMRIGHT',-f:GetWidth()*.055,f:GetHeight()*.095)
        local edit=CreateFrame('EditBox',nil,scroll)
        f.edit=edit;f.scroll=scroll
        edit:SetMultiLine(true);edit:EnableMouse(true);edit:SetAutoFocus(false);edit:SetMaxLetters(0)
        edit:SetFontObject(ChatFontNormal);edit:SetTextInsets(f:GetWidth()*.006,f:GetWidth()*.006,f:GetHeight()*.008,f:GetHeight()*.008)
        edit:SetWidth(f:GetWidth()*.91);edit:SetHeight(f:GetHeight()*.01)
        scroll:SetScrollChild(edit)
        edit:SetScript('OnEscapePressed',function(self) self:ClearFocus();f:Hide() end)
        edit:SetScript('OnCursorChanged',function(self,x,y,width,height)
            local top=scroll:GetVerticalScroll()
            local cursor=-y
            if cursor<top then scroll:SetVerticalScroll(math.max(0,cursor))
            elseif cursor+height>top+scroll:GetHeight() then
                scroll:SetVerticalScroll(math.min(scroll:GetVerticalScrollRange(),cursor+height-scroll:GetHeight()))
            end
        end)
        f:SetScript('OnHide',function() edit:ClearFocus() end)
        local select=CreateFrame('Button',nil,f,'UIPanelButtonTemplate')
        select:SetSize(f:GetWidth()*.17,f:GetHeight()*.045);select:SetPoint('BOTTOMLEFT',f,'BOTTOMLEFT',f:GetWidth()*.03,f:GetHeight()*.025);select:SetText('Select all')
        select:SetScript('OnClick',function() edit:SetFocus();edit:HighlightText() end)
        local refresh=CreateFrame('Button',nil,f,'UIPanelButtonTemplate')
        refresh:SetSize(f:GetWidth()*.15,f:GetHeight()*.045);refresh:SetPoint('LEFT',select,'RIGHT',f:GetWidth()*.02,0);refresh:SetText('Refresh')
        refresh:SetScript('OnClick',function() if f.refreshReport then f.refreshReport() else AM:ShowDiagnostics() end end)
        if UISpecialFrames then table.insert(UISpecialFrames,'SetupSwapDiagnosticsWindow') end
    end
    f.refreshReport=refreshReport
    f.title:SetText(titleText or 'SetupSwap log')
    f:Show()
    f.edit:SetText(report or self:DiagnosticsText())
    f.edit:SetCursorPosition(0)
    f.scroll:SetVerticalScroll(0)
    f.edit:SetFocus()
    f.edit:HighlightText()
end

local frame=CreateFrame('Frame')
frame:RegisterEvent('ADDON_ACTION_BLOCKED')
frame:RegisterEvent('ADDON_ACTION_FORBIDDEN')
frame:SetScript('OnEvent',function(_,event,addon,operation)
    local entries=recent
    if AM.db then
        AM.db.blockedActions=AM.db.blockedActions or {}
        entries=AM.db.blockedActions
    end
    local item={event=event,addon=tostring(addon or 'unknown'),operation=tostring(operation or 'unknown'),context=AM.operationContext,stack=debugstack and debugstack(2,12,12) or nil}
    entries[#entries+1]=item
    if #entries>20 then table.remove(entries,1) end
    AM:Print('Blocked addon action: '..item.addon..' -> '..item.operation..(item.context and (' ['..item.context..']') or '')..'. Details: /ss log')
end)
