local _, ns = ...

local XP = {}
ns.ExperienceBar = XP

local DB = ns.DB
local Media = ns.Media
local Movers = ns.Movers
local Log = ns.Log
local U = ns.U
local Animate = ns.Animate

local XP_FADE_IN_DURATION = 0.16
local XP_FADE_OUT_DURATION = 0.12

local function Clamp(v, minV, maxV, fallback)
    if U and U.ClampWithFallback then
        return U.ClampWithFallback(v, minV, maxV, fallback)
    end
    local n = tonumber(v)
    if type(n) ~= "number" then
        n = fallback
    end
    if type(n) ~= "number" then
        n = minV
    end
    if n < minV then n = minV end
    if n > maxV then n = maxV end
    return n
end

local function ClampWhole(v, minV, maxV, fallback)
    return math.floor(Clamp(v, minV, maxV, fallback) + 0.5)
end

local function GetCfg()
    local p = (DB and DB.GetProfile) and DB:GetProfile() or {}
    local xp = (type(p.experience) == "table") and p.experience or {}

    local cfg = {
        enabled = (xp.enabled ~= false),
        showText = (xp.showText ~= false),
        showRested = (xp.showRested ~= false),
        width = Clamp(xp.width, 200, 900, 420),
        height = Clamp(xp.height, 6, 24, 10),
    }
    return cfg, p
end

local function CreateMoverSpec()
    return {
        label = "XP Bar",
        applyKeys = "experience",
        positionKey = "xpbar",
        getSize = function()
            local cfg = GetCfg()
            return cfg.width, cfg.height
        end,
        buildSizeWrites = function(width, height)
            return {
                { path = { "experience", "width" }, value = ClampWhole(width, 200, 900, 420), rule = { type = "int", min = 200, max = 900, fallback = 420 } },
                { path = { "experience", "height" }, value = ClampWhole(height, 6, 24, 10), rule = { type = "int", min = 6, max = 24, fallback = 10 } },
            }
        end,
        previewSize = function(frame, width, height)
            local resolvedWidth = ClampWhole(width, 200, 900, 420)
            local resolvedHeight = ClampWhole(height, 6, 24, 10)
            if frame and frame.SetSize then frame:SetSize(resolvedWidth, resolvedHeight) end
            return resolvedWidth, resolvedHeight
        end,
        buildWheelWrites = function(delta, shiftDown)
            local cfg = GetCfg()
            if shiftDown then
                return {
                    path = { "experience", "height" },
                    value = ClampWhole(cfg.height + delta, 6, 24, 10),
                    rule = { type = "int", min = 6, max = 24, fallback = 10 },
                }
            end

            return {
                path = { "experience", "width" },
                value = ClampWhole(cfg.width + ((tonumber(delta) or 0) * 10), 200, 900, 420),
                rule = { type = "int", min = 200, max = 900, fallback = 420 },
            }
        end,
        previewWheel = function(frame, delta, shiftDown)
            local cfg = GetCfg()
            local width, height = cfg.width, cfg.height
            if shiftDown then height = ClampWhole(height + delta, 6, 24, 10)
            else width = ClampWhole(width + ((tonumber(delta) or 0) * 10), 200, 900, 420) end
            if frame and frame.SetSize then frame:SetSize(width, height) end
            return true
        end,
    }
end

local STATUS_TRACKING_FRAME_NAMES = {
    "StatusTrackingBarManager",
    "MainStatusTrackingBarContainer",
    "SecondaryStatusTrackingBarContainer",
}

local function ReadFrameAlpha(frame)
    if not (frame and type(frame.GetAlpha) == "function") then return nil end
    local ok, value = pcall(frame.GetAlpha, frame)
    return ok and type(value) == "number" and value or nil
end

local function ReadFrameMouseEnabled(frame)
    if not (frame and type(frame.IsMouseEnabled) == "function") then return nil end
    local ok, value = pcall(frame.IsMouseEnabled, frame)
    if not ok or type(value) ~= "boolean" then return nil end
    return value
end

local function SetFrameAlpha(frame, value)
    if not (frame and type(frame.SetAlpha) == "function" and type(value) == "number") then
        return false
    end
    local current = ReadFrameAlpha(frame)
    if current == value then return true end
    return pcall(frame.SetAlpha, frame, value)
end

