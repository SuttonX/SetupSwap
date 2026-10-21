local frames={}
function CreateFrame() local f={};function f:RegisterEvent() end;function f:SetScript(k,v) self[k]=v end;frames[#frames+1]=f;return f end
function GetRealmName() return 'TestRealm' end
function UnitName() return 'Mage' end
function UnitFactionGroup() return 'Horde' end
function InCombatLockdown() return false end
function IsAddOnLoaded() return true end
function GetAddOnMetadata(_,scope) if scope=='SavedVariables' then return 'QuestieConfig' elseif scope=='SavedVariablesPerCharacter' then return 'QuestieConfigCharacter' end end
SlashCmdList={};DEFAULT_CHAT_FRAME={AddMessage=function() end}
dofile('SetupSwap/Core.lua');dofile('SetupSwap/SnapshotPolicy.lua');dofile('SetupSwap/Snapshots.lua')
local AM=SetupSwap;AM.db={profiles={}}
function AM:Inventory() return {{name='Questie',enabled=true}},{Questie={}} end
function AM:SavedActionBars() end
local n=0
local function check(ok,message) assert(ok,message);n=n+1 end
local source={profile={trackerFontSizeQuest=14,trackerSetpoint='TOPRIGHT'},
 global={questBin='compiled cache',showQuestIcons=true},
 char={TrackedQuests={[101]=true},TrackerHiddenObjectives={['101 1']=true},TrackerFocus='101 1',complete={[102]=true},journey={{quest=101}},townsfolkClass='DRUID',isTrackerExpanded=false,futureGameplayField={101}}}
local captured=AM:AceSnapshot(source,nil,'QuestieConfig')
check(captured.scopes.char.isTrackerExpanded==false and next(captured.scopes.char,'isTrackerExpanded')==nil,'Only verified character display preference captured')
check(captured.profile.trackerFontSizeQuest==14 and captured.profile.trackerSetpoint=='TOPRIGHT','Questie visual options retained')
check(source.char.TrackedQuests[101] and source.global.questBin,'Capture leaves native quest state and database intact')
local mage={TrackedQuests={[201]=true},TrackerHiddenObjectives={['201 2']=true},TrackerFocus='201 2',complete={[202]=true},journey={{quest=201}},townsfolkClass='MAGE',isTrackerExpanded=true,futureGameplayField={201}}
local tracked,hidden,journey,future=mage.TrackedQuests,mage.TrackerHiddenObjectives,mage.journey,mage.futureGameplayField
local native={profile={trackerFontSizeQuest=10},global={questBin='mage cache'},char=mage}
function native:SetProfile(name) self.target=name end
function native:GetCurrentProfile() return self.target or 'Original' end
AM.AceDatabase=function() return native end
QuestieConfig={}
local old={profile=source.profile,scopes={char=source.char,global=source.global}}
local function snapshot(value,mode) return {variables={{addon='Questie',name='QuestieConfig',scope='SavedVariables',mode=mode or 'ace',value=value}}} end
local legacy=snapshot(old)
AM:ApplySettings(legacy,true,'gamepad',true)
check(mage.TrackedQuests==tracked and tracked[201] and not tracked[101],'Legacy live restore cannot import another character quests')
check(mage.TrackerHiddenObjectives==hidden and mage.TrackerFocus=='201 2' and mage.complete[202],'Hidden objectives focus and completion stay character local')
check(mage.journey==journey and mage.futureGameplayField==future and mage.townsfolkClass=='MAGE','Journey class caches and future gameplay fields retain identity')
check(native.profile.trackerFontSizeQuest==14 and mage.isTrackerExpanded==false,'Live restore still applies customization')
check(native.global.questBin=='mage cache','Legacy snapshot cannot overwrite compiled cache')
local backup=AM.db.settingsBackup.variables[1].value
check(backup.scopes.char.TrackedQuests==nil,'Rollback captures exclude quest data too')
AM:ApplySettings(legacy,false,'desktop',false)
tracked[299]=true
frames[#frames].OnEvent()
check(mage.TrackedQuests==tracked and tracked[299],'Logout reapply preserves quest progress made since restore')
local key='Mage - TestRealm'
local raw={profiles={Original={keep=true}},profileKeys={[key]='Original'},char={[key]=mage,['Druid - TestRealm']=source.char},global={questBin='raw cache'}}
AM.AceDatabase=function() end
QuestieConfig=raw
AM:ApplySettings(legacy,false,'gamepad',true)
check(QuestieConfig.char[key].TrackedQuests==tracked and tracked[201] and not tracked[101],'Raw early restore retains destination character quest tables')
check(QuestieConfig.char['Druid - TestRealm'].TrackedQuests[101],'Raw early restore leaves other characters alone')
check(QuestieConfig.profiles['SetupSwap-gamepad'].trackerFontSizeQuest==14 and QuestieConfig.profileKeys[key]=='SetupSwap-gamepad','Raw early restore still seeds selected UI profile')
local flat={char={['Druid - TestRealm']=source.char},global=source.global,profiles={Default=source.profile}}
local flatCapture=AM:CopyVariableSettings('QuestieConfig',flat)
check(flatCapture.char==nil and flatCapture.profiles.Default.trackerFontSizeQuest==14,'Flat captures omit all per-character quest stores')
local charMap=QuestieConfig.char
AM:ApplySettings(snapshot(flat,'flat'),false,'desktop',true)
check(QuestieConfig.char==charMap and QuestieConfig.char[key].TrackedQuests==tracked,'Old flat restores preserve complete native character store')
QuestieConfig=nil
AM:ApplySettings(snapshot(flat,'flat'),false,'desktop',true)
check(QuestieConfig.char==nil,'Missing native globals cannot import legacy flat quest data')
local storage={profiles={desktop={settings=AM:CopySettings(legacy)},gamepad={settings=snapshot(AM:CopySettings(flat),'flat')}},settingsBackup=AM:CopySettings(legacy)}
AM:CompactSnapshots(storage)
check(storage.profiles.desktop.settings.variables[1].value.scopes.char.TrackedQuests==nil and storage.profiles.gamepad.settings.variables[1].value.char==nil,'Existing snapshots automatically shed quest stores')
check(storage.profiles.desktop.settings.variables[1].value.profile.trackerSetpoint=='TOPRIGHT' and storage.settingsBackup.variables[1].value.scopes.char.isTrackerExpanded==false,'Cleanup keeps profiles and display preferences')
check(AM:CompactSnapshots(storage)==0,'Quest-state cleanup is idempotent')
local declarations=AM:SettingsDeclarations('Questie')
for _,item in ipairs(declarations) do check(item.name~='QuestieConfigCharacter','Obsolete character variable excluded') end
local unrelated=AM:AceSnapshot(source,nil,'OtherAddon')
check(unrelated.scopes.char.TrackedQuests[101],'Policy stays limited to Questie')
print(n..' Questie character-state checks passed')
