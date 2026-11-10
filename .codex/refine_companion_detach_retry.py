from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


path = Path('modules/CompanionRuntime.lua')
text = path.read_text(encoding='utf-8')

text = replace_once(
    text,
    '''    if not scripted or result == false then
        return nil, "watcher callback setup failed: " .. ErrorText(scriptDetail or result)
    end
''',
    '''    if not scripted or result == false then
        record.cleanupPending = true
        local failure = "watcher callback setup failed: " .. ErrorText(scriptDetail or result)
        local cleaned, cleanupDetail = CleanupWatcherRecord(record)
        if not cleaned then
            AddRetiredRecord(module, "_retiredWatcherRecords", record)
            failure = failure .. "; cleanup: " .. ErrorText(cleanupDetail)
        end
        return nil, failure
    end
''',
    'watcher setup cleanup',
)

text = replace_once(
    text,
    '''local function RetryRetiredRegistrations(module)
''',
    '''local function InstallDetachRetryWatcher(module)
    local watcher, detail = PrepareWatcherRecord(
        module,
        DETACH_WATCHER_EVENTS,
        "detach"
    )
    if not watcher then
        module._pendingDetachRestore = true
        module._eventsAttached = false
        module._detached = true
        module._detaching = nil
        return false, detail
    end

    PublishWatcherRecord(module, watcher)
    module._pendingDetachRestore = true
    module._eventsAttached = false
    module._detached = true
    module._detaching = nil
    return true
end

local function RetryRetiredRegistrations(module)
''',
    'detach retry watcher helper',
)

old_finalize = '''FinalizeDetach = function(module)
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
'''
new_finalize = '''FinalizeDetach = function(module)
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

    -- Keep the dedicated detach watcher active while older callback/watcher
    -- generations are still unresolved. It is the automatic retry owner.
    local retiredOK, retiredDetail = RetryRetiredRegistrations(module)
    if not retiredOK then
        module._pendingDetachRestore = true
        return false, "retired registrations: " .. ErrorText(retiredDetail)
    end

    local watcherOK, watcherDetail = ReleaseCurrentWatcherRecord(module)
    if not watcherOK then
        local retryOK, retryDetail = InstallDetachRetryWatcher(module)
        local detail = "detach watcher: " .. ErrorText(watcherDetail)
        if not retryOK then
            detail = detail .. "; replacement watcher: " .. ErrorText(retryDetail)
        end
        return false, detail
    end

    module._pendingAfterCombat = nil
    module._pendingPetButtons = nil
    module._pendingDetachRestore = nil
    module._applyingMicroLayout = nil
    module._eventsAttached = false
    module._detaching = nil
    module._detached = true
    ClearRuntimeFailure(module, "_detachLastError")
    return true
end
'''
text = replace_once(text, old_finalize, new_finalize, 'finalize detach retry ordering')

text = replace_once(
    text,
    '''    if IsDetached(module) then
        if module._pendingDetachRestore and not Shared:IsInCombat() then
            return FinalizeDetach(module)
        end
        return true
    end
''',
    '''    if IsDetached(module) then
        if module._pendingDetachRestore and not Shared:IsInCombat() then
            return FinalizeDetach(module)
        end

        local retiredOK, retiredDetail = RetryRetiredRegistrations(module)
        if not retiredOK then
            return false, "Companion retired cleanup failed: " .. ErrorText(retiredDetail)
        end
        return true
    end
''',
    'detached cleanup retry',
)

text = replace_once(
    text,
    '''    if Shared:IsInCombat() then
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
''',
    '''    if Shared:IsInCombat() then
        local watcherInstalled, watcherDetail = InstallDetachRetryWatcher(module)
        if not watcherInstalled then
            AppendFailure(failures, "detach watcher", watcherDetail)
            return false, JoinFailures(failures)
        end

        local detail = JoinFailures(failures)
''',
    'combat detach watcher installation',
)

path.write_text(text, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
anchor = "    assertSourceIncludes('modules/CompanionRuntime.lua', 'local function PrepareWatcherRecord(module, events, mode)');\n"
addition = (
    anchor
    + "    assertSourceIncludes('modules/CompanionRuntime.lua', 'local function InstallDetachRetryWatcher(module)');\n"
    + "    assertSourceIncludes('modules/CompanionRuntime.lua', 'Keep the dedicated detach watcher active');\n"
    + "    assertSourceIncludes('modules/CompanionRuntime.lua', 'replacement watcher: ');\n"
)
check = replace_once(check, anchor, addition, 'Companion detach retry static contracts')
check_path.write_text(check, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(
    readme,
    'uses a dedicated post-combat detach watcher whose restore failure remains pending and inert until a later exact retry.',
    'uses a dedicated post-combat detach watcher that remains the retry owner until restore and every retired registration are clean; failed self-unregister is replaced by a fresh exact watcher generation.',
    'README Companion detach retry policy',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    'and combat detach uses a dedicated watcher until exact layout restore succeeds.',
    'and combat detach keeps a dedicated watcher until exact layout restore plus retired-registration cleanup succeeds, replacing that watcher if its own unregister fails.',
    'AGENT_GUIDE Companion detach retry policy',
)
agent_path.write_text(agent, encoding='utf-8')

print('Refined Companion detach watcher ownership and setup cleanup.')
