-- FeelsGoodUI: atomic settings and panel transaction journal
local _, ns = ...

local Tx = {}
ns.PanelTransactions = Tx

local Apply = ns.Apply
local DB = ns.DB
local Log = ns.Log
local Settings = ns.Settings
local Shared = ns.OptionsShared
local U = ns.U

local OriginalContext = Shared and Shared.CreateBuilderContext
local OriginalBind = Shared and Shared.BindPanelApplyControls
local OriginalInvalidateAll = Settings and Settings.InvalidateAllHistory
local OriginalResetSection = Settings and Settings.ResetSection
local OriginalResetSections = Settings and Settings.ResetSections
local OriginalSetTx = Settings and Settings.SetTx
local OriginalUndo = Settings and Settings.UndoPanel

Tx._nextID = Tx._nextID or 0
Tx._byKey = Tx._byKey or {}
Tx._sectionEpoch = Tx._sectionEpoch or {}

local function Copy(value)
    if type(value) == "table" and U and type(U.DeepCopy) == "function" then
        return U.DeepCopy(value)
    end
    return value
end

local function CopyPath(path)
    if type(path) ~= "table" or #path == 0 then return nil end
    local out = {}
    for i = 1, #path do out[i] = path[i] end
    return out
end

local function UniqueStrings(value)
    local out, seen = {}, {}
    local function Add(item)
        if type(item) == "string" and item ~= "" and not seen[item] then
            seen[item] = true
            out[#out + 1] = item
        end
    end
    if type(value) == "string" then
        Add(value)
    elseif type(value) == "table" then
        for i = 1, #value do Add(value[i]) end
    end
    return out
end

local function Profile()
    local profile = DB and type(DB.EnsureProfileRoot) == "function" and DB:EnsureProfileRoot() or nil
    if type(profile) ~= "table" and DB and type(DB.GetProfile) == "function" then
        profile = DB:GetProfile()
    end
    return type(profile) == "table" and profile or nil
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

local function CurrentEpoch(section)
    return type(section) == "string" and (Tx._sectionEpoch[section] or 0) or 0
end

local function AdvanceEpoch(section)
    if type(section) ~= "string" or section == "" then return nil end
    local before = CurrentEpoch(section)
    local owned = before + 1
    Tx._sectionEpoch[section] = owned
    return { section = section, before = before, owned = owned }
end

local function SnapshotPath(path)
    local profile = Profile()
    local copiedPath = CopyPath(path)
    if not profile or not copiedPath then return nil end

    local node = profile
    for i = 1, #copiedPath - 1 do
        if type(node) ~= "table" then return nil end
        local key = copiedPath[i]
        local child = node[key]
        if child == nil then
            return {
                path = copiedPath,
                section = copiedPath[1],
                epoch = CurrentEpoch(copiedPath[1]),
                branchDepth = i,
                existed = false,
            }
        end
        if type(child) ~= "table" then
            return {
                path = copiedPath,
                section = copiedPath[1],
                epoch = CurrentEpoch(copiedPath[1]),
                branchDepth = i,
                existed = true,
                value = Copy(child),
            }
        end
        node = child
    end

    if type(node) ~= "table" then return nil end
    local key = copiedPath[#copiedPath]
    return {
        path = copiedPath,
        section = copiedPath[1],
        epoch = CurrentEpoch(copiedPath[1]),
        existed = node[key] ~= nil,
        value = Copy(node[key]),
    }
end

local function ReadPath(path)
    local node = Profile()
    if not node or type(path) ~= "table" then return false, nil end
    for i = 1, #path - 1 do
        node = type(node) == "table" and node[path[i]] or nil
        if type(node) ~= "table" then return false, nil end
    end
    local key = path[#path]
    return node[key] ~= nil, node[key]
end

local function WritePath(snapshot)
    local profile = Profile()
    if not profile or type(snapshot) ~= "table" or type(snapshot.path) ~= "table" then return false end

    local path = snapshot.path
    local stop = snapshot.branchDepth or #path
    local node = profile
    for i = 1, stop - 1 do
        local key = path[i]
        if type(node[key]) ~= "table" then node[key] = {} end
        node = node[key]
    end
    node[path[stop]] = snapshot.existed and Copy(snapshot.value) or nil
    return true
end

local function OwnsPath(snapshot, expected)
    if CurrentEpoch(snapshot.section) ~= snapshot.epoch then return false end
    local exists, current = ReadPath(snapshot.path)
    if expected == nil then return not exists end
    if type(expected) == "table" then return exists and rawequal(current, expected) end
    return exists and current == expected
end

local function SnapshotSections(sections)
    local profile = Profile()
    local names = UniqueStrings(sections)
    if not profile or #names == 0 then return nil end

    local snapshot = {}
    for i = 1, #names do
        local name = names[i]
        snapshot[i] = {
            name = name,
            existed = profile[name] ~= nil,
            value = Copy(profile[name]),
        }
    end
    return snapshot
end

local function ClaimSections(snapshot)
    for i = 1, #(snapshot or {}) do
        snapshot[i].epoch = AdvanceEpoch(snapshot[i].name)
        local profile = Profile()
        snapshot[i].expected = profile and Copy(profile[snapshot[i].name]) or nil
    end
end

local function CollectDiff(expected, current, path, out)
    if DeepEqual(expected, current) then return end
    if type(expected) == "table" and type(current) == "table" then
        local seen = {}
        for key in pairs(expected) do
            seen[key] = true
            local nextPath = CopyPath(path) or {}
            nextPath[#nextPath + 1] = key
            CollectDiff(expected[key], current[key], nextPath, out)
        end
        for key in pairs(current) do
            if not seen[key] then
                local nextPath = CopyPath(path) or {}
                nextPath[#nextPath + 1] = key
                CollectDiff(nil, current[key], nextPath, out)
            end
        end
        return
    end
    out[#out + 1] = { path = CopyPath(path) or {}, existed = current ~= nil, value = Copy(current) }
end

local function ApplyRelative(section, changes)
    local profile = Profile()
    if not profile then return end
    for i = 1, #changes do
        local change = changes[i]
        if #change.path == 0 then
            profile[section] = change.existed and Copy(change.value) or nil
        else
            if type(profile[section]) ~= "table" then profile[section] = {} end
            local node = profile[section]
            for j = 1, #change.path - 1 do
                local key = change.path[j]
                if type(node[key]) ~= "table" then node[key] = {} end
                node = node[key]
            end
            node[change.path[#change.path]] = change.existed and Copy(change.value) or nil
        end
    end
end

local function RestoreClaimedSections(snapshot)
    local profile = Profile()
    if not profile then return false end
    local changed = false

    for i = 1, #(snapshot or {}) do
        local record = snapshot[i]
        local epoch = record.epoch
        if epoch and CurrentEpoch(record.name) == epoch.owned then
            local overlay = {}
            CollectDiff(record.expected, profile[record.name], {}, overlay)
            profile[record.name] = record.existed and Copy(record.value) or nil
            ApplyRelative(record.name, overlay)
            Tx._sectionEpoch[record.name] = epoch.before
            changed = true
        end
    end
    return changed
end

local function HistoryState(panelKey)
    if not Settings or type(panelKey) ~= "string" or panelKey == "" then return nil end
    local stack = type(Settings._undoPanels) == "table" and Settings._undoPanels[panelKey] or nil
    local batch = type(Settings._undoPanelBatches) == "table" and Settings._undoPanelBatches[panelKey] or nil
    return {
        panelKey = panelKey,
        stack = stack,
        stackLength = type(stack) == "table" and #stack or 0,
        batch = batch,
        changeLength = type(batch) == "table" and type(batch.changes) == "table" and #batch.changes or 0,
    }
end

local function CaptureHistoryArtifact(before)
    if type(before) ~= "table" then return nil end
    local batch = before.batch
    if type(batch) == "table" and type(batch.changes) == "table" and #batch.changes > before.changeLength then
        return { container = batch.changes, entry = batch.changes[before.changeLength + 1] }
    end

    local stack = type(Settings._undoPanels) == "table" and Settings._undoPanels[before.panelKey] or nil
    if type(stack) == "table" and #stack > before.stackLength then
        return { container = stack, entry = stack[before.stackLength + 1] }
    end
    return nil
end

local function RemoveEmptyBatchOwner(container)
    if type(container) ~= "table" or #container ~= 0 then
        return
    end

    local panels = Settings and Settings._undoPanels
    if type(panels) ~= "table" then
        return
    end

    for panelKey, stack in pairs(panels) do
        if type(stack) == "table" then
            for i = #stack, 1, -1 do
                local entry = stack[i]
                if type(entry) == "table" and entry.changes == container then
                    table.remove(stack, i)
                    if #stack == 0 and panels[panelKey] == stack then
                        panels[panelKey] = nil
                    end
                    return
                end
            end
        end
    end
end

local function RemoveArtifact(artifact)
    local container = artifact and artifact.container
    if type(container) ~= "table" then return false end
    for i = #container, 1, -1 do
        if container[i] == artifact.entry then
            table.remove(container, i)
            RemoveEmptyBatchOwner(container)
            return true
        end
    end
    return false
end

local function UndoRecord(panelKey)
    local stack = Settings and type(Settings._undoPanels) == "table" and Settings._undoPanels[panelKey] or nil
    local index = type(stack) == "table" and #stack or 0
    local entry = index > 0 and stack[index] or nil
    if type(entry) ~= "table" then return nil end
    return { panelKey = panelKey, stack = stack, index = index, entry = entry }
end

local function UndoChanges(entry)
    local out = {}
    local function Add(change)
        if type(change) == "table" and type(change.path) == "table" then
            local snapshot = SnapshotPath(change.path)
            if snapshot then
                out[#out + 1] = { snapshot = snapshot, expected = change.old }
            end
        end
    end
    if type(entry.changes) == "table" then
        for i = 1, #entry.changes do Add(entry.changes[i]) end
    else
        Add(entry)
    end
    return out
end

local function RestoreUndoHistory(record)
    if type(record) ~= "table" then return false end
    local stack = type(Settings._undoPanels) == "table" and Settings._undoPanels[record.panelKey] or nil
    if type(stack) ~= "table" then
        Settings._undoPanels = Settings._undoPanels or {}
        stack = {}
        Settings._undoPanels[record.panelKey] = stack
    end
    for i = 1, #stack do if stack[i] == record.entry then return false end end
    table.insert(stack, math.min(record.index, #stack + 1), record.entry)
    return true
end

local function CaptureHistoryEntries(panelKey)
    local stack = Settings and type(Settings._undoPanels) == "table" and Settings._undoPanels[panelKey] or nil
    local entries = {}
    for i = 1, #(stack or {}) do entries[#entries + 1] = stack[i] end
    local batch = Settings and type(Settings._undoPanelBatches) == "table" and Settings._undoPanelBatches[panelKey] or nil
    local changes = {}
    for i = 1, #(batch and batch.changes or {}) do changes[#changes + 1] = batch.changes[i] end
    return { panelKey = panelKey, stack = stack, entries = entries, changes = changes, batch = batch }
end

local function RemoveCapturedHistory(captured)
    for i = 1, #(captured and captured.entries or {}) do
        RemoveArtifact({ container = captured.stack, entry = captured.entries[i] })
    end
    for i = 1, #(captured and captured.changes or {}) do
        RemoveArtifact({ container = captured.batch and captured.batch.changes, entry = captured.changes[i] })
    end

    local panelKey = captured and captured.panelKey
    if panelKey and captured.stack and #captured.stack == 0
        and Settings._undoPanels and Settings._undoPanels[panelKey] == captured.stack then
        Settings._undoPanels[panelKey] = nil
    end
    if panelKey and captured.batch and type(captured.batch.changes) == "table" and #captured.batch.changes == 0
        and Settings._undoPanelBatches and Settings._undoPanelBatches[panelKey] == captured.batch then
        Settings._undoPanelBatches[panelKey] = nil
    end
end

local function SafeCall(label, fn)
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn)
    if not ok then
        if Log and type(Log.Error) == "function" then Log:Error(label .. ": " .. tostring(result)) end
        return nil
    end
    return result
end

local function RemoveFromKey(transaction, key)
    local list = Tx._byKey[key]
    if type(list) ~= "table" then return end
    for i = #list, 1, -1 do if list[i] == transaction then table.remove(list, i) end end
    if #list == 0 then Tx._byKey[key] = nil end
end

local function Remove(transaction)
    for i = 1, #(transaction.keys or {}) do RemoveFromKey(transaction, transaction.keys[i]) end
end

local function Gather(keys)
    local out, seen = {}, {}
    local normalized = UniqueStrings(keys)
    for i = 1, #normalized do
        local list = Tx._byKey[normalized[i]]
        for j = 1, #(list or {}) do
            local transaction = list[j]
            if not seen[transaction] then seen[transaction] = true; out[#out + 1] = transaction end
        end
    end
    return out, normalized
end

function Tx:Register(keys, transaction)
    local normalized = UniqueStrings(keys)
    if #normalized == 0 or type(transaction) ~= "table" then return false end
    self._nextID = self._nextID + 1
    transaction.id = self._nextID
    transaction.keys = normalized
    transaction.waiting = {}
    transaction.committed = {}
    for i = 1, #normalized do
        local key = normalized[i]
        transaction.waiting[key] = true
        self._byKey[key] = self._byKey[key] or {}
        self._byKey[key][#self._byKey[key] + 1] = transaction
    end
    return true
end

function Tx:CommitKeys(keys)
    local transactions, normalized = Gather(keys)
    local finished = {}
    for i = 1, #transactions do
        local transaction = transactions[i]
        for j = 1, #normalized do
            local key = normalized[j]
            if transaction.waiting[key] then
                transaction.waiting[key] = nil
                transaction.committed[key] = true
                RemoveFromKey(transaction, key)
            end
        end
        if next(transaction.waiting) == nil then finished[#finished + 1] = transaction end
    end
    table.sort(finished, function(a, b) return a.id < b.id end)
    for i = 1, #finished do
        local transaction = finished[i]
        Remove(transaction)
        SafeCall("Settings transaction commit", transaction.commit)
        SafeCall("Settings transaction onCommit", transaction.onCommit)
    end
    return #finished > 0
end

local function RollbackTransactions(transactions)
    table.sort(transactions, function(a, b) return a.id > b.id end)
    local callbacks, restoreKeys = {}, {}
    for i = 1, #transactions do
        local transaction = transactions[i]
        Remove(transaction)
        local changed = SafeCall("Settings transaction rollback", transaction.rollback) == true
        if changed then
            for key in pairs(transaction.committed or {}) do restoreKeys[#restoreKeys + 1] = key end
        end
        if type(transaction.onRollback) == "function" then callbacks[#callbacks + 1] = transaction.onRollback end
    end
    return (#callbacks > 0 and callbacks or nil), UniqueStrings(restoreKeys)
end

function Tx:Checkpoint()
    return tonumber(self._nextID) or 0
end

function Tx:RollbackAfter(checkpoint, keys)
    checkpoint = tonumber(checkpoint) or 0
    local gathered = Gather(keys)
    local transactions = {}
    for i = 1, #gathered do
        local transaction = gathered[i]
        if (tonumber(transaction.id) or 0) > checkpoint then
            transactions[#transactions + 1] = transaction
        end
    end
    return RollbackTransactions(transactions)
end

function Tx:RollbackKeys(keys)
    local transactions = Gather(keys)
    return RollbackTransactions(transactions)
end

function Tx:RunRollbackCallbacks(callbacks)
    for i = 1, #(callbacks or {}) do SafeCall("Settings transaction onRollback", callbacks[i]) end
end

function Tx:InvalidateAll()
    self._byKey = {}
    self._sectionEpoch = {}
end

function Tx:UndoPanel(panelKey, applyKeys, callbacks)
    if not (Settings and type(OriginalUndo) == "function") then return false end
    local keys = UniqueStrings(applyKeys)
    if #keys == 0 or not (Apply and type(Apply.Request) == "function") then return OriginalUndo(Settings, panelKey) end

    local history = UndoRecord(panelKey)
    local changes = history and UndoChanges(history.entry) or nil
    if not history or #changes == 0 or OriginalUndo(Settings, panelKey) ~= true then return false end

    local transaction = {
        rollback = function()
            local owned = {}
            for i = 1, #changes do
                owned[i] = OwnsPath(changes[i].snapshot, changes[i].expected)
            end

            local changed = false
            for i = 1, #changes do
                if owned[i] then
                    WritePath(changes[i].snapshot)
                    changed = true
                end
            end
            return RestoreUndoHistory(history) or changed
        end,
        onCommit = type(callbacks) == "table" and callbacks.onCommit or nil,
        onRollback = type(callbacks) == "table" and callbacks.onRollback or nil,
    }
    if self:Register(keys, transaction) then return true end
    transaction.rollback()
    return false
end

function Tx:ResetSections(panelKey, sections, applyKeys, callbacks)
    local keys = UniqueStrings(applyKeys)
    if #keys == 0 or not (Apply and type(Apply.Request) == "function") then
        return Settings and Settings:ResetSections(sections) or false
    end

    local snapshot = SnapshotSections(sections)
    local capturedHistory = CaptureHistoryEntries(panelKey)
    if not snapshot then return false end

    local reset
    if type(OriginalResetSections) == "function" then
        reset = OriginalResetSections(Settings, sections)
    elseif type(OriginalResetSection) == "function" then
        reset = false
        for _, section in ipairs(UniqueStrings(sections)) do
            reset = OriginalResetSection(Settings, section) or reset
        end
    end
    if reset ~= true then return false end
    ClaimSections(snapshot)

    local transaction = {
        rollback = function() return RestoreClaimedSections(snapshot) end,
        commit = function() RemoveCapturedHistory(capturedHistory) end,
        onCommit = type(callbacks) == "table" and callbacks.onCommit or nil,
        onRollback = type(callbacks) == "table" and callbacks.onRollback or nil,
    }
    if self:Register(keys, transaction) then return true end
    transaction.rollback()
    return false
end

local function BindControls(applyState, undoBtn, resetBtn, resetSections, refreshFn, restoreApplyKeys)
    if type(OriginalBind) == "function" then OriginalBind(applyState, undoBtn, resetBtn, resetSections, refreshFn, restoreApplyKeys) end
    if type(applyState) ~= "table" then return end
    local keys = restoreApplyKeys or applyState.defaultApplyKeys
    local callbacks = { onRollback = refreshFn }
    if undoBtn then
        undoBtn:SetScript("OnClick", function()
            if Tx:UndoPanel(applyState.panelKey, keys, callbacks) then
                applyState:ApplyNow(keys)
                SafeCall("Panel refresh", refreshFn)
            end
        end)
    end
    if resetBtn then
        resetBtn:SetScript("OnClick", function()
            if Tx:ResetSections(applyState.panelKey, resetSections, keys, callbacks) then
                applyState.pending = false
                applyState:ApplyNow(keys)
                SafeCall("Panel refresh", refreshFn)
            end
        end)
    end
end

if Settings and type(OriginalSetTx) == "function" then
    function Settings:SetTx(applyKeys, path, value, rule, panelKey)
        local snapshot = SnapshotPath(path)
        local historyBefore = HistoryState(panelKey)
        local changed, stored = OriginalSetTx(self, applyKeys, path, value, rule, panelKey)
        local keys = UniqueStrings(applyKeys)
        if changed == true and snapshot and #keys > 0 then
            local artifact = CaptureHistoryArtifact(historyBefore)
            Tx:Register(keys, {
                rollback = function()
                    local restored = false
                    if OwnsPath(snapshot, stored) then restored = WritePath(snapshot) end
                    return RemoveArtifact(artifact) or restored
                end,
            })
        end
        return changed, stored
    end
end

if Settings and type(OriginalResetSection) == "function" then
    function Settings:ResetSection(section)
        local result = OriginalResetSection(self, section)
        if result == true then AdvanceEpoch(section) end
        return result
    end
end

if Settings and type(OriginalResetSections) == "function" then
    function Settings:ResetSections(sections)
        local result = OriginalResetSections(self, sections)
        if result == true then for _, section in ipairs(UniqueStrings(sections)) do AdvanceEpoch(section) end end
        return result
    end
end

if Shared and type(OriginalContext) == "function" then
    function Shared.CreateBuilderContext(...)
        local context = OriginalContext(...)
        if type(context) == "table" then context.BindPanelApplyControls = BindControls end
        return context
    end
    Shared.BindPanelApplyControls = BindControls
end

if Settings and type(OriginalInvalidateAll) == "function" then
    function Settings:InvalidateAllHistory(...)
        Tx:InvalidateAll()
        return OriginalInvalidateAll(self, ...)
    end
end

return Tx
