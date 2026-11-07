-- FeelsGoodUI: atomic profile-import coordinator
--
-- Decoding stays in ProfileTransfer. This owner stages normalization against a
-- detached profile, replaces the live profile through PanelTransactions, and
-- reports commit/rollback only after every runtime apply key reaches a terminal
-- result.

local _, ns = ...

local Import = {}
ns.ProfileImport = Import

local Apply = ns.Apply
local DB = ns.DB
local Log = ns.Log
local PanelTransactions = ns.PanelTransactions
local Schema = ns.Schema or {}
local Settings = ns.Settings

local FALLBACK_APPLY_ORDER = {
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

local function ErrorHandler(err)
    return tostring(err or "unknown profile import error")
end

local function CopyApplyOrder(order)
    local out, seen = {}, {}
    for i = 1, #(order or {}) do
        local key = order[i]
        if type(key) == "string" and key ~= "" and not seen[key] then
            seen[key] = true
            out[#out + 1] = key
        end
    end
    return out
end

local function GetApplyKeys()
    local app = ns.App
    local keys = {}
    if app and type(app.GetApplyOrder) == "function" then
        keys = CopyApplyOrder(app:GetApplyOrder())
    end

    local seen = {}
    for i = 1, #keys do seen[keys[i]] = true end
    for i = 1, #FALLBACK_APPLY_ORDER do
        local key = FALLBACK_APPLY_ORDER[i]
        if not seen[key] then
            seen[key] = true
            keys[#keys + 1] = key
        end
    end
    return keys
end

local function NormalizeSnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return false, "Imported profile snapshot is not a table"
    end
    for key in pairs(snapshot) do
        if type(key) ~= "string" then
            return false, "Imported profile contains an unsupported top-level key"
        end
    end
    if not (DB and type(DB.data) == "table") then
        return false, "Profile database is not initialized"
    end

    local data = DB.data
    local globalDB = _G.FeelsGoodUIDB
    local oldDataProfile = data.profile
    local oldGlobalProfile = type(globalDB) == "table" and globalDB.profile or nil

    data.profile = snapshot
    if type(globalDB) == "table" then
        globalDB.profile = snapshot
    end

    local ok, result = xpcall(function()
        if Settings and type(Settings.NormalizeAll) == "function" then
            local normalized, detail = Settings:NormalizeAll()
            if normalized == false then
                error(detail or "Settings.NormalizeAll returned false", 0)
            end
        end
        if type(Schema.NormalizeProfile) == "function" then
            local normalized = Schema.NormalizeProfile(snapshot, DB.defaults and DB.defaults.profile)
            if normalized == false then
                error("Schema.NormalizeProfile returned false", 0)
            end
        end
        return true
    end, ErrorHandler)

    data.profile = oldDataProfile
    if type(globalDB) == "table" then
        globalDB.profile = oldGlobalProfile
    end

    if not ok then
        return false, result
    end
    return true
end

local function SafeCallback(callback, ...)
    if type(callback) ~= "function" then
        return
    end
    local ok, err = pcall(callback, ...)
    if not ok and Log and type(Log.Error) == "function" then
        Log:Error("Profile import callback failed: " .. tostring(err))
    end
end

local function Finish(owner, state, status, message, callback)
    state.status = status
    state.message = message
    if owner._pending == state then
        owner._pending = nil
    end
    SafeCallback(callback, message)
end

local function RollbackStaged(checkpoint, keys)
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

function Import:IsPending()
    return type(self._pending) == "table" and self._pending.status == "pending"
end

function Import:Stage(snapshot, callbacks)
    callbacks = type(callbacks) == "table" and callbacks or {}
    if self:IsPending() then
        return false, "Another profile import is still pending"
    end
    if not (PanelTransactions
        and type(PanelTransactions.HasPending) == "function"
        and type(PanelTransactions.Checkpoint) == "function"
        and type(PanelTransactions.ReplaceProfile) == "function"
        and type(PanelTransactions.RollbackAfter) == "function") then
        return false, "Profile transaction owner is unavailable"
    end
    if not (Apply and type(Apply.Request) == "function") then
        return false, "Apply queue is unavailable"
    end
    if PanelTransactions:HasPending() then
        return false, "Finish pending settings changes before importing a profile"
    end

    local normalized, normalizeError = NormalizeSnapshot(snapshot)
    if not normalized then
        return false, normalizeError
    end

    local keys = GetApplyKeys()
    local checkpoint = PanelTransactions:Checkpoint()

    local state = { status = "pending" }
    self._pending = state

    local replaceCallOK, replaced, replaceError = xpcall(function()
        return PanelTransactions:ReplaceProfile(snapshot, keys, {
            onCommit = function()
                Finish(
                    self,
                    state,
                    "committed",
                    "Profile imported and applied.",
                    callbacks.onCommit
                )
            end,
            onRollback = function()
                Finish(
                    self,
                    state,
                    "rolled_back",
                    "Profile import failed during runtime apply. Previous profile restored.",
                    callbacks.onRollback
                )
            end,
        })
    end, ErrorHandler)
    if not replaceCallOK or replaced ~= true then
        RollbackStaged(checkpoint, keys)
        self._pending = nil
        return false, (not replaceCallOK and replaced)
            or replaceError
            or "Profile replacement transaction failed"
    end

    local requested, requestError = xpcall(function()
        local result, detail = Apply:Request(keys)
        if result == false then
            error(detail or "Apply.Request returned false", 0)
        end
    end, ErrorHandler)
    if not requested then
        RollbackStaged(checkpoint, keys)
        if state.status == "pending" then
            Finish(
                self,
                state,
                "rolled_back",
                "Profile import could not be queued. Previous profile restored.",
                callbacks.onRollback
            )
        end
        return false, requestError
    end

    if state.status == "committed" then
        return true, state.message
    end
    if state.status == "rolled_back" then
        return false, state.message
    end
    return true, "Profile import queued; changes commit after runtime validation."
end

return Import
