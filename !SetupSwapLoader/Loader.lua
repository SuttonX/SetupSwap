-- No SavedVariables here: the existing SetupSwap account database stays in its
-- original file. Register before addon login handlers, then use the fully loaded
-- SetupSwap implementation at PLAYER_LOGIN. Never restore on an ordinary login.
SetupSwapEarlyLoader = {alreadyLoaded={},saveBindings=SaveBindings}
local loader=SetupSwapEarlyLoader
for i=1,GetNumAddOns() do
    local name=GetAddOnInfo(i)
    if name and IsAddOnLoaded(name) then loader.alreadyLoaded[name]=true end
end
local frame=CreateFrame('Frame')
frame:RegisterEvent('PLAYER_LOGIN')
frame:SetScript('OnEvent',function(self)
    self:UnregisterEvent('PLAYER_LOGIN')
    loader.loginStarted=true
    if SetupSwap and SetupSwap.TryEarlySettingsRestore then
        SetupSwap:TryEarlySettingsRestore(loader)
    end
end)
