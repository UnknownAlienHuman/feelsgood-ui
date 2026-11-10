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

local eventConfigs = {}
local eventFrames = {}
local refreshCalls = 0
local updateCalls = 0
local powerCalls = 0
local runeCalls = 0
local restoreCalls = 0
local stopTickerCalls = 0
local restoreOK = true
local config = { enabled = true }

local function QueueEventConfig(value)
    eventConfigs[#eventConfigs + 1] = value or {}
end

local function NewEventFrame(frameConfig)
    local frame = {
        config = frameConfig or {},
        registerCalls = 0,
        unregisterCalls = 0,
        registrations = {},
        script = nil,
    }

    function frame:SetScript(name, callback)
        if name ~= "OnEvent" then return true end
        if callback ~= nil and self.config.failSetScript then
            error("forced SetScript failure")
        end
        if callback == nil and self.config.failClearScript then
            error("forced clear-script failure")
        end
        self.script = callback
        return true
    end

    local function Register(self, method, event, unit)
        self.registerCalls = self.registerCalls + 1
        if self.config.failRegisterAt == self.registerCalls then
            if self.config.rejectRegister then return false end
            error("forced registration failure")
        end
        self.registrations[#self.registrations + 1] = {
            method = method,
            event = event,
            unit = unit,
        }
        return true
    end

    function frame:RegisterEvent(event)
        return Register(self, "RegisterEvent", event, nil)
    end

    if not frameConfig.noUnitMethod then
        function frame:RegisterUnitEvent(event, unit)
            return Register(self, "RegisterUnitEvent", event, unit)
        end
    end

    function frame:UnregisterAllEvents()
        self.unregisterCalls = self.unregisterCalls + 1
        if self.config.failUnregister then
            error("forced UnregisterAllEvents failure")
        end
        if self.config.rejectUnregister then return false end
        self.registrations = {}
        return true
    end

    function frame:Fire(event, ...)
        if self.script then self.script(self, event, ...) end
    end

    eventFrames[#eventFrames + 1] = frame
    return frame
end

_G.UIParent = {}
_G.CreateFrame = function()
    local frameConfig = table.remove(eventConfigs, 1) or {}
    if frameConfig.failCreate then
        error("forced CreateFrame failure")
    end
    return NewEventFrame(frameConfig)
end
_G.InCombatLockdown = function() return false end

local ns = {
    Log = {
        Error = function() end,
        Warn = function() end,
        Info = function() end,
    },
    Media = {
        FetchStatusbar = function(_, token) return token end,
        ApplyFont = function() end,
    },
    Movers = {},
    Safety = {
        Dispatch = function(owner, _, handler, ...)
            return handler(owner, ...)
        end,
    },
}

assert(loadfile('modules/CenterBarsRuntime.lua'))('FeelsGoodUI', ns)
local Runtime = assert(ns.CenterBarsRuntime)
Runtime:Configure({
    GetCenterCfg = function() return config end,
    GetCenterTextCfg = function() return {} end,
    GetSharedFontToken = function() return "font" end,
    GetSharedFontOutline = function() return "" end,
    GetSharedFontSize = function() return 12 end,
    GetSharedStatusbarToken = function() return "bar" end,
    RefreshResourceMode = function()
        refreshCalls = refreshCalls + 1
        return true
    end,
    UpdatePower = function()
        updateCalls = updateCalls + 1
        return true
    end,
    OnUnitPower = function()
        powerCalls = powerCalls + 1
        return true
    end,
    OnRuneEvent = function()
        runeCalls = runeCalls + 1
        return true
    end,
    RestoreDefaultClassResources = function()
        restoreCalls = restoreCalls + 1
        if restoreOK then return true end
        return false, "forced native restore failure"
    end,
    StopRuneTicker = function()
        stopTickerCalls = stopTickerCalls + 1
        return true
    end,
})

local function NewOwnedFrame()
    local frame = { shown = true }
    function frame:Hide() self.shown = false end
    function frame:Show() self.shown = true end
    function frame:SetScale() end
    function frame:SetSize() end
    return frame
end

local function NewOwner()
    return {
        _inited = true,
        frame = NewOwnedFrame(),
        resourceSegments = {},
        RefreshCache = function() end,
    }
end

local function ResetState()
    eventConfigs = {}
    eventFrames = {}
    refreshCalls = 0
    updateCalls = 0
    powerCalls = 0
    runeCalls = 0
    restoreCalls = 0
    stopTickerCalls = 0
    restoreOK = true
    config.enabled = true
end

-- CreateFrame and SetScript are mandatory attach edges. Neither failure may
-- publish an event owner.
ResetState()
local owner = NewOwner()
QueueEventConfig({ failCreate = true })
local ok, detail = Runtime:Attach(owner)
assertFalse(ok, "event-frame creation failure propagates")
assertContains(detail, "event-frame creation failed", "creation failure detail")
assertEqual(owner._eventRecord, nil, "creation failure publishes no record")
assertEqual(owner._eventsAttached, false, "creation failure explicitly unattached")

owner = NewOwner()
QueueEventConfig({ failSetScript = true })
ok, detail = Runtime:Attach(owner)
assertFalse(ok, "SetScript failure propagates")
assertContains(detail, "event callback setup failed", "SetScript failure detail")
assertEqual(owner._eventRecord, nil, "SetScript failure publishes no record")
assertEqual(owner._retiredEventRecords, nil, "successful setup cleanup leaves no retired record")

-- Failed setup cleanup is retained and blocks a new generation until exact
-- cleanup succeeds.
owner = NewOwner()
QueueEventConfig({
    failSetScript = true,
    failClearScript = true,
    failUnregister = true,
})
ok, detail = Runtime:Attach(owner)
assertFalse(ok, "SetScript cleanup failure propagates")
assertContains(detail, "cleanup", "SetScript cleanup detail")
assertTrue(type(owner._retiredEventRecords) == "table", "failed setup cleanup retained")
local leakedSetupFrame = eventFrames[#eventFrames]
leakedSetupFrame:Fire("PLAYER_ENTERING_WORLD")
assertEqual(refreshCalls, 0, "unpublished setup callback inert")

leakedSetupFrame.config.failClearScript = false
leakedSetupFrame.config.failUnregister = false
QueueEventConfig({})
ok, detail = Runtime:Attach(owner)
assertTrue(ok, detail)
assertEqual(owner._retiredEventRecords, nil, "setup cleanup retried before publication")

-- Partial RegisterUnitEvent failure leaves no active generation. When cleanup
-- succeeds, retry installs all nine edges exactly once.
ResetState()
owner = NewOwner()
QueueEventConfig({ failRegisterAt = 4 })
ok, detail = Runtime:Attach(owner)
assertFalse(ok, "partial registration failure propagates")
assertContains(detail, "event registration failed", "registration failure detail")
local failedFrame = eventFrames[#eventFrames]
assertEqual(owner._eventRecord, nil, "partial record unpublished")
assertEqual(failedFrame.unregisterCalls, 1, "partial registration cleaned")
failedFrame:Fire("PLAYER_ENTERING_WORLD")
assertEqual(refreshCalls, 0, "cleaned partial callback inert")

QueueEventConfig({})
ok, detail = Runtime:Attach(owner)
assertTrue(ok, detail)
local activeFrame = owner._eventFrame
assertEqual(#activeFrame.registrations, 9, "all event edges registered")
assertTrue(owner._eventRecord.active, "complete record active")
assertTrue(owner._eventsAttached, "complete record published")

local registerCalls = activeFrame.registerCalls
ok, detail = Runtime:Attach(owner)
assertTrue(ok, detail)
assertEqual(owner._eventFrame, activeFrame, "repeat attach reuses record")
assertEqual(activeFrame.registerCalls, registerCalls, "repeat attach adds no event edges")

activeFrame:Fire("PLAYER_ENTERING_WORLD")
assertEqual(refreshCalls, 1, "world event refreshes resource mode")
assertEqual(updateCalls, 1, "world event updates power")
activeFrame:Fire("PLAYER_SPECIALIZATION_CHANGED", "target")
assertEqual(refreshCalls, 1, "foreign specialization unit ignored")
activeFrame:Fire("PLAYER_SPECIALIZATION_CHANGED", "player")
assertEqual(refreshCalls, 2, "player specialization refreshes")
activeFrame:Fire("UNIT_POWER_UPDATE", "player", "MANA")
assertEqual(powerCalls, 1, "power event dispatches")
activeFrame:Fire("RUNE_POWER_UPDATE")
assertEqual(runeCalls, 1, "rune event dispatches")

-- Failed partial cleanup remains dirty/inert. A later attach retries the exact
-- retired frame before publishing a fresh record.
ResetState()
owner = NewOwner()
QueueEventConfig({
    failRegisterAt = 5,
    failClearScript = true,
    failUnregister = true,
})
ok, detail = Runtime:Attach(owner)
assertFalse(ok, "partial cleanup failure propagates")
assertContains(detail, "cleanup", "partial cleanup detail")
local dirtyFrame = eventFrames[#eventFrames]
assertTrue(type(owner._retiredEventRecords) == "table", "dirty record retained")
dirtyFrame:Fire("PLAYER_ENTERING_WORLD")
assertEqual(refreshCalls, 0, "dirty partial callback inert")

dirtyFrame.config.failClearScript = false
dirtyFrame.config.failUnregister = false
QueueEventConfig({})
ok, detail = Runtime:Attach(owner)
assertTrue(ok, detail)
assertEqual(owner._retiredEventRecords, nil, "dirty cleanup retried")

-- Fallback clients without RegisterUnitEvent still register the same complete
-- event set through RegisterEvent.
ResetState()
owner = NewOwner()
QueueEventConfig({ noUnitMethod = true })
ok, detail = Runtime:Attach(owner)
assertTrue(ok, detail)
assertEqual(#owner._eventFrame.registrations, 9, "fallback event set complete")
for i = 1, #owner._eventFrame.registrations do
    assertEqual(owner._eventFrame.registrations[i].method, "RegisterEvent", "fallback uses RegisterEvent")
end
assertTrue(Runtime:Detach(owner))

-- Detach invalidates and unpublishes before cleanup. Failed native unregister
-- cannot make the stale callback functional; retry removes the retired record.
ResetState()
owner = NewOwner()
QueueEventConfig({})
assertTrue(Runtime:Attach(owner))
activeFrame = owner._eventFrame
activeFrame.config.failClearScript = true
activeFrame.config.failUnregister = true
ok, detail = Runtime:Detach(owner)
assertFalse(ok, "detach cleanup failure propagates")
assertContains(detail, "events:", "detach event detail")
assertEqual(owner._eventRecord, nil, "detach unpublishes record before cleanup")
assertFalse(owner._eventsAttached, "detach explicitly unattached")
local beforeRefresh = refreshCalls
activeFrame:Fire("PLAYER_ENTERING_WORLD")
assertEqual(refreshCalls, beforeRefresh, "stale detach callback inert")

activeFrame.config.failClearScript = false
activeFrame.config.failUnregister = false
ok, detail = Runtime:Detach(owner)
assertTrue(ok, detail)
assertEqual(owner._retiredEventRecords, nil, "detach retry cleans retired record")

-- Native restore and event teardown failures are both preserved in the result.
ResetState()
owner = NewOwner()
QueueEventConfig({})
assertTrue(Runtime:Attach(owner))
activeFrame = owner._eventFrame
activeFrame.config.failClearScript = true
activeFrame.config.failUnregister = true
restoreOK = false
ok, detail = Runtime:Detach(owner)
assertFalse(ok, "combined detach failure propagates")
assertContains(detail, "native restore: forced native restore failure", "native detach detail")
assertContains(detail, "events: CenterBars event cleanup failed", "event detach detail")

activeFrame.config.failClearScript = false
activeFrame.config.failUnregister = false
restoreOK = true
assertTrue(Runtime:Detach(owner))

-- Disabled ApplyConfig aggregates the same ownership failures and hides the
-- addon-owned frame while callbacks stay inert.
ResetState()
owner = NewOwner()
QueueEventConfig({})
assertTrue(Runtime:Attach(owner))
activeFrame = owner._eventFrame
activeFrame.config.failClearScript = true
activeFrame.config.failUnregister = true
restoreOK = false
config.enabled = false
ok, detail = Runtime:ApplyConfig(owner)
assertFalse(ok, "disabled apply cleanup failure propagates")
assertContains(detail, "native restore: forced native restore failure", "disabled native detail")
assertContains(detail, "events: CenterBars event cleanup failed", "disabled event detail")
assertFalse(owner.frame.shown, "disabled apply hides owned frame")
activeFrame:Fire("PLAYER_ENTERING_WORLD")
assertEqual(refreshCalls, 0, "disabled stale callback inert")

activeFrame.config.failClearScript = false
activeFrame.config.failUnregister = false
restoreOK = true
ok, detail = Runtime:ApplyConfig(owner)
assertTrue(ok, detail)
assertEqual(owner._retiredEventRecords, nil, "disabled apply retry cleans event record")

-- Attach while disabled also reports an unresolved old generation instead of
-- silently claiming success.
ResetState()
owner = NewOwner()
QueueEventConfig({})
assertTrue(Runtime:Attach(owner))
activeFrame = owner._eventFrame
activeFrame.config.failClearScript = true
activeFrame.config.failUnregister = true
config.enabled = false
ok, detail = Runtime:Attach(owner)
assertFalse(ok, "disabled attach cleanup failure propagates")
assertContains(detail, "event cleanup failed", "disabled attach detail")
assertEqual(owner._eventRecord, nil, "disabled attach unpublishes stale owner")

print('CenterBars event lifecycle tests passed.')
