from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


path = Path('modules/ExperienceBar.lua')
text = path.read_text(encoding='utf-8')
start = text.index('local function EnsureEventFrame(module)')
end = text.index('return XP', start)
replacement = r'''local EXPERIENCE_EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "PLAYER_XP_UPDATE",
    "PLAYER_MAX_LEVEL_UPDATE",
    "PLAYER_LEVEL_CHANGED",
    "PLAYER_LEVEL_UP",
    "UPDATE_EXHAUSTION",
    "UPDATE_FACTION",
    "HONOR_XP_UPDATE",
    "ENABLE_XP_GAIN",
    "DISABLE_XP_GAIN",
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

local function ReportExperienceEventFailure(module, event, detail)
    local message = tostring(event or "event") .. ": " .. tostring(detail or "unknown failure")
    if module._eventLastError == message then return end
    module._eventLastError = message
    if Log and type(Log.Error) == "function" then
        Log:Error("ExperienceBar event refresh failed: " .. message)
    end
end

local function ClearExperienceEventFailure(module)
    module._eventLastError = nil
end

local function RunExperienceUpdate(module)
    if type(module.Update) ~= "function" then
        return false, "ExperienceBar update owner unavailable"
    end

    local ok, result, detail = pcall(module.Update, module)
    if not ok then
        return false, "ExperienceBar update failed: " .. tostring(result)
    end
    if result == false then
        return false, tostring(detail or "ExperienceBar update failed")
    end
    return true
end

local function EnsureEventFrame(module)
    local existing = module._eventRecord
    if type(existing) == "table" and existing.frame then
        module._events = existing.frame
        return existing.frame, existing
    end

    local created, ev = pcall(CreateFrame, "Frame")
    if not created or not ev then
        return nil, nil, "ExperienceBar event-frame creation failed: " .. tostring(ev)
    end

    local record = {
        frame = ev,
        active = false,
        registered = false,
        cleanupPending = false,
    }

    local callback = function(_, event, ...)
        if module._eventRecord ~= record or record.active ~= true then
            return
        end

        local unit = ...
        if (event == "PLAYER_XP_UPDATE"
            or event == "HONOR_XP_UPDATE"
            or event == "PLAYER_MAX_LEVEL_UPDATE")
            and unit and unit ~= "player" then
            return
        end

        if module._suppressBlizzardTracking == true then
            local maintained, maintainDetail = MaintainStatusTrackingOwnership(module)
            if maintained == false then
                ReportStatusTrackingFailure(module, maintainDetail)
            else
                ClearStatusTrackingFailure(module)
            end
        end

        local updated, updateDetail = RunExperienceUpdate(module)
        if updated == false then
            ReportExperienceEventFailure(module, event, updateDetail)
        else
            ClearExperienceEventFailure(module)
        end
    end

    local scripted, scriptDetail = EventFrameCall(ev, "SetScript", "OnEvent", callback)
    if scripted == false then
        return nil, nil, "ExperienceBar event callback setup failed: " .. tostring(scriptDetail)
    end

    record.callback = callback
    module._eventRecord = record
    module._events = ev
    return ev, record
end

local function CleanupEventSubscriptions(record)
    if type(record) ~= "table" then return true end

    record.active = false
    if record.registered ~= true and record.cleanupPending ~= true then
        return true
    end

    local cleaned, detail = EventFrameCall(record.frame, "UnregisterAllEvents")
    if cleaned == false then
        record.cleanupPending = true
        return false, detail
    end

    record.registered = false
    record.cleanupPending = false
    return true
end

local function PrepareEventSubscriptions(module, record)
    if type(record) ~= "table" or module._eventRecord ~= record then
        return false, "ExperienceBar event record unavailable"
    end

    if record.active == true and record.registered == true and record.cleanupPending ~= true then
        return true, nil, false
    end

    if record.registered == true or record.cleanupPending == true then
        local cleaned, cleanupDetail = CleanupEventSubscriptions(record)
        if cleaned == false then
            return false, "previous event cleanup failed: " .. tostring(cleanupDetail)
        end
    end

    record.active = false
    for i = 1, #EXPERIENCE_EVENTS do
        local event = EXPERIENCE_EVENTS[i]
        local registered, detail = EventFrameCall(record.frame, "RegisterEvent", event)
        if registered == false then
            -- A native registration may have partially succeeded before raising
            -- or returning false. Treat the frame as dirty until a complete
            -- UnregisterAllEvents succeeds.
            record.registered = true
            record.cleanupPending = true
            local cleaned, cleanupDetail = CleanupEventSubscriptions(record)
            local failure = tostring(event) .. ": " .. tostring(detail)
            if cleaned == false then
                failure = failure .. "; cleanup: " .. tostring(cleanupDetail)
            end
            return false, failure
        end
    end

    record.registered = true
    record.cleanupPending = false
    return true, nil, true
end

local function ActivateEventSubscriptions(module, record)
    if type(record) ~= "table"
        or module._eventRecord ~= record
        or record.registered ~= true
        or record.cleanupPending == true then
        return false, "ExperienceBar event subscriptions are not ready"
    end
    record.active = true
    return true
end

local function ReleaseEventSubscriptions(module)
    local record = module and module._eventRecord or nil
    if type(record) ~= "table" then return true end
    record.active = false
    return CleanupEventSubscriptions(record)
end

local function JoinFailures(failures)
    if #failures == 0 then return nil end
    return table.concat(failures, "; ")
end

function XP:ApplyConfig()
    local initialized, initDetail = self:Init()
    if initialized == false then return false, initDetail end

    local cfg = GetCfg()
    local bar = self._bar
    local ev = self._events
    local record = self._eventRecord
    if not (bar and ev and record) then
        return false, "ExperienceBar runtime owners unavailable"
    end

    if not cfg.enabled then
        local failures = {}
        local released, releaseDetail = ReleaseEventSubscriptions(self)
        if released == false then
            failures[#failures + 1] = "events: " .. tostring(releaseDetail)
        end

        self._suppressBlizzardTracking = nil
        local restored, restoreDetail = RestoreBlizzardStatusTracking(self)
        if restored == false then
            failures[#failures + 1] = "native restore: " .. tostring(restoreDetail)
        end

        SetBarVisible(bar, false, true)
        local detail = JoinFailures(failures)
        if detail then return false, detail end
        ClearStatusTrackingFailure(self)
        ClearExperienceEventFailure(self)
        return true
    end

    local wasActive = record.active == true
        and record.registered == true
        and record.cleanupPending ~= true

    local prepared, prepareDetail = PrepareEventSubscriptions(self, record)
    if prepared == false then
        return false, "ExperienceBar event subscription failed: " .. tostring(prepareDetail)
    end

    self._suppressBlizzardTracking = true
    local maintained, maintainDetail = MaintainStatusTrackingOwnership(self)
    local updated, updateDetail = true, nil
    if maintained then
        updated, updateDetail = RunExperienceUpdate(self)
    end

    if maintained and updated then
        local activated, activateDetail = ActivateEventSubscriptions(self, record)
        if activated == false then
            maintained = false
            maintainDetail = activateDetail
        else
            ClearStatusTrackingFailure(self)
            ClearExperienceEventFailure(self)
            return true
        end
    end

    local failures = {}
    if maintained == false then
        failures[#failures + 1] = "native ownership: " .. tostring(maintainDetail)
    end
    if updated == false then
        failures[#failures + 1] = "update: " .. tostring(updateDetail)
    end

    if not wasActive then
        record.active = false
        local released, releaseDetail = CleanupEventSubscriptions(record)
        if released == false then
            failures[#failures + 1] = "event rollback: " .. tostring(releaseDetail)
        end

        self._suppressBlizzardTracking = nil
        local restored, restoreDetail = RestoreBlizzardStatusTracking(self)
        if restored == false then
            failures[#failures + 1] = "native rollback: " .. tostring(restoreDetail)
        end
        SetBarVisible(bar, false, true)
    else
        -- A reapply failure must not tear down the previously committed event
        -- owner. The settings/apply journal can restore the prior geometry while
        -- this exact event generation remains active.
        record.active = true
    end

    return false, JoinFailures(failures) or "ExperienceBar apply failed"
end

function XP:Attach()
    if self._attached then return true end

    local initialized, detail = self:Init()
    if initialized == false then return false, detail end
    self._attached = true
    return true
end

function XP:Detach()
    self._attached = false

    local failures = {}
    local released, releaseDetail = ReleaseEventSubscriptions(self)
    if released == false then
        failures[#failures + 1] = "events: " .. tostring(releaseDetail)
    end

    self._suppressBlizzardTracking = nil
    local restored, restoreDetail = RestoreBlizzardStatusTracking(self)
    if restored == false then
        failures[#failures + 1] = "native restore: " .. tostring(restoreDetail)
    end

    if self._bar then
        SetBarVisible(self._bar, false, true)
    end

    local detail = JoinFailures(failures)
    if detail then return false, detail end
    ClearStatusTrackingFailure(self)
    ClearExperienceEventFailure(self)
    return true
end

function XP:Init()
    if self._inited then return true end

    local bar, frameDetail = EnsureFrame(self)
    if not bar then return false, frameDetail end

    local events, _, eventDetail = EnsureEventFrame(self)
    if not events then return false, eventDetail or "ExperienceBar event owner unavailable" end

    self._inited = true
    if Log and Log.Debug then
        Log:Debug("ExperienceBar loaded")
    end
    return true
end

'''
text = text[:start] + replacement + text[end:]
path.write_text(text, encoding='utf-8')


