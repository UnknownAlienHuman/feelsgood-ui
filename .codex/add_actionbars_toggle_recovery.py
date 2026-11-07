from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


path = Path('modules/ActionBarsBlizzardShell.lua')
text = path.read_text(encoding='utf-8')
text = replace_once(
    text,
    '''local MANAGED_POSITIONS_REFRESH_KEY = "FGUI_AB_MANAGED_POSITIONS"

''',
    '''local MANAGED_POSITIONS_REFRESH_KEY = "FGUI_AB_MANAGED_POSITIONS"
local NATIVE_TOGGLE_RECOVERY_KEY = "_actionBarsNativeToggleRecovery"
local NATIVE_TOGGLE_RECOVERY_VERSION = 1

''',
    'native recovery constants',
)

helpers = r'''local function CopyToggleVector(values, count)
    if type(values) ~= "table" then return nil end
    count = tonumber(count) or #values
    if count < 4 then return nil end

    local copy = {}
    for i = 1, count do copy[i] = values[i] end
    return copy, count
end

local function GetNativeToggleRecoveryRoot()
    local root = DB and type(DB.data) == "table" and DB.data or _G.FeelsGoodUIDB
    return type(root) == "table" and root or nil
end

local function GetNativeToggleRecoveryID()
    if type(_G.UnitGUID) == "function" then
        local guid = _G.UnitGUID("player")
        if type(guid) == "string" and guid ~= "" then
            return guid
        end
    end

    if type(_G.UnitFullName) == "function" then
        local name, realm = _G.UnitFullName("player")
        if type(name) == "string" and name ~= "" then
            return name .. "-" .. tostring(realm or "")
        end
    end
    return "default"
end

local function ReadPersistedNativeActionBarToggles()
    local root = GetNativeToggleRecoveryRoot()
    local recovery = root and root[NATIVE_TOGGLE_RECOVERY_KEY] or nil
    if type(recovery) ~= "table" or recovery.version ~= NATIVE_TOGGLE_RECOVERY_VERSION
        or type(recovery.records) ~= "table" then
        return nil
    end

    local record = recovery.records[GetNativeToggleRecoveryID()]
    if type(record) ~= "table" then return nil end
    local values, count = CopyToggleVector(record.values, record.count)
    if not values then return nil end
    return values, count
end

local function PersistNativeActionBarToggles(values, count)
    local root = GetNativeToggleRecoveryRoot()
    local copy, resolvedCount = CopyToggleVector(values, count)
    if not root or not copy then return false end

    local recovery = root[NATIVE_TOGGLE_RECOVERY_KEY]
    if type(recovery) ~= "table" or recovery.version ~= NATIVE_TOGGLE_RECOVERY_VERSION then
        recovery = {
            version = NATIVE_TOGGLE_RECOVERY_VERSION,
            records = {},
        }
        root[NATIVE_TOGGLE_RECOVERY_KEY] = recovery
    end
    recovery.records = type(recovery.records) == "table" and recovery.records or {}
    recovery.records[GetNativeToggleRecoveryID()] = {
        values = copy,
        count = resolvedCount,
    }
    return true
end

local function ClearPersistedNativeActionBarToggles()
    local root = GetNativeToggleRecoveryRoot()
    local recovery = root and root[NATIVE_TOGGLE_RECOVERY_KEY] or nil
    if type(recovery) ~= "table" or type(recovery.records) ~= "table" then
        return false
    end

    recovery.records[GetNativeToggleRecoveryID()] = nil
    if next(recovery.records) == nil then
        root[NATIVE_TOGGLE_RECOVERY_KEY] = nil
    end
    return true
end

'''
text = replace_once(
    text,
    'local function ReadActionBarToggles()\n',
    helpers + 'local function ReadActionBarToggles()\n',
    'native recovery helpers',
)