local function SetFrameMouseEnabled(frame, enabled)
    if not (frame and type(frame.EnableMouse) == "function" and type(enabled) == "boolean") then
        return false
    end
    local current = ReadFrameMouseEnabled(frame)
    if current == enabled then return true end
    return pcall(frame.EnableMouse, frame, enabled)
end

local function CaptureStatusTrackingFrame(module, frame)
    if type(module) ~= "table" or type(frame) ~= "table" then return nil end
    module._statusTrackingSnapshot = type(module._statusTrackingSnapshot) == "table"
        and module._statusTrackingSnapshot
        or {}

    local record = module._statusTrackingSnapshot[frame]
    if record then return record end

    record = {
        alpha = ReadFrameAlpha(frame),
        mouseEnabled = ReadFrameMouseEnabled(frame),
    }
    module._statusTrackingSnapshot[frame] = record
    return record
end

local function SuppressBlizzardStatusTracking(module)
    for i = 1, #STATUS_TRACKING_FRAME_NAMES do
        local frame = _G[STATUS_TRACKING_FRAME_NAMES[i]]
        if type(frame) == "table" then
            CaptureStatusTrackingFrame(module, frame)
            SetFrameAlpha(frame, 0)
            SetFrameMouseEnabled(frame, false)
        end
    end
    return true
end

local function RestoreBlizzardStatusTracking(module)
    local snapshot = module and module._statusTrackingSnapshot
    if type(snapshot) ~= "table" then return true end

    module._statusTrackingSnapshot = nil
    for frame, record in pairs(snapshot) do
        if type(frame) == "table" and type(record) == "table" then
            -- Restore only properties that still carry our suppression value.
            -- A different owner changing them while attached wins.
            if type(record.alpha) == "number" and ReadFrameAlpha(frame) == 0 then
                SetFrameAlpha(frame, record.alpha)
            end
            if type(record.mouseEnabled) == "boolean" and ReadFrameMouseEnabled(frame) == false then
                SetFrameMouseEnabled(frame, record.mouseEnabled)
            end
        end
    end
    return true
end

local function EnsureStatusTrackingHooks(module)
    if module._statusTrackingHooked then return true end

    local manager = _G.StatusTrackingBarManager
    local secureHook = _G.hooksecurefunc or hooksecurefunc
    if type(manager) ~= "table" or type(secureHook) ~= "function" then
        return false
    end

    local hooked = false
    local function Resuppress()
        if module._suppressBlizzardTracking == true then
            SuppressBlizzardStatusTracking(module)
        end
    end

    if type(manager.UpdateBarsShown) == "function" then
        secureHook(manager, "UpdateBarsShown", Resuppress)
        hooked = true
    end
    if type(manager.UpdateBarVisuals) == "function" then
        secureHook(manager, "UpdateBarVisuals", Resuppress)
        hooked = true
    end

    module._statusTrackingHooked = hooked
    return hooked
end

local function MaintainStatusTrackingOwnership(module)
    EnsureStatusTrackingHooks(module)
    return SuppressBlizzardStatusTracking(module)
end

local function SetBarVisible(bar, shouldShow, immediate)
    if not bar then
        return
    end

    local visible = (shouldShow == true)
    if immediate then
        if Animate and type(Animate.CancelFade) == "function" then
            Animate.CancelFade(bar)
        end
        bar._fguiVisible = visible
        bar:SetAlpha(visible and 1 or 0)
        if visible then
            if not bar:IsShown() then
                bar:Show()
            end
        elseif bar:IsShown() then
            bar:Hide()
        end
        return
    end

    if bar._fguiVisible == visible then
        return
    end
    bar._fguiVisible = visible

    if Animate then
        if visible and type(Animate.FadeIn) == "function" then
            if Animate.FadeIn(bar, XP_FADE_IN_DURATION, { showOnStart = true, toAlpha = 1 }) then
                return
            end
        elseif (not visible) and type(Animate.FadeOut) == "function" then
            if Animate.FadeOut(bar, XP_FADE_OUT_DURATION, { hideOnFinished = true, toAlpha = 0 }) then
                return
            end
        end
    end

    bar:SetAlpha(visible and 1 or 0)
    if visible then
        if not bar:IsShown() then
            bar:Show()
        end
    elseif bar:IsShown() then
        bar:Hide()
    end
end

