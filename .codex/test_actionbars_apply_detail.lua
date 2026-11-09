local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertContains(value, needle, label)
    value = tostring(value)
    if not string.find(value, needle, 1, true) then
        error((label or "value") .. ": expected " .. string.format("%q", needle) .. " in " .. string.format("%q", value), 2)
    end
end

_G = _G or {}
_G.InCombatLockdown = function() return false end

local function NewButton(id)
    local button = {
        id = id,
        skinCalls = 0,
        refreshCalls = 0,
        autoHookCalls = 0,
        shown = true,
    }
    function button:ClearAllPoints() end
    function button:SetParent(parent) self.parent = parent end
    function button:SetSize(width, height) self.width, self.height = width, height end
    function button:Show() self.shown = true end
    function button:Hide() self.shown = false end
    function button:SetPoint(...) self.point = { ... } end
    function button:EnableMouse(enabled) self.mouseEnabled = enabled == true end
    return button
end

local buttons = {}
for i = 1, 12 do
    local button = NewButton(i)
    buttons[i] = button
    _G["ActionButton" .. tostring(i)] = button
end

local function NewHolder(id)
    local holder = {
        id = id,
        buttons = {},
        shown = true,
        strata = "LOW",
        level = 10,
    }
    function holder:SetSize(width, height) self.width, self.height = width, height end
    function holder:Show() self.shown = true end
    function holder:Hide() self.shown = false end
    function holder:GetFrameStrata() return self.strata end
    function holder:SetFrameStrata(value) self.strata = value end
    function holder:GetFrameLevel() return self.level end
    function holder:SetFrameLevel(value) self.level = value end
    return holder
end

local cfg = {
    autoHide = { enabled = false },
    buttonSize = 32,
    spacing = 0,
    showHotkeys = true,
    hideBlizzard = false,
    bars = {
        [1] = { enabled = true, prefix = "ActionButton", buttons = 12, rows = 1 },
        [2] = { enabled = false },
        [3] = { enabled = false },
        [4] = { enabled = false },
        [5] = { enabled = false },
    },
}

local warnings = {}
local ns = {
    Log = {
        Warn = function(_, message) warnings[#warnings + 1] = tostring(message) end,
        Error = function(_, message) warnings[#warnings + 1] = tostring(message) end,
    },
    DB = {
        ReadSection = function(_, section)
            if section == "actionbars" then return cfg end
            return nil
        end,
        ShouldHideBlizzardActionBars = function() return false end,
    },
    ActionBarsEditMode = {
        ResolveBarSpacing = function(value) return tonumber(value) or 0 end,
    },
    ActionBarsBlizzardShell = {
        EnsureBlizzardMultiBars = function() return true end,
        EnsureSettingsHooks = function() return true end,
        ShouldHideBlizzardArt = function() return false end,
        RestoreBlizzardArt = function() return true end,
    },
}

ns.ActionBarsVisuals = {
    BuildStyleConfig = function() return {} end,
    SkinButton = function(button)
        button.skinCalls = button.skinCalls + 1
        if button.failSkin then
            return false, "injected skin failure"
        end
        return true
    end,
    RefreshButtonVisualState = function(button)
        button.refreshCalls = button.refreshCalls + 1
        if button.failRefresh then
            return false, "injected refresh failure"
        end
        return true
    end,
    SetButtonHotkey = function() return true end,
}

ns.ActionBarsState = {
    AttachButtonAutoHideHooks = function(button)
        button.autoHookCalls = button.autoHookCalls + 1
        if button.failAutoHook then
            return false, "injected button hook failure"
        end
        return true
    end,
}

assert(loadfile("modules/ActionBarsRuntime.lua"))("FeelsGoodUI", ns)
local Runtime = assert(ns.ActionBarsRuntime)

local module = {
    bars = {},
    hookFailure = nil,
    _detached = nil,
}
for i = 1, 5 do module.bars[i] = NewHolder(i) end
function module:EnsureCreated() end
function module:EnsureAutoHideHooks()
    if self.hookFailure then return false, self.hookFailure end
    return true
end
function module:RefreshEmptySlots() self.refreshEmptyCalls = (self.refreshEmptyCalls or 0) + 1 end
function module:UpdateAutoHideState() self.autoHideUpdateCalls = (self.autoHideUpdateCalls or 0) + 1 end

module.hookFailure = "holder hook exploded"
local ok, detail = Runtime.ApplyNow(module)
assertEqual(ok, false, "holder hook failure result")
assertContains(detail, "holder hook exploded", "holder hook detail")
assertEqual(buttons[1].skinCalls, 0, "button work does not start after holder failure")

module.hookFailure = nil
buttons[3].failSkin = true
ok, detail = Runtime.ApplyNow(module)
assertEqual(ok, false, "skin failure result")
assertContains(detail, "ActionBar 1", "skin bar detail")
assertContains(detail, "ActionButton3", "skin button detail")
assertContains(detail, "injected skin failure", "skin root detail")
assertEqual(buttons[3].refreshCalls, 0, "failed skin skips duplicate visual initialization")
assertEqual(module.bars[1].shown, false, "failed holder hidden")

buttons[3].failSkin = nil
buttons[4].failAutoHook = true
ok, detail = Runtime.ApplyConfig(module)
assertEqual(ok, false, "button hook ApplyConfig result")
assertContains(detail, "ActionButton4", "button hook identity detail")
assertContains(detail, "injected button hook failure", "button hook root detail")
assertEqual(module._pending, true, "failed ApplyConfig stays pending")

module._pending = nil
buttons[4].failAutoHook = nil
buttons[2].failRefresh = true
ok, detail = Runtime.PreviewMoverLayout(module, 36, 2)
assertEqual(ok, false, "preview refresh failure result")
assertContains(detail, "ActionBar 1", "preview bar detail")
assertContains(detail, "ActionButton2", "preview button detail")
assertContains(detail, "injected refresh failure", "preview root detail")

buttons[2].failRefresh = nil
ok, detail = Runtime.ApplyConfig(module)
assertEqual(ok, true, "successful ApplyConfig")
assertEqual(detail, nil, "successful ApplyConfig detail")
assertEqual(module._pending, nil, "successful ApplyConfig not pending")
assertEqual(module.bars[1].shown, true, "successful holder shown")
assertEqual(module.refreshEmptyCalls, 1, "successful empty-slot refresh")
assertEqual(module.autoHideUpdateCalls, 1, "successful auto-hide refresh")
assertEqual(#warnings >= 1, true, "holder hook failure logged")

print("ActionBars apply detail propagation tests passed.")
