from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


shell_path = Path('modules/ActionBarsBlizzardShell.lua')
shell = shell_path.read_text(encoding='utf-8')
old_snapshot = '''    local snapshot = module._nativeActionBarToggles
    if type(snapshot) ~= "table" or type(snapshot.values) ~= "table" then
        return false
    end
'''
new_snapshot = '''    local snapshot = module._nativeActionBarToggles
    if type(snapshot) ~= "table" or type(snapshot.values) ~= "table" then
        local values, count = ReadPersistedNativeActionBarToggles()
        if not values then return false end
        snapshot = { values = values, count = count }
        module._nativeActionBarToggles = snapshot
    end
'''
shell = replace_once(shell, old_snapshot, new_snapshot, 'runtime snapshot fallback')

public_restore = r'''function Shell.RestorePersistedNativeActionBarToggles()
    if InCombat() then return false end

    local values, count = ReadPersistedNativeActionBarToggles()
    if not values then return false end

    local restored = ApplyActionBarToggles(values, count)
    if restored then
        ClearPersistedNativeActionBarToggles()
    end
    return restored
end

'''
shell = replace_once(
    shell,
    'local function SetMouseEnabledSafe(frame, enabled)\n',
    public_restore + 'local function SetMouseEnabledSafe(frame, enabled)\n',
    'public persisted toggle restore',
)
shell_path.write_text(shell, encoding='utf-8')

app_path = Path('core/App.lua')
app = app_path.read_text(encoding='utf-8')
app = replace_once(
    app,
    '''function App:OnPlayerLogin()
    Guard("App.EnableFeatureModules", function()
''',
    '''function App:OnPlayerLogin()
    Guard("ActionBars.RestorePersistedNativeState", function()
        local shell = ns.ActionBarsBlizzardShell
        if shell and type(shell.RestorePersistedNativeActionBarToggles) == "function" then
            shell.RestorePersistedNativeActionBarToggles()
        end
    end)

    Guard("App.EnableFeatureModules", function()
''',
    'pre-enable native toggle recovery',
)
app_path.write_text(app, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
check = replace_once(
    check,
    "    assertSourceIncludes('modules/ActionBarsBlizzardShell.lua', 'NATIVE_TOGGLE_RECOVERY_KEY');\n",
    "    assertSourceIncludes('modules/ActionBarsBlizzardShell.lua', 'NATIVE_TOGGLE_RECOVERY_KEY');\n"
    "    assertSourceIncludes('modules/ActionBarsBlizzardShell.lua', 'RestorePersistedNativeActionBarToggles');\n"
    "    assertSourceIncludes('core/App.lua', 'ActionBars.RestorePersistedNativeState');\n",
    'pre-enable recovery static contracts',
)
check_path.write_text(check, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    'persists a per-character recovery vector across reload/interruption, and restores the exact snapshot only on detach;',
    'persists a per-character recovery vector across reload/interruption, restores that vector on `PLAYER_LOGIN` before feature enable, and restores the exact snapshot on detach;',
    'AGENT_GUIDE startup recovery order',
)
agent_path.write_text(agent, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(
    readme,
    'a compact per-character recovery marker preserves that baseline across `/reload` or interruption until restore succeeds.',
    'a compact per-character recovery marker preserves that baseline across `/reload` or interruption and is restored on `PLAYER_LOGIN` before ActionBars reattaches.',
    'README startup recovery order',
)
readme_path.write_text(readme, encoding='utf-8')

print('Added pre-enable ActionBars native-state recovery.')
