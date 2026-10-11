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
print(checks..' checks passed')
