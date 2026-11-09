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

local registrations = setmetatable({}, { __mode = "k" })
local attempts = setmetatable({}, { __mode = "k" })
local failures = setmetatable({}, { __mode = "k" })

local function Record(target, method)
    local byMethod = registrations[target]
    if not byMethod then
        byMethod = {}
        registrations[target] = byMethod
    end
    byMethod[method] = byMethod[method] or {}
    return byMethod[method]
end

local function SetFailure(target, method, count)
    failures[target] = failures[target] or {}
    failures[target][method] = count
end

local function HookCount(target, method)
    local byMethod = registrations[target]
    return byMethod and byMethod[method] and #byMethod[method] or 0
end

local function AttemptCount(target, method)
    local byMethod = attempts[target]
    return byMethod and byMethod[method] or 0
end

local function Fire(target, method, ...)
    local callbacks = registrations[target] and registrations[target][method] or {}
    for i = 1, #callbacks do callbacks[i](...) end
end

_G = _G or {}
_G.InCombatLockdown = function() return false end
_G.GetActionInfo = function() return "spell" end
_G.hooksecurefunc = function(target, method, callback)
    attempts[target] = attempts[target] or {}
    attempts[target][method] = (attempts[target][method] or 0) + 1
    local remaining = failures[target] and failures[target][method] or 0
    if remaining > 0 then
        failures[target][method] = remaining - 1
        error("injected " .. tostring(method) .. " hook failure")
    end
    Record(target, method)[#Record(target, method) + 1] = callback
end

local actionMixin = {
    UpdateState = function() end,
    UpdateUsable = function() end,
    UpdateAction = function() end,
}
local baseMixin = { SetShowGrid = function() end }
local spellManager = {
    ShowAlert = function() end,
    HideAlert = function() end,
}
local movers = { SetUnlocked = function() end }
_G.ActionBarActionButtonMixin = actionMixin
_G.BaseActionButtonMixin = baseMixin
_G.ActionButtonSpellAlertManager = spellManager
_G.EventRegistry = nil

local visualCalls = 0
local ns = {
    Movers = movers,
    ActionBarsVisuals = {
        RefreshButtonVisualState = function()
            visualCalls = visualCalls + 1
            return true
        end,
    },
}
assert(loadfile("modules/ActionBarsState.lua"))("FeelsGoodUI", ns)
local State = assert(ns.ActionBarsState)
assertEqual(getmetatable(State._secureHookRegistry).__mode, "k", "secure hook registry mode")

local moduleA = { _detached = false, refreshCalls = 0, autoCalls = 0 }
function moduleA:RefreshEmptySlots() self.refreshCalls = self.refreshCalls + 1 end
function moduleA:UpdateAutoHideState() self.autoCalls = self.autoCalls + 1 end
local moduleB = { _detached = false, refreshCalls = 0, autoCalls = 0 }
function moduleB:RefreshEmptySlots() self.refreshCalls = self.refreshCalls + 1 end
function moduleB:UpdateAutoHideState() self.autoCalls = self.autoCalls + 1 end

SetFailure(actionMixin, "UpdateUsable", 1)
local ok, detail = State.EnsureStateHooks(moduleA, false)
assertEqual(ok, false, "partial state hook result")
assertContains(detail, "UpdateUsable", "partial state hook detail")
assertEqual(HookCount(actionMixin, "UpdateState"), 1, "UpdateState registered")
assertEqual(HookCount(actionMixin, "UpdateUsable"), 0, "failed UpdateUsable unpublished")
assertEqual(HookCount(actionMixin, "UpdateAction"), 1, "UpdateAction fallback registered")
assertEqual(HookCount(baseMixin, "SetShowGrid"), 1, "SetShowGrid registered")
assertEqual(HookCount(movers, "SetUnlocked"), 1, "Movers hook registered")
assertEqual(HookCount(spellManager, "ShowAlert"), 1, "ShowAlert registered")
assertEqual(HookCount(spellManager, "HideAlert"), 1, "HideAlert registered")
assertEqual(rawget(moduleA, "_stateHooksAttached"), nil, "state summary marker absent")

ok, detail = State.EnsureStateHooks(moduleA, false)
assertEqual(ok, true, "state hook retry succeeds")
assertEqual(detail, nil, "state hook retry detail")
assertEqual(HookCount(actionMixin, "UpdateUsable"), 1, "missing UpdateUsable registered once")
assertEqual(AttemptCount(actionMixin, "UpdateState"), 1, "successful UpdateState not retried")
assertEqual(AttemptCount(actionMixin, "UpdateUsable"), 2, "failed UpdateUsable retried once")
assertEqual(HookCount(movers, "SetUnlocked"), 1, "Movers hook not duplicated")

ok = State.EnsureStateHooks(moduleB, false)
assertEqual(ok, true, "owner replacement succeeds")
assertEqual(HookCount(actionMixin, "UpdateState"), 1, "owner replacement reuses UpdateState hook")
assertEqual(HookCount(movers, "SetUnlocked"), 1, "owner replacement reuses Movers hook")
Fire(movers, "SetUnlocked", movers, true)
assertEqual(moduleA.refreshCalls, 0, "old owner refresh inert")
assertEqual(moduleB.refreshCalls, 1, "current owner refresh called")
assertEqual(moduleB.autoCalls, 1, "current owner auto-hide called")

local button = {}
local record = State.GetButtonRecord(button, true)
record.layers.pressed = {
    shown = false,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown = false end,
}
local overlay = {
    alpha = 1,
    hidden = false,
    SetAlpha = function(self, value) self.alpha = value end,
    Hide = function(self) self.hidden = true end,
}
button.SpellActivationAlert = overlay
Fire(spellManager, "ShowAlert", spellManager, button)
assertEqual(record.layers.pressed.shown, true, "current owner spell alert shown")
assertEqual(overlay.alpha, 0, "native overlay alpha suppressed")
assertEqual(overlay.hidden, true, "native overlay hidden")
Fire(spellManager, "HideAlert", spellManager, button)
assertEqual(record.layers.pressed.shown, false, "current owner spell alert hidden")

Fire(actionMixin, "UpdateState", button)
assertEqual(visualCalls, 1, "state callback runs for current owner")
moduleB._detached = true
Fire(actionMixin, "UpdateState", button)
assertEqual(visualCalls, 1, "detached owner callback inert")
moduleB._detached = false
assertEqual(State.ReleaseStateHookOwner(moduleB), true, "state owner released")
Fire(movers, "SetUnlocked", movers, false)
assertEqual(moduleB.refreshCalls, 1, "released owner callback inert")

-- Replacement target gets its own hook record without touching the old target.
local replacementSpellManager = {
    ShowAlert = function() end,
    HideAlert = function() end,
}
_G.ActionButtonSpellAlertManager = replacementSpellManager
assertEqual(State.EnsureStateHooks(moduleA, false), true, "replacement target registration")
assertEqual(HookCount(replacementSpellManager, "ShowAlert"), 1, "replacement ShowAlert registered")
assertEqual(HookCount(replacementSpellManager, "HideAlert"), 1, "replacement HideAlert registered")
assertEqual(HookCount(spellManager, "ShowAlert"), 1, "old target remains single")

-- With a real action-change callback, a fresh mixin does not receive UpdateAction fallback.
local replacementActionMixin = {
    UpdateState = function() end,
    UpdateUsable = function() end,
    UpdateAction = function() end,
}
_G.ActionBarActionButtonMixin = replacementActionMixin
assertEqual(State.EnsureStateHooks(moduleA, true), true, "registered callback state hooks")
assertEqual(HookCount(replacementActionMixin, "UpdateState"), 1, "replacement UpdateState registered")
assertEqual(HookCount(replacementActionMixin, "UpdateUsable"), 1, "replacement UpdateUsable registered")
assertEqual(HookCount(replacementActionMixin, "UpdateAction"), 0, "UpdateAction fallback skipped")

print("ActionBars global state hook tests passed.")
