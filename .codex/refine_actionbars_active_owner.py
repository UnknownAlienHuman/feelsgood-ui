from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


state_path = Path('modules/ActionBarsState.lua')
state = state_path.read_text(encoding='utf-8')
state = replace_once(
    state,
    '''function State.ReleaseStateHookOwner(module)
    if GlobalHookState.owner == module then
        GlobalHookState.owner = nil
        return true
    end
    return false
end
''',
    '''function State.SetStateHookOwner(module)
    if type(module) ~= "table" or module._detached == true then
        return false, "ActionBars state hook owner unavailable"
    end
    GlobalHookState.owner = module
    return true
end

function State.ReleaseStateHookOwner(module)
    if GlobalHookState.owner == module then
        GlobalHookState.owner = nil
        return true
    end
    return false
end
''',
    'State owner publication API',
)
state = replace_once(
    state,
    '''    GlobalHookState.owner = module
    local firstDetail
''',
    '''    local firstDetail
''',
    'remove preemptive State owner publication',
)
state_path.write_text(state, encoding='utf-8')


shell_path = Path('modules/ActionBarsBlizzardShell.lua')
shell = shell_path.read_text(encoding='utf-8')
shell = replace_once(
    shell,
    '''function Shell.ReleaseHookOwner(module)
    if GlobalHookState.owner == module then
        GlobalHookState.owner = nil
        return true
    end
    return false
end
''',
    '''function Shell.SetHookOwner(module)
    if type(module) ~= "table" or module._detached == true then
        return false, "ActionBars shell hook owner unavailable"
    end
    GlobalHookState.owner = module
    return true
end

function Shell.ReleaseHookOwner(module)
    if GlobalHookState.owner == module then
        GlobalHookState.owner = nil
        return true
    end
    return false
end
''',
    'Shell owner publication API',
)
shell = replace_once(
    shell,
    '''function Shell.EnsureEndCapsHook(module)
    if type(module) ~= "table" then
        return false, "ActionBars shell hook owner unavailable"
    end
    GlobalHookState.owner = module
''',
    '''function Shell.EnsureEndCapsHook(module)
    if type(module) ~= "table" then
        return false, "ActionBars shell hook owner unavailable"
    end
''',
    'remove preemptive EndCaps owner publication',
)
shell = replace_once(
    shell,
    '''function Shell.EnsureSettingsHooks(module)
    if type(module) ~= "table" then
        return false, "ActionBars settings hook owner unavailable"
    end
    GlobalHookState.owner = module
''',
    '''function Shell.EnsureSettingsHooks(module)
    if type(module) ~= "table" then
        return false, "ActionBars settings hook owner unavailable"
    end
''',
    'remove preemptive Settings owner publication',
)
shell_path.write_text(shell, encoding='utf-8')


runtime_path = Path('modules/ActionBarsRuntime.lua')
runtime = runtime_path.read_text(encoding='utf-8')
runtime = replace_once(
    runtime,
    '''local Runtime = {}
ns.ActionBarsRuntime = Runtime
''',
    '''local Runtime = {}
ns.ActionBarsRuntime = Runtime
Runtime._callbackOwner = nil
''',
    'Runtime callback owner state',
)
runtime = replace_once(
    runtime,
    '''local function OnActionChanged(_, button)
    local activeModule = ns.ActionBars
    if IsDetached(activeModule) then return end
''',
    '''local function OnActionChanged(_, button)
    local activeModule = Runtime._callbackOwner
    if IsDetached(activeModule) then return end
''',
    'callback owner dispatch',
)
owner_publish = '''    if State and type(State.SetStateHookOwner) == "function" then
        local ownerOK, ownerDetail = State.SetStateHookOwner(module)
        if ownerOK == false then
            return false, tostring(ownerDetail or "ActionBars state hook owner publication failed")
        end
    end

    if Shell and type(Shell.SetHookOwner) == "function" then
        local ownerOK, ownerDetail = Shell.SetHookOwner(module)
        if ownerOK == false then
            if State and type(State.ReleaseStateHookOwner) == "function" then
                State.ReleaseStateHookOwner(module)
            end
            return false, tostring(ownerDetail or "ActionBars shell hook owner publication failed")
        end
    end

    Runtime._callbackOwner = callbackRegistered == true and module or nil

'''
runtime = replace_once(
    runtime,
    '''    if module._initDone then
        return true
    end

    module._initDone = true
''',
    owner_publish + '''    if module._initDone then
        return true
    end

    module._initDone = true
''',
    'publish active owners after successful registrations',
)
runtime = replace_once(
    runtime,
    '''    module._actionChangedCallbackRegistered = nil

    if State and type(State.ReleaseStateHookOwner) == "function" then
''',
    '''    module._actionChangedCallbackRegistered = nil
    if Runtime._callbackOwner == module then
        Runtime._callbackOwner = nil
    end

    if State and type(State.ReleaseStateHookOwner) == "function" then
''',
    'release callback owner on detach',
)
runtime_path.write_text(runtime, encoding='utf-8')


