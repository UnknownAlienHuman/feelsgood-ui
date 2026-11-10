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
local callbackConfigs = {}
local watcherConfigs = {}
local handlesCreated = {}
local watchersCreated = {}
local restoreCalls = 0
local errors = {}

local function QueueCallback(config)
    callbackConfigs[#callbackConfigs + 1] = config or {}
end

local function QueueWatcher(config)
    watcherConfigs[#watcherConfigs + 1] = config or {}
end

local function NewHandles(config)
    local handles = {
        config = config or {},
        unregisterCalls = 0,
    }

    function handles:RegisterCallback(_, _, callback)
        if self.config.failRegister then error("forced callback register failure") end
        self.callback = callback
        return true
    end

    function handles:Unregister()
        self.unregisterCalls = self.unregisterCalls + 1
        if self.config.failUnregister then error("forced callback unregister failure") end
        return true
    end

    function handles:Fire()
        if self.callback then self.callback() end
    end

    handlesCreated[#handlesCreated + 1] = handles
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
        if callback ~= nil and self.config.failSetScript then
            error("forced watcher SetScript failure")
        end
        if callback == nil and self.config.failClearScript then
            error("forced watcher clear-script failure")
        end
        self.script = callback
        return true
    end

    function watcher:RegisterEvent(event)
        self.registerCalls = self.registerCalls + 1
        if self.config.failRegisterAt == self.registerCalls then
            error("forced watcher register failure")
        end
        self.registrations[#self.registrations + 1] = event
        return true
    end

    function watcher:UnregisterAllEvents()
        self.unregisterCalls = self.unregisterCalls + 1
        if self.config.failUnregister then
            error("forced watcher unregister failure")
        end
        self.registrations = {}
        return true
    end

    function watcher:Fire(event, arg1)
        if self.script then self.script(self, event, arg1) end
    end

    watchersCreated[#watchersCreated + 1] = watcher
    return watcher
end

_G.oUF = {}
_G.EventRegistry = {}
_G.EventUtil = {
    CreateCallbackHandleContainer = function()
        local config = table.remove(callbackConfigs, 1) or {}
        return NewHandles(config)
    end,
}
_G.CreateFrame = function()
    local config = table.remove(watcherConfigs, 1) or {}
    return NewWatcher(config)
end

local Shared = {
    APPLY_DEBOUNCE_KEY = "Companion.Apply",
    MICRO_LAYOUT_RETRY_KEY = "Companion.MicroRetry",
    IsInCombat = function() return inCombat end,
    GetCompanionCfg = function() return {} end,
}

local MicroBags = {}
function MicroBags:EnsureHooks() return true end
function MicroBags:Apply() return true end
function MicroBags:RestoreDefaultLayout()
    restoreCalls = restoreCalls + 1
    return true
end
function MicroBags:UpdateCompactBagCountText() return true end
function MicroBags:HandleExpandChanged() return true end
function MicroBags:HandleBagUpdate() return false end

local PetBar = {}
function PetBar:Apply() return true end
function PetBar:RestoreDefaultLayout() return true end

local ns = {
    Log = {
        Error = function(_, message) errors[#errors + 1] = tostring(message) end,
        Warn = function() end,
        Info = function() end,
    },
    Safety = {
        Debounce = function() return true end,
        CancelDebounce = function() return true end,
    },
    CompanionShared = Shared,
    CompanionPetBar = PetBar,
    CompanionMicroBags = MicroBags,
}

assert(loadfile('modules/CompanionRuntime.lua'))('FeelsGoodUI', ns)
local Runtime = assert(ns.CompanionRuntime)

local function Reset()
    inCombat = false
    callbackConfigs = {}
    watcherConfigs = {}
    handlesCreated = {}
    watchersCreated = {}
    restoreCalls = 0
    errors = {}
end

local function NewModule()
    local module = {}
    ns.Companion = module
    return module
end

local function Attach(module, callbackConfig, watcherConfig)
    QueueCallback(callbackConfig or {})
    QueueWatcher(watcherConfig or {})
    return Runtime.Attach(module)
end

-- Failed watcher SetScript is cleaned before returning. If that cleanup itself
-- fails, the inactive record remains in owner state and a later attach retries
-- it before publishing a new watcher generation.
Reset()
local module = NewModule()
local ok, detail = Attach(module, {}, { failSetScript = true })
assertFalse(ok, "watcher setup failure propagates")
assertContains(detail, "watcher callback setup failed", "watcher setup detail")
assertEqual(module._watcherRecord, nil, "failed watcher unpublished")
assertEqual(module._retiredWatcherRecords, nil, "successful setup cleanup leaves no retired record")
assertEqual(handlesCreated[1].unregisterCalls, 1, "prepared callback cleaned after watcher setup failure")

module = NewModule()
ok, detail = Attach(module, {}, {
    failSetScript = true,
    failClearScript = true,
    failUnregister = true,
})
assertFalse(ok, "watcher setup cleanup failure propagates")
assertContains(detail, "cleanup", "watcher setup cleanup detail")
assertTrue(type(module._retiredWatcherRecords) == "table", "failed setup cleanup retained")
local leakedWatcher = watchersCreated[1]
leakedWatcher:Fire("PLAYER_ENTERING_WORLD")
assertEqual(module._pendingAfterCombat, nil, "unpublished setup callback inert")

leakedWatcher.config.failClearScript = false
leakedWatcher.config.failUnregister = false
QueueCallback({})
QueueWatcher({})
ok, detail = Runtime.Attach(module)
assertTrue(ok, detail)
assertEqual(module._retiredWatcherRecords, nil, "failed setup cleanup retried")

-- If an old callback generation cannot unregister during combat detach, the
-- dedicated detach watcher remains the exact retry owner after restore. It is
-- not released until the retired callback is clean.
Reset()
module = NewModule()
assertTrue(Attach(module))
local staleHandle = module._callbackHandles
staleHandle.config.failUnregister = true
inCombat = true
QueueWatcher({})
ok, detail = Runtime.Detach(module)
assertFalse(ok, "combat detach reports deferred completion")
assertTrue(module._detached, "combat detach publishes logical detach")
assertTrue(module._pendingDetachRestore, "combat detach pending")
local retryWatcher = module._combatWatcher
assertTrue(retryWatcher ~= nil, "dedicated detach watcher installed")

inCombat = false
retryWatcher:Fire("PLAYER_REGEN_ENABLED")
assertTrue(module._pendingDetachRestore, "retired cleanup failure keeps pending state")
assertEqual(module._combatWatcher, retryWatcher, "same detach watcher retained")
assertTrue(module._watcherRecord.active, "retry watcher remains active")
local before = restoreCalls
staleHandle:Fire()
assertEqual(restoreCalls, before, "stale callback remains inert")

staleHandle.config.failUnregister = false
retryWatcher:Fire("PLAYER_ENTERING_WORLD")
assertEqual(module._pendingDetachRestore, nil, "later event completes cleanup")
assertEqual(module._watcherRecord, nil, "detach watcher released after complete cleanup")
assertEqual(module._retiredExpandRecords, nil, "retired callback released")

-- If the dedicated watcher cannot unregister itself, it is invalidated and a
-- fresh watcher generation is installed. The stale watcher cannot dispatch;
-- the replacement performs the exact retry after the old cleanup becomes
-- possible.
Reset()
module = NewModule()
assertTrue(Attach(module))
inCombat = true
QueueWatcher({ failClearScript = true, failUnregister = true })
Runtime.Detach(module)
local failedDetachWatcher = module._combatWatcher
QueueWatcher({}) -- replacement generation created by FinalizeDetach
inCombat = false
failedDetachWatcher:Fire("PLAYER_REGEN_ENABLED")
assertTrue(module._pendingDetachRestore, "self-unregister failure keeps pending state")
local replacementWatcher = module._combatWatcher
assertTrue(replacementWatcher ~= nil and replacementWatcher ~= failedDetachWatcher, "fresh retry watcher installed")
assertFalse(module._watcherRecord == nil, "replacement watcher published")

local pendingBefore = module._pendingDetachRestore
failedDetachWatcher:Fire("PLAYER_ENTERING_WORLD")
assertEqual(module._pendingDetachRestore, pendingBefore, "stale detach watcher inert")

failedDetachWatcher.config.failClearScript = false
failedDetachWatcher.config.failUnregister = false
replacementWatcher:Fire("PLAYER_ENTERING_WORLD")
assertEqual(module._pendingDetachRestore, nil, "replacement watcher completes detach")
assertEqual(module._watcherRecord, nil, "replacement watcher released")
assertEqual(module._retiredWatcherRecords, nil, "failed detach watcher cleanup retried")

-- Detached callers retry unresolved retired registrations even when no layout
-- restore remains pending.
Reset()
module = NewModule()
assertTrue(Attach(module))
local oldHandle = module._callbackHandles
oldHandle.config.failUnregister = true
inCombat = true
QueueWatcher({})
Runtime.Detach(module)
inCombat = false
local detachWatcher = module._combatWatcher
oldHandle.config.failUnregister = false
detachWatcher:Fire("PLAYER_REGEN_ENABLED")
assertTrue(module._detached, "module remains detached")
assertEqual(module._pendingDetachRestore, nil, "normal finalization clears pending state")

ok, detail = Runtime.Detach(module)
assertTrue(ok, detail)

print('Companion detach retry tests passed.')
