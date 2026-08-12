-- FeelsGoodUI: CenterBars render, threshold, and resource update helpers

local _, ns = ...

local Render = {}
ns.CenterBarsRender = Render

local Media = ns.Media
local Secret = ns.Secret
local U = ns.U

local EMPTY = {}

Render._ctx = Render._ctx or EMPTY

function Render:Configure(context)
    if type(context) == "table" then
        self._ctx = context
    else
        self._ctx = EMPTY
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

local function GetCenterCfg()
    local value = Call("GetCenterCfg")
    if type(value) == "table" then
        return value
    end
    return {}
end

local function GetFormatCfg()
    local value = Call("GetFormatCfg")
    if type(value) == "table" then
        return value
    end
    return {}
end

local function GetStyleCfg()
    local value = Call("GetStyleCfg")
    if type(value) == "table" then
        return value
    end
    return {}
end

local function GetCenterTextCfg()
    local value = Call("GetCenterTextCfg")
    if type(value) == "table" then
        return value
    end
    return {}
end

local function GetSharedFontToken()
    return Call("GetSharedFontToken") or "Fonts\\FRIZQT__.TTF"
end

local function GetSharedFontOutline()
    return Call("GetSharedFontOutline") or "OUTLINE"
end

local function GetSharedFontSize()
    local value = tonumber(Call("GetSharedFontSize"))
    if type(value) == "number" then
        return value
    end
    return 12
end

local function GetSharedStatusbarToken()
    return Call("GetSharedStatusbarToken") or "Interface/Buttons/WHITE8x8"
end

local function GetResourceDefs()
    local defs = Ctx().ResourceDefs
    if type(defs) == "table" then
        return defs
    end
    return EMPTY
end

local function ResolvePowerType(powerKey)
    return Call("ResolvePowerType", powerKey)
end

local function GetPlayerClassColor()
    return Call("GetPlayerClassColor")
end

local function GetDKSpecColor()
    return Call("GetDKSpecColor")
end

local function IsSecret(v)
    return (Secret and Secret.IsSecret and Secret.IsSecret(v)) == true
end

local function TryNumber(v)
    if U and U.TryNumber then
        return U.TryNumber(v)
    end
    if type(v) ~= "number" then return false, nil end
    if IsSecret(v) then return false, nil end
    return true, v
end

local function IsPlainNumber(x)
    if U and U.IsPlainNumber then
        return U.IsPlainNumber(x)
    end
    local ok = TryNumber(x)
    return ok == true
end

local function CanAccessValue(v)
    if Secret and Secret.CanAccess then
        return Secret.CanAccess(v)
    end
    return true
end

local function SafeSetText(fs, v)
    if not fs then return end
    if Secret and Secret.SafeSetText then
        Secret.SafeSetText(fs, v)
        return
    end
    pcall(fs.SetText, fs, v or "")
end

local function SafeClamp01(x)
    if not IsPlainNumber(x) then return 0 end
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

local function SafeDiv(a, b)
    if not (IsPlainNumber(a) and IsPlainNumber(b)) then return 0 end
    if b <= 0 then return 0 end
    return a / b
end

local function TruncateWhenZero(v)
    if Secret and Secret.TruncateWhenZero then
        return Secret.TruncateWhenZero(v)
    end
    if _G.C_StringUtil and _G.C_StringUtil.TruncateWhenZero then
        return _G.C_StringUtil.TruncateWhenZero(v)
    end
    if IsPlainNumber(v) then
        return (v > 0) and tostring(v) or ""
    end
    return ""
end

local function TryAbbreviateNumbers(v)
    if type(_G.AbbreviateNumbers) ~= "function" then
        return nil
    end
    local ok, s = pcall(_G.AbbreviateNumbers, v)
    if not ok then
        return nil
    end
    local okNil, isNil = pcall(function() return s == nil end)
    if okNil and isNil then
        return nil
    end
    return s
end

