-- FeelsGoodUI: Apply queue (dirty flags + debounced module refresh)
--
-- Stage 39: Foundation refactor
-- Goal: avoid "apply everything" on every slider tick.
--
-- Design:
--  - Modules request apply via ns.Apply:Request("unitframes") etc.
--  - Applies are debounced (coalesced) and executed in a stable order.
--  - Secure/protected code paths are handled inside modules (they defer in combat).
--
-- Author: Neomorph

local _, ns = ...

local Apply = {}
ns.Apply = Apply

local DB = ns.DB
local Safety = ns.Safety
local Log = ns.Log
local Settings = ns.Settings
local Perf = ns.Perf

local DEBOUNCE_KEY = "FGUI_APPLY_QUEUE"

local FALLBACK_ORDER = {
    "runtime",
    "theme",
    "unitframes",
    "center",
    "experience",
    "actionbars",
    "companion",
    "minimap",
}

Apply._dirty = Apply._dirty or {}
Apply._scheduled = false

local function GetApplyOrder()
    local app = ns.App
    if app and app.GetApplyOrder then
        local order = app:GetApplyOrder()
        if type(order) == "table" and #order > 0 then
            return order
        end
    end
    return FALLBACK_ORDER
end

local function BuildOrderedKeys(snapshot)
    local out, seen = {}, {}

    for _, key in ipairs(GetApplyOrder()) do
        if snapshot[key] and not seen[key] then
            seen[key] = true
            out[#out + 1] = key
        end
    end

    local extras = {}
    for key, value in pairs(snapshot) do
        if value == true and type(key) == "string" and key ~= "" and not seen[key] then
            extras[#extras + 1] = key
        end
    end
    table.sort(extras)

    for i = 1, #extras do
        out[#out + 1] = extras[i]
    end

    return out
end

local function _ErrHandler(err)
    local s = tostring(err)
    if _G and _G.debugstack then
        s = s .. "\n" .. _G.debugstack(2, 30, 30)
    end
    return s
end

local function NowMS()
    if Perf and Perf.NowMS then
        return Perf:NowMS()
    end
    if _G and _G.debugprofilestop then
        return _G.debugprofilestop()
    end
    if _G and _G.GetTime then
        return _G.GetTime() * 1000
    end
    return 0
end

local function SafeApplyKey(key, fn)
    local perfOn = (Perf and Perf.IsEnabled and Perf:IsEnabled()) == true
    local t0 = perfOn and NowMS() or nil

    if type(fn) ~= "function" then
        return false, "Missing apply callback: " .. tostring(key)
    end

    local function Run()
        if Settings and Settings.Normalize then
            local normalized, detail = Settings:Normalize(key)
            if normalized == false then
                return false, detail or ("Settings normalization returned false: " .. tostring(key))
            end
        end
        return fn()
    end

    local ok, result, detail = xpcall(Run, _ErrHandler)
    if perfOn and t0 then
        Perf:Time(key, NowMS() - t0)
        Perf:Inc("Apply:" .. tostring(key))
    end

    if not ok then
        return false, result
    end
    if result == false then
        return false, detail or ("Apply returned false: " .. tostring(key))
    end
    return true
end

local function FinalizePending(keys, method)
    if type(keys) ~= "table" or #keys == 0 then
        return nil
    end

    local transactions = ns.PanelTransactions
    if method == "Rollback"
        and transactions
        and type(transactions.RollbackKeys) == "function" then
        -- PanelTransactions journals both scalar SetTx writes and higher-level
        -- undo/reset snapshots in one sequence. Clear Settings' legacy pending
        -- lists without replaying a second, differently ordered rollback.
        local callbacks, committedKeys = transactions:RollbackKeys(keys)
        if Settings and type(Settings.Commit) == "function" then
            for i = 1, #keys do
                Settings:Commit(keys[i])
            end
        end
        if type(transactions.RunRollbackCallbacks) == "function" then
            transactions:RunRollbackCallbacks(callbacks)
        end
        return committedKeys
    end

    if Settings and type(Settings[method]) == "function" then
        for i = 1, #keys do
            local key = keys[i]
            if type(key) == "string" and key ~= "" then
                Settings[method](Settings, key)
            end
        end
    end

    if method == "Commit"
        and transactions
        and type(transactions.CommitKeys) == "function" then
        transactions:CommitKeys(keys)
    end
    return nil
end

local function CallFallback(object, method, key)
    if not (object and type(object[method]) == "function") then
        return false, "Missing fallback apply handler: " .. tostring(key)
    end

    local result, detail = object[method](object)
    if result == false then
        return false, detail or ("Fallback apply returned false: " .. tostring(key))
    end
    return true
end

local function ExecuteApplyKey(key)
    local currentApp = ns.App
    if currentApp and currentApp.ApplyByKey then
        return currentApp:ApplyByKey(key)
    end

    if key == "runtime" then
        return CallFallback(DB, "ApplyRuntime", key)
    elseif key == "theme" then
        return CallFallback(ns.Theme, "RefreshFromDB", key)
    elseif key == "unitframes" then
        return CallFallback(ns.UF, "ApplyConfig", key)
    elseif key == "center" then
        return CallFallback(ns.Center, "ApplyConfig", key)
    elseif key == "experience" then
        return CallFallback(ns.ExperienceBar, "ApplyConfig", key)
    elseif key == "actionbars" then
        return CallFallback(ns.ActionBars, "ApplyConfig", key)
    elseif key == "companion" then
        return CallFallback(ns.Companion, "ApplyConfig", key)
    elseif key == "minimap" then
        return CallFallback(ns.MinimapIcon, "ApplyConfig", key)
    end

    return false, "Unknown apply key: " .. tostring(key)
end

local function RestoreRuntimeKeys(keys)
    if type(keys) ~= "table" or #keys == 0 then
        return
    end

    for i = 1, #keys do
        local key = keys[i]
        local ok, err = SafeApplyKey(key, function()
            return ExecuteApplyKey(key)
        end)
        if not ok and Log and Log.Error then
            Log:Error("Apply restore failed [" .. tostring(key) .. "]: " .. tostring(err))
        end
    end
end

local function MarkDirty(key)
    if type(key) == "string" and key ~= "" then
        Apply._dirty[key] = true
    end
end

function Apply:Request(keys)
    if (Perf and Perf.IsEnabled and Perf:IsEnabled()) == true then
        Perf:Inc("ApplyRequest")
    end
    if type(keys) == "string" then
        MarkDirty(keys)
    elseif type(keys) == "table" then
        for _, key in ipairs(keys) do
            MarkDirty(key)
        end
    else
        return
    end

    self:Schedule()
end

function Apply:RequestAll()
    if (Perf and Perf.IsEnabled and Perf:IsEnabled()) == true then
        Perf:Inc("ApplyRequest")
    end
    for _, key in ipairs(GetApplyOrder()) do
        self._dirty[key] = true
    end
    self:Schedule()
end

function Apply:Schedule()
    if self._scheduled then return end
    self._scheduled = true

    local function Run()
        Apply._scheduled = false
        Apply:Flush()
    end

    if Safety and Safety.Debounce and Safety.Debounce(DEBOUNCE_KEY, 0.05, Run) then
        return
    end

    Run()
end

function Apply:Flush()
    if (Perf and Perf.IsEnabled and Perf:IsEnabled()) == true then
        Perf:Inc("ApplyFlush")
    end
    local dirty = self._dirty
    if not dirty then return end

    -- Snapshot + clear first (re-entrant safe).
    local snapshot = {}
    for key, value in pairs(dirty) do
        if value == true then snapshot[key] = true end
        dirty[key] = nil
    end

    local batchKeys = BuildOrderedKeys(snapshot)
    local app = ns.App

    -- Defer the protected subset but retain the original batch key set. If any
    -- executable key fails, pending changes for the complete logical batch roll
    -- back, including keys that were waiting for combat to end.
    local inCombat = (InCombatLockdown and InCombatLockdown()) == true
    if inCombat then
        for i = 1, #batchKeys do
            local key = batchKeys[i]
            if snapshot[key]
                and app
                and app.ShouldDeferApplyInCombat
                and app:ShouldDeferApplyInCombat(key) then
                dirty[key] = true
                snapshot[key] = nil
                self._needsCombatEnd = true
            end
        end
    end

    local orderedKeys = {}
    for i = 1, #batchKeys do
        local key = batchKeys[i]
        if snapshot[key] then
            orderedKeys[#orderedKeys + 1] = key
        end
    end

    local appliedKeys = {}
    local failedKey = nil
    local failedErr = nil

    for i = 1, #orderedKeys do
        local key = orderedKeys[i]
        local ok, err = SafeApplyKey(key, function()
            return ExecuteApplyKey(key)
        end)

        if not ok then
            failedKey = key
            failedErr = err
            break
        end

        appliedKeys[#appliedKeys + 1] = key
    end

    if not failedKey then
        FinalizePending(orderedKeys, "Commit")
        return
    end

    local previouslyCommittedKeys = FinalizePending(batchKeys, "Rollback")

    local restoreSet = {}
    for i = 1, #appliedKeys do restoreSet[appliedKeys[i]] = true end
    restoreSet[failedKey] = true
    for i = 1, #(previouslyCommittedKeys or {}) do
        restoreSet[previouslyCommittedKeys[i]] = true
    end
    RestoreRuntimeKeys(BuildOrderedKeys(restoreSet))

    if Log and Log.Error then
        Log:Error("Apply batch failed [" .. tostring(failedKey) .. "]: " .. tostring(failedErr))
    end
end

-- Called from the addon's PLAYER_REGEN_ENABLED handler.
function Apply:OnCombatEnd()
    if self._needsCombatEnd ~= true then return end
    self._needsCombatEnd = false

    if self._scheduled then return end
    self:Schedule()
end

function ns.ApplyAll()
    if ns.Apply and ns.Apply.RequestAll then
        ns.Apply:RequestAll()
    end
end