local function EnsureFrame(module)
    if module._bar then
        return module._bar
    end

    local bar = CreateFrame("StatusBar", "FGUI_XPBar", UIParent)
    bar:SetSize(420, 10)
    bar:SetPoint("CENTER", UIParent, "CENTER", 0, -296)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetFrameStrata("LOW")
    bar:SetFrameLevel(10)
    bar:SetStatusBarTexture("Interface/Buttons/WHITE8x8")
    bar._fguiVisible = true

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0.07, 0.07, 0.07, 1)

    bar.rested = bar:CreateTexture(nil, "ARTWORK")
    bar.rested:SetColorTexture(0.15, 0.35, 0.80, 0.55)
    bar.rested:Hide()

    bar.text = bar:CreateFontString(nil, "OVERLAY")
    bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    bar.text:SetJustifyH("CENTER")
    bar.text:SetText("")

    if Media and Media.CreateBorder then
        Media:CreateBorder(bar)
    end

    module._bar = bar

    if Movers and Movers.Register then
        Movers:Register("xpbar", bar, CreateMoverSpec())
        Movers:Apply("xpbar", bar)
    end

    return bar
end

local function UpdateRestedOverlay(bar, currentXP, maxXP, restedXP)
    if not (bar and bar.rested) then return end
    if type(maxXP) ~= "number" or maxXP <= 0 then
        bar.rested:Hide()
        return
    end
    if type(restedXP) ~= "number" or restedXP <= 0 then
        bar.rested:Hide()
        return
    end

    local startRatio = currentXP / maxXP
    local endRatio = math.min(currentXP + restedXP, maxXP) / maxXP
    if endRatio <= startRatio then
        bar.rested:Hide()
        return
    end

    local width = tonumber(bar:GetWidth()) or 0
    if width <= 0 then
        bar.rested:Hide()
        return
    end

    local startX = math.floor((width * startRatio) + 0.5)
    local overlayW = math.floor((width * (endRatio - startRatio)) + 0.5)
    if overlayW < 1 then
        overlayW = 1
    end

    bar.rested:ClearAllPoints()
    bar.rested:SetPoint("TOPLEFT", bar, "TOPLEFT", startX, 0)
    bar.rested:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", startX, 0)
    bar.rested:SetWidth(overlayW)
    bar.rested:Show()
end

local function ClampProgress(currentValue, maxValue)
    local current = tonumber(currentValue)
    local maxV = tonumber(maxValue)
    if type(maxV) ~= "number" or maxV <= 0 then
        return nil, nil
    end
    if type(current) ~= "number" or current < 0 then
        current = 0
    end
    if current > maxV then
        current = maxV
    end
    return current, maxV
end

local function BuildXPProgress(cfg)
    local current, maxV = ClampProgress(UnitXP("player") or 0, UnitXPMax("player") or 0)
    if not current then
        return nil
    end

    local rested = 0
    if cfg and cfg.showRested then
        rested = tonumber(GetXPExhaustion()) or 0
        if rested < 0 then
            rested = 0
        end
    end

    return {
        mode = "xp",
        label = (_G and _G.XP) or "XP",
        current = current,
        max = maxV,
        rested = rested,
    }
end

