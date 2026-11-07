local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
    end
end

local function assertArray(actual, expected, label)
    assertEqual(type(actual), 'table', (label or 'array') .. ' type')
    assertEqual(#actual, #expected, (label or 'array') .. ' length')
    for i = 1, #expected do
        assertEqual(actual[i], expected[i], (label or 'array') .. '[' .. i .. ']')
    end
end

_G = _G or {}
_G.InCombatLockdown = function() return false end
_G.UnitGUID = function() return 'Player-Login' end
_G.UIParent_ManageFramePositions = function() end
_G.CreateFrame = function() return { Hide = function() end } end

local current = { true, true, false, false, true }
local setCalls = 0
_G.GetActionBarToggles = function() return unpack(current) end
_G.SetActionBarToggles = function(...)
    setCalls = setCalls + 1
    current = { ... }
end
_G.MultiActionBar_Update = function() end

local baseline = { false, true, true, false, false }
local root = {
    profile = {},
    _actionBarsNativeToggleRecovery = {
        version = 1,
        records = {
            ['Player-Login'] = { values = baseline, count = #baseline },
        },
    },
}
_G.FeelsGoodUIDB = root
local ns = {
    DB = {
        data = root,
        GetSection = function(_, name)
            if name == 'actionbars' then return { hideBlizzard = true } end
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
assert(Shell.RestorePersistedNativeActionBarToggles() == true)
assertArray(current, baseline, 'PLAYER_LOGIN restore')
assertEqual(root._actionBarsNativeToggleRecovery, nil, 'login recovery cleared')
assertEqual(setCalls, 1, 'login recovery writes once')
assert(Shell.RestorePersistedNativeActionBarToggles() == false)
assertEqual(setCalls, 1, 'second login recovery is inert')

-- A detached module without an in-memory snapshot can still recover from root.
local fallback = { true, false, false, true, true }
root._actionBarsNativeToggleRecovery = {
    version = 1,
    records = {
        ['Player-Login'] = { values = fallback, count = #fallback },
    },
}
current = { true, true, false, false, true }
local module = { _detached = true }
assert(Shell.RestoreBlizzardArt(module, {}) == true)
assertArray(current, fallback, 'detach fallback restore')
assertEqual(module._nativeActionBarToggles, nil, 'fallback runtime snapshot released')
assertEqual(root._actionBarsNativeToggleRecovery, nil, 'fallback recovery cleared')

print('ActionBars pre-enable recovery tests passed.')
