-- FeelsGoodUI: UnitFrames render, auras, castbar and style helpers

local _, ns = ...

local Render = {}
ns.UnitFramesRender = Render

local DB = ns.DB
local Media = ns.Media
local Secret = ns.Secret
local Target = ns.UnitFramesTarget
local Text = ns.UnitFramesText
local U = ns.U

local EMPTY = {}

local combatStartTime = nil
local combatTicker = nil

Render._ctx = Render._ctx or EMPTY

local ConfigureTargetHelper

function Render:Configure(context)
    if type(context) == "table" then
        self._ctx = context
    else
        self._ctx = EMPTY
    end

    if type(ConfigureTargetHelper) == "function" then
        ConfigureTargetHelper()
    end
end

local function Ctx()
    return Render._ctx or EMPTY
end

local function Call(name, ...)
    local fn = Ctx()[name]
    if type(fn) == "function" then
        return fn(...)
    end
    return nil
end

local function GetCache()
    local cache = Ctx().Cache
    if type(cache) == "table" then
        return cache
    end
    return EMPTY
end

local function EnsureCache()
    local fn = Ctx().EnsureCache
    if type(fn) == "function" then
        fn()
    end
end

local function GetUnitFramesCfg()
    local value = Call("GetUnitFramesCfg")
    if type(value) == "table" then
        return value
    end
    return EMPTY
end

local function GetStyleCfg()
    local value = Call("GetStyleCfg")
    if type(value) == "table" then
        return value
    end
    return EMPTY
end

local function GetSharedFontToken()
    return Call("GetSharedFontToken") or "Fonts\\FRIZQT__.TTF"
end

local function GetSharedStatusbarToken()
    return Call("GetSharedStatusbarToken") or "Interface/Buttons/WHITE8x8"
end

local function IsSecretValue(v)
    if Text and Text.IsSecretValue then
        return Text.IsSecretValue(v)
    end
    return false
end

local function SafeSetText(fs, v)
    if Text and Text.SafeSetText then
        Text.SafeSetText(fs, v)
        return
    end

    if fs then
        fs:SetText(v or "")
    end
end

local function FormatNumberShort(v)
    EnsureCache()
    if Text and Text.FormatNumberShort then
        return Text.FormatNumberShort(GetCache(), v)
    end
    return ""
end

local function TryBlizzardAbbrev(v)
    if Text and Text.TryBlizzardAbbrev then
        return Text.TryBlizzardAbbrev(v)
    end
    return false, nil
end

local function FormatNumberFull(v)
    if Text and Text.FormatNumberFull then
        return Text.FormatNumberFull(v)
    end
    return nil
end

local function ShouldShortenUnit(unit)
    EnsureCache()
    if Text and Text.ShouldShortenUnit then
        return Text.ShouldShortenUnit(GetCache(), unit)
    end
    return false
end

local function IsTargetLikeUnit(unit)
    return unit == "target" or unit == "focus" or unit == "targettarget"
end

local function FormatSecondsMMSS(sec)
    if type(sec) ~= "number" or sec < 0 then
        sec = 0
    end

    local m = math.floor(sec / 60)
    local s = math.floor(sec - (m * 60))
    return string.format("%02d:%02d", m, s)
end

local function SetStatusBarColorSafe(bar, r, g, b, a)
    if not bar then return end
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return end
    bar:SetStatusBarColor(r, g, b, a or 1)
end

local function ResolveRGBA(tbl, fallbackR, fallbackG, fallbackB, fallbackA)
    if type(tbl) == "table" then
        local r = tonumber(tbl.r)
        local g = tonumber(tbl.g)
        local b = tonumber(tbl.b)
        local a = tonumber(tbl.a)
        if r and g and b then
            return r, g, b, a or fallbackA or 1
        end
    end
    return fallbackR, fallbackG, fallbackB, fallbackA or 1
end

Render.ResolveRGBA = ResolveRGBA
Render.SetStatusBarColorSafe = SetStatusBarColorSafe

