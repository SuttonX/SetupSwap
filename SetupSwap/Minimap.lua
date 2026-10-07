local AM=SetupSwap
function AM:PositionMinimapButton()
    local b=self.minimapButton
    local pos=self.db.minimapPosition or {x=-0.70710678,y=-0.70710678}
    local length=math.sqrt(pos.x*pos.x+pos.y*pos.y)
    if length==0 then pos={x=-0.70710678,y=-0.70710678}; length=1 end
    local radius=math.min(Minimap:GetWidth(),Minimap:GetHeight())/2+8
    b:ClearAllPoints()
    b:SetPoint('CENTER',Minimap,'CENTER',pos.x/length*radius,pos.y/length*radius)
end
function AM:DragMinimapButton()
    local x,y=GetCursorPosition()
    local scale=Minimap:GetEffectiveScale()
    local cx,cy=Minimap:GetCenter()
    if not cx or not cy then return end
    x=x/scale-cx; y=y/scale-cy
    local length=math.sqrt(x*x+y*y)
    if length>0 then
        self.db.minimapPosition={x=x/length,y=y/length}
        self:PositionMinimapButton()
    end
end
function AM:ShowMinimapProfiles(anchor)
    if not self.minimapProfileMenu then
        self.minimapProfileMenu=CreateFrame('Frame','SetupSwapMinimapProfileMenu',UIParent,'UIDropDownMenuTemplate')
    end
    local menu={{text='Switch profile',isTitle=true,notCheckable=true}}
    for _,name in ipairs(self:ProfileNames()) do
        local selected=name
        menu[#menu+1]={text=name,notCheckable=true,func=function() AM:Switch(selected) end}
    end
    if #menu==1 then menu[#menu+1]={text='No saved profiles',disabled=true,notCheckable=true} end
    EasyMenu(menu,self.minimapProfileMenu,anchor,0,0,'MENU')
end
function AM:CreateMinimapButton()
    if self.minimapButton then self:PositionMinimapButton(); return end
    local b=CreateFrame('Button','SetupSwapMinimapButton',Minimap)
    self.minimapButton=b
    local buttonSize=32
    b:SetWidth(buttonSize); b:SetHeight(buttonSize); b:SetFrameStrata('MEDIUM'); b:SetFrameLevel(Minimap:GetFrameLevel()+5)
    b:RegisterForClicks('LeftButtonUp','RightButtonUp'); b:RegisterForDrag('LeftButton')
    local icon=b:CreateTexture(nil,'BACKGROUND')
    icon:SetTexture('Interface\\AddOns\\SetupSwap\\Assets\\Swap')
    -- Fit the approved transparent artwork inside the native tracking border.
    icon:SetWidth(buttonSize*.75); icon:SetHeight(buttonSize*.75)
    icon:SetPoint('CENTER',b,'CENTER',buttonSize/32,0)
    local border=b:CreateTexture(nil,'OVERLAY')
    border:SetTexture('Interface\\Minimap\\MiniMap-TrackingBorder')
    border:SetWidth(54); border:SetHeight(54); border:SetPoint('TOPLEFT')
    b:SetHighlightTexture('Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight')
    b:SetScript('OnClick',function(self,button)
        if button=='RightButton' then AM:ShowMinimapProfiles(self) else AM:ShowUI() end
    end)
    b:SetScript('OnDragStart',function(self)
        GameTooltip:Hide()
        self:SetScript('OnUpdate',function() AM:DragMinimapButton() end)
    end)
    b:SetScript('OnDragStop',function(self)
        self:SetScript('OnUpdate',nil); AM:DragMinimapButton()
    end)
    b:SetScript('OnEnter',function(self)
        GameTooltip:SetOwner(self,'ANCHOR_LEFT'); GameTooltip:SetText('SetupSwap')
        GameTooltip:AddLine('Left-click to open addon profiles.',1,1,1)
        GameTooltip:AddLine('Right-click to switch to a saved profile.',1,1,1)
        GameTooltip:AddLine('Drag to move around the minimap.',1,1,1)
        GameTooltip:AddLine('You can also type /ss.',.6,.8,1)
        GameTooltip:Show()
    end)
    b:SetScript('OnLeave',function() GameTooltip:Hide() end)
    self:PositionMinimapButton()
end
