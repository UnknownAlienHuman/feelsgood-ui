from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


runtime_path = Path('modules/ActionBarsRuntime.lua')
runtime = runtime_path.read_text(encoding='utf-8')
runtime = replace_once(
    runtime,
    '''local Runtime = {}
ns.ActionBarsRuntime = Runtime
Runtime._callbackOwner = nil
''',
    '''local Runtime = {}
ns.ActionBarsRuntime = Runtime
Runtime._callbackOwner = nil
Runtime._callbackRecord = nil
Runtime._nextCallbackID = 0
''',
    'callback registry state',
)

start = runtime.index('local function EnsureActionChangedCallback(module)')
end = runtime.index('function Runtime.PreviewMoverLayout', start)
replacement = r'''local function DispatchActionChanged(record, _, button)
    if not (record and record.active == true and Runtime._callbackRecord == record) then
        return
    end
    OnActionChanged(nil, button)
end

local function EnsureActionChangedCallback(module)
    local existingRecord = module._actionChangedCallbackRecord
    if module._actionChangedCallbackRegistered == true
        and type(existingRecord) == "table"
        and existingRecord.active == true
        and module._callbackHandles then
        return true, nil, true, existingRecord
    end

    module._actionChangedCallbackRegistered = nil
    module._actionChangedCallbackRecord = nil
    module._callbackHandles = nil

    if not _G.EventRegistry then
        return true, nil, false, nil
    end
    if not (EventUtil and type(EventUtil.CreateCallbackHandleContainer) == "function") then
        return true, nil, false, nil
    end

    local createOK, container = pcall(EventUtil.CreateCallbackHandleContainer)
    if not createOK or not container then
        return false, createOK and "Callback handle container unavailable" or tostring(container), false, nil
    end
    if type(container.RegisterCallback) ~= "function" then
        return false, "Callback handle container lacks RegisterCallback", false, nil
    end

    Runtime._nextCallbackID = Runtime._nextCallbackID + 1
    local record = {
        id = Runtime._nextCallbackID,
        active = true,
    }
    local callback = function(...)
        DispatchActionChanged(record, ...)
    end

    local registeredOK, registeredDetail = pcall(
        container.RegisterCallback,
        container,
        _G.EventRegistry,
        "ActionButton.OnActionChanged",
        callback,
        module
    )
    if not registeredOK then
        record.active = false
        if type(container.Unregister) == "function" then
            pcall(container.Unregister, container)
        end
        return false, tostring(registeredDetail), false, nil
    end

    module._callbackHandles = container
    module._actionChangedCallbackRecord = record
    module._actionChangedCallbackRegistered = true
    return true, nil, true, record
end

'''
runtime = runtime[:start] + replacement + runtime[end:]

runtime = replace_once(
    runtime,
    '''    local callbackOK, callbackDetail, callbackRegistered = EnsureActionChangedCallback(module)
''',
    '''    local callbackOK, callbackDetail, callbackRegistered, callbackRecord = EnsureActionChangedCallback(module)
''',
    'callback record result',
)
runtime = replace_once(
    runtime,
    '''    Runtime._callbackOwner = callbackRegistered == true and module or nil
''',
    '''    Runtime._callbackOwner = callbackRegistered == true and module or nil
    Runtime._callbackRecord = callbackRegistered == true and callbackRecord or nil
''',
    'callback record publication',
)
runtime = replace_once(
    runtime,
    '''    module._detached = true

    if InCombat() then
''',
    '''    module._detached = true

    local callbackRecord = module._actionChangedCallbackRecord
    if type(callbackRecord) == "table" then
        callbackRecord.active = false
    end
    if Runtime._callbackRecord == callbackRecord then
        Runtime._callbackRecord = nil
    end
    if Runtime._callbackOwner == module then
        Runtime._callbackOwner = nil
    end

    if InCombat() then
''',
    'invalidate callback record before detach cleanup',
)
old_cleanup = '''    if module._callbackHandles and type(module._callbackHandles.Unregister) == "function" then
        local ok, detail = pcall(module._callbackHandles.Unregister, module._callbackHandles)
        if not ok then
            cleanupOK = false
            cleanupDetail = cleanupDetail or tostring(detail)
        end
    end
    module._actionChangedCallbackRegistered = nil
    if Runtime._callbackOwner == module then
        Runtime._callbackOwner = nil
    end
'''
new_cleanup = '''    local callbackHandles = module._callbackHandles
    module._callbackHandles = nil
    module._actionChangedCallbackRecord = nil
    module._actionChangedCallbackRegistered = nil
    if callbackHandles and type(callbackHandles.Unregister) == "function" then
        local ok, detail = pcall(callbackHandles.Unregister, callbackHandles)
        if not ok then
            cleanupOK = false
            cleanupDetail = cleanupDetail or tostring(detail)
        end
    end
'''
runtime = replace_once(runtime, old_cleanup, new_cleanup, 'detach callback handle cleanup')
runtime_path.write_text(runtime, encoding='utf-8')


check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
contracts = r'''    assertSourceIncludes('modules/ActionBarsRuntime.lua', 'Runtime._callbackRecord = nil');
    assertSourceIncludes('modules/ActionBarsRuntime.lua', 'local function DispatchActionChanged(record, _, button)');
    assertSourceIncludes('modules/ActionBarsRuntime.lua', 'record.active == true and Runtime._callbackRecord == record');
    assertSourceIncludes('modules/ActionBarsRuntime.lua', 'callbackRecord.active = false');
    assertSourceIncludes('modules/ActionBarsRuntime.lua', 'module._callbackHandles = nil');
    assertSourceExcludes('modules/ActionBarsRuntime.lua', /RegisterCallback[\s\S]{0,500}OnActionChanged,\s*module/, 'unguarded ActionBars callback registration');

'''
check = replace_once(
    check,
    "    assertSourceIncludes('modules/ActionBarsRuntime.lua', 'Runtime._callbackOwner = nil');\n",
    "    assertSourceIncludes('modules/ActionBarsRuntime.lua', 'Runtime._callbackOwner = nil');\n" + contracts,
    'callback record static contracts',
)
check_path.write_text(check, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(
    readme,
    'detach releases owners and unregisters callback handles, and retry installs only missing edges.',
    'detach invalidates a generation record before unregistering callback handles, so an old callback remains inert even when cleanup fails; owners are released and retry installs only missing edges.',
    'README callback generation contract',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    'callbacks resolve the explicitly published active owner; partial permanent hooks stay inert until callback/state/shell registration all succeed,',
    'callbacks require both the explicitly published active owner and the current registration record; detach invalidates that record before attempting `Unregister`, so stale callback handles remain inert even after cleanup failure. Partial permanent hooks stay inert until callback/state/shell registration all succeed,',
    'AGENT_GUIDE callback record contract',
)
agent_path.write_text(agent, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(
    todo,
    'partial hooks stay inert until full init publishes active owners, init/callback flags publish after success, owner replacement is dynamic, and detach releases owners/handles.',
    'partial hooks stay inert until full init publishes active owners, init/callback flags publish after success, callback generations make stale handles inert before cleanup, owner replacement is dynamic, and detach releases owners/handles.',
    'TODO callback generation status',
)
todo_path.write_text(todo, encoding='utf-8')

print('Guarded ActionBars callback registrations with invalidatable records.')