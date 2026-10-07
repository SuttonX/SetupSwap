local AM=SetupSwap
local runner
-- Explicit integrations for windows whose addons do not persist their layout.
-- Only selected, loaded addons and unprotected frames anchored to UIParent.
local windows={OptimalRaidComp={'OptimalRaidCompFrame','ORC_CommandsWindow','ORC_Launcher'}}
local function identity()
    return tostring(GetRealmName and GetRealmName() or '')..'/'..tostring(UnitName and UnitName('player') or '')
end
local function excluded(name)
    return not name or name:find('^SetupSwap') or name:find('^ChatFrame%d')
        or name:find('^StaticPopup') or name=='UIParent' or name=='WorldFrame'
end
local function writable(frame)
    return frame and frame.GetPoint and frame.SetPoint and frame.ClearAllPoints
        and not (frame.IsProtected and frame:IsProtected())
end
local function layoutCandidate(frame)
    if not frame then return false end
    if (frame.IsMovable and frame:IsMovable()) or (frame.IsUserPlaced and frame:IsUserPlaced())
        or (frame.IsResizable and frame:IsResizable()) then return true end
    if frame.GetScript then
        if frame:GetScript('OnDragStart') or frame:GetScript('OnDragStop') then return true end
        if frame.GetObjectType and frame:GetObjectType()=='Frame'
            and frame:GetScript('OnMouseDown') and frame:GetScript('OnMouseUp') then return true end
    end
    return false
end
local function owner(name,profile)
    local normalized=name:lower():gsub('[^%w]','')
    local found,length
    for addon,enabled in pairs(profile.addons or {}) do
        if enabled and IsAddOnLoaded(addon) and addon~=AM.name then
            local base=addon:lower():gsub('[-_]%d[%d%.]*$','')
            base=base:gsub('[^%w]','')
            if #base>2 and normalized:sub(1,#base)==base and (not length or #base>length) then found,length=addon,#base end
        end
    end
    return found or '__ui'
end
function AM:CaptureFrameLayouts(profile)
    local result,seen={},{}
    local coverage={movable=0,protected=0,unnamed=0,captured=0}
    self.lastFrameCoverage=coverage
    if not UIParent or not UIParent.GetWidth then return result end
    local width,height=UIParent:GetWidth(),UIParent:GetHeight()
    if not width or not height or width<=0 or height<=0 then return result end
    local function capture(frame,name,addon,generic)
        if seen[name] or excluded(name) or not writable(frame) then return end
        local point,relative,relativePoint,x,y=frame:GetPoint(1)
        local cx,cy
        if frame.GetCenter then cx,cy=frame:GetCenter() end
        if cx and cy and frame.GetEffectiveScale and UIParent.GetEffectiveScale then
            local ratio=frame:GetEffectiveScale()/UIParent:GetEffectiveScale()
            point,relative,relativePoint,x,y='CENTER',UIParent,'BOTTOMLEFT',cx*ratio,cy*ratio
        end
        if point and (relative==UIParent or relative==nil) and type(x)=='number' and type(y)=='number' then
            seen[name]=true
            result[#result+1]={addon=addon,name=name,point=point,relativePoint=relativePoint or point,x=x/width,y=y/height,generic=generic or nil}
        end
    end
    for addon,names in pairs(windows) do
        if profile.addons[addon]==true and IsAddOnLoaded(addon) then
            for _,name in ipairs(names) do capture(_G[name],name,addon,false) end
        end
    end
    -- Discover the running layout without a per-addon list. Stable names allow
    -- matching recreated frames after reload; movable/user-placed frames carry layout.
    if EnumerateFrames then
        local frame=EnumerateFrames()
        while frame do
            local name=frame.GetName and frame:GetName()
            if layoutCandidate(frame) then
                coverage.movable=coverage.movable+1
                if not name then coverage.unnamed=coverage.unnamed+1
                elseif frame.IsProtected and frame:IsProtected() then coverage.protected=coverage.protected+1
                elseif _G[name]==frame then capture(frame,name,owner(name,profile),true) end
            end
            frame=EnumerateFrames(frame)
        end
    end
    coverage.captured=#result
    return result
end
function AM:ApplyFrameLayouts(layouts,profile)
    if InCombatLockdown() or not UIParent then return end
    local count=0
    for _,item in ipairs(layouts or {}) do
        local allowed=false
        for _,name in ipairs(windows[item.addon] or {}) do if name==item.name then allowed=true end end
        local candidate=type(item.name)=='string' and _G[item.name]
        if item.generic and not excluded(item.name) and writable(candidate)
            and layoutCandidate(candidate) then allowed=true end
        local frame=allowed and candidate
        if frame and (item.addon=='__ui' or ((not profile or profile.addons[item.addon]==true) and IsAddOnLoaded(item.addon)))
            and not (frame.IsProtected and frame:IsProtected()) and type(item.x)=='number' and type(item.y)=='number' then
            frame:ClearAllPoints()
            local ratio=1
            if item.relativePoint=='BOTTOMLEFT' and frame.GetEffectiveScale and UIParent.GetEffectiveScale then
                ratio=frame:GetEffectiveScale()/UIParent:GetEffectiveScale()
            end
            frame:SetPoint(item.point,UIParent,item.relativePoint,item.x*UIParent:GetWidth()/ratio,item.y*UIParent:GetHeight()/ratio)
            count=count+1
        end
    end
    return count
end
function AM:RestoreMatchingWindowsOnLogin()
    if self.db.pendingSettings or self.db.pendingFrameLayouts or not self.MatchingEnabledProfile then return end
    local name=self:MatchingEnabledProfile()
    local profile=name and self.db.profiles[name]
    if profile and profile.captureSettings and profile.settings then
        self:StageFrameLayouts(name,profile.settings.layouts)
    end
end
function AM:StageFrameLayouts(name,layouts)
    if type(layouts)=='table' and #layouts>0 then
        self.db.pendingFrameLayouts={name=name,layouts=layouts,character=identity()}
        if runner and runner:GetScript('OnEvent') then runner:GetScript('OnEvent')(runner) end
    end
end
runner=CreateFrame('Frame')
runner:RegisterEvent('PLAYER_LOGIN')
runner:SetScript('OnEvent',function(self)
    local elapsed=0
    self:SetScript('OnUpdate',function(frame,delta)
        if not AM.db then return end
        local pending=AM.db.pendingFrameLayouts
        if not pending then frame:SetScript('OnUpdate',nil); return end
        if pending.character~=identity() then AM.db.pendingFrameLayouts=nil;frame:SetScript('OnUpdate',nil);return end
        if InCombatLockdown() or AM.db.pendingSettings or AM.followupReload then return end
        elapsed=elapsed+delta
        if elapsed<2 then return end
        AM.db.pendingFrameLayouts=nil;frame:SetScript('OnUpdate',nil)
        local count=AM:ApplyFrameLayouts(pending.layouts,AM.db.profiles[pending.name])
        AM.db.lastWindowRestore={name=pending.name,count=count or 0,actual=AM:CaptureFrameLayouts(AM.db.profiles[pending.name] or {addons={}})}
        if count and count>0 then AM:Print('Restored '..count..' window positions.') end
    end)
end)
