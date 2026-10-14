local AM=SetupSwap
local function key() return tostring(GetRealmName() or '')..'/'..tostring(UnitName('player') or '') end
local function scan(first,last)
    local rows={}
    if GetMacroInfo then
        for index=first,last do
            local name,icon,body=GetMacroInfo(index)
            if name and body then rows[index]={name=name,body=body} end
        end
    end
    return rows
end
local function count(rows) local n=0;for _ in pairs(rows) do n=n+1 end;return n end
local function equal(a,b) return a and b and a.name==b.name and a.body==b.body end
function AM:SyncMacroIdentities()
    local db=self.db or SetupSwapAccountDB
    if not db then return end
    db.macroIdentities=db.macroIdentities or {characters={}}
    local book=db.macroIdentities
    book.characters=book.characters or {}
    local maxAccount=MAX_ACCOUNT_MACROS or 36
    local scopes={{container=book,key='account',first=1,last=maxAccount},
        {container=book.characters,key=key(),first=maxAccount+1,last=maxAccount+(MAX_CHARACTER_MACROS or 18)}}
    for _,scope in ipairs(scopes) do
        local old=scope.container[scope.key] or {}
        local current=scan(scope.first,scope.last)
        local used={}
        local sameSlots=count(old)==count(current)
        if sameSlots then for index in pairs(old) do if not current[index] then sameSlots=false;break end end end
        -- Keep native slot identity for unchanged lists, including identical
        -- blank-named macros. After additions/deletions use unique fingerprints
        -- to follow index shifts; ambiguous old duplicates are not guessed.
        if sameSlots then
            for index,row in pairs(current) do
                if equal(old[index],row) then row.token=old[index].token;used[index]=true end
            end
        end
        for index,row in pairs(current) do
            if not row.token then
                local match,ambiguous
                for previous,entry in pairs(old) do
                    if not used[previous] and equal(entry,row) then
                        if match then ambiguous=true;break end
                        match=previous
                    end
                end
                local newMatches=0
                for _,other in pairs(current) do if not other.token and equal(row,other) then newMatches=newMatches+1 end end
                if match and not ambiguous and newMatches==1 then
                    row.token=old[match].token;used[match]=true
                end
            end
        end
        -- Edits retain their native slot. This includes changing commands,
        -- name and icon. Observed DeleteMacro invalidates its slot first, so a
        -- later CreateMacro cannot inherit the deleted macro's identity.
        if sameSlots then
            for index,row in pairs(current) do
                if not row.token and old[index] and not used[index] then
                    row.token=old[index].token;used[index]=true
                end
            end
        end
        for _,row in pairs(current) do
            if not row.token then
                db.macroIdentitySerial=(tonumber(db.macroIdentitySerial) or 0)+1
                row.token='m'..db.macroIdentitySerial
            end
        end
        scope.container[scope.key]=current
    end
    return book
end
function AM:MacroIdentityAt(index)
    local book=self:SyncMacroIdentities()
    if not book then return end
    local rows=index>(MAX_ACCOUNT_MACROS or 36) and book.characters[key()] or book.account
    return rows and rows[index] and rows[index].token
end
function AM:ResolveMacroIdentity(token,characterMacro)
    local book=self:SyncMacroIdentities()
    local rows=book and (characterMacro and book.characters[key()] or book.account)
    local found
    for index,row in pairs(rows or {}) do
        if row.token==token then
            if found then return nil,'Ambiguous tracked macro' end
            found=index
        end
    end
    return found,'Tracked macro missing; it may have been deleted or could not be identified safely'
end
function AM:ForgetDeletedMacro(index)
    local db=self.db or SetupSwapAccountDB
    local book=db and db.macroIdentities
    if not book then return end
    local rows
    if type(index)=='string' then
        -- Native name overload selects the first matching macro index.
        local found
        for _,scope in ipairs({book.account or {},book.characters[key()] or {}}) do
            for i,row in pairs(scope) do if row.name==index and (not found or i<found) then found=i end end
        end
        index=found
    end
    if type(index)=='number' then
        rows=index>(MAX_ACCOUNT_MACROS or 36) and book.characters[key()] or book.account
        local first=index>(MAX_ACCOUNT_MACROS or 36) and (MAX_ACCOUNT_MACROS or 36)+1 or 1
        local last=index>(MAX_ACCOUNT_MACROS or 36) and (MAX_ACCOUNT_MACROS or 36)+(MAX_CHARACTER_MACROS or 18) or (MAX_ACCOUNT_MACROS or 36)
        -- A refused/no-op deletion must not invalidate a live macro.
        if rows and count(scan(first,last))<count(rows) then rows[index]=nil end
    end