function Render.UpdateUnitHealthColor(frame, unit)
    if Target and Target.UpdateUnitHealthColor then
        Target.UpdateUnitHealthColor(frame, unit)
    end
end

function Render.UpdateTargetHealthColor(frame)
    if Target and Target.UpdateTargetHealthColor then
        Target.UpdateTargetHealthColor(frame)
    end
end

function Render.StopCombatTimer(frame)
    if combatTicker then
        combatTicker:Cancel()
        combatTicker = nil
    end

    combatStartTime = nil

    if frame and frame.CombatTime then
        frame.CombatTime:SetText("00:00")
        frame.CombatTime:Hide()
    end
end

function Render.StartCombatTimer(frame)
    Render.StopCombatTimer(frame)
    combatStartTime = GetTime()

    if frame and frame.CombatTime then
        frame.CombatTime:Show()
    end

    EnsureCache()
    local hz = GetCache().combatHz or 5
    if type(hz) ~= "number" or hz <= 0 then
        hz = 5
    end

    local interval = 1 / hz
    combatTicker = C_Timer.NewTicker(interval, function()
        if not combatStartTime then
            return
        end

        local dt = GetTime() - combatStartTime
        if frame and frame.CombatTime then
            frame.CombatTime:SetText(FormatSecondsMMSS(dt))
        end
    end)
end

local function GetScaleTo100Curve()
    return (_G.CurveConstants and _G.CurveConstants.ScaleTo100) or nil
end

local function SafeUnitHealthPercent(unit)
    if not (unit and _G.UnitHealthPercent) then
        return nil
    end

    local ok, value = pcall(_G.UnitHealthPercent, unit, true, GetScaleTo100Curve())
    if ok then
        return value
    end

    return nil
end

local function HideLowHPGlow(frame)
    if not frame or not frame.LowHPGlow then
        return
    end

    if frame._fguiLowHPVisible == true then
        frame.LowHPGlow:Hide()
        frame._fguiLowHPVisible = false
    end
end

local function UpdatePlayerLowHPGlow(frame, unit, value, maxv)
    if not frame or unit ~= "player" or not frame.LowHPGlow then
        return
    end

    EnsureCache()
    local cache = GetCache()
    if cache.lowHPEnabled ~= true then
        HideLowHPGlow(frame)
        return
    end

    local percent = nil
    local direct = SafeUnitHealthPercent(unit)
    local okDirect, directNumber = U.TryNumber(direct)
    if okDirect then
        percent = directNumber
    else
        local okCur, curNumber = U.TryNumber(value)
        local okMax, maxNumber = U.TryNumber(maxv)
        if okCur and okMax and maxNumber and maxNumber > 0 then
            percent = (curNumber / maxNumber) * 100
        end
    end

    if type(percent) ~= "number" then
        HideLowHPGlow(frame)
        return
    end

    local threshold = cache.lowHPThreshold or 30
    if percent > threshold then
        HideLowHPGlow(frame)
        return
    end

    local ratio = 1 - (percent / threshold)
    if ratio < 0 then ratio = 0 end
    if ratio > 1 then ratio = 1 end

    local color = cache.lowHPColor or EMPTY
    local baseA = tonumber(color.a) or 1
    local maxAlpha = cache.lowHPMaxAlpha or 0.65
    local alpha = maxAlpha * (0.25 + (0.75 * ratio)) * baseA

    local r = color.r or 1.00
    local g = color.g or 0.12
    local b = color.b or 0.12
    local updateColor = (frame._fguiLowHPR ~= r)
        or (frame._fguiLowHPG ~= g)
        or (frame._fguiLowHPB ~= b)
        or (frame._fguiLowHPAlpha == nil)
        or (math.abs((frame._fguiLowHPAlpha or 0) - alpha) > 0.01)

    if updateColor then
        frame.LowHPGlow:SetColorTexture(r, g, b, alpha)
        frame._fguiLowHPR = r
        frame._fguiLowHPG = g
        frame._fguiLowHPB = b
        frame._fguiLowHPAlpha = alpha
    end

    if frame._fguiLowHPVisible ~= true then
        frame.LowHPGlow:Show()
        frame._fguiLowHPVisible = true
    end
