local AM=SetupSwap
local function engine()
    if not IsAddOnLoaded or not IsAddOnLoaded('ElvUI') then return end
    local E=type(_G.ElvUI)=='table' and _G.ElvUI[1]
    if type(E)~='table' or type(E.GetModule)~='function' or not E.media or not E.private or type(E.db)~='table' or type(E.db.general)~='table' then return end
    local ok,S=pcall(E.GetModule,E,'Skins',true)
    if ok and type(S)=='table' then return E,S end
end
function AM:LayoutElvUISkin(f,unit)
    if not f.elvUISkinned then return end
    local checks={f.includeSettings,f.characterOnly}
    for _,row in ipairs(f.rows or {}) do checks[#checks+1]=row.check end
    for _,check in ipairs(checks) do
        local backdrop=check and check.backdrop
        if backdrop then
            local inset=check:GetWidth()*.16
            backdrop:ClearAllPoints()
            backdrop:SetPoint('TOPLEFT',check,'TOPLEFT',inset,-inset)
            backdrop:SetPoint('BOTTOMRIGHT',check,'BOTTOMRIGHT',-inset,inset)
        end
    end
    local close=f.close
    if close and close.Texture then
        close.Texture:SetSize(close:GetWidth()*.45,close:GetHeight()*.45)
        if close.SetHitRectInsets then
            close:SetHitRectInsets(close:GetWidth()*.20,close:GetWidth()*.20,close:GetHeight()*.20,close:GetHeight()*.20)
        end
    end
    local scrollbar=f.scroll and (f.scroll.ScrollBar or _G.SetupSwapAddonScrollScrollBar)
    if scrollbar then scrollbar:SetWidth(unit*1.5) end
end
function AM:ApplyElvUISkin(f)
    if not f or f.elvUISkinned or f.elvUISkinFailed then return false end
    local E,S=engine()
    if not E or type(f.SetTemplate)~='function' or type(f.StripTextures)~='function' then return false end
    for _,method in ipairs({'HandleButton','HandleEditBox','HandleCheckBox','HandleCloseButton','HandleScrollBar'}) do
        if type(S[method])~='function' then return false end
    end
    local ok,err=pcall(function()
        f:StripTextures();f:SetTemplate('Transparent')
        for _,control in ipairs({f.saveProfile,f.selectProfile,f.deleteProfile,f.barsOnly,
            f.saveSettings,f.useCurrent,f.selectAll,f.deselectAll,f.switchProfile}) do
            S:HandleButton(control,true)
        end
        f.profileName:StripTextures();S:HandleEditBox(f.profileName)
        S:HandleCheckBox(f.includeSettings);S:HandleCheckBox(f.characterOnly)
        for _,row in ipairs(f.rows) do S:HandleCheckBox(row.check) end
        S:HandleCloseButton(f.close)
        local scrollbar=f.scroll.ScrollBar or _G.SetupSwapAddonScrollScrollBar
        if scrollbar then S:HandleScrollBar(scrollbar) end
        f.elvUISkinned=true
    end)
    if not ok then
        f.elvUISkinFailed=true;self.elvUISkinError=tostring(err)
        self:Print('ElvUI window skin could not finish. Details: /ss log')
        return false
    end
    -- Native handlers can adjust sizes. Reapply our container-relative layout.
    self:LayoutUI()
    return true
end
