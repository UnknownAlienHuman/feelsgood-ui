from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# UnitFramesTarget: prepare/commit observer ownership and retry cleanup.
# ---------------------------------------------------------------------------
target_path = Path('modules/UnitFramesTarget.lua')
target = target_path.read_text(encoding='utf-8')
target = replace_once(
    target,
    '''local function GetOwnerRecord(owner, create)
    local record = owner and OwnerRegistry[owner] or nil
    if not record and create == true and owner then
        record = {}
        OwnerRegistry[owner] = record
    end
    return record
end
''',
    '''local function GetOwnerRecord(owner, create)
    local record = owner and OwnerRegistry[owner] or nil
    if not record and create == true and owner then
        record = {}
        OwnerRegistry[owner] = record
    end
    if record and type(record.retiredFrames) ~= "table" then
        record.retiredFrames = setmetatable({}, { __mode = "k" })
    end
    return record
end
''',
    'UnitFrames owner retired registry',
)

hook_start = target.index('local function HookTargetHeaderSignal(frame, element)')
hook_end = target.index('local function HandleObservedEvent(frame, owner, event, unit)', hook_start)
hook_replacement = r'''local function HookTargetHeaderSignal(frame, element)
    if not (frame and element and type(element.HookScript) == "function") then
        return true
    end

    local hook = HeaderHookRegistry[element]
    if type(hook) ~= "table" then
        hook = {}
        HeaderHookRegistry[element] = hook
    end

    if type(hook.callback) ~= "function" then
        hook.callback = function(signal)
            local current = HeaderHookRegistry[signal]
            local currentFrame = current and current.frame or nil
            local record = currentFrame and FrameRegistry[currentFrame] or nil
            if not record or record.active ~= true then
                return
            end
            Target.LayoutTargetHeader(currentFrame)
            Target.ApplyTargetHeaderTextColor(currentFrame)
        end
    end

    if hook.showHooked ~= true then
        local ok, result = pcall(element.HookScript, element, "OnShow", hook.callback)
        if not ok or result == false then
            return false, "Target header OnShow hook failed: " .. tostring(result)
        end
        hook.showHooked = true
    end

    if hook.hideHooked ~= true then
        local ok, result = pcall(element.HookScript, element, "OnHide", hook.callback)
        if not ok or result == false then
            return false, "Target header OnHide hook failed: " .. tostring(result)
        end
        hook.hideHooked = true
    end

    -- Publish the target frame only after every mandatory permanent edge is
    -- installed. A partial hook remains inert and retryable.
    hook.frame = frame
    return true
end

local function HookTargetHeaderAnchorSignals(frame)
    if type(frame) ~= "table" or not frame.TargetHeader then
        return true
    end

    local ok, detail = HookTargetHeaderSignal(frame, frame.Buffs)
    if ok == false then return false, detail end
    return HookTargetHeaderSignal(frame, frame.Debuffs)
end

'''
target = target[:hook_start] + hook_replacement + target[hook_end:]

