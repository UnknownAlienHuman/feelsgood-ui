-- FeelsGoodUI: transactional owner for mover geometry settings
--
-- Preview hooks mutate runtime frames only. Persisted values are produced by
-- pure write builders and committed once through Settings/Apply.

local _, ns = ...

local Transactions = {}
ns.MoversTransactions = Transactions

local Apply = ns.Apply
local DB = ns.DB
local Log = ns.Log
local Settings = ns.Settings
local U = ns.U

local PANEL_KEY = "editmode"

local OPERATIONS = {
    scale = { builder = "buildScaleWrites", preview = "previewScale" },
    size = { builder = "buildSizeWrites", preview = "previewSize" },
    wheel = { builder = "buildWheelWrites", preview = "previewWheel" },
}

local function ErrorHandler(err)
    return tostring(err or "unknown mover transaction error")
end

local function NormalizeWrites(value)
    if type(value) ~= "table" then
        return {}
    end
    if type(value.path) == "table" then
        return { value }
    end

    local writes = {}
    for i = 1, #value do
        local write = value[i]
        if type(write) == "table" and type(write.path) == "table" and #write.path > 0 then
            writes[#writes + 1] = write
        end
    end
    return writes
end

local function NormalizeApplyKeys(value)
    local keys, seen = {}, {}

    local function Add(key)
        if type(key) == "string" and key ~= "" and not seen[key] then
            seen[key] = true
            keys[#keys + 1] = key
        end
    end

    if type(value) == "string" then
        Add(value)
    elseif type(value) == "table" then
        for i = 1, #value do
            Add(value[i])
        end
    end

    return keys
end

local function HasApplyKeys(value)
    return #NormalizeApplyKeys(value) > 0
end

local function MergeApplyKeys(...)
    local merged, seen = {}, {}
    local function Add(value)
        if type(value) == "string" then
            if value ~= "" and not seen[value] then
                seen[value] = true
                merged[#merged + 1] = value
            end
        elseif type(value) == "table" then
            for i = 1, #value do Add(value[i]) end
        end
    end
    for i = 1, select("#", ...) do Add(select(i, ...)) end
    return merged
end

local function Copy(value, seen)
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
    if type(path) ~= "table" or #path == 0 then return nil end
    local out = {}
    for i = 1, #path do out[i] = path[i] end
    return out
end

local function Profile()
    local profile = DB and type(DB.EnsureProfileRoot) == "function" and DB:EnsureProfileRoot() or nil
    if type(profile) ~= "table" and DB and type(DB.GetProfile) == "function" then
        profile = DB:GetProfile()
    end
    return type(profile) == "table" and profile or nil
end

local function SnapshotPath(path, expected)
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
                stop = i,
                existed = false,
                expected = expected,
            }
        end
        if type(child) ~= "table" then
            return {
                path = copiedPath,
                stop = i,
                existed = true,
                value = Copy(child),
                expected = expected,
            }
        end
        node = child
    end

    if type(node) ~= "table" then return nil end
    local key = copiedPath[#copiedPath]
    return {
        path = copiedPath,
        stop = #copiedPath,
        existed = node[key] ~= nil,
        value = Copy(node[key]),
        expected = expected,
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

local function OwnsExpected(snapshot)
    if type(snapshot) ~= "table" then return false end
    local exists, current = ReadPath(snapshot.path)
    if snapshot.expected == nil then
        return not exists
    end
    return exists and DeepEqual(current, snapshot.expected)
end

local function RestorePath(snapshot)
    local profile = Profile()
    if not profile or not OwnsExpected(snapshot) then return false end

    local path = snapshot.path
    local stop = snapshot.stop or #path
    local node = profile
    for i = 1, stop - 1 do
        local key = path[i]
        if type(node[key]) ~= "table" then node[key] = {} end
        node = node[key]
    end
    node[path[stop]] = snapshot.existed and Copy(snapshot.value) or nil
    return true
end

local function CaptureWriteSnapshots(writes)
    if not Profile() then return nil end
    local snapshots = {}
    for i = 1, #writes do
        local write = writes[i]
        local expected = write.value
        if write.rule and Settings and type(Settings.Validate) == "function" then
            expected = Settings:Validate(write.value, write.rule)
        end
        local snapshot = SnapshotPath(write.path, expected)
        if snapshot then snapshots[#snapshots + 1] = snapshot end
    end
    return snapshots
end

local function RestoreWriteSnapshots(snapshots)
    local changed = false
    for i = #(snapshots or {}), 1, -1 do
        changed = RestorePath(snapshots[i]) or changed
    end
    return changed
end

local function LogError(message)
    if Log and type(Log.Error) == "function" then
        Log:Error(tostring(message))
    end
end

local function RestorePreview(applyKeys)
    if Apply and type(Apply.Request) == "function" and HasApplyKeys(applyKeys) then
        Apply:Request(applyKeys)
        return true
    end
    return false
end

local function CaptureUndoBatch(panelKey)
    local batches = Settings and Settings._undoPanelBatches
    local batch = type(batches) == "table" and batches[panelKey] or nil
    local panels = Settings and Settings._undoPanels
    local stack = type(panels) == "table" and panels[panelKey] or nil
    return {
        panelKey = panelKey,
        batch = batch,
        depth = type(batch) == "table" and (tonumber(batch.depth) or 0) or 0,
        changeLength = type(batch) == "table" and type(batch.changes) == "table" and #batch.changes or 0,
        stack = stack,
        stackLength = type(stack) == "table" and #stack or 0,
    }
end

local function RestoreUndoBatch(checkpoint)
    if type(checkpoint) ~= "table" or not Settings then return end
    Settings._undoPanelBatches = type(Settings._undoPanelBatches) == "table" and Settings._undoPanelBatches or {}
    Settings._undoPanels = type(Settings._undoPanels) == "table" and Settings._undoPanels or {}

    local panelKey = checkpoint.panelKey
    local batch = checkpoint.batch
    if type(batch) ~= "table" then
        Settings._undoPanelBatches[panelKey] = nil
    else
        Settings._undoPanelBatches[panelKey] = batch
        batch.depth = checkpoint.depth
        batch.changes = type(batch.changes) == "table" and batch.changes or {}
        while #batch.changes > checkpoint.changeLength do
            table.remove(batch.changes)
        end
    end

    local stack = checkpoint.stack
    if type(stack) == "table" then
        Settings._undoPanels[panelKey] = stack
        while #stack > checkpoint.stackLength do
            table.remove(stack)
        end
    else
        local current = Settings._undoPanels[panelKey]
        if type(current) == "table" then
            while #current > checkpoint.stackLength do
                table.remove(current)
            end
            if #current == 0 then Settings._undoPanels[panelKey] = nil end
        else
            Settings._undoPanels[panelKey] = nil
        end
    end
end

local function CapturePendingCheckpoint(applyKeys)
    local checkpoint = {}
    local pending = Settings and Settings._pending
    for _, key in ipairs(NormalizeApplyKeys(applyKeys)) do
        local list = type(pending) == "table" and pending[key] or nil
        checkpoint[key] = type(list) == "table" and #list or 0
    end
    return checkpoint
end

local function TrimPendingAfter(checkpoint)
    local pending = Settings and Settings._pending
    if type(pending) ~= "table" or type(checkpoint) ~= "table" then
        return
    end

    for key, length in pairs(checkpoint) do
        local list = pending[key]
        if type(list) == "table" then
            while #list > length do
                table.remove(list)
            end
            if #list == 0 then
                pending[key] = nil
            end
        end
    end
end

local function RollbackPartialWrites(applyKeys, journalCheckpoint, pendingCheckpoint)
    local keys = NormalizeApplyKeys(applyKeys)
    local journal = ns.PanelTransactions
    local callbacks, restoreKeys
    local journalHandled = false

    if journal and type(journal.RollbackAfter) == "function" then
        callbacks, restoreKeys = journal:RollbackAfter(journalCheckpoint, keys)
        journalHandled = true
    end

    if journalHandled then
        TrimPendingAfter(pendingCheckpoint)
    elseif Settings and type(Settings.Rollback) == "function" then
        for i = 1, #keys do
            Settings:Rollback(keys[i])
        end
    end

    if journal and type(journal.RunRollbackCallbacks) == "function" then
        journal:RunRollbackCallbacks(callbacks)
    end

    if type(restoreKeys) == "table" and #restoreKeys > 0
        and Apply and type(Apply.Request) == "function" then
        Apply:Request(restoreKeys)
    end
end

function Transactions:Preview(spec, frame, operation, ...)
    local contract = OPERATIONS[operation]
    if type(spec) ~= "table" or not contract then
        return false, "Invalid mover preview contract"
    end

    local preview = spec[contract.preview]
    if type(preview) == "function" then
        local firstArg, secondArg = ...
        local ok, first, second = xpcall(function()
            return preview(frame, firstArg, secondArg)
        end, ErrorHandler)
        if not ok then
            return false, first
        end
        if first == false then
            return false, second or ("Mover " .. operation .. " preview returned false")
        end
        return true, first, second
    end

    if operation == "scale" and frame and type(frame.SetScale) == "function" then
        local value = tonumber((...))
        if type(value) ~= "number" then
            return false, "Mover scale preview requires a number"
        end
        frame:SetScale(value)
        return true, value
    end

    if operation == "size" and frame and type(frame.SetSize) == "function" then
        local width, height = ...
        width = tonumber(width)
        height = tonumber(height)
        if type(width) ~= "number" or type(height) ~= "number" then
            return false, "Mover size preview requires width and height"
        end
        frame:SetSize(width, height)
        return true, width, height
    end

    return false, "Missing mover " .. tostring(operation) .. " preview"
end

function Transactions:CommitWrites(applyKeys, writes, panelKey)
    if not HasApplyKeys(applyKeys) then
        return false, "Mover transaction has no apply key"
    end
    if not (Settings and type(Settings.SetTx) == "function") then
        RestorePreview(applyKeys)
        return false, "Settings.SetTx unavailable"
    end
    if not (Apply and type(Apply.Request) == "function") then
        return false, "Apply.Request unavailable"
    end

    writes = NormalizeWrites(writes)
    if #writes == 0 then
        RestorePreview(applyKeys)
        return false, "Mover transaction produced no writes"
    end

    local okSnapshots, writeSnapshots = xpcall(function()
        return CaptureWriteSnapshots(writes)
    end, ErrorHandler)
    if not okSnapshots then
        RestorePreview(applyKeys)
        LogError("Mover transaction snapshot failed: " .. tostring(writeSnapshots))
        return false, writeSnapshots
    end

    local journal = ns.PanelTransactions
    local journalCheckpoint = journal and type(journal.Checkpoint) == "function"
        and journal:Checkpoint()
        or nil
    local pendingCheckpoint = CapturePendingCheckpoint(applyKeys)
    panelKey = (type(panelKey) == "string" and panelKey ~= "") and panelKey or PANEL_KEY
    local undoCheckpoint = CaptureUndoBatch(panelKey)
    local beganBatch = false
    if type(Settings.BeginPanelUndoBatch) == "function" then
        local okBegin, beginResult = xpcall(function()
            return Settings:BeginPanelUndoBatch(panelKey) == true
        end, ErrorHandler)
        if not okBegin or beginResult ~= true then
            local detail = okBegin and "Settings.BeginPanelUndoBatch returned false" or beginResult
            RestoreUndoBatch(undoCheckpoint)
            RestorePreview(applyKeys)
            LogError("Mover transaction batch begin failed: " .. tostring(detail))
            return false, detail
        end
        beganBatch = true
    end
    local changed = false

    local okWrite, writeError = xpcall(function()
        for i = 1, #writes do
            local write = writes[i]
            local didChange = Settings:SetTx(
                applyKeys,
                write.path,
                write.value,
                write.rule,
                panelKey
            )
            changed = didChange == true or changed
        end
    end, ErrorHandler)

    if beganBatch and type(Settings.EndPanelUndoBatch) == "function" then
        local okEnd, endError = xpcall(function()
            Settings:EndPanelUndoBatch(panelKey)
        end, ErrorHandler)
        if not okEnd and okWrite then
            okWrite = false
            writeError = endError
        end
    end

    if not okWrite then
        RollbackPartialWrites(applyKeys, journalCheckpoint, pendingCheckpoint)
        RestoreWriteSnapshots(writeSnapshots)
        RestoreUndoBatch(undoCheckpoint)
        RestorePreview(applyKeys)
        LogError("Mover transaction failed: " .. tostring(writeError))
        return false, writeError
    end

    if changed then
        Apply:Request(applyKeys)
    end
    return changed
end

function Transactions:MergeApplyKeys(...)
    return MergeApplyKeys(...)
end

function Transactions:Restore(applyKeys)
    return RestorePreview(applyKeys)
end

function Transactions:BuildWrites(spec, operation, ...)
    local contract = OPERATIONS[operation]
    if type(spec) ~= "table" or not contract then
        return nil, "Invalid mover transaction contract"
    end

    local builder = spec[contract.builder]
    if type(builder) ~= "function" then
        return nil, "Missing mover " .. tostring(operation) .. " write builder"
    end

    local firstArg, secondArg = ...
    local okBuild, built = xpcall(function()
        return builder(firstArg, secondArg)
    end, ErrorHandler)
    if not okBuild then
        return nil, built
    end

    local writes = NormalizeWrites(built)
    if #writes == 0 then
        return nil, "Mover transaction produced no writes"
    end
    return writes
end

function Transactions:Commit(spec, operation, ...)
    local writes, detail = self:BuildWrites(spec, operation, ...)
    if not writes then
        RestorePreview(type(spec) == "table" and spec.applyKeys or nil)
        if detail then LogError("Mover " .. tostring(operation) .. " write build failed: " .. tostring(detail)) end
        return false, detail
    end

    return self:CommitWrites(spec.applyKeys, writes, spec.panelKey)
end

return Transactions
