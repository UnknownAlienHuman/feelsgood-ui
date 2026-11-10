local function fail(message)
    error(message, 2)
end

local function assertTrue(value, label)
    if value ~= true then fail((label or "expected true") .. ": got " .. tostring(value)) end
end

local function assertFalse(value, label)
    if value ~= false then fail((label or "expected false") .. ": got " .. tostring(value)) end
end

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        fail((label or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assertContains(text, needle, label)
    text = tostring(text)
    if not string.find(text, needle, 1, true) then
        fail((label or "missing text") .. ": expected '" .. needle .. "' in '" .. text .. "'")
    end
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

local errors = {}
local moverEntry
local ns = {
    DB = {
        GetProfile = function() return profile end,
    },
    Media = {
        CreateBorder = function() end,
        FetchStatusbar = function(_, token) return token end,
        ApplyFont = function() end,
    },
    Movers = {
        GetEntry = function(_, key)
            if key == "xpbar" then return moverEntry end
        end,
        Register = function(_, key, frame)
            moverEntry = { key = key, frame = frame }
            return true
        end,
        Apply = function() return true end,
    },
    Log = {
        Error = function(_, message) errors[#errors + 1] = tostring(message) end,
        Warn = function() end,
        Info = function() end,
        Debug = function() end,
    },
    U = {
        ClampWithFallback = function(value, minValue, maxValue, fallback)
            local number = tonumber(value) or fallback
            if number < minValue then number = minValue end
            if number > maxValue then number = maxValue end
            return number
        end,
    },
}

_G.UIParent = {}
_G.UnitXP = function() return 50 end
_G.UnitXPMax = function() return 100 end
_G.GetXPExhaustion = function() return 25 end
_G.UnitHonor = function() return 0 end
_G.UnitHonorMax = function() return 1 end
_G.C_Reputation = nil
_G.C_GossipInfo = nil
_G.C_MajorFactions = nil
_G.XP = "XP"
_G.HONOR = "Honor"
_G.StatusTrackingBarManager = nil
_G.MainStatusTrackingBarContainer = nil
_G.SecondaryStatusTrackingBarContainer = nil

local function NewTexture()
    local texture = { shown = true }
    function texture:SetAllPoints() end
    function texture:SetColorTexture() end
    function texture:SetPoint() end
    function texture:SetWidth() end
    function texture:Hide() self.shown = false end
    function texture:Show() self.shown = true end
    return texture
end

local function NewFontString()
    local font = { shown = true, text = "" }
    function font:SetPoint() end
    function font:SetJustifyH() end
    function font:SetText(value) self.text = value end
    function font:Hide() self.shown = false end
    function font:Show() self.shown = true end
    return font
end

local bars = {}
local function NewBar()
    local bar = {
        shown = true,
        alpha = 1,
        width = 420,
        height = 10,
        value = 0,
    }
    function bar:SetSize(width, height) self.width, self.height = width, height end
    function bar:SetPoint() end
    function bar:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
    function bar:SetValue(value) self.value = value end
    function bar:SetFrameStrata() end
    function bar:SetFrameLevel() end
    function bar:SetStatusBarTexture() end
    function bar:SetStatusBarColor() end
    function bar:CreateTexture() return NewTexture() end
    function bar:CreateFontString() return NewFontString() end
    function bar:SetAlpha(value) self.alpha = value end
    function bar:IsShown() return self.shown end
    function bar:Show() self.shown = true end
    function bar:Hide() self.shown = false end
    function bar:GetWidth() return self.width end
    bars[#bars + 1] = bar
    return bar
end

local eventConfigs = {}
local eventFrames = {}
local function QueueEventConfig(config)
    eventConfigs[#eventConfigs + 1] = config or {}
end

local function NewEventFrame(config)
    local frame = {
        config = config or {},
        registerCalls = 0,
        unregisterCalls = 0,
        registrations = {},
    }

    function frame:SetScript(name, callback)
        if name ~= "OnEvent" then return end
        if self.config.failSetScript then
            error("forced SetScript failure")
        end
        self.script = callback
    end

    function frame:RegisterEvent(event)
        self.registerCalls = self.registerCalls + 1
        if self.config.failRegisterAt == self.registerCalls then
            if self.config.rejectRegister then return false end
            error("forced RegisterEvent failure")
        end
        self.registrations[#self.registrations + 1] = event
        return true
    end

    function frame:UnregisterAllEvents()
        self.unregisterCalls = self.unregisterCalls + 1
        if self.config.failUnregister then
            error("forced UnregisterAllEvents failure")
        end
        self.registrations = {}
        return true
    end

    function frame:Fire(event, ...)
        if self.script then self.script(self, event, ...) end
    end

    eventFrames[#eventFrames + 1] = frame
    return frame
end

_G.CreateFrame = function(frameType)
    if frameType == "StatusBar" then
        return NewBar()
    end

    local config = table.remove(eventConfigs, 1) or {}
    if config.failCreate then
        error("forced CreateFrame failure")
    end
    return NewEventFrame(config)
end

assert(loadfile('modules/ExperienceBar.lua'))('FeelsGoodUI', ns)
local XP = assert(ns.ExperienceBar)
local originalUpdate = XP.Update

local function ResetModule()
    XP._bar = nil
    XP._moverReadyFrame = nil
    XP._events = nil
    XP._eventRecord = nil
    XP._eventLastError = nil
    XP._statusTrackingSnapshot = nil
    XP._statusTrackingHookOwner = nil
    XP._statusTrackingHookMethods = nil
    XP._statusTrackingResuppress = nil
    XP._statusTrackingLastError = nil
    XP._suppressBlizzardTracking = nil
    XP._inited = nil
    XP._attached = nil
    XP.Update = originalUpdate
    profile.experience.enabled = true
    moverEntry = nil
    errors = {}
    eventConfigs = {}
end

-- Event frame creation and callback setup are mandatory init edges. Neither
-- failure may publish an initialized owner.
ResetModule()
QueueEventConfig({ failCreate = true })
local ok, detail = XP:Init()
assertFalse(ok, "event frame creation failure propagates")
assertContains(detail, "event-frame creation failed", "creation failure detail")
assertEqual(XP._inited, nil, "creation failure leaves init unpublished")
assertEqual(XP._eventRecord, nil, "creation failure publishes no event record")

QueueEventConfig({ failSetScript = true })
ok, detail = XP:Init()
assertFalse(ok, "event SetScript failure propagates")
assertContains(detail, "event callback setup failed", "SetScript failure detail")
assertEqual(XP._eventRecord, nil, "SetScript failure publishes no record")
assertEqual(XP._inited, nil, "SetScript failure leaves init unpublished")

QueueEventConfig({})
ok, detail = XP:Init()
assertTrue(ok, detail)
assertTrue(XP._inited, "successful retry publishes init")

-- Partial registration is rolled back; its callback remains inert. A clean
-- retry installs the full set exactly once, and active reapply does not
-- duplicate registrations.
ResetModule()
QueueEventConfig({ failRegisterAt = 3 })
assertTrue(XP:Init())
local frame = XP._events
ok, detail = XP:ApplyConfig()
assertFalse(ok, "partial registration failure propagates")
assertContains(detail, "event subscription failed", "partial registration detail")
assertFalse(XP._eventRecord.active, "partial generation inactive")
assertFalse(XP._eventRecord.registered, "partial generation cleaned")
assertEqual(frame.unregisterCalls, 1, "partial registration cleanup attempted")

local updateCalls = 0
XP.Update = function()
    updateCalls = updateCalls + 1
    return true
end
frame:Fire("PLAYER_ENTERING_WORLD")
assertEqual(updateCalls, 0, "partial callback inert")

frame.config.failRegisterAt = nil
ok, detail = XP:ApplyConfig()
assertTrue(ok, detail)
assertTrue(XP._eventRecord.active, "complete generation activated")
assertTrue(XP._eventRecord.registered, "complete generation registered")
assertEqual(updateCalls, 1, "initial apply updates once")
local registeredCalls = frame.registerCalls
ok, detail = XP:ApplyConfig()
assertTrue(ok, detail)
assertEqual(frame.registerCalls, registeredCalls, "active reapply creates no duplicate registrations")
assertEqual(updateCalls, 2, "active reapply updates once")
frame:Fire("PLAYER_ENTERING_WORLD")
assertEqual(updateCalls, 3, "active callback dispatches once")

-- Failed partial cleanup is retained as dirty/inert state. Retry first cleans
-- it, then installs a complete generation.
ResetModule()
QueueEventConfig({ failRegisterAt = 2, failUnregister = true })
assertTrue(XP:Init())
frame = XP._events
updateCalls = 0
XP.Update = function()
    updateCalls = updateCalls + 1
    return true
end
ok, detail = XP:ApplyConfig()
assertFalse(ok, "registration cleanup failure propagates")
assertContains(detail, "cleanup", "registration cleanup detail")
assertFalse(XP._eventRecord.active, "dirty partial generation inactive")
assertTrue(XP._eventRecord.registered, "dirty registration retained")
assertTrue(XP._eventRecord.cleanupPending, "cleanup retry retained")
frame:Fire("PLAYER_ENTERING_WORLD")
assertEqual(updateCalls, 0, "dirty partial callback inert")

frame.config.failRegisterAt = nil
frame.config.failUnregister = false
ok, detail = XP:ApplyConfig()
assertTrue(ok, detail)
assertTrue(XP._eventRecord.active, "retry activates fresh generation")
assertFalse(XP._eventRecord.cleanupPending, "retry clears cleanup marker")
assertEqual(updateCalls, 1, "retry updates once")

-- First-enable update failure tears down the prepared generation and restores
-- inactive presentation. A later retry is clean.
ResetModule()
QueueEventConfig({})
assertTrue(XP:Init())
frame = XP._events
XP.Update = function() return false, "forced first-enable update failure" end
ok, detail = XP:ApplyConfig()
assertFalse(ok, "first-enable update failure propagates")
assertContains(detail, "forced first-enable update failure", "first-enable update detail")
assertFalse(XP._eventRecord.active, "failed first-enable generation inactive")
assertFalse(XP._eventRecord.registered, "failed first-enable generation unregistered")
assertEqual(XP._suppressBlizzardTracking, nil, "failed first-enable native owner released")
assertFalse(XP._bar:IsShown(), "failed first-enable bar hidden")

XP.Update = originalUpdate
ok, detail = XP:ApplyConfig()
assertTrue(ok, detail)
assertTrue(XP._eventRecord.active, "first-enable retry active")

-- Active reapply failure preserves the committed event generation instead of
-- tearing down working subscriptions.
local activeFrame = XP._events
local activeRegisterCalls = activeFrame.registerCalls
local activeUnregisterCalls = activeFrame.unregisterCalls
XP.Update = function() return false, "forced reapply update failure" end
ok, detail = XP:ApplyConfig()
assertFalse(ok, "active reapply failure propagates")
assertContains(detail, "forced reapply update failure", "reapply update detail")
assertTrue(XP._eventRecord.active, "prior generation remains active")
assertEqual(activeFrame.registerCalls, activeRegisterCalls, "reapply does not re-register")
assertEqual(activeFrame.unregisterCalls, activeUnregisterCalls, "reapply does not unregister prior generation")

-- Event callback exceptions/results are contained and deduplicated.
errors = {}
activeFrame:Fire("PLAYER_ENTERING_WORLD")
activeFrame:Fire("PLAYER_ENTERING_WORLD")
assertEqual(#errors, 1, "identical callback update failure logged once")
assertContains(errors[1], "forced reapply update failure", "event update failure logged")

-- Disable deactivates before unregister. Failed cleanup is visible but cannot
-- dispatch; retry completes without reconstructing the event frame.
profile.experience.enabled = false
activeFrame.config.failUnregister = true
ok, detail = XP:ApplyConfig()
assertFalse(ok, "disable unregister failure propagates")
assertContains(detail, "events:", "disable event failure detail")
assertFalse(XP._eventRecord.active, "failed disable generation inactive")
local callsBefore = #errors
activeFrame:Fire("PLAYER_ENTERING_WORLD")
assertEqual(#errors, callsBefore, "failed-disable callback inert")

activeFrame.config.failUnregister = false
ok, detail = XP:ApplyConfig()
assertTrue(ok, detail)
assertFalse(XP._eventRecord.registered, "disable retry unregisters events")
assertFalse(XP._bar:IsShown(), "disabled bar hidden")

-- Detach uses the same result-bearing cleanup and keeps stale callbacks inert.
profile.experience.enabled = true
XP.Update = originalUpdate
ok, detail = XP:ApplyConfig()
assertTrue(ok, detail)
activeFrame.config.failUnregister = true
ok, detail = XP:Detach()
assertFalse(ok, "detach unregister failure propagates")
assertContains(detail, "events:", "detach event failure detail")
assertFalse(XP._eventRecord.active, "failed detach generation inactive")
assertEqual(XP._attached, false, "detach owner flag cleared")

activeFrame.config.failUnregister = false
ok, detail = XP:Detach()
assertTrue(ok, detail)
assertFalse(XP._eventRecord.registered, "detach retry unregisters events")

print('ExperienceBar event lifecycle tests passed.')