lifecycle_start = target.index('local function AttachFrameSignals(frame, owner)')
lifecycle_end = target.index('local function ApplyOwnerAuraMode(owner)', lifecycle_start)
lifecycle_replacement = r'''local OBSERVED_FIELDS = { "target", "focus", "targettarget" }

local function ObserverCall(observer, method, ...)
    local fn = observer and observer[method] or nil
    if type(fn) ~= "function" then
        return false, tostring(method) .. " is unavailable"
    end

    local ok, result = pcall(fn, observer, ...)
    if not ok then
        return false, tostring(method) .. " failed: " .. tostring(result)
    end
    if result == false then
        return false, tostring(method) .. " rejected the request"
    end
    return true
end

local function CleanupObserver(observer)
    if not observer then return true end

    local failures = {}
    local scriptOK, scriptDetail = ObserverCall(observer, "SetScript", "OnEvent", nil)
    if scriptOK == false then failures[#failures + 1] = scriptDetail end
    local eventsOK, eventsDetail = ObserverCall(observer, "UnregisterAllEvents")
    if eventsOK == false then failures[#failures + 1] = eventsDetail end

    if #failures > 0 then
        return false, table.concat(failures, "; ")
    end
    return true
end

local function AddRetiredObserver(record, observer)
    if not (record and observer) then return end
    record.retiredObservers = type(record.retiredObservers) == "table"
        and record.retiredObservers
        or {}
    for i = 1, #record.retiredObservers do
        if record.retiredObservers[i] == observer then return end
    end
    record.retiredObservers[#record.retiredObservers + 1] = observer
end

local function RetryRetiredObservers(record)
    local retired = record and record.retiredObservers
    if type(retired) ~= "table" or #retired == 0 then
        return true
    end

    local failures = {}
    for i = #retired, 1, -1 do
        local observer = retired[i]
        local ok, detail = CleanupObserver(observer)
        if ok then
            table.remove(retired, i)
        else
            failures[#failures + 1] = tostring(detail)
        end
    end
    if #retired == 0 then record.retiredObservers = nil end
    if #failures > 0 then
        return false, table.concat(failures, "; ")
    end
    return true
end

local function RegisterObserverEvent(observer, event, unit)
    if unit ~= nil and type(observer.RegisterUnitEvent) == "function" then
        local ok, detail = ObserverCall(observer, "RegisterUnitEvent", event, unit)
        if ok == false then
            return false, tostring(event) .. " (" .. tostring(unit) .. "): " .. tostring(detail)
        end
        return true
    end

    local ok, detail = ObserverCall(observer, "RegisterEvent", event)
    if ok == false then
        return false, tostring(event) .. ": " .. tostring(detail)
    end
    return true
end

local function BuildFrameObserver(frame, unit)
    local ok, observer = pcall(CreateFrame, "Frame", nil, frame)
    if not ok or not observer then
        return nil, "Target observer creation failed: " .. tostring(observer), nil
    end

    local scriptOK, scriptDetail = ObserverCall(observer, "SetScript", "OnEvent", function(_, event, ...)
        local current = FrameRegistry[frame]
        if not current
            or current.active ~= true
            or current.observer ~= observer then
            return
        end
        HandleObservedEvent(frame, current.owner, event, ...)
    end)
    if scriptOK == false then
        local cleaned, cleanupDetail = CleanupObserver(observer)
        local detail = "Target observer OnEvent setup failed: " .. tostring(scriptDetail)
        if cleaned == false then detail = detail .. "; cleanup: " .. tostring(cleanupDetail) end
        return nil, detail, cleaned and nil or observer
    end

    local registrations = {}
    if unit == "target" then
        registrations = {
            { "PLAYER_TARGET_CHANGED" },
            { "UNIT_NAME_UPDATE", unit },
            { "UNIT_LEVEL", unit },
            { "UNIT_CLASSIFICATION_CHANGED", unit },
            { "UNIT_FACTION", unit },
            { "UNIT_TARGET", unit },
        }
    elseif unit == "focus" then
        registrations = {
            { "PLAYER_FOCUS_CHANGED" },
            { "UNIT_FACTION", unit },
        }
    else
        registrations = {
            { "UNIT_FACTION", unit },
        }
    end

    for i = 1, #registrations do
        local registration = registrations[i]
        local registered, detail = RegisterObserverEvent(observer, registration[1], registration[2])
        if registered == false then
            local cleaned, cleanupDetail = CleanupObserver(observer)
            local failure = "Target observer registration failed: " .. tostring(detail)
            if cleaned == false then failure = failure .. "; cleanup: " .. tostring(cleanupDetail) end
            return nil, failure, cleaned and nil or observer
        end
    end

    return observer
end

local function AttachFrameSignals(frame, owner)
    if type(frame) ~= "table" then
        return true, nil, false, true
    end

    local unit = frame.unit
    if unit ~= "target" and unit ~= "focus" and unit ~= "targettarget" then
        return true, nil, false, true
    end

    local hooked, hookDetail = HookTargetHeaderAnchorSignals(frame)
    if hooked == false then
        return false, hookDetail, false, false
    end

    local record = GetFrameRecord(frame, true)
    local cleanupOK, cleanupDetail = RetryRetiredObservers(record)

    if record.active == true then
        if record.owner ~= owner or record.unit ~= unit or not record.observer then
            return false, "UnitFrames observer frame already has a different active owner", false, false
        end
        if cleanupOK == false then
            return false, cleanupDetail, false, true
        end
        return true, nil, false, true
    end

    local observer, detail, staleObserver = BuildFrameObserver(frame, unit)
    if staleObserver then AddRetiredObserver(record, staleObserver) end
    if not observer then
        return false, detail, false, false
    end

    local previousObserver = record.observer
    record.observer = observer
    record.owner = owner
    record.unit = unit
    record.active = true

    local failures = {}
    if cleanupOK == false then failures[#failures + 1] = tostring(cleanupDetail) end
    if previousObserver and previousObserver ~= observer then
        AddRetiredObserver(record, previousObserver)
        local retiredOK, retiredDetail = RetryRetiredObservers(record)
        if retiredOK == false then failures[#failures + 1] = tostring(retiredDetail) end
    end

    if #failures > 0 then
        return false, table.concat(failures, "; "), true, true
    end
    return true, nil, true, true
end

local function DetachFrameSignals(frame)
    local record = type(frame) == "table" and FrameRegistry[frame] or nil
    if not record then
        return true
    end

    record.active = false
    record.owner = nil
    record.unit = nil

    local observer = record.observer
    record.observer = nil
    if observer then AddRetiredObserver(record, observer) end

    local cleaned, detail = RetryRetiredObservers(record)
    if cleaned == false then
        return false, detail
    end
    return true
end

local function GetRetiredFrameSet(ownerRecord)
    ownerRecord.retiredFrames = type(ownerRecord.retiredFrames) == "table"
        and ownerRecord.retiredFrames
        or setmetatable({}, { __mode = "k" })
    return ownerRecord.retiredFrames
end

local function MarkRetiredFrame(ownerRecord, frame)
    if frame then GetRetiredFrameSet(ownerRecord)[frame] = true end
end

local function RetryOwnerRetiredFrames(ownerRecord)
    local retired = ownerRecord and ownerRecord.retiredFrames
    if type(retired) ~= "table" then return true end

    local failures = {}
    for frame in pairs(retired) do
        local ok, detail = DetachFrameSignals(frame)
        if ok then
            retired[frame] = nil
        else
            failures[#failures + 1] = tostring(detail)
        end
    end
    if #failures > 0 then
        return false, table.concat(failures, "; ")
    end
    return true
end

local function RollbackActivatedFrames(ownerRecord, activated)
    local failures = {}
    for i = #activated, 1, -1 do
        local frame = activated[i]
        local ok, detail = DetachFrameSignals(frame)
        if ok == false then
            MarkRetiredFrame(ownerRecord, frame)
            failures[#failures + 1] = tostring(detail)
        end
    end
    if #failures > 0 then
        return false, table.concat(failures, "; ")
    end
    return true
end

function Target.AttachOwner(owner)
    if type(owner) ~= "table" then
        return false, "UnitFrames target observer owner is unavailable"
    end

    local ownerRecord = GetOwnerRecord(owner, true)
    local failures = {}
    local retiredOK, retiredDetail = RetryOwnerRetiredFrames(ownerRecord)
    if retiredOK == false then failures[#failures + 1] = tostring(retiredDetail) end

    local previous = {}
    local desired = {}
    local activated = {}
    local activatedSet = {}

    for i = 1, #OBSERVED_FIELDS do
        local field = OBSERVED_FIELDS[i]
        previous[field] = ownerRecord[field]
        desired[field] = owner[field]

        local ok, detail, changed, ready = AttachFrameSignals(desired[field], owner)
        if changed and desired[field] and not activatedSet[desired[field]] then
            activatedSet[desired[field]] = true
            activated[#activated + 1] = desired[field]
        end
        if ready ~= true then
            local rollbackOK, rollbackDetail = RollbackActivatedFrames(ownerRecord, activated)
            local failure = tostring(field) .. ": " .. tostring(detail)
            if rollbackOK == false then
                failure = failure .. "; rollback cleanup: " .. tostring(rollbackDetail)
            end
            if #failures > 0 then
                failure = table.concat(failures, "; ") .. "; " .. failure
            end
            return false, failure
        end
        if ok == false then
            failures[#failures + 1] = tostring(field) .. ": " .. tostring(detail)
        end
    end

    -- Every desired frame is active before replacing ownerRecord fields.
    for i = 1, #OBSERVED_FIELDS do
        local field = OBSERVED_FIELDS[i]
        ownerRecord[field] = desired[field]
    end

    for i = 1, #OBSERVED_FIELDS do
        local field = OBSERVED_FIELDS[i]
        local oldFrame = previous[field]
        local newFrame = desired[field]
        if oldFrame and oldFrame ~= newFrame then
            local detached, detail = DetachFrameSignals(oldFrame)
            if detached == false then
                MarkRetiredFrame(ownerRecord, oldFrame)
                failures[#failures + 1] = tostring(field)
                    .. " previous observer cleanup: " .. tostring(detail)
            end
        end
    end

    if #failures > 0 then
        return false, table.concat(failures, "; ")
    end
    return true
end

function Target.DetachOwner(owner)
    if type(owner) ~= "table" then
        return true
    end

    local ownerRecord = GetOwnerRecord(owner, false) or GetOwnerRecord(owner, true)
    local frames = setmetatable({}, { __mode = "k" })
    local retired = GetRetiredFrameSet(ownerRecord)

    for i = 1, #OBSERVED_FIELDS do
        local field = OBSERVED_FIELDS[i]
        local recorded = ownerRecord[field]
        local current = owner[field]
        if recorded then frames[recorded] = true end
        if current then frames[current] = true end
        ownerRecord[field] = nil
    end
    for frame in pairs(retired) do frames[frame] = true end

    local failures = {}
    for frame in pairs(frames) do
        local detached, detail = DetachFrameSignals(frame)
        if detached then
            retired[frame] = nil
        else
            retired[frame] = true
            failures[#failures + 1] = tostring(detail)
        end
    end

    if #failures > 0 then
        return false, table.concat(failures, "; ")
    end

    OwnerRegistry[owner] = nil
    return true
end

'''
target = target[:lifecycle_start] + lifecycle_replacement + target[lifecycle_end:]
target_path.write_text(target, encoding='utf-8')


