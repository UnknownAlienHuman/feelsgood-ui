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

local timers = {}
local afterCallbacks = {}
_G = _G or {}
_G.C_Timer = {
    NewTimer = function(delay, callback)
        local timer = {
            delay = delay,
            callback = callback,
            cancelled = false,
            cancelCalls = 0,
        }
        function timer:Cancel()
            self.cancelCalls = self.cancelCalls + 1
            self.cancelled = true
        end
        timers[#timers + 1] = timer
        return timer
    end,
    After = function(delay, callback)
        afterCallbacks[#afterCallbacks + 1] = {
            delay = delay,
            callback = callback,
        }
    end,
}

local function NewAnimationGroup(frame)
    local group = {
        frame = frame,
        playing = false,
        playCalls = 0,
        stopCalls = 0,
        scripts = {},
    }
    function group:CreateAnimation(kind)
        assertEqual(kind, "Alpha", "animation kind")
        local animation = { kind = kind }
        function animation:SetOrder(value) self.order = value end
        function animation:SetSmoothing(value) self.smoothing = value end
        function animation:SetDuration(value) self.duration = value end
        function animation:SetFromAlpha(value) self.fromAlpha = value end
        function animation:SetToAlpha(value) self.toAlpha = value end
        self.animation = animation
        return animation
    end
    function group:SetScript(name, callback)
        self.scripts[name] = callback
    end
    function group:IsPlaying() return self.playing end
    function group:Play()
        self.playing = true
        self.playCalls = self.playCalls + 1
    end
    function group:Stop()
        self.playing = false
        self.stopCalls = self.stopCalls + 1
    end
    function group:Finish()
        self.playing = false
        if self.scripts.OnFinished then self.scripts.OnFinished(self) end
    end
    return group
end

local function NewFrame(alpha, shown)
    local frame = {
        alpha = alpha or 0,
        shown = shown == true,
        groups = {},
        createCalls = 0,
        showCalls = 0,
        hideCalls = 0,
    }
    function frame:CreateAnimationGroup()
        self.createCalls = self.createCalls + 1
        local group = NewAnimationGroup(self)
        self.groups[#self.groups + 1] = group
        return group
    end
    function frame:SetAlpha(value) self.alpha = value end
    function frame:GetAlpha() return self.alpha end
    function frame:Show() self.shown = true; self.showCalls = self.showCalls + 1 end
    function frame:Hide() self.shown = false; self.hideCalls = self.hideCalls + 1 end
    function frame:IsShown() return self.shown end
    return frame
end

local ns = {}
assert(loadfile("core/Animate.lua"))("FeelsGoodUI", ns)
local Animate = assert(ns.Animate)
assertEqual(getmetatable(Animate._frameRegistry).__mode, "k", "weak frame registry")
assertEqual(getmetatable(Animate._timerRegistry).__mode, "k", "weak timer registry")

local frame = NewFrame(0.35, false)
assertEqual(Animate.FadeIn(frame, 0.20, { fromAlpha = 0, toAlpha = 1 }), true, "fade in starts")
assertEqual(frame.shown, true, "fade in shows frame")
assertEqual(frame.alpha, 0, "fade in start alpha")
assertEqual(frame.createCalls, 1, "one fade-in group")
local frameState = Animate._frameRegistry[frame]
assertEqual(type(frameState), "table", "frame state in registry")
assertEqual(type(frameState.fadeIn), "table", "fade-in group in registry")
assertEqual(frameState.fadeIn.playing, true, "fade-in playing")
assertEqual(frameState.fadeIn.animation.duration, 0.20, "fade-in duration")
assertEqual(frameState.fadeIn.animation.fromAlpha, 0, "fade-in animation from")
assertEqual(frameState.fadeIn.animation.toAlpha, 1, "fade-in animation to")
assertNil(rawget(frame, "_fguiAnimateState"), "frame has no animation marker")
assertNil(rawget(frameState.fadeIn, "_fguiFinalAlpha"), "group has no final-alpha marker")
assertNil(rawget(frameState.fadeIn, "_fguiHideOnFinished"), "group has no hide marker")
frameState.fadeIn:Finish()
assertEqual(frame.alpha, 1, "fade-in terminal alpha")
assertEqual(frame.shown, true, "fade-in remains shown")

local fadeInGroup = frameState.fadeIn
assertEqual(Animate.FadeIn(frame, 0.10, { fromAlpha = 0.25, toAlpha = 0.90 }), true, "repeat fade in")
assertEqual(frameState.fadeIn, fadeInGroup, "fade-in group reused")
assertEqual(frame.createCalls, 1, "repeat fade-in allocates nothing")
assertEqual(frame.alpha, 0.25, "repeat fade-in start alpha")
fadeInGroup:Finish()
assertEqual(frame.alpha, 0.90, "repeat fade-in terminal alpha")

assertEqual(Animate.FadeOut(frame, 0.15, { fromAlpha = 0.90, toAlpha = 0.10, hideOnFinished = true }), true, "fade out starts")
assertEqual(frame.createCalls, 2, "one fade-out group")
assertEqual(frameState.fadeOut.playing, true, "fade-out playing")
assertEqual(frame.alpha, 0.90, "fade-out start alpha")
frameState.fadeOut:Finish()
assertEqual(frame.alpha, 0.10, "fade-out terminal alpha")
assertEqual(frame.shown, false, "fade-out hides frame")

assertEqual(Animate.FadeIn(frame, 1), true, "fade in for cancellation")
assertEqual(frameState.fadeIn.playing, true, "cancel target playing")
assertEqual(Animate.CancelFade(frame, { resetAlpha = 0.55 }), true, "cancel fade")
assertEqual(frameState.fadeIn.playing, false, "fade-in stopped")
assertEqual(frame.alpha, 0.55, "cancel reset alpha")

local untouched = NewFrame(0.20, true)
assertNil(Animate._frameRegistry[untouched], "untouched frame has no registry state")
assertEqual(Animate.CancelFade(untouched, { resetAlpha = 0.40 }), true, "cancel untouched frame")
assertEqual(untouched.alpha, 0.40, "untouched alpha reset")
assertNil(Animate._frameRegistry[untouched], "cancel does not create registry state")
assertNil(rawget(untouched, "_fguiAnimateState"), "untouched frame has no marker")

local owner = {}
local calls = {}
assertEqual(Animate.After(owner, "refresh", 1.25, function(host)
    calls[#calls + 1] = host
end), true, "schedule timer")
assertEqual(#timers, 1, "one timer created")
local timer1 = timers[1]
local timerState = Animate._timerRegistry[owner]
assertEqual(type(timerState), "table", "timer state in registry")
assertEqual(timerState.entries.refresh, timer1, "timer entry stored")
assertNil(rawget(owner, "_fguiAnimateTimers"), "owner has no timer marker")

assertEqual(Animate.After(owner, "refresh", 2.50, function(host)
    calls[#calls + 1] = host
end), true, "replace timer")
assertEqual(#timers, 2, "replacement timer created")
local timer2 = timers[2]
assertEqual(timer1.cancelled, true, "old timer cancelled")
assertEqual(timerState.entries.refresh, timer2, "replacement entry stored")
timer1.callback()
assertEqual(#calls, 0, "stale timer callback invalidated")
timer2.callback()
assertEqual(#calls, 1, "current timer callback runs")
assertEqual(calls[1], owner, "timer callback receives owner")
assertNil(timerState.entries.refresh, "timer entry cleared")

assertEqual(Animate.After(owner, "cancel", 1, function()
    calls[#calls + 1] = "cancelled"
end), true, "schedule cancellable timer")
local timer3 = timers[3]
assertEqual(Animate.CancelAfter(owner, "cancel"), true, "cancel timer")
assertEqual(timer3.cancelled, true, "timer handle cancelled")
timer3.callback()
assertEqual(#calls, 1, "cancelled callback invalidated")

assertEqual(Animate.After(owner, "zero", 0, function(host)
    calls[#calls + 1] = host
end), true, "schedule zero-delay callback")
assertEqual(#afterCallbacks, 1, "zero-delay callback queued")
assertEqual(Animate.CancelAfter(owner, "zero"), false, "zero-delay has no timer handle")
afterCallbacks[1].callback()
assertEqual(#calls, 1, "zero-delay callback token invalidated")

assertEqual(Animate.After(owner, "a", 1, function() end), true, "schedule a")
assertEqual(Animate.After(owner, "b", 1, function() end), true, "schedule b")
local timerA, timerB = timers[#timers - 1], timers[#timers]
assertEqual(Animate.CancelAllAfter(owner), true, "cancel all timers")
assertEqual(timerA.cancelled, true, "timer a cancelled")
assertEqual(timerB.cancelled, true, "timer b cancelled")
assertNil(timerState.entries.a, "timer a entry cleared")
assertNil(timerState.entries.b, "timer b entry cleared")
assertNil(rawget(owner, "_fguiAnimateTimers"), "owner remains marker-free")

print("Animate weak registry tests passed.")
