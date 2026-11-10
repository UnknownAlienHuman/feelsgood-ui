-- FeelsGoodUI: CenterBars owner/runtime and config apply helpers

local _, ns = ...

local Runtime = {}
ns.CenterBarsRuntime = Runtime

local Log = ns.Log
local Media = ns.Media
local Movers = ns.Movers
local Safety = ns.Safety

local EMPTY = {}

Runtime._ctx = Runtime._ctx or EMPTY
Runtime._nextEventRecordID = Runtime._nextEventRecordID or 0

function Runtime:Configure(context)
    if type(context) == "table" then
        self._ctx = context
    else
        self._ctx = EMPTY
    end
end

local function Ctx()
    return Runtime._ctx or EMPTY
end

local function Call(name, ...)
    local fn = Ctx()[name]
    if type(fn) == "function" then
        return fn(...)
    end
    return nil
end

local function CallResult(name, ...)
    local fn = Ctx()[name]
    if type(fn) ~= "function" then
        return false, "CenterBars " .. tostring(name) .. " helper unavailable"
    end

    local ok, result, detail = pcall(fn, ...)
    if not ok then
        return false, "CenterBars " .. tostring(name) .. " failed: " .. tostring(result)
    end
    if result == false then
        return false, tostring(detail or ("CenterBars " .. tostring(name) .. " failed"))
    end
    return true, detail
end

local function GetCenterCfg()
    local value = Call("GetCenterCfg")
    if type(value) == "table" then
        return value
    end
    return {}
end

local function GetCenterTextCfg()
    local value = Call("GetCenterTextCfg")
    if type(value) == "table" then
        return value
    end
    return {}
end

local function GetSharedFontToken()
    return Call("GetSharedFontToken") or "Fonts\\FRIZQT__.TTF"
end

local function GetSharedFontOutline()
    return Call("GetSharedFontOutline") or "OUTLINE"
end

local function GetSharedFontSize()
    local value = tonumber(Call("GetSharedFontSize"))
    if type(value) == "number" then
        return value
    end
    return 12
end

local function GetSharedStatusbarToken()
    return Call("GetSharedStatusbarToken") or "Interface/Buttons/WHITE8x8"
end

local function RefreshResourceOwner(owner)
    local refreshed, refreshDetail = CallResult("RefreshResourceMode", owner)
    if refreshed == false then
        return false, refreshDetail
    end

    local updated, updateDetail = CallResult("UpdatePower", owner)
    if updated == false then
        return false, updateDetail
    end
    return true
end

local function ReportEventRefreshFailure(owner, event, detail)
    detail = tostring(detail or "unknown CenterBars event refresh failure")
    local key = tostring(event) .. ": " .. detail
    if owner._eventRefreshLastError == key then return end
    owner._eventRefreshLastError = key
    if Log and type(Log.Error) == "function" then
        Log:Error("CenterBars " .. tostring(event) .. " refresh failed: " .. detail)
    end
end

local function RefreshResourceOwnerForEvent(owner, event)
    local ok, detail = RefreshResourceOwner(owner)
    if ok == false then
        ReportEventRefreshFailure(owner, event, detail)
        return false
    end
    owner._eventRefreshLastError = nil
    return true
end

local CENTER_EVENT_HANDLERS = {
    PLAYER_ENTERING_WORLD = function(owner)
        RefreshResourceOwnerForEvent(owner, "PLAYER_ENTERING_WORLD")
    end,
    PLAYER_SPECIALIZATION_CHANGED = function(owner, unit)
        if unit ~= "player" then return end
        RefreshResourceOwnerForEvent(owner, "PLAYER_SPECIALIZATION_CHANGED")
    end,
    PLAYER_TALENT_UPDATE = function(owner)
        RefreshResourceOwnerForEvent(owner, "PLAYER_TALENT_UPDATE")
    end,
    UNIT_DISPLAYPOWER = function(owner, unit)
        if unit ~= "player" then return end
        local ok, detail = CallResult("UpdatePower", owner)
        if ok == false then ReportEventRefreshFailure(owner, "UNIT_DISPLAYPOWER", detail) end
    end,
    UNIT_POWER_UPDATE = function(owner, unit, powerType)
        Call("OnUnitPower", owner, unit, powerType)
    end,
    UNIT_POWER_FREQUENT = function(owner, unit, powerType)
        Call("OnUnitPower", owner, unit, powerType)
    end,
    UNIT_MAXPOWER = function(owner, unit, powerType)
        Call("OnUnitPower", owner, unit, powerType)
    end,
    RUNE_POWER_UPDATE = function(owner)
        Call("OnRuneEvent", owner)
    end,
    RUNE_TYPE_UPDATE = function(owner)
        Call("OnRuneEvent", owner)
    end,
}

