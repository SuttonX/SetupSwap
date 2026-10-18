local checks=0
local function check(ok,label) assert(ok,label);checks=checks+1;print('PASS '..label) end
local function session(options)
 options=options or {}
 local frames={};local loaded={SetupSwap=false,TomTom=true,Later=false,Demand=false}
 local env=setmetatable({}, {__index=_G});env._G=env
 function env.CreateFrame()
  local f={scripts={},events={}}
  function f:RegisterEvent(e) self.events[e]=true end
  function f:UnregisterEvent(e) self.events[e]=nil end
  function f:SetScript(k,v) self.scripts[k]=v end
  frames[#frames+1]=f;return f
 end
 local function event(e,...)
  for i=1,#frames do local f=frames[i];if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f,e,...) end end
 end
 local function source(path) assert(loadfile(path,'t',env))('SetupSwap') end
 function env.GetRealmName() if not options.identityMissing then return 'Realm' end end
 function env.UnitName() if not options.identityMissing then return 'Mage' end end
 function env.InCombatLockdown() return false end
 function env.GetNumAddOns() return 5 end
 local names={'SetupSwap','!SetupSwapLoader','TomTom','Later','Demand'}
 function env.GetAddOnInfo(i)
  local name=type(i)=='number' and names[i] or i
  return name,name,'',true,true
 end
 function env.IsAddOnLoaded(name) return loaded[name]==true end
 function env.IsAddOnLoadOnDemand(name) return name=='Demand' end
 function env.GetAddOnDependencies() end
 function env.GetAddOnMetadata(addon,field) if field=='SavedVariables' then return addon..'DB' end end
 env.SlashCmdList={};env.DEFAULT_CHAT_FRAME={AddMessage=function() end}
 env.TomTomDB={setting='old TomTom'};env.LaterDB={setting='old Later'}
 local initializedWith
 -- Target's login handler deliberately registers BEFORE the helper.
 local target=env.CreateFrame();target:RegisterEvent('PLAYER_LOGIN')
 target:SetScript('OnEvent',function() initializedWith=env.TomTomDB.setting end)
 source('!SetupSwapLoader/Loader.lua')
 source('SetupSwap/Core.lua');source('SetupSwap/Snapshots.lua')
 local AM=env.SetupSwap
 function AM:Initialize() self.db=env.SetupSwapAccountDB end
 local items={}
 for _,name in ipairs({'TomTom','Later','Demand'}) do
  items[#items+1]={addon=name,name=name..'DB',scope='SavedVariables',mode='flat',value={setting='target '..name}}
 end
 items[#items+1]={addon='!BugGrabber',name='BugGrabberDB',scope='SavedVariables',mode='flat',value={errors={}}}
 local bars={token='rollback untouched'}
 local db={profiles={gamepad={addons={SetupSwap=true,TomTom=true,Later=true,Demand=true},captureSettings=true,settings={version=1,variables=items}}},
  pendingActionBarBackup=bars,pendingSettings={kind='restore',early=true,name='gamepad',character='Realm/Mage'}}
 if options.noPending then db.pendingSettings=nil end
 local applies,follows=0,0
 local apply=AM.ApplySettings
 function AM:ApplySettings(...)
  applies=applies+1
  if options.fail then error('simulated unsafe database') end
  return apply(self,...)
 end
 function AM:SavedActionBars() return options.bars and bars or nil end
 function AM:ValidateActionBars() end
 function AM:SnapshotMacrosReady() error('Pre-login restore queried native macros') end
 function AM:CaptureActionBars() error('Pre-login restore captured native bars') end
 function AM:ActionBarContext() return 'Realm/Mage/1' end
 function AM:StageActionBars() end
 function AM:RequestFollowupReload() follows=follows+1 end
 env.BugGrabberDB={errors={{message='keep'}}}
 local errors=env.BugGrabberDB.errors
 event('ADDON_LOADED','Earlier')
 check(applies==0,'No restore before main SavedVariables are available')
 env.SetupSwapAccountDB=db;loaded.SetupSwap=true
 event('ADDON_LOADED','SetupSwap')
 check(applies==0,'Wait for selected snapshot owners rather than partially restoring')
 loaded.Later=true;event('ADDON_LOADED','Later')
 return {env=env,AM=AM,db=db,event=event,errors=errors,stats=function() return applies,follows,initializedWith end}
end
local s=session({bars=true})
check(s.stats()==1 and s.db.pendingSettings.earlyApplied and s.env.TomTomDB.setting=='target TomTom' and s.env.LaterDB.setting=='target Later','Settings restore before PLAYER_LOGIN when TomTom loaded before the helper')
check(s.db.settingsBackup.actionBars['Realm/Mage/1'].token=='rollback untouched','Existing rollback bars retained without early native macro queries')
check(s.env.BugGrabberDB.errors==s.errors and s.env.DemandDB==nil,'BugGrabber data untouched and demand addons not forced to load')
s.event('ADDON_LOADED','Another');s.event('PLAYER_LOGIN')
check(s.stats()==1 and select(3,s.stats())=='target TomTom','Earlier target login handlers see restored settings; helper does not apply twice')
s.AM:FinishSettingsOperation()
check(select(2,s.stats())==0 and s.db.lastRestoreMode.mode=='single reload' and s.db.pendingSettings==nil,'Successful queued switch completes without a second reload')
local ordinary=session({noPending=true});ordinary.event('PLAYER_LOGIN')
check(ordinary.stats()==0 and ordinary.env.TomTomDB.setting=='old TomTom','Ordinary login never restores settings without a queued switch')
local failed=session({fail=true});failed.event('ADDON_LOADED','Another');failed.event('PLAYER_LOGIN')
check(failed.stats()==1 and not failed.db.pendingSettings.earlyApplied and failed.db.pendingSettings.earlyFallback:find('simulated unsafe database',1,true),'Failed restore retains fallback and does not repeat early attempts')
local late=session({identityMissing=true});late.event('PLAYER_LOGIN')
check(late.stats()==0 and late.db.pendingSettings~=nil,'Unavailable pre-login identity leaves safety fallback intact')
print(checks..' single-reload startup checks passed')
