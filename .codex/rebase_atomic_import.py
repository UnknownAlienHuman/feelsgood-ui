from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


panel_path = Path("core/PanelTransactions.lua")
panel = panel_path.read_text(encoding="utf-8")

restore_exact = r'''local function RestoreSectionsExact(snapshot)
    local profile = Profile()
    if not profile then return false end

    for i = 1, #(snapshot or {}) do
        local record = snapshot[i]
        profile[record.name] = record.existed and Copy(record.value) or nil
    end
    return true
end

'''
panel = replace_once(
    panel,
    'local function HistoryState(panelKey)\n',
    restore_exact + 'local function HistoryState(panelKey)\n',
    "RestoreSectionsExact insertion",
)

all_history = r'''local function CaptureAllHistory()
    local names, seen = {}, {}
    local function Add(panelKey)
        if type(panelKey) == "string" and panelKey ~= "" and not seen[panelKey] then
            seen[panelKey] = true
            names[#names + 1] = panelKey
        end
    end

    for panelKey in pairs((Settings and Settings._undoPanels) or {}) do Add(panelKey) end
    for panelKey in pairs((Settings and Settings._undoPanelBatches) or {}) do Add(panelKey) end
    table.sort(names)

    local captured = {}
    for i = 1, #names do
        captured[#captured + 1] = CaptureHistoryEntries(names[i])
    end
    return captured
end

local function RemoveCapturedHistories(captured)
    for i = 1, #(captured or {}) do
        RemoveCapturedHistory(captured[i])
    end
end

'''
panel = replace_once(
    panel,
    'local function SafeCall(label, fn)\n',
    all_history + 'local function SafeCall(label, fn)\n',
    "CaptureAllHistory insertion",
)

profile_replace = r'''function Tx:HasPending()
    for _, list in pairs(self._byKey or {}) do
        if type(list) == "table" and #list > 0 then
            return true
        end
    end
    for _, list in pairs((Settings and Settings._pending) or {}) do
        if type(list) == "table" and #list > 0 then
            return true
        end
    end
    for _, batch in pairs((Settings and Settings._undoPanelBatches) or {}) do
        if type(batch) == "table" and (tonumber(batch.depth) or 0) > 0 then
            return true
        end
    end
    return false
end

function Tx:ReplaceProfile(replacement, applyKeys, callbacks)
    callbacks = type(callbacks) == "table" and callbacks or {}
    if type(replacement) ~= "table" then
        return false, "Replacement profile is not a table"
    end
    if self:HasPending() then
        return false, "Settings transactions are still pending"
    end

    local keys = UniqueStrings(applyKeys)
    if #keys == 0 then
        return false, "Profile replacement has no apply owners"
    end

    local profile = Profile()
    if not profile then
        return false, "Live profile is unavailable"
    end

    local names, seen = {}, {}
    local function Add(name)
        if type(name) == "string" and name ~= "" and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    for name in pairs(profile) do Add(name) end
    for name in pairs(replacement) do
        if type(name) ~= "string" then
            return false, "Replacement profile contains an unsupported top-level key"
        end
        Add(name)
    end
    table.sort(names)

    local snapshot = SnapshotSections(names)
    if not snapshot then
        return false, "Profile replacement snapshot failed"
    end
    local capturedHistory = CaptureAllHistory()
    local claimed = false

    local installed, installError = xpcall(function()
        for i = 1, #names do
            local name = names[i]
            profile[name] = Copy(replacement[name])
        end
        ClaimSections(snapshot)
        claimed = true
    end, function(err)
        return tostring(err or "unknown profile replacement error")
    end)
    if not installed then
        if claimed then
            RestoreClaimedSections(snapshot)
        else
            RestoreSectionsExact(snapshot)
        end
        return false, installError
    end

    local transaction = {
        rollback = function()
            return RestoreClaimedSections(snapshot)
        end,
        commit = function()
            RemoveCapturedHistories(capturedHistory)
        end,
        onCommit = callbacks.onCommit,
        onRollback = callbacks.onRollback,
    }

    local registerOK, registered = pcall(self.Register, self, keys, transaction)
    if registerOK and registered == true then
        return true
    end

    transaction.rollback()
    return false, registerOK and "Profile replacement registration failed" or tostring(registered)
end

'''
panel = replace_once(
    panel,
    'function Tx:Register(keys, transaction)\n',
    profile_replace + 'function Tx:Register(keys, transaction)\n',
    "ReplaceProfile insertion",
)
panel_path.write_text(panel, encoding="utf-8")

