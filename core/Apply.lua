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

local DB     = ns.DB
local Safety = ns.Safety
local Log    = ns.Log
local Settings = ns.Settings

local Perf   = ns.Perf

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
    if Settings and Settings.Normalize then
        Settings:Normalize(key)
    end

    if type(fn) ~= "function" then
        return true
    end

    local ok, err = xpcall(fn, _ErrHandler)
    if perfOn and t0 then
        Perf:Time(key, NowMS() - t0)
        Perf:Inc("Apply:" .. tostring(key))
    end
    return ok, err
end

local function FinalizePending(keys, method)
    if type(keys) ~= "table" or not Settings or type(Settings[method]) ~= "function" then
        return
    end

    for i = 1, #keys do
        local key = keys[i]
        if type(key) == "string" and key ~= "" then
            Settings[method](Settings, key)
        end
    end
end

local function ExecuteApplyKey(key)
    local currentApp = ns.App
    if currentApp and currentApp.ApplyByKey then
        currentApp:ApplyByKey(key)
        return
    end

    if key == "runtime" and DB and DB.ApplyRuntime then
        DB:ApplyRuntime()
    elseif key == "theme" and ns.Theme and ns.Theme.RefreshFromDB then
        ns.Theme:RefreshFromDB()
    elseif key == "unitframes" and ns.UF and ns.UF.ApplyConfig then
        ns.UF:ApplyConfig()
    elseif key == "center" and ns.Center and ns.Center.ApplyConfig then
        ns.Center:ApplyConfig()
    elseif key == "experience" and ns.ExperienceBar and ns.ExperienceBar.ApplyConfig then
        ns.ExperienceBar:ApplyConfig()
    elseif key == "actionbars" and ns.ActionBars and ns.ActionBars.ApplyConfig then
        ns.ActionBars:ApplyConfig()
    elseif key == "companion" and ns.Companion and ns.Companion.ApplyConfig then
        ns.Companion:ApplyConfig()
    elseif key == "minimap" and ns.MinimapIcon and ns.MinimapIcon.ApplyConfig then
        ns.MinimapIcon:ApplyConfig()
    end
end

local function RestoreRuntimeKeys(keys)
    if type(keys) ~= "table" or #keys == 0 then
        return
    end

    for i = 1, #keys do
        local key = keys[i]
        local ok, err = SafeApplyKey(key, function()
            ExecuteApplyKey(key)
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
        for _, k in ipairs(keys) do
            MarkDirty(k)
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
    for _, k in ipairs(GetApplyOrder()) do
        self._dirty[k] = true
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

    -- Fallback: immediate flush.
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
    for k, v in pairs(dirty) do
        if v == true then snapshot[k] = true end
        dirty[k] = nil
    end

    local app = ns.App

    -- Avoid calling potentially protected/taint-prone apply paths while in combat.
    -- Modules should still defend themselves, but the queue adds a second layer.
    local inCombat = (InCombatLockdown and InCombatLockdown()) == true
    if inCombat then
        for _, key in ipairs(GetApplyOrder()) do
            if snapshot[key] and app and app.ShouldDeferApplyInCombat and app:ShouldDeferApplyInCombat(key) then
                dirty[key] = true
                snapshot[key] = nil
                self._needsCombatEnd = true
            end
        end
    end

    -- One flush snapshot is treated as a single transactional batch.
    local orderedKeys = {}
    for _, key in ipairs(GetApplyOrder()) do
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
            ExecuteApplyKey(key)
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

    FinalizePending(orderedKeys, "Rollback")

    local restoreKeys = {}
    for i = 1, #appliedKeys do
        restoreKeys[#restoreKeys + 1] = appliedKeys[i]
    end
    restoreKeys[#restoreKeys + 1] = failedKey
    RestoreRuntimeKeys(restoreKeys)

    if Log and Log.Error then
        Log:Error("Apply batch failed [" .. tostring(failedKey) .. "]: " .. tostring(failedErr))
    end
end

-- Called from the addon's PLAYER_REGEN_ENABLED handler.
function Apply:OnCombatEnd()
    if self._needsCombatEnd ~= true then return end
    self._needsCombatEnd = false

    -- If anything was re-dirtied during combat, flush once now.
    if self._scheduled then return end
    self:Schedule()
end

-- Back-compat: many places call ns.ApplyAll().
function ns.ApplyAll()
    if ns.Apply and ns.Apply.RequestAll then
        ns.Apply:RequestAll()
    end
end