local function BuildReputationProgress()
    local reputationAPI = C_Reputation
    if type(reputationAPI) ~= "table" or type(reputationAPI.GetWatchedFactionData) ~= "function" then
        return nil
    end

    local watchedFactionData = reputationAPI.GetWatchedFactionData()
    if type(watchedFactionData) ~= "table" then
        return nil
    end

    local name = watchedFactionData.name
    if type(name) ~= "string" or name == "" then
        return nil
    end

    local factionID = tonumber(watchedFactionData.factionID) or 0
    local minBar = tonumber(watchedFactionData.currentReactionThreshold)
    local maxBar = tonumber(watchedFactionData.nextReactionThreshold)
    local value = tonumber(watchedFactionData.currentStanding)
    local gossipInfoAPI = C_GossipInfo
    local friendshipInfo
    local friendshipFactionID = 0

    if factionID > 0 and type(gossipInfoAPI) == "table" and type(gossipInfoAPI.GetFriendshipReputation) == "function" then
        friendshipInfo = gossipInfoAPI.GetFriendshipReputation(factionID)
        friendshipFactionID = tonumber(friendshipInfo and friendshipInfo.friendshipFactionID) or 0
    end

    local isMajorFaction = factionID > 0
        and type(reputationAPI.IsMajorFaction) == "function"
        and reputationAPI.IsMajorFaction(factionID) == true

    if factionID > 0
        and type(reputationAPI.IsFactionParagonForCurrentPlayer) == "function"
        and type(reputationAPI.GetFactionParagonInfo) == "function"
        and reputationAPI.IsFactionParagonForCurrentPlayer(factionID) then
        local currentValue, threshold, _, hasRewardPending = reputationAPI.GetFactionParagonInfo(factionID)
        if type(currentValue) == "number" and type(threshold) == "number" and threshold > 0 then
            minBar = 0
            maxBar = threshold
            value = currentValue % threshold
            if hasRewardPending then
                value = value + threshold
            end
        end
    elseif isMajorFaction and type(C_MajorFactions) == "table" and type(C_MajorFactions.GetMajorFactionData) == "function" then
        local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID)
        minBar = 0
        maxBar = tonumber(majorFactionData and majorFactionData.renownLevelThreshold)
    elseif friendshipFactionID > 0 then
        if type(friendshipInfo) ~= "table" and type(gossipInfoAPI) == "table" and type(gossipInfoAPI.GetFriendshipReputation) == "function" then
            friendshipInfo = gossipInfoAPI.GetFriendshipReputation(factionID)
        end

        local nextThreshold = tonumber(friendshipInfo and friendshipInfo.nextThreshold)
        if type(nextThreshold) == "number" and nextThreshold > 0 then
            minBar = tonumber(friendshipInfo and friendshipInfo.reactionThreshold) or 0
            maxBar = nextThreshold
            value = tonumber(friendshipInfo and friendshipInfo.standing)
        else
            minBar, maxBar, value = 0, 1, 1
        end
    end

    if type(minBar) == "number" and type(maxBar) == "number" and type(value) == "number" then
        maxBar = maxBar - minBar
        value = value - minBar
    end

    if type(maxBar) ~= "number" or maxBar <= 0 or type(value) ~= "number" then
        -- Keep watched reputations visible at capped/edge states instead of falling through to honor.
        maxBar = 1
        value = (type(value) == "number" and value > 0) and 1 or 0
    end

    local current, maxV = ClampProgress(value, maxBar)
    if not current then
        return nil
    end

    if factionID > 0
        and type(reputationAPI.IsAccountWideReputation) == "function"
        and reputationAPI.IsAccountWideReputation(factionID)
        and type(REPUTATION_STATUS_BAR_LABEL_ACCOUNT_WIDE) == "string"
        and REPUTATION_STATUS_BAR_LABEL_ACCOUNT_WIDE ~= "" then
        name = name .. " " .. REPUTATION_STATUS_BAR_LABEL_ACCOUNT_WIDE
    end

    return {
        mode = "reputation",
        label = name,
        current = current,
        max = maxV,
        rested = 0,
    }
end

local function BuildHonorProgress()
    local current, maxV = ClampProgress(UnitHonor("player"), UnitHonorMax("player"))
    if not current then
        return nil
    end

    return {
        mode = "honor",
        label = HONOR or "Honor",
        current = current,
        max = maxV,
        rested = 0,
    }
end

local function ResolveProgress(cfg)
    local xpData = BuildXPProgress(cfg)
    if xpData then
        return xpData
    end

    local reputationData = BuildReputationProgress()
    if reputationData then
        return reputationData
    end

    return BuildHonorProgress()
end

local function ApplyModeColor(bar, mode)
    if not bar then
        return
    end
    if mode == "reputation" then
        bar:SetStatusBarColor(0.24, 0.68, 0.30, 1.0)
    elseif mode == "honor" then
        bar:SetStatusBarColor(0.84, 0.22, 0.18, 1.0)
    else
        bar:SetStatusBarColor(0.88, 0.62, 0.18, 1.0)
    end
end