check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
contracts = r'''    assertSourceIncludes('modules/ActionBarsState.lua', 'function State.SetStateHookOwner(module)');
    assertSourceIncludes('modules/ActionBarsBlizzardShell.lua', 'function Shell.SetHookOwner(module)');
    assertSourceIncludes('modules/ActionBarsRuntime.lua', 'Runtime._callbackOwner = nil');
    assertSourceIncludes('modules/ActionBarsRuntime.lua', 'local activeModule = Runtime._callbackOwner');
    assertSourceIncludes('modules/ActionBarsRuntime.lua', 'local ownerOK, ownerDetail = State.SetStateHookOwner(module)');
    assertSourceIncludes('modules/ActionBarsRuntime.lua', 'local ownerOK, ownerDetail = Shell.SetHookOwner(module)');
    assertSourceExcludes('modules/ActionBarsState.lua', /function State\.EnsureStateHooks[\s\S]*?GlobalHookState\.owner\s*=\s*module/, 'pre-success ActionBars state owner publication');
    assertSourceExcludes('modules/ActionBarsBlizzardShell.lua', /function Shell\.Ensure(?:EndCapsHook|SettingsHooks)[\s\S]*?GlobalHookState\.owner\s*=\s*module/, 'pre-success ActionBars shell owner publication');

'''
check = replace_once(
    check,
    "    assertSourceIncludes('modules/ActionBarsState.lua', 'State._secureHookRegistry');\n",
    "    assertSourceIncludes('modules/ActionBarsState.lua', 'State._secureHookRegistry');\n" + contracts,
    'active owner static contracts',
)
check_path.write_text(check, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(
    readme,
    'target/method edges live in weak registries, init/callback summaries publish only after successful registration, callbacks resolve the current active owner,',
    'target/method edges live in weak registries, installed partial edges remain inert until full initialization publishes the active owner, init/callback summaries publish only after successful registration, callbacks resolve that current active owner,',
    'README active owner publication',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    'callbacks resolve current ownership and every registration failure propagates through `ActionBarsRuntime` before `_initDone` or callback summaries publish.',
    'callbacks resolve the explicitly published active owner; partial permanent hooks stay inert until callback/state/shell registration all succeed, and every failure propagates through `ActionBarsRuntime` before `_initDone` or active-owner publication.',
    'AGENT_GUIDE active owner policy',
)
agent = replace_once(
    agent,
    'resolve the current owner at dispatch, and release owner references on detach.',
    'publish the active owner only after all mandatory init edges succeed, resolve that owner at dispatch, and release owner references on detach.',
    'AGENT_GUIDE active owner invariant',
)
agent_path.write_text(agent, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(
    todo,
    'weak target/method registries prevent duplicates, init/callback flags publish after success, owner replacement is dynamic, and detach releases owners/handles.',
    'weak target/method registries prevent duplicates, partial hooks stay inert until full init publishes active owners, init/callback flags publish after success, owner replacement is dynamic, and detach releases owners/handles.',
    'TODO active owner status',
)
todo_path.write_text(todo, encoding='utf-8')

print('Delayed ActionBars active-owner publication until full init success.')
