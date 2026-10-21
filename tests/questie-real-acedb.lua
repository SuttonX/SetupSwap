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
