-- Reproduce stale IceHUD moduleSettings with real AceDB, not fabricated nils.
strmatch=string.match;unpack=table.unpack;loadstring=load
function wipe(t) for k in pairs(t) do t[k]=nil end;return t end
function GetRealmName() return 'Ashbringer' end
function UnitName() return 'Shifthead' end
function UnitClass() return 'Druid','DRUID' end
function UnitRace() return 'Night Elf','NightElf' end
function UnitFactionGroup() return 'Alliance' end
function GetLocale() return 'enUS' end
function InCombatLockdown() return false end
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
SlashCmdList={};DEFAULT_CHAT_FRAME={AddMessage=function() end}
dofile('../tomtom-test-libs/LibStub.lua')
dofile('../tomtom-test-libs/CallbackHandler-1.0.lua')
dofile('../tomtom-test-libs/AceDB-3.0.lua')
dofile('SetupSwap/Core.lua');dofile('SetupSwap/Snapshots.lua')
local AM=SetupSwap;AM.db={profiles={}}
function AM:SavedActionBars() end
function AM:Inventory() return {{name='IceHUD',enabled=true}},{IceHUD={}} end
function IsAddOnLoaded() return true end
function GetAddOnMetadata(_,key) if key=='SavedVariables' then return 'IceCoreDB' end end
local lib=LibStub('AceDB-3.0')
local defaults={profile={scale=0.9,modules={RangeCheck={scale=1,enabled=false},PetInfo={scale=1,enabled=false},NewModule={scale=1,enabled=true}}}}
IceCoreDB={};IceHUD={IceCore={elements={{elementName='RangeCheck'},{elementName='PetInfo'},{elementName='NewModule'}}}}
IceHUD.db=lib:New('IceCoreDB',defaults,true)
local core=IceHUD.IceCore
function core:SetModuleDatabases()
 for _,element in ipairs(self.elements) do
  element.settings=self.settings
  element.moduleSettings=self.settings.modules[element.elementName]
 end
end
local function bind() core.settings=IceHUD.db.profile;core.accountSettings=IceHUD.db.global;core:SetModuleDatabases() end
local function enable()
 for _,element in ipairs(core.elements) do
  assert(type(element.moduleSettings.scale)=='number' and element.moduleSettings.scale>0,'Usage: IceHUD_'..element.elementName..':SetScale(scale)')
 end
end
bind()
local snapshot={variables={{addon='IceHUD',name='IceCoreDB',scope='SavedVariables',mode='ace',value=AM:AceSnapshot(IceHUD.db)}}}
snapshot.variables[1].value.profile.modules.NewModule=nil -- capture predates this module
local n=0
local function check(ok,label) assert(ok,label);n=n+1;print('PASS '..label) end
local reconnect=AM.ReconnectNativeProfileCache
AM.ReconnectNativeProfileCache=function() end
local oldRange=core.elements[1].moduleSettings
AM:ApplySettings(snapshot,false,'old-reproduction',true)
local ok,err=pcall(enable)
check(not ok and err:find('IceHUD_RangeCheck:SetScale',1,true) and oldRange.scale==nil,'Real AceDB reproduces IceHUD scale error after a silent profile change strips old defaults')
IceHUD.db:SetProfile('Default');bind()
AM.ReconnectNativeProfileCache=reconnect
local callbacks=0
function IceHUD:Refresh()
 callbacks=callbacks+1
 assert(core.settings==self.db.profile)
 enable()
end
IceHUD.db.RegisterCallback(IceHUD,'OnProfileChanged','Refresh')
AM:ApplySettings(snapshot,true,'gamepad',true)
local rollback=AM.db.settingsBackup
check(pcall(enable) and callbacks==0,'All IceHUD modules can create frames before deferred native callbacks run')
check(core.settings==IceHUD.db.profile and core.accountSettings==IceHUD.db.global and core.elements[1].moduleSettings==IceHUD.db.profile.modules.RangeCheck,'Core and module cached settings point to the selected native profile')
check(core.elements[3].moduleSettings==IceHUD.db.profile.modules.NewModule and core.elements[3].moduleSettings.scale==1,'Modules absent from an old capture rebind after native defaults recreate their tables')
AM:RefreshStartupSettings()
check(callbacks==1 and pcall(enable) and AM.db.settingsBackup==rollback,'Normal startup callbacks still run once and preserve the rollback backup')
-- Change an explicit saved scale and disabled-state value without normalizing it.
snapshot.variables[1].value.profile.modules.RangeCheck.scale=1.35
snapshot.variables[1].value.profile.modules.PetInfo.scale=0.8
snapshot.variables[1].value.profile.modules.PetInfo.enabled=false
AM:ApplySettings(snapshot,false,'desktop',false)
check(core.elements[1].moduleSettings.scale==1.35 and core.elements[2].moduleSettings.scale==0.8 and not core.elements[2].moduleSettings.enabled,'Explicit scales and disabled modules remain exactly as captured')
local live=core.settings
AM:ReconnectNativeProfileCache({profile={}})
check(core.settings==live,'Unrelated native databases do not rebind IceHUD')
-- Feed the uploaded gamepad snapshot through the same restore path in isolation.
local fixture=os.getenv('SETUPSWAP_SV_FIXTURE')
if fixture then
 local env={}
 debug.sethook(function() error('Input exceeded instruction limit') end,'',50000000)
 assert(loadfile(fixture,'t',env))();debug.sethook()
 local db=env.SetupSwapAccountDB;local item
 for _,v in ipairs(db.profiles.gamepad.settings.variables) do if v.name=='IceCoreDB' then item=v end end
 assert(item and item.mode=='ace')
 AM:ApplySettings({variables={item}},false,'gamepad',true)
 check(core.elements[1].moduleSettings.scale==item.value.profile.modules.RangeCheck.scale and core.elements[2].moduleSettings.scale==item.value.profile.modules.PetInfo.scale and pcall(enable),'Uploaded gamepad module settings restore without changing captured scales or triggering the reproduced scale error')
end
print(n..' IceHUD native cache checks passed')
