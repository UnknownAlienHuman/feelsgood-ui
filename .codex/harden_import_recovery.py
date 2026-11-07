from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


profile_path = Path('core/ProfileImport.lua')
profile = profile_path.read_text(encoding='utf-8')
profile = replace_once(
    profile,
    'local Settings = ns.Settings\n',
    'local Settings = ns.Settings\nlocal U = ns.U\n',
    'ProfileImport U dependency',
)
profile = replace_once(
    profile,
    '''local FALLBACK_APPLY_ORDER = {
    "runtime",
    "theme",
    "unitframes",
    "center",
    "experience",
    "actionbars",
    "companion",
    "minimap",
    "movers",
}

''',
    '''local FALLBACK_APPLY_ORDER = {
    "runtime",
    "theme",
    "unitframes",
    "center",
    "experience",
    "actionbars",
    "companion",
    "minimap",
    "movers",
}

local RECOVERY_KEY = "_profileImportRecovery"
local RECOVERY_VERSION = 1

''',
    'ProfileImport recovery constants',
)

helpers = r'''local function Copy(value, seen)
    if type(value) ~= "table" then return value end
    if U and type(U.DeepCopy) == "function" then
        return U.DeepCopy(value)
    end

    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, item in pairs(value) do
        out[Copy(key, seen)] = Copy(item, seen)
    end
    return out
end

local function DeepEqual(a, b, seen)
    if rawequal(a, b) then return true end
    if type(a) ~= type(b) or type(a) ~= "table" then return false end

    seen = seen or {}
    if seen[a] == b then return true end
    seen[a] = b

    for key, value in pairs(a) do
        if not DeepEqual(value, b[key], seen) then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end

local function CopyPath(path)
    local out = {}
    for i = 1, #(path or {}) do out[i] = path[i] end
    return out
end

local function CollectDiff(expected, current, path, out)
    if DeepEqual(expected, current) then return end
    if type(expected) == "table" and type(current) == "table" then
        local seen = {}
        for key, value in pairs(expected) do
            seen[key] = true
            local nextPath = CopyPath(path)
            nextPath[#nextPath + 1] = key
            CollectDiff(value, current[key], nextPath, out)
        end
        for key, value in pairs(current) do
            if not seen[key] then
                local nextPath = CopyPath(path)
                nextPath[#nextPath + 1] = key
                CollectDiff(nil, value, nextPath, out)
            end
        end
        return
    end

    out[#out + 1] = {
        path = CopyPath(path),
        existed = current ~= nil,
        value = Copy(current),
    }
end

local function ApplyDiff(profile, changes)
    for i = 1, #(changes or {}) do
        local change = changes[i]
        local path = change.path or {}
        if #path == 0 then
            profile = change.existed and Copy(change.value) or {}
        else
            local node = profile
            for j = 1, #path - 1 do
                local key = path[j]
                if type(node[key]) ~= "table" then node[key] = {} end
                node = node[key]
            end
            node[path[#path]] = change.existed and Copy(change.value) or nil
        end
    end
    return profile
end

local function GetRecoveryRoot()
    local root = DB and type(DB.data) == "table" and DB.data or _G.FeelsGoodUIDB
    return type(root) == "table" and root or nil
end

local function ClearRecovery()
    local root = GetRecoveryRoot()
    if root then root[RECOVERY_KEY] = nil end
end

local function PrepareRecovery(snapshot)
    local root = GetRecoveryRoot()
    local profile = DB and type(DB.GetProfile) == "function" and DB:GetProfile() or nil
    if not root or type(profile) ~= "table" then
        return false, "Profile recovery root is unavailable"
    end

    root[RECOVERY_KEY] = {
        version = RECOVERY_VERSION,
        previous = Copy(profile),
        expected = Copy(snapshot),
    }
    return true
end

'''
profile = replace_once(
    profile,
    'local function ErrorHandler(err)\n',
    helpers + 'local function ErrorHandler(err)\n',
    'ProfileImport recovery helpers',
)

