local frames={}
function CreateFrame() local f={scripts={}};function f:RegisterEvent() end;function f:SetScript(k,v) self.scripts[k]=v end;frames[#frames+1]=f;return f end
function GetRealmName() return 'Ashbringer' end
function UnitName() return 'Druid' end
function GetActiveTalentGroup() return 1 end
function InCombatLockdown() return false end
function GetCursorInfo() return nil end
function IsAddOnLoaded() return true end
local addons={{name='SetupSwap',enabled=true},{name='DesktopUI',enabled=false},{name='GamepadUI',enabled=true},{name='Questie-335',enabled=true}}
function GetNumAddOns() return #addons end
function GetAddOnInfo(id)
 for i,e in ipairs(addons) do if id==i or id==e.name then return e.name,e.name,'',e.enabled,true,nil end end
end
function GetAddOnDependencies() end
function GetAddOnMetadata(addon,field) if addon=='Questie-335' and field=='SavedVariables' then return 'QuestieConfig' end end
local refuse=false
function EnableAddOn(index) assert(type(index)=='number','Expected native addon index');if not refuse then addons[index].enabled=true end end
function DisableAddOn(index) assert(type(index)=='number','Expected native addon index');if not refuse then addons[index].enabled=false end end
local reloads=0;function ReloadUI() reloads=reloads+1 end
SlashCmdList={};DEFAULT_CHAT_FRAME={AddMessage=function() end}
local macros={[37]={name=' ',body='/cast Heal'}}
local nativeCharacter=1
function GetNumMacros() return 0,nativeCharacter end
function GetMacroInfo(index) local row=macros[index];if row then return row.name,1,row.body end end
function GetActionInfo() end
function ClearCursor() end
dofile('SetupSwap/Core.lua');dofile('SetupSwap/SnapshotPolicy.lua');dofile('SetupSwap/Snapshots.lua')
dofile('SetupSwap/ManagedMacros.lua');dofile('SetupSwap/MacroIdentity.lua');dofile('SetupSwap/ActionBars.lua')
local AM=SetupSwap;AM.db={profiles={}}
local n=0;local function check(ok,message) assert(ok,message);n=n+1;print('PASS '..message) end
local global={questBin=string.rep('cache',10000),questPtrs='pointers',dbIsCompiled=true,showQuestIcons=true}
local native={profile={trackerFontSize=14},global=global}
local capture=AM:AceSnapshot(native,nil,'QuestieConfig')
check(capture.scopes.global.questBin==nil and capture.scopes.global.questPtrs==nil and capture.scopes.global.dbIsCompiled==nil,'Ace capture excludes compiled Questie data before copying')
check(global.questBin~=nil and global.dbIsCompiled and capture.scopes.global.showQuestIcons,'Native Questie cache and captured options remain intact')
local flat=AM:CopyVariableSettings('QuestieConfig',{global=global,profiles={Default={font=14}}})
check(flat.global.questBin==nil and flat.profiles.Default.font==14,'Flat Questie backup excludes caches while retaining settings')
local unrelated=AM:CopyVariableSettings('OtherAddon',{global=global})
check(unrelated.global.questBin==global.questBin,'Cache policy is restricted to QuestieConfig')
AM.db.profiles.desktop={settings={variables={{name='QuestieConfig',mode='ace',value={scopes={global=AM:CopySettings(global)}}}},actionBars={keep='macro mapping'}}}
AM.db.settingsBackup={variables={{name='QuestieConfig',mode='flat',value={global=AM:CopySettings(global)}}}}
local removed,bytes=AM:CompactSnapshots(AM.db)
check(removed==6 and bytes>100000 and AM.db.profiles.desktop.settings.actionBars.keep=='macro mapping','Existing profiles and backup compact without touching macro snapshots')
check(AM:CompactSnapshots(AM.db)==0,'Cache compaction is idempotent')
local raw=AM:PrepareRawAceSettings(capture,'SetupSwap-desktop',{global=global,profiles={Existing={keep=true}}},'QuestieConfig')
check(raw.global.questBin==global.questBin and raw.global.dbIsCompiled and raw.profiles.Existing.keep,'Early native preparation preserves the live compiled database')
QuestieConfig={}
function native:SetProfile(name) self.current=name end
function native:GetCurrentProfile() return self.current end
AM.AceDatabase=function(_,name) if name=='QuestieConfig' then return native end end
local snapshot={variables={{name='QuestieConfig',addon='Questie-335',scope='SavedVariables',mode='ace',value=capture}}}
capture.scopes.global.showQuestIcons=false
AM:ApplySettings(snapshot,false,'desktop',true)
check(native.global.questBin==global.questBin and native.global.dbIsCompiled and not native.global.showQuestIcons,'Live Ace restoration preserves caches while restoring UI options')
AM.AceDatabase=function() end
AM.db.profiles.desktop={addons={SetupSwap=true,DesktopUI=true,GamepadUI=false,['Questie-335']=true},captureSettings=true,settings={variables={{addon='Questie-335'}}}}
AM.db.profiles.gamepad={addons={SetupSwap=true,DesktopUI=false,GamepadUI=true,['Questie-335']=true}}
AM.db.active='gamepad'
check(AM:Switch('desktop') and addons[2].enabled and not addons[3].enabled and reloads==1,'Addon switching applies native index flags and verifies them before reload')
check(AM:CheckPendingAddonSwitch() and #AM.db.lastAddonSwitch.mismatches==0,'Successful persisted addon selection is verified after reload')
AM.db.pendingSettings=nil
AM.db.active='gamepad';addons[2].enabled=false;addons[3].enabled=true
refuse=true
check(not AM:Switch('desktop') and reloads==1 and AM.db.active=='gamepad','Refused addon changes do not report success or trigger a reload')
refuse=false
AM.db.pendingAddonSwitch={name='desktop',target={DesktopUI=true,GamepadUI=false},character='Ashbringer/Druid',previousActive='gamepad'}
AM.db.active='desktop';AM.db.pendingSettings={kind='restore'}
check(not AM:CheckPendingAddonSwitch() and AM.db.pendingSettings==nil and AM.db.active=='gamepad','Lost enable flags stop settings restoration into the wrong addon set')
local context=AM:ActionBarContext()
local slots={}
for i=1,144 do if i<=120 or i>=133 then slots[i]={kind='empty'} end end
slots[1]={kind='macro',name=' ',body='/cast Heal',characterMacro=true,macroToken='m10'}
local saved={version=1,context=context,slots=slots}
AM.db={profiles={desktop={addons={SetupSwap=true},captureSettings=true,settings={actionBars={[context]=saved}}}},active='desktop',macroIdentitySerial=10,
 macroIdentities={account={},characters={['Ashbringer/Druid']={[37]={name=' ',body='/cast Heal',token='m10'}}}}}
check(AM:ResolveMacroIdentity('m10',true)==37,'Existing native macro mapping is retained')
macros={}
check(AM:ResolveMacroIdentity('m10',true)==nil and AM.db.macroIdentities.characters['Ashbringer/Druid'][37].token=='m10','Partial macro scans retain the previous identity without placing a macro')
nativeCharacter=0
check(not AM:SnapshotMacrosReady(saved) and AM.db.macroIdentities.characters['Ashbringer/Druid'][37].token=='m10','An unexpectedly empty native list cannot erase saved identities')
AM.ProfileMatchesEnabled=function() return true end
check(not AM:SaveActionBarsOnly('desktop') and AM:SavedActionBars(AM.db.profiles.desktop.settings)==saved,'Unavailable native macros cannot overwrite a saved bar capture')
local calls=0;local realApply=AM.ApplyActionBars
AM.ApplyActionBars=function() calls=calls+1;return 0,{} end
AM:StageActionBars(AM.db.profiles.desktop.settings,'desktop')
local runner=frames[#frames];runner.scripts.OnEvent(runner);runner.scripts.OnUpdate(runner,2)
check(calls==0 and AM.db.pendingActionBars~=nil,'Queued action restore waits for native macro data')
macros={[37]={name=' ',body='/cast Heal'}};nativeCharacter=1
runner.scripts.OnUpdate(runner,2)
check(calls==1 and AM:ResolveMacroIdentity('m10',true)==37,'Native macros arriving late resume restoration with the original identity')
AM.ApplyActionBars=realApply
AM.db.macroIdentities.characters['Ashbringer/Druid']={}
check(AM:ResolveMacroIdentity('m10',true)==37,'A lost registry can recover a uniquely identifiable saved macro token')
macros={};nativeCharacter=0;AM:ForgetDeletedMacro(37);AM:SyncMacroIdentities()
macros={[37]={name=' ',body='/cast Heal'}};nativeCharacter=1
check(AM:ResolveMacroIdentity('m10',true)==nil and AM.db.macroIdentities.deleted.m10,'Explicit deletion prevents an identical replacement from inheriting a saved identity')
check(slots[1].macroToken=='m10','Original profile macro mapping remains stored after deletion')
-- A diagnostic addon sorts before the helper, but is not profile settings.
addons[#addons+1]={name='!BugGrabber',enabled=true}
local oldMetadata=GetAddOnMetadata
function GetAddOnMetadata(addon,field)
 if addon=='!BugGrabber' and field=='SavedVariables' then return 'BugGrabberDB' end
 return oldMetadata(addon,field)
end
BugGrabberDB={errors={{message='keep current errors'}},limit=1000}
local errors=BugGrabberDB.errors
local bugItem={addon='!BugGrabber',name='BugGrabberDB',scope='SavedVariables',mode='flat',value={errors={},limit=10}}
check(#AM:SettingsDeclarations('!BugGrabber')==0,'BugGrabber diagnostic data is excluded from new settings captures')
AM:ApplySettings({variables={bugItem}},false,'desktop',true)
check(BugGrabberDB.errors==errors and BugGrabberDB.limit==1000,'Old BugGrabber snapshots leave the live error database and preferences untouched')
SetupSwapAccountDB={profiles={desktop={settings={variables={bugItem}}}},pendingSettings={kind='restore',name='desktop',character='Ashbringer/Druid',early=true}}
check(AM:TryEarlySettingsRestore({alreadyLoaded={['!BugGrabber']=true}}) and SetupSwapAccountDB.pendingSettings.earlyApplied,'BugGrabber loading before the helper no longer forces another reload')
local questItem={addon='Questie-335',name='QuestieConfig',scope='SavedVariables',mode='ace',value=capture}
SetupSwapAccountDB.profiles.desktop.settings.variables={bugItem,questItem}
SetupSwapAccountDB.pendingSettings={kind='restore',name='desktop',character='Ashbringer/Druid',early=true}
check(not AM:TryEarlySettingsRestore({alreadyLoaded={['!BugGrabber']=true,['Questie-335']=true}})
 and SetupSwapAccountDB.pendingSettings.earlyFallback=='Startup helper loaded after Questie-335','Load-order safeguard still applies to real addon settings')
SetupSwapAccountDB.profiles.desktop.settings.variables={{addon='!BugGrabber',name='BugGrabberDB',scope='SavedVariables',mode='ace',value={profile={}}}}
SetupSwapAccountDB.pendingSettings={kind='restore',name='desktop',character='Ashbringer/Druid',earlyApplied=true}
AM.StageFrameLayouts=function() end;AM.StageChatLayout=function() end;AM.ApplyFrameLayouts=function() end
local followups=0;AM.RequestFollowupReload=function() followups=followups+1 end
AM:FinishSettingsOperation()
check(followups==0 and BugGrabberDB.errors==errors,'Excluded legacy Ace snapshots cannot trigger the post-startup fallback')
print(n..' compatibility regression checks passed')
