local AM=SetupSwap
local defaultMask='Textures\\MinimapMask'
local squareMask='Interface\\ChatFrame\\ChatFrameBackground'
local function elvuiMask()
    local engine=IsAddOnLoaded('ElvUI') and type(ElvUI)=='table' and ElvUI[1]
    local general=engine and engine.private and engine.private.general
    if general and type(general.minimap)=='table' then
        return general.minimap.enable and squareMask or defaultMask
    end
end
function AM:RestoreNativeState(native)
    -- The target ElvUI private settings have now been restored. A previously
    -- captured circular fallback must not override its enabled square skin.
    local mask=elvuiMask() or (native and native.minimapMask)
    if type(mask)=='string' and Minimap and Minimap.SetMaskTexture then
        Minimap:SetMaskTexture(mask);self.minimapMask=mask
    end
end
-- Rendering state can survive ReloadUI even though addon Lua objects are recreated.
-- Apply the target baseline early, before the selected addons initialize their skins.
function AM:CaptureNativeState()
    return {minimapMask=self.minimapMask or (SetupSwapEarlyLoader and SetupSwapEarlyLoader.minimapMask) or elvuiMask() or defaultMask}
end
function AM:PrepareNativeState(profile)
    local native=profile and profile.captureSettings and profile.settings and profile.settings.native
    if native and type(native.minimapMask)=='string' then
        self.db.pendingMinimapMask=native.minimapMask
    elseif IsAddOnLoaded('ElvUI') and not (profile and self:EffectiveState(profile,{name="ElvUI"})) then
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
        AM:RestoreNativeState({minimapMask=db.pendingMinimapMask})
        db.pendingMinimapMask=nil
    end
    if self.UnregisterEvent then self:UnregisterEvent('ADDON_LOADED') end
end)
