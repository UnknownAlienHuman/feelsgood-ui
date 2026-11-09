local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertContains(value, needle, label)
    value = tostring(value)
    if not string.find(value, needle, 1, true) then
        error((label or "value") .. ": missing " .. tostring(needle) .. " in " .. value, 2)
    end
end

_G = _G or {}
_G.InCombatLockdown = function() return false end
_G.EventRegistry = {}

local queuedTimers = {}
_G.C_Timer = {
    After = function(delay, callback)
        queuedTimers[#queuedTimers + 1] = { delay = delay, callback = callback }
    end,
}

local frames = {}
_G.CreateFrame = function()
    local frame = { events = {}, scripts = {}, unregisterCalls = 0 }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterAllEvents()
        self.unregisterCalls = self.unregisterCalls + 1
        self.events = {}
    end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    frames[#frames + 1] = frame
    return frame
end

local createFailures = 1
local container = {
    registerCalls = 0,
    unregisterCalls = 0,
    registerFailures = 1,
    unregisterFailures = 0,
    callback = nil,
}
function container:RegisterCallback(_, _, callback)
    self.registerCalls = self.registerCalls + 1
    if self.registerFailures > 0 then
        self.registerFailures = self.registerFailures - 1
        error("injected callback registration failure")
    end
    self.callback = callback
end
function container:Unregister()
    self.unregisterCalls = self.unregisterCalls + 1
    if self.unregisterFailures > 0 then
        self.unregisterFailures = self.unregisterFailures - 1
        error("injected callback unregister failure")
    end
    self.callback = nil
end

_G.EventUtil = {
    CreateCallbackHandleContainer = function()
        if createFailures > 0 then
            createFailures = createFailures - 1
            error("injected callback container failure")
        end
        return container
    end,
}

local cfg = {
    autoHide = { enabled = false },
    hideBlizzard = false,
    buttonSize = 32,
    spacing = 0,
    showHotkeys = false,
    bars = {
        [1] = { enabled = false },
        [2] = { enabled = false },
        [3] = { enabled = false },
        [4] = { enabled = false },
        [5] = { enabled = false },
    },
}

local stateReleaseCalls = 0
local resetCalls = 0
local shellReleaseCalls = 0
local restoreCalls = 0
local cancelCalls = 0
local visualCalls = 0
local stateFailure
local endCapsFailure
local settingsFailure
local stateEnsureCalls = 0
local endCapsEnsureCalls = 0

local ns = {
    Log = { Info = function() end, Warn = function() end, Error = function() end },
    DB = {
        ReadSection = function(_, section)
            if section == "actionbars" then return cfg end
            return nil
        end,
        ShouldHideBlizzardActionBars = function() return false end,
    },
    ActionBarsState = {
        ResetAutoHideState = function() resetCalls = resetCalls + 1 end,
        ReleaseStateHookOwner = function() stateReleaseCalls = stateReleaseCalls + 1; return true end,
        UpdateButtonChecked = function() end,
        UpdateButtonEmpty = function() end,
    },
    ActionBarsVisuals = {
        RefreshButtonVisualState = function()
            visualCalls = visualCalls + 1
            return true
        end,
        BuildStyleConfig = function() return {} end,
        SetButtonHotkey = function() return true end,
    },
    ActionBarsEditMode = {
        ResolveBarSpacing = function(value) return tonumber(value) or 0 end,
    },
    ActionBarsBlizzardShell = {
        EnsureEndCapsHook = function()
            endCapsEnsureCalls = endCapsEnsureCalls + 1
            if endCapsFailure then return false, endCapsFailure end
            return true
        end,
        EnsureSettingsHooks = function()
            if settingsFailure then return false, settingsFailure end
            return true
        end,
        EnsureBlizzardMultiBars = function() return true end,
        ShouldHideBlizzardArt = function() return false end,
        RestoreBlizzardArt = function() restoreCalls = restoreCalls + 1; return true end,
        CancelPendingWork = function() cancelCalls = cancelCalls + 1; return true end,
        ReleaseHookOwner = function() shellReleaseCalls = shellReleaseCalls + 1; return true end,
    },
}

assert(loadfile("modules/ActionBarsRuntime.lua"))("FeelsGoodUI", ns)
local Runtime = assert(ns.ActionBarsRuntime)

local function NewHolder()
    local holder = { shown = true, strata = "LOW", level = 10, buttons = {} }
    function holder:GetFrameStrata() return self.strata end
    function holder:SetFrameStrata(value) self.strata = value end
    function holder:GetFrameLevel() return self.level end
    function holder:SetFrameLevel(value) self.level = value end
    function holder:Show() self.shown = true end
    function holder:Hide() self.shown = false end
    return holder
end

local module = {
    _detached = false,
    bars = { NewHolder(), NewHolder(), NewHolder(), NewHolder(), NewHolder() },
    stateCallbackFlags = {},
}
ns.ActionBars = module
function module:EnsureCreated() end
function module:EnsureStateHooks(hasCallback)
    stateEnsureCalls = stateEnsureCalls + 1
    self.stateCallbackFlags[#self.stateCallbackFlags + 1] = hasCallback == true
    if stateFailure then return false, stateFailure end
    return true
end
function module:EnsureAutoHideHooks() return true end
function module:RefreshEmptySlots() end
function module:UpdateAutoHideState() end

local ok, detail = Runtime.Init(module)
assertEqual(ok, false, "callback container failure result")
assertContains(detail, "callback container failure", "callback container failure detail")
assertEqual(module._initDone, nil, "init flag absent after container failure")
assertEqual(stateEnsureCalls, 0, "state hooks not attempted before callback owner resolves")

ok, detail = Runtime.Init(module)
assertEqual(ok, false, "callback registration failure result")
assertContains(detail, "callback registration failure", "callback registration detail")
assertEqual(module._actionChangedCallbackRegistered, nil, "callback flag unpublished after failure")
assertEqual(module._initDone, nil, "init flag absent after callback failure")

stateFailure = "state hook exploded"
ok, detail = Runtime.Init(module)
assertEqual(ok, false, "state hook failure result")
assertContains(detail, "state hook exploded", "state hook failure detail")
assertEqual(module._actionChangedCallbackRegistered, true, "callback flag published after success")
assertEqual(module._initDone, nil, "init flag absent after state failure")
assertEqual(module.stateCallbackFlags[#module.stateCallbackFlags], true, "state hooks know callback is registered")

stateFailure = nil
endCapsFailure = "end caps exploded"
ok, detail = Runtime.Init(module)
assertEqual(ok, false, "EndCaps failure result")
assertContains(detail, "end caps exploded", "EndCaps failure detail")
assertEqual(module._initDone, nil, "init flag absent after EndCaps failure")

endCapsFailure = nil
ok, detail = Runtime.Init(module)
assertEqual(ok, true, "init retry succeeds")
assertEqual(detail, nil, "init retry detail")
assertEqual(module._initDone, true, "init flag published after every edge succeeds")
assertEqual(module._inited, true, "legacy inited flag published after success")
assertEqual(container.registerCalls, 2, "callback registration attempted once after initial failure")
local stateCallsAfterInit = stateEnsureCalls
local endCapsCallsAfterInit = endCapsEnsureCalls
assertEqual(Runtime.Init(module), true, "repeated init succeeds")
assertEqual(container.registerCalls, 2, "repeated init does not duplicate callback")
assertEqual(stateEnsureCalls, stateCallsAfterInit + 1, "repeated init refreshes state hook owner")
assertEqual(endCapsEnsureCalls, endCapsCallsAfterInit + 1, "repeated init refreshes shell hook owner")

container.callback(nil, {})
assertEqual(visualCalls, 1, "action-change callback uses active module")
module._detached = true
container.callback(nil, {})
assertEqual(visualCalls, 1, "action-change callback inert while detached")
module._detached = false

settingsFailure = "settings hook exploded"
ok, detail = Runtime.ApplyNow(module)
assertEqual(ok, false, "settings hook apply failure result")
assertContains(detail, "settings hook exploded", "settings hook apply detail")
settingsFailure = nil

-- Cleanup failure is reported after all owners and flags are still released.
container.unregisterFailures = 1
ok, detail = Runtime.Detach(module)
assertEqual(ok, false, "detach unregister failure result")
assertContains(detail, "unregister failure", "detach unregister detail")
assertEqual(module._actionChangedCallbackRegistered, nil, "callback flag cleared on failed detach")
assertEqual(stateReleaseCalls, 1, "state owner released on failed detach")
assertEqual(shellReleaseCalls, 1, "shell owner released on failed detach")
assertEqual(module._eventsAttached, false, "events state cleared on failed detach")
assertEqual(cancelCalls, 1, "shell pending work cancelled")
assertEqual(resetCalls, 1, "auto-hide state reset")
assertEqual(restoreCalls, 1, "shell restored")

-- Reattach retries callback registration even though _initDone already exists.
container.registerFailures = 1
ok, detail = Runtime.Attach(module)
assertEqual(ok, false, "reattach callback failure result")
assertContains(detail, "callback registration failure", "reattach callback failure detail")
assertEqual(module._eventsAttached, false, "failed reattach publishes no event state")
assertEqual(module._initDone, true, "successful historical init remains true")

ok, detail = Runtime.Attach(module)
assertEqual(ok, true, "reattach retry succeeds")
assertEqual(detail, nil, "reattach retry detail")
assertEqual(module._actionChangedCallbackRegistered, true, "callback flag republished after retry")
assertEqual(module._eventsAttached, true, "events published after attach")
assertEqual(type(module._eventFrame), "table", "event frame created")
assertEqual(#queuedTimers, 1, "initial apply queued without synchronous execution")

ok, detail = Runtime.Detach(module)
assertEqual(ok, true, "final detach succeeds")
assertEqual(detail, nil, "final detach detail")
assertEqual(module._actionChangedCallbackRegistered, nil, "final detach clears callback flag")
assertEqual(module._eventsAttached, false, "final detach clears events")
assertEqual(stateReleaseCalls, 2, "state owner released after final detach")
assertEqual(shellReleaseCalls, 2, "shell owner released after final detach")

print("ActionBars callback/init/detach tests passed.")
