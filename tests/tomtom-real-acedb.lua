strmatch=string.match;unpack=table.unpack;loadstring=load
function wipe(t) for k in pairs(t) do t[k]=nil end;return t end
function GetRealmName() return 'Ashbringer' end
function UnitName() return 'Shifthead' end
function UnitClass() return 'Druid','DRUID' end
function UnitRace() return 'Night Elf','NightElf' end
function UnitFactionGroup() return 'Alliance' end
function GetLocale() return 'enUS' end
function InCombatLockdown() return false end
function CreateFrame()
    return {RegisterEvent=function() end,SetScript=function() end}
end
SlashCmdList={};DEFAULT_CHAT_FRAME={AddMessage=function() end}
dofile('../tomtom-test-libs/LibStub.lua')
dofile('../tomtom-test-libs/CallbackHandler-1.0.lua')
dofile('../tomtom-test-libs/AceDB-3.0.lua')
dofile('SetupSwap/Core.lua');dofile('SetupSwap/Snapshots.lua');dofile('SetupSwap/ManagedMacros.lua');dofile('SetupSwap/MacroIdentity.lua');dofile('SetupSwap/ActionBars.lua')
local AM=SetupSwap
AM.db={profiles={}}
local lib=LibStub('AceDB-3.0')
TomTomDB={};TomTomWaypoints={}
TomTom={}
TomTom.db=lib:New('TomTomDB',{profile={persistence={cleardistance=10,savewaypoints=true},arrow={arrival=15}}},'Default')
TomTom.waydb=lib:New('TomTomWaypoints',{profile={['*']={}}},'Default')
TomTom.profile=TomTom.db.profile;TomTom.waypointprofile=TomTom.waydb.profile
function TomTom:ReloadOptions() self.profile=self.db.profile end
TomTom.db.RegisterCallback(TomTom,'OnProfileChanged','ReloadOptions')
function AM:Inventory() return {{name='TomTom',enabled=true,dependencies={}}},{TomTom={}} end
function IsAddOnLoaded() return true end
function GetAddOnMetadata(_,key) if key=='SavedVariables' then return 'TomTomDB TomTomWaypoints' end end
local snapshot={variables={
    {addon='TomTom',name='TomTomDB',scope='SavedVariables',mode='ace',value=AM:AceSnapshot(TomTom.db)},
    {addon='TomTom',name='TomTomWaypoints',scope='SavedVariables',mode='ace',value=AM:AceSnapshot(TomTom.waydb)},
}}
local cached=TomTom.profile
AM:ApplySettings(snapshot,true,'gamepad',true)
assert(cached.persistence==nil,'Real AceDB did not invalidate the old profile as expected')
assert(TomTom.profile==TomTom.db.profile and TomTom.profile.persistence.cleardistance==10)
assert(TomTom.waypointprofile==TomTom.waydb.profile)
print('PASS Installed TomTom AceDB reproduces stripped old defaults; restored cache is readable before callbacks')
table.insert(AM.startupSettingsCallbacks,1,{db={callbacks={Fire=function()
    assert(TomTom.profile.persistence.cleardistance==10)
end}},target='gamepad'})
AM:RefreshStartupSettings()
assert(TomTom.profile==TomTom.db.profile)
print('PASS Consumer callback can request a waypoint before TomTom refresh with installed AceDB')
AM:ApplySettings(snapshot,true,'desktop',false)
assert(TomTom.profile==TomTom.db.profile and TomTom.profile.persistence.cleardistance==10)
print('PASS Fallback restore also keeps installed TomTom profile cache readable')

