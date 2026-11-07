from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


shell_path = Path('modules/ActionBarsBlizzardShell.lua')
shell = shell_path.read_text(encoding='utf-8')

native_helpers = r'''local function ReadActionBarToggles()
    if type(_G.GetActionBarToggles) ~= "function" then
        return nil
    end

    local values = { _G.GetActionBarToggles() }
    if #values < 4 then
        return nil
    end
    return values
end

local function ApplyActionBarToggles(values, count)
    if type(values) ~= "table" or type(_G.SetActionBarToggles) ~= "function" then
        return false
    end

    count = tonumber(count) or #values
    if count < 4 then
        return false
    end

    local ok = pcall(_G.SetActionBarToggles, unpack(values, 1, count))
    if not ok then
        return false
    end

    if type(_G.MultiActionBar_Update) == "function" then
        pcall(_G.MultiActionBar_Update)
    end
    return true
end

local function CaptureNativeActionBarToggles(module, values)
    if type(module) ~= "table" then
        return false
    end
    if type(module._nativeActionBarToggles) == "table" then
        return true
    end

    values = values or ReadActionBarToggles()
    if type(values) ~= "table" then
        return false
    end

    local snapshot = {}
    for i = 1, #values do snapshot[i] = values[i] end
    module._nativeActionBarToggles = {
        values = snapshot,
        count = #snapshot,
    }
    return true
end

local function RestoreNativeActionBarToggles(module)
    if type(module) ~= "table" then
        return false
    end

    local snapshot = module._nativeActionBarToggles
    if type(snapshot) ~= "table" or type(snapshot.values) ~= "table" then
        return false
    end
    if InCombat() then
        module._pendingRestore = true
        return false
    end

    local restored = ApplyActionBarToggles(snapshot.values, snapshot.count)
    if restored then
        module._nativeActionBarToggles = nil
    end
    return restored
end

'''
shell = replace_once(
    shell,
    'local function SetMouseEnabledSafe(frame, enabled)\n',
    native_helpers + 'local function SetMouseEnabledSafe(frame, enabled)\n',
    'native toggle helpers',
)

old_restore = '''    if type(barsCfg) == "table" and Shell.EnsureBlizzardMultiBars then
        Shell.EnsureBlizzardMultiBars(module, barsCfg, false)
    end

    if type(_G.MultiActionBar_Update) == "function" then
        pcall(_G.MultiActionBar_Update)
    end
'''
new_restore = '''    local restoredNativeToggles = false
    if IsDetached(module) then
        restoredNativeToggles = RestoreNativeActionBarToggles(module)
    elseif type(barsCfg) == "table" and Shell.EnsureBlizzardMultiBars then
        Shell.EnsureBlizzardMultiBars(module, barsCfg, false)
    end

    if not restoredNativeToggles and type(_G.MultiActionBar_Update) == "function" then
        pcall(_G.MultiActionBar_Update)
    end
'''
shell = replace_once(shell, old_restore, new_restore, 'RestoreBlizzardArt native-state branch')
shell = replace_once(
    shell,
    '    return restored\nend\n\nfunction Shell.KickHideBlizzardArt',
    '    return restored or restoredNativeToggles\nend\n\nfunction Shell.KickHideBlizzardArt',
    'RestoreBlizzardArt return value',
)

start = shell.index('local function IsUntouchedSideBar')
end = shell.index('function Shell.EnsureBlizzardMultiBars', start)
shell = shell[:start] + shell[end:]

