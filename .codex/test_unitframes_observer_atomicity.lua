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

local ns = {
    Media = {},
    Secret = { CanAccess = function() return true end },
    U = {
        TryNumber = function(value)
            if type(value) == "number" then return true, value end
            return false, nil
        end,
        Round = function(value) return math.floor(value + 0.5) end,
    },
    Log = {
        Warn = function() end,
        Info = function() end,
        Error = function() end,
    },
}

local function NewSignal(name)
    local signal = {
        name = name,
        hooks = {},
        hookCalls = {},
    }

    function signal:HookScript(scriptName, callback)
        self.hookCalls[scriptName] = (self.hookCalls[scriptName] or 0) + 1
        if self.failScript == scriptName then
            error("forced " .. scriptName .. " hook failure")
        end
        local list = self.hooks[scriptName]
        if not list then
            list = {}
            self.hooks[scriptName] = list
        end
        list[#list + 1] = callback
    end

    function signal:Trigger(scriptName)
        local list = self.hooks[scriptName] or {}
        for i = 1, #list do list[i](self) end
    end

    return signal
end

local observerQueue = {}
local observers = {}
local observerID = 0

local function QueueObserverConfig(config)
    observerQueue[#observerQueue + 1] = config or {}
end

local function NewObserver(config, parent)
    observerID = observerID + 1
    local observer = {
        id = observerID,
        config = config or {},
        parent = parent,
        script = nil,
        registrations = {},
        registerCalls = 0,
        unregisterCalls = 0,
        clearScriptCalls = 0,
    }

    function observer:SetScript(scriptName, callback)
        if scriptName ~= "OnEvent" then return end
        if callback == nil then
            self.clearScriptCalls = self.clearScriptCalls + 1
            if self.config.failClearScript then
                error("forced clear-script failure")
            end
        elseif self.config.failSetScript then
            error("forced SetScript failure")
        end
        self.script = callback
    end

    local function Register(self, method, event, unit)
        self.registerCalls = self.registerCalls + 1
        if self.config.failRegisterAt == self.registerCalls then
            if self.config.rejectRegistration then return false end
            error("forced registration failure")
        end
        self.registrations[#self.registrations + 1] = {
            method = method,
            event = event,
            unit = unit,
        }
        return true
    end

    function observer:RegisterEvent(event)
        return Register(self, "RegisterEvent", event, nil)
    end

    function observer:RegisterUnitEvent(event, unit)
        return Register(self, "RegisterUnitEvent", event, unit)
    end

    function observer:UnregisterAllEvents()
        self.unregisterCalls = self.unregisterCalls + 1
        if self.config.failUnregister then
            error("forced unregister failure")
        end
        self.registrations = {}
        return true
    end

    function observer:Fire(event, ...)
        if self.script then self.script(self, event, ...) end
    end

    observers[#observers + 1] = observer
    return observer
end

_G.CreateFrame = function(_, _, parent)
    local config = table.remove(observerQueue, 1) or {}
    if config.failCreate then error("forced observer creation failure") end
    return NewObserver(config, parent)
end

assert(loadfile('modules/UnitFramesTarget.lua'))('FeelsGoodUI', ns)
local Target = assert(ns.UnitFramesTarget)
Target:Configure({
    GetUnitFramesCfg = function() return {} end,
})

Target.UpdateUnitHealthColor = function(frame)
    frame.refreshCount = (frame.refreshCount or 0) + 1
end
Target.UpdateTargetInfoFrame = function(frame)
    frame.headerRefreshCount = (frame.headerRefreshCount or 0) + 1
end
Target.LayoutTargetHeader = function(frame)
    frame.layoutCount = (frame.layoutCount or 0) + 1
end
Target.ApplyTargetHeaderTextColor = function(frame)
    frame.colorCount = (frame.colorCount or 0) + 1
end

local function NewUnitFrame(unit, withHeader)
    local frame = {
        unit = unit,
        Health = {},
        refreshCount = 0,
    }
    if withHeader then
        frame.TargetHeader = {}
        frame.Buffs = NewSignal(unit .. "Buffs")
        frame.Debuffs = NewSignal(unit .. "Debuffs")
    end
    return frame
end

local function ObserverFor(frame)
    local record = Target._frameRegistry[frame]
    return record and record.observer or nil
end

-- Initial attach publishes one observer per frame and repeated attach is single.
local owner = {
    target = NewUnitFrame("target", true),
    focus = NewUnitFrame("focus", false),
    targettarget = NewUnitFrame("targettarget", false),
}
QueueObserverConfig({})
QueueObserverConfig({})
QueueObserverConfig({})
local ok, detail = Target.AttachOwner(owner)
assertTrue(ok, detail)
assertEqual(#observers, 3, "three observers created")
assertEqual(owner.target.Buffs.hookCalls.OnShow, 1, "buff OnShow hooked once")
assertEqual(owner.target.Buffs.hookCalls.OnHide, 1, "buff OnHide hooked once")
assertTrue(Target._frameRegistry[owner.target].active, "target record active")
assertEqual(Target._ownerRegistry[owner].target, owner.target, "target owner published")

local firstTargetObserver = ObserverFor(owner.target)
firstTargetObserver:Fire("PLAYER_TARGET_CHANGED")
assertEqual(owner.target.refreshCount, 1, "active observer dispatches")

ok, detail = Target.AttachOwner(owner)
assertTrue(ok, detail)
assertEqual(#observers, 3, "repeat attach creates no observers")
assertEqual(owner.target.Buffs.hookCalls.OnShow, 1, "repeat attach creates no header hook")

-- Header partial failure publishes neither frame mapping nor observer; retry adds
-- only the missing permanent edge.
do
    local partialTarget = NewUnitFrame("target", true)
    partialTarget.Buffs.failScript = "OnHide"
    local partialOwner = { target = partialTarget }

    ok, detail = Target.AttachOwner(partialOwner)
    assertFalse(ok, "partial header hook fails attach")
    assertContains(detail, "OnHide hook failed", "partial hook detail")
    assertEqual(ObserverFor(partialTarget), nil, "observer unpublished after hook failure")
    partialTarget.Buffs:Trigger("OnShow")
    assertEqual(partialTarget.layoutCount, nil, "partial hook callback remains inert")
    assertEqual(partialTarget.Buffs.hookCalls.OnShow, 1, "successful OnShow edge single")

    partialTarget.Buffs.failScript = nil
    QueueObserverConfig({})
    ok, detail = Target.AttachOwner(partialOwner)
    assertTrue(ok, detail)
    assertEqual(partialTarget.Buffs.hookCalls.OnShow, 1, "retry does not duplicate OnShow")
    assertEqual(partialTarget.Buffs.hookCalls.OnHide, 2, "retry installs missing OnHide")
    assertTrue(Target.DetachOwner(partialOwner))
end

-- Failed target replacement keeps every prior owner active and cleans the
-- unpublished partial observer.
do
    local oldTarget = owner.target
    local oldObserver = ObserverFor(oldTarget)
    local replacement = NewUnitFrame("target", true)
    owner.target = replacement
    QueueObserverConfig({ failRegisterAt = 3 })

    ok, detail = Target.AttachOwner(owner)
    assertFalse(ok, "registration failure propagates")
    assertContains(detail, "registration failed", "registration failure detail")
    assertEqual(Target._ownerRegistry[owner].target, oldTarget, "old target owner retained")
    assertTrue(Target._frameRegistry[oldTarget].active, "old target remains active")
    assertEqual(ObserverFor(replacement), nil, "failed replacement unpublished")
    assertEqual(oldObserver.unregisterCalls, 0, "old observer never torn down before prepare")

    local failedObserver = observers[#observers]
    local before = replacement.refreshCount
    failedObserver:Fire("PLAYER_TARGET_CHANGED")
    assertEqual(replacement.refreshCount, before, "failed observer callback inert")

    QueueObserverConfig({})
    ok, detail = Target.AttachOwner(owner)
    assertTrue(ok, detail)
    assertEqual(Target._ownerRegistry[owner].target, replacement, "replacement published after retry")
    assertEqual(Target._frameRegistry[oldTarget].active, false, "old target retired after commit")
end

-- A later field failure rolls back only newly prepared frames and leaves the
-- complete previous owner set untouched.
do
    local previousTarget = owner.target
    local previousFocus = owner.focus
    local target2 = NewUnitFrame("target", true)
    local focus2 = NewUnitFrame("focus", false)
    owner.target = target2
    owner.focus = focus2
    QueueObserverConfig({})
    QueueObserverConfig({ failRegisterAt = 1, rejectRegistration = true })

    ok, detail = Target.AttachOwner(owner)
    assertFalse(ok, "multi-frame prepare failure propagates")
    assertContains(detail, "focus", "failed field identified")
    assertEqual(Target._ownerRegistry[owner].target, previousTarget, "previous target owner preserved")
    assertEqual(Target._ownerRegistry[owner].focus, previousFocus, "previous focus owner preserved")
    assertTrue(Target._frameRegistry[previousTarget].active, "previous target remains active")
    assertTrue(Target._frameRegistry[previousFocus].active, "previous focus remains active")
    assertEqual(Target._frameRegistry[target2].active, false, "prepared target rolled back")

    owner.target = previousTarget
    owner.focus = previousFocus
end

-- Cleanup failure commits the prepared replacement, gates the stale callback by
-- exact observer identity, and retries cleanup on the next reconciliation.
do
    local oldTarget = owner.target
    local oldObserver = ObserverFor(oldTarget)
    oldObserver.config.failClearScript = true
    oldObserver.config.failUnregister = true
    local replacement = NewUnitFrame("target", true)
    owner.target = replacement
    QueueObserverConfig({})

    ok, detail = Target.AttachOwner(owner)
    assertFalse(ok, "old cleanup failure propagates")
    assertContains(detail, "previous observer cleanup", "cleanup failure detail")
    assertEqual(Target._ownerRegistry[owner].target, replacement, "prepared replacement committed")
    assertTrue(Target._frameRegistry[replacement].active, "replacement active")
    assertEqual(Target._frameRegistry[oldTarget].active, false, "old record inactive before cleanup")

    local before = oldTarget.refreshCount
    oldObserver:Fire("PLAYER_TARGET_CHANGED")
    assertEqual(oldTarget.refreshCount, before, "stale callback gated despite failed cleanup")

    oldObserver.config.failClearScript = false
    oldObserver.config.failUnregister = false
    ok, detail = Target.AttachOwner(owner)
    assertTrue(ok, detail)
    assertEqual(#Target._frameRegistry[oldTarget].retiredObservers, 0, "retired observer cleanup retried")
end

-- Detach deactivates first, retains failed cleanup for retry, and finally drops
-- owner state only after cleanup succeeds.
do
    local activeTarget = owner.target
    local activeObserver = ObserverFor(activeTarget)
    activeObserver.config.failClearScript = true
    activeObserver.config.failUnregister = true

    ok, detail = Target.DetachOwner(owner)
    assertFalse(ok, "detach cleanup failure propagates")
    assertContains(detail, "UnregisterAllEvents failed", "detach cleanup detail")
    assertEqual(Target._frameRegistry[activeTarget].active, false, "detach gates record before cleanup")
    assertTrue(Target._ownerRegistry[owner] ~= nil, "owner record retained for cleanup retry")

    local before = activeTarget.refreshCount
    activeObserver:Fire("PLAYER_TARGET_CHANGED")
    assertEqual(activeTarget.refreshCount, before, "failed-detach callback remains inert")

    activeObserver.config.failClearScript = false
    activeObserver.config.failUnregister = false
    ok, detail = Target.DetachOwner(owner)
    assertTrue(ok, detail)
    assertEqual(Target._ownerRegistry[owner], nil, "owner record released after retry")
end

-- Runtime surfaces observer teardown failures together with unit-watch cleanup.
do
    ns.DB = { defaults = { profile = { unitframes = {} } } }
    ns.Media.FetchStatusbar = function(_, token) return token end
    ns.Media.ApplyFont = function() end
    ns.Movers = {}
    _G.InCombatLockdown = function() return false end

    assert(loadfile('modules/UnitFramesRuntime.lua'))('FeelsGoodUI', ns)
    local Runtime = assert(ns.UnitFramesRuntime)
    local cfg = { enabled = false }
    Runtime:Configure({
        GetUnitFramesCfg = function() return cfg end,
    })

    local originalDetach = Target.DetachOwner
    Target.DetachOwner = function() return false, "forced observer cleanup failure" end

    local hidden = false
    local runtimeOwner = {
        _eventsAttached = true,
        player = {
            Hide = function() hidden = true end,
        },
        RefreshCache = function() end,
    }

    ok, detail = Runtime:Detach(runtimeOwner)
    assertFalse(ok, "runtime detach propagates observer failure")
    assertContains(detail, "observers: forced observer cleanup failure", "runtime detach detail")
    assertTrue(hidden, "runtime still hides owned frame")

    runtimeOwner._eventsAttached = true
    ok, detail = Runtime:ApplyConfig(runtimeOwner)
    assertFalse(ok, "disabled apply propagates observer failure")
    assertContains(detail, "observers: forced observer cleanup failure", "disabled apply detail")

    Target.DetachOwner = originalDetach
end

print('UnitFrames observer atomicity tests passed.')