old_capture = r'''local function CaptureNativeActionBarToggles(module, values)
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
'''
new_capture = r'''local function CaptureNativeActionBarToggles(module, values)
    if type(module) ~= "table" then
        return false
    end
    if type(module._nativeActionBarToggles) == "table" then
        return true
    end

    local persistedValues, persistedCount = ReadPersistedNativeActionBarToggles()
    local snapshot, count
    if persistedValues then
        snapshot, count = persistedValues, persistedCount
    else
        values = values or ReadActionBarToggles()
        snapshot, count = CopyToggleVector(values)
        if not snapshot then return false end
        PersistNativeActionBarToggles(snapshot, count)
    end

    module._nativeActionBarToggles = {
        values = snapshot,
        count = count,
    }
    return true
end
'''
text = replace_once(text, old_capture, new_capture, 'durable native toggle capture')
text = replace_once(
    text,
    '''    if restored then
        module._nativeActionBarToggles = nil
    end
''',
    '''    if restored then
        module._nativeActionBarToggles = nil
        ClearPersistedNativeActionBarToggles()
    end
''',
    'durable native toggle cleanup',
)
path.write_text(text, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
check = replace_once(
    check,
    "    assertSourceIncludes('modules/ActionBarsBlizzardShell.lua', 'RestoreNativeActionBarToggles');\n",
    "    assertSourceIncludes('modules/ActionBarsBlizzardShell.lua', 'RestoreNativeActionBarToggles');\n"
    "    assertSourceIncludes('modules/ActionBarsBlizzardShell.lua', 'NATIVE_TOGGLE_RECOVERY_KEY');\n",
    'native recovery static contract',
)
check_path.write_text(check, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(
    readme,
    'ActionBars snapshots the complete native `GetActionBarToggles()` state before takeover and restores it exactly on detach; native sidebar state is never imported by mutating the addon profile, and unchanged toggle sets are not rewritten.',
    'ActionBars snapshots the complete native `GetActionBarToggles()` state before takeover and restores it exactly on detach; a compact per-character recovery marker preserves that baseline across `/reload` or interruption until restore succeeds. Native sidebar state is never imported by mutating the addon profile, and unchanged toggle sets are not rewritten.',
    'README durable toggle recovery',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    '`ActionBarsBlizzardShell` snapshots native multi-bar toggles before takeover and restores the exact snapshot only on detach; it must never infer or persist addon configuration from Blizzard toggles.',
    '`ActionBarsBlizzardShell` snapshots native multi-bar toggles before takeover, persists a per-character recovery vector across reload/interruption, and restores the exact snapshot only on detach; it must never infer or persist addon profile configuration from Blizzard toggles.',
    'AGENT_GUIDE durable native ownership',
)
agent_path.write_text(agent, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(
    todo,
    '- [x] Make ActionBars native toggle takeover reversible: never copy Blizzard side-bar state into SavedVariables, avoid redundant `SetActionBarToggles` calls, and restore the exact pre-attach toggle vector after out-of-combat or deferred detach.\n',
    '- [x] Make ActionBars native toggle takeover reversible: never copy Blizzard side-bar state into addon profile data, persist a per-character recovery vector across reload/interruption, avoid redundant `SetActionBarToggles` calls, and restore the exact pre-attach vector after out-of-combat or deferred detach.\n',
    'TODO durable native recovery status',
)
todo = replace_once(
    todo,
    '- [ ] Before enabling ActionBars, set a distinctive Blizzard multi-bar toggle combination; addon apply must not alter `profile.actionbars.bars[4/5].enabled`, repeated identical applies must not rewrite native toggles, and detach must restore the exact original toggle vector.\n',
    '- [ ] Before enabling ActionBars, set a distinctive Blizzard multi-bar toggle combination; addon apply must not alter `profile.actionbars.bars[4/5].enabled`, repeated identical applies must not rewrite native toggles, `/reload` must retain the original recovery vector, and detach must restore the exact original vector and remove its recovery record.\n',
    'TODO durable native recovery validation',
)
todo_path.write_text(todo, encoding='utf-8')

matrix_path = Path('docs/REGRESSION_MATRIX_1_25.md')
matrix = matrix_path.read_text(encoding='utf-8')
matrix = replace_once(
    matrix,
    'Exact pre-attach Blizzard toggles and shell state restore; addon profile bars do not change; no detached delayed callback re-enters',
    'Exact pre-attach Blizzard toggles and shell state restore after reload or detach; recovery marker clears after restore; addon profile bars do not change; no detached delayed callback re-enters',
    'regression matrix durable native recovery',
)
matrix_path.write_text(matrix, encoding='utf-8')

print('Added durable per-character ActionBars toggle recovery.')