local function FormatPowerValueText(v, shortCfg)
    local sn = (type(shortCfg) == "table") and shortCfg or {}

    if sn.enabled == true and U and U.FormatNumberShort then
        local s = U.FormatNumberShort(v, {
            hideZero = true,
            suffixCase = sn.suffixCase,
            decimalsSmall = sn.decimalsSmall,
            decimalsLarge = sn.decimalsLarge,
        })
        if s ~= nil then
            return s
        end

        local abbrev = TryAbbreviateNumbers(v)
        if abbrev ~= nil then
            if IsSecret(abbrev) or not CanAccessValue(abbrev) then
                return abbrev
            end
            if sn.suffixCase ~= "upper" and type(abbrev) == "string" then
                local okG, out = pcall(function()
                    return (abbrev:gsub("K", "k"):gsub("M", "m"):gsub("B", "b"))
                end)
                if okG and type(out) == "string" then
                    return out
                end
            end
            return abbrev
        end
    end

    local okN, n = TryNumber(v)
    if okN then
        if n == 0 then
            return ""
        end
        if _G.BreakUpLargeNumbers and U and U.Round then
            local okS, s = pcall(_G.BreakUpLargeNumbers, U.Round(n))
            if okS and type(s) == "string" then
                return s
            end
        end
        return tostring((U and U.Round and U.Round(n)) or n)
    end

    return TruncateWhenZero(v)
end

local function GetPowerColor(token)
    if token == nil or IsSecret(token) then
        return 0.25, 0.55, 1
    end
    local tbl = _G.PowerBarColor
    if not tbl then return 0.25, 0.55, 1 end

    local t = tbl[token]
    if t and IsPlainNumber(t.r) and IsPlainNumber(t.g) and IsPlainNumber(t.b) then
        return t.r, t.g, t.b
    end
    return 0.25, 0.55, 1
end

local function GetRuneCooldown(i)
    if _G.C_Rune and _G.C_Rune.GetRuneCooldown then
        return _G.C_Rune.GetRuneCooldown(i)
    end
    if _G.GetRuneCooldown then
        return _G.GetRuneCooldown(i)
    end
    return nil, nil, nil
end

local function CreateSegment(parent, height)
    local style = GetStyleCfg()
    local s = CreateFrame("StatusBar", nil, parent)
    s:SetHeight(height)
    s:SetStatusBarTexture(Media:FetchStatusbar(GetSharedStatusbarToken()))
    s:SetMinMaxValues(0, 1)
    s:SetValue(0)

    s.bg = s:CreateTexture(nil, "BACKGROUND")
    s.bg:SetAllPoints()
    s.bg:SetColorTexture(0.07, 0.07, 0.07, 1)

    Media:CreateBorder(s, style.borderSize or 1)
    return s
end

function Render.EnsureSegmentPool(owner, count, height)
    if not owner or not owner.resourceBar then return end
    owner.resourceSegments = owner.resourceSegments or {}

    local need = tonumber(count) or 0
    need = math.floor(need)
    if need < 1 then need = 1 end
    if need > 32 then need = 32 end

    local have = #owner.resourceSegments
    if have >= need then return end

    for i = have + 1, need do
        owner.resourceSegments[i] = CreateSegment(owner.resourceBar, height or 12)
    end
end

local function LayoutSegments(container, segments, count, totalWidth, height, gap)
    gap = (IsPlainNumber(gap) and gap) or 2
    count = (IsPlainNumber(count) and count) or 0

    for i, seg in ipairs(segments) do
        seg:Hide()
        seg:ClearAllPoints()
    end

    if count <= 0 then
        container:SetWidth(totalWidth)
        container:SetHeight(height)
        return
    end

    local usable = totalWidth - (gap * (count - 1))
    local w = usable / count

    local prev = nil
    for i = 1, count do
        local seg = segments[i]
        if not seg then break end
        seg:Show()
        seg:SetWidth(w)
        seg:SetHeight(height)
        if not prev then
            seg:SetPoint("LEFT", container, "LEFT", 0, 0)
        else
            seg:SetPoint("LEFT", prev, "RIGHT", gap, 0)
        end
        prev = seg
    end
end

function Render.CreatePowerBar(parent, width, height)
    local style = GetStyleCfg()
    local text = GetCenterTextCfg()

    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(width, height)
    bar:SetStatusBarTexture(Media:FetchStatusbar(GetSharedStatusbarToken()))

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0.07, 0.07, 0.07, 1)

    Media:CreateBorder(bar, style.borderSize or 1)

    bar.text = bar:CreateFontString(nil, "OVERLAY")
    bar.text:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
    local font = text.font or GetSharedFontToken()
    local size = tonumber(text.size) or GetSharedFontSize()
    local outline = text.outline or GetSharedFontOutline()
    Media:ApplyFont(bar.text, font, size, outline)
    bar.text:SetJustifyH("RIGHT")
    bar.text:SetTextColor(1, 1, 1, 1)

    return bar
