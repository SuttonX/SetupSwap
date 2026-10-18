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
function AM:HasSavedMacroScope(characterMacro)
    for _,profile in pairs((self.db or SetupSwapAccountDB or {}).profiles or {}) do
        local snapshot=self:SavedActionBars(profile.settings)
        for _,entry in pairs(snapshot and snapshot.slots or {}) do
            if entry.kind=='macro' and entry.characterMacro==characterMacro
                and not ((self.db or SetupSwapAccountDB).macroIdentities and (self.db or SetupSwapAccountDB).macroIdentities.deleted
                    and (self.db or SetupSwapAccountDB).macroIdentities.deleted[entry.macroToken]) then return true end
        end
    end
    return false
end
function AM:SyncMacroIdentities()
    local db=self.db or SetupSwapAccountDB
    if not db then return end
    db.macroIdentities=db.macroIdentities or {characters={}}
    local book=db.macroIdentities
    book.characters=book.characters or {}
    local maxAccount=MAX_ACCOUNT_MACROS or 36
    local scopes={{container=book,key='account',first=1,last=maxAccount},
        {container=book.characters,key=key(),first=maxAccount+1,last=maxAccount+(MAX_CHARACTER_MACROS or 18)}}
    self.macroScanStatus={}
    local nativeAccount,nativeCharacter
    if GetNumMacros then nativeAccount,nativeCharacter=GetNumMacros() end
    for scopeIndex,scope in ipairs(scopes) do
        local old=scope.container[scope.key] or {}
        local current=scan(scope.first,scope.last)
        local nativeCount=scopeIndex==1 and nativeAccount or nativeCharacter
        local ready=not (type(nativeCount)=='number' and nativeCount~=count(current))
        if count(current)==0 and (count(old)>0 or self:HasSavedMacroScope(scopeIndex==2)) then ready=false end
        self.macroScanStatus[scopeIndex==1 and 'account' or 'character']={ready=ready,count=count(current),native=nativeCount}
        if ready then
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
            -- Recover a lost registry only by a unique saved name/body/scope match.
            -- Two saved identities competing for the same macro are left unresolved.
            local present,claims,plans={},{},{}
            for _,row in pairs(old) do if row.token then present[row.token]=true end end
            for _,profile in pairs(db.profiles or {}) do
                local snapshot=self:SavedActionBars(profile.settings)
                for _,entry in pairs(snapshot and snapshot.slots or {}) do
                    if entry.kind=='macro' and entry.characterMacro==(scopeIndex==2) and entry.macroToken
                        and not present[entry.macroToken] and not (book.deleted and book.deleted[entry.macroToken])
                        and not self:ManagedMacroIdentity(entry.body) then
                        local match,ambiguous
                        for index,row in pairs(current) do
                            if equal(entry,row) then if match then ambiguous=true;break end;match=index end
                        end
                        if match and not ambiguous and not present[current[match].token] then
                            local token=entry.macroToken
                            if plans[token] and plans[token]~=match then plans[token]=false
                            elseif plans[token]==nil then plans[token]=match end
                            claims[match]=claims[match] or {}
                            claims[match][token]=true
                        end
                    end
                end
            end
            for token,index in pairs(plans) do
                if index then
                    local n=0;for _ in pairs(claims[index]) do n=n+1 end
                    if n==1 then current[index].token=token end
                end
            end
            scope.container[scope.key]=current
        end
    end
    return book
end
function AM:MacroIdentityAt(index)
    local book=self:SyncMacroIdentities()
    if not book then return end
    local characterMacro=index>(MAX_ACCOUNT_MACROS or 36)
    local status=self.macroScanStatus and self.macroScanStatus[characterMacro and 'character' or 'account']
    if status and not status.ready then return end
    local rows=characterMacro and book.characters[key()] or book.account
    return rows and rows[index] and rows[index].token
end
function AM:SnapshotMacrosReady(snapshot)
    self:SyncMacroIdentities()
    for _,entry in pairs(snapshot and snapshot.slots or {}) do
        if entry.kind=='macro' then
            local state=self.macroScanStatus[entry.characterMacro and 'character' or 'account']
            if state and not state.ready then return false end
        end
    end
    return true
end
function AM:ResolveMacroIdentity(token,characterMacro)
    local book=self:SyncMacroIdentities()
    local status=self.macroScanStatus and self.macroScanStatus[characterMacro and 'character' or 'account']
    if status and not status.ready then return nil,'Native macros unavailable; saved identity retained' end
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
        local scanned=scan(first,last)
        local a,c;if GetNumMacros then a,c=GetNumMacros() end
        local expected=index>(MAX_ACCOUNT_MACROS or 36) and c or a
        if rows and (expected==nil or expected==count(scanned)) and count(scanned)==count(rows)-1 then
            if rows[index] and rows[index].token then
                book.deleted=book.deleted or {};book.deleted[rows[index].token]=true
            end
            rows[index]=nil
        end
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
