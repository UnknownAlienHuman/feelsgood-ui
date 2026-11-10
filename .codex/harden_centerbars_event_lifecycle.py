from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


path = Path('modules/CenterBarsRuntime.lua')
text = path.read_text(encoding='utf-8')
text = replace_once(
    text,
    '''Runtime._ctx = Runtime._ctx or EMPTY
''',
    '''Runtime._ctx = Runtime._ctx or EMPTY
Runtime._nextEventRecordID = Runtime._nextEventRecordID or 0
''',
    'CenterBars event record counter',
)

start = text.index('local function EnsureEvents(owner)')
end = text.index('function Runtime:Attach(owner)', start)
replacement = r'''local CENTER_EVENT_REGISTRATIONS = {
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

'''
text = text[:start] + replacement + text[end:]

text = replace_once(
    text,
    '''    if center.enabled == false then
        DetachEvents(owner)
        return true
    end
''',
    '''    if center.enabled == false then
        local detached, detail = DetachEvents(owner)
        if detached == false then return false, detail end
        return true
    end
''',
    'CenterBars disabled attach cleanup result',
)

text = replace_once(
    text,
    '''function Runtime:Detach(owner)
    Call("StopRuneTicker", owner)
    local restored, restoreDetail = CallResult("RestoreDefaultClassResources", owner)

    if owner.frame then
        owner.frame:Hide()
    end

    DetachEvents(owner)
    if restored == false then
        return false, "CenterBars native restore failed: " .. tostring(restoreDetail)
    end
    return true
end
''',
    '''function Runtime:Detach(owner)
    Call("StopRuneTicker", owner)
    local restored, restoreDetail = CallResult("RestoreDefaultClassResources", owner)
    local eventsDetached, eventDetail = DetachEvents(owner)

    if owner.frame then
        owner.frame:Hide()
    end

    local failures = {}
    if restored == false then
        failures[#failures + 1] = "native restore: " .. tostring(restoreDetail)
    end
    if eventsDetached == false then
        failures[#failures + 1] = "events: " .. tostring(eventDetail)
    end
    if #failures > 0 then
        return false, table.concat(failures, "; ")
    end
    return true
end
''',
    'CenterBars detach event cleanup result',
)

text = replace_once(
    text,
    '''    if center.enabled == false then
        Call("StopRuneTicker", owner)
        local restored, restoreDetail = CallResult("RestoreDefaultClassResources", owner)
        DetachEvents(owner)
        if owner.frame then
            owner.frame:Hide()
        end
        if restored == false then
            return false, "CenterBars native restore failed: " .. tostring(restoreDetail)
        end
        return true
    end
''',
    '''    if center.enabled == false then
        Call("StopRuneTicker", owner)
        local restored, restoreDetail = CallResult("RestoreDefaultClassResources", owner)
        local eventsDetached, eventDetail = DetachEvents(owner)
        if owner.frame then
            owner.frame:Hide()
        end

        local failures = {}
        if restored == false then
            failures[#failures + 1] = "native restore: " .. tostring(restoreDetail)
        end
        if eventsDetached == false then
            failures[#failures + 1] = "events: " .. tostring(eventDetail)
        end
        if #failures > 0 then
            return false, table.concat(failures, "; ")
        end
        return true
    end
''',
    'CenterBars disabled apply event cleanup result',
)

path.write_text(text, encoding='utf-8')
print('Hardened CenterBars event generation and teardown ownership.')
