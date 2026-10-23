local t=10
local timers,frames,combatQueue={},{},{}
local combat=false
function GetTime() return t end
function InCombatLockdown() return combat end
function CreateFrame()
 local f={scripts={}}
 function f:RegisterEvent() end;function f:UnregisterEvent() end
 function f:SetScript(k,v) self.scripts[k]=v end
 frames[#frames+1]=f;return f
end
function hooksecurefunc(object,key,hook)
 local native=object[key];object[key]=function(...) native(...);hook(...) end
end
SetupSwap={}
Questie={db={profile={trackerEnabled=true}}}
local tracker={started=true}
local pool={ResetLinesForChange=function() end}
local source,shown={},{}
local renders=0
local root=os.getenv('QUESTIE_LIB_ROOT')
local prefix
if root then
 local f=assert(io.open(root..'/Modules/Tracker/QuestieTracker.lua'));local s=f:read('*a');f:close()
 prefix=assert(s:match('(function QuestieTracker:Update%(%)%s.-lastTrackerUpdate = now)'))
else
 prefix=[[function QuestieTracker:Update()
 local now=GetTime()
 if not QuestieTracker.started or InCombatLockdown() or now-lastTrackerUpdate<0.1 then return end
 lastTrackerUpdate=now]]
end
local env=setmetatable({QuestieTracker=tracker,TrackerLinePool=pool,Render=function()
 renders=renders+1;shown={};for id in pairs(source) do shown[id]=true end
end},{__index=_G})
assert(load('local lastTrackerUpdate=0\n'..prefix..'\nTrackerLinePool.ResetLinesForChange()\nRender()\nend','native Questie throttle','t',env))()
QuestieCompat={C_Timer={After=function(delay,callback) timers[#timers+1]={at=t+delay,callback=callback} end}}
QuestieLoader={_modules={QuestieTracker=tracker,TrackerLinePool=pool,QuestieCombatQueue={Queue=function(_,fn) combatQueue[#combatQueue+1]=fn end}}}
local function advance(nextTime)
 t=nextTime
 local old=timers;timers={}
 for _,timer in ipairs(old) do if timer.at<=t then timer.callback() else timers[#timers+1]=timer end end
end
local checks=0
local function check(ok,msg) assert(ok,msg);checks=checks+1 end
-- Reproduce uploaded failure exactly using the upstream throttle.
t=10.094;tracker:Update();source[11357]=true
t=10.190;tracker:Update()
check(not shown[11357] and renders==1 and #timers==0,'Original native throttle loses final update at 96ms')
source={};shown={}
dofile('SetupSwap/QuestieRefresh.lua')
frames[1].scripts.OnEvent(frames[1])
check(SetupSwap.questieDeferredRefresh.attached and #timers==0,'Attachment does not schedule updates')
t=20.094;tracker:Update();source[11357]=true;tracker:Update()
check(#timers==1 and not shown[11357],'First suppressed native request schedules one trailing callback')
t=20.190;tracker:Update()
check(#timers==1 and not shown[11357],'Final 96ms update coalesces into existing callback')
advance(20.205)
check(shown[11357] and SetupSwap.questieDeferredRefresh.replayed==1,'Deferred native render shows accepted quest without another event')
check(#timers==0,'No polling remains after delivery')
-- A native render overtaking the timer cancels stale work.
t=30;tracker:Update();source[222]=true;t=30.05;tracker:Update()
local previous=renders
t=30.105;tracker:Update();advance(30.2)
check(renders==previous+1 and shown[222],'Later native render supersedes scheduled retry')
check(SetupSwap.questieDeferredRefresh.replayed==1,'Superseded callback does not run a duplicate update')
-- Disable gates and combat must be respected.
Questie.db.profile.trackerEnabled=false;t=30.21;tracker:Update()
check(#timers==0,'Disabled tracker does not schedule deferred work')
Questie.db.profile.trackerEnabled=true;combat=true;t=30.22;tracker:Update()
check(#timers==0,'Combat-skipped calls do not schedule new work')
combat=false;t=40;tracker:Update();source[333]=true;t=40.05;tracker:Update()
combat=true;advance(40.12)
check(#combatQueue==1 and not shown[333] and #timers==0,'Combat beginning during delay hands single callback to native combat queue')
combat=false;combatQueue[1]();combatQueue={}
check(shown[333] and #timers==0,'Native combat queue delivers once after combat')
t=50;tracker:Update();t=50.05;tracker:Update();Questie.db.profile.trackerEnabled=false
previous=renders;advance(50.2)
check(renders==previous and #timers==0,'Tracker disabled during delay is left alone')
check(frames[1].scripts.OnUpdate==nil,'Integration never installs an OnUpdate polling script')
print(checks..' Questie dropped-refresh regression checks passed')
