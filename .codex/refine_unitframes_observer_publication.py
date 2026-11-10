from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


path = Path('modules/UnitFramesTarget.lua')
text = path.read_text(encoding='utf-8')

text = replace_once(
    text,
    '''    -- Publish the target frame only after every mandatory permanent edge is
    -- installed. A partial hook remains inert and retryable.
    hook.frame = frame
    return true
end

local function HookTargetHeaderAnchorSignals(frame)
''',
    '''    return true
end

local function PublishTargetHeaderSignal(frame, element)
    local hook = element and HeaderHookRegistry[element] or nil
    if type(hook) == "table" and hook.showHooked == true and hook.hideHooked == true then
        hook.frame = frame
    end
end

local function PublishTargetHeaderAnchorSignals(frame)
    if type(frame) ~= "table" or not frame.TargetHeader then return end
    PublishTargetHeaderSignal(frame, frame.Buffs)
    PublishTargetHeaderSignal(frame, frame.Debuffs)
end

local function HookTargetHeaderAnchorSignals(frame)
''',
    'defer target header owner publication',
)

text = replace_once(
    text,
    '''    local unit = frame.unit
    if unit ~= "target" and unit ~= "focus" and unit ~= "targettarget" then
        return true, nil, false, true
    end
''',
    '''    local unit = frame.unit
    if unit ~= "target" and unit ~= "focus" and unit ~= "targettarget" then
        return false,
            "UnitFrames observer frame unit is unavailable or unsupported: " .. tostring(unit),
            false,
            false
    end
''',
    'reject invalid observer unit',
)

text = replace_once(
    text,
    '''        if cleanupOK == false then
            return false, cleanupDetail, false, true
        end
        return true, nil, false, true
    end
''',
    '''        PublishTargetHeaderAnchorSignals(frame)
        if cleanupOK == false then
            return false, cleanupDetail, false, true
        end
        return true, nil, false, true
    end
''',
    'publish active target header owner',
)

text = replace_once(
    text,
    '''    record.observer = observer
    record.owner = owner
    record.unit = unit
    record.active = true

    local failures = {}
''',
    '''    record.observer = observer
    record.owner = owner
    record.unit = unit
    record.active = true
    PublishTargetHeaderAnchorSignals(frame)

    local failures = {}
''',
    'publish prepared target header owner',
)

text = replace_once(
    text,
    '''        if ready ~= true then
            local rollbackOK, rollbackDetail = RollbackActivatedFrames(ownerRecord, activated)
            local failure = tostring(field) .. ": " .. tostring(detail)
''',
    '''        if ready ~= true then
            local failedFrame = desired[field]
            local failedRecord = failedFrame and FrameRegistry[failedFrame] or nil
            if failedRecord
                and type(failedRecord.retiredObservers) == "table"
                and #failedRecord.retiredObservers > 0 then
                MarkRetiredFrame(ownerRecord, failedFrame)
            end

            local rollbackOK, rollbackDetail = RollbackActivatedFrames(ownerRecord, activated)
            local failure = tostring(field) .. ": " .. tostring(detail)
''',
    'retain failed prepare cleanup ownership',
)

path.write_text(text, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
check = replace_once(
    check,
    "    assertSourceIncludes('modules/UnitFramesTarget.lua', 'local function BuildFrameObserver(frame, unit)');\n",
    "    assertSourceIncludes('modules/UnitFramesTarget.lua', 'local function BuildFrameObserver(frame, unit)');\n"
    "    assertSourceIncludes('modules/UnitFramesTarget.lua', 'local function PublishTargetHeaderAnchorSignals(frame)');\n"
    "    assertSourceIncludes('modules/UnitFramesTarget.lua', 'UnitFrames observer frame unit is unavailable or unsupported');\n"
    "    assertSourceIncludes('modules/UnitFramesTarget.lua', 'MarkRetiredFrame(ownerRecord, failedFrame)');\n",
    'UnitFrames publication static contracts',
)
check_path.write_text(check, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(
    readme,
    'Observer replacement prepares every new subscription before owner publication, rolls back failed multi-frame preparation without dropping prior observers, gates stale callbacks by exact observer identity, retains failed cleanup for retry, and propagates detach failures instead of publishing a false attached state.',
    'Observer replacement prepares every new subscription before event/header owner publication, rolls back failed multi-frame preparation without dropping prior observers, rejects malformed frame units, gates stale callbacks by exact observer identity, retains both failed preparation and teardown cleanup for retry, and propagates detach failures instead of publishing a false attached state.',
    'README UnitFrames publication refinement',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    'Observer subscriptions use prepare/commit replacement: every RegisterEvent/RegisterUnitEvent edge must succeed before publication, multi-frame failure rolls back only newly prepared observers, stale callbacks require exact observer identity, failed cleanup remains inert and retryable, and observer/watch failures are result-bearing.',
    'Observer subscriptions use prepare/commit replacement: every RegisterEvent/RegisterUnitEvent edge and valid observed unit must succeed before event/header owner publication, multi-frame failure rolls back only newly prepared observers, stale callbacks require exact observer identity, failed preparation/teardown cleanup remains inert and retryable, and observer/watch failures are result-bearing.',
    'AGENT_GUIDE UnitFrames publication refinement',
)
agent_path.write_text(agent, encoding='utf-8')

print('Refined UnitFrames observer/header publication and failed-prepare cleanup ownership.')
