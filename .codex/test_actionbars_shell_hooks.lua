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

local secureHooks = setmetatable({}, { __mode = "k" })
local secureAttempts = setmetatable({}, { __mode = "k" })
local secureFailures = setmetatable({}, { __mode = "k" })

local function SetSecureFailure(target, method, count)
    secureFailures[target] = secureFailures[target] or {}
    secureFailures[target][method] = count
end

local function SecureCount(target, method)
    return secureHooks[target] and secureHooks[target][method] and #secureHooks[target][method] or 0
end

local function SecureAttemptCount(target, method)
    return secureAttempts[target] and secureAttempts[target][method] or 0
end

local function FireSecure(target, method, ...)
    local callbacks = secureHooks[target] and secureHooks[target][method] or {}
    for i = 1, #callbacks do callbacks[i](...) end
end

local function NewScriptTarget(failures)
    local target = { hooks = {}, attempts = {}, failures = failures or {} }
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
    return target
end

local function ScriptCount(target, event)
    return #(target.hooks[event] or {})
end

local function FireScript(target, event, ...)
    for i = 1, #(target.hooks[event] or {}) do
        target.hooks[event][i](target, ...)
    end
end

_G = _G or {}
_G.InCombatLockdown = function() return false end
_G.CreateFrame = function()
    return { Hide = function(self) self.hidden = true end }
