local AM=SetupSwap
local runner
local function identity()
    return tostring(GetRealmName and GetRealmName() or '')..'/'..tostring(UnitName and UnitName('player') or '')
end
local function on(v) return v~=nil and v~=false and v~=0 end
function AM:CaptureChatLayout()
    if not GetChatWindowInfo or not UIParent then return end
    local result={windows={}}
    for i=1,NUM_CHAT_WINDOWS or 10 do
        local frame=_G['ChatFrame'..i]
        if frame and not frame.isTemporary then
            local name,size,r,g,b,alpha,shown,locked,docked,uninteractable=GetChatWindowInfo(i)
            local point,x,y=GetChatWindowSavedPosition(i)
            local w,h=frame:GetWidth(),frame:GetHeight()
            -- Use current geometry; chat-cache can lag behind the visible frame.
            local left,bottom=frame:GetLeft(),frame:GetBottom()
            if left and bottom then
                point,x,y='BOTTOMLEFT',left/GetScreenWidth(),bottom/GetScreenHeight()
            end
            result.windows[#result.windows+1]={id=i,name=name,size=size,r=r,g=g,b=b,alpha=alpha,
                shown=on(shown),locked=on(locked),docked=docked,uninteractable=on(uninteractable),
                point=point,x=x,y=y,width=w/UIParent:GetWidth(),height=h/UIParent:GetHeight(),
                messages={GetChatWindowMessages(i)},channels={GetChatWindowChannels(i)}}
        end
    end
    return result
end
function AM:ApplyChatLayout(layout)
    if InCombatLockdown() or not layout or not GetChatWindowInfo then return end
    -- Remove old docking before recreating the saved order.
    for _,item in ipairs(layout.windows or {}) do
        local frame=_G['ChatFrame'..item.id]
        if frame and item.id~=1 and FCF_UnDockFrame then FCF_UnDockFrame(frame) end
    end
    for _,item in ipairs(layout.windows or {}) do
        local frame=_G['ChatFrame'..item.id]
        if frame then
            if FCF_SetWindowName and item.name then FCF_SetWindowName(frame,item.name) end
            if FCF_SetChatWindowFontSize and item.size then FCF_SetChatWindowFontSize(nil,frame,item.size) end
            if FCF_SetWindowColor and item.r then FCF_SetWindowColor(frame,item.r,item.g,item.b) end
            if FCF_SetWindowAlpha and item.alpha then FCF_SetWindowAlpha(frame,item.alpha) end
            if item.point and item.x and item.y then
                SetChatWindowSavedPosition(item.id,item.point,item.x,item.y)
                SetChatWindowSavedDimensions(item.id,item.width*UIParent:GetWidth(),item.height*UIParent:GetHeight())
                -- Native restore uses an implicit parent, which may be an ElvUI panel.
                -- Saved coordinates describe the screen, not that panel's origin.
                frame:SetSize(item.width*UIParent:GetWidth(),item.height*UIParent:GetHeight())
                frame:ClearAllPoints()
                frame:SetPoint(item.point,UIParent,item.point,item.x*GetScreenWidth(),item.y*GetScreenHeight())
                if frame.SetUserPlaced then frame:SetUserPlaced(true) end
            end
            if ChatFrame_RemoveAllMessageGroups then
                ChatFrame_RemoveAllMessageGroups(frame)
                for _,group in ipairs(item.messages or {}) do ChatFrame_AddMessageGroup(frame,group) end
            end
            if ChatFrame_RemoveAllChannels then
                ChatFrame_RemoveAllChannels(frame)
                -- Native getter returns channel name / zone-ID pairs.
                for n=1,#(item.channels or {}),2 do ChatFrame_AddChannel(frame,item.channels[n]) end
            end
            if FCF_SetLocked then FCF_SetLocked(frame,item.locked and 1 or nil) end
            if FCF_SetUninteractable then FCF_SetUninteractable(frame,item.uninteractable and 1 or nil) end
            SetChatWindowShown(item.id,item.shown and 1 or nil)
            frame.isShown=item.shown
            if item.shown or item.id==1 then frame:Show() else frame:Hide() end
            local tab=_G['ChatFrame'..item.id..'Tab']
            if tab then if item.shown or item.id==1 then tab:Show() else tab:Hide() end end
        end
    end
    local order={}
    for _,item in ipairs(layout.windows or {}) do
        if on(item.docked) then order[#order+1]=item end
    end
    table.sort(order,function(a,b) return (tonumber(a.docked) or a.id)<(tonumber(b.docked) or b.id) end)
    for index,item in ipairs(order) do
        local frame=_G['ChatFrame'..item.id]
        if frame and FCF_DockFrame then FCF_DockFrame(frame,index,item.id==1) end
    end
    -- ElvUI manages these Blizzard frames inside its own panels. Reconcile only
    -- after visibility and docking have been restored, so it finds the right window.
    local engine=type(ElvUI)=='table' and ElvUI[1]
    if engine and engine.GetModule then
        local chat=engine:GetModule('Chat',true)
        if chat and chat.Initialized and chat.PositionChat then chat:PositionChat(true) end
    end
end
function AM:StageChatLayout(layout)
    if layout then
        self.db.pendingChatLayout={layout=layout,character=identity()}
        if runner and runner:GetScript('OnEvent') then runner:GetScript('OnEvent')(runner) end
    end
end
runner=CreateFrame('Frame')
runner:RegisterEvent('PLAYER_LOGIN')
runner:SetScript('OnEvent',function(self)
    local elapsed=0
    self:SetScript('OnUpdate',function(frame,delta)
        if not AM.db then return end
        local pending=AM.db.pendingChatLayout
        if not pending then frame:SetScript('OnUpdate',nil);return end
        if pending.character~=identity() then AM.db.pendingChatLayout=nil;frame:SetScript('OnUpdate',nil);return end
        if InCombatLockdown() or AM.db.pendingSettings or AM.followupReload then return end
        elapsed=elapsed+delta;if elapsed<2 then return end
        AM.db.pendingChatLayout=nil;frame:SetScript('OnUpdate',nil)
        local ok,err=pcall(AM.ApplyChatLayout,AM,pending.layout)
        AM.db.lastChatRestore={ok=ok,error=not ok and tostring(err) or nil,actual=ok and AM:CaptureChatLayout() or nil}
        if not ok then AM:Print('Chat restore stopped: '..tostring(err)) else AM:Print('Restored saved chat windows.') end
    end)
end)

-- Some servers send channel notice types missing from the 3.3.5 localization.
-- Blizzard formats a nil template at ChatFrame.lua:2802. Keep ordinary channel
-- notices intact; record only notices the native handler cannot render.
if ChatFrame_AddMessageEventFilter then
    ChatFrame_AddMessageEventFilter('CHAT_MSG_CHANNEL_NOTICE',function(_,event,notice,_,_,channel)
        if type(notice)~='string' then return end
        local template=_G['CHAT_'..notice..'_NOTICE_BN'] or _G['CHAT_'..notice..'_NOTICE']
        if type(template)=='string' then return end
        local db=AM.db or SetupSwapAccountDB
        if db then
            db.unsupportedChatNotices=db.unsupportedChatNotices or {}
            local notices=db.unsupportedChatNotices
            notices[#notices+1]={notice=notice:sub(1,128),channel=tostring(channel or ''):sub(1,128)}
            if #notices>20 then table.remove(notices,1) end
        end
        return true
    end)
end