end

local function ParseLooseNumber(v)
    if v == nil then
        return nil
    end

    if Secret and Secret.IsSecret and Secret.IsSecret(v) then
        return nil
    end

    local okNumber, number = U.TryNumber(v)
    if okNumber then
        return number
    end

    if type(v) ~= "string" then
        local okString, text = pcall(tostring, v)
        if not okString or type(text) ~= "string" then
            return nil
        end
        v = text
    end

    local okClean, clean = pcall(string.gsub, v, ",", ".")
    if not okClean or type(clean) ~= "string" then
        return nil
    end

    local parsed = tonumber(clean)
    if type(parsed) == "number" then
        return parsed
    end

    local okMatch, match = pcall(string.match, clean, "[-+]?%d+%.?%d*")
    if not okMatch then
        return nil
    end

    if type(match) == "string" then
        return tonumber(match)
    end

    return nil
end

local function FormatPercentText(v)
    local number = ParseLooseNumber(v)
    if type(number) ~= "number" then
        return ""
    end

    if number < 0 then number = 0 end
    if number > 100 then number = 100 end
    return tostring(U.Round(number)) .. "%"
end

local function PostUpdateHealth(health, unit, cur, minOrMax, maybeMax)
    local frame = health and health.__owner
    if not frame or not unit then
        return
    end

    local value = cur
    local maxv = maybeMax
    if (not IsSecretValue(maxv)) and (not maxv) then
        maxv = minOrMax
    end

    local shorten = ShouldShortenUnit(unit)
    if frame.HealthValueText then
        local okValue = U.TryNumber(value)
        if okValue then
            if shorten then
                SafeSetText(frame.HealthValueText, FormatNumberShort(value))
            else
                SafeSetText(frame.HealthValueText, FormatNumberFull(value) or "")
            end
        else
            local looseShort = nil
            if shorten then
                local looseNumber = ParseLooseNumber(value)
                if type(looseNumber) == "number" then
                    looseShort = FormatNumberShort(looseNumber)
                end
            end

            if type(looseShort) == "string" and looseShort ~= "" then
                SafeSetText(frame.HealthValueText, looseShort)
            elseif shorten and IsSecretValue(value) then
                local hasAbbrev, abbrev = TryBlizzardAbbrev(value)
                if hasAbbrev then
                    SafeSetText(frame.HealthValueText, abbrev)
                else
                    SafeSetText(frame.HealthValueText, value)
                end
            else
                SafeSetText(frame.HealthValueText, value)
            end
        end
    end

    if frame.HealthPercentText then
        local direct = SafeUnitHealthPercent(unit)
        local okDirect, directNumber = U.TryNumber(direct)
        if okDirect then
            local percentText = FormatPercentText(directNumber)
            if percentText ~= "" then
                SafeSetText(frame.HealthPercentText, percentText)
            else
                local rendered = false
                if Secret and Secret.SafeSetFormattedText then
                    Secret.SafeSetFormattedText(frame.HealthPercentText, "%s%%", directNumber)
                    local text = frame.HealthPercentText:GetText()
                    rendered = (type(text) == "string" and text ~= "")
                end
                if not rendered then
                    SafeSetText(frame.HealthPercentText, directNumber)
                end
            end
        elseif IsSecretValue(direct) then
            local rendered = false
            if Secret and Secret.SafeSetFormattedText then
                Secret.SafeSetFormattedText(frame.HealthPercentText, "%s%%", direct)
                local text = frame.HealthPercentText:GetText()
                rendered = (type(text) == "string" and text ~= "")
            end
            if not rendered then
                SafeSetText(frame.HealthPercentText, direct)
            end
        else
            local okCur, curNumber = U.TryNumber(value)
            local okMax, maxNumber = U.TryNumber(maxv)
            if okCur and okMax and maxNumber and maxNumber > 0 then
                local pct = (curNumber / maxNumber) * 100
                SafeSetText(frame.HealthPercentText, FormatPercentText(pct))
            else
                SafeSetText(frame.HealthPercentText, "")
            end
        end
    end

    if frame.NameText then
        local okName, name = pcall(_G.UnitName, unit)
        if okName then
            SafeSetText(frame.NameText, name)
        end
    end

    if unit == "player" then
        UpdatePlayerLowHPGlow(frame, unit, value, maxv)
    else
        Render.UpdateUnitHealthColor(frame, unit)
    end
