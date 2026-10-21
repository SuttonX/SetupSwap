-- Geometry model: GetCenter uses frame units; SetPoint offsets use frame units.
-- Parent size/scale, frame size/scale and the anchored point can vary independently.
local checks=0
local function check(value,message) assert(value,message);checks=checks+1 end
local function near(a,b) return math.abs(a-b)<0.00001 end
local anchor={TOPLEFT={-.5,.5},TOP={0,.5},TOPRIGHT={.5,.5},LEFT={-.5,0},CENTER={0,0},RIGHT={.5,0},BOTTOMLEFT={-.5,-.5},BOTTOM={0,-.5},BOTTOMRIGHT={.5,-.5}}
UIParent={w=1600,h=900,scale=.8}
function UIParent:GetWidth() return self.w end
function UIParent:GetHeight() return self.h end
function UIParent:GetEffectiveScale() return self.scale end
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
function IsAddOnLoaded() return true end
function InCombatLockdown() return false end
local list={}
local function window(name,point,x,y)
 local f={name=name,point=point,x=x,y=y,w=240,h=100,scale=.64,hidden=false}
 function f:GetName() return self.name end
 function f:GetPoint() return self.point,UIParent,'BOTTOMLEFT',self.x,self.y end
 function f:GetParent() return UIParent end
 function f:GetWidth() return self.w end
 function f:GetHeight() return self.h end
 function f:GetEffectiveScale() return self.scale end
 function f:GetCenter() local a=anchor[self.point];return self.x-a[1]*self.w,self.y-a[2]*self.h end
 function f:IsMovable() return true end
 function f:ClearAllPoints() end
 function f:SetPoint(p,parent,r,x,y) assert((parent==UIParent or parent=='UIParent') and r=='BOTTOMLEFT');self.point=p;self.x=x;self.y=y end
 function f:Show() error('Position restoration must not change visibility') end
 function f:Hide() error('Position restoration must not change visibility') end
 _G[name]=f;list[#list+1]=f;return f
end
function EnumerateFrames(prev) if not prev then return list[1] end;for i,f in ipairs(list) do if f==prev then return list[i+1] end end end
SetupSwap={name='SetupSwap',AddonSelection=function() return {['Questie-335']=true,OtherAddon=true} end,EffectiveState=function() return true end}
dofile('SetupSwap/FrameLayouts.lua')
local AM=SetupSwap
local function center(f) local x,y=f:GetCenter();local ratio=f.scale/UIParent.scale;return x*ratio,y*ratio end
for point in pairs(anchor) do
 list={};local f=window('OtherAddonWindow',point,1200,700)
 local layouts=AM:CaptureFrameLayouts({})
 check(#layouts==1 and layouts[1].point==point and layouts[1].anchorVersion==2,'Capture preserves '..point)
 local x,y=layouts[1].x,layouts[1].y
 UIParent.w=1920;UIParent.h=1080;UIParent.scale=.7;f.scale=.91
 f.x=10;f.y=10
 AM:ApplyFrameLayouts(layouts,{})
 check(f.point==point and near(f.x*f.scale/UIParent.scale,x*1920) and near(f.y*f.scale/UIParent.scale,y*1080),'Resolution and scale restore '..point)
 local ax,ay=f.x,f.y
 f.w=f.w+80;f.h=f.h+180
 check(f.x==ax and f.y==ay,'Resizing keeps native attachment '..point)
 AM:ApplyFrameLayouts(layouts,{})
 check(near(f.x,ax) and near(f.y,ay),'Delayed restore stays stable '..point)
end
for _,point in ipairs({'TOPLEFT','TOPRIGHT','BOTTOMLEFT','BOTTOMRIGHT'}) do
 list={};local f=window('Questie_BaseFrame','CENTER',900,500)
 Questie={db={profile={trackerSetpoint=point,TrackerLocation={'TOPLEFT','UIParent','BOTTOMLEFT',1,2}}}}
 local old={name=f.name,addon='Questie-335',generic=true,point='CENTER',relativePoint='BOTTOMLEFT',x=.5,y=.5}
 local sourceX,sourceY=old.x*UIParent.w,old.y*UIParent.h
 AM:ApplyFrameLayouts({old},{})
 local cx,cy=center(f)
 check(f.point==point and near(cx,sourceX) and near(cy,sourceY),'Legacy center retains rectangle '..point)
 local loc=Questie.db.profile.TrackerLocation
 check(loc[1]==point and loc[2]=='UIParent' and near(loc[4],f.x) and near(loc[5],f.y),'Questie native position agrees '..point)
 local x,y=f.x,f.y;f.w=400;f.h=360
 AM:ApplyFrameLayouts({old},{})
 check(near(x,f.x) and near(y,f.y),'Legacy conversion does not drift on retry '..point)
 -- Simulate the patched Questie's next sizing pass reapplying TrackerLocation.
 f:SetPoint(loc[1],UIParent,loc[3],loc[4],loc[5])
 check(near(x,f.x) and near(y,f.y),'Native sizing cannot undo restore '..point)
 local layouts=AM:CaptureFrameLayouts({})
 check(layouts[1].point==point,'Resaving upgraded layout retains growth '..point)
end
list={};Questie=nil
local f=window('OtherAddonWindow','TOPRIGHT',300,400)
local old={name=f.name,addon='OtherAddon',generic=true,point='CENTER',relativePoint='BOTTOMLEFT',x=.3,y=.4}
AM:ApplyFrameLayouts({old},{})
check(f.point=='TOPRIGHT','Other dynamic windows also recover native growth from legacy centers')
local centered=window('OtherAddonCentered','CENTER',500,500)
local item={name=centered.name,addon='OtherAddon',generic=true,point='CENTER',relativePoint='BOTTOMLEFT',x=.4,y=.4}
AM:ApplyFrameLayouts({item},{})
check(centered.point=='CENTER','Intentionally centered windows remain centered')
list={};f=window('Questie_BaseFrame','CENTER',700,600)
Questie={db={profile={trackerSetpoint='TOPRIGHT'}}}
local cx,cy=center(f)
AM:SyncQuestieWindowPosition(f)
local loc=Questie.db.profile.TrackerLocation
check(f.point=='CENTER' and near(center(f),cx),'Pre-save sync does not move the live frame')
f:SetPoint(loc[1],UIParent,loc[3],loc[4],loc[5])
local nx,ny=center(f)
check(near(nx,cx) and near(ny,cy),'Pre-save native corner preserves rectangle across reload')
-- Optional integration uses the unmodified upstream method, not our fork.
local fixture=os.getenv('QUESTIE_BASE_FIXTURE')
if fixture then
 local file=assert(io.open(fixture));local source=file:read('*a');file:close()
 assert(not source:find('function TrackerBaseFrame:RestoreGrowthAnchor',1,true),'Expected original Questie source')
 local method=assert(source:match('(function TrackerBaseFrame:OnProfileChange%(%)%s.-)\n_OnEnter ='))
 for _,point in ipairs({'TOPLEFT','TOPRIGHT','BOTTOMLEFT','BOTTOMRIGHT'}) do
  list={};local f=window('Questie_BaseFrame','CENTER',700,500)
  Questie={db={profile={trackerEnabled=true,trackerSetpoint=point}}}
  local item={name=f.name,addon='Questie-335',generic=true,point='CENTER',relativePoint='BOTTOMLEFT',x=.6,y=.7}
  AM:ApplyFrameLayouts({item},{})
  local x,y=f.x,f.y
  local module={}
  local env=setmetatable({TrackerBaseFrame=module,baseFrame=f,Questie=Questie,
   C_Timer={After=function(_,fn) fn() end},QuestieCombatQueue={Queue=function(_,fn) fn() end},
   QuestieTracker={Update=function() f.w=f.w+80;f.h=f.h+180 end}}, {__index=_G})
  assert(load(method,'Original Questie OnProfileChange','t',env))()
  module:OnProfileChange()
  AM:ApplyFrameLayouts({item},{})
  check(f.point==point and near(x,f.x) and near(y,f.y),'Original Questie profile callback and auto growth preserve '..point)
 end
end
print(checks..' frame growth and scale checks passed')
