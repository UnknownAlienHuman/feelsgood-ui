-- FeelsGoodUI: shared animation/timer helpers.
-- Purpose: one place for fade transitions and cancelable keyed delays.

local _, ns = ...

local Animate = {}
ns.Animate = Animate

local DEFAULT_FADE_IN_DURATION = 0.20
local DEFAULT_FADE_OUT_DURATION = 0.20
local EPSILON = 0.001

local abs = math.abs
local max = math.max

local function ClampDuration(duration, fallback)
    local d = tonumber(duration)
    if type(d) ~= "number" then
        d = fallback
    end
    d = tonumber(d) or 0
    if d < 0 then d = 0 end
    return d
end

local function ResolveAlpha(alpha, fallback)
    local a = tonumber(alpha)
    if type(a) ~= "number" then
        a = fallback
    end
    a = tonumber(a) or 0
    if a < 0 then a = 0 end
    if a > 1 then a = 1 end
    return a
end

local function IsAnimFrame(frame)
    return frame
        and type(frame.CreateAnimationGroup) == "function"
        and type(frame.SetAlpha) == "function"
end

local function StopGroup(group)
    if group and group.IsPlaying and group:IsPlaying() then
        group:Stop()
    end
end

local function GetFrameState(frame)
    local state = frame and frame._fguiAnimateState
    if type(state) ~= "table" then
        state = {}
        if frame then
            frame._fguiAnimateState = state
        end
    end
    return state
end

local function EnsureFadeGroup(frame, state, key)
    local group = state[key]
    if group then
        return group, state[key .. "Alpha"]
    end

    group = frame:CreateAnimationGroup()
    local alpha = group:CreateAnimation("Alpha")
    state[key] = group
    state[key .. "Alpha"] = alpha

    group:SetScript("OnFinished", function()
        if group._fguiFinalAlpha ~= nil then
            frame:SetAlpha(group._fguiFinalAlpha)
        end
        if group._fguiHideOnFinished == true and type(frame.Hide) == "function" then
            frame:Hide()
        end
    end)

    return group, alpha
end

local function PlayFade(frame, key, duration, fromAlpha, toAlpha, hideOnFinished, showOnStart)
    if not IsAnimFrame(frame) then
        return false
    end

    local state = GetFrameState(frame)
    local oppositeKey = (key == "fadeIn") and "fadeOut" or "fadeIn"
    StopGroup(state[oppositeKey])

    local group, alpha = EnsureFadeGroup(frame, state, key)
    StopGroup(group)

    local d = ClampDuration(duration, (key == "fadeIn") and DEFAULT_FADE_IN_DURATION or DEFAULT_FADE_OUT_DURATION)
    fromAlpha = ResolveAlpha(fromAlpha, frame:GetAlpha() or 1)
    toAlpha = ResolveAlpha(toAlpha, (key == "fadeIn") and 1 or 0)

    if showOnStart == true and type(frame.Show) == "function" then
        frame:Show()
    end

    if d <= 0 or abs(fromAlpha - toAlpha) <= EPSILON then
        frame:SetAlpha(toAlpha)
        if hideOnFinished == true and type(frame.Hide) == "function" then
            frame:Hide()
        end
        return true
    end

    frame:SetAlpha(fromAlpha)
    alpha:SetDuration(d)
    alpha:SetFromAlpha(fromAlpha)
    alpha:SetToAlpha(toAlpha)
    group._fguiFinalAlpha = toAlpha
    group._fguiHideOnFinished = (hideOnFinished == true)
    group:Play()
    return true
end

function Animate.CancelFade(frame, resetAlpha)
    if not IsAnimFrame(frame) then
        return false
    end

    local state = GetFrameState(frame)
    StopGroup(state.fadeIn)
    StopGroup(state.fadeOut)

    if resetAlpha ~= nil then
        frame:SetAlpha(ResolveAlpha(resetAlpha, frame:GetAlpha() or 1))
    end
    return true
end

function Animate.FadeIn(frame, duration, opts)
    opts = (type(opts) == "table") and opts or {}
    if not IsAnimFrame(frame) then
        if frame and frame.SetAlpha then frame:SetAlpha(1) end
        if frame and frame.Show then frame:Show() end
        return false
    end

    local fromAlpha = opts.fromAlpha
    if fromAlpha == nil then
        if frame.IsShown and not frame:IsShown() then
            fromAlpha = 0
        else
            fromAlpha = frame:GetAlpha() or 1
        end
    end

    return PlayFade(
        frame,
        "fadeIn",
        duration,
        fromAlpha,
        opts.toAlpha or 1,
        false,
        opts.showOnStart ~= false
    )
end

function Animate.FadeOut(frame, duration, opts)
    opts = (type(opts) == "table") and opts or {}
    if not IsAnimFrame(frame) then
        if frame and frame.SetAlpha then frame:SetAlpha(0) end
        if (opts.hideOnFinished ~= false) and frame and frame.Hide then frame:Hide() end
        return false
    end

    local fromAlpha = opts.fromAlpha
    if fromAlpha == nil then
        fromAlpha = frame:GetAlpha() or 1
    end

    return PlayFade(
        frame,
        "fadeOut",
        duration,
        fromAlpha,
        opts.toAlpha or 0,
        opts.hideOnFinished ~= false,
        opts.showOnStart == true
    )
end

local function GetTimerState(owner)
    local host = (type(owner) == "table") and owner or Animate
    local state = host._fguiAnimateTimers
    if type(state) ~= "table" then
        state = { entries = {}, tokens = {} }
        host._fguiAnimateTimers = state
    end
    return host, state
end

function Animate.CancelAfter(owner, key)
    if type(key) ~= "string" or key == "" then
        return false
    end

    local _, state = GetTimerState(owner)
    local entries = state.entries
    local tokens = state.tokens

    local existing = entries[key]
    if type(existing) == "table" and type(existing.Cancel) == "function" then
        pcall(existing.Cancel, existing)
    end
    entries[key] = nil
    tokens[key] = max((tonumber(tokens[key]) or 0) + 1, 1)
    return existing ~= nil
end

function Animate.After(owner, key, delay, callback)
    if type(key) ~= "string" or key == "" then
        return false
    end
    if type(callback) ~= "function" then
        return false
    end

    local host, state = GetTimerState(owner)
    local entries = state.entries
    local tokens = state.tokens
    local d = ClampDuration(delay, 0)

    Animate.CancelAfter(host, key)
    local token = max((tonumber(tokens[key]) or 0) + 1, 1)
    tokens[key] = token

    local function Run()
        local current = host._fguiAnimateTimers
        if type(current) ~= "table" then
            return
        end
        if (tonumber(current.tokens[key]) or 0) ~= token then
            return
        end

        current.entries[key] = nil
        callback(host)
    end

    if d <= 0 then
        if C_Timer and C_Timer.After then
            entries[key] = true
            C_Timer.After(0, Run)
            return true
        end
        Run()
        return true
    end

    if C_Timer and C_Timer.NewTimer then
        entries[key] = C_Timer.NewTimer(d, Run)
        return true
    end

    if C_Timer and C_Timer.After then
        entries[key] = true
        C_Timer.After(d, Run)
        return true
    end

    Run()
    return true
end

function Animate.CancelAllAfter(owner)
    local host, state = GetTimerState(owner)
    local keys = {}
    for key in pairs(state.entries) do
        keys[#keys + 1] = key
    end
    for i = 1, #keys do
        Animate.CancelAfter(host, keys[i])
    end
end

return Animate