end

function Render.ForceUpdateHealthText(frame, unit)
    if not (frame and frame.Health and unit) then
        return
    end

    local okExists, exists = pcall(_G.UnitExists, unit)
    if not okExists or not exists then
        return
    end

    local okCur, cur = pcall(_G.UnitHealth, unit)
    local okMax, maxv = pcall(_G.UnitHealthMax, unit)
    if not okCur then cur = nil end
    if not okMax then maxv = nil end

    pcall(PostUpdateHealth, frame.Health, unit, cur, maxv)
end

local function Aura_PostCreateIcon(icons, button)
    if not button then
        return
    end

    EnsureCache()
    local cache = GetCache()

    if button.icon then
        Media:ApplyIconCrop(button.icon, cache.iconInset or 0.08)
    end

    if button.cd then
        button.cd:SetAllPoints(button)
    end

    if button.count then
        button.count:ClearAllPoints()
        button.count:SetPoint("BOTTOMRIGHT", -1, 1)
        local font = cache.auraFont or "Fonts\\FRIZQT__.TTF"
        Media:ApplyFont(button.count, font, 11, "OUTLINE")
    end

    Media:CreateBorder(button, cache.borderSize or 1)
end

local function Aura_PostUpdateIcon(icons, unit, button)
    if not button then
        return
    end

    EnsureCache()
    if button.icon then
        Media:ApplyIconCrop(button.icon, GetCache().iconInset or 0.08)
    end
end

local function Aura_IsFromPlayerOrPet(sourceUnit, auraData, ...)
    if sourceUnit == "player" or sourceUnit == "pet" or sourceUnit == "vehicle" then
        return true
    end

    if type(auraData) == "table" then
        if auraData.isFromPlayerOrPlayerPet == true then return true end
        if auraData.isCastByPlayer == true then return true end
        if auraData.sourceUnit == "player" or auraData.sourceUnit == "pet" then return true end
        if auraData.unitCaster == "player" or auraData.unitCaster == "pet" then return true end
        return false
    end

    return nil
end

local function Aura_ExtractSourceUnit(...)
    local first = ...
    if type(first) == "table" then
        return first.sourceUnit or first.unitCaster or first.caster or first.source, first
    end

    for i = 7, 12 do
        local value = select(i, ...)
        if type(value) == "string" then
            return value, nil
        end
    end

    return nil, nil
end

ConfigureTargetHelper = function()
    if not (Target and Target.Configure) then
        return
    end

    Target:Configure({
        AuraExtractSourceUnit = Aura_ExtractSourceUnit,
        AuraIsFromPlayerOrPet = Aura_IsFromPlayerOrPet,
        Cache = GetCache(),
        EnsureCache = EnsureCache,
        GetSharedFontToken = GetSharedFontToken,
        GetUnitFramesCfg = GetUnitFramesCfg,
        IsSecretValue = IsSecretValue,
        IsTargetLikeUnit = IsTargetLikeUnit,
        ResolveRGBA = ResolveRGBA,
        SafeSetText = SafeSetText,
        SetStatusBarColorSafe = SetStatusBarColorSafe,
    })
end

local function NormalizeAuraSpacing(spacing)
    local value = math.floor((tonumber(spacing) or 0) + 0.5)
    if value < 0 then value = 0 end
    if value > 12 then value = 12 end
    if value <= 1 then
        return 0
    end
    return value
end

