-- FeelsGoodUI: Companion lifecycle and apply coordinator

local _, ns = ...

local Runtime = {}
ns.CompanionRuntime = Runtime

local Log = ns.Log
local Safety = ns.Safety
local Shared = ns.CompanionShared
local PetBar = ns.CompanionPetBar
local MicroBags = ns.CompanionMicroBags

Runtime._nextExpandRecordID = Runtime._nextExpandRecordID or 0
Runtime._nextWatcherRecordID = Runtime._nextWatcherRecordID or 0

local NORMAL_WATCHER_EVENTS = {
    "PLAYER_REGEN_ENABLED",
    "PLAYER_ENTERING_WORLD",
    "UNIT_PET",
    "PET_BAR_UPDATE",
    "BAG_UPDATE_DELAYED",
}

local DETACH_WATCHER_EVENTS = {
    "PLAYER_REGEN_ENABLED",
    "PLAYER_ENTERING_WORLD",
}

local HandleWatcherEvent
local FinalizeDetach

local function HasCompanionLayers()
    return Shared and PetBar and MicroBags
end

local function IsReady(module)
    return type(module) == "table"
end

local function IsDetached(module)
    return module and module._detached == true
end

local function IsUnavailable(module)
    return not IsReady(module)
        or module._detached == true
        or module._detaching == true
end

local function GetActiveModule(module)
    return ns.Companion or module
end

local function ErrorText(detail)
    return tostring(detail or "unknown Companion runtime failure")
end

local function JoinFailures(failures)
    if #failures == 0 then return nil end
    return table.concat(failures, "; ")
end