end
_G.hooksecurefunc = function(target, method, callback)
    secureAttempts[target] = secureAttempts[target] or {}
    secureAttempts[target][method] = (secureAttempts[target][method] or 0) + 1
    local remaining = secureFailures[target] and secureFailures[target][method] or 0
    if remaining > 0 then
        secureFailures[target][method] = remaining - 1
        error("injected " .. tostring(method) .. " failure")
    end
    secureHooks[target] = secureHooks[target] or {}
    secureHooks[target][method] = secureHooks[target][method] or {}
    secureHooks[target][method][#secureHooks[target][method] + 1] = callback
end

local endCapsMixin = { UpdateEndCaps = function() end }
local settingsMixin = { TransitionBackOpeningPanel = function() end }
local settingsPanel = NewScriptTarget({ OnHide = 1 })
_G.MainActionBarMixin = endCapsMixin
_G.SettingsPanelMixin = settingsMixin
_G.SettingsPanel = settingsPanel
_G.MainMenuBarArtFrame_UpdateEndCaps = nil

local ns = {
    DB = {
        ReadSection = function(_, section)
            if section == "actionbars" then return { hideBlizzard = true } end
            return nil
        end,
        ShouldHideBlizzardActionBars = function() return true end,
    },
    Safety = {
        CancelDebounce = function() return true end,
        Debounce = function(_, _, callback) callback(); return true end,
    },
}
assert(loadfile("modules/ActionBarsBlizzardShell.lua"))("FeelsGoodUI", ns)
local Shell = assert(ns.ActionBarsBlizzardShell)
assertEqual(getmetatable(Shell._secureHookRegistry).__mode, "k", "shell secure registry mode")
assertEqual(getmetatable(Shell._scriptHookRegistry).__mode, "k", "shell script registry mode")

local kicks = {}
Shell.KickHideBlizzardArt = function(module)
    kicks[#kicks + 1] = module
    return true
end
Shell.ShouldHideBlizzardArt = function() return true end

local moduleA = { _detached = false, applyCalls = 0 }
function moduleA:ApplyConfig() self.applyCalls = self.applyCalls + 1; return true end
local moduleB = { _detached = false, applyCalls = 0 }
function moduleB:ApplyConfig() self.applyCalls = self.applyCalls + 1; return true end

SetSecureFailure(endCapsMixin, "UpdateEndCaps", 1)
local ok, detail = Shell.EnsureEndCapsHook(moduleA)
assertEqual(ok, false, "partial EndCaps registration fails")
assertContains(detail, "UpdateEndCaps", "EndCaps detail")
assertEqual(SecureCount(endCapsMixin, "UpdateEndCaps"), 0, "failed EndCaps edge unpublished")
assertEqual(rawget(moduleA, "_endCapsHooked"), nil, "EndCaps marker absent")

ok, detail = Shell.EnsureEndCapsHook(moduleA)
assertEqual(ok, true, "EndCaps retry succeeds")
assertEqual(detail, nil, "EndCaps retry detail")
assertEqual(SecureCount(endCapsMixin, "UpdateEndCaps"), 1, "EndCaps hook installed once")
assertEqual(SecureAttemptCount(endCapsMixin, "UpdateEndCaps"), 2, "EndCaps failure retried once")

SetSecureFailure(settingsMixin, "TransitionBackOpeningPanel", 1)
ok, detail = Shell.EnsureSettingsHooks(moduleA)
assertEqual(ok, false, "partial settings registration fails")
assertContains(detail, "SettingsPanel.OnHide", "settings first detail")
assertEqual(ScriptCount(settingsPanel, "OnHide"), 0, "failed panel edge unpublished")
assertEqual(SecureCount(settingsMixin, "TransitionBackOpeningPanel"), 0, "failed mixin edge unpublished")
assertEqual(rawget(moduleA, "_settingsPanelHooked"), nil, "settings panel marker absent")
assertEqual(rawget(moduleA, "_settingsTransitionHooked"), nil, "settings mixin marker absent")
assertEqual(rawget(moduleA, "_settingsShellRepair"), nil, "settings callback marker absent")

ok, detail = Shell.EnsureSettingsHooks(moduleA)
assertEqual(ok, true, "settings retry succeeds")
assertEqual(ScriptCount(settingsPanel, "OnHide"), 1, "panel hook installed once")
assertEqual(SecureCount(settingsMixin, "TransitionBackOpeningPanel"), 1, "mixin hook installed once")
assertEqual(settingsPanel.attempts.OnHide, 2, "panel failure retried once")
assertEqual(SecureAttemptCount(settingsMixin, "TransitionBackOpeningPanel"), 2, "mixin failure retried once")

assertEqual(Shell.EnsureEndCapsHook(moduleB), true, "EndCaps owner replacement succeeds")
assertEqual(Shell.EnsureSettingsHooks(moduleB), true, "settings owner replacement succeeds")
assertEqual(SecureCount(endCapsMixin, "UpdateEndCaps"), 1, "EndCaps hook not duplicated")
assertEqual(ScriptCount(settingsPanel, "OnHide"), 1, "settings panel hook not duplicated")
assertEqual(SecureCount(settingsMixin, "TransitionBackOpeningPanel"), 1, "settings mixin hook not duplicated")

FireSecure(endCapsMixin, "UpdateEndCaps", endCapsMixin)
assertEqual(kicks[#kicks], moduleB, "EndCaps callback resolves current owner")
FireScript(settingsPanel, "OnHide")
assertEqual(moduleA.applyCalls, 0, "old settings owner inert")
assertEqual(moduleB.applyCalls, 1, "current settings owner applied")
FireSecure(settingsMixin, "TransitionBackOpeningPanel", settingsMixin)
assertEqual(moduleB.applyCalls, 2, "settings mixin callback uses current owner")

assertEqual(Shell.ReleaseHookOwner(moduleB), true, "shell owner released")
local kickCount = #kicks
FireSecure(endCapsMixin, "UpdateEndCaps", endCapsMixin)
FireScript(settingsPanel, "OnHide")
assertEqual(#kicks, kickCount, "released EndCaps callback inert")
assertEqual(moduleB.applyCalls, 2, "released settings callback inert")

-- Replaced SettingsPanel gets its own hook record; old target remains single.
local replacementPanel = NewScriptTarget()
_G.SettingsPanel = replacementPanel
assertEqual(Shell.EnsureSettingsHooks(moduleA), true, "replacement panel registration succeeds")
assertEqual(ScriptCount(replacementPanel, "OnHide"), 1, "replacement panel hooked")
assertEqual(ScriptCount(settingsPanel, "OnHide"), 1, "old panel hook remains single")
FireScript(replacementPanel, "OnHide")
assertEqual(moduleA.applyCalls, 1, "replacement panel uses current owner")

-- Detached active owner is inert without changing permanent hook records.
moduleA._detached = true
FireSecure(endCapsMixin, "UpdateEndCaps", endCapsMixin)
FireScript(replacementPanel, "OnHide")
assertEqual(moduleA.applyCalls, 1, "detached shell owner inert")
assertEqual(#kicks, kickCount, "detached EndCaps owner inert")

print("ActionBars shell hook ownership tests passed.")