local function CreateAuraContainer(frame, size, spacing, max, growthY, filter)
    local auras = CreateFrame("Frame", nil, frame)
    size = math.max(8, math.min(64, tonumber(size) or 20))
    spacing = NormalizeAuraSpacing(spacing)
    max = math.max(1, math.min(40, tonumber(max) or 8))
    auras.size = size
    auras.spacing = spacing
    auras.num = max

    if type(filter) == "string" then
        auras.filter = filter
    end

    auras.initialAnchor = "LEFT"
    auras["growth-x"] = "RIGHT"
    auras["growth-y"] = growthY or "UP"

    auras:SetSize((size * max) + (spacing * (max - 1)), size)
    auras.PostCreateIcon = Aura_PostCreateIcon
    auras.PostUpdateIcon = Aura_PostUpdateIcon

    return auras
end

function Render.ApplyTargetAuraModeToFrame(frame)
    if Target and Target.ApplyTargetAuraModeToFrame then
        Target.ApplyTargetAuraModeToFrame(frame)
    end
end

local function CreateHealthBar(frame)
    local style = GetStyleCfg()
    local unitframesCfg = GetUnitFramesCfg()
    local defaults = (DB.defaults and DB.defaults.profile and DB.defaults.profile.unitframes) or {}
    Call("NormalizeUFSizeTables", unitframesCfg, defaults)
    Call("NormalizeUFScaleTables", unitframesCfg, defaults)

    local width, height = Call("GetUnitFrameSize", unitframesCfg, defaults, frame.unit)
    frame:SetSize(width, height)

    local health = CreateFrame("StatusBar", nil, frame)
    health:SetAllPoints(frame)
    health:SetStatusBarTexture(Media:FetchStatusbar(GetSharedStatusbarToken()))

    health.bg = health:CreateTexture(nil, "BACKGROUND")
    health.bg:SetAllPoints()
    health.bg:SetColorTexture(0.08, 0.08, 0.08, 1)

    local colors = unitframesCfg.colors or EMPTY
    if frame.unit == "player" then
        local pr, pg, pb, pa = ResolveRGBA(colors.playerHealth, 0.65, 0.00, 0.00, 1)
        SetStatusBarColorSafe(health, pr, pg, pb, pa)
    else
        local tr, tg, tb, ta = ResolveRGBA(colors.targetFallback, 0.12, 0.12, 0.12, 1)
        SetStatusBarColorSafe(health, tr, tg, tb, ta)
    end

    health.PostUpdate = PostUpdateHealth
    frame.Health = health
    Media:CreateBorder(frame, style.borderSize or 1)

    if frame.unit == "player" then
        local glow = frame:CreateTexture(nil, "ARTWORK", nil, 7)
        glow:SetAllPoints(frame)
        glow:SetBlendMode("ADD")
        glow:SetColorTexture(1.00, 0.12, 0.12, 0)
        glow:Hide()
        frame.LowHPGlow = glow
    end

    local valueText = health:CreateFontString(nil, "OVERLAY")
    valueText:SetPoint("RIGHT", frame.Health, "RIGHT", -6, 0)
    local textCfg = unitframesCfg.text or EMPTY
    local font = textCfg.font or GetSharedFontToken()
    Media:ApplyFont(valueText, font, textCfg.size or 12, textCfg.outline or "OUTLINE")
    valueText:SetJustifyH("RIGHT")
    valueText:SetWordWrap(false)
    valueText:SetTextColor(1, 1, 1, 1)
    frame.HealthValueText = valueText

    local percentText = health:CreateFontString(nil, "OVERLAY")
    percentText:SetPoint("CENTER", frame.Health, "CENTER", 0, 0)
    Media:ApplyFont(percentText, font, textCfg.size or 12, textCfg.outline or "OUTLINE")
    percentText:SetJustifyH("CENTER")
    percentText:SetWordWrap(false)
    percentText:SetTextColor(1, 1, 1, 1)
    percentText:SetWidth(math.max(34, math.floor(width * 0.30)))
    valueText:SetWidth(math.max(32, math.floor(width * 0.48)))
    valueText:SetPoint("LEFT", percentText, "RIGHT", 6, 0)
    frame.HealthPercentText = percentText

    return health
end