end

local function SetStatusBarColorIfChanged(bar, r, g, b, a)
    if not bar then return end
    a = (type(a) == "number") and a or 1
    if bar._fguiColorR == r and bar._fguiColorG == g and bar._fguiColorB == b and bar._fguiColorA == a then
        return
    end
    bar._fguiColorR = r
    bar._fguiColorG = g
    bar._fguiColorB = b
    bar._fguiColorA = a
    bar:SetStatusBarColor(r, g, b, a)
end

local function SetStatusBarValueIfChanged(bar, value)
    if not bar then return end
    if type(value) == "number" then
        local prev = bar._fguiValue
        if type(prev) == "number" and math.abs(prev - value) < 0.0001 then
            return
        end
        bar._fguiValue = value
        bar:SetValue(value)
        return
    end
    bar._fguiValue = nil
    bar:SetValue(value)
end

local function EnsureSpark(bar)
    if not bar then return nil end
    if bar._fguiSpark and bar._fguiSpark.SetPoint then
        return bar._fguiSpark
    end

    local spark = bar:CreateTexture(nil, "OVERLAY", nil, 7)
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetSize(22, 22)
    spark:SetAlpha(0.9)
    spark:Hide()
    spark._fguiShown = false
    bar._fguiSpark = spark
    return spark
end

local function SetSparkVisible(bar, show)
    local spark = EnsureSpark(bar)
    if not spark then return end
    if not show then
        if spark._fguiShown == true then
            spark:Hide()
            spark._fguiShown = false
        end
        return
    end

    local tex = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if not tex then
        if spark._fguiShown == true then
            spark:Hide()
            spark._fguiShown = false
        end
        return
    end

    local h = (bar.GetHeight and bar:GetHeight()) or 10
    local targetH = math.max(12, h + 10)
    if spark._fguiHeight ~= targetH then
        spark:SetHeight(targetH)
        spark._fguiHeight = targetH
    end
    if spark._fguiTex ~= tex then
        spark:ClearAllPoints()
        spark:SetPoint("CENTER", tex, "RIGHT", 0, 0)
        spark._fguiTex = tex
    end
    if spark._fguiShown ~= true then
        spark:Show()
        spark._fguiShown = true
    end
end

local function ClampNumber(v, minV, maxV, fallback)
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

function Render.RefreshThresholdConfig(owner)
    local center = GetCenterCfg()
    local threshold = (type(center.threshold) == "table") and center.threshold or {}
    local color = (type(threshold.color) == "table") and threshold.color or {}
    local format = GetFormatCfg()
    local shortNumbers = (type(format.shortNumbers) == "table") and format.shortNumbers or {}

    owner._thresholdEnabled = (threshold.enabled ~= false)
    owner._thresholdPercent = ClampNumber(threshold.percent, 10, 95, 70)
    owner._thresholdMode = (threshold.mode == "above") and "above" or "below"
    owner._thresholdSpark = (threshold.spark ~= false)
    owner._thresholdColor = owner._thresholdColor or {}
    owner._thresholdColor.r = ClampNumber(color.r, 0.00, 1.00, 1.00)
    owner._thresholdColor.g = ClampNumber(color.g, 0.00, 1.00, 0.34)
    owner._thresholdColor.b = ClampNumber(color.b, 0.00, 1.00, 0.12)
    owner._thresholdColor.a = ClampNumber(color.a, 0.00, 1.00, 1.00)

    owner._showPowerText = (center.showPowerText == true)
    owner._maxSegmentsCap = tonumber(center.maxSegments) or 10
    if owner._maxSegmentsCap <= 0 then
        owner._maxSegmentsCap = 10
    end
    owner._centerWidth = tonumber(center.width) or 560
    owner._resourceHeight = tonumber(center.resourceHeight) or 12
    owner._resourceGap = 2

    owner._shortCfg = owner._shortCfg or {}
    owner._shortCfg.enabled = (shortNumbers.enabled == true)
    owner._shortCfg.suffixCase = shortNumbers.suffixCase
    owner._shortCfg.decimalsSmall = shortNumbers.decimalsSmall
    owner._shortCfg.decimalsLarge = shortNumbers.decimalsLarge
end

