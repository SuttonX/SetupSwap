-- No SavedVariables here: the existing SetupSwap account database stays in its
-- original file. Restore a queued switch once all required saved settings have
-- loaded, before PLAYER_LOGIN handlers initialize the target UI. Never restore
-- on an ordinary login.
SetupSwapEarlyLoader = {alreadyLoaded={}}
local loader=SetupSwapEarlyLoader
-- Observe mask changes before ElvUI initializes, rather than guessing the
-- current mask after the main SetupSwap addon loads later in the alphabet.
if Minimap and Minimap.SetMaskTexture and hooksecurefunc then
    hooksecurefunc(Minimap,'SetMaskTexture',function(_,texture)
        if type(texture)=='string' then loader.minimapMask=texture end
    end)
end
for i=1,GetNumAddOns() do
    local name=GetAddOnInfo(i)
    if name and IsAddOnLoaded(name) then loader.alreadyLoaded[name]=true end
end
local frame=CreateFrame('Frame')
frame:RegisterEvent('ADDON_LOADED')
frame:RegisterEvent('PLAYER_LOGIN')
frame:SetScript('OnEvent',function(self,event)
    if event=='PLAYER_LOGIN' then
        self:UnregisterEvent('PLAYER_LOGIN')
        self:UnregisterEvent('ADDON_LOADED')
        loader.loginStarted=true
        loader.beforeLogin=false
    elseif event=='ADDON_LOADED' then
        if loader.loginStarted then return end
        loader.beforeLogin=true
    else return end
    if not loader.restoreAttempted and SetupSwap and SetupSwap.TryEarlySettingsRestore then
        SetupSwap:TryEarlySettingsRestore(loader)
    end
end)
