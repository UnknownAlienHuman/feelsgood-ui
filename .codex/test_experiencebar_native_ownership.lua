local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function NewForeignFrame(alpha, mouseEnabled, shown)
    local frame = {
        alpha = alpha,
        mouseEnabled = mouseEnabled,
        shown = shown,
        hideCalls = 0,
        showCalls = 0,
        alphaWrites = 0,
        mouseWrites = 0,
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
    function frame:UpdateBarsShown() end
    function frame:UpdateBarVisuals() end
    return frame
end

local manager = NewForeignFrame(0.82, true, true)
local primary = NewForeignFrame(0.63, true, false)
local secondary = NewForeignFrame(0.41, false, true)
_G = _G or {}
_G.StatusTrackingBarManager = manager
_G.MainStatusTrackingBarContainer = primary
_G.SecondaryStatusTrackingBarContainer = secondary
_G.hooksecurefunc = function(object, method, callback)
    object.hooks[method] = callback
end

local eventFrame = { registered = {}, unregisterCalls = 0 }
function eventFrame:SetScript(name, callback)
    if name == "OnEvent" then self.onEvent = callback end
end
function eventFrame:RegisterEvent(name)
    self.registered[name] = true
end
function eventFrame:UnregisterAllEvents()
    self.unregisterCalls = self.unregisterCalls + 1
    self.registered = {}
end
_G.CreateFrame = function(frameType)
    assertEqual(frameType, "Frame", "only event frame should be created")
    return eventFrame
end

local profile = {
    experience = {
        enabled = true,
        showText = true,
        showRested = true,
        width = 420,
        height = 10,
    },
    media = {},
    unitframes = { text = {} },
}

local ns = {
    DB = {
        GetProfile = function() return profile end,
    },
    Media = {},
    Movers = {},
    Log = {
        Debug = function() end,
    },
    U = {},
    Animate = {
        CancelFade = function() end,
    },
}

assert(loadfile("modules/ExperienceBar.lua"))("FeelsGoodUI", ns)
local XP = assert(ns.ExperienceBar)
assertEqual(XP.Enable, nil, "parallel Enable owner removed")
assertEqual(XP.Disable, nil, "parallel Disable owner removed")

local bar = {
    alpha = 1,
    shown = true,
    hideCalls = 0,
    showCalls = 0,
}
function bar:SetAlpha(value) self.alpha = value end
function bar:IsShown() return self.shown end
function bar:Hide() self.hideCalls = self.hideCalls + 1; self.shown = false end
function bar:Show() self.showCalls = self.showCalls + 1; self.shown = true end
XP._bar = bar

local updateCalls = 0
function XP:Update()
    updateCalls = updateCalls + 1
end

-- Attach initializes runtime objects but must not apply or take over native frames.
assert(XP:Attach() == true)
assertEqual(XP._attached, true, "attached")
assertEqual(XP._inited, true, "initialized")
assertEqual(updateCalls, 0, "attach does not apply")
assertEqual(manager.alpha, 0.82, "attach leaves manager alpha")
assertEqual(primary.alpha, 0.63, "attach leaves primary alpha")
assertEqual(secondary.alpha, 0.41, "attach leaves secondary alpha")
assertEqual(eventFrame.unregisterCalls, 0, "attach leaves events untouched")

-- First apply captures once, changes only alpha/mouse, and never Hide/Show.
assert(XP:ApplyConfig() == true)
assertEqual(updateCalls, 1, "one apply update")
assertEqual(manager.alpha, 0, "manager suppressed")
assertEqual(primary.alpha, 0, "primary suppressed")
assertEqual(secondary.alpha, 0, "secondary suppressed")
assertEqual(manager.mouseEnabled, false, "manager mouse suppressed")
assertEqual(primary.mouseEnabled, false, "primary mouse suppressed")
assertEqual(secondary.mouseEnabled, false, "secondary already false")
assertEqual(manager.hideCalls, 0, "manager never hidden")
assertEqual(primary.hideCalls, 0, "primary never hidden")
assertEqual(secondary.hideCalls, 0, "secondary never hidden")
assertEqual(manager.showCalls, 0, "manager never shown")
assertEqual(primary.showCalls, 0, "primary never shown")
assertEqual(secondary.showCalls, 0, "secondary never shown")
assertEqual(manager.shown, true, "manager visibility owned by Blizzard")
assertEqual(primary.shown, false, "primary visibility preserved")
assertEqual(secondary.shown, true, "secondary visibility preserved")
assertEqual(type(manager.hooks.UpdateBarsShown), "function", "manager shown hook")
assertEqual(type(manager.hooks.UpdateBarVisuals), "function", "manager visuals hook")
assertEqual(eventFrame.registered.PLAYER_ENTERING_WORLD, true, "events registered")

local managerBaselineWrites = manager.alphaWrites
local primaryBaselineWrites = primary.alphaWrites
assert(XP:ApplyConfig() == true)
assertEqual(updateCalls, 2, "second apply update")
assertEqual(manager.alphaWrites, managerBaselineWrites, "identical manager suppression not rewritten")
assertEqual(primary.alphaWrites, primaryBaselineWrites, "identical primary suppression not rewritten")
assertEqual(manager.alpha, 0, "manager remains suppressed")

-- Native refresh or normal event reasserts suppression without replacing baseline.
manager.alpha = 1
manager.mouseEnabled = true
manager.hooks.UpdateBarsShown()
assertEqual(manager.alpha, 0, "native refresh re-suppressed")
assertEqual(manager.mouseEnabled, false, "native refresh mouse re-suppressed")
primary.alpha = 0.7
primary.mouseEnabled = true
eventFrame.onEvent(eventFrame, "UPDATE_FACTION")
assertEqual(primary.alpha, 0, "event maintenance re-suppressed")
assertEqual(primary.mouseEnabled, false, "event maintenance mouse re-suppressed")
assertEqual(updateCalls, 3, "event updates module")

-- A newer conflicting owner wins during restore.
secondary.alpha = 0.55
secondary.mouseEnabled = true
profile.experience.enabled = false
assert(XP:ApplyConfig() == true)
assertEqual(manager.alpha, 0.82, "manager alpha restored")
assertEqual(primary.alpha, 0.63, "primary alpha restored")
assertEqual(secondary.alpha, 0.55, "newer secondary alpha preserved")
assertEqual(manager.mouseEnabled, true, "manager mouse restored")
assertEqual(primary.mouseEnabled, true, "primary mouse restored")
assertEqual(secondary.mouseEnabled, true, "newer secondary mouse preserved")
assertEqual(manager.shown, true, "manager visibility unchanged after release")
assertEqual(primary.shown, false, "primary visibility unchanged after release")
assertEqual(secondary.shown, true, "secondary visibility unchanged after release")
assertEqual(XP._statusTrackingSnapshot, nil, "snapshot released")
assertEqual(bar.shown, false, "custom bar hidden when disabled")

-- Re-enable captures the current baseline; detach restores it exactly.
profile.experience.enabled = true
assert(XP:ApplyConfig() == true)
assertEqual(manager.alpha, 0, "manager re-suppressed")
assertEqual(secondary.alpha, 0, "secondary re-suppressed")
assert(XP:Detach() == true)
assertEqual(XP._attached, false, "detached")
assertEqual(manager.alpha, 0.82, "manager restored on detach")
assertEqual(primary.alpha, 0.63, "primary restored on detach")
assertEqual(secondary.alpha, 0.55, "secondary current baseline restored on detach")
assertEqual(manager.mouseEnabled, true, "manager mouse restored on detach")
assertEqual(primary.mouseEnabled, true, "primary mouse restored on detach")
assertEqual(secondary.mouseEnabled, true, "secondary mouse baseline restored on detach")
assertEqual(eventFrame.unregisterCalls >= 3, true, "events unregistered on apply/detach")
assertEqual(manager.hideCalls, 0, "manager still never hidden")
assertEqual(manager.showCalls, 0, "manager still never shown")
assertEqual(XP:Detach(), true, "detach idempotent")

print("ExperienceBar native ownership tests passed.")
