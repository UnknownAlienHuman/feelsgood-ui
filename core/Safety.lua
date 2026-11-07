-- FeelsGoodUI: Safety helpers
-- Goals:
--  - prevent single handler crash from killing addon
--  - debounce/coalesce repeated passes (actionbar hide kicks, relayout)
--  - avoid wrapping FAST events by default for perf

local _, ns = ...

local Safety = {}
ns.Safety = Safety

local Log = ns.Log
local Errors = ns.Errors
local DB = ns.DB

local xpcall = xpcall
local tostring = tostring
local type = type

local FAST_EVENTS = {
    UNIT_POWER_FREQUENT = true,
    UNIT_POWER_UPDATE   = true,
    UNIT_AURA           = true,
    RUNE_POWER_UPDATE   = true,
}

local function GetStack()
    if type(debugstack) == "function" then
        return debugstack(3, 15, 15)
    end
    return ""
end

local function WantSafe(event)
    local safe = true
    local safeFast = false

    if DB and DB.ReadSection then
        local general = DB:ReadSection("general")
        if type(general) == "table" then
            if general.safeHandlers ~= nil then safe = (general.safeHandlers == true) end
            if general.safeHandlersFast ~= nil then safeFast = (general.safeHandlersFast == true) end
        end
    end

    if not safe then return false end
    if FAST_EVENTS[event] and not safeFast then return false end
    return true
end

function Safety.Dispatch(addon, event, handler, ...)
    if not handler then return end

    if not WantSafe(event) then
        handler(addon, ...)
        return
    end

    -- IMPORTANT (Lua vararg): nested closures cannot access "..." directly.
    -- Capture args once (only on the safe-path) to avoid syntax/runtime issues.
    local argc = select("#", ...)
    local args
    if argc > 0 then
        args = { ... }
    end
    local unpack = (table and table.unpack) or unpack

    local ok, errMsg = xpcall(function()
        if argc == 0 then
            handler(addon)
        else
            handler(addon, unpack(args, 1, argc))
        end
    end, function(err)
        return tostring(err or "unknown error")
    end)

    if ok then return end

    local stack = GetStack()
    if Errors and Errors.Capture then
        Errors:Capture(event, errMsg, stack)
    end
    if Log and Log.Error then
        Log:Error(("Error in %s: %s"):format(tostring(event), tostring(errMsg)))
    end
end

-- Coalescing debounce (keyed). Generations make cancellation reliable even on
-- clients where only C_Timer.After is available and no timer handle exists.
Safety._timers = Safety._timers or {}
Safety._timerGenerations = Safety._timerGenerations or {}

local function NextTimerGeneration(key)
    local generations = Safety._timerGenerations
    local generation = (generations[key] or 0) + 1
    generations[key] = generation
    return generation
end

function Safety.IsDebouncePending(key)
    return key ~= nil and Safety._timers[key] ~= nil
end

function Safety.CancelDebounce(key)
    if not key then return false end

    local timers = Safety._timers
    local pending = timers[key]
    timers[key] = nil
    NextTimerGeneration(key)

    local pendingType = type(pending)
    if pendingType == "table" or pendingType == "userdata" then
        local okMethod, cancel = pcall(function()
            return pending.Cancel
        end)
        if okMethod and type(cancel) == "function" then
            pcall(cancel, pending)
        end
    end

    return pending ~= nil
end

-- Returns true when the request was scheduled OR coalesced into an existing
-- request. False means the arguments/timer backend are unavailable and callers
-- may execute their synchronous fallback.
function Safety.Debounce(key, delay, fn)
    if not key or type(fn) ~= "function" then return false end
    delay = tonumber(delay) or 0

    local timers = Safety._timers
    if timers[key] then return true end

    local generation = NextTimerGeneration(key)
    local function Run()
        if Safety._timerGenerations[key] ~= generation then
            return
        end
        timers[key] = nil
        Safety.Guard(key, fn)
    end

    if C_Timer and C_Timer.NewTimer then
        timers[key] = C_Timer.NewTimer(delay, Run)
        return true
    end

    if C_Timer and C_Timer.After then
        timers[key] = true
        C_Timer.After(delay, Run)
        return true
    end

    return false
end

function Safety.Guard(src, fn)
    local ok, err = pcall(fn)
    if ok then return true end
    if Errors and Errors.Capture then
        Errors:Capture(src or "guard", tostring(err), GetStack())
    end
    if Log and Log.Warn then
        Log:Warn(("Guard failed: %s"):format(tostring(src)))
    end
    return false
end