function Render.IsThresholdActive(owner, ratio)
    if owner._thresholdEnabled ~= true then return false end
    if type(ratio) ~= "number" then return false end
    local threshold = (owner._thresholdPercent or 70) / 100
    if owner._thresholdMode == "above" then
        return ratio >= threshold
    end
    return ratio <= threshold
end

local function SelectThresholdColor(owner, active, r, g, b, a)
    if not active then
        return r, g, b, (type(a) == "number" and a or 1)
    end
    local c = owner and owner._thresholdColor
    if type(c) ~= "table" then
        return 1.00, 0.34, 0.12, 1.00
    end
    return c.r or 1.00, c.g or 0.34, c.b or 0.12, c.a or 1.00
end

function Render.EnsureResourceLayout(owner, count, totalWidth, height, gap)
    if not (owner.resourceBar and owner.resourceSegments) then return end
    local c = (type(count) == "number") and count or 0
    local w = (type(totalWidth) == "number") and totalWidth or 0
    local h = (type(height) == "number") and height or 0
    local g = (type(gap) == "number") and gap or 0

    local layout = owner._resourceLayout
    if layout and layout.count == c and layout.width == w and layout.height == h and layout.gap == g then
        return
    end

    LayoutSegments(owner.resourceBar, owner.resourceSegments, c, w, h, g)
    owner._resourceLayout = owner._resourceLayout or {}
    owner._resourceLayout.count = c
    owner._resourceLayout.width = w
    owner._resourceLayout.height = h
    owner._resourceLayout.gap = g
end

local RUNE_REFRESH_INTERVAL = 0.10
local MIN_RUNE_REFRESH_DELAY = 0.02

local function NormalizeRuneRefreshDelay(delay)
    local value = tonumber(delay)
    if type(value) ~= "number" or value <= 0 then
        return RUNE_REFRESH_INTERVAL
    end
    if value < MIN_RUNE_REFRESH_DELAY then
        return MIN_RUNE_REFRESH_DELAY
    end
    if value > RUNE_REFRESH_INTERVAL then
        return RUNE_REFRESH_INTERVAL
    end
    return value
end

function Render.StartRuneTicker(owner, delay)
    if type(owner) ~= "table" then
        return
    end

    local normalizedDelay = NormalizeRuneRefreshDelay(delay)
    if owner._runeTicker then
        local currentDelay = tonumber(owner._runeTickerDelay)
        if type(currentDelay) == "number" and currentDelay <= normalizedDelay then
            return
        end
        Render.StopRuneTicker(owner)
    end

    owner._runeTickerDelay = normalizedDelay
    owner._runeTicker = C_Timer.NewTimer(normalizedDelay, function()
        if type(owner) ~= "table" then
            return
        end

        owner._runeTicker = nil
        owner._runeTickerDelay = nil

        if owner.resourceMode ~= "RUNES" then
            return
        end
        if not owner.resourceBar or not owner.frame then
            return
        end
        if not owner.frame:IsShown() or not owner.resourceBar:IsShown() then
            return
        end
        if owner.UpdateRunes then
            owner:UpdateRunes()
        end
    end)
end

function Render.StopRuneTicker(owner)
    if owner._runeTicker then
        owner._runeTicker:Cancel()
        owner._runeTicker = nil
    end
    owner._runeTickerDelay = nil
end

function Render.UpdatePower(owner)
    if not owner.frame or not owner.powerBar then return end

    local powerType, powerToken = UnitPowerType("player")
    local cur = UnitPower("player", powerType)
    local max = UnitPowerMax("player", powerType)

    if max ~= nil then
        local okMaxNum, maxNum = TryNumber(max)
        if okMaxNum and type(maxNum) == "number" then
            if owner._powerLastMax ~= maxNum then
                owner.powerBar:SetMinMaxValues(0, maxNum)
                owner._powerLastMax = maxNum
            end
        else
            owner._powerLastMax = nil
            owner.powerBar:SetMinMaxValues(0, max)
        end
    end
    if cur ~= nil then
        local okCurNum, curNum = TryNumber(cur)
        if okCurNum and type(curNum) == "number" then
            SetStatusBarValueIfChanged(owner.powerBar, curNum)
        else
            owner.powerBar._fguiValue = nil
            owner.powerBar:SetValue(cur)
        end
    end

    local ratio = nil
    local okCur, curNum = TryNumber(cur)
    local okMax, maxNum = TryNumber(max)
    if okCur and okMax and maxNum and maxNum > 0 then
        ratio = SafeClamp01(curNum / maxNum)
    end

    local low = Render.IsThresholdActive(owner, ratio)
    local r, g, b = GetPowerColor(powerToken)
    r, g, b = SelectThresholdColor(owner, low, r, g, b, 1)
    SetStatusBarColorIfChanged(owner.powerBar, r, g, b, 1)

    local showSpark = (low and owner._thresholdSpark == true and ratio and ratio > 0)
    SetSparkVisible(owner.powerBar, showSpark)

    if owner._showPowerText and owner.powerBar.text then
        SafeSetText(owner.powerBar.text, FormatPowerValueText(cur, owner._shortCfg))
    elseif owner.powerBar.text then
        SafeSetText(owner.powerBar.text, "")
    end
