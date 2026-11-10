local function fail(message)
    error(message, 2)
end

local function assertTrue(value, label)
    if value ~= true then fail((label or "expected true") .. ": got " .. tostring(value)) end
end

local function assertFalse(value, label)
    if value ~= false then fail((label or "expected false") .. ": got " .. tostring(value)) end
end

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        fail((label or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assertContains(text, needle, label)
    text = tostring(text)
    if not string.find(text, needle, 1, true) then
        fail((label or "missing text") .. ": expected '" .. needle .. "' in '" .. text .. "'")
    end
end

local inCombat = false
local errors = {}
local expandCalls = 0
local bagCalls = 0
local applyCalls = 0
local microRestoreCalls = 0
local petRestoreCalls = 0
local ensureHooksFail = false
local microApplyFail = false
local petApplyFail = false
local microRestoreFail = false
local petRestoreFail = false

local callbackConfigs = {}
local callbackHandles = {}
local watcherConfigs = {}
local watchers = {}
local debounceCallbacks = {}
local cancelledKeys = {}

local function QueueCallback(config)
    callbackConfigs[#callbackConfigs + 1] = config or {}
end

local function QueueWatcher(config)
    watcherConfigs[#watcherConfigs + 1] = config or {}
end

local function NewCallbackHandles(config)
    local handles = {
        config = config or {},
        registerCalls = 0,
        unregisterCalls = 0,
        registered = false,
    }

    function handles:RegisterCallback(_, _, callback, owner)
        self.registerCalls = self.registerCalls + 1
        if self.config.failRegister then
            error("forced callback registration failure")
        end
        if self.config.rejectRegister then return false end
        self.callback = callback
        self.owner = owner
        self.registered = true
        return true
    end

    function handles:Unregister()
        self.unregisterCalls = self.unregisterCalls + 1
        if self.config.failUnregister then
            error("forced callback unregister failure")
        end
        if self.config.rejectUnregister then return false end
        self.registered = false
        return true
    end

    function handles:Fire()
        if self.callback then self.callback() end
    end

    callbackHandles[#callbackHandles + 1] = handles
    return handles
end

local function NewWatcher(config)
    local watcher = {
        config = config or {},
        registerCalls = 0,
        unregisterCalls = 0,
        registrations = {},
    }

    function watcher:SetScript(name, callback)
        if name ~= "OnEvent" then return end
        if callback == nil and self.config.failClearScript then
            error("forced watcher clear-script failure")
        end
        if callback ~= nil and self.config.failSetScript then
            error("forced watcher SetScript failure")
        end
        self.script = callback
    end

    function watcher:RegisterEvent(event)
        self.registerCalls = self.registerCalls + 1
        if self.config.failRegisterAt == self.registerCalls then
            if self.config.rejectRegister then return false end
            error("forced watcher registration failure")
        end
        self.registrations[#self.registrations + 1] = event
        return true
    end

    function watcher:UnregisterAllEvents()
        self.unregisterCalls = self.unregisterCalls + 1
        if self.config.failUnregister then
            error("forced watcher unregister failure")
        end
        if self.config.rejectUnregister then return false end
        self.registrations = {}
        return true
    end

    function watcher:Fire(event, arg1)
        if self.script then self.script(self, event, arg1) end
    end

    watchers[#watchers + 1] = watcher
    return watcher
end

_G.oUF = {}
_G.EventRegistry = {}
_G.EventUtil = {
    CreateCallbackHandleContainer = function()
        local config = table.remove(callbackConfigs, 1) or {}
        if config.failCreate then error("forced callback container creation failure") end
        return NewCallbackHandles(config)
    end,
}
_G.CreateFrame = function()
    local config = table.remove(watcherConfigs, 1) or {}
    if config.failCreate then error("forced watcher creation failure") end
    return NewWatcher(config)
end

local Shared = {
    APPLY_DEBOUNCE_KEY = "Companion.Apply",
    MICRO_LAYOUT_RETRY_KEY = "Companion.MicroRetry",
    IsInCombat = function() return inCombat end,
    GetCompanionCfg = function()
        return {
            buttonSize = 32,
            spacing = 0,
            petBar = {},
            microMenu = { enabled = true },
            bags = { enabled = true, compact = true },
        }
    end,
}

local PetBar = {}
function PetBar:Apply()
    if petApplyFail then return false, "forced pet apply failure" end
    return true
end
function PetBar:RestoreDefaultLayout()
    petRestoreCalls = petRestoreCalls + 1
    if petRestoreFail then return false, "forced pet restore failure" end
    return true
end

local MicroBags = {}
function MicroBags:EnsureHooks()
    if ensureHooksFail then return false, "forced hook failure" end
    return true
end
function MicroBags:Apply()
    if microApplyFail then return false, "forced micro apply failure" end
    return true
end
function MicroBags:RestoreDefaultLayout()
    microRestoreCalls = microRestoreCalls + 1
    if microRestoreFail then return false, "forced micro restore failure" end
    return true
end
function MicroBags:UpdateCompactBagCountText() end
function MicroBags:HandleExpandChanged()
    expandCalls = expandCalls + 1
    if self.failExpand then error("forced expand callback failure") end
end
function MicroBags:HandleBagUpdate()
    bagCalls = bagCalls + 1
    return false
end

local Safety = {
    Debounce = function(key, _, callback)
        debounceCallbacks[key] = callback
        return true
    end,
    CancelDebounce = function(key)
        cancelledKeys[#cancelledKeys + 1] = key
        debounceCallbacks[key] = nil
        return true
    end,
}

local ns = {
    Log = {
        Error = function(_, message) errors[#errors + 1] = tostring(message) end,
        Warn = function() end,
        Info = function() end,
    },
    Safety = Safety,
    CompanionShared = Shared,
    CompanionPetBar = PetBar,
    CompanionMicroBags = MicroBags,
}

assert(loadfile('modules/CompanionRuntime.lua'))('FeelsGoodUI', ns)
local Runtime = assert(ns.CompanionRuntime)

local function ResetFlags()
    inCombat = false
    errors = {}
    expandCalls = 0
    bagCalls = 0
    applyCalls = 0
    microRestoreCalls = 0
    petRestoreCalls = 0
    ensureHooksFail = false
    microApplyFail = false
    petApplyFail = false
    microRestoreFail = false
    petRestoreFail = false
    callbackConfigs = {}
    watcherConfigs = {}
    debounceCallbacks = {}
    cancelledKeys = {}
    MicroBags.failExpand = false
end

local function NewModule()
    local module = {}
    ns.Companion = module
    return module
end

-- Happy attach publishes exactly one callback/watcher generation; repeated
-- attach reuses it and dispatches through the exact active records.
ResetFlags()
local module = NewModule()
QueueCallback({})
QueueWatcher({})
local ok, detail = Runtime.Attach(module)
assertTrue(ok, detail)
assertTrue(module._initDone, "init published")
assertTrue(module._eventsAttached, "events attached")
assertTrue(module._expandCallbackRecord.active, "expand record active")
assertTrue(module._watcherRecord.active, "watcher record active")
assertEqual(#callbackHandles, 1, "one callback container")
local firstHandle = module._callbackHandles
local firstWatcher = module._combatWatcher

firstHandle:Fire()
assertEqual(expandCalls, 1, "active expand callback dispatches")
firstWatcher:Fire("BAG_UPDATE_DELAYED")
assertEqual(bagCalls, 1, "active watcher dispatches")
assertTrue(debounceCallbacks[Shared.APPLY_DEBOUNCE_KEY] ~= nil, "watcher queues apply")

ok, detail = Runtime.Attach(module)
assertTrue(ok, detail)
assertEqual(module._callbackHandles, firstHandle, "repeat attach reuses callback")
assertEqual(module._combatWatcher, firstWatcher, "repeat attach reuses watcher")

-- Callback-container creation failure blocks attach without owner publication;
-- retry succeeds with a fresh generation.
ResetFlags()
module = NewModule()
QueueCallback({ failCreate = true })
ok, detail = Runtime.Attach(module)
assertFalse(ok, "callback container creation failure propagates")
assertContains(detail, "callback container creation failed", "callback creation detail")
assertEqual(module._eventsAttached, nil, "failed attach publishes no events")
assertEqual(module._expandCallbackRecord, nil, "failed attach publishes no callback")
assertTrue(module._detaching, "failed attach remains unavailable")

QueueCallback({})
QueueWatcher({})
ok, detail = Runtime.Attach(module)
assertTrue(ok, detail)
assertEqual(module._detaching, nil, "retry clears detaching state")

-- Partial watcher registration rolls back the prepared callback and watcher;
-- both stale closures remain inert. Retry creates one complete pair.
ResetFlags()
module = NewModule()
QueueCallback({})
QueueWatcher({ failRegisterAt = 3 })
ok, detail = Runtime.Attach(module)
assertFalse(ok, "watcher registration failure propagates")
assertContains(detail, "watcher preparation failed", "watcher failure detail")
local failedHandle = callbackHandles[#callbackHandles]
local failedWatcher = watchers[#watchers]
failedHandle:Fire()
failedWatcher:Fire("PLAYER_ENTERING_WORLD")
assertEqual(expandCalls, 0, "failed callback generation inert")
assertEqual(#debounceCallbacks, 0, "failed watcher generation inert")
assertEqual(failedHandle.unregisterCalls, 1, "prepared callback cleaned")
assertEqual(failedWatcher.unregisterCalls, 1, "partial watcher cleaned")

QueueCallback({})
QueueWatcher({})
ok, detail = Runtime.Attach(module)
assertTrue(ok, detail)
assertTrue(module._eventsAttached, "retry publishes events")

-- Failed callback unregister deactivates and unpublishes before cleanup. A
-- stale native callback cannot act; retry detach cleans the retired handle.
ResetFlags()
module = NewModule()
QueueCallback({})
QueueWatcher({})
assertTrue(Runtime.Attach(module))
local staleHandle = module._callbackHandles
staleHandle.config.failUnregister = true
ok, detail = Runtime.Detach(module)
assertFalse(ok, "callback unregister failure propagates")
assertContains(detail, "expand callback", "callback detach detail")
assertEqual(module._detached, nil, "failed out-of-combat detach unpublished")
assertTrue(module._detaching, "failed detach keeps runtime unavailable")
local beforeExpand = expandCalls
staleHandle:Fire()
assertEqual(expandCalls, beforeExpand, "stale callback inert after failed unregister")

staleHandle.config.failUnregister = false
ok, detail = Runtime.Detach(module)
assertTrue(ok, detail)
assertTrue(module._detached, "detach retry succeeds")
assertEqual(module._retiredExpandRecords, nil, "retired callback cleaned")

-- Failed watcher cleanup is also inert and retryable.
ResetFlags()
module = NewModule()
QueueCallback({})
QueueWatcher({})
assertTrue(Runtime.Attach(module))
local staleWatcher = module._combatWatcher
staleWatcher.config.failClearScript = true
staleWatcher.config.failUnregister = true
ok, detail = Runtime.Detach(module)
assertFalse(ok, "watcher cleanup failure propagates")
assertContains(detail, "watcher", "watcher detach detail")
local beforeBag = bagCalls
staleWatcher:Fire("BAG_UPDATE_DELAYED")
assertEqual(bagCalls, beforeBag, "stale watcher inert after failed cleanup")

staleWatcher.config.failClearScript = false
staleWatcher.config.failUnregister = false
ok, detail = Runtime.Detach(module)
assertTrue(ok, detail)
assertEqual(module._retiredWatcherRecords, nil, "retired watcher cleaned")

-- Combat detach installs a dedicated exact watcher after invalidating normal
-- callback/watcher generations. Regen finalizes restore and removes the watcher.
ResetFlags()
module = NewModule()
QueueCallback({})
QueueWatcher({})
assertTrue(Runtime.Attach(module))
local oldHandle = module._callbackHandles
local oldWatcher = module._combatWatcher
inCombat = true
QueueWatcher({})
ok, detail = Runtime.Detach(module)
assertFalse(ok, "combat detach reports deferred completion")
assertContains(detail, "deferred", "combat detach detail")
assertTrue(module._detached, "combat detach publishes logical detach")
assertTrue(module._pendingDetachRestore, "combat restore pending")
local detachWatcher = module._combatWatcher
assertTrue(detachWatcher ~= oldWatcher, "dedicated detach watcher installed")
oldHandle:Fire()
oldWatcher:Fire("BAG_UPDATE_DELAYED")
assertEqual(expandCalls, 0, "old callback inert in combat detach")
assertEqual(bagCalls, 0, "old watcher inert in combat detach")

inCombat = false
detachWatcher:Fire("PLAYER_REGEN_ENABLED")
assertEqual(module._pendingDetachRestore, nil, "regen finalizes restore")
assertEqual(module._watcherRecord, nil, "detach watcher released")
assertEqual(microRestoreCalls, 1, "micro layout restored")
assertEqual(petRestoreCalls, 1, "pet layout restored")

-- A restore failure keeps the dedicated watcher and pending state active for a
-- later exact retry; successful retry then releases it.
ResetFlags()
module = NewModule()
QueueCallback({})
QueueWatcher({})
assertTrue(Runtime.Attach(module))
inCombat = true
QueueWatcher({})
Runtime.Detach(module)
local retryWatcher = module._combatWatcher
microRestoreFail = true
inCombat = false
retryWatcher:Fire("PLAYER_REGEN_ENABLED")
assertTrue(module._pendingDetachRestore, "failed restore remains pending")
assertEqual(module._watcherRecord.frame, retryWatcher, "retry watcher retained")
assertTrue(#errors >= 1, "restore failure logged")

microRestoreFail = false
retryWatcher:Fire("PLAYER_ENTERING_WORLD")
assertEqual(module._pendingDetachRestore, nil, "later event retries restore")
assertEqual(module._watcherRecord, nil, "successful retry releases watcher")

-- Failed detach-watcher preparation does not publish logical detach; retry can
-- install a complete watcher without reactivating old registrations.
ResetFlags()
module = NewModule()
QueueCallback({})
QueueWatcher({})
assertTrue(Runtime.Attach(module))
inCombat = true
QueueWatcher({ failRegisterAt = 1 })
ok, detail = Runtime.Detach(module)
assertFalse(ok, "detach watcher preparation failure propagates")
assertContains(detail, "detach watcher", "detach watcher failure detail")
assertEqual(module._detached, nil, "failed deferred detach unpublished")
assertTrue(module._detaching, "failed deferred detach remains unavailable")

QueueWatcher({})
ok, detail = Runtime.Detach(module)
assertFalse(ok, "retry reports deferred completion")
assertTrue(module._detached, "retry publishes logical detach")
inCombat = false
module._combatWatcher:Fire("PLAYER_REGEN_ENABLED")

-- RequestApply in combat is a successful deferred request, not a false failure.
ResetFlags()
module = NewModule()
QueueCallback({})
QueueWatcher({})
assertTrue(Runtime.Attach(module))
inCombat = true
ok, detail = Runtime.RequestApply(module)
assertTrue(ok, "combat request is accepted")
assertContains(detail, "deferred", "combat request detail")
assertTrue(module._pendingAfterCombat, "combat request pending")

-- Callback errors are contained and deduplicated.
inCombat = false
MicroBags.failExpand = true
module._callbackHandles:Fire()
module._callbackHandles:Fire()
assertEqual(#errors, 1, "identical expand callback failure logged once")
assertContains(errors[1], "expand callback failed", "expand callback log")
MicroBags.failExpand = false
module._callbackHandles:Fire()
assertEqual(expandCalls, 3, "callback recovers after failure")

print('Companion runtime lifecycle tests passed.')
