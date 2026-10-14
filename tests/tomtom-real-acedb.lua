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
