local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertArray(actual, expected, label)
    assertEqual(#actual, #expected, (label or "array") .. " length")
    for i = 1, #expected do
        assertEqual(actual[i], expected[i], (label or "array") .. "[" .. i .. "]")
    end
end

_G = _G or {}
local inCombat = false
_G.InCombatLockdown = function() return inCombat end
_G.UIParent_ManageFramePositions = function() end

local currentToggles = { true, false, true, false, true }
local setCalls = {}
local multiUpdates = 0
_G.GetActionBarToggles = function()
    return unpack(currentToggles)
end
_G.SetActionBarToggles = function(...)
    local count = select("#", ...)
    local values = { ... }
    currentToggles = {}
    for i = 1, count do currentToggles[i] = values[i] end
    setCalls[#setCalls + 1] = values
end
_G.MultiActionBar_Update = function()
    multiUpdates = multiUpdates + 1
end

local function NewFrame()
    return {
        Hide = function(self) self.hidden = true end,
        Show = function(self) self.hidden = false end,
        SetAlpha = function() end,
        GetAlpha = function() return 1 end,
        IsShown = function() return true end,
        EnableMouse = function() end,
        IsMouseEnabled = function() return true end,
        GetParent = function() return nil end,
        SetParent = function() end,
        UnregisterAllEvents = function() end,
        SetScript = function() end,
    }
end
_G.CreateFrame = function() return NewFrame() end

local actionbars = {
    hideBlizzard = true,
    bars = {
        [1] = { enabled = true },
        [2] = { enabled = true },
        [3] = { enabled = true },
        [4] = { enabled = true },
        [5] = { enabled = true },
    },
}

local ns = {
    DB = {
        GetSection = function(_, name)
            if name == "actionbars" then return actionbars end
            return {}
        end,
        ShouldHideBlizzardActionBars = function() return true end,
    },
    Safety = {
        Debounce = function(_, _, fn) fn(); return true end,
        CancelDebounce = function() end,
    },
}

assert(loadfile('modules/ActionBarsBlizzardShell.lua'))('FeelsGoodUI', ns)
local Shell = assert(ns.ActionBarsBlizzardShell)
local module = {}
local barsBefore = {
    actionbars.bars[4].enabled,
    actionbars.bars[5].enabled,
}

assert(Shell.EnsureBlizzardMultiBars(module, actionbars.bars, true) == true)
assertEqual(#setCalls, 1, 'initial takeover writes once')
assertArray(currentToggles, { true, true, false, false, true }, 'managed toggles')
assertArray(module._nativeActionBarToggles.values, { true, false, true, false, true }, 'captured baseline')
assertEqual(actionbars.bars[4].enabled, barsBefore[1], 'bar 4 profile unchanged')
assertEqual(actionbars.bars[5].enabled, barsBefore[2], 'bar 5 profile unchanged')
assertEqual(Shell.ImportSideBarStateFromBlizzard, nil, 'implicit profile importer removed')

assert(Shell.EnsureBlizzardMultiBars(module, actionbars.bars, true) == true)
assertEqual(#setCalls, 1, 'identical apply does not rewrite toggles')

currentToggles[1] = false
assert(Shell.EnsureBlizzardMultiBars(module, actionbars.bars, true) == true)
assertEqual(#setCalls, 2, 'external drift repaired once')
assertArray(module._nativeActionBarToggles.values, { true, false, true, false, true }, 'baseline remains first snapshot')

module._detached = true
assert(Shell.RestoreBlizzardArt(module, actionbars.bars) == true)
assertArray(currentToggles, { true, false, true, false, true }, 'exact baseline restored')
assertEqual(module._nativeActionBarToggles, nil, 'baseline released after restore')

module._detached = nil
currentToggles = { false, true, false, true, false }
assert(Shell.EnsureBlizzardMultiBars(module, actionbars.bars, true) == true)
assertArray(module._nativeActionBarToggles.values, { false, true, false, true, false }, 'reattach captures new baseline')

-- Runtime config repair must be read-only.
local runtimeConfig = {
    autoHide = nil,
    hideBlizzard = false,
    buttonSize = 32,
    spacing = 0,
    showHotkeys = false,
    bars = {},
}
local function Holder()
    return {
        buttons = {},
        Hide = function(self) self.hidden = true end,
        Show = function(self) self.hidden = false end,
        GetFrameStrata = function() return 'LOW' end,
        SetFrameStrata = function() end,
        GetFrameLevel = function() return 10 end,
        SetFrameLevel = function() end,
    }
end
local runtimeModule = { bars = {} }
for i = 1, 5 do
    runtimeConfig.bars[i] = { enabled = false }
    runtimeModule.bars[i] = Holder()
end
function runtimeModule:EnsureCreated() end
function runtimeModule:EnsureAutoHideHooks() end
function runtimeModule:RefreshEmptySlots() end
function runtimeModule:UpdateAutoHideState() end

local nsRuntime = {
    Log = { Error = function() end },
    DB = {
        GetSection = function(_, name)
            if name == 'actionbars' then return runtimeConfig end
            return {}
        end,
        ShouldHideBlizzardActionBars = function() return false end,
    },
    ActionBarsBlizzardShell = {
        EnsureBlizzardMultiBars = function() return true end,
        EnsureSettingsHooks = function() return true end,
        RestoreBlizzardArt = function() return true end,
        ShouldHideBlizzardArt = function() return false end,
    },
    ActionBarsState = {},
    ActionBarsVisuals = {
        BuildStyleConfig = function() return {} end,
    },
}
assert(loadfile('modules/ActionBarsRuntime.lua'))('FeelsGoodUI', nsRuntime)
assert(nsRuntime.ActionBarsRuntime.ApplyNow(runtimeModule) == true)
assertEqual(runtimeConfig.autoHide, nil, 'runtime does not normalize SavedVariables')
assertEqual(runtimeModule._autoHideEnabled, false, 'missing autoHide resolves locally')

assert(multiUpdates >= 3)
print('ActionBars native-state ownership tests passed.')
