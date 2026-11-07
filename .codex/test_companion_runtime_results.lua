local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertContains(value, needle, label)
    value = tostring(value or "")
    if not value:find(needle, 1, true) then
        error((label or "value") .. ": expected to contain '" .. needle .. "', got '" .. value .. "'", 2)
    end
end

_G = _G or {}
_G.oUF = {}

local inCombat = false
local errors = {}
local debounceCallback
local hookOK, hookDetail = true, nil
local petOK, petDetail = true, nil
local microOK, microDetail = true, nil
local hookCalls = 0
local petApplyCalls = 0
local microApplyCalls = 0
local petRestoreCalls = 0
local microRestoreCalls = 0
local countUpdateCalls = 0

local shared = {
    APPLY_DEBOUNCE_KEY = "TEST_COMPANION_APPLY",
    MICRO_LAYOUT_RETRY_KEY = "TEST_MICRO_RETRY",
    IsInCombat = function() return inCombat end,
    GetCompanionCfg = function()
        return {
            buttonSize = 32,
            spacing = 0,
            microMenu = { enabled = true },
            bags = { enabled = true, compact = true },
            petBar = { showHotkeys = false, strata = "LOW", level = 35 },
        }
    end,
}

local petBar = {
    Apply = function()
        petApplyCalls = petApplyCalls + 1
        return petOK, petDetail
    end,
    RestoreDefaultLayout = function()
        petRestoreCalls = petRestoreCalls + 1
        return true
    end,
}

local microBags = {
    EnsureHooks = function()
        hookCalls = hookCalls + 1
        return hookOK, hookDetail
    end,
    Apply = function()
        microApplyCalls = microApplyCalls + 1
        return microOK, microDetail
    end,
    RestoreDefaultLayout = function()
        microRestoreCalls = microRestoreCalls + 1
        return true
    end,
    UpdateCompactBagCountText = function()
        countUpdateCalls = countUpdateCalls + 1
    end,
    HandleBagUpdate = function() return false end,
    HandleExpandChanged = function() end,
}

local safety = {
    CancelDebounce = function() end,
    Debounce = function(_, _, callback)
        debounceCallback = callback
        return true
    end,
}

local ns = {
    CompanionShared = shared,
    CompanionPetBar = petBar,
    CompanionMicroBags = microBags,
    Safety = safety,
    Log = {
        Warn = function() end,
        Error = function(_, message) errors[#errors + 1] = message end,
    },
}

assert(loadfile("modules/CompanionRuntime.lua"))("FeelsGoodUI", ns)
local Runtime = assert(ns.CompanionRuntime)
local module = {}
ns.Companion = module

hookOK = false
hookDetail = "hook failure"
local initialized, initDetail = Runtime.Init(module)
assertEqual(initialized, false, "hook failure rejects init")
assertEqual(initDetail, "hook failure", "hook failure detail")
assertEqual(module._initDone, nil, "failed init is not published")
assertEqual(hookCalls, 1, "failed hook called once")

hookOK = true
hookDetail = nil
initialized, initDetail = Runtime.Init(module)
assertEqual(initialized, true, "successful init")
assertEqual(initDetail, nil, "successful init detail")
assertEqual(module._initDone, true, "successful init published")
assertEqual(hookCalls, 2, "successful hook retry")

initialized = Runtime.Init(module)
assertEqual(initialized, true, "repeat init succeeds")
assertEqual(hookCalls, 2, "repeat init does not reinitialize hooks")

-- Hook failure is propagated before any layer starts.
module._initDone = nil
hookOK = false
hookDetail = "apply hook failure"
local applied, detail = Runtime.ApplyCompanionConfig(module, {})
assertEqual(applied, false, "apply hook failure")
assertEqual(detail, "apply hook failure", "apply hook failure detail")
assertEqual(petApplyCalls, 0, "pet layer not started after hook failure")
assertEqual(microApplyCalls, 0, "micro layer not started after hook failure")

-- Pet failure restores only the partially applied pet presentation.
hookOK = true
hookDetail = nil
petOK = false
petDetail = "pet buttons unavailable"
applied, detail = Runtime.ApplyCompanionConfig(module, {})
assertEqual(applied, false, "pet layer failure")
assertEqual(detail, "pet buttons unavailable", "pet failure detail")
assertEqual(petApplyCalls, 1, "pet layer called once")
assertEqual(microApplyCalls, 0, "micro layer not started after pet failure")
assertEqual(petRestoreCalls, 1, "pet layer restored after failure")
assertEqual(microRestoreCalls, 0, "micro layer untouched after pet failure")
assertEqual(countUpdateCalls, 0, "count update not run after pet failure")

-- Micro failure restores both the micro layer and the previously applied pet layer.
petOK = true
petDetail = nil
microOK = false
microDetail = "micro layout failed"
applied, detail = Runtime.ApplyCompanionConfig(module, {})
assertEqual(applied, false, "micro layer failure")
assertEqual(detail, "micro layout failed", "micro failure detail")
assertEqual(petApplyCalls, 2, "pet layer applied before micro failure")
assertEqual(microApplyCalls, 1, "micro layer called once")
assertEqual(petRestoreCalls, 2, "pet layer restored after micro failure")
assertEqual(microRestoreCalls, 1, "micro layer restored after failure")
assertEqual(countUpdateCalls, 0, "count update not run after micro failure")

-- Full success reaches the terminal count update and preserves detail.
microOK = true
microDetail = "micro retry queued"
applied, detail = Runtime.ApplyCompanionConfig(module, {})
assertEqual(applied, true, "layered apply success")
assertEqual(detail, "micro retry queued", "success detail preserved")
assertEqual(petApplyCalls, 3, "pet success call")
assertEqual(microApplyCalls, 2, "micro success call")
assertEqual(petRestoreCalls, 2, "no cleanup on success")
assertEqual(microRestoreCalls, 1, "no micro cleanup on success")
assertEqual(countUpdateCalls, 1, "terminal count update run")

module._detached = true
applied, detail = Runtime.ApplyConfig(module, {})
assertEqual(applied, false, "detached apply rejected")
assertEqual(detail, "Companion is detached", "detached detail")
module._detached = nil

local missingApplied, missingDetail = Runtime.ApplyConfig(nil, {})
assertEqual(missingApplied, false, "missing owner rejected")
assertEqual(missingDetail, "Companion apply owner unavailable", "missing owner detail")

-- A debounced failure is not silently lost.
petOK = false
petDetail = "debounced pet failure"
microOK = true
microDetail = nil
local requested = Runtime.RequestApply(module)
assertEqual(requested, true, "debounced request accepted")
assertEqual(type(debounceCallback), "function", "debounce callback captured")
debounceCallback()
assertEqual(#errors, 1, "debounced failure logged")
assertContains(errors[1], "debounced pet failure", "debounced failure log")

-- Combat deferral remains explicit and does not start a layer.
inCombat = true
local petCallsBeforeCombat = petApplyCalls
local combatRequested = Runtime.RequestApply(module)
assertEqual(combatRequested, false, "combat request deferred")
assertEqual(module._pendingAfterCombat, true, "combat pending marker")
assertEqual(petApplyCalls, petCallsBeforeCombat, "combat request starts no pet apply")
inCombat = false

print("Companion result propagation tests passed.")