local function AppendFailure(failures, label, detail)
    failures[#failures + 1] = tostring(label) .. ": " .. ErrorText(detail)
end

local function LogRuntimeFailure(module, field, prefix, detail)
    local message = tostring(prefix) .. ": " .. ErrorText(detail)
    if module[field] == message then return end
    module[field] = message
    if Log and type(Log.Error) == "function" then
        Log:Error(message)
    end
end

local function ClearRuntimeFailure(module, field)
    module[field] = nil
end

local function ProtectedCall(target, method, ...)
    local fn = target and target[method] or nil
    if type(fn) ~= "function" then
        return false, nil, tostring(method) .. " is unavailable"
    end

    local ok, result, detail = pcall(fn, target, ...)
    if not ok then
        return false, nil, tostring(method) .. " failed: " .. tostring(result)
    end
    return true, result, detail
end

local function CallRequired(target, method, ...)
    local ok, result, detail = ProtectedCall(target, method, ...)
    if not ok then return false, detail end
    if result == false then
        return false, detail or (tostring(method) .. " returned false")
    end
    return true, detail
end

local function CancelPendingWork()
    if not (Safety and type(Safety.CancelDebounce) == "function") then
        return true
    end

    local failures = {}
    local keys = {
        Shared.APPLY_DEBOUNCE_KEY,
        Shared.MICRO_LAYOUT_RETRY_KEY,
    }
    for i = 1, #keys do
        local ok, detail = pcall(Safety.CancelDebounce, keys[i])
        if not ok then
            AppendFailure(failures, "cancel " .. tostring(keys[i]), detail)
        end
    end

    local detail = JoinFailures(failures)
    if detail then return false, detail end
    return true
end

local function GetRetiredRecords(module, field)
    local records = module[field]
    if type(records) ~= "table" then
        records = {}
        module[field] = records
    end
    return records
end

local function AddRetiredRecord(module, field, record)
    if type(record) ~= "table" then return end
    local records = GetRetiredRecords(module, field)
    for i = 1, #records do
        if records[i] == record then return end
    end
    records[#records + 1] = record
end

local function CleanupExpandRecord(record)
    if type(record) ~= "table" then return true end
    record.active = false

    local handles = record.handles
    if not handles then
        record.cleanupPending = false
        return true
    end
    if type(handles.Unregister) ~= "function" then
        record.cleanupPending = true
        return false, "callback container lacks Unregister"
    end

    local ok, result = pcall(handles.Unregister, handles)
    if not ok then
        record.cleanupPending = true
        return false, "callback unregister failed: " .. tostring(result)
    end
    if result == false then
        record.cleanupPending = true
        return false, "callback unregister returned false"
    end

    record.handles = nil
    record.cleanupPending = false
    return true
end

local function RetryRetiredExpandRecords(module)
    local records = module._retiredExpandRecords
    if type(records) ~= "table" or #records == 0 then return true end

    local failures = {}
    for i = #records, 1, -1 do
        local record = records[i]
        local ok, detail = CleanupExpandRecord(record)
        if ok then
            table.remove(records, i)
        else
            failures[#failures + 1] = ErrorText(detail)
        end
    end
    if #records == 0 then module._retiredExpandRecords = nil end

    local detail = JoinFailures(failures)
    if detail then return false, detail end
    return true
end

local function PrepareExpandRecord(module)
    local registry = _G.EventRegistry or EventRegistry
    if not registry then
        return nil, "EventRegistry is unavailable"
    end
    if not (EventUtil and type(EventUtil.CreateCallbackHandleContainer) == "function") then
        return nil, "callback handle container API is unavailable"
    end

    local created, handles = pcall(EventUtil.CreateCallbackHandleContainer)
    if not created or not handles then
        return nil, "callback container creation failed: " .. tostring(handles)
    end
    if type(handles.RegisterCallback) ~= "function" then
        return nil, "callback container lacks RegisterCallback"
    end

    Runtime._nextExpandRecordID = Runtime._nextExpandRecordID + 1
    local record = {
        id = Runtime._nextExpandRecordID,
        handles = handles,
        active = false,
        cleanupPending = false,
    }

    record.callback = function()
        if module._expandCallbackRecord ~= record
            or record.active ~= true
            or IsUnavailable(module) then
            return
        end

        local activeModule = GetActiveModule(module)
        if activeModule ~= module then return end

        local ok, _, detail = ProtectedCall(
            MicroBags,
            "HandleExpandChanged",
            activeModule
        )
        if not ok then
            LogRuntimeFailure(
                module,
                "_expandCallbackLastError",
                "Companion expand callback failed",
                detail
            )
        else
            ClearRuntimeFailure(module, "_expandCallbackLastError")
        end
    end

    local registered, result = pcall(
        handles.RegisterCallback,
        handles,
        registry,
        "MainMenuBarManager.OnExpandChanged",
        record.callback,
        module
    )
    if not registered or result == false then
        local failure = registered
            and "callback registration returned false"
            or ("callback registration failed: " .. tostring(result))
        local cleaned, cleanupDetail = CleanupExpandRecord(record)
        if not cleaned then
            AddRetiredRecord(module, "_retiredExpandRecords", record)
            failure = failure .. "; cleanup: " .. ErrorText(cleanupDetail)
        end
        return nil, failure
    end

    return record
end

local function PublishExpandRecord(module, record)
    module._expandCallbackRecord = record
    module._callbackHandles = record and record.handles or nil
    module._expandCallbackRegistered = record ~= nil and true or nil
    if record then record.active = true end
end

local function ReleaseCurrentExpandRecord(module)
    local record = module._expandCallbackRecord
    module._expandCallbackRecord = nil
    module._callbackHandles = nil
    module._expandCallbackRegistered = nil
    if not record then return true end

    record.active = false
    local cleaned, detail = CleanupExpandRecord(record)
    if not cleaned then
        AddRetiredRecord(module, "_retiredExpandRecords", record)
        return false, detail
    end
    return true
end

local function CleanupWatcherRecord(record)
    if type(record) ~= "table" then return true end
    record.active = false

    local frame = record.frame
    if not frame then
        record.cleanupPending = false
        return true
    end

    local failures = {}
    local scriptOK, _, scriptDetail = ProtectedCall(frame, "SetScript", "OnEvent", nil)
    if not scriptOK then AppendFailure(failures, "SetScript", scriptDetail) end

    local eventsOK, result, eventsDetail = ProtectedCall(frame, "UnregisterAllEvents")
    if not eventsOK then
        AppendFailure(failures, "UnregisterAllEvents", eventsDetail)
    elseif result == false then
        AppendFailure(failures, "UnregisterAllEvents", "returned false")
    end

    local detail = JoinFailures(failures)
    if detail then
        record.cleanupPending = true
        return false, detail
    end

    record.registered = false
    record.cleanupPending = false
    return true
end

local function RetryRetiredWatcherRecords(module)
    local records = module._retiredWatcherRecords
    if type(records) ~= "table" or #records == 0 then return true end

    local failures = {}
    for i = #records, 1, -1 do
        local record = records[i]
        local ok, detail = CleanupWatcherRecord(record)
        if ok then
            table.remove(records, i)
        else
            failures[#failures + 1] = ErrorText(detail)
        end
    end
    if #records == 0 then module._retiredWatcherRecords = nil end

    local detail = JoinFailures(failures)
    if detail then return false, detail end
    return true
end

local function PrepareWatcherRecord(module, events, mode)
    local created, frame = pcall(CreateFrame, "Frame")
    if not created or not frame then
        return nil, "watcher creation failed: " .. tostring(frame)
    end

    Runtime._nextWatcherRecordID = Runtime._nextWatcherRecordID + 1
    local record = {
        id = Runtime._nextWatcherRecordID,
        frame = frame,
        mode = mode,
        active = false,
        registered = false,
        cleanupPending = false,
    }

    record.callback = function(_, event, arg1)
        if module._watcherRecord ~= record or record.active ~= true then
            return
        end

        local ok, result, detail = pcall(HandleWatcherEvent, module, event, arg1)
        if not ok then
            LogRuntimeFailure(
                module,
                "_watcherLastError",
                "Companion watcher callback failed",
                result
            )
            return
        end
        if result == false then
            LogRuntimeFailure(
                module,
                "_watcherLastError",
                "Companion watcher callback failed",
                detail
            )
        else
            ClearRuntimeFailure(module, "_watcherLastError")
        end
    end

    local scripted, result, scriptDetail = ProtectedCall(
        frame,
        "SetScript",
        "OnEvent",
        record.callback
    )
    if not scripted or result == false then
        return nil, "watcher callback setup failed: " .. ErrorText(scriptDetail or result)
    end

    for i = 1, #events do
        local event = events[i]
        local registered, registerResult, registerDetail = ProtectedCall(
            frame,
            "RegisterEvent",
            event
        )
        if not registered or registerResult == false then
            record.registered = true
            record.cleanupPending = true
            local failure = tostring(event) .. ": " .. ErrorText(registerDetail or registerResult)
            local cleaned, cleanupDetail = CleanupWatcherRecord(record)
            if not cleaned then
                AddRetiredRecord(module, "_retiredWatcherRecords", record)
                failure = failure .. "; cleanup: " .. ErrorText(cleanupDetail)
            end
            return nil, failure
        end
    end

    record.registered = true
    return record
end

local function PublishWatcherRecord(module, record)
    module._watcherRecord = record
    module._combatWatcher = record and record.frame or nil
    if record then record.active = true end
end

local function ReleaseCurrentWatcherRecord(module)
    local record = module._watcherRecord
    module._watcherRecord = nil
    module._combatWatcher = nil
    module._eventsAttached = false
    if not record then return true end

    record.active = false
    local cleaned, detail = CleanupWatcherRecord(record)
    if not cleaned then
        AddRetiredRecord(module, "_retiredWatcherRecords", record)
        return false, detail
    end
    return true
end

local function RetryRetiredRegistrations(module)
    local failures = {}
    local callbacksOK, callbackDetail = RetryRetiredExpandRecords(module)
    if not callbacksOK then AppendFailure(failures, "callbacks", callbackDetail) end
    local watchersOK, watcherDetail = RetryRetiredWatcherRecords(module)
    if not watchersOK then AppendFailure(failures, "watchers", watcherDetail) end

    local detail = JoinFailures(failures)
    if detail then return false, detail end
    return true
end

local function RestoreCompanionLayouts(module)
    if Shared:IsInCombat() then
        return false, "Companion restore is blocked in combat"
    end

    local failures = {}
    local microOK, microDetail = CallRequired(
        MicroBags,
        "RestoreDefaultLayout",
        module
    )
    if not microOK then AppendFailure(failures, "micro/bags", microDetail) end

    if PetBar and type(PetBar.RestoreDefaultLayout) == "function" then
        local petOK, petDetail = CallRequired(
            PetBar,
            "RestoreDefaultLayout",
            module
        )
        if not petOK then AppendFailure(failures, "pet bar", petDetail) end
    elseif module._petAnchor and type(module._petAnchor.Hide) == "function" then
        local hidden, result = pcall(module._petAnchor.Hide, module._petAnchor)
        if not hidden or result == false then
            AppendFailure(failures, "pet anchor hide", result)
        end
    end

    local detail = JoinFailures(failures)
    if detail then return false, detail end
    return true
end

FinalizeDetach = function(module)
    if not IsReady(module) then
        return false, "Companion detach owner unavailable"
    end
    if Shared:IsInCombat() then
        module._pendingDetachRestore = true
        return false, "Companion detach restore remains deferred in combat"
    end

    local restored, restoreDetail = RestoreCompanionLayouts(module)
    if not restored then
        module._pendingDetachRestore = true
        return false, restoreDetail
    end

    local failures = {}
    local watcherOK, watcherDetail = ReleaseCurrentWatcherRecord(module)
    if not watcherOK then AppendFailure(failures, "detach watcher", watcherDetail) end
    local retiredOK, retiredDetail = RetryRetiredRegistrations(module)
    if not retiredOK then AppendFailure(failures, "retired registrations", retiredDetail) end

    module._pendingAfterCombat = nil
    module._pendingPetButtons = nil
    module._pendingDetachRestore = nil
    module._applyingMicroLayout = nil
    module._eventsAttached = false
    module._detaching = nil
    module._detached = true

    local detail = JoinFailures(failures)
    if detail then return false, detail end
    return true
end

HandleWatcherEvent = function(module, event, arg1)
    if IsDetached(module) or module._detaching == true then
        if module._pendingDetachRestore
            and (event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD")
            and not Shared:IsInCombat() then
            return FinalizeDetach(module)
        end
        return true
    end

    if event == "UNIT_PET" and arg1 ~= "player" then
        return true
    end

    if event == "BAG_UPDATE_DELAYED" then
        local ok, handled, detail = ProtectedCall(
            MicroBags,
            "HandleBagUpdate",
            module
        )
        if not ok then return false, detail end
        if handled == true then return true end
    end

    if module._pendingAfterCombat then
        if Shared:IsInCombat() then return true end
        module._pendingAfterCombat = nil
        local applied, detail = Runtime.ApplyConfig(module)
        if applied == false then
            return false, detail
        end
        return true
    end

    local requested, detail = Runtime.RequestApply(module)
    if requested == false then
        return false, detail
    end
    return true
end

function Runtime.ApplyCompanionConfig(module, profile)
    if not IsReady(module) then return false, "Companion apply owner unavailable" end
    if IsUnavailable(module) then return false, "Companion is detached or detaching" end
    if not HasCompanionLayers() then return false, "Companion internal layers unavailable" end

    local currentProfile = profile
    local cp = Shared:GetCompanionCfg(currentProfile)

    local hooksReady, hookDetail = CallRequired(MicroBags, "EnsureHooks", module)
    if hooksReady ~= true then
        return false, hookDetail or "Companion hooks unavailable"
    end

    local petApplied, petDetail = CallRequired(
        PetBar,
        "Apply",
        module,
        cp,
        currentProfile
    )
    if petApplied ~= true then
        local failures = { petDetail or "Companion pet-bar apply failed" }
        if not Shared:IsInCombat() then
            local restored, restoreDetail = CallRequired(
                PetBar,
                "RestoreDefaultLayout",
                module
            )
            if not restored then AppendFailure(failures, "pet cleanup", restoreDetail) end
        end
        return false, table.concat(failures, "; ")
    end

    local microApplied, microDetail = CallRequired(
        MicroBags,
        "Apply",
        module,
        cp,
        currentProfile
    )
    if microApplied ~= true then
        local failures = { microDetail or "Companion micro/bag apply failed" }
        if not Shared:IsInCombat() then
            local microRestored, microRestoreDetail = CallRequired(
                MicroBags,
                "RestoreDefaultLayout",
                module
            )
            if not microRestored then AppendFailure(failures, "micro cleanup", microRestoreDetail) end
            local petRestored, petRestoreDetail = CallRequired(
                PetBar,
                "RestoreDefaultLayout",
                module
            )
            if not petRestored then AppendFailure(failures, "pet cleanup", petRestoreDetail) end
        end
        return false, table.concat(failures, "; ")
    end

    local countUpdated, countDetail = CallRequired(
        MicroBags,
        "UpdateCompactBagCountText",
        module,
        currentProfile
    )
    if not countUpdated then
        return false, countDetail
    end
    return true, microDetail
end

function Runtime.ApplyConfig(module, profile)
    if not IsReady(module) then return false, "Companion apply owner unavailable" end
    if IsUnavailable(module) then return false, "Companion is detached or detaching" end
    return Runtime.ApplyCompanionConfig(module, profile)
end

function Runtime.RequestApply(module)
    if not IsReady(module) or IsUnavailable(module) then
        return false, "Companion request owner unavailable"
    end

    if Shared:IsInCombat() then
        module._pendingAfterCombat = true
        return true, "Companion apply deferred in combat"
    end

    local function Run()
        local activeModule = GetActiveModule(module)
        if activeModule ~= module or IsUnavailable(activeModule) then return end
        local applied, detail = Runtime.ApplyConfig(activeModule)
        if applied == false then
            LogRuntimeFailure(
                module,
                "_applyLastError",
                "Companion apply failed",
                detail
            )
        else
            ClearRuntimeFailure(module, "_applyLastError")
        end
    end

    if Safety and type(Safety.Debounce) == "function" then
        local ok, scheduled = pcall(
            Safety.Debounce,
            Shared.APPLY_DEBOUNCE_KEY,
            0.03,
            Run
        )
        if not ok then
            return false, "Companion apply debounce failed: " .. tostring(scheduled)
        end
        if scheduled then return true end
    end

    return Runtime.ApplyConfig(module)
end

function Runtime.Init(module)
    if not IsReady(module) then
        return false, "Companion init owner unavailable"
    end

    if not _G.oUF then
        if Log and type(Log.Warn) == "function" then
            Log:Warn("oUF not detected; companion bars disabled.")
        end
        return false, "oUF not detected"
    end

    if not HasCompanionLayers() then
        if Log and type(Log.Error) == "function" then
            Log:Error("Companion internal layers missing; companion bars disabled.")
        end
        return false, "Companion internal layers missing"
    end

    if module._initDone then
        return true
    end

    local hooksReady, detail = CallRequired(MicroBags, "EnsureHooks", module)
    if hooksReady ~= true then
        return false, detail or "Companion hooks unavailable"
    end

    module._initDone = true
    return true
end

function Runtime.Attach(module)
    local initialized, initDetail = Runtime.Init(module)
    if initialized == false then
        return false, initDetail
    end

    if module._pendingDetachRestore then
        if Shared:IsInCombat() then
            return false, "Companion detach restore is pending in combat"
        end
        local finalized, finalizeDetail = FinalizeDetach(module)
        if finalized == false then
            return false, "Companion pending detach finalization failed: " .. ErrorText(finalizeDetail)
        end
    end

    if module._eventsAttached == true
        and module._watcherRecord
        and module._watcherRecord.active == true
        and module._expandCallbackRecord
        and module._expandCallbackRecord.active == true
        and not IsDetached(module) then
        return true
    end

    module._detaching = true

    local failures = {}
    local expandReleased, expandReleaseDetail = ReleaseCurrentExpandRecord(module)
    if not expandReleased then AppendFailure(failures, "prior callback", expandReleaseDetail) end
    local watcherReleased, watcherReleaseDetail = ReleaseCurrentWatcherRecord(module)
    if not watcherReleased then AppendFailure(failures, "prior watcher", watcherReleaseDetail) end
    local retiredClean, retiredDetail = RetryRetiredRegistrations(module)
    if not retiredClean then AppendFailure(failures, "retired registrations", retiredDetail) end
    local cleanupDetail = JoinFailures(failures)
    if cleanupDetail then
        return false, "Companion attach cleanup failed: " .. cleanupDetail
    end

    local expandRecord, expandDetail = PrepareExpandRecord(module)
    if not expandRecord then
        return false, "Companion expand callback preparation failed: " .. ErrorText(expandDetail)
    end

    local watcherRecord, watcherDetail = PrepareWatcherRecord(
        module,
        NORMAL_WATCHER_EVENTS,
        "active"
    )
    if not watcherRecord then
        local cleaned, cleanupError = CleanupExpandRecord(expandRecord)
        if not cleaned then
            AddRetiredRecord(module, "_retiredExpandRecords", expandRecord)
            watcherDetail = ErrorText(watcherDetail)
                .. "; callback cleanup: " .. ErrorText(cleanupError)
        end
        return false, "Companion watcher preparation failed: " .. ErrorText(watcherDetail)
    end

    PublishExpandRecord(module, expandRecord)
    PublishWatcherRecord(module, watcherRecord)
    module._pendingDetachRestore = nil
    module._detached = nil
    module._detaching = nil
    module._eventsAttached = true
    return true
end

function Runtime.Detach(module)
    if not IsReady(module) then
        return false, "Companion detach owner unavailable"
    end

    if IsDetached(module) then
        if module._pendingDetachRestore and not Shared:IsInCombat() then
            return FinalizeDetach(module)
        end
        return true
    end

    module._detaching = true
    module._pendingAfterCombat = nil
    module._applyingMicroLayout = nil

    local failures = {}
    local cancelled, cancelDetail = CancelPendingWork()
    if not cancelled then AppendFailure(failures, "pending work", cancelDetail) end

    local expandReleased, expandDetail = ReleaseCurrentExpandRecord(module)
    if not expandReleased then AppendFailure(failures, "expand callback", expandDetail) end
    local watcherReleased, watcherDetail = ReleaseCurrentWatcherRecord(module)
    if not watcherReleased then AppendFailure(failures, "watcher", watcherDetail) end

    if Shared:IsInCombat() then
        local detachWatcher, detachWatcherDetail = PrepareWatcherRecord(
            module,
            DETACH_WATCHER_EVENTS,
            "detach"
        )
        if not detachWatcher then
            AppendFailure(failures, "detach watcher", detachWatcherDetail)
            return false, JoinFailures(failures)
        end

        PublishWatcherRecord(module, detachWatcher)
        module._pendingDetachRestore = true
        module._eventsAttached = false
        module._detached = true
        module._detaching = nil

        local detail = JoinFailures(failures)
        if detail then
            LogRuntimeFailure(
                module,
                "_detachLastError",
                "Companion deferred detach cleanup failed",
                detail
            )
            return false, detail
        end
        return false, "Companion restore deferred until combat ends"
    end

    local restored, restoreDetail = RestoreCompanionLayouts(module)
    if not restored then AppendFailure(failures, "layout restore", restoreDetail) end
    local retiredClean, retiredDetail = RetryRetiredRegistrations(module)
    if not retiredClean then AppendFailure(failures, "retired registrations", retiredDetail) end

    local detail = JoinFailures(failures)
    if detail then
        return false, detail
    end

    module._pendingPetButtons = nil
    module._pendingDetachRestore = nil
    module._eventsAttached = false
    module._detaching = nil
    module._detached = true
    ClearRuntimeFailure(module, "_detachLastError")
    return true
end

return Runtime