local function PostUpdatePower(power, unit, cur, minOrMax, maybeMax)
    local frame = power and power.__owner
    if not frame or not unit then
        return
    end

    local powerType, powerToken = UnitPowerType(unit)
    if powerToken and (not IsSecretValue(powerToken)) and _G.PowerBarColor and _G.PowerBarColor[powerToken] then
        local color = _G.PowerBarColor[powerToken]
        if color and type(color.r) == "number" then
            SetStatusBarColorSafe(power, color.r, color.g, color.b, 1)
        end
    end
end

local function CreatePowerBar(frame)
    local style = GetStyleCfg()
    local statusbar = Media:FetchStatusbar(GetSharedStatusbarToken())

    local power = CreateFrame("StatusBar", nil, frame)
    power:SetStatusBarTexture(statusbar)

    power.bg = power:CreateTexture(nil, "BACKGROUND")
    power.bg:SetAllPoints()
    power.bg:SetColorTexture(0.07, 0.07, 0.07, 1)

    Media:CreateBorder(power, style.borderSize or 1)
    power.PostUpdate = PostUpdatePower
    frame.Power = power
    power:Hide()
end

local function CreateCastbar(frame)
    local style = GetStyleCfg()
    local unitframesCfg = GetUnitFramesCfg()
    local castbarCfg = unitframesCfg.castbar or EMPTY

    local castbar = CreateFrame("StatusBar", nil, frame)
    castbar:SetStatusBarTexture(Media:FetchStatusbar(GetSharedStatusbarToken()))
    castbar:SetMinMaxValues(0, 1)
    castbar:SetValue(0)

    castbar.bg = castbar:CreateTexture(nil, "BACKGROUND")
    castbar.bg:SetAllPoints()
    castbar.bg:SetColorTexture(0.07, 0.07, 0.07, 1)

    Media:CreateBorder(castbar, style.borderSize or 1)

    castbar.Icon = castbar:CreateTexture(nil, "ARTWORK")
    castbar.Icon:SetSize(castbarCfg.height or 14, castbarCfg.height or 14)
    castbar.Icon:SetPoint("RIGHT", castbar, "LEFT", -4, 0)
    Media:ApplyIconCrop(castbar.Icon, style.iconInset or 0.08)

    castbar.Text = castbar:CreateFontString(nil, "OVERLAY")
    castbar.Text:SetPoint("LEFT", castbar, "LEFT", 6, 0)
    castbar.Text:SetJustifyH("LEFT")

    castbar.Time = castbar:CreateFontString(nil, "OVERLAY")
    castbar.Time:SetPoint("RIGHT", castbar, "RIGHT", -6, 0)
    castbar.Time:SetJustifyH("RIGHT")

    local textCfg = unitframesCfg.text or EMPTY
    local font = textCfg.font or GetSharedFontToken()
    Media:ApplyFont(castbar.Text, font, textCfg.size or 12, textCfg.outline or "OUTLINE")
    Media:ApplyFont(castbar.Time, font, textCfg.size or 12, textCfg.outline or "OUTLINE")

    castbar.PostCastStart = function(activeCastbar, unit)
        SetStatusBarColorSafe(activeCastbar, 0.9, 0.7, 0.1, 1)
    end
    castbar.PostChannelStart = castbar.PostCastStart

    castbar.PostCastNotInterruptible = function(activeCastbar)
        SetStatusBarColorSafe(activeCastbar, 0.65, 0.65, 0.65, 1)
    end
    castbar.PostCastInterruptible = function(activeCastbar)
        SetStatusBarColorSafe(activeCastbar, 0.9, 0.7, 0.1, 1)
    end

    frame.Castbar = castbar
    castbar:Hide()
end

