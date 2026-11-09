local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function CountEntries(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do count = count + 1 end
    return count
end

_G = _G or {}
_G.UIParent = {}
_G.InCombatLockdown = function() return false end
_G.CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function() end,
    }
end

local warnings = {}
local ns = {
    DB = {
        defaults = { profile = { positions = {} } },
    },
    Log = {
        Warn = function(_, message) warnings[#warnings + 1] = tostring(message) end,
        Info = function() end,
    },
    U = {
        DeepCopy = function(value) return value end,
    },
    MoversShared = {
        GetProfileSection = function() return {} end,
        IsSafeToEdit = function() return true end,
        UIParentRect = function() return 0, 0, 100, 100 end,
        UIWH = function() return 100, 100 end,
        GetCursorUI = function() return 0, 0 end,
        Clamp = function(value) return value end,
        RoundToStep = function(value) return value end,
        ClampCenterOffsets = function(x, y) return x, y end,
        GetFrameSnapSize = function() return 10, 10 end,
        GetFrameSnapBounds = function() return 0, 0, 10, 10 end,
        ApplyStoredPoint = function() return true end,
        GetEditablePosition = function() return 0, 0 end,
        SetEditablePosition = function() return true end,
        EnsureCenterAnchor = function() return true end,
        SavePoint = function() return true end,
        BuildStoredPointWrites = function() return nil, {}, "movers", "editmode" end,
        ResolveStoredPointFromFrame = function() return { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 } end,
        GridStep = function() return 10 end,
        EditorCfg = function() return {} end,
        RequestApplyForKeys = function() return true end,
    },
}

assert(loadfile("core/Movers.lua"))("FeelsGoodUI", ns)
local Movers = assert(ns.Movers)
assertEqual(getmetatable(Movers._stateListeners).__mode, "k", "listener registry mode")

local ok, detail = Movers:RegisterStateListener(nil, function() end)
assertEqual(ok, false, "nil listener key rejected")
assertEqual(type(detail), "string", "nil key detail")
ok, detail = Movers:RegisterStateListener({}, nil)
assertEqual(ok, false, "nil listener callback rejected")
assertEqual(type(detail), "string", "nil callback detail")

local key = {}
local calls = {}
local function Listener(unlocked, owner, listenerKey)
    calls[#calls + 1] = {
        unlocked = unlocked,
        owner = owner,
        key = listenerKey,
    }
end

ok = Movers:RegisterStateListener(key, Listener)
assertEqual(ok, true, "listener registration succeeds")
assertEqual(Movers._stateListeners[key], Listener, "listener stored")
assertEqual(rawget(key, "_fguiMoversStateListenerRegistered"), nil, "listener marker absent")

local changed, previewDetail = Movers:PreviewUnlocked(true, { silent = true })
assertEqual(changed, true, "unlock preview succeeds")
assertEqual(previewDetail, nil, "unlock preview detail")
assertEqual(#calls, 1, "listener called once")
assertEqual(calls[1].unlocked, true, "listener receives state")
assertEqual(calls[1].owner, Movers, "listener receives owner")
assertEqual(calls[1].key, key, "listener receives registry key")

local replacementCalls = 0
local function Replacement(_, _, listenerKey)
    assertEqual(listenerKey, key, "replacement listener key")
    replacementCalls = replacementCalls + 1
end
assertEqual(Movers:RegisterStateListener(key, Replacement), true, "listener replacement succeeds")
assertEqual(CountEntries(Movers._stateListeners), 1, "replacement does not duplicate registry entry")
assertEqual(Movers:PreviewUnlocked(false, { silent = true }), true, "lock preview succeeds")
assertEqual(#calls, 1, "old listener becomes inert")
assertEqual(replacementCalls, 1, "replacement listener called once")

assertEqual(Movers:UnregisterStateListener(key), true, "listener unregister reports removal")
assertEqual(Movers:UnregisterStateListener(key), false, "second unregister is inert")
assertEqual(Movers:PreviewUnlocked(true, { silent = true }), true, "preview without listener succeeds")
assertEqual(replacementCalls, 1, "unregistered listener remains inert")

-- Weak-key registry does not retain rebuilt panel roots when callbacks do not capture them.
do
    local transient = {}
    assertEqual(Movers:RegisterStateListener(transient, Listener), true, "transient listener registration")
    assertEqual(CountEntries(Movers._stateListeners), 1, "transient listener stored")
    transient = nil
end
collectgarbage("collect")
collectgarbage("collect")
assertEqual(CountEntries(Movers._stateListeners), 0, "transient listener key collected")
assertEqual(#warnings, 0, "no listener warnings")

print("Movers weak listener registry tests passed.")
