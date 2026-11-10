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

local STATUS_TRACKING_MANAGED_ALPHA = 0
local STATUS_TRACKING_MANAGED_MOUSE = false
local STATUS_TRACKING_ALPHA_EPSILON = 0.0001

local function FrameLabel(name, frame)
    if type(name) == "string" and name ~= "" then
        return name
    end
    if frame and type(frame.GetName) == "function" then
        local ok, value = pcall(frame.GetName, frame)
        if ok and type(value) == "string" and value ~= "" then
            return value
        end
    end
    return tostring(frame or "unknown frame")
end

local function SameAlpha(a, b)
    return type(a) == "number"
        and type(b) == "number"
        and math.abs(a - b) <= STATUS_TRACKING_ALPHA_EPSILON
end

local function ReadFrameAlpha(frame)
    if not (frame and type(frame.GetAlpha) == "function") then
        return false, nil, "GetAlpha is unavailable"
    end
    local ok, value = pcall(frame.GetAlpha, frame)
    if not ok then
        return false, nil, "GetAlpha failed: " .. tostring(value)
    end
    if type(value) ~= "number" then
        return false, nil, "GetAlpha returned a non-number"
    end
    return true, value
end

local function ReadFrameMouseEnabled(frame)
    if not (frame and type(frame.IsMouseEnabled) == "function") then
        return false, nil, "IsMouseEnabled is unavailable"
    end
    local ok, value = pcall(frame.IsMouseEnabled, frame)
    if not ok then
        return false, nil, "IsMouseEnabled failed: " .. tostring(value)
    end
    if type(value) ~= "boolean" then
        return false, nil, "IsMouseEnabled returned a non-boolean"
    end
    return true, value
end

local function WriteFrameAlpha(frame, value)
    local readable, current, readDetail = ReadFrameAlpha(frame)
    if not readable then
        return false, readDetail
    end
    if SameAlpha(current, value) then
        return true
    end
    if type(frame.SetAlpha) ~= "function" then
        return false, "SetAlpha is unavailable"
    end

    local ok, err = pcall(frame.SetAlpha, frame, value)
    if not ok then
        return false, "SetAlpha failed: " .. tostring(err)
    end

    local verified, actual, verifyDetail = ReadFrameAlpha(frame)
    if not verified then
        return false, "SetAlpha could not be verified: " .. tostring(verifyDetail)
    end
    if not SameAlpha(actual, value) then
        return false, "SetAlpha did not retain the requested value"
    end
    return true
end

local function WriteFrameMouseEnabled(frame, enabled)
    local readable, current, readDetail = ReadFrameMouseEnabled(frame)
    if not readable then
        return false, readDetail
    end
    if current == enabled then
        return true
    end
    if type(frame.EnableMouse) ~= "function" then
        return false, "EnableMouse is unavailable"
    end

    local ok, err = pcall(frame.EnableMouse, frame, enabled)
    if not ok then
        return false, "EnableMouse failed: " .. tostring(err)
    end

    local verified, actual, verifyDetail = ReadFrameMouseEnabled(frame)
    if not verified then
        return false, "EnableMouse could not be verified: " .. tostring(verifyDetail)
    end
    if actual ~= enabled then
        return false, "EnableMouse did not retain the requested value"
    end
    return true
end

local function GetStatusTrackingSnapshot(module)
    if type(module) ~= "table" then return nil end
    local snapshot = module._statusTrackingSnapshot
    if type(snapshot) ~= "table" then
        snapshot = {}
        module._statusTrackingSnapshot = snapshot
    end
    return snapshot
end

local function CaptureStatusTrackingFrame(module, name, frame)
    if type(module) ~= "table" or type(frame) ~= "table" then
        return nil
    end

    local snapshot = GetStatusTrackingSnapshot(module)
    local record = snapshot[frame]
    if type(record) ~= "table" then
        record = { name = name }
        snapshot[frame] = record
    elseif not record.name then
        record.name = name
    end

    if record.alphaCaptured ~= true and record.alphaOwned ~= true then
        local ok, value, detail = ReadFrameAlpha(frame)
        if ok then
            record.alpha = value
            record.alphaCaptured = true
            record.alphaCaptureDetail = nil
        else
            record.alphaCaptureDetail = detail
        end
    end

    if record.mouseCaptured ~= true and record.mouseOwned ~= true then
        local ok, value, detail = ReadFrameMouseEnabled(frame)
        if ok then
            record.mouseEnabled = value
            record.mouseCaptured = true
            record.mouseCaptureDetail = nil
        else
            record.mouseCaptureDetail = detail
        end
    end

    return record
