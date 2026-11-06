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
local OriginalSetTx = Settings and Settings.SetTx
local OriginalUndo = Settings and Settings.UndoPanel

Tx._nextID = Tx._nextID or 0
Tx._byKey = Tx._byKey or {}

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
            return { path = copiedPath, branchDepth = i, existed = false }
        end
        if type(child) ~= "table" then
            return { path = copiedPath, branchDepth = i, existed = true, value = Copy(child) }
        end
        node = child
    end

    if type(node) ~= "table" then return nil end
    local key = copiedPath[#copiedPath]
    return {
        path = copiedPath,
        existed = node[key] ~= nil,
        value = Copy(node[key]),
    }
end

local function RestorePath(snapshot)
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

    local key = path[stop]
    node[key] = snapshot.existed and Copy(snapshot.value) or nil
    return true
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

local function RestoreSections(snapshot)
    local profile = Profile()
    if not profile or type(snapshot) ~= "table" then return false end
    for i = 1, #snapshot do
        local record = snapshot[i]
        profile[record.name] = record.existed and Copy(record.value) or nil
    end
    return true
end

local function SnapshotHistory(panelKey)
    if not Settings or type(panelKey) ~= "string" or panelKey == "" then return nil end
    local undo = type(Settings._undoPanels) == "table" and Settings._undoPanels[panelKey] or nil
    local batch = type(Settings._undoPanelBatches) == "table" and Settings._undoPanelBatches[panelKey] or nil
    return {
        panelKey = panelKey,
        undoExisted = undo ~= nil,
        undo = Copy(undo),
        batchExisted = batch ~= nil,
        batch = Copy(batch),
    }
end

local function RestoreHistory(snapshot)
    if not Settings or type(snapshot) ~= "table" then return false end
    Settings._undoPanels = Settings._undoPanels or {}
    Settings._undoPanelBatches = Settings._undoPanelBatches or {}
    Settings._undoPanels[snapshot.panelKey] = snapshot.undoExisted and Copy(snapshot.undo) or nil
    Settings._undoPanelBatches[snapshot.panelKey] = snapshot.batchExisted and Copy(snapshot.batch) or nil
    return true
end

local function UndoSections(panelKey)
    local stack = Settings and type(Settings._undoPanels) == "table" and Settings._undoPanels[panelKey] or nil
    local entry = type(stack) == "table" and stack[#stack] or nil
    if type(entry) ~= "table" then return nil end

    local sections = {}
    local function Add(change)
        local path = change and change.path
        if type(path) == "table" then sections[#sections + 1] = path[1] end
    end
    if type(entry.changes) == "table" then
        for i = 1, #entry.changes do Add(entry.changes[i]) end
    else
        Add(entry)
    end
    return UniqueStrings(sections)
end

local function SafeCall(label, fn)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn)
    if not ok and Log and type(Log.Error) == "function" then
        Log:Error(label .. ": " .. tostring(err))
    end
end

local function RemoveFromKey(transaction, key)
    local list = Tx._byKey[key]
    if type(list) ~= "table" then return end
    for i = #list, 1, -1 do
        if list[i] == transaction then table.remove(list, i) end
    end
    if #list == 0 then Tx._byKey[key] = nil end
end

local function Remove(transaction)
    for i = 1, #(transaction.keys or {}) do
        RemoveFromKey(transaction, transaction.keys[i])
    end
end

local function Gather(keys)
    local out, seen = {}, {}
    local normalized = UniqueStrings(keys)
    for i = 1, #normalized do
        local list = Tx._byKey[normalized[i]]
        for j = 1, #(list or {}) do
            local transaction = list[j]
            if not seen[transaction] then
                seen[transaction] = true
                out[#out + 1] = transaction
            end
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

function Tx:RollbackKeys(keys)
    local transactions = Gather(keys)
    table.sort(transactions, function(a, b) return a.id > b.id end)

    local callbacks, restoreKeys = {}, {}
    for i = 1, #transactions do
        local transaction = transactions[i]
        Remove(transaction)
        SafeCall("Settings transaction rollback", transaction.rollback)
        for key in pairs(transaction.committed or {}) do restoreKeys[#restoreKeys + 1] = key end
        if type(transaction.onRollback) == "function" then
            callbacks[#callbacks + 1] = transaction.onRollback
        end
    end
    return (#callbacks > 0 and callbacks or nil), UniqueStrings(restoreKeys)
end

function Tx:RunRollbackCallbacks(callbacks)
    for i = 1, #(callbacks or {}) do
        SafeCall("Settings transaction onRollback", callbacks[i])
    end
end

function Tx:InvalidateAll()
    self._byKey = {}
end

function Tx:UndoPanel(panelKey, applyKeys, callbacks)
    if not (Settings and type(OriginalUndo) == "function") then return false end
    local keys = UniqueStrings(applyKeys)
    if #keys == 0 or not (Apply and type(Apply.Request) == "function") then
        return OriginalUndo(Settings, panelKey)
    end

    local sections = SnapshotSections(UndoSections(panelKey))
    local history = SnapshotHistory(panelKey)
    if not sections or not history or OriginalUndo(Settings, panelKey) ~= true then return false end

    local transaction = {
        rollback = function()
            RestoreSections(sections)
            RestoreHistory(history)
        end,
        onCommit = type(callbacks) == "table" and callbacks.onCommit or nil,
        onRollback = type(callbacks) == "table" and callbacks.onRollback or nil,
    }
    if self:Register(keys, transaction) then return true end

    transaction.rollback()
    return false
end

function Tx:ResetSections(panelKey, sections, applyKeys, callbacks)
    if not (Settings and type(Settings.ResetSections) == "function") then return false end
    local keys = UniqueStrings(applyKeys)
    if #keys == 0 or not (Apply and type(Apply.Request) == "function") then
        return Settings:ResetSections(sections)
    end

    local sectionSnapshot = SnapshotSections(sections)
    local historySnapshot = SnapshotHistory(panelKey)
    if not sectionSnapshot or not historySnapshot or Settings:ResetSections(sections) ~= true then return false end

    local transaction = {
        rollback = function()
            RestoreSections(sectionSnapshot)
            RestoreHistory(historySnapshot)
        end,
        commit = function()
            if type(Settings.InvalidatePanelHistory) == "function" then
                Settings:InvalidatePanelHistory(panelKey)
            end
        end,
        onCommit = type(callbacks) == "table" and callbacks.onCommit or nil,
        onRollback = type(callbacks) == "table" and callbacks.onRollback or nil,
    }
    if self:Register(keys, transaction) then return true end

    transaction.rollback()
    return false
end

local function BindControls(applyState, undoBtn, resetBtn, resetSections, refreshFn, restoreApplyKeys)
    if type(OriginalBind) == "function" then
        OriginalBind(applyState, undoBtn, resetBtn, resetSections, refreshFn, restoreApplyKeys)
    end
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
        local history = SnapshotHistory(panelKey)
        local changed, stored = OriginalSetTx(self, applyKeys, path, value, rule, panelKey)
        local keys = UniqueStrings(applyKeys)
        if changed == true and snapshot and #keys > 0 then
            Tx:Register(keys, {
                rollback = function()
                    RestorePath(snapshot)
                    if history then RestoreHistory(history) end
                end,
            })
        end
        return changed, stored
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