ensure_start = shell.index('function Shell.EnsureBlizzardMultiBars')
ensure_end = shell.index('function Shell.EnsureEndCapsHook', ensure_start)
new_ensure = r'''function Shell.EnsureBlizzardMultiBars(module, barsCfg, hideBlizzardOverride)
    if InCombat() then return false end

    local toggles = ReadActionBarToggles()
    if not toggles or type(_G.SetActionBarToggles) ~= "function" then
        return false
    end
    CaptureNativeActionBarToggles(module, toggles)

    local function IsBarEnabled(index)
        local cfg = barsCfg[index]
        return type(cfg) ~= "table" or cfg.enabled ~= false
    end

    local hideBlizzard = hideBlizzardOverride
    if hideBlizzard == nil then
        hideBlizzard = Shell.ShouldHideBlizzardArt()
    end

    local desired = {
        IsBarEnabled(2),
        IsBarEnabled(3),
        hideBlizzard and false or IsBarEnabled(4),
        hideBlizzard and false or IsBarEnabled(5),
    }
    local didChange = false
    for i = 1, 4 do
        if toggles[i] ~= desired[i] then
            toggles[i] = desired[i]
            didChange = true
        end
    end

    if didChange then
        if not ApplyActionBarToggles(toggles, #toggles) then
            return false
        end
        Shell.QueueManagedPositionsRefresh(module)
    end
    return true
end

'''
shell = shell[:ensure_start] + new_ensure + shell[ensure_end:]
shell_path.write_text(shell, encoding='utf-8')