# ---------------------------------------------------------------------------
# UnitFramesRuntime: propagate observer detach/cleanup failures.
# ---------------------------------------------------------------------------
runtime_path = Path('modules/UnitFramesRuntime.lua')
runtime = runtime_path.read_text(encoding='utf-8')
runtime = replace_once(
    runtime,
    '''local function DetachObservers(owner)
    if Target and Target.DetachOwner then
        Target.DetachOwner(owner)
    end
    owner._eventsAttached = false
end
''',
    '''local function DetachObservers(owner)
    owner._eventsAttached = false
    if Target and Target.DetachOwner then
        return Target.DetachOwner(owner)
    end
    return true
end
''',
    'UnitFrames observer detach result',
)

runtime = replace_once(
    runtime,
    '''    if cfg.enabled == false then
        DetachObservers(owner)
        return true
    end
''',
    '''    if cfg.enabled == false then
        local detached, detail = DetachObservers(owner)
        if detached == false then return false, detail end
        return true
    end
''',
    'UnitFrames disabled attach cleanup',
)

runtime = replace_once(
    runtime,
    '''function Runtime:Detach(owner)
    DetachObservers(owner)

    local watchesDisabled, watchDetail = DisableOptionalUnitWatches(owner)

    if owner.player then
        owner.player:Hide()
    end
    if owner.target then
        owner.target:Hide()
    end
    if owner.player and owner.player.CombatTime then
        Call("StopCombatTimer", owner.player)
    end

    owner._configDirty = nil
    owner._auraModeDirty = nil
    if watchesDisabled == false then
        return false, watchDetail
    end
    return true
end
''',
    '''function Runtime:Detach(owner)
    local observersDetached, observerDetail = DetachObservers(owner)
    local watchesDisabled, watchDetail = DisableOptionalUnitWatches(owner)

    if owner.player then
        owner.player:Hide()
    end
    if owner.target then
        owner.target:Hide()
    end
    if owner.player and owner.player.CombatTime then
        Call("StopCombatTimer", owner.player)
    end

    owner._configDirty = nil
    owner._auraModeDirty = nil
    local failures = {}
    if observersDetached == false then
        failures[#failures + 1] = "observers: " .. tostring(observerDetail)
    end
    if watchesDisabled == false then
        failures[#failures + 1] = "unit watches: " .. tostring(watchDetail)
    end
    if #failures > 0 then
        return false, table.concat(failures, "; ")
    end
    return true
end
''',
    'UnitFrames detach cleanup aggregation',
)