end

function Render.UpdatePointResource(owner)
    if not (owner.resourceBar and owner.resourceSegments) then return end
    if not owner.resourcePowerType then return end

    local cur = UnitPower("player", owner.resourcePowerType)
    local max = UnitPowerMax("player", owner.resourcePowerType)

    local cfgCap = tonumber(owner._maxSegmentsCap) or 10
    if cfgCap <= 0 then cfgCap = 10 end

    local want = tonumber(owner.resourceMaxSegments or cfgCap) or cfgCap
    if want > cfgCap then want = cfgCap end
    if want < 1 then want = 1 end

    local okMax, maxNum = TryNumber(max)
    local show = want
    if okMax and maxNum and maxNum > 0 and maxNum < show then
        show = maxNum
    end

    Render.EnsureSegmentPool(owner, show, owner._resourceHeight or 12)
    Render.EnsureResourceLayout(owner, show, owner._centerWidth or 560, owner._resourceHeight or 12, owner._resourceGap or 2)

    local r, g, b = 0.0, 0.75, 1.0
    if owner.resourceColor and type(owner.resourceColor) == "table"
        and type(owner.resourceColor[1]) == "number"
        and type(owner.resourceColor[2]) == "number"
        and type(owner.resourceColor[3]) == "number" then
        r, g, b = owner.resourceColor[1], owner.resourceColor[2], owner.resourceColor[3]
    end

    local okCur, curNum = TryNumber(cur)
    local ratio = nil
    if okCur and okMax and maxNum and maxNum > 0 then
        ratio = SafeClamp01(curNum / maxNum)
    end
    local low = Render.IsThresholdActive(owner, ratio)
    r, g, b = SelectThresholdColor(owner, low, r, g, b, 1)

    local perSeg = nil
    if okMax and maxNum and show > 0 then
        perSeg = maxNum / show
    end

    local sparkIndex = nil
    local lastActive = nil
    for i = 1, show do
        local seg = owner.resourceSegments[i]
        if not seg then
            break
        end

        local value = 0
        if perSeg and perSeg > 0 and okCur and curNum then
            local startVal = (i - 1) * perSeg
            value = SafeClamp01((curNum - startVal) / perSeg)
        end

        SetStatusBarValueIfChanged(seg, value)
        SetStatusBarColorIfChanged(seg, r, g, b, 1)
        seg:Show()

        if value > 0 then
            lastActive = i
            if value < 1 then
                sparkIndex = i
            end
        end
    end

    if not sparkIndex then
        sparkIndex = lastActive
    end

    local showSpark = (low and owner._thresholdSpark == true and sparkIndex ~= nil)
    for i = 1, show do
        local seg = owner.resourceSegments[i]
        if not seg then
            break
        end
        SetSparkVisible(seg, showSpark and i == sparkIndex)
    end

    for i = show + 1, #owner.resourceSegments do
        local seg = owner.resourceSegments[i]
        SetSparkVisible(seg, false)
        seg:Hide()
    end
end

function Render.UpdateComboPoints(owner)
    return Render.UpdatePointResource(owner)
end

