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

local function NewNativeFrame(alpha, mouseEnabled, shown)
    local frame = {
        alpha = alpha,
        mouseEnabled = mouseEnabled,
        shown = shown,
        alphaWrites = 0,
        mouseWrites = 0,
        hideCalls = 0,
        showCalls = 0,
        setupCalls = 0,
        hooks = {},
    }
    function frame:GetAlpha() return self.alpha end
    function frame:SetAlpha(value)
        self.alphaWrites = self.alphaWrites + 1
        self.alpha = value
    end
    function frame:IsMouseEnabled() return self.mouseEnabled end
    function frame:EnableMouse(value)
        self.mouseWrites = self.mouseWrites + 1
        self.mouseEnabled = value
    end
    function frame:IsShown() return self.shown end
    function frame:Hide()
        self.hideCalls = self.hideCalls + 1
        self.shown = false
    end
    function frame:Show()
        self.showCalls = self.showCalls + 1
        self.shown = true
    end
    function frame:Setup()
        self.setupCalls = self.setupCalls + 1
    end
    function frame:HookScript(name, callback)
        self.hooks[name] = self.hooks[name] or {}
        self.hooks[name][#self.hooks[name] + 1] = callback
    end
    function frame:Fire(name)
        for i = 1, #(self.hooks[name] or {}) do
            self.hooks[name][i](self)
        end
    end
    return frame
end

_G = _G or {}
local inCombat = false
_G.InCombatLockdown = function() return inCombat end

local config = { hideBlizzardClassResources = true }
local ns = {
    Media = {},
    Secret = {},
    U = {},
}
assert(loadfile("modules/CenterBarsRender.lua"))("FeelsGoodUI", ns)
local Render = assert(ns.CenterBarsRender)
Render:Configure({
    GetCenterCfg = function() return config end,
})

local frameA = NewNativeFrame(0.75, true, false)
local frameB = NewNativeFrame(0.35, false, true)
_G.NativeA = frameA
_G.NativeB = frameB

local owner = {
    _hideFrames = { "NativeA", "NativeB" },
}

assertEqual(Render.SyncDefaultClassResources(owner), true, "initial sync")
assertEqual(owner._classResourceSuppressionActive, true, "suppression active")
assertEqual(frameA.alpha, 0, "A alpha suppressed")
assertEqual(frameB.alpha, 0, "B alpha suppressed")
assertEqual(frameA.mouseEnabled, false, "A mouse suppressed")
assertEqual(frameB.mouseEnabled, false, "B false mouse preserved as suppression")
assertEqual(frameA.shown, false, "A native visibility preserved")
assertEqual(frameB.shown, true, "B native visibility preserved")
assertEqual(frameA.hideCalls, 0, "A never hidden")
assertEqual(frameB.hideCalls, 0, "B never hidden")
assertEqual(frameA.showCalls, 0, "A never shown")
assertEqual(frameB.showCalls, 0, "B never shown")
assertEqual(frameA.setupCalls, 0, "A setup untouched")
assertEqual(frameB.setupCalls, 0, "B setup untouched")
assertEqual(#frameA.hooks.OnShow, 1, "A one OnShow hook")
assertEqual(#frameB.hooks.OnShow, 1, "B one OnShow hook")
assertNil(rawget(frameA, "_fguiSuppressRequested"), "A no foreign request marker")
assertNil(rawget(frameA, "_fguiSuppressHooked"), "A no foreign hook marker")

local aAlphaWrites = frameA.alphaWrites
local aMouseWrites = frameA.mouseWrites
local bAlphaWrites = frameB.alphaWrites
local bMouseWrites = frameB.mouseWrites
assertEqual(Render.SyncDefaultClassResources(owner), true, "repeat sync")
assertEqual(frameA.alphaWrites, aAlphaWrites, "A identical alpha not rewritten")
assertEqual(frameA.mouseWrites, aMouseWrites, "A identical mouse not rewritten")
assertEqual(frameB.alphaWrites, bAlphaWrites, "B identical alpha not rewritten")
assertEqual(frameB.mouseWrites, bMouseWrites, "B identical mouse not rewritten")
assertEqual(#frameA.hooks.OnShow, 1, "A hook not duplicated")

-- Native OnShow reasserts only the narrow alpha/mouse ownership.
frameA.alpha = 1
frameA.mouseEnabled = true
frameA.shown = true
frameA:Fire("OnShow")
assertEqual(frameA.alpha, 0, "A OnShow alpha re-suppressed")
assertEqual(frameA.mouseEnabled, false, "A OnShow mouse re-suppressed")
assertEqual(frameA.shown, true, "A OnShow visibility retained")

-- A newer conflicting owner wins on release.
frameB.alpha = 0.55
frameB.mouseEnabled = true
assertEqual(Render.RestoreDefaultClassResources(owner), true, "restore")
assertEqual(owner._classResourceSuppressionActive, false, "suppression inactive")
assertEqual(frameA.alpha, 0.75, "A alpha restored")
assertEqual(frameA.mouseEnabled, true, "A mouse restored")
assertEqual(frameB.alpha, 0.55, "B conflicting alpha preserved")
assertEqual(frameB.mouseEnabled, true, "B conflicting mouse preserved")
assertEqual(frameA.shown, true, "A visibility still external")
assertEqual(frameB.shown, true, "B visibility still external")
assertEqual(next(owner._classResourceSuppression), nil, "registry emptied")

-- Re-enable captures current baselines. A replacement frame restores the old
-- instance before the new one is adopted.
assertEqual(Render.SyncDefaultClassResources(owner), true, "re-enable")
local frameC = NewNativeFrame(0.90, false, true)
_G.NativeA = frameC
assertEqual(Render.SyncDefaultClassResources(owner), true, "frame replacement sync")
assertEqual(frameA.alpha, 0.75, "old A restored before replacement")
assertEqual(frameA.mouseEnabled, true, "old A mouse restored before replacement")
assertEqual(frameC.alpha, 0, "replacement C suppressed")
assertEqual(frameC.mouseEnabled, false, "replacement C mouse suppressed")
assertEqual(#frameC.hooks.OnShow, 1, "replacement C hook installed")

-- The stale permanent hook is owner-gated and record-gated.
frameA.alpha = 1
frameA.mouseEnabled = true
frameA:Fire("OnShow")
assertEqual(frameA.alpha, 1, "stale A hook inert")
assertEqual(frameA.mouseEnabled, true, "stale A mouse hook inert")

-- Removing a name restores only that record.
owner._hideFrames = { "NativeA" }
assertEqual(Render.SyncDefaultClassResources(owner), true, "remove B sync")
assertEqual(frameB.alpha, 0.55, "B restored after name removal")
assertEqual(frameB.mouseEnabled, true, "B mouse restored after name removal")
assertEqual(frameC.alpha, 0, "C remains suppressed")
assertNil(owner._classResourceSuppression.NativeB, "B record removed")

-- Config transitions are deferred in combat and applied on combat end.
config.hideBlizzardClassResources = false
inCombat = true
assertEqual(Render.SyncDefaultClassResources(owner), true, "combat defer restore")
assertEqual(owner._pendingClassResourceSync, true, "restore marked pending")
assertEqual(frameC.alpha, 0, "C remains suppressed in combat")
inCombat = false
Render.OnCombatEnd(owner)
assertNil(owner._pendingClassResourceSync, "pending restore cleared")
assertEqual(frameC.alpha, 0.90, "C alpha restored after combat")
assertEqual(frameC.mouseEnabled, false, "C original false mouse restored")
assertEqual(owner._classResourceSuppressionActive, false, "inactive after deferred restore")

config.hideBlizzardClassResources = true
inCombat = true
assertEqual(Render.SyncDefaultClassResources(owner), true, "combat defer suppress")
assertEqual(frameC.alpha, 0.90, "C not suppressed during combat")
inCombat = false
Render.OnCombatEnd(owner)
assertEqual(frameC.alpha, 0, "C suppressed after combat")
assertEqual(frameC.mouseEnabled, false, "C mouse suppressed after combat")
assertEqual(owner._classResourceSuppressionActive, true, "active after deferred suppress")

assertEqual(Render.RestoreDefaultClassResources(owner), true, "final restore")
assertEqual(frameC.alpha, 0.90, "C final alpha restored")
assertEqual(frameC.mouseEnabled, false, "C final mouse restored")
assertEqual(Render.RestoreDefaultClassResources(owner), true, "restore idempotent")

for _, frame in ipairs({ frameA, frameB, frameC }) do
    assertEqual(frame.hideCalls, 0, "foreign frame never hidden")
    assertEqual(frame.showCalls, 0, "foreign frame never shown")
    assertEqual(frame.setupCalls, 0, "foreign frame setup never called")
    assertNil(rawget(frame, "_fguiSuppressRequested"), "no request marker")
    assertNil(rawget(frame, "_fguiSuppressHooked"), "no hook marker")
end

print("CenterBars native class-resource ownership tests passed.")