runtime = replace_once(
    runtime,
    '''    if unitframesCfg.enabled == false then
        DetachObservers(owner)
        local watchesDisabled, watchDetail = DisableOptionalUnitWatches(owner)

        if owner.player then
            owner.player:Hide()
        end
        if owner.target then
            owner.target:Hide()
        end
        if owner.player and owner.player.CombatTime then
            Call("StopCombatTimer", owner.player)
        end
        if watchesDisabled == false then
            return false, watchDetail
        end
        return true
    end
''',
    '''    if unitframesCfg.enabled == false then
        local observersDetached, observerDetail = DetachObservers(owner)
        local watchesDisabled, watchDetail = DisableOptionalUnitWatches(owner)

        if owner.player then
            owner.player:Hide()
        end
        if owner.target then
            owner.target:Hide()
        end
        if owner.player and owner.player.CombatTime then
            Call("StopCombatTimer", owner.player)
        end

        local failures = {}
        if observersDetached == false then
            failures[#failures + 1] = "observers: " .. tostring(observerDetail)
        end
        if watchesDisabled == false then
            failures[#failures + 1] = "unit watches: " .. tostring(watchDetail)
        end
        if #failures > 0 then
            return false, table.concat(failures, "; ")
        end
        return true
    end
''',
    'UnitFrames disabled apply cleanup aggregation',
)
runtime_path.write_text(runtime, encoding='utf-8')


