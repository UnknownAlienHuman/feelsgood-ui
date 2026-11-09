local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertNil(value, label)
    if value ~= nil then
        error((label or "value") .. ": expected nil, got " .. tostring(value), 2)
    end
end

local function HookCount(target, event)
    return #(target.hooks[event] or {})
end

local function Fire(target, event, ...)
    local hooks = target.hooks[event] or {}
    for i = 1, #hooks do
        hooks[i](target, ...)
    end
end

local function NewHookTarget(failures)
    local target = {
        hooks = {},
        attempts = {},
        failures = failures or {},
        width = 620,
    }

    function target:HookScript(event, callback)
        self.attempts[event] = (self.attempts[event] or 0) + 1
        local remaining = tonumber(self.failures[event]) or 0
        if remaining > 0 then
            self.failures[event] = remaining - 1
            error("injected " .. event .. " failure")
        end
        self.hooks[event] = self.hooks[event] or {}
        self.hooks[event][#self.hooks[event] + 1] = callback
    end

    function target:EnableMouseWheel(enabled)
        self.enableAttempts = (self.enableAttempts or 0) + 1
        local remaining = tonumber(self.failures.EnableMouseWheel) or 0
        if remaining > 0 then
            self.failures.EnableMouseWheel = remaining - 1
            error("injected EnableMouseWheel failure")
        end
        self.mouseWheelEnabled = enabled == true
    end

    function target:GetWidth()
        return self.width
    end

    return target
end

local warnings = {}
local ns = {
    OptionsShared = {},
    Log = {
        Warn = function(_, message)
            warnings[#warnings + 1] = tostring(message)
        end,
    },
    L = function(text) return text end,
}

assert(loadfile("core/OptionsSharedHelpers.lua"))("FeelsGoodUI", ns)
local Shared = assert(ns.OptionsShared)

assertEqual(getmetatable(Shared._adaptiveOwnerRegistry).__mode, "k", "adaptive owner registry mode")
assertEqual(getmetatable(Shared._adaptiveWidgetRegistry).__mode, "k", "adaptive widget registry mode")
assertEqual(getmetatable(Shared._numericParentRegistry).__mode, "k", "numeric parent registry mode")
assertEqual(getmetatable(Shared._numericSliderRegistry).__mode, "k", "numeric slider registry mode")
assertEqual(getmetatable(Shared._wheelProxyRegistry).__mode, "k", "wheel registry mode")

-- Adaptive width: successful edges publish once; failed edges retry only themselves.
local ownerA = NewHookTarget({ OnSizeChanged = 1 })
local ownerB = NewHookTarget()
local widget = NewHookTarget({ OnShow = 1 })
local adaptiveCalls = {}
local function ApplyA(target, owner)
    adaptiveCalls[#adaptiveCalls + 1] = { target = target, owner = owner, tag = "A" }
end

local ok = Shared.HookAdaptiveWidth(widget, ownerA, ApplyA)
assertEqual(ok, false, "partial adaptive registration fails")
assertEqual(#adaptiveCalls, 1, "adaptive initial apply")
assertEqual(HookCount(ownerA, "OnSizeChanged"), 0, "failed size hook unpublished")
assertEqual(HookCount(ownerA, "OnShow"), 1, "owner show hook published")
assertEqual(HookCount(widget, "OnShow"), 0, "failed widget show hook unpublished")
assertNil(rawget(widget, "_fguiAdaptiveWidthHooked"), "adaptive widget marker absent")

ok = Shared.HookAdaptiveWidth(widget, ownerA, ApplyA)
assertEqual(ok, true, "adaptive retry succeeds")
assertEqual(HookCount(ownerA, "OnSizeChanged"), 1, "size hook installed once")
assertEqual(HookCount(ownerA, "OnShow"), 1, "owner show hook not duplicated")
assertEqual(HookCount(widget, "OnShow"), 1, "widget show hook installed once")
assertEqual(ownerA.attempts.OnSizeChanged, 2, "only failed size edge retried")
assertEqual(ownerA.attempts.OnShow, 1, "successful owner edge not retried")
assertEqual(widget.attempts.OnShow, 2, "only failed widget edge retried")

Fire(ownerA, "OnSizeChanged")
Fire(widget, "OnShow")
assertEqual(#adaptiveCalls, 4, "adaptive callbacks dispatch exactly once")

local function ApplyB(target, owner)
    adaptiveCalls[#adaptiveCalls + 1] = { target = target, owner = owner, tag = "B" }
end
ok = Shared.HookAdaptiveWidth(widget, ownerB, ApplyB)
assertEqual(ok, true, "adaptive owner replacement succeeds")
assertEqual(HookCount(widget, "OnShow"), 1, "owner replacement reuses widget hook")
local beforeOldOwner = #adaptiveCalls
Fire(ownerA, "OnShow")
assertEqual(#adaptiveCalls, beforeOldOwner, "old owner callback becomes inert")
Fire(ownerB, "OnShow")
assertEqual(adaptiveCalls[#adaptiveCalls].owner, ownerB, "new owner callback resolves current record")
Fire(widget, "OnShow")
assertEqual(adaptiveCalls[#adaptiveCalls].tag, "B", "widget callback resolves replacement apply function")

-- Numeric sync: slider and parent edges are independently retryable and marker-free.
local parentA = NewHookTarget({ OnShow = 1 })
local parentB = NewHookTarget()
local slider = NewHookTarget({ OnShow = 1 })
slider.value = 5
function slider:GetValue() return self.value end
local editA = { text = nil }
function editA:SetText(value) self.text = value end

ok = Shared.RegisterNumericSliderSync(slider, parentA, editA, function(value)
    return "v" .. tostring(value)
end)
assertEqual(ok, false, "partial numeric registration fails")
assertEqual(editA.text, "v5", "numeric initial sync")
assertEqual(HookCount(slider, "OnValueChanged"), 1, "numeric value edge published")
assertEqual(HookCount(slider, "OnShow"), 0, "failed numeric show edge unpublished")
assertEqual(HookCount(parentA, "OnShow"), 0, "failed parent edge unpublished")
assertNil(rawget(slider, "_fguiNumericParentHooked"), "numeric marker absent")

ok = Shared.RegisterNumericSliderSync(slider, parentA, editA, function(value)
    return "v" .. tostring(value)
end)
assertEqual(ok, true, "numeric retry succeeds")
assertEqual(HookCount(slider, "OnValueChanged"), 1, "numeric value edge not duplicated")
assertEqual(HookCount(slider, "OnShow"), 1, "numeric show edge installed once")
assertEqual(HookCount(parentA, "OnShow"), 1, "numeric parent edge installed once")
slider.value = 7
Fire(slider, "OnValueChanged")
assertEqual(editA.text, "v7", "slider event syncs edit box")

local editB = { text = nil }
function editB:SetText(value) self.text = value end
ok = Shared.RegisterNumericSliderSync(slider, parentB, editB, function(value)
    return "b" .. tostring(value)
end)
assertEqual(ok, true, "numeric parent replacement succeeds")
assertEqual(HookCount(slider, "OnValueChanged"), 1, "numeric replacement reuses slider value hook")
assertEqual(HookCount(slider, "OnShow"), 1, "numeric replacement reuses slider show hook")
local oldText = editB.text
Fire(parentA, "OnShow")
assertEqual(editB.text, oldText, "old numeric parent callback becomes inert")
slider.value = 9
Fire(parentB, "OnShow")
assertEqual(editB.text, "b9", "new numeric parent resolves current record")

-- Wheel proxy: EnableMouseWheel and HookScript publish independently, retry, and never duplicate.
local wheelFrame = NewHookTarget({ EnableMouseWheel = 1, OnMouseWheel = 1 })
local scrollA = {}
local scrollB = {}
local wheelCalls = {}
local function ScrollA(scroll, delta)
    wheelCalls[#wheelCalls + 1] = { scroll = scroll, delta = delta, tag = "A" }
end
local function ScrollB(scroll, delta)
    wheelCalls[#wheelCalls + 1] = { scroll = scroll, delta = delta, tag = "B" }
end

ok = Shared.AttachWheelProxy(wheelFrame, scrollA, ScrollA)
assertEqual(ok, false, "partial wheel registration fails")
assertEqual(HookCount(wheelFrame, "OnMouseWheel"), 0, "failed wheel hook unpublished")
assertEqual(wheelFrame.mouseWheelEnabled, nil, "failed mouse-wheel enable unpublished")
assertNil(rawget(wheelFrame, "_fguiWheelProxy"), "wheel marker absent")

ok = Shared.AttachWheelProxy(wheelFrame, scrollA, ScrollA)
assertEqual(ok, true, "wheel retry succeeds")
assertEqual(HookCount(wheelFrame, "OnMouseWheel"), 1, "wheel hook installed once")
assertEqual(wheelFrame.enableAttempts, 2, "mouse-wheel enable retried once")
Fire(wheelFrame, "OnMouseWheel", 2)
assertEqual(#wheelCalls, 1, "wheel callback dispatched once")
assertEqual(wheelCalls[1].scroll, scrollA, "wheel callback uses first owner")

ok = Shared.AttachWheelProxy(wheelFrame, scrollB, ScrollB)
assertEqual(ok, true, "wheel owner replacement succeeds")
assertEqual(HookCount(wheelFrame, "OnMouseWheel"), 1, "wheel replacement reuses permanent hook")
Fire(wheelFrame, "OnMouseWheel", -1)
assertEqual(#wheelCalls, 2, "replacement wheel callback dispatched once")
assertEqual(wheelCalls[2].scroll, scrollB, "wheel callback resolves current owner")
assertEqual(wheelCalls[2].tag, "B", "wheel callback resolves current function")

assertEqual(#warnings >= 3, true, "injected hook failures were reported")
print("Options hook registry tests passed.")