-- Exercise the exact position persistence code from the user's TomTom build.
local file=io.open('../tomtom-inspect/TomTom.lua','r')
if file then
    local source=file:read('*a');file:close()
    local positionCode=assert(source:match('(%-%- Persist complete anchors.-)\nfunction TomTom:ADDON_LOADED'))
    assert(load(positionCode,'TomTom native position functions'))()
    UIParent={GetName=function() return 'UIParent' end,GetWidth=function() return 1000 end,
        GetHeight=function() return 800 end,GetEffectiveScale=function() return 1 end}
    local function window(name,x,y,scale)
        local f={point='CENTER',relative=UIParent,rel='BOTTOMLEFT',x=x,y=y,scale=scale or 1,userPlaced=true}
        function f:GetName() return name end
        function f:GetParent() return UIParent end
        function f:GetPoint() return self.point,self.relative,self.rel,self.x,self.y end
        function f:GetCenter() return self.x,self.y end
        function f:GetEffectiveScale() return self.scale end
        function f:IsMovable() return true end
        function f:IsProtected() return false end
        function f:ClearAllPoints() end
        function f:SetPoint(point,relative,rel,x,y) self.point=point;self.relative=relative;self.rel=rel;self.x=x;self.y=y end
        function f:SetUserPlaced(value) self.userPlaced=value end
        _G[name]=f;return f
    end
    TomTomCrazyArrow=window('TomTomCrazyArrow',300,600,.8)
    TomTomBlock=window('TomTomBlock',500,100)
    TomTom.db.profile.arrow.position={point='CENTER',relativeTo='UIParent',rel='BOTTOMLEFT',x=10,y=20}
    TomTom.db.profile.block={position={point='CENTER',relativeTo='UIParent',rel='BOTTOMLEFT',x=30,y=40}}
    local windows={TomTomCrazyArrow,TomTomBlock}
    function EnumerateFrames(previous)
        if not previous then return windows[1] end
        if previous==windows[1] then return windows[2] end
    end
    dofile('SetupSwap/FrameLayouts.lua')
    local desktop={addons={TomTom=true}}
    local layouts=AM:CaptureFrameLayouts(desktop)
    assert(#layouts==2)
    AM.db.profiles.desktop=desktop
    function ReloadUI() end
    function AM:CaptureActionBars() return {version=1,context=self:ActionBarContext(),slots={}} end
    assert(AM:BeginSettingsCapture('desktop',false))
    AM.db.pendingSettings=nil
    local saved=AM:AceSnapshot(TomTom.db)
    assert(saved.profile.arrow.position.x==300 and saved.profile.arrow.position.y==600)
    print('PASS Pre-capture sync saves the actual arrow position instead of an older native anchor')

    -- Recreate the native DB as the mage, like a new character login.
    lib.db_registry[TomTom.db]=nil;lib.db_registry[TomTom.waydb]=nil
    function UnitName() return 'Mage' end
    TomTom.db=lib:New('TomTomDB',{profile={arrow={scale=1},block={}}},'Mage')
    TomTom.profile=TomTom.db.profile
    TomTomCrazyArrow.x=900;TomTomCrazyArrow.y=50
    TomTomCrazyArrow.scale=1.2
    TomTom.db.RegisterCallback(TomTom,'OnProfileChanged',function(self)
        self.profile=self.db.profile;self:RestoreWindowPositions()
    end)
    AM:ApplySettings({variables={{addon='TomTom',name='TomTomDB',scope='SavedVariables',mode='ace',value=saved}}},false,'desktop',true)
    AM:RefreshStartupSettings()
    AM:ApplyFrameLayouts(layouts,desktop)
    assert(math.abs(TomTomCrazyArrow.x*TomTomCrazyArrow.scale-240)<.000001)
    assert(math.abs(TomTomCrazyArrow.y*TomTomCrazyArrow.scale-480)<.000001)
    print('PASS Shared arrow layout restores on the mage with a different frame scale')
    local x,y=TomTomCrazyArrow.x,TomTomCrazyArrow.y
    TomTom:RestoreWindowPositions()
    assert(TomTomCrazyArrow.x==x and TomTomCrazyArrow.y==y and not TomTomCrazyArrow.userPlaced)
    assert(TomTom.db.profile.arrow.position.x==x and TomTom.db.profile.arrow.position.y==y)
    print('PASS Later native TomTom refresh cannot undo the shared arrow restore')

    local alternate={{name='TomTomCrazyArrow',addon='TomTom',generic=true,point='CENTER',relativePoint='BOTTOMLEFT',x=.8,y=.2}}
    for i=1,4 do
        AM:ApplyFrameLayouts(alternate,desktop);TomTom:RestoreWindowPositions()
        assert(math.abs(TomTomCrazyArrow.x*1.2-800)<.000001)
        AM:ApplyFrameLayouts(layouts,desktop);TomTom:RestoreWindowPositions()
        assert(math.abs(TomTomCrazyArrow.x*1.2-240)<.000001)
    end
    print('PASS Repeated alternate/shared layouts survive native arrow refreshes')
    assert(TomTomBlock.x==500 and TomTomBlock.y==100)
    print('PASS TomTom coordinate block retains its independent saved position')
end

-- Reproduce test5's photographed fallback using TomTom's actual AceDB library:
-- early seed succeeds, but a later initializer selects another native profile.
local repairSnapshot=AM:CopySettings(snapshot)
repairSnapshot.variables[1].value.profile.arrow={arrival=42}
AM.db.profiles.gamepad={settings=repairSnapshot,captureSettings=true}
AM:ApplySettings(repairSnapshot,true,'gamepad',true)
local rollback=AM.db.settingsBackup
TomTom.db:SetProfile('Default');TomTom.waydb:SetProfile('Default')
local otherCallbacks=0
AM.startupSettingsCallbacks[#AM.startupSettingsCallbacks+1]={db={callbacks={Fire=function()
    otherCallbacks=otherCallbacks+1
    assert(TomTom.profile==TomTom.db.profile and TomTom.profile.persistence.cleardistance==10)
    assert(TomTom.waypointprofile==TomTom.waydb.profile)
end}},target='SetupSwap-gamepad'}
AM.db.pendingSettings={kind='restore',name='gamepad',character=AM:CharacterKey(),earlyApplied=true,earlyCount=2}
local reloads=0
function AM:RequestFollowupReload() reloads=reloads+1 end
AM:FinishSettingsOperation()
assert(reloads==0 and AM.db.pendingSettings==nil)
assert(TomTom.db:GetCurrentProfile()=='SetupSwap-gamepad' and TomTom.waydb:GetCurrentProfile()=='SetupSwap-gamepad')
assert(TomTom.db.profile.arrow.arrival==42 and TomTom.profile.persistence.cleardistance==10)
assert(AM.db.settingsBackup==rollback and otherCallbacks==1)
assert(AM.db.lastStartupReconcile.count==2)
print('PASS Installed TomTom AceDB reproduces late profile reselection and reconciles both native databases without a second reload')
print('PASS Native cache defaults, snapshot values, original rollback backup and other startup callbacks survive reconciliation')
assert(AM:ReconcileStartupProfiles(repairSnapshot,'gamepad')==0)
print('PASS Correct TomTom native profiles do not need repeated reconciliation')

-- The fix must not silently bypass an unavailable or unrelated native database.
local missing={variables={{addon='TomTom',name='TomTomMissing',scope='SavedVariables',mode='ace',value={profile={}}}}}
local priorDeclarations=AM.SettingsDeclarations
function AM:SettingsDeclarations(addon)
    local result=priorDeclarations(self,addon)
    result[#result+1]={addon='TomTom',name='TomTomMissing',scope='SavedVariables'}
    return result
end
local pending={kind='restore',name='missing',character=AM:CharacterKey(),earlyApplied=true}
AM.db.profiles.missing={settings=missing};AM.db.pendingSettings=pending
AM:FinishSettingsOperation()
assert(reloads==0 and not pending.earlyApplied and pending.earlyFallback:find('TomTom',1,true))
print('PASS An unavailable native database still retains the safety fallback rather than reporting a successful repair')
