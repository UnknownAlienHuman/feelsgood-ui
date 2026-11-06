-- FeelsGoodUI: transactional panel undo/reset coordination
--
-- Settings:SetTx owns ordinary field writes. This layer owns higher-level panel
-- operations that previously changed whole sections/history outside the apply
-- rollback boundary.

local _, ns = ...

local PanelTransactions = {}
ns.PanelTransactions = PanelTransactions

local Apply = ns.Apply
local DB = ns.DB
local FeatureRegistry = ns.FeatureRegistry
local Log = ns.Log
local Settings = ns.Settings
local Shared = ns.OptionsShared
local U = ns.U

local OriginalCreateBuilderContext = Shared and Shared.CreateBuilderContext
local OriginalBindPanelApplyControls = Shared and Shared.BindPanelApplyControls
local OriginalInvalidateAllHistory = Settings and Settings.InvalidateAllHistory
local OriginalResetProfileSections = Shared and Shared.ResetProfileSections
local OriginalUndoPanel = Settings and Settings.UndoPanel

PanelTransactions._nextID = PanelTransactions._nextID or 0
PanelTransactions._pendingByKey = PanelTransactions._pendingByKey or {}

local function Copy(value)
    if type(value) == "table" and U and type(U.DeepCopy) == "function" then
        return U.DeepCopy(value)
    end
    return value
end

local function GetProfile()
    if DB and type(DB.EnsureProfileRoot) == "function" then
        local profile = DB:EnsureProfileRoot()
        if type(profile) == "table" then
            return profile
        end
    end
    if DB and type(DB.GetProfile) == "function" then
        local profile = DB:GetProfile()
        if type(profile) == "table" then
            return profile
        end
    end
    return nil
end