function Render.UpdateRunes(owner)
    if not owner.resourceBar or not owner.resourceSegments then return end

    local show = 6
    Render.EnsureSegmentPool(owner, show, owner._resourceHeight or 12)
    Render.EnsureResourceLayout(owner, show, owner._centerWidth or 560, owner._resourceHeight or 12, owner._resourceGap or 2)

    local anyRecharging = false
    local nextDelay = nil
    local now = GetTime()

    local r, g, b = 0.0, 0.65, 1.0
    if owner.resourceColor and type(owner.resourceColor) == "table" and IsPlainNumber(owner.resourceColor[1]) then
        r, g, b = owner.resourceColor[1], owner.resourceColor[2], owner.resourceColor[3]
    end

    local totalFill = 0
    local sparkIndex = nil
    local lastActive = nil
    for i = 1, show do
        local seg = owner.resourceSegments[i]
        local start, duration, ready = GetRuneCooldown(i)

        local readyPlain = nil
        if type(ready) == "boolean" and not IsSecret(ready) then
            readyPlain = ready
        end

        local durationPlain = (IsPlainNumber(duration) and duration) or nil
        local value = 0
        if readyPlain == true or (durationPlain ~= nil and durationPlain == 0) then
            value = 1
        else
            if IsPlainNumber(start) and durationPlain and durationPlain > 0 then
                anyRecharging = true
                local elapsed = now - start
                local remaining = durationPlain - elapsed
                if remaining > 0 then
                    if nextDelay == nil or remaining < nextDelay then
                        nextDelay = remaining
                    end
                end
                value = SafeClamp01(SafeDiv(elapsed, durationPlain))
            end
        end

        SetStatusBarValueIfChanged(seg, value)
        totalFill = totalFill + value
        if value > 0 then
            lastActive = i
            if value < 1 then
                sparkIndex = i
            end
        end
    end

    local ratio = nil
    if show > 0 then
        ratio = SafeClamp01(totalFill / show)
    end
    local low = Render.IsThresholdActive(owner, ratio)
    r, g, b = SelectThresholdColor(owner, low, r, g, b, 1)

    if not sparkIndex then
        sparkIndex = lastActive
    end
    local showSpark = (low and owner._thresholdSpark == true and sparkIndex ~= nil)
    for i = 1, show do
        local seg = owner.resourceSegments[i]
        SetStatusBarColorIfChanged(seg, r, g, b, 1)
        SetSparkVisible(seg, showSpark and i == sparkIndex)
    end

    if anyRecharging and owner.resourceMode == "RUNES" and owner.frame and owner.frame:IsShown()
        and owner.resourceBar and owner.resourceBar:IsShown() then
        Render.StartRuneTicker(owner, nextDelay)
    else
        Render.StopRuneTicker(owner)
    end
end

local function SoftHideFrame(frame)
    if not frame then
        return
    end
    pcall(frame.SetAlpha, frame, 0)
    pcall(frame.Hide, frame)
end

local function RestoreFrameSuppression(frame)
    if not frame then
        return
    end
    frame._fguiSuppressRequested = nil
    pcall(frame.SetAlpha, frame, 1)
    if type(frame.Setup) == "function" then
        pcall(frame.Setup, frame)
        return
    end
    pcall(frame.Show, frame)
end

local function EnsureFrameHideHook(frame)
    if not frame or frame._fguiSuppressHooked then
        return
    end
    if type(frame.HookScript) == "function" then
        pcall(frame.HookScript, frame, "OnShow", function(self)
            if self._fguiSuppressRequested then
                SoftHideFrame(self)
            end
        end)
    end
    frame._fguiSuppressHooked = true
end

local function GetSuppressedFrameRegistry(owner)
    if type(owner._suppressedClassResourceFrames) ~= "table" then
        owner._suppressedClassResourceFrames = {}
    end
    return owner._suppressedClassResourceFrames
end

function Render.RestoreDefaultClassResources(owner)
    if type(owner) ~= "table" then
        return
    end

    owner._pendingClassResourceSync = nil

    local registry = owner._suppressedClassResourceFrames
    if type(registry) ~= "table" then
        return
    end

    for name, frame in pairs(registry) do
        RestoreFrameSuppression(frame)
        registry[name] = nil
    end
end

