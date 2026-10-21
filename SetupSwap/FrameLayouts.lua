local AM=SetupSwap
local runner
-- Explicit integrations for windows whose addons do not persist their layout.
-- Only selected, loaded addons and unprotected frames anchored to UIParent.
local windows={OptimalRaidComp={'OptimalRaidCompFrame','ORC_CommandsWindow','ORC_Launcher'}}
local function identity()
    return tostring(GetRealmName and GetRealmName() or '')..'/'..tostring(UnitName and UnitName('player') or '')
end
local function excluded(name,frame)
    -- Questie's pooled rows and resize handle are internal layout components,
    -- not independent windows. Reanchoring them to UIParent breaks the tracker.
    if name and (name:find('^linePool') or name=='Questie_Sizer') then return true end
    local parent=frame and frame.GetParent and frame:GetParent()
    local seen={}
    while parent and not seen[parent] do
        seen[parent]=true
        if parent.GetName and parent:GetName()=='Questie_BaseFrame' then return true end
        parent=parent.GetParent and parent:GetParent()
    end
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
    for addon,enabled in pairs(AM:AddonSelection(profile)) do
        if enabled and IsAddOnLoaded(addon) and addon~=AM.name then
            local base=addon:lower():gsub('[-_]%d[%d%.]*$','')
            base=base:gsub('[^%w]','')
            if #base>2 and normalized:sub(1,#base)==base and (not length or #base>length) then found,length=addon,#base end
        end
    end
    return found or '__ui'
end
-- TomTom can restore its own anchor after a generic window restore. Keep the
-- native saved anchor in sync, and release the per-character layout cache.
function AM:SyncTomTomWindowPosition(frame,name)
    local option=({TomTomCrazyArrow='arrow',TomTomBlock='block'})[name]
    local tomtom=_G.TomTom
    if not option or not IsAddOnLoaded('TomTom') or type(tomtom)~='table'
        or not tomtom.db or type(tomtom.db.profile)~='table'
        or type(tomtom.db.profile[option])~='table' or not writable(frame) then return end
    local point,relative,relativePoint,x,y=frame:GetPoint(1)
    local relativeName=relative and relative.GetName and relative:GetName() or 'UIParent'
    if not point or (relative and relative~=UIParent and relativeName=='UIParent')
        or type(x)~='number' or type(y)~='number' then return end
    tomtom.db.profile[option].position={point=point,relativeTo=relativeName,
        rel=relativePoint or point,x=x,y=y}
    if frame.SetUserPlaced then frame:SetUserPlaced(false) end
end
-- Coordinates are normalized in UIParent space, but the attachment point is
-- part of the layout: replacing a corner with CENTER changes resize direction.
local anchors={TOPLEFT={-0.5,0.5},TOP={0,0.5},TOPRIGHT={0.5,0.5},
    LEFT={-0.5,0},CENTER={0,0},RIGHT={0.5,0},
    BOTTOMLEFT={-0.5,-0.5},BOTTOM={0,-0.5},BOTTOMRIGHT={0.5,-0.5}}
local function growthPoint(frame,name)
    local questie=name=='Questie_BaseFrame' and _G.Questie
    local profile=type(questie)=='table' and questie.db and questie.db.profile
    local point=profile and profile.trackerSetpoint
    if anchors[point] then return point end
    point=frame:GetPoint(1)
    return anchors[point] and point or 'CENTER'
end
local function scaleRatio(frame)
    local ratio=frame.GetEffectiveScale and UIParent.GetEffectiveScale
        and frame:GetEffectiveScale()/UIParent:GetEffectiveScale() or 1
    return ratio>0 and ratio or 1
end
local function dimensions(frame)
    local w=frame.GetWidth and frame:GetWidth()
    local h=frame.GetHeight and frame:GetHeight()
    if type(w)=='number' and type(h)=='number' and w>0 and h>0 then return w,h end