recover_method = r'''function Import:RecoverInterrupted(root)
    root = type(root) == "table" and root or _G.FeelsGoodUIDB
    if type(root) ~= "table" then return false end

    local recovery = root[RECOVERY_KEY]
    if type(recovery) ~= "table" then return false end
    root[RECOVERY_KEY] = nil

    if recovery.version ~= RECOVERY_VERSION
        or type(recovery.previous) ~= "table"
        or type(recovery.expected) ~= "table" then
        if Log and type(Log.Warn) == "function" then
            Log:Warn("Discarded invalid profile-import recovery record.")
        end
        return false
    end

    local current = type(root.profile) == "table" and root.profile or {}
    local overlay = {}
    CollectDiff(recovery.expected, current, {}, overlay)
    root.profile = ApplyDiff(Copy(recovery.previous), overlay)

    if Log and type(Log.Warn) == "function" then
        Log:Warn("Recovered an interrupted profile import before DB initialization.")
    end
    return true
end

'''
profile = replace_once(
    profile,
    'function Import:IsPending()\n',
    recover_method + 'function Import:IsPending()\n',
    'ProfileImport recovery method',
)
profile = replace_once(
    profile,
    '''    local keys = GetApplyKeys()
    local checkpoint = PanelTransactions:Checkpoint()

    local state = { status = "pending" }
''',
    '''    local keys = GetApplyKeys()
    local checkpoint = PanelTransactions:Checkpoint()
    local recoveryReady, recoveryError = PrepareRecovery(snapshot)
    if not recoveryReady then
        return false, recoveryError
    end

    local state = { status = "pending" }
''',
    'ProfileImport recovery preparation',
)
profile = replace_once(
    profile,
    '''            onCommit = function()
                Finish(
''',
    '''            onCommit = function()
                ClearRecovery()
                Finish(
''',
    'ProfileImport commit recovery cleanup',
)
profile = replace_once(
    profile,
    '''            onRollback = function()
                Finish(
''',
    '''            onRollback = function()
                ClearRecovery()
                Finish(
''',
    'ProfileImport rollback recovery cleanup',
)
profile = replace_once(
    profile,
    '''    if not replaceCallOK or replaced ~= true then
        RollbackStaged(checkpoint, keys)
        self._pending = nil
''',
    '''    if not replaceCallOK or replaced ~= true then
        RollbackStaged(checkpoint, keys)
        ClearRecovery()
        self._pending = nil
''',
    'ProfileImport replace failure recovery cleanup',
)
profile = replace_once(
    profile,
    '''    if not requested then
        RollbackStaged(checkpoint, keys)
        if state.status == "pending" then
''',
    '''    if not requested then
        RollbackStaged(checkpoint, keys)
        ClearRecovery()
        if state.status == "pending" then
''',
    'ProfileImport request failure recovery cleanup',
)
profile_path.write_text(profile, encoding='utf-8')

app_path = Path('core/App.lua')
app = app_path.read_text(encoding='utf-8')
app = replace_once(
    app,
    '''function App:RunStartupServices()
    local services = {
        {
            label = "DB.Init",
''',
    '''function App:RunStartupServices()
    local services = {
        {
            label = "ProfileImport.RecoverInterrupted",
            run = function()
                local recovery = ns.ProfileImport
                if recovery and type(recovery.RecoverInterrupted) == "function" then
                    recovery:RecoverInterrupted(_G.FeelsGoodUIDB)
                end
            end,
        },
        {
            label = "DB.Init",
''',
    'App recovery startup service',
)
app_path.write_text(app, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(
    readme,
    'Profile import is staged on a detached snapshot and replaces the live profile through one profile-wide transaction; success is published only after every immediate and combat-deferred runtime owner commits, while a late failure restores the prior profile and history.',
    'Profile import is staged on a detached snapshot and replaces the live profile through one profile-wide transaction; success is published only after every immediate and combat-deferred runtime owner commits, while a late failure restores the prior profile and history. A temporary SavedVariables recovery record restores any import interrupted by `/reload`, logout, or client termination before terminal commit and overlays newer edits onto the recovered profile.',
    'README durable import policy',
)
readme_path.write_text(readme, encoding='utf-8')

index_path = Path('CODE_INDEX.md')
index = index_path.read_text(encoding='utf-8')
index = replace_once(
    index,
    '| `core/ProfileImport.lua`, `core/ProfileTransfer.lua` | Bounded decode/export UI plus detached normalization and profile-wide atomic import commit/rollback. |',
    '| `core/ProfileImport.lua`, `core/ProfileTransfer.lua` | Bounded decode/export UI, detached normalization, profile-wide atomic commit/rollback, and durable recovery for interrupted imports. |',
    'CODE_INDEX durable recovery',
)
index_path.write_text(index, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(
    todo,
    '- [x] Stage profile import on a detached snapshot and commit through one profile-wide transaction; preserve live root identity/history until every immediate and combat-deferred runtime owner succeeds, and restore the prior profile on any late failure.\n',
    '- [x] Stage profile import on a detached snapshot and commit through one profile-wide transaction; preserve live root identity/history until every immediate and combat-deferred runtime owner succeeds, restore the prior profile on any late failure, and persist a recovery record for interrupted imports.\n',
    'TODO durable recovery status',
)
todo = replace_once(
    todo,
    '- [ ] Attempt import while another settings transaction or import is pending; the live profile, runtime state, and undo history remain untouched.\n',
    '- [ ] Attempt import while another settings transaction or import is pending; the live profile, runtime state, and undo history remain untouched.\n'
    '- [ ] Start an import that remains combat-deferred, then `/reload` or log out before commit; next startup restores the previous profile and overlays any newer post-import edits, then removes the recovery record.\n',
    'TODO interrupted import validation',
)
todo_path.write_text(todo, encoding='utf-8')

print('Added durable recovery for interrupted profile imports.')
