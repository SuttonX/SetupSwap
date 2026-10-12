local frames={}
function CreateFrame()
    local f={scripts={}}
    function f:SetScript(name,fn) self.scripts[name]=fn end
    function f:RegisterEvent() end
    frames[#frames+1]=f;return f
end
local char,group,combat,vehicle,cursor='Druid',1,false,false,nil
local spells={{name='Heal',rank='Rank 1',id=100},{name='Barkskin',rank='',id=200}}
local macros={[1]={name='Help',body='/help'},[37]={name='Help',body='/help'}}
local companions={{name='Horse',id=900}}
local items={[123]=2,[456]=1}
local bars={}
local failSlot
BOOKTYPE_SPELL='spell'
function GetRealmName() return 'TestRealm' end
function UnitName() return char end
function GetActiveTalentGroup() return group end
function InCombatLockdown() return combat end
function UnitInVehicle() return vehicle end
function GetCursorInfo() return cursor and cursor.kind end
function ClearCursor() cursor=nil end
function GetActionInfo(slot)
    local e=bars[slot];if e then return e.kind,e.id,e.subtype end
end
function GetNumSpellTabs() return 1 end
function GetSpellTabInfo() return '',nil,0,#spells end
function GetSpellName(index) local e=spells[index];if e then return e.name,e.rank end end
function GetSpellLink(index) local e=spells[index];if e then return '|Hspell:'..e.id..'|h' end end
function GetMacroInfo(index) local e=macros[index];if e then return e.name,1,e.body end end
function GetItemCount(id) return items[id] or 0 end
function GetNumCompanions() return #companions end
function GetCompanionInfo(_,index) local e=companions[index];return 1,e.name,e.id end
function GetNumEquipmentSets() return 1 end
function GetEquipmentSetInfo() return 'Healing' end
function PickupSpell(index) cursor={kind='spell',id=index} end
function PickupItem(id) cursor={kind='item',id=id} end
function PickupMacro(index) cursor={kind='macro',id=index} end
function PickupCompanion(kind,index) cursor={kind='companion',subtype=kind,id=index} end
function PickupEquipmentSet() cursor={kind='equipmentset',id='Healing'} end
function PickupAction(slot) cursor=bars[slot];bars[slot]=nil end
function PlaceAction(slot)
    if failSlot==slot then failSlot=nil;error('simulated placement failure') end
    local old=bars[slot];bars[slot]=cursor;cursor=old
end
function ReloadUI() end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
dofile('SetupSwap/Core.lua')
dofile('SetupSwap/Snapshots.lua')
dofile('SetupSwap/ActionBars.lua')
local AM=SetupSwap
AM.db={profiles={}}
function AM:Print() end
function AM:Inventory() return {},{} end
function AM:CaptureSettings() return {version=1,variables={},addons=0,skipped={}} end
local checks=0
local function check(ok,label) assert(ok,label);checks=checks+1;print('PASS '..label) end
local function fixture()
    bars={[1]={kind='spell',id=1},[2]={kind='spell',id=2},[3]={kind='item',id=123},[4]={kind='macro',id=1},[5]={kind='companion',subtype='MOUNT',id=1},[6]={kind='equipmentset',id='Healing'},[133]={kind='spell',id=2}}
end
fixture()
local saved=AM:CaptureActionBars()
check(saved.slots[7].kind=='empty' and not saved.slots[121] and saved.slots[133].kind=='spell','Empty slots and extra player slots captured; possession excluded')
bars[1]={kind='spell',id=2};bars[7]={kind='item',id=456}
local count,skipped=AM:ApplyActionBars(saved)
check(count==2 and #skipped==0 and bars[1].id==1 and bars[7]==nil,'Desktop/gamepad assignments and empty slots restore')
spells[1],spells[2]=spells[2],spells[1]
bars[1]={kind='spell',id=1}
AM:ApplyActionBars(saved)
check(bars[1].id==2,'Spellbook reorder resolved by spell ID')
macros[2]=macros[1];macros[1]=nil;bars[4]={kind='macro',id=37}
AM:ApplyActionBars(saved)
check(bars[4].id==2,'Macro index changes resolved without crossing account/character scope')
macros[2].body='/changed';bars[4]={kind='spell',id=1}
count,skipped=AM:ApplyActionBars(saved)
check(bars[4].kind=='spell' and #skipped==1,'Edited macro leaves destination unchanged and is reported')
items[123]=0;bars[3]={kind='item',id=456}
count,skipped=AM:ApplyActionBars(saved)
check(bars[3].id==456 and #skipped==2,'Missing item leaves destination unchanged')
spells[2]=nil;bars[1]={kind='spell',id=1}
count,skipped=AM:ApplyActionBars(saved)
check(bars[1].id==1 and #skipped==3,'Unlearned spell leaves destination unchanged')
spells={{name='Heal',rank='Rank 1',id=100},{name='Barkskin',rank='',id=200}}
macros={[1]={name='Help',body='/help'},[37]={name='Help',body='/help'}};items[123]=2
fixture();bars[1]={kind='spell',id=2};bars[2]={kind='spell',id=1};failSlot=2
local ok,err=pcall(AM.ApplyActionBars,AM,saved)
check(not ok and bars[1].id==2 and bars[2].id==1 and not cursor,'Placement failure rolls back already changed slots')
combat=true;ok=pcall(AM.CaptureActionBars,AM);combat=false
check(not ok,'Combat capture blocked')
vehicle=true;ok=pcall(AM.CaptureActionBars,AM);vehicle=false
check(not ok,'Vehicle capture blocked')
cursor={kind='item',id=456};ok=pcall(AM.ApplyActionBars,AM,saved);ClearCursor()
check(not ok,'Held cursor object preserved by refusing restore')
char='Other';ok=pcall(AM.ApplyActionBars,AM,saved);char='Druid'
check(not ok,'Other character snapshot rejected')
group=2;ok=pcall(AM.ApplyActionBars,AM,saved);group=1
check(not ok,'Other talent spec snapshot rejected')
local invalid=AM:CopySettings(saved);invalid.slots[1]=nil
ok=pcall(AM.ApplyActionBars,AM,invalid)
check(not ok,'Incomplete snapshot rejected before mutation')
AM.db.profiles.desktop={addons={},captureSettings=true,settings={actionBars={other='preserved'}}}
fixture();check(AM:BeginSettingsCapture('desktop',false),'Integrated capture schedules reload')
AM:FinishSettingsOperation()
local settings=AM.db.profiles.desktop.settings
check(settings.actionBars.other=='preserved' and AM:SavedActionBars(settings),'Capture retains other character/spec snapshots')
AM.db.pendingSettings={kind='restore',name='desktop',character='TestRealm/Druid',earlyApplied=true}
AM:FinishSettingsOperation()
check(AM.db.pendingActionBars~=nil and AM:OperationBusy(),'Early restore stages action bars and blocks new operations')
local runner=frames[#frames];runner.scripts.OnEvent(runner)
combat=true;runner.scripts.OnUpdate(runner,2)
check(AM.db.pendingActionBars~=nil,'Queued restore waits for combat')
combat=false;cursor={kind='item',id=123};runner.scripts.OnUpdate(runner,2)
check(AM.db.pendingActionBars~=nil and cursor~=nil,'Queued restore waits without discarding cursor object')
ClearCursor();bars[1]={kind='spell',id=2};runner.scripts.OnUpdate(runner,2)
check(not AM.db.pendingActionBars and bars[1].id==1,'Queued restore completes after constraints clear')
AM:StageActionBars(settings,'desktop');group=2;runner.scripts.OnUpdate(runner,2);group=1
check(not AM.db.pendingActionBars,'Queued restore cancels after talent spec changes')
AM:StageActionBars({},'old')
check(not AM.db.pendingActionBars,'Old profiles keep action bars unchanged')
AM.db.pendingActionBarBackup=saved;AM:ApplySettings(settings,true,'desktop')
check(AM.db.settingsBackup.actionBars[saved.context].slots[1].spellID==100 and not AM.db.pendingActionBarBackup,'Pre-switch action bars included in settings undo backup')
AM.db.pendingSettings={kind='undo',character='TestRealm/Druid'};AM:FinishSettingsOperation()
check(AM.db.pendingActionBars~=nil,'Undo stages saved action-bar backup')
AM.db.pendingActionBars=nil
fixture();bars[1]={kind='flyout',id=1}
local _,unsupported=AM:ApplyActionBars(saved)
check(bars[1].kind=='flyout' and #unsupported==1,'Unsupported current action preserved for safe rollback')
fixture();local rank=AM:CopySettings(saved);rank.slots[1].spellID=nil;rank.slots[1].rank='Rank 2'
local _,ranks=AM:ApplyActionBars(rank)
check(bars[1].id==1 and #ranks==1,'Unavailable exact spell rank is not replaced by another rank')
AM.db.pendingSettings={kind='restore',name='desktop',character='TestRealm/Druid'}
AM:FinishSettingsOperation()
check(AM.db.pendingActionBars~=nil,'Fallback settings restore also stages action bars')
runner.scripts.OnEvent(runner);AM.followupReload=true;runner.scripts.OnUpdate(runner,2)
check(AM.db.pendingActionBars~=nil,'Action bars wait for required fallback reload')
AM.followupReload=nil;AM.db.pendingActionBars=nil
-- Character addon selection and removed binding behavior.
local inventory={
    {name='SetupSwap',enabled=true,dependencies={}},
    {name='HealBot',enabled=false,dependencies={'Library'}},
    {name='Library',enabled=false,dependencies={}},
    {name='Questie',enabled=true,dependencies={}},
}
function AM:Inventory()
    local byName={};for _,e in ipairs(inventory) do byName[e.name]=e end
    return inventory,byName
end
AM.db={profiles={desktop={addons={SetupSwap=true,HealBot=false,Library=false,Questie=true}},gamepad={addons={SetupSwap=true,HealBot=false,Library=false,Questie=false}}}}
local desktop=AM.db.profiles.desktop
char='Druid'
AM:SaveAddonSelection(desktop,{SetupSwap=true,HealBot=true,Library=true,Questie=true},true)
check(desktop.addons.HealBot==false and desktop.characterAddons['TestRealm/Druid'].HealBot==true,'Healer override preserves shared selection')
check(desktop.characterAddons['TestRealm/Druid'].Questie==nil,'Only changed addon choices stored')
check(AM:Plan('desktop').target.HealBot and AM:Plan('desktop').target.Library,'Switch plan uses healer overrides and dependencies')
group=2;check(AM:Plan('desktop').target.HealBot,'Character addon choices apply to both talent specs');group=1
char='Mage';check(not AM:Plan('desktop').target.HealBot,'Mage inherits shared selection without healer addon')
local realm='OtherRealm';GetRealmName=function() return realm end
char='Druid';check(not AM:Plan('desktop').target.HealBot,'Same character name on another realm is isolated')
GetRealmName=function() return 'TestRealm' end;char='Mage'
AM:SaveAddonSelection(desktop,{SetupSwap=true,HealBot=false,Library=false,Questie=false},false)
char='Druid'
check(AM:Plan('desktop').target.HealBot and not AM:Plan('desktop').target.Questie,'Shared edits propagate without replacing healer overrides')
AM:SaveAddonSelection(AM.db.profiles.gamepad,{SetupSwap=true,HealBot=false,Library=false,Questie=true},true)
check(AM:Plan('desktop').target.HealBot and not AM:Plan('gamepad').target.HealBot,'Overrides are independent for each profile')
AM:SaveAddonSelection(desktop,desktop.addons,false)
check(not AM:HasCharacterOverrides(desktop) and not AM:Plan('desktop').target.HealBot,'Reset removes only current character overrides')
-- UI load, save and Save + Switch keep the chosen scope.
dofile('SetupSwap/UI.lua')
function AM:RefreshUI() end
local name='desktop'
AM.ui={selected=name,profileName={GetText=function() return name end,SetText=function(_,v) name=v end}}
AM:LoadDraft();AM.ui.draft.customize=true
AM:SetSelection('desktop','HealBot',true,AM.ui.draft)
check(AM.ui.draft.addons.Library,'Checkbox selection includes dependencies')
AM:SaveDraft()
check(AM:HasCharacterOverrides(desktop) and desktop.addons.HealBot==false,'Editor Save overrides preserves shared addon list')
AM:LoadDraft()
check(AM.ui.draft.customize and AM.ui.draft.addons.HealBot and not AM:DraftDiffers('desktop'),'Editor reopens matching saved character scope')
char='Mage';AM:LoadDraft()
check(not AM.ui.draft.customize and not AM.ui.draft.addons.HealBot,'Mage editor opens shared scope')
inventory[2].enabled=false;inventory[3].enabled=false;inventory[4].enabled=false
check(AM:ProfileMatchesEnabled('desktop'),'Profile detection uses mage shared selection')
char='Druid';check(not AM:ProfileMatchesEnabled('desktop'),'Profile detection respects character override')
local switched
local switch=AM.Switch;AM.Switch=function(_,v) switched=v;return true end
AM:ConfirmSwitch({addons={SetupSwap=true,HealBot=true,Library=true,Questie=false},customize=true,captureSettings=false},'desktop')
check(switched=='desktop' and AM:HasCharacterOverrides(desktop) and desktop.addons.HealBot==false,'Save + Switch retains character scope')
AM.Switch=switch
-- Calls to native binding APIs would fail the test immediately.
SetBinding=function() error('Native bindings must not be written') end
SaveBindings=function() error('Native bindings must not be saved') end
GetBinding=function() error('Native bindings must not be captured') end
desktop.settings={bindings={version=1,keys={Q='STRAFELEFT'}},variables={}}
AM.db.pendingBindings={value=desktop.settings.bindings};AM.db.pendingBindingBackup={keys={}}
AM.db.lastBindingRestore={};AM.db.settingsBackup={bindings={keys={}}}
AM:RemoveLegacyBindings()
check(not desktop.settings.bindings and not AM.db.pendingBindings and not AM.db.settingsBackup.bindings,'Legacy binding snapshots and queued restores discarded without API calls')
check(not AM.CaptureBindings and not AM.ApplyBindings and not AM.StageBindings,'Keybinding feature absent')
AM:ApplySettings({variables={},bindings={version=1,keys={Q='STRAFELEFT'}}},true,'desktop')
check(not AM.db.settingsBackup.bindings,'Old binding snapshots ignored by settings apply and backup')
AM:BeginSettingsCapture('desktop',false)
check(not AM.db.pendingSettings.bindings,'Settings capture no longer reads keybindings')
AM.db.pendingSettings=nil
GetAddOnMetadata=function(_,key)
    if key=='SavedVariablesPerCharacter' then return 'ConsolePortBindingSet ConsolePortLoaderBinding ConsolePortMouse' end
end
local declarations=AM:SettingsDeclarations('ConsolePort')
local foundMouse=false
for _,e in ipairs(declarations) do
    assert(e.name~='ConsolePortBindingSet' and e.name~='ConsolePortLoaderBinding')
    if e.name=='ConsolePortMouse' then foundMouse=true end
end
check(foundMouse,'ConsolePort binding variables excluded even when declared by installed TOC')
inventory[#inventory+1]={name='ConsolePort',enabled=true,dependencies={}}
IsAddOnLoaded=function() return true end
ConsolePortBindingSet={original=true};ConsolePortLoaderBinding={original=true}
AM:ApplySettings({variables={
    {addon='ConsolePort',name='ConsolePortBindingSet',scope='SavedVariablesPerCharacter',value={changed=true}},
    {addon='ConsolePort',name='ConsolePortLoaderBinding',scope='SavedVariablesPerCharacter',value={changed=true}},
}},false,'desktop')
check(ConsolePortBindingSet.original and ConsolePortLoaderBinding.original,'Older ConsolePort binding snapshots cannot overwrite live binding variables')
-- TomTom holds a cached pointer that AceDB invalidates on profile changes.
local live={persistence={savewaypoints=true},arrow={arrival=15}}
local old={persistence={savewaypoints=false}}
local native={profile=old,defaults={profile={persistence={savewaypoints=true}}}}
function native:SetProfile(target)
    self.target=target;old.persistence=nil;self.profile=live
end
function native:GetCurrentProfile() return self.target end
function native:RegisterDefaults() end
native.callbacks={Fire=function() end}
TomTom={db=native,profile=old}
local aceLookup=AM.AceDatabase
AM.AceDatabase=function(_,name) if name=='TomTomDB' then return native end end
GetAddOnMetadata=function(addon,key) if addon=='TomTom' and key=='SavedVariables' then return 'TomTomDB' end end
inventory[#inventory+1]={name='TomTom',enabled=true,dependencies={}}
TomTomDB={};AM:ApplySettings({variables={{addon='TomTom',name='TomTomDB',scope='SavedVariables',mode='ace',value={profile=live}}}},false,'gamepad',true)
check(TomTom.profile==native.profile and TomTom.profile.persistence.savewaypoints,'Early profile restore reconnects TomTom cache before deferred callbacks')
local consumer={callbacks={Fire=function() assert(TomTom.profile.persistence.savewaypoints,'Questie saw stale TomTom profile') end}}
TomTom.profile={};AM.startupSettingsCallbacks={{db=consumer,target='gamepad'},{db=native,target='gamepad'}}
check(AM:RefreshStartupSettings()==2 and TomTom.profile==native.profile,'Questie callback can precede TomTom callback without stale cached profile')
local waydb={profile={waypoints=true}};TomTom.waydb=waydb;TomTom.waypointprofile={}
AM:ReconnectNativeProfileCache(waydb)
check(TomTom.waypointprofile==waydb.profile,'TomTom waypoint profile cache also reconnected')
local preserved=TomTom.profile;AM:ReconnectNativeProfileCache({profile={}})
check(TomTom.profile==preserved,'Unrelated addon databases do not modify TomTom cache')
AM.AceDatabase=aceLookup
-- Minimap masks may be applied by ElvUI before SetupSwap loads.
local mask
Minimap={SetMaskTexture=function(_,texture) mask=texture end}
local capturedHooks={}
hooksecurefunc=function(_,_,fn) capturedHooks[#capturedHooks+1]=fn end
SetupSwapEarlyLoader={minimapMask='Interface\\ChatFrame\\ChatFrameBackground'}
ElvUI={{private={general={minimap={enable=true}}}}}
dofile('SetupSwap/NativeState.lua')
AM.minimapMask=nil
check(AM:CaptureNativeState().minimapMask==SetupSwapEarlyLoader.minimapMask,'Early observed ElvUI mask captured before main addon hook')
AM:RestoreNativeState({minimapMask='Textures\\MinimapMask'})
check(mask=='Interface\\ChatFrame\\ChatFrameBackground','Enabled ElvUI restores square mask even with old circular snapshot')
ElvUI[1].private.general.minimap.enable=false
AM:RestoreNativeState({minimapMask='Interface\\ChatFrame\\ChatFrameBackground'})
check(mask=='Textures\\MinimapMask','Disabled ElvUI minimap skin restores circular mask')
IsAddOnLoaded=function() return false end
AM:RestoreNativeState({minimapMask='Textures\\MinimapMask'})
check(mask=='Textures\\MinimapMask','Gamepad without ElvUI restores saved circular mask')
AM:RestoreNativeState({minimapMask='CustomMask'})
check(mask=='CustomMask','Other minimap masks remain supported without ElvUI')
-- Old snapshots must not detach Questie's internal rows or resize handles.
UIParent={GetWidth=function() return 1000 end,GetHeight=function() return 800 end,GetEffectiveScale=function() return 1 end}
local function movable(name,parent)
    local frame={name=name,parent=parent,changes=0}
    function frame:GetName() return self.name end
    function frame:GetParent() return self.parent end
    function frame:IsMovable() return true end
    function frame:IsProtected() return false end
    function frame:GetPoint() return 'TOPLEFT',self.parent,'TOPLEFT',10,20 end
    function frame:GetCenter() return 500,400 end
    function frame:GetEffectiveScale() return 1 end
    function frame:ClearAllPoints() self.changes=self.changes+1 end
    function frame:SetPoint() self.changes=self.changes+1 end
    _G[name]=frame;return frame
end
local root=movable('Questie_BaseFrame',UIParent)
local rows=movable('linePool3',root)
local sizer=movable('Questie_Sizer',root)
local nested=movable('QuestieInternalText',rows)
local independent=movable('OtherAddonWindow',UIParent)
local enumerated={root,rows,sizer,nested,independent}
function EnumerateFrames(previous)
    if not previous then return enumerated[1] end
    for i,f in ipairs(enumerated) do if f==previous then return enumerated[i+1] end end
end
IsAddOnLoaded=function() return true end
dofile('SetupSwap/FrameLayouts.lua')
local layouts=AM:CaptureFrameLayouts({addons={['Questie-335']=true}})
check(#layouts==2 and layouts[1].name=='Questie_BaseFrame' and layouts[2].name=='OtherAddonWindow','Capture keeps tracker anchor and independent windows; excludes tracker internals')
local oldLayouts={}
for _,f in ipairs(enumerated) do oldLayouts[#oldLayouts+1]={name=f.name,addon='__ui',generic=true,point='CENTER',relativePoint='BOTTOMLEFT',x=.5,y=.5} end
local changed=AM:ApplyFrameLayouts(oldLayouts,{addons={['Questie-335']=true}})
check(changed==2 and rows.changes==0 and sizer.changes==0 and nested.changes==0,'Older snapshots cannot reanchor Questie rows, resize handle or descendants')
check(root.changes==2 and independent.changes==2,'Tracker root and other windows still restore positions')
print(checks..' checks passed')