end

local function SuppressStatusTrackingFrame(module, name, frame)
    local record = CaptureStatusTrackingFrame(module, name, frame)
    if not record then
        return false, FrameLabel(name, frame) .. ": snapshot unavailable"
    end

    local failures = {}
    local label = FrameLabel(record.name or name, frame)

    if record.alphaCaptured ~= true then
        failures[#failures + 1] = label .. ".alpha: " .. tostring(record.alphaCaptureDetail or "original value is unreadable")
    else
        local ok, detail = WriteFrameAlpha(frame, STATUS_TRACKING_MANAGED_ALPHA)
        if ok then
            record.alphaOwned = true
        else
            failures[#failures + 1] = label .. ".alpha: " .. tostring(detail)
        end
    end

    if record.mouseCaptured ~= true then
        failures[#failures + 1] = label .. ".mouse: " .. tostring(record.mouseCaptureDetail or "original value is unreadable")
    else
        local ok, detail = WriteFrameMouseEnabled(frame, STATUS_TRACKING_MANAGED_MOUSE)
        if ok then
            record.mouseOwned = true
        else
            failures[#failures + 1] = label .. ".mouse: " .. tostring(detail)
        end
    end

    if #failures > 0 then
        return false, table.concat(failures, "; ")
    end
    return true
end

local function SuppressBlizzardStatusTracking(module)
    local failures = {}
    for i = 1, #STATUS_TRACKING_FRAME_NAMES do
        local name = STATUS_TRACKING_FRAME_NAMES[i]
        local frame = _G[name]
        if type(frame) == "table" then
            local ok, detail = SuppressStatusTrackingFrame(module, name, frame)
            if ok == false then
                failures[#failures + 1] = tostring(detail)
            end
        end
    end

    if #failures > 0 then
        return false, table.concat(failures, "; ")
    end
    return true
end

local function ClearReleasedRecord(snapshot, frame, record)
    if record.alphaOwned ~= true and record.mouseOwned ~= true then
        snapshot[frame] = nil
    end
end

local function RestoreStatusTrackingRecord(frame, record)
    if type(frame) ~= "table" or type(record) ~= "table" then
        return true
    end

    local failures = {}
    local label = FrameLabel(record.name, frame)

    if record.alphaOwned == true then
        local readable, current, detail = ReadFrameAlpha(frame)
        if not readable then
            failures[#failures + 1] = label .. ".alpha restore: " .. tostring(detail)
        elseif SameAlpha(current, STATUS_TRACKING_MANAGED_ALPHA) then
            local restored, restoreDetail = WriteFrameAlpha(frame, record.alpha)
            if restored then
                record.alphaOwned = nil
            else
                failures[#failures + 1] = label .. ".alpha restore: " .. tostring(restoreDetail)
            end
        else
            -- A newer owner changed the value while attached; do not overwrite it.
            record.alphaOwned = nil
        end
    end

    if record.mouseOwned == true then
        local readable, current, detail = ReadFrameMouseEnabled(frame)
        if not readable then
            failures[#failures + 1] = label .. ".mouse restore: " .. tostring(detail)
        elseif current == STATUS_TRACKING_MANAGED_MOUSE then
            local restored, restoreDetail = WriteFrameMouseEnabled(frame, record.mouseEnabled)
            if restored then
                record.mouseOwned = nil
            else
                failures[#failures + 1] = label .. ".mouse restore: " .. tostring(restoreDetail)
            end
        else
            -- A newer owner changed the value while attached; do not overwrite it.
            record.mouseOwned = nil
        end
    end

    if #failures > 0 then
        return false, table.concat(failures, "; ")
    end
    return true
end

local function RestoreBlizzardStatusTracking(module)
    local snapshot = module and module._statusTrackingSnapshot
    if type(snapshot) ~= "table" then return true end

    local failures = {}
    for frame, record in pairs(snapshot) do
        local ok, detail = RestoreStatusTrackingRecord(frame, record)
        if ok == false then
            failures[#failures + 1] = tostring(detail)
        end
        ClearReleasedRecord(snapshot, frame, record)
    end

    if next(snapshot) == nil then
        module._statusTrackingSnapshot = nil
    end
    if #failures > 0 then
        return false, table.concat(failures, "; ")
    end
    return true
end

local function ReportStatusTrackingFailure(module, detail)
    detail = tostring(detail or "unknown native status-tracking failure")
    if module._statusTrackingLastError == detail then
        return
    end
    module._statusTrackingLastError = detail
    if Log and type(Log.Error) == "function" then
        Log:Error("ExperienceBar native status tracking failed: " .. detail)
    end
end

local function ClearStatusTrackingFailure(module)
    module._statusTrackingLastError = nil
end

local MaintainStatusTrackingOwnership

local function EnsureStatusTrackingHooks(module)
    local manager = _G.StatusTrackingBarManager
    if type(manager) ~= "table" then
        return true, "StatusTrackingBarManager pending runtime creation"
    end

    local secureHook = _G.hooksecurefunc or hooksecurefunc
    if type(secureHook) ~= "function" then
        return false, "hooksecurefunc is unavailable"
    end

    if module._statusTrackingHookOwner ~= manager then
        module._statusTrackingHookOwner = manager
        module._statusTrackingHookMethods = {}
    end
    local methods = module._statusTrackingHookMethods

    if type(module._statusTrackingResuppress) ~= "function" then
        module._statusTrackingResuppress = function()
            if module._suppressBlizzardTracking ~= true then return end
            local ok, detail = MaintainStatusTrackingOwnership(module)
            if ok == false then
                ReportStatusTrackingFailure(module, detail)
            else
                ClearStatusTrackingFailure(module)
            end
        end
    end

    local available = 0
    local failures = {}
    for _, methodName in ipairs({ "UpdateBarsShown", "UpdateBarVisuals" }) do
        if type(manager[methodName]) == "function" then
            available = available + 1
            if methods[methodName] ~= true then
                local ok, err = pcall(secureHook, manager, methodName, module._statusTrackingResuppress)
                if ok then
                    methods[methodName] = true
                else
                    failures[#failures + 1] = methodName .. " hook failed: " .. tostring(err)
                end
            end
        end
    end

    if #failures > 0 then
        return false, table.concat(failures, "; ")
    end
    if available == 0 then
        return true, "StatusTrackingBarManager methods pending runtime creation"
    end
    return true
end

MaintainStatusTrackingOwnership = function(module)
    local failures = {}
    local hooked, hookDetail = EnsureStatusTrackingHooks(module)
    if hooked == false then
        failures[#failures + 1] = tostring(hookDetail)
    end

    local suppressed, suppressDetail = SuppressBlizzardStatusTracking(module)
    if suppressed == false then
        failures[#failures + 1] = tostring(suppressDetail)
    end

    if #failures > 0 then
        return false, table.concat(failures, "; ")
    end
    ClearStatusTrackingFailure(module)
    return true
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
    local bar = module._bar
    if not bar then
        bar = CreateFrame("StatusBar", "FGUI_XPBar", UIParent)
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
    end

    local moverEntry = Movers and type(Movers.GetEntry) == "function" and Movers:GetEntry("xpbar") or nil
    if module._moverReadyFrame ~= bar or not moverEntry or moverEntry.frame ~= bar then
        if not (Movers and type(Movers.Register) == "function" and type(Movers.Apply) == "function") then
            return nil, "ExperienceBar mover registry unavailable"
        end
        local registered, registerDetail = Movers:Register("xpbar", bar, CreateMoverSpec())
        if registered == false then
            return nil, "ExperienceBar mover registration failed: " .. tostring(registerDetail)
        end
        local applied, applyDetail = Movers:Apply("xpbar", bar)
        if applied == false then
            return nil, "ExperienceBar mover apply failed: " .. tostring(applyDetail)
        end
        module._moverReadyFrame = bar
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
    local bar, frameDetail = EnsureFrame(self)
    if not bar then return false, frameDetail end

    if not cfg.enabled then
        SetBarVisible(bar, false, false)
        return true
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
        return true
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
    return true
end

local EXPERIENCE_EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "PLAYER_XP_UPDATE",
    "PLAYER_MAX_LEVEL_UPDATE",
    "PLAYER_LEVEL_CHANGED",
    "PLAYER_LEVEL_UP",
    "UPDATE_EXHAUSTION",
    "UPDATE_FACTION",
    "HONOR_XP_UPDATE",
    "ENABLE_XP_GAIN",
    "DISABLE_XP_GAIN",
}

local function EventFrameCall(frame, method, ...)
    local fn = frame and frame[method] or nil
    if type(fn) ~= "function" then
        return false, tostring(method) .. " is unavailable"
    end

    local ok, result = pcall(fn, frame, ...)
    if not ok then
        return false, tostring(method) .. " failed: " .. tostring(result)
    end
    if result == false then
        return false, tostring(method) .. " rejected the request"
    end
    return true
end

local function ReportExperienceEventFailure(module, event, detail)
    local message = tostring(event or "event") .. ": " .. tostring(detail or "unknown failure")
    if module._eventLastError == message then return end
    module._eventLastError = message
    if Log and type(Log.Error) == "function" then
        Log:Error("ExperienceBar event refresh failed: " .. message)
    end
end

local function ClearExperienceEventFailure(module)
    module._eventLastError = nil
end

local function RunExperienceUpdate(module)
    if type(module.Update) ~= "function" then
        return false, "ExperienceBar update owner unavailable"
    end

    local ok, result, detail = pcall(module.Update, module)
    if not ok then
        return false, "ExperienceBar update failed: " .. tostring(result)
    end
    if result == false then
        return false, tostring(detail or "ExperienceBar update failed")
    end
    return true
end

local function EnsureEventFrame(module)
    local existing = module._eventRecord
    if type(existing) == "table" and existing.frame then
        module._events = existing.frame
        return existing.frame, existing
    end

    local created, ev = pcall(CreateFrame, "Frame")
    if not created or not ev then
        return nil, nil, "ExperienceBar event-frame creation failed: " .. tostring(ev)
    end

    local record = {
        frame = ev,
        active = false,
        registered = false,
        cleanupPending = false,
    }

    local callback = function(_, event, ...)
        if module._eventRecord ~= record or record.active ~= true then
            return
        end

        local unit = ...
        if (event == "PLAYER_XP_UPDATE"
            or event == "HONOR_XP_UPDATE"
            or event == "PLAYER_MAX_LEVEL_UPDATE")
            and unit and unit ~= "player" then
            return
        end

        if module._suppressBlizzardTracking == true then
            local maintained, maintainDetail = MaintainStatusTrackingOwnership(module)
            if maintained == false then
                ReportStatusTrackingFailure(module, maintainDetail)
            else
                ClearStatusTrackingFailure(module)
            end
        end

        local updated, updateDetail = RunExperienceUpdate(module)
        if updated == false then
            ReportExperienceEventFailure(module, event, updateDetail)
        else
            ClearExperienceEventFailure(module)
        end
    end

    local scripted, scriptDetail = EventFrameCall(ev, "SetScript", "OnEvent", callback)
    if scripted == false then
        return nil, nil, "ExperienceBar event callback setup failed: " .. tostring(scriptDetail)
    end

    record.callback = callback
    module._eventRecord = record
    module._events = ev
    return ev, record
end

local function CleanupEventSubscriptions(record)
    if type(record) ~= "table" then return true end

    record.active = false
    if record.registered ~= true and record.cleanupPending ~= true then
        return true
    end

    local cleaned, detail = EventFrameCall(record.frame, "UnregisterAllEvents")
    if cleaned == false then
        record.cleanupPending = true
        return false, detail
    end

    record.registered = false
    record.cleanupPending = false
    return true
end

local function PrepareEventSubscriptions(module, record)
    if type(record) ~= "table" or module._eventRecord ~= record then
        return false, "ExperienceBar event record unavailable"
    end

    if record.active == true and record.registered == true and record.cleanupPending ~= true then
        return true, nil, false
    end

    if record.registered == true or record.cleanupPending == true then
        local cleaned, cleanupDetail = CleanupEventSubscriptions(record)
        if cleaned == false then
            return false, "previous event cleanup failed: " .. tostring(cleanupDetail)
        end
    end

    record.active = false
    for i = 1, #EXPERIENCE_EVENTS do
        local event = EXPERIENCE_EVENTS[i]
        local registered, detail = EventFrameCall(record.frame, "RegisterEvent", event)
        if registered == false then
            -- A native registration may have partially succeeded before raising
            -- or returning false. Treat the frame as dirty until a complete
            -- UnregisterAllEvents succeeds.
            record.registered = true
            record.cleanupPending = true
            local cleaned, cleanupDetail = CleanupEventSubscriptions(record)
            local failure = tostring(event) .. ": " .. tostring(detail)
            if cleaned == false then
                failure = failure .. "; cleanup: " .. tostring(cleanupDetail)
            end
            return false, failure
        end
    end

    record.registered = true
    record.cleanupPending = false
    return true, nil, true
end

local function ActivateEventSubscriptions(module, record)
    if type(record) ~= "table"
        or module._eventRecord ~= record
        or record.registered ~= true
        or record.cleanupPending == true then
        return false, "ExperienceBar event subscriptions are not ready"
    end
    record.active = true
    return true
end

local function ReleaseEventSubscriptions(module)
    local record = module and module._eventRecord or nil
    if type(record) ~= "table" then return true end
    record.active = false
    return CleanupEventSubscriptions(record)
end

local function JoinFailures(failures)
    if #failures == 0 then return nil end
    return table.concat(failures, "; ")
end

function XP:ApplyConfig()
    local initialized, initDetail = self:Init()
    if initialized == false then return false, initDetail end

    local cfg = GetCfg()
    local bar = self._bar
    local ev = self._events
    local record = self._eventRecord
    if not (bar and ev and record) then
        return false, "ExperienceBar runtime owners unavailable"
    end

    if not cfg.enabled then
        local failures = {}
        local released, releaseDetail = ReleaseEventSubscriptions(self)
        if released == false then
            failures[#failures + 1] = "events: " .. tostring(releaseDetail)
        end

        self._suppressBlizzardTracking = nil
        local restored, restoreDetail = RestoreBlizzardStatusTracking(self)
        if restored == false then
            failures[#failures + 1] = "native restore: " .. tostring(restoreDetail)
        end

        SetBarVisible(bar, false, true)
        local detail = JoinFailures(failures)
        if detail then return false, detail end
        ClearStatusTrackingFailure(self)
        ClearExperienceEventFailure(self)
        return true
    end

    local wasActive = record.active == true
        and record.registered == true
        and record.cleanupPending ~= true

    local prepared, prepareDetail = PrepareEventSubscriptions(self, record)
    if prepared == false then
        return false, "ExperienceBar event subscription failed: " .. tostring(prepareDetail)
    end

    self._suppressBlizzardTracking = true
    local maintained, maintainDetail = MaintainStatusTrackingOwnership(self)
    local updated, updateDetail = true, nil
    if maintained then
        updated, updateDetail = RunExperienceUpdate(self)
    end

    if maintained and updated then
        local activated, activateDetail = ActivateEventSubscriptions(self, record)
        if activated == false then
            maintained = false
            maintainDetail = activateDetail
        else
            ClearStatusTrackingFailure(self)
            ClearExperienceEventFailure(self)
            return true
        end
    end

    local failures = {}
    if maintained == false then
        failures[#failures + 1] = "native ownership: " .. tostring(maintainDetail)
    end
    if updated == false then
        failures[#failures + 1] = "update: " .. tostring(updateDetail)
    end

    if not wasActive then
        record.active = false
        local released, releaseDetail = CleanupEventSubscriptions(record)
        if released == false then
            failures[#failures + 1] = "event rollback: " .. tostring(releaseDetail)
        end

        self._suppressBlizzardTracking = nil
        local restored, restoreDetail = RestoreBlizzardStatusTracking(self)
        if restored == false then
            failures[#failures + 1] = "native rollback: " .. tostring(restoreDetail)
        end
        SetBarVisible(bar, false, true)
    else
        -- A reapply failure must not tear down the previously committed event
        -- owner. The settings/apply journal can restore the prior geometry while
        -- this exact event generation remains active.
        record.active = true
    end

    return false, JoinFailures(failures) or "ExperienceBar apply failed"
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

    local failures = {}
    local released, releaseDetail = ReleaseEventSubscriptions(self)
    if released == false then
        failures[#failures + 1] = "events: " .. tostring(releaseDetail)
    end

    self._suppressBlizzardTracking = nil
    local restored, restoreDetail = RestoreBlizzardStatusTracking(self)
    if restored == false then
        failures[#failures + 1] = "native restore: " .. tostring(restoreDetail)
    end

    if self._bar then
        SetBarVisible(self._bar, false, true)
    end

    local detail = JoinFailures(failures)
    if detail then return false, detail end
    ClearStatusTrackingFailure(self)
    ClearExperienceEventFailure(self)
    return true
end

function XP:Init()
    if self._inited then return true end

    local bar, frameDetail = EnsureFrame(self)
    if not bar then return false, frameDetail end

    local events, _, eventDetail = EnsureEventFrame(self)
    if not events then return false, eventDetail or "ExperienceBar event owner unavailable" end

    self._inited = true
    if Log and Log.Debug then
        Log:Debug("ExperienceBar loaded")
    end
    return true
end

return XP