end
local function anchorPosition(frame,point)
    local cx,cy
    if frame.GetCenter then cx,cy=frame:GetCenter() end
    local w,h=dimensions(frame)
    if type(cx)~='number' or type(cy)~='number' then return end
    if point~='CENTER' and not w then return end
    local a=anchors[point]
    local ratio=scaleRatio(frame)
    return (cx+(w or 0)*a[1])*ratio,(cy+(h or 0)*a[2])*ratio
end
-- Questie reapplies TrackerLocation on profile changes and resizing. Keep its
-- native corner and our restored position identical, without a Questie patch.
function AM:SyncQuestieWindowPosition(frame)
    local questie=_G.Questie
    local profile=type(questie)=='table' and questie.db and questie.db.profile
    if type(profile)~='table' or not writable(frame) then return end
    local point=growthPoint(frame,'Questie_BaseFrame')
    local x,y=anchorPosition(frame,point)
    if x and y then
        local ratio=scaleRatio(frame)
        profile.TrackerLocation={point,'UIParent','BOTTOMLEFT',x/ratio,y/ratio}
    end
end
function AM:CaptureFrameLayouts(profile)
    local result,seen={},{}
    local coverage={movable=0,protected=0,unnamed=0,captured=0}
    self.lastFrameCoverage=coverage
    if not UIParent or not UIParent.GetWidth then return result end
    local width,height=UIParent:GetWidth(),UIParent:GetHeight()
    if not width or not height or width<=0 or height<=0 then return result end
    local function capture(frame,name,addon,generic)
        if seen[name] or excluded(name,frame) or not writable(frame) then return end
        local point,relative,relativePoint,x,y=frame:GetPoint(1)
        local selected=growthPoint(frame,name)
        local ax,ay=anchorPosition(frame,selected)
        local anchorVersion
        if ax and ay then
            point,relative,relativePoint,x,y=selected,UIParent,'BOTTOMLEFT',ax,ay
            anchorVersion=2
        end
        if point and (relative==UIParent or relative==nil) and type(x)=='number' and type(y)=='number' then
            seen[name]=true
            result[#result+1]={addon=addon,name=name,point=point,relativePoint=relativePoint or point,x=x/width,y=y/height,generic=generic or nil,anchorVersion=anchorVersion}
        end
    end
    for addon,names in pairs(windows) do
        if self:EffectiveState(profile,{name=addon}) and IsAddOnLoaded(addon) then
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
        if item.generic and not excluded(item.name,candidate) and writable(candidate)
            and layoutCandidate(candidate) then allowed=true end
        local frame=allowed and candidate
        if frame and (item.addon=='__ui' or ((not profile or self:EffectiveState(profile,{name=item.addon})) and IsAddOnLoaded(item.addon)))
            and not (frame.IsProtected and frame:IsProtected()) and type(item.x)=='number' and type(item.y)=='number' then
            -- Legacy captures stored only a center, losing the growth point.
            -- Convert once using the native anchor and current dimensions, keeping
            -- the same rectangle. Persist the conversion so retries after resizing
            -- do not move the corner again. Unknown native centers stay centers.
            if not item.anchorVersion and item.point=='CENTER' and item.relativePoint=='BOTTOMLEFT' then
                local point=growthPoint(frame,item.name)
                local w,h=dimensions(frame)
                if point~='CENTER' and w then
                    local a=anchors[point]
                    local ratio=scaleRatio(frame)
                    item.x=item.x+w*a[1]*ratio/UIParent:GetWidth()
                    item.y=item.y+h*a[2]*ratio/UIParent:GetHeight()
                    item.point=point;item.anchorVersion=2
                end
            end
            if anchors[item.point] and anchors[item.relativePoint] then
                frame:ClearAllPoints()
                local ratio=item.relativePoint=='BOTTOMLEFT' and scaleRatio(frame) or 1
                frame:SetPoint(item.point,UIParent,item.relativePoint,item.x*UIParent:GetWidth()/ratio,item.y*UIParent:GetHeight()/ratio)
                self:SyncTomTomWindowPosition(frame,item.name)
                if item.name=='Questie_BaseFrame' then self:SyncQuestieWindowPosition(frame) end
                count=count+1
            end
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
