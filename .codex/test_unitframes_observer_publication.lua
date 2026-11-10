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
}

local function NewSignal()
    local signal = { hooks = {}, calls = {} }
    function signal:HookScript(name, callback)
        self.calls[name] = (self.calls[name] or 0) + 1
        local list = self.hooks[name]
        if not list then
            list = {}
            self.hooks[name] = list
        end
        list[#list + 1] = callback
    end
    function signal:Trigger(name)
        local list = self.hooks[name] or {}
        for i = 1, #list do list[i](self) end
    end
    return signal
end

local observerQueue = {}
local observers = {}
local function QueueObserver(config)
    observerQueue[#observerQueue + 1] = config or {}
end

_G.CreateFrame = function(_, _, parent)
    local config = table.remove(observerQueue, 1) or {}
    local observer = {
        config = config,
        parent = parent,
        registrations = {},
        registerCalls = 0,
    }

    function observer:SetScript(name, callback)
        if name ~= "OnEvent" then return end
        if callback == nil and self.config.failClearScript then
            error("forced clear-script failure")
        end
        self.script = callback
    end

    local function Register(self, method, event, unit)
        self.registerCalls = self.registerCalls + 1
        if self.config.failRegisterAt == self.registerCalls then
            error("forced registration failure")
        end
        self.registrations[#self.registrations + 1] = { method, event, unit }
    end

    function observer:RegisterEvent(event)
        Register(self, "RegisterEvent", event, nil)
    end

    function observer:RegisterUnitEvent(event, unit)
        Register(self, "RegisterUnitEvent", event, unit)
    end

    function observer:UnregisterAllEvents()
        if self.config.failUnregister then
            error("forced unregister failure")
        end
        self.registrations = {}
    end

    function observer:Fire(event, ...)
        if self.script then self.script(self, event, ...) end
    end

    observers[#observers + 1] = observer
    return observer
end

assert(loadfile('modules/UnitFramesTarget.lua'))('FeelsGoodUI', ns)
local Target = assert(ns.UnitFramesTarget)
Target:Configure({ GetUnitFramesCfg = function() return {} end })
Target.UpdateTargetInfoFrame = function(frame)
    frame.infoRefresh = (frame.infoRefresh or 0) + 1
end
Target.UpdateUnitHealthColor = function(frame)
    frame.healthRefresh = (frame.healthRefresh or 0) + 1
end
Target.LayoutTargetHeader = function(frame)
    frame.layoutRefresh = (frame.layoutRefresh or 0) + 1
end
Target.ApplyTargetHeaderTextColor = function(frame)
    frame.colorRefresh = (frame.colorRefresh or 0) + 1
end

local function NewTarget(buffs, debuffs)
    return {
        unit = "target",
        Health = {},
        TargetHeader = {},
        Buffs = buffs or NewSignal(),
        Debuffs = debuffs or NewSignal(),
    }
end

local owner = { target = NewTarget() }
QueueObserver({})
local ok, detail = Target.AttachOwner(owner)
assertTrue(ok, detail)
local original = owner.target
local originalObserver = Target._frameRegistry[original].observer

-- Reuse the exact aura containers. Failed observer preparation must not move
-- their permanent callbacks away from the still-active previous frame.
local replacement = NewTarget(original.Buffs, original.Debuffs)
owner.target = replacement
QueueObserver({ failRegisterAt = 2 })
ok, detail = Target.AttachOwner(owner)
assertFalse(ok, "replacement registration failure propagates")
assertContains(detail, "registration failed", "replacement failure detail")
assertEqual(Target._ownerRegistry[owner].target, original, "previous owner retained")

local oldLayout = original.layoutRefresh or 0
local newLayout = replacement.layoutRefresh or 0
original.Buffs:Trigger("OnShow")
assertEqual(original.layoutRefresh, oldLayout + 1, "shared header hook remains on previous owner")
assertEqual(replacement.layoutRefresh or 0, newLayout, "failed replacement receives no header dispatch")
assertEqual(originalObserver.unregisterCalls, nil, "previous observer not cleaned before commit")

QueueObserver({})
ok, detail = Target.AttachOwner(owner)
assertTrue(ok, detail)
assertEqual(Target._ownerRegistry[owner].target, replacement, "replacement published after full prepare")
oldLayout = original.layoutRefresh or 0
newLayout = replacement.layoutRefresh or 0
original.Buffs:Trigger("OnShow")
assertEqual(original.layoutRefresh or 0, oldLayout, "shared hook leaves retired owner")
assertEqual(replacement.layoutRefresh, newLayout + 1, "shared hook follows committed owner")

-- Malformed frame identity is a hard prepare failure, never a silent removal of
-- the current observer owner.
local committed = owner.target
owner.target = { unit = "party1" }
ok, detail = Target.AttachOwner(owner)
assertFalse(ok, "unsupported observed unit rejected")
assertContains(detail, "unit is unavailable or unsupported", "unsupported unit detail")
assertEqual(Target._ownerRegistry[owner].target, committed, "malformed replacement preserves owner")
owner.target = committed

-- If registration and immediate cleanup both fail, the unpublished observer is
-- retained in the owner's retry set. Its callback is inert because it never
-- became the exact record observer.
local leaking = NewTarget()
owner.target = leaking
QueueObserver({ failRegisterAt = 2, failClearScript = true, failUnregister = true })
ok, detail = Target.AttachOwner(owner)
assertFalse(ok, "failed prepare cleanup propagates")
assertContains(detail, "cleanup", "failed prepare cleanup detail")
local failedObserver = observers[#observers]
local ownerRecord = Target._ownerRegistry[owner]
assertTrue(ownerRecord.retiredFrames[leaking] == true, "failed prepare frame retained for cleanup")
local before = leaking.healthRefresh or 0
failedObserver:Fire("PLAYER_TARGET_CHANGED")
assertEqual(leaking.healthRefresh or 0, before, "unpublished observer callback inert")

owner.target = committed
failedObserver.config.failClearScript = false
failedObserver.config.failUnregister = false
ok, detail = Target.AttachOwner(owner)
assertTrue(ok, detail)
assertEqual(ownerRecord.retiredFrames[leaking], nil, "failed prepare cleanup retried")
assertEqual(Target._frameRegistry[leaking].retiredObservers, nil, "retired observer released")

assertTrue(Target.DetachOwner(owner))
print('UnitFrames observer publication tests passed.')