profile_path = Path("core/ProfileImport.lua")
profile = profile_path.read_text(encoding="utf-8")
profile = replace_once(
    profile,
    '''    if not (PanelTransactions
        and type(PanelTransactions.HasPending) == "function"
        and type(PanelTransactions.BeginScope) == "function"
        and type(PanelTransactions.ReplaceProfile) == "function"
        and type(PanelTransactions.RollbackScope) == "function") then
''',
    '''    if not (PanelTransactions
        and type(PanelTransactions.HasPending) == "function"
        and type(PanelTransactions.Checkpoint) == "function"
        and type(PanelTransactions.ReplaceProfile) == "function"
        and type(PanelTransactions.RollbackAfter) == "function") then
''',
    "ProfileImport owner contract",
)

rollback_helper = r'''local function RollbackStaged(checkpoint, keys)
    local callbacks, restoreKeys = PanelTransactions:RollbackAfter(checkpoint, keys)
    if type(PanelTransactions.RunRollbackCallbacks) == "function" then
        PanelTransactions:RunRollbackCallbacks(callbacks)
    end

    if type(restoreKeys) == "table" and #restoreKeys > 0
        and Apply and type(Apply.Request) == "function" then
        local ok, err = pcall(Apply.Request, Apply, restoreKeys)
        if not ok and Log and type(Log.Error) == "function" then
            Log:Error("Profile import runtime restore request failed: " .. tostring(err))
        end
    end
end

'''
profile = replace_once(
    profile,
    'function Import:IsPending()\n',
    rollback_helper + 'function Import:IsPending()\n',
    "ProfileImport rollback helper",
)
profile = replace_once(
    profile,
    '''    local scope = PanelTransactions:BeginScope(keys)
    if not scope then
        return false, "Profile import scope could not be created"
    end
''',
    '''    local checkpoint = PanelTransactions:Checkpoint()
''',
    "ProfileImport checkpoint",
)
count = profile.count('PanelTransactions:RollbackScope(scope)')
if count != 2:
    raise RuntimeError(f"ProfileImport rollback calls: expected 2, found {count}")
profile = profile.replace('PanelTransactions:RollbackScope(scope)', 'RollbackStaged(checkpoint, keys)')
profile_path.write_text(profile, encoding="utf-8")

todo_path = Path("todo.md")
todo = todo_path.read_text(encoding="utf-8")
todo = replace_once(
    todo,
    '- [x] Target Interface `120105` and release `0.0.49`.',
    '- [x] Target Interface `120105` and release `0.0.50`.',
    "TODO release",
)
todo = replace_once(
    todo,
    '- [x] Separate mover geometry preview from persistence: drag/resize hot paths mutate runtime frames only, terminal input creates one validated transaction, and failed/cancelled commits restore the persisted runtime owner.\n',
    '- [x] Separate mover geometry preview from persistence: drag/resize hot paths mutate runtime frames only, terminal input creates one validated transaction, and failed/cancelled commits restore the persisted runtime owner.\n'
    '- [x] Stage profile import on a detached snapshot and commit through one profile-wide transaction; preserve live root identity/history until every immediate and combat-deferred runtime owner succeeds, and restore the prior profile on any late failure.\n',
    "TODO implementation status",
)
todo = replace_once(
    todo,
    '- [ ] Show/hide/reset the minimap icon from settings and slash commands; position reset is one undo action and failed `LibDBIcon` apply rolls back hide/position values.\n',
    '- [ ] Show/hide/reset the minimap icon from settings and slash commands; position reset is one undo action and failed `LibDBIcon` apply rolls back hide/position values.\n'
    '- [ ] Import a valid profile both in and out of combat; the UI reports queued status until all apply owners finish, old history is removed only after commit, and a forced late failure restores the previous profile while preserving newer edits.\n'
    '- [ ] Attempt import while another settings transaction or import is pending; the live profile, runtime state, and undo history remain untouched.\n',
    "TODO import validation",
)
todo_path.write_text(todo, encoding="utf-8")

print("Rebased atomic profile import onto current mover transaction tree.")
