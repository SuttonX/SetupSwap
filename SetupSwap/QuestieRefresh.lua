local AM=SetupSwap
-- Questie 335 drops Update calls inside its 0.1s throttle. Its combat/task
-- queues can deliver the final acceptance update just under that boundary.
-- Preserve that request on the trailing edge; never poll or refresh on a timer
-- unless a native Update was actually throttled.
local state={serial=0,scheduled=0,replayed=0,canceled=0}
AM.questieDeferredRefresh=state
local function modules()
    local loader=_G.QuestieLoader
    return type(loader)=='table' and loader._modules
end
local function eligible(tracker)
    local questie=_G.Questie
    local profile=type(questie)=='table' and questie.db and questie.db.profile
    return tracker.started and profile and profile.trackerEnabled and not tracker.disableHooks
end
local function attach()
    if state.attached or not hooksecurefunc then return end
    local loaded=modules()
    local tracker=loaded and loaded.QuestieTracker
    local pool=loaded and loaded.TrackerLinePool
    local timer=_G.QuestieCompat and _G.QuestieCompat.C_Timer
    if not tracker or type(tracker.Update)~='function' or not pool or type(pool.ResetLinesForChange)~='function'
        or not timer or type(timer.After)~='function' then return end
    hooksecurefunc(pool,'ResetLinesForChange',function()
        state.serial=state.serial+1
        state.lastRender=GetTime()
        if state.pending then state.canceled=state.canceled+1;state.pending=nil end
    end)
    hooksecurefunc(tracker,'Update',function()
        local rendered=state.serial~=state.observedSerial
        state.observedSerial=state.serial
        if rendered or state.pending or not state.lastRender or not eligible(tracker) or InCombatLockdown() then return end
        local elapsed=GetTime()-state.lastRender
        if elapsed<0 or elapsed>=0.1 then return end
        local request={serial=state.serial}
        state.pending=request;state.scheduled=state.scheduled+1
        local function replay()
            if state.pending~=request then return end
            state.pending=nil
            if state.serial~=request.serial or not eligible(tracker) or InCombatLockdown() then return end
            state.replayed=state.replayed+1
            tracker:Update()
        end
        timer.After(0.1-elapsed+0.01,function()
            if state.pending~=request then return end
            if InCombatLockdown() then
                local queue=loaded.QuestieCombatQueue
                if queue and type(queue.Queue)=='function' then queue:Queue(replay)
                else state.pending=nil end
            else replay() end
        end)
    end)
    state.observedSerial=state.serial
    state.attached=true
end
local events=CreateFrame('Frame')
events:RegisterEvent('ADDON_LOADED');events:RegisterEvent('PLAYER_LOGIN')
events:SetScript('OnEvent',function(self)
    attach()
    if state.attached then self:UnregisterEvent('ADDON_LOADED');self:UnregisterEvent('PLAYER_LOGIN') end
end)
