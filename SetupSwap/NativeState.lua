local AM=SetupSwap
local defaultMask='Textures\\MinimapMask'
-- Rendering state can survive ReloadUI even though addon Lua objects are recreated.
-- Apply the target baseline early, before the selected addons initialize their skins.
function AM:CaptureNativeState()
    return {minimapMask=self.minimapMask or defaultMask}
end
function AM:PrepareNativeState(profile)
    local native=profile and profile.captureSettings and profile.settings and profile.settings.native
    if native and type(native.minimapMask)=='string' then
        self.db.pendingMinimapMask=native.minimapMask
    elseif IsAddOnLoaded('ElvUI') and not (profile and profile.addons.ElvUI) then
        self.db.pendingMinimapMask=defaultMask
    end
end
if Minimap and Minimap.SetMaskTexture and hooksecurefunc then
    hooksecurefunc(Minimap,'SetMaskTexture',function(_,texture)
        if type(texture)=='string' then AM.minimapMask=texture end
    end)
end
local startup=CreateFrame('Frame')
startup:RegisterEvent('ADDON_LOADED')
startup:SetScript('OnEvent',function(self,event,addon)
    if addon~=AM.name then return end
    local db=SetupSwapAccountDB
    if db and db.pendingMinimapMask and Minimap and Minimap.SetMaskTexture then
        Minimap:SetMaskTexture(db.pendingMinimapMask)
        AM.minimapMask=db.pendingMinimapMask
        db.pendingMinimapMask=nil
    end
    if self.UnregisterEvent then self:UnregisterEvent('ADDON_LOADED') end
end)