function Render.SyncDefaultClassResources(owner)
    if type(owner) ~= "table" then
        return
    end

    local center = GetCenterCfg()
    local hideNames = owner._hideFrames
    local shouldHide = center.hideBlizzardClassResources ~= false
        and type(hideNames) == "table"
        and #hideNames > 0

    if _G.InCombatLockdown and InCombatLockdown() then
        owner._pendingClassResourceSync = true
        return
    end

    owner._pendingClassResourceSync = nil

    if not shouldHide then
        Render.RestoreDefaultClassResources(owner)
        return
    end

    local registry = GetSuppressedFrameRegistry(owner)
    local activeNames = {}

    for _, name in ipairs(hideNames) do
        activeNames[name] = true
        local frame = name and _G[name]
        if frame then
            EnsureFrameHideHook(frame)
            frame._fguiSuppressRequested = true
            registry[name] = frame
            SoftHideFrame(frame)
        end
    end

    for name, frame in pairs(registry) do
        if not activeNames[name] then
            RestoreFrameSuppression(frame)
            registry[name] = nil
        end
    end
end

function Render.HideDefaultClassResources(owner)
    return Render.SyncDefaultClassResources(owner)
end

function Render.OnCombatEnd(owner)
    if owner._pendingClassResourceSync then
        Render.SyncDefaultClassResources(owner)
    end
end

function Render.RefreshResourceMode(owner)
    if not owner.frame then return end

    local _, class = UnitClass("player")
    local center = GetCenterCfg()

    owner.resourceMode = "NONE"
    owner.resourcePowerType = nil
    owner.resourceMaxSegments = nil
    owner.resourceColor = nil
    owner._hideFrames = nil
    owner._resourceLayout = nil

    local showClassBar = (center.showClassBar ~= false)
    local defs = GetResourceDefs()
    local def = showClassBar and defs[class] or nil
    if def then
        if def.kind == "RUNES" then
            owner.resourceMode = "RUNES"
            owner.resourceMaxSegments = def.segments or 6
            owner.resourceColor = def.color
            owner._hideFrames = def.hideFrames

            if center.useClassColorForResource ~= false then
                local classColor = GetPlayerClassColor()
                if classColor then
                    owner.resourceColor = classColor
                end
            end

            if class == "DEATHKNIGHT" and center.useSpecColorForRunes ~= false then
                local specColor = GetDKSpecColor()
                if specColor then
                    owner.resourceColor = specColor
                end
            end
        elseif def.kind == "POWER_POINTS" then
            local powerType = ResolvePowerType(def.powerKey)
            if powerType then
                owner.resourceMode = "POINTS"
                owner.resourcePowerType = powerType
                owner.resourceMaxSegments = def.maxSegments
                owner.resourceColor = def.color
                owner._hideFrames = def.hideFrames

                if center.useClassColorForResource ~= false then
                    local classColor = GetPlayerClassColor()
                    if classColor then
                        owner.resourceColor = classColor
                    end
                end
            end
        end
    end

    local w = tonumber(center.width) or 560
    local h1 = tonumber(center.resourceHeight) or 12
    local h2 = tonumber(center.powerHeight) or 14
    local gap = tonumber(center.spacing) or 6

    if owner.resourceMode == "NONE" then
        if owner.resourceBar then owner.resourceBar:Hide() end
        if owner.resourceSegments then
            for i = 1, #owner.resourceSegments do
                SetSparkVisible(owner.resourceSegments[i], false)
            end
        end
        if owner.powerBar then
            SetSparkVisible(owner.powerBar, false)
        end
        Render.StopRuneTicker(owner)

        if owner.powerBar then
            owner.powerBar:ClearAllPoints()
            owner.powerBar:SetPoint("TOP", owner.frame, "TOP", 0, 0)
        end
        owner.frame:SetSize(w, h2)
        Render.SyncDefaultClassResources(owner)
        return
    end

    if owner.resourceBar then owner.resourceBar:Show() end
    if owner.powerBar and owner.resourceBar then
        owner.powerBar:ClearAllPoints()
        owner.powerBar:SetPoint("TOP", owner.resourceBar, "BOTTOM", 0, -gap)
    end
    owner.frame:SetSize(w, h1 + gap + h2)

    if owner.resourceMode == "RUNES" then
        Render.UpdateRunes(owner)
    elseif owner.resourceMode == "POINTS" then
        Render.UpdatePointResource(owner)
    end

    Render.SyncDefaultClassResources(owner)
end

function Render.OnUnitPower(owner, unit)
    if unit ~= "player" then return end
    Render.UpdatePower(owner)
    if owner.resourceMode == "POINTS" then
        Render.UpdatePointResource(owner)
    end
end

function Render.OnRuneEvent(owner)
    if owner.resourceMode == "RUNES" then
        Render.UpdateRunes(owner)
    end
end

return Render