# ---------------------------------------------------------------------------
# Static contracts, docs, release metadata.
# ---------------------------------------------------------------------------
check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
contracts = r'''    assertSourceIncludes('modules/UnitFramesTarget.lua', 'local function BuildFrameObserver(frame, unit)');
    assertSourceIncludes('modules/UnitFramesTarget.lua', 'current.observer ~= observer');
    assertSourceIncludes('modules/UnitFramesTarget.lua', 'local function RetryOwnerRetiredFrames(ownerRecord)');
    assertSourceIncludes('modules/UnitFramesTarget.lua', 'Every desired frame is active before replacing ownerRecord fields.');
    assertSourceIncludes('modules/UnitFramesTarget.lua', 'previous observer cleanup');
    assertSourceIncludes('modules/UnitFramesRuntime.lua', 'observers: ');
    assertSourceExcludes('modules/UnitFramesTarget.lua', /observer:UnregisterAllEvents\(\)/, 'unchecked UnitFrames observer unregister');
    assertSourceExcludes('modules/UnitFramesTarget.lua', /observer:Register(?:Unit)?Event\(/, 'unchecked UnitFrames observer registration');

'''
check = replace_once(
    check,
    "    assertSourceIncludes('modules/UnitFramesTarget.lua', 'Target._frameRegistry');\n",
    "    assertSourceIncludes('modules/UnitFramesTarget.lua', 'Target._frameRegistry');\n" + contracts,
    'UnitFrames observer atomicity static contracts',
)
check_path.write_text(check, encoding='utf-8')