function Render.LayoutUnderFrame(frame)
    if not frame then
        return
    end

    local unitframesCfg = GetUnitFramesCfg()
    local castbarCfg = unitframesCfg.castbar or EMPTY
    local targetInfoCfg = unitframesCfg.targetInfo or EMPTY
    local gap = 4

    local anchor = frame
    if frame.Power then
        frame.Power:ClearAllPoints()
        frame.Power:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
        frame.Power:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -gap)
        frame.Power:SetHeight(targetInfoCfg.powerHeight or 10)

        local want = (frame.unit == "target") and (targetInfoCfg.enabled == true) and (targetInfoCfg.showPower ~= false)
        if want then
            frame.Power:Show()
            anchor = frame.Power
        else
            frame.Power:Hide()
        end
    end

    if frame.Castbar then
        frame.Castbar:ClearAllPoints()
        frame.Castbar:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
        frame.Castbar:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -gap)
        frame.Castbar:SetHeight(castbarCfg.height or 14)

        if frame.Castbar.Icon then
            frame.Castbar.Icon:SetSize(castbarCfg.height or 14, castbarCfg.height or 14)
            if castbarCfg.showIcon then
                frame.Castbar.Icon:Show()
            else
                frame.Castbar.Icon:Hide()
            end
        end

        if frame.Castbar.Text then
            if castbarCfg.showText ~= false then
                frame.Castbar.Text:Show()
            else
                frame.Castbar.Text:Hide()
            end
        end

        if frame.Castbar.Time then
            if castbarCfg.showTime ~= false then
                frame.Castbar.Time:Show()
            else
                frame.Castbar.Time:Hide()
            end
        end

        if castbarCfg.enabled == false then
            frame.Castbar:Hide()
        else
            frame.Castbar:Show()
            anchor = frame.Castbar
        end
    end

    if frame.CombatTime then
        frame.CombatTime:ClearAllPoints()
        frame.CombatTime:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
    end
end

function Render.Style(frame, unit)
    frame.menu = function() end
    frame:RegisterForClicks("AnyUp")

    CreateHealthBar(frame)

    if unit == "pet" then
        local cache = GetCache()
        local font = cache.font or "Fonts\\FRIZQT__.TTF"
        local label = frame.Health:CreateFontString(nil, "OVERLAY")
        label:SetPoint("LEFT", frame.Health, "LEFT", 6, 0)
        label:SetJustifyH("LEFT")
        Media:ApplyFont(label, font, 11, "OUTLINE")
        label:SetTextColor(1, 1, 1, 1)
        frame.NameText = label
    end

    local unitframesCfg = GetUnitFramesCfg()
    if unit == "player" then
        local buffs = CreateAuraContainer(frame, unitframesCfg.auraIconSize or 20, unitframesCfg.auraSpacing or 0, unitframesCfg.auraMax or 8, nil, "HELPFUL")
        buffs:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 6)
        frame.Buffs = buffs

        CreateCastbar(frame)

        local timer = frame:CreateFontString(nil, "OVERLAY")
        local font = (unitframesCfg.text and unitframesCfg.text.font) or GetSharedFontToken()
        Media:ApplyFont(timer, font, (unitframesCfg.text and unitframesCfg.text.size) or 12, (unitframesCfg.text and unitframesCfg.text.outline) or "OUTLINE")
        timer:SetJustifyH("LEFT")
        timer:SetTextColor(1, 1, 1, 1)
        timer:SetText("00:00")
        timer:Hide()
        frame.CombatTime = timer
    end

    if IsTargetLikeUnit(unit) then
        if unit == "target" and Target and Target.CreateTargetHeader then
            Target.CreateTargetHeader(frame)
        end

        CreatePowerBar(frame)

        local buffs = CreateAuraContainer(frame, unitframesCfg.auraIconSize or 20, unitframesCfg.auraSpacing or 0, unitframesCfg.auraMax or 8, nil, "HELPFUL")
        local debuffs = CreateAuraContainer(frame, unitframesCfg.auraIconSize or 20, unitframesCfg.auraSpacing or 0, unitframesCfg.auraMax or 8, nil, "HARMFUL")
        frame.Buffs = buffs
        frame.Debuffs = debuffs

        CreateCastbar(frame)
        Render.ApplyTargetAuraModeToFrame(frame)
        Render.UpdateUnitHealthColor(frame, unit)
    end

    Render.LayoutUnderFrame(frame)
end

return Render
