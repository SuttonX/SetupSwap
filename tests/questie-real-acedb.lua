-- Optional integration against Questie-335's actual AceDB libraries.
local root=assert(os.getenv('QUESTIE_LIB_ROOT'))
strmatch=string.match;unpack=table.unpack
function wipe(t) for k in pairs(t) do t[k]=nil end;return t end
function GetRealmName() return 'TestRealm' end
function UnitName() return 'Mage' end
function UnitClass() return 'Mage','MAGE' end
function UnitRace() return 'Orc','Orc' end
function UnitFactionGroup() return 'Horde' end
function GetLocale() return 'enUS' end
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
function IsAddOnLoaded() return true end
function GetAddOnMetadata(_,scope) if scope=='SavedVariables' then return 'QuestieConfig' end end
SlashCmdList={};DEFAULT_CHAT_FRAME={AddMessage=function() end}
dofile(root..'/Libs/LibStub/LibStub.lua')
dofile(root..'/Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua')
dofile(root..'/Compat/Libs/AceDB-3.0/AceDB-3.0.lua')
dofile('SetupSwap/Core.lua');dofile('SetupSwap/SnapshotPolicy.lua');dofile('SetupSwap/Snapshots.lua')
local AM=SetupSwap;AM.db={profiles={}}
function AM:Inventory() return {{name='Questie',enabled=true}},{Questie={}} end
function AM:SavedActionBars() end
QuestieConfig={}
local db=LibStub('AceDB-3.0'):New('QuestieConfig',{profile={trackerFontSizeQuest=10},char={complete={},hidden={},journey={},isTrackerExpanded=true}},true)
db.char.TrackedQuests={[201]=true};db.char.hidden[202]=true
local tracked,hidden=db.char.TrackedQuests,db.char.hidden
local old={profile={trackerFontSizeQuest=14},scopes={char={TrackedQuests={[101]=true},hidden={[102]=true},complete={[103]=true},isTrackerExpanded=false}}}
local snapshot={variables={{addon='Questie',name='QuestieConfig',scope='SavedVariables',mode='ace',value=old}}}
AM:ApplySettings(snapshot,true,'gamepad',true)
assert(db.char.TrackedQuests==tracked and tracked[201] and not tracked[101])
assert(db.char.hidden==hidden and hidden[202] and not hidden[102] and not db.char.complete[103])
assert(db.profile.trackerFontSizeQuest==14 and db.char.isTrackerExpanded==false)
AM:RefreshStartupSettings()
AM:ApplySettings(snapshot,false,'desktop',false)
assert(db.char.TrackedQuests==tracked and db.char.hidden==hidden)
local capture=AM:AceSnapshot(db,nil,'QuestieConfig')
assert(capture.scopes.char.TrackedQuests==nil and capture.scopes.char.hidden==nil and capture.profile.trackerFontSizeQuest==14)
print('5 actual Questie AceDB character-state checks passed')

-- Exercise the actual upstream profile callback: it starts SmoothReset rather
-- than merely repainting options. A pre-login restore must not invoke it while
-- the native staged initialization is still constructing the quest log.
local file=assert(io.open(root..'/Questie.lua'));local source=file:read('*a');file:close()
local callback=assert(source:match('(function Questie:RefreshConfig.-\nend)'))
local resetCount,anchorCount,iconCount=0,0,0
Questie={db=db,SetIcons=function() iconCount=iconCount+1 end,Debug=function() end}
local quest={SmoothReset=function() resetCount=resetCount+1 end}
local tracker={OnProfileChange=function() anchorCount=anchorCount+1 end}
assert(load('local QuestieQuest,TrackerBaseFrame=...\n'..callback,'upstream Questie RefreshConfig'))(quest,tracker)
db.RegisterCallback(Questie,'OnProfileChanged','RefreshConfig')
old.profile.isInitialLogin=true -- legacy snapshot from a different login
old.profile.trackerSetpoint='TOPRIGHT'
db.profile.isInitialLogin=false -- actual current reload
AM.preLoginSettingsRestore=true
AM:ApplySettings(snapshot,true,'gamepad',true)
AM.preLoginSettingsRestore=nil
assert(db.profile.isInitialLogin==false,'Snapshot replaced the live reload marker')
local count=AM:RefreshStartupSettings()
assert(count==0 and resetCount==0 and anchorCount==0 and iconCount==0,'Pre-login restore launched an overlapping Questie reset')
assert(db.profile.trackerSetpoint=='TOPRIGHT' and db.profile.trackerFontSizeQuest==14)
assert(db.char.TrackedQuests==tracked and db.char.hidden==hidden)
local saved=AM:AceSnapshot(db,nil,'QuestieConfig')
assert(saved.profile.isInitialLogin==nil,'Capture saved transient startup state')
-- Raw native seeding must retain the receiving character's active marker too.
local raw={profiles={Current={isInitialLogin=false,trackerFontSizeQuest=10}},profileKeys={['Mage - TestRealm']='Current'},char={['Mage - TestRealm']={TrackedQuests={[201]=true}}}}
local seeded=AM:PrepareRawAceSettings(old,'SetupSwap-raw',raw,'QuestieConfig')
assert(seeded.profiles['SetupSwap-raw'].isInitialLogin==false)
assert(seeded.char['Mage - TestRealm'].TrackedQuests[201] and not seeded.char['Mage - TestRealm'].TrackedQuests[101])
-- A real login must likewise stay a login when the snapshot says reload.
db.profile.isInitialLogin=true;old.profile.isInitialLogin=false
AM.preLoginSettingsRestore=true
AM:ApplySettings(snapshot,false,'desktop',true)
AM.preLoginSettingsRestore=nil
assert(db.profile.isInitialLogin==true)
AM:RefreshStartupSettings()
assert(resetCount==0)
-- Late restores still refresh the already running addon exactly once.
AM:ApplySettings(snapshot,false,'gamepad',true)
AM:RefreshStartupSettings()
assert(resetCount==1 and anchorCount==1 and iconCount==1,'Late restore lost the required native refresh')
-- Providers and unrelated addons must continue receiving startup callbacks.
local other=0
AM.startupSettingsCallbacks={{db=db,target='SetupSwap-gamepad',initializesAtLogin=true},
 {db={callbacks={Fire=function() other=other+1 end}},target='Other'}}
assert(AM:RefreshStartupSettings()==1 and other==1 and resetCount==1)
-- Legacy cleanup and flat captures must remove session flags, preserving options.
local flat=AM:CopyVariableSettings('QuestieConfig',{profiles={Current={isInitialLogin=false,trackerFontSizeQuest=14}}})
assert(flat.profiles.Current.isInitialLogin==nil and flat.profiles.Current.trackerFontSizeQuest==14)
local legacy={profiles={desktop={settings=snapshot}}}
old.profile.isInitialLogin=true
AM:CompactSnapshots(legacy)
assert(old.profile.isInitialLogin==nil and old.profile.trackerSetpoint=='TOPRIGHT')
print('14 Questie native startup callback and session-marker checks passed')