# ---------------------------------------------------------------------------
# Static contracts, docs, release metadata.
# ---------------------------------------------------------------------------
check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
contracts = r'''    assertSourceIncludes('modules/ExperienceBar.lua', 'local EXPERIENCE_EVENTS = {');
    assertSourceIncludes('modules/ExperienceBar.lua', 'module._eventRecord ~= record or record.active ~= true');
    assertSourceIncludes('modules/ExperienceBar.lua', 'previous event cleanup failed');
    assertSourceIncludes('modules/ExperienceBar.lua', 'event rollback: ');
    assertSourceIncludes('modules/ExperienceBar.lua', 'record.active = false');
    assertSourceIncludes('modules/ExperienceBar.lua', 'ExperienceBar event callback setup failed');
    assertSourceExcludes('modules/ExperienceBar.lua', /ev:RegisterEvent\(/, 'unchecked ExperienceBar event registration');
    assertSourceExcludes('modules/ExperienceBar.lua', /self\._events:UnregisterAllEvents\(/, 'unchecked ExperienceBar event unregister');

'''
check = replace_once(
    check,
    "    assertSourceIncludes('modules/ExperienceBar.lua', 'function XP:ApplyConfig()');\n",
    "    assertSourceIncludes('modules/ExperienceBar.lua', 'function XP:ApplyConfig()');\n" + contracts,
    'ExperienceBar event lifecycle static contracts',
)
check_path.write_text(check, encoding='utf-8')


