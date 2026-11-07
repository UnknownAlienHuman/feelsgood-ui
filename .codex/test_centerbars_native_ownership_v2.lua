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

local function ReadableFrame(alpha, mouseEnabled)
    local frame = {
        alpha = alpha,
        mouseEnabled = mouseEnabled,
        alphaWrites = 0,
        mouseWrites = 0,
        hooks = {},
    }
    function frame:GetAlpha() return self.alpha end
    function frame:SetAlpha(value) self.alphaWrites = self.alphaWrites + 1; self.alpha = value end
    function frame:IsMouseEnabled() return self.mouseEnabled end
    function frame:EnableMouse(value) self.mouseWrites = self.mouseWrites + 1; self.mouseEnabled = value end
    function frame:HookScript(name, callback) self.hooks[name] = callback end
    return frame
end

_G = _G or {}
_G.InCombatLockdown = function() return false end
local config = { hideBlizzardClassResources = true }
local ns = { Media = {}, Secret = {}, U = {} }
assert(loadfile("modules/CenterBarsRender.lua"))("FeelsGoodUI", ns)
local Render = assert(ns.CenterBarsRender)
Render:Configure({ GetCenterCfg = function() return config end })

-- A named global disappearing must restore the old instance and release its record.
local old = ReadableFrame(0.72, true)
_G.EdgeResource = old
local owner = { _hideFrames = { "EdgeResource" } }
assertEqual(Render.SyncDefaultClassResources(owner), true, "initial sync")
assertEqual(old.alpha, 0, "old suppressed")
assertEqual(old.mouseEnabled, false, "old mouse suppressed")
_G.EdgeResource = nil
assertEqual(Render.SyncDefaultClassResources(owner), true, "missing global sync")
assertEqual(old.alpha, 0.72, "missing global restores old alpha")
assertEqual(old.mouseEnabled, true, "missing global restores old mouse")
assertNil(owner._classResourceSuppression.EdgeResource, "missing global record released")

-- A completely unreadable frame is never mutated because exact restore is impossible.
local unreadable = {
    alphaWrites = 0,
    mouseWrites = 0,
    hooks = {},
}
function unreadable:SetAlpha() self.alphaWrites = self.alphaWrites + 1 end
function unreadable:EnableMouse() self.mouseWrites = self.mouseWrites + 1 end
function unreadable:HookScript(name, callback) self.hooks[name] = callback end
_G.EdgeResource = unreadable
assertEqual(Render.SyncDefaultClassResources(owner), true, "unreadable sync")
assertEqual(unreadable.alphaWrites, 0, "unreadable alpha untouched")
assertEqual(unreadable.mouseWrites, 0, "unreadable mouse untouched")
assertNil(owner._classResourceSuppression.EdgeResource, "unreadable frame not adopted")
assertNil(unreadable.hooks.OnShow, "unreadable frame not hooked")

-- A partially readable frame owns and restores only the captured property.
local alphaOnly = {
    alpha = 0.44,
    alphaWrites = 0,
    mouseWrites = 0,
    hooks = {},
}
function alphaOnly:GetAlpha() return self.alpha end
function alphaOnly:SetAlpha(value) self.alphaWrites = self.alphaWrites + 1; self.alpha = value end
function alphaOnly:EnableMouse() self.mouseWrites = self.mouseWrites + 1 end
function alphaOnly:HookScript(name, callback) self.hooks[name] = callback end
_G.EdgeResource = alphaOnly
assertEqual(Render.SyncDefaultClassResources(owner), true, "alpha-only sync")
assertEqual(alphaOnly.alpha, 0, "alpha-only suppressed")
assertEqual(alphaOnly.mouseWrites, 0, "uncaptured mouse untouched")
assertEqual(type(alphaOnly.hooks.OnShow), "function", "alpha-only hook installed")
alphaOnly.alpha = 1
alphaOnly.hooks.OnShow(alphaOnly)
assertEqual(alphaOnly.alpha, 0, "alpha-only OnShow re-suppressed")
assertEqual(alphaOnly.mouseWrites, 0, "alpha-only OnShow leaves mouse")
assertEqual(Render.RestoreDefaultClassResources(owner), true, "alpha-only restore")
assertEqual(alphaOnly.alpha, 0.44, "alpha-only exact restore")
assertEqual(alphaOnly.mouseWrites, 0, "alpha-only restore leaves mouse")

-- Replacing a readable owned frame with an unreadable one restores the old
-- frame and declines ownership of the new frame.
local readable = ReadableFrame(0.61, false)
_G.EdgeResource = readable
assertEqual(Render.SyncDefaultClassResources(owner), true, "readable replacement baseline")
assertEqual(readable.alpha, 0, "readable suppressed")
_G.EdgeResource = unreadable
assertEqual(Render.SyncDefaultClassResources(owner), true, "unreadable replacement sync")
assertEqual(readable.alpha, 0.61, "readable old frame restored")
assertEqual(readable.mouseEnabled, false, "readable old false mouse restored")
assertNil(owner._classResourceSuppression.EdgeResource, "unreadable replacement not adopted")
assertEqual(unreadable.alphaWrites, 0, "unreadable replacement alpha untouched")
assertEqual(unreadable.mouseWrites, 0, "unreadable replacement mouse untouched")

print("CenterBars ownership edge tests passed.")
