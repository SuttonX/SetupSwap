local AM=SetupSwap
local registered={}
local function identifier(value)
    return type(value)=='string' and #value<=64 and value:match('^[%a][%w_%-]*$')~=nil
end
-- Other addons can register an existing stable leading comment. Neither
-- names nor executable body text alone establish managed-macro ownership.
function AM:RegisterManagedMacro(owner,key,header)
    if not identifier(owner) or not identifier(key) or type(header)~='string'
        or #header>255 or not header:match('^#') or header:find('[\r\n]') then
        return nil,'Use owner/key identifiers and one exact # comment.'
    end
    local previous=registered[header]
    if previous and (previous.owner~=owner or previous.key~=key) then
        return nil,'That managed macro header is already registered.'
    end
    registered[header]={owner=owner,key=key}
    return true
end
AM:RegisterManagedMacro('SmartTravel','dynamic','# DO NOT EDIT - SmartTravel')
AM:RegisterManagedMacro('SmartTravel','dynamic','# DO NOT EDIT - Managed by SmartTravel')
function AM:ManagedMacroIdentity(body)
    if type(body)~='string' then return end
    local function identify(header)
        local known=registered[header]
        if known then return known.owner,known.key end
        -- Explicit opt-in marker supports multiple macros per addon. The common
        -- dynamic ownership header supports one logical macro per name and scope.
        local owner,key=header:match('^# SetupSwap%-ManagedMacro: ([%a][%w_%-]*)/([%a][%w_%-]*)$')
        if not owner then
            owner=header:match('^# DO NOT EDIT %- Dynamic macro managed by ([%a][%w_%-]*)$')
                or header:match('^# DO NOT EDIT %- Managed by ([%a][%w_%-]*)$')
            key='dynamic'
        end
        if identifier(owner) and identifier(key) then return owner,key end
    end
    local foundOwner,foundKey
    -- Blizzard/cache writers may put #showtooltip ahead of the ownership line.
    -- Recognize exact standalone markers in the leading comment preamble only.
    for line in (body..'\n'):gmatch('([^\n]*)\n') do
        line=line:gsub('\r$','')
        if line~='' and line:sub(1,1)~='#' then break end
        local owner,key=identify(line)
        if owner then
            if foundOwner and (foundOwner~=owner or foundKey~=key) then return end
            foundOwner,foundKey=owner,key
        end
    end
    return foundOwner,foundKey
end
function AM:SameMacro(a,b)
    if a.characterMacro~=b.characterMacro then return false end
    local ownerA,keyA=self:ManagedMacroIdentity(a.body)
    local ownerB,keyB=self:ManagedMacroIdentity(b.body)
    if ownerA or ownerB then return a.name==b.name and ownerA==ownerB and keyA==keyB end
    if a.macroToken and b.macroToken then return a.macroToken==b.macroToken end
    -- Legacy snapshots lack native tracking information. Retain exact matching
    -- until they can be adopted safely or recaptured once.
    return a.name==b.name and a.body==b.body
end