runtime_path = Path('modules/ActionBarsRuntime.lua')
runtime = runtime_path.read_text(encoding='utf-8')
runtime = replace_once(
    runtime,
    '''    ab.autoHide = (type(ab.autoHide) == "table") and ab.autoHide or {}
    module._autoHideEnabled = (ab.autoHide.enabled == true)
''',
    '''    local autoHide = (type(ab.autoHide) == "table") and ab.autoHide or nil
    module._autoHideEnabled = autoHide and autoHide.enabled == true or false
''',
    'ActionBars auto-hide read-only config',
)
runtime = replace_once(
    runtime,
    '''    if Shell and Shell.ImportSideBarStateFromBlizzard then
        Shell.ImportSideBarStateFromBlizzard(module, barsCfg)
    end
''',
    '',
    'remove implicit Blizzard-to-profile import',
)
runtime_path.write_text(runtime, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
check = replace_once(
    check,
    '''    assertSourceIncludes('core/MoversTransactions.lua', 'RestorePreview(spec.applyKeys)');

''',
    '''    assertSourceIncludes('core/MoversTransactions.lua', 'RestorePreview(spec.applyKeys)');
    assertSourceIncludes('modules/ActionBarsBlizzardShell.lua', 'CaptureNativeActionBarToggles');
    assertSourceIncludes('modules/ActionBarsBlizzardShell.lua', 'RestoreNativeActionBarToggles');
    assertSourceExcludes('modules/ActionBarsBlizzardShell.lua', /ImportSideBarStateFromBlizzard/, 'implicit Blizzard-to-profile sidebar import');
    assertSourceExcludes('modules/ActionBarsBlizzardShell.lua', /barsCfg\s*\[\s*[45]\s*\]\.enabled\s*=/, 'direct sidebar profile mutation');
    assertSourceExcludes('modules/ActionBarsRuntime.lua', /\bab\.autoHide\s*=(?!=)/, 'runtime action-bar profile normalization');

''',
    'ActionBars static ownership contracts',
)
check_path.write_text(check, encoding='utf-8')

# Release metadata and documentation.
toc_path = Path('FeelsGoodUI.toc')
toc = toc_path.read_text(encoding='utf-8')
toc = replace_once(toc, '## Version: 0.0.50', '## Version: 0.0.51', 'TOC version')
toc_path.write_text(toc, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(readme, '- FeelsGoodUI `0.0.50`', '- FeelsGoodUI `0.0.51`', 'README version')
readme = replace_once(
    readme,
    'Protected action-bar and Blizzard-frame mutations remain deferred outside combat.',
    'Protected action-bar and Blizzard-frame mutations remain deferred outside combat. ActionBars snapshots the complete native `GetActionBarToggles()` state before takeover and restores it exactly on detach; native sidebar state is never imported by mutating the addon profile, and unchanged toggle sets are not rewritten.',
    'README native-toggle policy',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    '- Action bars: `modules/ActionBars.lua` owns secure holders and delegates state, visual, Blizzard shell, Edit Mode, and runtime updates to the `ActionBars*` files. This is the most protected/taint-sensitive family.',
    '- Action bars: `modules/ActionBars.lua` owns secure holders and delegates state, visual, Blizzard shell, Edit Mode, and runtime updates to the `ActionBars*` files. `ActionBarsBlizzardShell` snapshots native multi-bar toggles before takeover and restores the exact snapshot only on detach; it must never infer or persist addon configuration from Blizzard toggles. This is the most protected/taint-sensitive family.',
    'AGENT_GUIDE action-bar ownership',
)
agent = replace_once(
    agent,
    '- Secure action-bar holders, state drivers, Edit Mode, `SetAttribute`, and Blizzard shell visibility are protected boundaries. Defer mutations in combat and validate `ADDON_ACTION_BLOCKED`, `ADDON_ACTION_FORBIDDEN`, and `MACRO_ACTION_FORBIDDEN` reports.',
    '- Secure action-bar holders, state drivers, Edit Mode, `SetAttribute`, Blizzard shell visibility, and native action-bar toggles are protected ownership boundaries. Defer mutations in combat, snapshot before takeover, restore exactly on detach, avoid redundant native writes, and validate `ADDON_ACTION_BLOCKED`, `ADDON_ACTION_FORBIDDEN`, and `MACRO_ACTION_FORBIDDEN` reports.',
    'AGENT_GUIDE action-bar invariant',
)
agent_path.write_text(agent, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(todo, '- [x] Target Interface `120105` and release `0.0.50`.', '- [x] Target Interface `120105` and release `0.0.51`.', 'TODO version')
todo = replace_once(
    todo,
    '- [x] Stage profile import on a detached snapshot and commit through one profile-wide transaction; preserve live root identity/history until every immediate and combat-deferred runtime owner succeeds, restore the prior profile on any late failure, and persist a recovery record for interrupted imports.\n',
    '- [x] Stage profile import on a detached snapshot and commit through one profile-wide transaction; preserve live root identity/history until every immediate and combat-deferred runtime owner succeeds, restore the prior profile on any late failure, and persist a recovery record for interrupted imports.\n'
    '- [x] Make ActionBars native toggle takeover reversible: never copy Blizzard side-bar state into SavedVariables, avoid redundant `SetActionBarToggles` calls, and restore the exact pre-attach toggle vector after out-of-combat or deferred detach.\n',
    'TODO action-bar implementation status',
)
todo = replace_once(
    todo,
    '- [ ] Disable ActionBars both out of combat and during combat; after combat, Blizzard shell is restored once and no stale delayed hide/apply callback reclaims it.\n',
    '- [ ] Disable ActionBars both out of combat and during combat; after combat, Blizzard shell is restored once and no stale delayed hide/apply callback reclaims it.\n'
    '- [ ] Before enabling ActionBars, set a distinctive Blizzard multi-bar toggle combination; addon apply must not alter `profile.actionbars.bars[4/5].enabled`, repeated identical applies must not rewrite native toggles, and detach must restore the exact original toggle vector.\n',
    'TODO native toggle validation',
)
todo_path.write_text(todo, encoding='utf-8')

matrix_path = Path('docs/REGRESSION_MATRIX_1_25.md')
matrix = matrix_path.read_text(encoding='utf-8')
matrix = replace_once(
    matrix,
    '| 21 | Disable/re-enable action bars and reload | Blizzard-owned bars restore; no detached delayed callback re-enters |  |  |',
    '| 21 | Disable/re-enable action bars and reload after setting a distinctive native multi-bar toggle vector | Exact pre-attach Blizzard toggles and shell state restore; addon profile bars do not change; no detached delayed callback re-enters |  |  |',
    'regression matrix ActionBars restore',
)
matrix_path.write_text(matrix, encoding='utf-8')

print('Hardened ActionBars native toggle and profile ownership.')