local function NormalizeKeys(keys)
    local out, seen = {}, {}

    local function Add(key)
        if type(key) == "string" and key ~= "" and not seen[key] then
            seen[key] = true
            out[#out + 1] = key
        end
    end

    if type(keys) == "string" then
        Add(keys)
    elseif type(keys) == "table" then
        for i = 1, #keys do
            Add(keys[i])
        end
    end

    return out
end

local function NormalizeSections(sections)
    local out, seen = {}, {}

    local function Add(section)
        if type(section) == "string" and section ~= "" and not seen[section] then
            seen[section] = true
            out[#out + 1] = section
        end
    end

    if type(sections) == "string" then
        Add(sections)
    elseif type(sections) == "table" then
        for i = 1, #sections do
            Add(sections[i])
        end
    end

    return out
end

local function GetPanelSections(panelKey, explicitSections, includeContract)
    local out = NormalizeSections(explicitSections)
    if includeContract ~= true then
        return out
    end

    local seen = {}
    for i = 1, #out do
        seen[out[i]] = true
    end

    local contract = FeatureRegistry
        and type(FeatureRegistry.GetPanelContract) == "function"
        and FeatureRegistry:GetPanelContract(panelKey)
        or nil

    local function Add(section)
        if type(section) == "string" and section ~= "" and not seen[section] then
            seen[section] = true
            out[#out + 1] = section
        end
    end

    if type(contract) == "table" then
        if type(contract.contextSections) == "table" then
            for _, section in pairs(contract.contextSections) do
                Add(section)
            end
        end
        if type(contract.resetSections) == "table" then
            for i = 1, #contract.resetSections do
                Add(contract.resetSections[i])
            end
        end
    end

    return out
end

local function GetUndoSections(panelKey)
    if not Settings or type(Settings._undoPanels) ~= "table" then
        return nil
    end

    local stack = Settings._undoPanels[panelKey]
    local entry = type(stack) == "table" and stack[#stack] or nil
    if type(entry) ~= "table" then
        return nil
    end

    local sections, seen = {}, {}
    local function AddPath(path)
        local section = type(path) == "table" and path[1] or nil
        if type(section) == "string" and section ~= "" and not seen[section] then
            seen[section] = true
            sections[#sections + 1] = section
        end
    end

    if type(entry.changes) == "table" then
        for i = 1, #entry.changes do
            AddPath(entry.changes[i] and entry.changes[i].path)
        end
    else
        AddPath(entry.path)
    end

    return #sections > 0 and sections or nil
end

local function SnapshotSections(panelKey, explicitSections, includeContract)
    local profile = GetProfile()
    if type(profile) ~= "table" then
        return nil
    end

    local sections = GetPanelSections(panelKey, explicitSections, includeContract)
    if #sections == 0 then
        return nil
    end

    local snapshot = {}
    for i = 1, #sections do
        local section = sections[i]
        snapshot[#snapshot + 1] = {
            section = section,
            existed = profile[section] ~= nil,
            value = Copy(profile[section]),
        }
    end
    return snapshot
end

local function RestoreSections(snapshot)
    local profile = GetProfile()
    if type(profile) ~= "table" or type(snapshot) ~= "table" then
        return false
    end

    for i = 1, #snapshot do
        local record = snapshot[i]
        if type(record) == "table" and type(record.section) == "string" then
            if record.existed then
                profile[record.section] = Copy(record.value)
            else
                profile[record.section] = nil
            end
        end
    end
    return true
end

local function SnapshotPanelHistory(panelKey)
    if not Settings or type(panelKey) ~= "string" or panelKey == "" then
        return nil
    end

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

local function RestorePanelHistory(snapshot)
    if not Settings or type(snapshot) ~= "table" then
        return false
    end

    local panelKey = snapshot.panelKey
    if type(panelKey) ~= "string" or panelKey == "" then
        return false
    end

    Settings._undoPanels = Settings._undoPanels or {}
    Settings._undoPanelBatches = Settings._undoPanelBatches or {}

    if snapshot.undoExisted then
        Settings._undoPanels[panelKey] = Copy(snapshot.undo)
    else
        Settings._undoPanels[panelKey] = nil
    end

    if snapshot.batchExisted then
        Settings._undoPanelBatches[panelKey] = Copy(snapshot.batch)
    else
        Settings._undoPanelBatches[panelKey] = nil
    end

    return true
end

local function RemoveTransactionFromKey(transaction, key)
    local list = PanelTransactions._pendingByKey[key]
    if type(list) ~= "table" then
        return
    end

    for index = #list, 1, -1 do
        if list[index] == transaction then
            table.remove(list, index)
        end
    end
    if #list == 0 then
        PanelTransactions._pendingByKey[key] = nil
    end
end

local function RemoveTransaction(transaction)
    local keys = transaction and transaction.keys or nil
    if type(keys) ~= "table" then
        return
    end

    for i = 1, #keys do
        RemoveTransactionFromKey(transaction, keys[i])
    end
end

local function SafeCallback(label, callback)
    if type(callback) ~= "function" then
        return
    end

    local ok, err = pcall(callback)
    if not ok and Log and type(Log.Error) == "function" then
        Log:Error(tostring(label) .. ": " .. tostring(err))
    end
end

function PanelTransactions:Register(keys, transaction)
    local normalizedKeys = NormalizeKeys(keys)
    if #normalizedKeys == 0 or type(transaction) ~= "table" then
        return false
    end

    self._nextID = self._nextID + 1
    transaction.id = self._nextID
    transaction.keys = normalizedKeys
    transaction.remaining = {}
    transaction.finalized = false

    for i = 1, #normalizedKeys do
        local key = normalizedKeys[i]
        transaction.remaining[key] = true
        local list = self._pendingByKey[key]
        if type(list) ~= "table" then
            list = {}
            self._pendingByKey[key] = list
        end
        list[#list + 1] = transaction
    end

    return true
end

local function CollectTransactions(self, keys)
    local collected, seen = {}, {}
    local normalizedKeys = NormalizeKeys(keys)

    for i = 1, #normalizedKeys do
        local list = self._pendingByKey[normalizedKeys[i]]
        if type(list) == "table" then
            for j = 1, #list do
                local transaction = list[j]
                if type(transaction) == "table" and not seen[transaction] then
                    seen[transaction] = true
                    collected[#collected + 1] = transaction
                end
            end
        end
    end

    return collected, normalizedKeys
end

function PanelTransactions:CommitKeys(keys)
    local transactions, normalizedKeys = CollectTransactions(self, keys)
    if #transactions == 0 then
        return false
    end

    local finalized = {}
    for i = 1, #transactions do
        local transaction = transactions[i]
        for j = 1, #normalizedKeys do
            local key = normalizedKeys[j]
            if transaction.remaining[key] then
                transaction.remaining[key] = nil
                RemoveTransactionFromKey(transaction, key)
            end
        end
        if not transaction.finalized and next(transaction.remaining) == nil then
            finalized[#finalized + 1] = transaction
        end
    end

    table.sort(finalized, function(a, b) return (a.id or 0) < (b.id or 0) end)
    for i = 1, #finalized do
        local transaction = finalized[i]
        transaction.finalized = true
        RemoveTransaction(transaction)
        SafeCallback("Panel transaction commit", transaction.commit)
        SafeCallback("Panel transaction onCommit", transaction.onCommit)
    end

    return #finalized > 0
end

function PanelTransactions:RollbackKeys(keys)
    local transactions = CollectTransactions(self, keys)
    if #transactions == 0 then
        return nil
    end

    table.sort(transactions, function(a, b) return (a.id or 0) > (b.id or 0) end)
    local callbacks = {}

    for i = 1, #transactions do
        local transaction = transactions[i]
        if not transaction.finalized then
            transaction.finalized = true
            RemoveTransaction(transaction)
            SafeCallback("Panel transaction rollback", transaction.rollback)
            if type(transaction.onRollback) == "function" then
                callbacks[#callbacks + 1] = transaction.onRollback
            end
        end
    end

    return callbacks
end

function PanelTransactions:RunRollbackCallbacks(callbacks)
    if type(callbacks) ~= "table" then
        return
    end
    for i = 1, #callbacks do
        SafeCallback("Panel transaction onRollback", callbacks[i])
    end
end

function PanelTransactions:InvalidateAll()
    self._pendingByKey = {}
end

function PanelTransactions:UndoPanel(panelKey, applyKeys, callbacks)
    if not (Settings and type(OriginalUndoPanel) == "function") then
        return false
    end

    local keys = NormalizeKeys(applyKeys)
    if #keys == 0 or not (Apply and type(Apply.Request) == "function") then
        return OriginalUndoPanel(Settings, panelKey)
    end

    local undoSections = GetUndoSections(panelKey)
    if type(undoSections) ~= "table" then
        undoSections = GetPanelSections(panelKey, nil, true)
    end

    local sections = SnapshotSections(panelKey, undoSections, false)
    local history = SnapshotPanelHistory(panelKey)
    if type(sections) ~= "table" or type(history) ~= "table" then
        return false
    end

    if OriginalUndoPanel(Settings, panelKey) ~= true then
        return false
    end

    local transaction = {
        rollback = function()
            RestoreSections(sections)
            RestorePanelHistory(history)
        end,
        onRollback = type(callbacks) == "table" and callbacks.onRollback or nil,
        onCommit = type(callbacks) == "table" and callbacks.onCommit or nil,
    }

    if not self:Register(keys, transaction) then
        RestoreSections(sections)
        RestorePanelHistory(history)
        return false
    end

    return true
end

function PanelTransactions:ResetSections(panelKey, sections, applyKeys, callbacks)
    if not (Settings and type(Settings.ResetSections) == "function") then
        return false
    end

    local keys = NormalizeKeys(applyKeys)
    if #keys == 0 or not (Apply and type(Apply.Request) == "function") then
        return Settings:ResetSections(sections)
    end

    local sectionSnapshot = SnapshotSections(panelKey, sections, false)
    local historySnapshot = SnapshotPanelHistory(panelKey)
    if type(sectionSnapshot) ~= "table" or type(historySnapshot) ~= "table" then
        return false
    end

    if Settings:ResetSections(sections) ~= true then
        return false
    end

    local transaction = {
        rollback = function()
            RestoreSections(sectionSnapshot)
            RestorePanelHistory(historySnapshot)
        end,
        commit = function()
            if type(Settings.InvalidatePanelHistory) == "function" then
                Settings:InvalidatePanelHistory(panelKey)
            end
        end,
        onRollback = type(callbacks) == "table" and callbacks.onRollback or nil,
        onCommit = type(callbacks) == "table" and callbacks.onCommit or nil,
    }

    if not self:Register(keys, transaction) then
        RestoreSections(sectionSnapshot)
        RestorePanelHistory(historySnapshot)
        return false
    end

    return true
end

local function RefreshPanel(refreshFn)
    if type(refreshFn) == "function" then
        refreshFn()
    end
end

local function BindPanelApplyControls(applyState, undoBtn, resetBtn, resetSections, refreshFn, restoreApplyKeys)
    if type(OriginalBindPanelApplyControls) == "function" then
        OriginalBindPanelApplyControls(applyState, undoBtn, resetBtn, resetSections, refreshFn, restoreApplyKeys)
    end
    if type(applyState) ~= "table" then
        return
    end

    local keys = restoreApplyKeys or applyState.defaultApplyKeys
    local callbacks = {
        onRollback = function()
            RefreshPanel(refreshFn)
        end,
    }

    if undoBtn then
        undoBtn:SetScript("OnClick", function()
            if PanelTransactions:UndoPanel(applyState.panelKey, keys, callbacks) then
                applyState:ApplyNow(keys)
                RefreshPanel(refreshFn)
            end
        end)
    end

    if resetBtn then
        resetBtn:SetScript("OnClick", function()
            if PanelTransactions:ResetSections(applyState.panelKey, resetSections, keys, callbacks) then
                applyState.pending = false
                applyState:ApplyNow(keys)
                RefreshPanel(refreshFn)
            end
        end)
    end
end

if Shared and type(OriginalCreateBuilderContext) == "function" then
    function Shared.CreateBuilderContext(...)
        local context = OriginalCreateBuilderContext(...)
        if type(context) == "table" then
            context.BindPanelApplyControls = BindPanelApplyControls
        end
        return context
    end
    Shared.BindPanelApplyControls = BindPanelApplyControls
end

if Settings and type(OriginalInvalidateAllHistory) == "function" then
    function Settings:InvalidateAllHistory(...)
        PanelTransactions:InvalidateAll()
        return OriginalInvalidateAllHistory(self, ...)
    end
end

-- Keep the public direct-reset helper used by Edit Mode unchanged. Transactional
-- panel reset is installed through BindPanelApplyControls above.
if Shared and type(OriginalResetProfileSections) == "function" then
    Shared.ResetProfileSections = OriginalResetProfileSections
end

return PanelTransactions
