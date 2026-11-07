local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertArray(actual, expected, label)
    assertEqual(type(actual), "table", (label or "array") .. " type")
    assertEqual(#actual, #expected, (label or "array") .. " length")
    for i = 1, #expected do
        assertEqual(actual[i], expected[i], (label or "array") .. "[" .. i .. "]")
    end
end

_G = _G or {}
local playerGUID = "Player-A"
_G.UnitGUID = function() return playerGUID end
_G.InCombatLockdown = function() return false end
_G.UIParent_ManageFramePositions = function() end
_G.CreateFrame = function()
    return { Hide = function() end }
end

local current = { true, false, true, false, true }
local setCalls = 0
_G.GetActionBarToggles = function() return unpack(current) end
_G.SetActionBarToggles = function(...)
    setCalls = setCalls + 1
    current = { ... }
end
_G.MultiActionBar_Update = function() end

local root = { profile = {} }
_G.FeelsGoodUIDB = root
local ns = {
    DB = {
        data = root,
        GetSection = function(_, name)
            if name == "actionbars" then return { hideBlizzard = true } end
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
local bars = {
    [2] = { enabled = true },
    [3] = { enabled = true },
    [4] = { enabled = true },
    [5] = { enabled = true },
}

local moduleA = {}
assert(Shell.EnsureBlizzardMultiBars(moduleA, bars, true) == true)
assertArray(moduleA._nativeActionBarToggles.values, { true, false, true, false, true }, 'A baseline')
assertArray(root._actionBarsNativeToggleRecovery.records['Player-A'].values, { true, false, true, false, true }, 'A persisted baseline')
assertArray(current, { true, true, false, false, true }, 'A managed state')

-- Simulate /reload: runtime module disappears, native toggles stay managed, root survives.
local moduleAfterReload = {}
assert(Shell.EnsureBlizzardMultiBars(moduleAfterReload, bars, true) == true)
assertArray(moduleAfterReload._nativeActionBarToggles.values, { true, false, true, false, true }, 'reload uses persisted baseline')
assertEqual(setCalls, 1, 'reload does not rewrite identical managed state')
moduleAfterReload._detached = true
assert(Shell.RestoreBlizzardArt(moduleAfterReload, bars) == true)
assertArray(current, { true, false, true, false, true }, 'A exact restore after reload')
assertEqual(root._actionBarsNativeToggleRecovery, nil, 'A recovery cleared')

-- Separate characters own separate recovery vectors.
current = { false, false, true, true, false }
local moduleA2 = {}
assert(Shell.EnsureBlizzardMultiBars(moduleA2, bars, true) == true)
playerGUID = 'Player-B'
current = { true, true, false, true, true }
local moduleB = {}
assert(Shell.EnsureBlizzardMultiBars(moduleB, bars, true) == true)
local recovery = root._actionBarsNativeToggleRecovery
assertArray(recovery.records['Player-A'].values, { false, false, true, true, false }, 'A2 persisted baseline')
assertArray(recovery.records['Player-B'].values, { true, true, false, true, true }, 'B persisted baseline')

moduleB._detached = true
assert(Shell.RestoreBlizzardArt(moduleB, bars) == true)
assertArray(current, { true, true, false, true, true }, 'B exact restore')
assertEqual(root._actionBarsNativeToggleRecovery.records['Player-B'], nil, 'B record cleared')
assertEqual(type(root._actionBarsNativeToggleRecovery.records['Player-A']), 'table', 'A record retained')

playerGUID = 'Player-A'
moduleA2._detached = true
assert(Shell.RestoreBlizzardArt(moduleA2, bars) == true)
assertArray(current, { false, false, true, true, false }, 'A2 exact restore')
assertEqual(root._actionBarsNativeToggleRecovery, nil, 'all recovery cleared')

print('ActionBars durable toggle recovery tests passed.')