local CENTER_EVENT_REGISTRATIONS = {
    { event = "PLAYER_ENTERING_WORLD" },
    { event = "PLAYER_SPECIALIZATION_CHANGED" },
    { event = "PLAYER_TALENT_UPDATE" },
    { event = "UNIT_DISPLAYPOWER", unit = "player" },
    { event = "UNIT_POWER_UPDATE", unit = "player" },
    { event = "UNIT_POWER_FREQUENT", unit = "player" },
    { event = "UNIT_MAXPOWER", unit = "player" },
    { event = "RUNE_POWER_UPDATE" },
    { event = "RUNE_TYPE_UPDATE" },
}

local function EventFrameCall(frame, method, ...)
    local fn = frame and frame[method] or nil
    if type(fn) ~= "function" then
        return false, tostring(method) .. " is unavailable"
    end

    local ok, result = pcall(fn, frame, ...)
    if not ok then
        return false, tostring(method) .. " failed: " .. tostring(result)
    end
    if result == false then
        return false, tostring(method) .. " rejected the request"
    end
    return true
end

local function GetRetiredEventRecords(owner)
    local records = owner._retiredEventRecords
    if type(records) ~= "table" then
        records = {}
        owner._retiredEventRecords = records
    end
    return records
end

local function AddRetiredEventRecord(owner, record)
    if type(record) ~= "table" then return end
    local records = GetRetiredEventRecords(owner)
    for i = 1, #records do
        if records[i] == record then return end
    end
    records[#records + 1] = record
end

local function CleanupEventRecord(record)
    if type(record) ~= "table" then return true end
    record.active = false

    local failures = {}
    local scriptOK, scriptDetail = EventFrameCall(record.frame, "SetScript", "OnEvent", nil)
    if not scriptOK then failures[#failures + 1] = tostring(scriptDetail) end

    local eventsOK, eventsDetail = EventFrameCall(record.frame, "UnregisterAllEvents")
    if not eventsOK then failures[#failures + 1] = tostring(eventsDetail) end

    if #failures > 0 then
        record.cleanupPending = true
        return false, table.concat(failures, "; ")
    end

    record.registered = false
    record.cleanupPending = false
    return true
end

local function RetryRetiredEventRecords(owner)
    local records = owner._retiredEventRecords
    if type(records) ~= "table" or #records == 0 then return true end

    local failures = {}
    for i = #records, 1, -1 do
        local record = records[i]
        local ok, detail = CleanupEventRecord(record)
        if ok then
            table.remove(records, i)
        else
            failures[#failures + 1] = tostring(detail)
        end
    end
    if #records == 0 then owner._retiredEventRecords = nil end
    if #failures > 0 then return false, table.concat(failures, "; ") end
    return true
end

local function RegisterEventEdge(frame, registration)
    if registration.unit ~= nil and type(frame.RegisterUnitEvent) == "function" then
        local ok, detail = EventFrameCall(
            frame,
            "RegisterUnitEvent",
            registration.event,
            registration.unit
        )
        if ok == false then
            return false, registration.event .. " (" .. tostring(registration.unit) .. "): " .. tostring(detail)
        end
        return true
    end

    local ok, detail = EventFrameCall(frame, "RegisterEvent", registration.event)
    if ok == false then
        return false, registration.event .. ": " .. tostring(detail)
    end
    return true
end

local function PrepareEventRecord(owner)
    local created, frame = pcall(CreateFrame, "Frame")
    if not created or not frame then
        return nil, "CenterBars event-frame creation failed: " .. tostring(frame)
    end

    Runtime._nextEventRecordID = Runtime._nextEventRecordID + 1
    local record = {
        id = Runtime._nextEventRecordID,
        frame = frame,
        active = false,
        registered = false,
        cleanupPending = false,
    }

    record.callback = function(_, event, ...)
        if owner._eventRecord ~= record or record.active ~= true then
            return
        end

        local handler = CENTER_EVENT_HANDLERS[event]
        if not handler then return end
        if Safety and type(Safety.Dispatch) == "function" then
            Safety.Dispatch(owner, event, handler, ...)
        else
            local ok, detail = pcall(handler, owner, ...)
            if not ok then
                ReportEventRefreshFailure(owner, event, detail)
            end
        end
    end

    local scripted, scriptDetail = EventFrameCall(
        frame,
        "SetScript",
        "OnEvent",
        record.callback
    )
    if not scripted then
        record.cleanupPending = true
        local failure = "CenterBars event callback setup failed: " .. tostring(scriptDetail)
        local cleaned, cleanupDetail = CleanupEventRecord(record)
        if not cleaned then
            AddRetiredEventRecord(owner, record)
            failure = failure .. "; cleanup: " .. tostring(cleanupDetail)
        end
        return nil, failure
    end

    for i = 1, #CENTER_EVENT_REGISTRATIONS do
        local registered, detail = RegisterEventEdge(frame, CENTER_EVENT_REGISTRATIONS[i])
        if registered == false then
            record.registered = true
            record.cleanupPending = true
            local failure = "CenterBars event registration failed: " .. tostring(detail)
            local cleaned, cleanupDetail = CleanupEventRecord(record)
            if not cleaned then
                AddRetiredEventRecord(owner, record)
                failure = failure .. "; cleanup: " .. tostring(cleanupDetail)
            end
            return nil, failure
        end
    end

    record.registered = true
    return record
end

local function PublishEventRecord(owner, record)
    owner._eventRecord = record
    owner._eventFrame = record and record.frame or nil
    owner._eventsAttached = record ~= nil and true or false
    if record then record.active = true end
end

local function ReleaseCurrentEventRecord(owner)
    local record = owner._eventRecord
    owner._eventRecord = nil
    owner._eventFrame = nil
    owner._eventsAttached = false
    if not record then return true end

    record.active = false
    local cleaned, detail = CleanupEventRecord(record)
    if not cleaned then
        AddRetiredEventRecord(owner, record)
        return false, detail
    end
    return true
end

local function EnsureEvents(owner)
    local current = owner._eventRecord
    if owner._eventsAttached == true
        and type(current) == "table"
        and current.active == true
        and current.registered == true
        and current.cleanupPending ~= true then
        return true
    end

    ReleaseCurrentEventRecord(owner)
    local retiredOK, retiredDetail = RetryRetiredEventRecords(owner)
    if retiredOK == false then
        return false, "CenterBars previous event cleanup failed: " .. tostring(retiredDetail)
    end

    local record, detail = PrepareEventRecord(owner)
    if not record then
        return false, detail
    end

    PublishEventRecord(owner, record)
    return true
end

local function DetachEvents(owner)
    ReleaseCurrentEventRecord(owner)
    local retiredOK, retiredDetail = RetryRetiredEventRecords(owner)
    if retiredOK == false then
        return false, "CenterBars event cleanup failed: " .. tostring(retiredDetail)
    end
    return true
end

function Runtime:Attach(owner)
    local center = GetCenterCfg()
    if center.enabled == false then
        local detached, detail = DetachEvents(owner)
        if detached == false then return false, detail end
        return true
    end

    if not owner._inited then
        local initialized, detail = owner:Init()
        if initialized == false then
            return false, detail
        end
    end
    if not owner._inited then
        return false, "CenterBars initialization incomplete"
    end

    return EnsureEvents(owner)
end

function Runtime:Detach(owner)
    Call("StopRuneTicker", owner)
    local restored, restoreDetail = CallResult("RestoreDefaultClassResources", owner)
    local eventsDetached, eventDetail = DetachEvents(owner)

    if owner.frame then
        owner.frame:Hide()
    end

    local failures = {}
    if restored == false then
        failures[#failures + 1] = "CenterBars native restore failed: " .. tostring(restoreDetail)
    end
    if eventsDetached == false then
        failures[#failures + 1] = "events: " .. tostring(eventDetail)
    end
    if #failures > 0 then
        return false, table.concat(failures, "; ")
    end
    return true
end

function Runtime:Init(owner)
    if owner._inited then
        return true
    end

    local createCenterMoverSpec = Ctx().CreateCenterMoverSpec
    local createPowerBar = Ctx().CreatePowerBar
    local ensureSegmentPool = Ctx().EnsureSegmentPool
    if type(createCenterMoverSpec) ~= "function"
        or type(createPowerBar) ~= "function"
        or type(ensureSegmentPool) ~= "function" then
        Log:Warn("CenterBars runtime helpers missing; init aborted.")
        return false, "CenterBars runtime helpers missing"
    end

    local center = GetCenterCfg()
    if center.enabled == false then
        Log:Info("CenterBars disabled (DB).")
        return true
    end
    Call("RefreshThresholdConfig", owner)

    local w = tonumber(center.width) or 560
    local h1 = tonumber(center.resourceHeight) or 12
    local h2 = tonumber(center.powerHeight) or 14
    local gap = tonumber(center.spacing) or 6

    local f = owner.frame
    if not f then
        f = CreateFrame("Frame", "FGUI_Center", UIParent)
        owner.frame = f
    end
    f:SetSize(w, h1 + gap + h2)

    local resource = owner.resourceBar
    if not resource then
        resource = CreateFrame("Frame", nil, f)
        owner.resourceBar = resource
    end
    resource:ClearAllPoints()
    resource:SetPoint("TOP", f, "TOP", 0, 0)
    resource:SetSize(w, h1)

    owner.resourceSegments = owner.resourceSegments or {}

    local maxSeg = tonumber(center.maxSegments) or 10
    if maxSeg < 6 then maxSeg = 6 end
    ensureSegmentPool(owner, maxSeg, h1)

    local power = owner.powerBar
    if not power then
        power = createPowerBar(f, w, h2)
        if not power then
            f:Hide()
            Log:Warn("CenterBars power bar helper returned nil; init aborted.")
            return false, "CenterBars power bar helper returned nil"
        end
        owner.powerBar = power
    end
    power:ClearAllPoints()
    power:SetPoint("TOP", resource, "BOTTOM", 0, -gap)

    if not (Movers and type(Movers.Register) == "function" and type(Movers.Apply) == "function") then
        f:Hide()
        return false, "CenterBars mover registry unavailable"
    end
    local registered, registerDetail = Movers:Register("center", f, createCenterMoverSpec("Center"))
    if registered == false then
        f:Hide()
        return false, "CenterBars mover registration failed: " .. tostring(registerDetail)
    end
    local applied, applyDetail = Movers:Apply("center", f)
    if applied == false then
        f:Hide()
        return false, "CenterBars mover apply failed: " .. tostring(applyDetail)
    end

    local refreshed, refreshDetail = RefreshResourceOwner(owner)
    if refreshed == false then
        Call("StopRuneTicker", owner)
        local restored, restoreDetail = CallResult("RestoreDefaultClassResources", owner)
        f:Hide()
        if restored == false then
            refreshDetail = tostring(refreshDetail)
                .. "; rollback restore failed: " .. tostring(restoreDetail)
        end
        return false, "CenterBars initialization failed: " .. tostring(refreshDetail)
    end

    owner._inited = true
    Log:Info("CenterBars initialized.")
    return true
end

function Runtime:ApplyConfig(owner)
    local center = GetCenterCfg()
    local text = GetCenterTextCfg()

    if center.enabled == false then
        Call("StopRuneTicker", owner)
        local restored, restoreDetail = CallResult("RestoreDefaultClassResources", owner)
        local eventsDetached, eventDetail = DetachEvents(owner)
        if owner.frame then
            owner.frame:Hide()
        end

        local failures = {}
        if restored == false then
            failures[#failures + 1] = "CenterBars native restore failed: " .. tostring(restoreDetail)
        end
        if eventsDetached == false then
            failures[#failures + 1] = "events: " .. tostring(eventDetail)
        end
        if #failures > 0 then
            return false, table.concat(failures, "; ")
        end
        return true
    end

    Call("RefreshThresholdConfig", owner)

    if not owner._inited then
        local initialized, detail = owner:Init()
        if initialized == false then
            return false, detail
        end
    end
    if not owner.frame then
        return false, "CenterBars frame unavailable"
    end

    local attached, attachDetail = EnsureEvents(owner)
    if attached == false then
        return false, attachDetail
    end

    local w = tonumber(center.width) or 560
    local h1 = tonumber(center.resourceHeight) or 12
    local h2 = tonumber(center.powerHeight) or 14
    local gap = tonumber(center.spacing) or 6
    local maxSeg = tonumber(owner._maxSegmentsCap) or tonumber(center.maxSegments) or 10
    if maxSeg < 6 then maxSeg = 6 end
    Call("EnsureSegmentPool", owner, maxSeg, h1)

    local scale = tonumber(center.scale) or 1.0
    owner.frame:SetScale(scale)

    local sb = Media:FetchStatusbar(GetSharedStatusbarToken())
    if owner.powerBar then owner.powerBar:SetStatusBarTexture(sb) end
    if owner.resourceSegments then
        for _, seg in ipairs(owner.resourceSegments) do
            if seg then seg:SetStatusBarTexture(sb) end
        end
    end

    local font = text.font or GetSharedFontToken()
    local size = tonumber(text.size) or GetSharedFontSize()
    local outline = text.outline or GetSharedFontOutline()
    if owner.powerBar and owner.powerBar.text then
        Media:ApplyFont(owner.powerBar.text, font, size, outline)
    end

    owner.frame:SetSize(w, h1 + gap + h2)
    if owner.resourceBar then
        owner.resourceBar:SetSize(w, h1)
    end
    if owner.powerBar then
        owner.powerBar:SetSize(w, h2)
        owner.powerBar:ClearAllPoints()
        if owner.resourceBar then
            owner.powerBar:SetPoint("TOP", owner.resourceBar, "BOTTOM", 0, -gap)
        else
            owner.powerBar:SetPoint("TOP", owner.frame, "TOP", 0, 0)
        end
    end

    owner.frame:Show()
    local refreshed, refreshDetail = RefreshResourceOwner(owner)
    if refreshed == false then
        return false, "CenterBars resource refresh failed: " .. tostring(refreshDetail)
    end
    return true
end

return Runtime
