-- FeelsGoodUI: Companion lifecycle and apply coordinator

local _, ns = ...

local Runtime = {}
ns.CompanionRuntime = Runtime

local Log = ns.Log
local Safety = ns.Safety
local Shared = ns.CompanionShared
local PetBar = ns.CompanionPetBar
local MicroBags = ns.CompanionMicroBags

local function HasCompanionLayers()
    return Shared and PetBar and MicroBags
end

local function IsReady(module)
    return type(module) == "table"
end

local function IsDetached(module)
    return module and module._detached == true
end

local function GetActiveModule(module)
    return ns.Companion or module
end

local function CancelPendingWork()
    if not (Safety and Safety.CancelDebounce) then
        return
    end

    Safety.CancelDebounce(Shared.APPLY_DEBOUNCE_KEY)
    Safety.CancelDebounce(Shared.MICRO_LAYOUT_RETRY_KEY)
end

local function FinalizeDetach(module)
    if not IsReady(module) then
        return false
    end

    if MicroBags and MicroBags.RestoreDefaultLayout and not Shared:IsInCombat() then
        MicroBags:RestoreDefaultLayout(module)
    end

    if PetBar and PetBar.RestoreDefaultLayout and not Shared:IsInCombat() then
        PetBar:RestoreDefaultLayout(module)
    elseif module._petAnchor and type(module._petAnchor.Hide) == "function" then
        module._petAnchor:Hide()
    end

    if module._combatWatcher then
        module._combatWatcher:UnregisterAllEvents()
        module._combatWatcher:SetScript("OnEvent", nil)
    end

    module._pendingAfterCombat = nil
    module._pendingDetachRestore = nil
    module._applyingMicroLayout = nil
    module._eventsAttached = false
    return true
end

local function EnsureExpandChangedCallback(module)
    if (not module._callbackHandles) and EventUtil and type(EventUtil.CreateCallbackHandleContainer) == "function" then
        module._callbackHandles = EventUtil.CreateCallbackHandleContainer()
    end

    if module._expandCallbackRegistered
        or not module._callbackHandles
        or not EventRegistry
        or type(module._callbackHandles.RegisterCallback) ~= "function" then
        return
    end

    module._expandCallbackRegistered = true
    module._callbackHandles:RegisterCallback(EventRegistry, "MainMenuBarManager.OnExpandChanged", function()
        MicroBags:HandleExpandChanged(GetActiveModule(module))
    end, module)
end

local function GetCombatWatcher(module)
    local watcher = module._combatWatcher
    if watcher then
        return watcher
    end

    watcher = CreateFrame("Frame")
    module._combatWatcher = watcher
    return watcher
end

local function HandleWatcherEvent(module, event, arg1)
    if IsDetached(module) then
        if event == "PLAYER_REGEN_ENABLED" and module._pendingDetachRestore then
            FinalizeDetach(module)
        end
        return
    end

    if event == "UNIT_PET" and arg1 ~= "player" then
        return
    end

    if event == "BAG_UPDATE_DELAYED" and MicroBags:HandleBagUpdate(module) then
        return
    end

    if module._pendingAfterCombat then
        module._pendingAfterCombat = nil
        Runtime.ApplyConfig(module)
        return
    end

    Runtime.RequestApply(module)
end

function Runtime.ApplyCompanionConfig(module, profile)
    if not IsReady(module) then return false, "Companion apply owner unavailable" end
    if IsDetached(module) then return false, "Companion is detached" end
    if not HasCompanionLayers() then return false, "Companion internal layers unavailable" end

    local currentProfile = profile
    local cp = Shared:GetCompanionCfg(currentProfile)

    local hooksReady, hookDetail = MicroBags:EnsureHooks(module)
    if hooksReady ~= true then
        return false, hookDetail or "Companion hooks unavailable"
    end

    local petApplied, petDetail = PetBar:Apply(module, cp, currentProfile)
    if petApplied ~= true then
        if type(PetBar.RestoreDefaultLayout) == "function" and not Shared:IsInCombat() then
            PetBar:RestoreDefaultLayout(module)
        end
        return false, petDetail or "Companion pet-bar apply failed"
    end

    local microApplied, microDetail = MicroBags:Apply(module, cp, currentProfile)
    if microApplied ~= true then
        if not Shared:IsInCombat() then
            if type(MicroBags.RestoreDefaultLayout) == "function" then
                MicroBags:RestoreDefaultLayout(module)
            end
            if type(PetBar.RestoreDefaultLayout) == "function" then
                PetBar:RestoreDefaultLayout(module)
            end
        end
        return false, microDetail or "Companion micro/bag apply failed"
    end

    MicroBags:UpdateCompactBagCountText(module, currentProfile)
    return true, microDetail
end

function Runtime.ApplyConfig(module, profile)
    if not IsReady(module) then return false, "Companion apply owner unavailable" end
    if IsDetached(module) then return false, "Companion is detached" end
    return Runtime.ApplyCompanionConfig(module, profile)
end

function Runtime.RequestApply(module)
    if not IsReady(module) or IsDetached(module) then
        return false
    end

    if Shared:IsInCombat() then
        module._pendingAfterCombat = true
        return false
    end

    if Safety and Safety.Debounce and Safety.Debounce(Shared.APPLY_DEBOUNCE_KEY, 0.03, function()
        local applied, detail = Runtime.ApplyConfig(GetActiveModule(module))
        if applied == false and Log and type(Log.Error) == "function" then
            Log:Error("Companion apply failed: " .. tostring(detail or "unknown error"))
        end
    end) then
        return true
    end

    return Runtime.ApplyConfig(module)
end

function Runtime.Init(module)
    if not IsReady(module) then
        return false
    end

    if not _G.oUF then
        Log:Warn("oUF not detected; companion bars disabled.")
        return false
    end

    if not HasCompanionLayers() then
        Log:Error("Companion internal layers missing; companion bars disabled.")
        return false
    end

    if module._initDone then
        return true
    end

    local hooksReady, detail = MicroBags:EnsureHooks(module)
    if hooksReady ~= true then
        return false, detail or "Companion hooks unavailable"
    end

    module._initDone = true
    return true
end

function Runtime.Attach(module)
    if Runtime.Init(module) == false then
        return false
    end

    module._detached = nil
    module._pendingDetachRestore = nil

    if module._eventsAttached then
        return true
    end

    local watcher = GetCombatWatcher(module)
    EnsureExpandChangedCallback(module)

    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("UNIT_PET")
    watcher:RegisterEvent("PET_BAR_UPDATE")
    watcher:RegisterEvent("BAG_UPDATE_DELAYED")
    watcher:SetScript("OnEvent", function(_, event, arg1)
        HandleWatcherEvent(module, event, arg1)
    end)

    module._eventsAttached = true
    return true
end

function Runtime.Detach(module)
    if not IsReady(module) then
        return false
    end

    module._detached = true
    module._pendingAfterCombat = nil
    module._applyingMicroLayout = nil

    CancelPendingWork()

    if module._callbackHandles and type(module._callbackHandles.Unregister) == "function" then
        module._callbackHandles:Unregister()
    end
    module._expandCallbackRegistered = nil

    local watcher = GetCombatWatcher(module)
    watcher:UnregisterAllEvents()

    if Shared:IsInCombat() then
        module._pendingDetachRestore = true
        watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
        watcher:SetScript("OnEvent", function(_, event, arg1)
            HandleWatcherEvent(module, event, arg1)
        end)
        module._eventsAttached = false
        return false
    end

    return FinalizeDetach(module)
end

return Runtime