end
function AM:AfterMacroEdit(index,name,icon,body)
    local db=self.db or SetupSwapAccountDB
    local book=db and db.macroIdentities
    if book and type(index)=='number' then
        local character=index>(MAX_ACCOUNT_MACROS or 36)
        local rows=character and book.characters[key()] or book.account
        local old=rows and rows[index]
        if old then
            local first=character and (MAX_ACCOUNT_MACROS or 36)+1 or 1
            local last=character and (MAX_ACCOUNT_MACROS or 36)+(MAX_CHARACTER_MACROS or 18) or (MAX_ACCOUNT_MACROS or 36)
            local expected={name=name or old.name,body=body or old.body}
            local current=scan(first,last)
            local match,ambiguous
            for i,row in pairs(current) do
                if equal(row,expected) then
                    if match then ambiguous=true;break end
                    match=i
                end
            end
            if match and not ambiguous then
                -- Update its fingerprint in the old list first. Reconciliation
                -- can then follow a rename-induced reorder without overwriting
                -- the identity of the macro previously occupying its new index.
                rows[index]={name=expected.name,body=expected.body,token=old.token}
            end
        end
    end
    self:SyncMacroIdentities()
end
function AM:AdoptLegacyMacroIdentities()
    self:SyncMacroIdentities()
    -- Existing snapshots can be upgraded only when their saved contents still
    -- identify one live macro uniquely. Never guess between blank names.
    for _,profile in pairs(self.db and self.db.profiles or {}) do
        local value=type(profile)=='table' and self:SavedActionBars(profile.settings)
        local slots=type(value)=='table' and type(value.slots)=='table' and value.slots or {}
        for _,entry in pairs(slots) do
            if type(entry)=='table' and entry.kind=='macro' and type(entry.name)=='string' and type(entry.body)=='string'
                and type(entry.characterMacro)=='boolean' and not entry.macroToken and not self:ManagedMacroIdentity(entry.body) then
                local start=entry.characterMacro and (MAX_ACCOUNT_MACROS or 36)+1 or 1
                local finish=entry.characterMacro and (MAX_ACCOUNT_MACROS or 36)+(MAX_CHARACTER_MACROS or 18) or (MAX_ACCOUNT_MACROS or 36)
                local match,ambiguous
                for index=start,finish do
                    local name,_,body=GetMacroInfo(index)
                    if name==entry.name and body==entry.body then
                        if match then ambiguous=true;break end
                        match=index
                    end
                end
                if match and not ambiguous then entry.macroToken=self:MacroIdentityAt(match) end
            end
        end
    end
end
if hooksecurefunc then
    if DeleteMacro then hooksecurefunc('DeleteMacro',function(index)
        AM:ForgetDeletedMacro(index);AM:SyncMacroIdentities()
    end) end
    if CreateMacro then hooksecurefunc('CreateMacro',function() AM:SyncMacroIdentities() end) end
    if EditMacro then hooksecurefunc('EditMacro',function(...) AM:AfterMacroEdit(...) end) end
end
local watcher=CreateFrame('Frame')
watcher:RegisterEvent('PLAYER_LOGIN');watcher:RegisterEvent('UPDATE_MACROS')
watcher:SetScript('OnEvent',function(_,event)
    if event=='PLAYER_LOGIN' then AM:AdoptLegacyMacroIdentities()
    else
        -- UPDATE_MACROS may fire inside a native API call. Let its post-hook
        -- process deletion/edit information before reconciling the new list.
        watcher:SetScript('OnUpdate',function(frame)
            frame:SetScript('OnUpdate',nil);AM:SyncMacroIdentities()
        end)
    end
end)