toc_path = Path('FeelsGoodUI.toc')
toc = toc_path.read_text(encoding='utf-8')
toc = replace_once(toc, '## Version: 0.0.69', '## Version: 0.0.70', 'TOC version')
toc_path.write_text(toc, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(readme, '- FeelsGoodUI `0.0.69`', '- FeelsGoodUI `0.0.70`', 'README version')
readme = replace_once(
    readme,
    'Unit-frame runtime state is also registry-owned: target/focus/targettarget observers, aura roles, header-hook state, low-health cache and `RegisterUnitWatch` ownership are kept off oUF frames/elements; target-aura reads do not repair SavedVariables, native watch failures propagate, and frame replacement reconciles through the current owner.',
    'Unit-frame runtime state is also registry-owned: target/focus/targettarget observers, aura roles, header-hook state, low-health cache and `RegisterUnitWatch` ownership are kept off oUF frames/elements. Observer replacement prepares every new subscription before owner publication, rolls back a failed multi-frame prepare without dropping prior observers, gates stale callbacks by exact observer identity, retains failed cleanup for retry, propagates detach failures, and target-aura reads never repair SavedVariables.',
    'README UnitFrames observer atomicity',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    'Target observer records, aura roles, header hooks, low-health cache and unit-watch ownership live in weak registries rather than on oUF frames/elements; observer/watch failures are result-bearing.',
    'Target observer records, aura roles, header hooks, low-health cache and unit-watch ownership live in weak registries rather than on oUF frames/elements. Observer subscriptions use prepare/commit replacement: every RegisterEvent/RegisterUnitEvent edge must succeed before publication, multi-frame failure rolls back only newly prepared observers, stale callbacks require exact observer identity, failed cleanup remains inert and retryable, and observer/watch failures are result-bearing.',
    'AGENT_GUIDE UnitFrames observer contract',
)
agent_path.write_text(agent, encoding='utf-8')

index_path = Path('CODE_INDEX.md')
index = index_path.read_text(encoding='utf-8')
index = replace_once(
    index,
    '| `modules/UnitFramesRuntime.lua`, `modules/UnitFramesRender.lua`, `modules/UnitFramesTarget.lua`, `modules/UnitFramesText.lua`, `modules/UnitFrames.lua` | Unit-frame lifecycle, rendering, target/aura observers, text safety, weak-key oUF runtime ownership, and result-bearing unit-watch transitions without persisted configuration repair. |',
    '| `modules/UnitFramesRuntime.lua`, `modules/UnitFramesRender.lua`, `modules/UnitFramesTarget.lua`, `modules/UnitFramesText.lua`, `modules/UnitFrames.lua` | Unit-frame lifecycle, rendering, atomic/retryable target-aura observer ownership, text safety, weak-key oUF runtime state, and result-bearing observer/unit-watch teardown without persisted configuration repair. |',
    'CODE_INDEX UnitFrames observer atomicity',
)
index_path.write_text(index, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(todo, '- [x] Target Interface `120105` and release `0.0.69`.', '- [x] Target Interface `120105` and release `0.0.70`.', 'TODO version')
todo = replace_once(
    todo,
    '- [x] Move UnitFrames target observers, aura roles, header-hook state, low-health cache and unit-watch ownership off oUF frames/elements into weak registries; remove target-aura runtime persistence writes and propagate native watch failures.',
    '- [x] Make UnitFrames target observer ownership atomic and retryable: prepare every event edge before publication, keep prior frames active across failed replacement, roll back only newly prepared observers, gate stale callbacks by exact observer identity, retain failed unregister cleanup for retry, and propagate observer/watch teardown failures without foreign metadata.',
    'TODO UnitFrames observer status',
)
todo = replace_once(
    todo,
    '- [ ] Target aura filtering handles ordinary and inaccessible aura-source payloads without indexing denied tables or fields; aura containers and oUF frames receive no `_fgui*` metadata, repeated attach installs no duplicate hooks/observers, and detach makes permanent header hooks inert.',
    '- [ ] Target aura filtering handles ordinary and inaccessible aura-source payloads without indexing denied tables or fields; inject CreateFrame/SetScript/RegisterEvent/RegisterUnitEvent/UnregisterAllEvents and partial header-hook failures during target/focus/targettarget replacement; prior observers remain active until full prepare, failed new observers are inert, cleanup retries exactly, repeated attach stays single, and no aura container/oUF frame receives `_fgui*` metadata.',
    'TODO UnitFrames observer validation',
)
todo_path.write_text(todo, encoding='utf-8')

matrix_path = Path('docs/REGRESSION_MATRIX_1_25.md')
matrix = matrix_path.read_text(encoding='utf-8')
matrix = replace_once(
    matrix,
    '| 13b | Reattach target/focus/targettarget observers, replace aura containers, and inject unit-watch register/unregister failure | Weak registries own observer/aura/header/low-health/watch state; no `_fgui*` fields or duplicate hooks remain; failure propagates and retry/teardown is exact |  |  |',
    '| 13b | Reattach/replace target, focus, targettarget and aura containers while injecting CreateFrame, SetScript, RegisterEvent, RegisterUnitEvent, UnregisterAllEvents, header-hook and unit-watch failure | New observer sets publish only after every edge succeeds; failed multi-frame prepare preserves prior owners and makes partial callbacks inert; stale callbacks require exact observer identity; unresolved cleanup retries; no `_fgui*` fields or duplicate hooks remain; exact failure reaches Apply/Lifecycle |  |  |',
    'regression matrix UnitFrames observer atomicity',
)
matrix_path.write_text(matrix, encoding='utf-8')

print('Made UnitFrames observer replacement atomic and cleanup retryable.')
