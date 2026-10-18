local AM=SetupSwap
-- Questie's compiled content database belongs to Questie, not to a UI profile.
local cacheKeys={npcBin=true,npcPtrs=true,questBin=true,questPtrs=true,
    objBin=true,objPtrs=true,itemBin=true,itemPtrs=true,dbIsCompiled=true,dbCompiledVersion=true}
function AM:PreserveSettingsKeys(variable,path)
    if variable=='QuestieConfig' and (path=='global' or path=='scopes/global') then return cacheKeys end
end
function AM:SettingsScopeView(variable,scope,value)
    if variable~='QuestieConfig' or scope~='global' or type(value)~='table' then return value end
    local result={}
    for key,item in pairs(value) do if not cacheKeys[key] then result[key]=item end end
    return result
end
function AM:CopyVariableSettings(variable,value,budget)
    if variable=='QuestieConfig' and type(value)=='table' and type(value.global)=='table' then
        local view={};for key,item in pairs(value) do view[key]=item end
        view.global=self:SettingsScopeView(variable,'global',value.global)
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
                local global=item.mode=='ace' and item.value.scopes and item.value.scopes.global or item.value.global
                if type(global)=='table' then
                    for key in pairs(cacheKeys) do
                        local value=global[key]
                        if value~=nil then
                            removed=removed+1;if type(value)=='string' then bytes=bytes+#value end
                            global[key]=nil
                        end
                    end
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
