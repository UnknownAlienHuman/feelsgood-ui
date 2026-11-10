local function fail(message)
    error(message, 2)
end

local function assertTrue(value, label)
    if value ~= true then
        fail((label or "expected true") .. ": got " .. tostring(value))
    end
end

local function assertFalse(value, label)
    if value ~= false then
        fail((label or "expected false") .. ": got " .. tostring(value))
    end
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

local errors = {}
local ns = {
    Log = {
        Error = function(_, message) errors[#errors + 1] = tostring(message) end,
        Warn = function() end,
        Info = function() end,
    },
    Media = {},
    Secret = {
        CanAccess = function() return true end,
    },
    U = {
        TryNumber = function(value)
            if type(value) == "number" then return true, value end
            return false, nil
        end,
        IsPlainNumber = function(value) return type(value) == "number" end,
        Round = function(value) return math.floor(value + 0.5) end,
    },
}

local inCombat = false
_G.InCombatLockdown = function() return inCombat end
_G.GetTime = function() return 0 end
_G.C_Timer = {
    NewTimer = function(_, callback)
        return {
            Cancel = function() end,
            Fire = callback,
        }
    end,
}

local function NewNativeFrame(name, alpha, mouseEnabled)
    local frame = {
        name = name,
        alpha = alpha,
        mouseEnabled = mouseEnabled,
        hooks = {},
        hookCount = 0,
        setAlphaCalls = 0,
        setMouseCalls = 0,
    }

    function frame:GetName()
        return self.name
    end

    function frame:GetAlpha()
        if self.readAlphaError then error("forced GetAlpha failure") end
        return self.alpha
    end

    function frame:SetAlpha(value)
        self.setAlphaCalls = self.setAlphaCalls + 1
        if self.setAlphaError then error("forced SetAlpha failure") end
        if self.rejectAlphaValue ~= nil and value == self.rejectAlphaValue then
            return
        end
        if not self.stubbornAlpha then
            self.alpha = value
        end
    end

    function frame:IsMouseEnabled()
        if self.readMouseError then error("forced IsMouseEnabled failure") end
        return self.mouseEnabled
    end

    function frame:EnableMouse(value)
        self.setMouseCalls = self.setMouseCalls + 1
        if self.setMouseError then error("forced EnableMouse failure") end
        if self.rejectMouseValue ~= nil and value == self.rejectMouseValue then
            return
        end
        if not self.stubbornMouse then
            self.mouseEnabled = value
        end
    end

    function frame:HookScript(scriptName, callback)
        if self.hookError then error("forced HookScript failure") end
        self.hookCount = self.hookCount + 1
        local list = self.hooks[scriptName]
        if not list then
            list = {}
            self.hooks[scriptName] = list
        end
        list[#list + 1] = callback
    end

    function frame:Trigger(scriptName)
        local list = self.hooks[scriptName] or {}
        for i = 1, #list do
            list[i](self)
        end
    end

    return frame
end

assert(loadfile('modules/CenterBarsRender.lua'))('FeelsGoodUI', ns)
local Render = assert(ns.CenterBarsRender)
local config = { hideBlizzardClassResources = true }
Render:Configure({
    GetCenterCfg = function() return config end,
})

local function NewOwner(name)
    return {
        _hideFrames = { name },
    }
end

-- Exact capture, one hook, OnShow reassertion, exact restore.
do
    local frame = NewNativeFrame('NormalFrame', 0.73, true)
    _G.NormalFrame = frame
    local owner = NewOwner('NormalFrame')

    local ok, detail = Render.SyncDefaultClassResources(owner)
    assertTrue(ok, detail)
    assertEqual(frame.alpha, 0, 'normal alpha suppressed')
    assertEqual(frame.mouseEnabled, false, 'normal mouse suppressed')
    assertEqual(frame.hookCount, 1, 'one OnShow hook')

    ok, detail = Render.SyncDefaultClassResources(owner)
    assertTrue(ok, detail)
    assertEqual(frame.hookCount, 1, 'repeat sync does not duplicate hook')

    frame.alpha = 1
    frame.mouseEnabled = true
    frame:Trigger('OnShow')
    assertEqual(frame.alpha, 0, 'OnShow reasserts alpha')
    assertEqual(frame.mouseEnabled, false, 'OnShow reasserts mouse')

    ok, detail = Render.RestoreDefaultClassResources(owner)
    assertTrue(ok, detail)
    assertEqual(frame.alpha, 0.73, 'normal alpha restored')
    assertEqual(frame.mouseEnabled, true, 'normal mouse restored')
    assertEqual(owner._classResourceSuppression, nil, 'released journal removed')
end

-- One unreadable channel never mutates; the readable channel remains journaled.
do
    local frame = NewNativeFrame('UnreadableFrame', 0.61, true)
    frame.readAlphaError = true
    _G.UnreadableFrame = frame
    local owner = NewOwner('UnreadableFrame')

    local ok, detail = Render.SyncDefaultClassResources(owner)
    assertFalse(ok, 'unreadable alpha reports failure')
    assertContains(detail, 'GetAlpha failed', 'unreadable alpha detail')
    assertEqual(frame.setAlphaCalls, 0, 'unreadable alpha never written')
    assertEqual(frame.mouseEnabled, false, 'readable mouse still suppressed')
    assertTrue(owner._classResourceSuppression.UnreadableFrame.mouseOwned, 'mouse ownership published')

    ok, detail = Render.RestoreDefaultClassResources(owner)
    assertTrue(ok, detail)
    assertEqual(frame.mouseEnabled, true, 'partial mouse ownership restored')
    assertEqual(owner._classResourceSuppression, nil, 'partial record released')
end

-- A setter that returns without applying is rejected by readback.
do
    local frame = NewNativeFrame('StubbornFrame', 0.82, true)
    frame.stubbornAlpha = true
    _G.StubbornFrame = frame
    local owner = NewOwner('StubbornFrame')

    local ok, detail = Render.SyncDefaultClassResources(owner)
    assertFalse(ok, 'stubborn alpha reports failure')
    assertContains(detail, 'SetAlpha did not retain the requested value', 'stubborn alpha detail')
    local record = owner._classResourceSuppression.StubbornFrame
    assertEqual(record.alphaOwned, nil, 'failed write publishes no alpha ownership')
    assertTrue(record.mouseOwned, 'independent mouse ownership retained')

    frame.stubbornAlpha = false
    ok, detail = Render.RestoreDefaultClassResources(owner)
    assertTrue(ok, detail)
    assertEqual(frame.alpha, 0.82, 'unchanged alpha preserved')
    assertEqual(frame.mouseEnabled, true, 'mouse restored after alpha failure')
end

-- Failed restore retains exactly the unresolved property and succeeds on retry.
do
    local frame = NewNativeFrame('RestoreRetryFrame', 0.62, true)
    _G.RestoreRetryFrame = frame
    local owner = NewOwner('RestoreRetryFrame')
    local ok, detail = Render.SyncDefaultClassResources(owner)
    assertTrue(ok, detail)

    frame.rejectAlphaValue = 0.62
    ok, detail = Render.RestoreDefaultClassResources(owner)
    assertFalse(ok, 'failed restore propagates')
    assertContains(detail, 'alpha restore', 'restore channel detail')
    assertTrue(owner._classResourceSuppression.RestoreRetryFrame.alphaOwned, 'unresolved alpha retained')
    assertEqual(owner._classResourceSuppression.RestoreRetryFrame.mouseOwned, nil, 'resolved mouse released')

    frame.rejectAlphaValue = nil
    ok, detail = Render.RestoreDefaultClassResources(owner)
    assertTrue(ok, detail)
    assertEqual(frame.alpha, 0.62, 'retry restores original alpha')
    assertEqual(owner._classResourceSuppression, nil, 'retry clears journal')
end

-- Replacement waits for old ownership release and leaves the new frame untouched.
do
    local oldFrame = NewNativeFrame('ReplaceFrameOld', 0.44, true)
    _G.ReplaceFrame = oldFrame
    local owner = NewOwner('ReplaceFrame')
    local ok, detail = Render.SyncDefaultClassResources(owner)
    assertTrue(ok, detail)

    oldFrame.rejectAlphaValue = 0.44
    local newFrame = NewNativeFrame('ReplaceFrameNew', 0.91, true)
    _G.ReplaceFrame = newFrame
    ok, detail = Render.SyncDefaultClassResources(owner)
    assertFalse(ok, 'replacement blocked by old restore')
    assertContains(detail, 'previous frame restore failed', 'replacement restore detail')
    assertEqual(newFrame.alpha, 0.91, 'new frame untouched while old unresolved')
    assertEqual(owner._classResourceSuppression.ReplaceFrame.frame, oldFrame, 'old owner retained')

    oldFrame.alpha = 0.2
    oldFrame:Trigger('OnShow')
    assertEqual(oldFrame.alpha, 0.2, 'releasing old callback remains inert')

    oldFrame.alpha = 0
    oldFrame.rejectAlphaValue = nil
    ok, detail = Render.SyncDefaultClassResources(owner)
    assertTrue(ok, detail)
    assertEqual(oldFrame.alpha, 0.44, 'old frame restored before replacement')
    assertEqual(newFrame.alpha, 0, 'new frame suppressed after release')
    assertEqual(owner._classResourceSuppression.ReplaceFrame.frame, newFrame, 'new frame becomes owner')
    assertTrue(Render.RestoreDefaultClassResources(owner))
end

-- A newer external value is preserved and releases only our ownership claim.
do
    local frame = NewNativeFrame('ConflictFrame', 0.35, true)
    _G.ConflictFrame = frame
    local owner = NewOwner('ConflictFrame')
    assertTrue(Render.SyncDefaultClassResources(owner))

    frame.alpha = 0.48
    frame.mouseEnabled = true
    local ok, detail = Render.RestoreDefaultClassResources(owner)
    assertTrue(ok, detail)
    assertEqual(frame.alpha, 0.48, 'newer alpha conflict preserved')
    assertEqual(frame.mouseEnabled, true, 'newer mouse conflict preserved')
    assertEqual(owner._classResourceSuppression, nil, 'conflict releases addon record')
end

-- Hook failure is result-bearing, does not publish success, and retries once.
do
    local frame = NewNativeFrame('HookRetryFrame', 0.78, true)
    frame.hookError = true
    _G.HookRetryFrame = frame
    local owner = NewOwner('HookRetryFrame')

    local ok, detail = Render.SyncDefaultClassResources(owner)
    assertFalse(ok, 'HookScript failure propagates')
    assertContains(detail, 'OnShow hook failed', 'HookScript detail')
    local hookRecord = owner._classResourceSuppressionHooks[frame]
    assertEqual(hookRecord.OnShow, nil, 'failed hook edge unpublished')

    frame.hookError = false
    ok, detail = Render.SyncDefaultClassResources(owner)
    assertTrue(ok, detail)
    assertEqual(frame.hookCount, 1, 'successful retry installs one edge')
    assertTrue(Render.RestoreDefaultClassResources(owner))
end

-- Combat work is deferred and claimed once on combat end.
do
    local frame = NewNativeFrame('CombatFrame', 0.57, true)
    _G.CombatFrame = frame
    local owner = NewOwner('CombatFrame')

    inCombat = true
    local ok, detail = Render.SyncDefaultClassResources(owner)
    assertTrue(ok, detail)
    assertTrue(owner._pendingClassResourceSync, 'combat sync marked pending')
    assertEqual(frame.alpha, 0.57, 'combat sync did not mutate')

    inCombat = false
    ok, detail = Render.OnCombatEnd(owner)
    assertTrue(ok, detail)
    assertEqual(frame.alpha, 0, 'combat-end sync applies once')
    assertEqual(owner._pendingClassResourceSync, nil, 'combat pending cleared')
    assertTrue(Render.RestoreDefaultClassResources(owner))
end

-- Runtime does not publish _inited before the native owner succeeds, and
-- detach/disabled apply propagate unresolved native restore.
do
    ns.Movers = {
        Register = function() return true end,
        Apply = function() return true end,
    }
    ns.Safety = nil
    ns.Media.FetchStatusbar = function(_, token) return token end
    ns.Media.ApplyFont = function() end

    local function NewRuntimeFrame()
        local frame = { shown = true }
        function frame:SetSize() end
        function frame:ClearAllPoints() end
        function frame:SetPoint() end
        function frame:SetScale() end
        function frame:SetStatusBarTexture() end
        function frame:Hide() self.shown = false end
        function frame:Show() self.shown = true end
        function frame:IsShown() return self.shown end
        return frame
    end

    _G.UIParent = {}
    _G.CreateFrame = function() return NewRuntimeFrame() end

    assert(loadfile('modules/CenterBarsRuntime.lua'))('FeelsGoodUI', ns)
    local Runtime = assert(ns.CenterBarsRuntime)
    local runtimeCfg = { enabled = true }
    local refreshOK = false
    local restoreOK = true

    Runtime:Configure({
        GetCenterCfg = function() return runtimeCfg end,
        GetCenterTextCfg = function() return {} end,
        GetSharedFontToken = function() return 'font' end,
        GetSharedFontOutline = function() return '' end,
        GetSharedFontSize = function() return 12 end,
        GetSharedStatusbarToken = function() return 'bar' end,
        CreateCenterMoverSpec = function() return {} end,
        CreatePowerBar = function() return NewRuntimeFrame() end,
        EnsureSegmentPool = function(owner) owner.resourceSegments = owner.resourceSegments or {} end,
        RefreshThresholdConfig = function() end,
        RefreshResourceMode = function()
            if refreshOK then return true end
            return false, 'forced native refresh failure'
        end,
        RestoreDefaultClassResources = function()
            if restoreOK then return true end
            return false, 'forced native restore failure'
        end,
        StopRuneTicker = function() end,
        UpdatePower = function() return true end,
        OnUnitPower = function() end,
        OnRuneEvent = function() end,
    })

    local owner = {}
    local ok, detail = Runtime:Init(owner)
    assertFalse(ok, 'failed native refresh blocks init')
    assertContains(detail, 'forced native refresh failure', 'init failure detail')
    assertEqual(owner._inited, nil, 'failed init unpublished')
    assertEqual(owner.frame.shown, false, 'failed partial frame hidden')

    refreshOK = true
    ok, detail = Runtime:Init(owner)
    assertTrue(ok, detail)
    assertTrue(owner._inited, 'successful retry publishes init')

    restoreOK = false
    ok, detail = Runtime:Detach(owner)
    assertFalse(ok, 'detach restore failure propagates')
    assertContains(detail, 'CenterBars native restore failed', 'detach restore detail')

    runtimeCfg.enabled = false
    ok, detail = Runtime:ApplyConfig(owner)
    assertFalse(ok, 'disabled apply restore failure propagates')
    assertContains(detail, 'CenterBars native restore failed', 'disabled restore detail')
end

print('CenterBars class-resource journal tests passed.')
