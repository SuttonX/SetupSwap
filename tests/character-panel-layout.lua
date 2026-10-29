local checks=0
local function check(ok,msg) assert(ok,msg);checks=checks+1 end
UIParent={x=0,y=0,GetWidth=function() return 1600 end,GetHeight=function() return 900 end,GetEffectiveScale=function() return 1 end}
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
function GetRealmName() return 'Realm' end
function UnitName() return 'Rogue' end
function IsAddOnLoaded() return true end
function InCombatLockdown() return false end
SetupSwap={name='SetupSwap',AddonSelection=function() return {} end,EffectiveState=function() return true end}
local frames={}
local function window(name,parent,x,y)
 local f={name=name,parent=parent,relative=parent,x=x,y=y,changes=0}
 function f:GetName() return self.name end
 function f:GetParent() return self.parent end
 function f:GetPoint() return 'CENTER',self.relative,'BOTTOMLEFT',self.x,self.y end
 function f:GetCenter() local px,py=self.relative:GetCenter();return px+self.x,py+self.y end
 function f:GetWidth() return 32 end;function f:GetHeight() return 32 end
 function f:GetEffectiveScale() return 1 end
 function f:IsMovable() return true end;function f:IsProtected() return false end
 function f:ClearAllPoints() self.changes=self.changes+1 end
 function f:SetPoint(_,relative,_,x,y) self.relative=relative;self.x=x;self.y=y;self.changes=self.changes+1 end
 _G[name]=f;frames[#frames+1]=f;return f
end
function UIParent:GetCenter() return 0,0 end
local panel=window('CharacterFrame',UIParent,400,500)
local paper=window('PaperDollFrame',panel,0,0)
local head=window('CharacterHeadSlot',paper,20,30)
local other=window('CharacterNewSlot',UIParent,35,35) -- name protects already-detached controls too
local nested=window('UnfamiliarEquipmentWidget',paper,40,60)
local independent=window('IndependentAddonWindow',UIParent,700,500)
function EnumerateFrames(previous)
 if not previous then return frames[1] end
 for i,f in ipairs(frames) do if f==previous then return frames[i+1] end end
end
dofile('SetupSwap/FrameLayouts.lua')
local layouts=SetupSwap:CaptureFrameLayouts({})
local names={};for _,item in ipairs(layouts) do names[item.name]=true end
check(names.CharacterFrame and names.IndependentAddonWindow,'Actual windows remain capturable')
check(not names.PaperDollFrame and not names.CharacterHeadSlot and not names.CharacterNewSlot and not names.UnfamiliarEquipmentWidget,'Equipment controls and unknown descendants excluded from capture')
local legacy={}
for _,f in ipairs(frames) do legacy[#legacy+1]={name=f.name,addon='__ui',generic=true,point='CENTER',relativePoint='BOTTOMLEFT',x=.5,y=.5} end
local count=SetupSwap:ApplyFrameLayouts(legacy,{})
check(count==2 and independent.changes==2 and panel.changes==2,'Old snapshots still restore actual windows')
check(paper.changes==0 and head.changes==0 and other.changes==0 and nested.changes==0,'Old snapshots cannot detach equipment controls')
local beforeX,beforeY=head:GetCenter()
panel.x=panel.x+350;panel.y=panel.y-75
local afterX,afterY=head:GetCenter()
check(afterX-beforeX==350 and afterY-beforeY==-75,'Gear follows character panel when another panel opens')
SetupSwap:ApplyFrameLayouts(legacy,{})
beforeX,beforeY=nested:GetCenter();panel.x=panel.x-200;panel.y=panel.y+40
afterX,afterY=nested:GetCenter()
check(afterX-beforeX==-200 and afterY-beforeY==40,'Nested controls retain native anchors through repeated restores')
check(head.relative==paper and paper.relative==panel,'Native parent anchors remain intact without settings reset')
-- Exclusions must not depend on character class or current frame availability.
_G.CharacterNewSlot=nil
check(SetupSwap:ApplyFrameLayouts({legacy[4]}, {})==0,'Legacy equipment entry is harmless while frame is unavailable')
print(checks..' character-panel layout regression checks passed')