toc_path = Path('FeelsGoodUI.toc')
toc = toc_path.read_text(encoding='utf-8')
toc = replace_once(toc, '## Version: 0.0.70', '## Version: 0.0.71', 'TOC version')
toc_path.write_text(toc, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(readme, '- FeelsGoodUI `0.0.70`', '- FeelsGoodUI `0.0.71`', 'README version')
readme = replace_once(
    readme,
    'ExperienceBar suppresses native status tracking through a verified per-frame/per-property alpha/mouse journal: unreadable properties are never mutated, every write is read back, hook/suppression/restore failures propagate to Apply/Lifecycle, unresolved restore records remain retryable, and newer conflicting external values are preserved.',
    'ExperienceBar uses a result-bearing event generation plus a verified per-frame/per-property native status journal. Event-frame creation, callback setup, registration, partial-registration cleanup, disable and detach are checked explicitly; callbacks require the exact active record, failed generations remain inert and retryable, first-enable failure rolls back both events and native ownership, and reapply failure preserves the previously committed generation. Unreadable native properties are never mutated, every write is read back, hook/suppression/restore failures propagate to Apply/Lifecycle, unresolved restore records remain retryable, and newer conflicting external values are preserved.',
    'README ExperienceBar event lifecycle',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    '- ExperienceBar owns one lifecycle apply path and a verified property journal for Blizzard status-tracking frames: alpha/mouse channels are captured only when readable, writes are read back, partial restore records survive for retry, manager replacement reopens hook ownership, and exact failures propagate to Apply/Lifecycle.',
    '- ExperienceBar owns one lifecycle apply path, an exact active event-generation record, and a verified property journal for Blizzard status-tracking frames. Event creation/setup/register/unregister edges are result-bearing; partial generations stay inert until complete apply, cleanup remains retryable, first-enable failure rolls back events and native ownership, and reapply failure preserves the prior committed generation. Alpha/mouse channels are captured only when readable, writes are read back, partial restore records survive for retry, manager replacement reopens hook ownership, and exact failures propagate to Apply/Lifecycle.',
    'AGENT_GUIDE ExperienceBar event lifecycle',
)
agent_path.write_text(agent, encoding='utf-8')

index_path = Path('CODE_INDEX.md')
index = index_path.read_text(encoding='utf-8')
index = replace_once(
    index,
    '| `modules/ExperienceBar.lua` | XP/reputation/honor presentation, single lifecycle apply owner, and a verified, retryable per-property Blizzard status-tracking journal. |',
    '| `modules/ExperienceBar.lua` | XP/reputation/honor presentation, result-bearing event-generation lifecycle, single apply owner, and a verified, retryable per-property Blizzard status-tracking journal. |',
    'CODE_INDEX ExperienceBar event lifecycle',
)
index_path.write_text(index, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(todo, '- [x] Target Interface `120105` and release `0.0.70`.', '- [x] Target Interface `120105` and release `0.0.71`.', 'TODO version')
todo = replace_once(
    todo,
    '- [x] Make ExperienceBar native takeover a verified property journal: refuse unreadable channels, read back every write, retain unresolved restore state for retry, reopen hooks on manager replacement, preserve newer conflicts, and propagate exact hook/suppress/restore failures.',
    '- [x] Make ExperienceBar event/native lifecycle result-bearing: publish callbacks only for the exact active complete generation, clean partial registration before retry, keep failed generations inert, aggregate disable/detach cleanup, roll back first-enable native ownership, preserve the prior committed generation on reapply failure, and retain the verified native property journal.',
    'TODO ExperienceBar event lifecycle status',
)
todo = replace_once(
    todo,
    '- [ ] Give Blizzard status-tracking manager/containers distinctive alpha, mouse and visibility states; inject unreadable alpha/mouse, stubborn setters, hook failure, manager replacement and restore failure; ExperienceBar must never mutate unreadable channels, must report exact failures, retain retryable unresolved records, avoid duplicate hooks/writes, restore exact still-owned values, and preserve newer conflicts without foreign `Hide`/`Show`.',
    '- [ ] Give Blizzard status-tracking manager/containers distinctive alpha, mouse and visibility states; inject event-frame creation/SetScript/RegisterEvent/UnregisterAllEvents failure plus unreadable alpha/mouse, stubborn setters, hook failure, manager replacement and restore failure; ExperienceBar must publish no partial event generation, keep stale callbacks inert, retry cleanup exactly, never mutate unreadable channels, retain unresolved native records, avoid duplicates, restore exact still-owned values, and preserve newer conflicts without foreign `Hide`/`Show`.',
    'TODO ExperienceBar event validation',
)
todo_path.write_text(todo, encoding='utf-8')

matrix_path = Path('docs/REGRESSION_MATRIX_1_25.md')
matrix = matrix_path.read_text(encoding='utf-8')
matrix = replace_once(
    matrix,
    '| 23 | Experience/reputation/honor states; unreadable/stubborn native status properties; manager replacement; hook/restore failure | Correct mode/text/rested state; only readable alpha/mouse channels are mutated and verified; failures reach Apply/Lifecycle; unresolved restore retries; hooks do not duplicate; exact still-owned values restore; newer conflicts survive |  |  |',
    '| 23 | Experience/reputation/honor states with event-frame creation/SetScript/RegisterEvent/UnregisterAllEvents failure, unreadable/stubborn native status properties, manager replacement, hook/update/restore failure | Only a complete exact event generation dispatches; partial/stale callbacks stay inert and cleanup retries; first-enable failure rolls back events/native ownership while reapply preserves the prior generation; correct mode/text/rested state remains; only readable alpha/mouse channels mutate and verify; exact failures reach Apply/Lifecycle; unresolved restore retries; hooks stay single; exact still-owned values restore and newer conflicts survive |  |  |',
    'regression matrix ExperienceBar event lifecycle',
)
matrix_path.write_text(matrix, encoding='utf-8')

print('Hardened ExperienceBar event generation and apply rollback lifecycle.')
