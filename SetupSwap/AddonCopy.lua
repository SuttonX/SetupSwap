local AM=SetupSwap
local function shortName(name)
    local base=name:lower():gsub('[-_]%d[%d%.]*$',''):gsub('[^a-z0-9]','')
    if base=='' or not base:match('^[a-z]') then base='addon'..base end
    return base
end
local function hash(name)
    local value=0
    for i=1,#name do value=(value*31+name:byte(i))%1000000007 end
    return tostring(value)
end
function AM:CopyAddonNames()
    local names,titles={},{}
    local function add(name,title)
        if type(name)=='string' and name~=self.name and name~='!SetupSwapLoader' and name~='__ui' then
            names[name]=true;titles[name]=title or titles[name] or name
        end
    end
    for _,entry in ipairs(self:Inventory()) do add(entry.name,entry.title) end
    for _,profile in pairs(self.db.profiles or {}) do
        for _,item in ipairs(profile.settings and profile.settings.variables or {}) do add(item.addon) end
        for _,item in ipairs(profile.settings and profile.settings.layouts or {}) do add(item.addon) end
    end
    local ordered,counts={},{}
    for name in pairs(names) do ordered[#ordered+1]=name;local base=shortName(name);counts[base]=(counts[base] or 0)+1 end
    table.sort(ordered)
    local result,aliases={},{}
    for _,name in ipairs(ordered) do
        local base=shortName(name)
        local alias=counts[base]>1 and (base..'_'..hash(name)) or base
        -- A hash collision is refused rather than resolving to the wrong addon.
        if aliases[alias]~=nil then aliases[alias]=false else aliases[alias]=name end
        result[#result+1]={name=name,title=titles[name],alias=alias}
    end
    return result,aliases
end
function AM:CopyAddonNamesText()
    local entries,aliases=self:CopyAddonNames()
    local lines={'Copy one addon\'s saved settings and positions:',
        '/ss copy ADDON FROM_PROFILE TO_PROFILE',
        'Example: /ss copy tomtom gamepad desktop',
        'Then switch to the destination profile to apply the copied capture.',
        'Addon choices, character overrides, and native action bars are unchanged.','',
        'Short name = installed addon name (profiles with a saved capture)'}
    for _,entry in ipairs(entries) do
        local profiles={}
        for name,profile in pairs(self.db.profiles or {}) do
            local found=false
            for _,field in ipairs({'variables','layouts'}) do
                for _,item in ipairs(profile.settings and profile.settings[field] or {}) do
                    if item.addon==entry.name then found=true;break end
                end
            end
            if found then profiles[#profiles+1]=name end
        end
        table.sort(profiles)
        if aliases[entry.alias] then
            lines[#lines+1]=entry.alias..' = '..entry.name..' ('..(#profiles>0 and table.concat(profiles,', ') or 'not captured')..')'
        end
    end
    return table.concat(lines,'\n')
end
function AM:ShowCopyAddonNames()
    self:ShowDiagnostics(self:CopyAddonNamesText(),'Copy addon names',function() AM:ShowCopyAddonNames() end)
end
function AM:CopyAddonSettings(alias,sourceName,targetName)
    if not self:CanStartOperation() then return false end
    local _,aliases=self:CopyAddonNames()
    local addon=aliases[alias]
    if not addon then self:Print('Unknown or ambiguous addon short name. Use /ss copynames.');return false end
    local source,target=self.db.profiles[sourceName],self.db.profiles[targetName]
    if not source or not target or sourceName==targetName then
        self:Print('Choose two different saved profiles: /ss copy ADDON FROM_PROFILE TO_PROFILE');return false
    end
    local selected={variables={},layouts={}}
    for _,field in ipairs({'variables','layouts'}) do
        for _,item in ipairs(source.settings and source.settings[field] or {}) do
            if item.addon==addon then selected[field][#selected[field]+1]=item end
        end
    end
    if #selected.variables==0 and #selected.layouts==0 then
        self:Print('No saved settings or positions for '..addon..' in '..sourceName..'. Nothing changed.');return false
    end
    local ok,copied=pcall(self.CopySettings,self,selected)
    if not ok then self:Print('Copy stopped: '..tostring(copied)..'. Nothing changed.');return false end
    local previous=target.settings or {version=1}
    -- A shared variable owned by another addon must not be restored twice.
    for _,item in ipairs(copied.variables) do
        item.restoreProfile=nil
        for _,existing in ipairs(previous.variables or {}) do
            if existing.addon~=addon and existing.name==item.name then
                self:Print('Copy stopped: '..item.name..' belongs to another captured addon in the destination. Nothing changed.');return false
            end
        end
    end
    local variables,layouts={},{}
    for _,item in ipairs(previous.variables or {}) do
        if item.addon~=addon or #copied.variables==0 then variables[#variables+1]=item end
    end
    for _,item in ipairs(previous.layouts or {}) do if item.addon~=addon then layouts[#layouts+1]=item end end
    for _,item in ipairs(copied.variables) do variables[#variables+1]=item end
    for _,item in ipairs(copied.layouts) do layouts[#layouts+1]=item end
    -- Commit after validation; no live addon settings or source tables are modified.
    previous.variables=variables;previous.layouts=layouts
    local captured={};for _,item in ipairs(variables) do captured[item.addon]=true end
    previous.addons=0;for _ in pairs(captured) do previous.addons=previous.addons+1 end
    target.settings=previous;target.captureSettings=true
    if self.ui and self.ui.selected==targetName and self.ui.draft then
        self.ui.draft.captureSettings=true;self:RefreshUI()
    end
    self:Print('Copied '..addon..' settings and positions from '..sourceName..' to '..targetName..'. Run /ss '..targetName..' to apply them. Addon choices and action bars are unchanged.')
    return true,#copied.variables,#copied.layouts
end