function XP:Update()
    local cfg, profile = GetCfg()
    local bar = EnsureFrame(self)

    if not cfg.enabled then
        SetBarVisible(bar, false, false)
        return
    end

    bar:SetSize(cfg.width, cfg.height)
    bar:SetStatusBarTexture(Media:FetchStatusbar((profile.media and profile.media.statusbar) or "Interface/Buttons/WHITE8x8"))

    if bar.text then
        local ufText = (profile.unitframes and profile.unitframes.text) or {}
        local font = (profile.media and profile.media.font) or ufText.font or "Fonts\\FRIZQT__.TTF"
        local size = Clamp(ufText.size, 8, 16, 11)
        local outline = ufText.outline or "OUTLINE"
        if Media and Media.ApplyFont then
            Media:ApplyFont(bar.text, font, size, outline)
        end
    end

    local progress = ResolveProgress(cfg)
    if type(progress) ~= "table" then
        SetBarVisible(bar, false, false)
        return
    end

    ApplyModeColor(bar, progress.mode)
    bar:SetMinMaxValues(0, progress.max)
    bar:SetValue(progress.current)

    local restedXP = 0
    if progress.mode == "xp" then
        restedXP = tonumber(progress.rested) or 0
        UpdateRestedOverlay(bar, progress.current, progress.max, restedXP)
    elseif bar.rested then
        bar.rested:Hide()
    end

    if cfg.showText and bar.text then
        local percent = math.floor(((progress.current / progress.max) * 100) + 0.5)
        local text = string.format("%s %d / %d (%d%%)", tostring(progress.label or "XP"), progress.current, progress.max, percent)
        if progress.mode == "xp" and type(restedXP) == "number" and restedXP > 0 then
            text = text .. string.format(" +%d", math.floor(restedXP + 0.5))
        end
        bar.text:SetText(text)
        bar.text:Show()
    elseif bar.text then
        bar.text:SetText("")
        bar.text:Hide()
    end

    SetBarVisible(bar, true, false)
end

local function EnsureEventFrame(module)
    if module._events then
        return module._events
    end

    local ev = CreateFrame("Frame")
    ev:SetScript("OnEvent", function(_, event, unit)
        if (event == "PLAYER_XP_UPDATE" or event == "HONOR_XP_UPDATE" or event == "PLAYER_MAX_LEVEL_UPDATE") and unit and unit ~= "player" then
            return
        end
        if module._suppressBlizzardTracking == true then
            MaintainStatusTrackingOwnership(module)
        end
        if type(module.Update) == "function" then
            module:Update()
        end
    end)

    module._events = ev
    return ev
end

function XP:ApplyConfig()
    local initialized, initDetail = self:Init()
    if initialized == false then return false, initDetail end

    local cfg = GetCfg()
    local bar = self._bar
    local ev = self._events
    if not (bar and ev) then
        return false, "ExperienceBar runtime owners unavailable"
    end

    ev:UnregisterAllEvents()
    if not cfg.enabled then
        self._suppressBlizzardTracking = nil
        RestoreBlizzardStatusTracking(self)
        SetBarVisible(bar, false, true)
        return true
    end

    self._suppressBlizzardTracking = true
    MaintainStatusTrackingOwnership(self)

    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("PLAYER_XP_UPDATE")
    ev:RegisterEvent("PLAYER_MAX_LEVEL_UPDATE")
    ev:RegisterEvent("PLAYER_LEVEL_CHANGED")
    ev:RegisterEvent("PLAYER_LEVEL_UP")
    ev:RegisterEvent("UPDATE_EXHAUSTION")
    ev:RegisterEvent("UPDATE_FACTION")
    ev:RegisterEvent("HONOR_XP_UPDATE")
    ev:RegisterEvent("ENABLE_XP_GAIN")
    ev:RegisterEvent("DISABLE_XP_GAIN")

    self:Update()
    return true
end

function XP:Attach()
    if self._attached then return true end

    local initialized, detail = self:Init()
    if initialized == false then return false, detail end
    self._attached = true
    return true
end

function XP:Detach()
    self._attached = false

    if self._events and self._events.UnregisterAllEvents then
        self._events:UnregisterAllEvents()
    end
    self._suppressBlizzardTracking = nil
    RestoreBlizzardStatusTracking(self)
    if self._bar then
        SetBarVisible(self._bar, false, true)
    end
    return true
end

function XP:Init()
    if self._inited then return true end

    local bar = EnsureFrame(self)
    local events = EnsureEventFrame(self)
    if not (bar and events) then
        return false, "ExperienceBar initialization failed"
    end

    self._inited = true
    if Log and Log.Debug then
        Log:Debug("ExperienceBar loaded")
    end
    return true
end

return XP
