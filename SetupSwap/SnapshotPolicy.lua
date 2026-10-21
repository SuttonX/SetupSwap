local AM=SetupSwap
-- Questie's compiled content database belongs to Questie, not to a UI profile.
local cacheKeys={npcBin=true,npcPtrs=true,questBin=true,questPtrs=true,
    objBin=true,objPtrs=true,itemBin=true,itemPtrs=true,dbIsCompiled=true,dbCompiledVersion=true}
-- Everything in Questie's character scope is gameplay state unless explicitly
-- identified as a display preference. Future quest-data fields stay excluded.
local characterState=setmetatable({}, {__index=function(_,key) return key~='isTrackerExpanded' end})
local flatState={char=true}
function AM:PreserveSettingsKeys(variable,path)
    if variable~='QuestieConfig' then return end
    if path=='global' or path=='scopes/global' then return cacheKeys end
    if path=='char' or path=='scopes/char' then return characterState end
    if path=='' then return flatState end
end
function AM:SettingsScopeView(variable,scope,value)
    if type(value)~='table' then return value end
    local preserve=self:PreserveSettingsKeys(variable,scope)
    if not preserve then return value end
    local result={}
    for key,item in pairs(value) do if not preserve[key] then result[key]=item end end
    return result
end
function AM:CopyVariableSettings(variable,value,budget)
    if variable=='QuestieConfig' and type(value)=='table' then
        local view={}
        for key,item in pairs(value) do
            if key~='char' then
                view[key]=key=='global' and self:SettingsScopeView(variable,'global',item) or item
            end
        end
        return self:CopySettings(view,budget)
    end
    return self:CopySettings(value,budget)
end
function AM:CompactSnapshots(db)
    if type(db)~='table' then return end
    local removed,bytes=0,0
    local function compact(snapshot)
        for _,item in ipairs(type(snapshot)=='table' and snapshot.variables or {}) do
            if item.name=='QuestieConfig' and type(item.value)=='table' then
                local function prune(value,preserve)
                    if type(value)~='table' then return end
                    for key,valueItem in pairs(value) do
                        if preserve[key] then
                            removed=removed+1
                            if type(valueItem)=='string' then bytes=bytes+#valueItem end
                            value[key]=nil
                        end
                    end
                end
                if item.mode=='ace' then
                    local scopes=item.value.scopes or {}
                    prune(scopes.global,cacheKeys)
                    prune(scopes.char,characterState)
                    for _,values in pairs(item.value.namespaceScopes or {}) do
                        prune(values.char,characterState)
                        prune(values.global,cacheKeys)
                    end
                else
                    prune(item.value.global,cacheKeys)
                    prune(item.value,flatState)
                end
            end
        end
    end
    for _,profile in pairs(db.profiles or {}) do if type(profile)=='table' then compact(profile.settings) end end
    compact(db.settingsBackup)
    if removed>0 then
        local previous=db.snapshotCleanup or {}
        db.snapshotCleanup={version=1,fields=(previous.fields or 0)+removed,bytes=(previous.bytes or 0)+bytes}
    end
    return removed,bytes
end
