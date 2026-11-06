-- FeelsGoodUI: Retail 12.1.5 restricted-value adapter for center bars
--
-- Ordinary values use the existing renderer. Inaccessible power/rune values
-- bypass legacy inspection and go only to exact native sinks or an explicit
-- unavailable presentation.

local _, ns = ...

local Secret = ns.Secret
local Render = ns.CenterBarsRender

if not (Secret and Render) then
    return
end

local OriginalUpdatePower = Render.UpdatePower
local OriginalUpdateRunes = Render.UpdateRunes

local function CanInspect(value)
    if Secret.CanAccess then
        return Secret.CanAccess(value)
    end
    if Secret.IsSecret then
        return not Secret.IsSecret(value)
    end
    return true
end

local function HideSpark(bar)
    local spark = bar and bar._fguiSpark
    if spark then
        spark:Hide()
        spark._fguiShown = false
    end
end

local function SetOpaqueText(fontString, value)
    if not fontString then return end
    if Secret.SafeSetText then
        Secret.SafeSetText(fontString, value)
    else
        fontString:SetText(value)
    end
end

function Render.UpdatePower(owner)
    if not (owner and owner.frame and owner.powerBar) then return end

    local powerType, powerToken = _G.UnitPowerType("player")
    if not CanInspect(powerType) or not CanInspect(powerToken) then
        owner.powerBar:SetStatusBarColor(0.25, 0.55, 1, 1)
        HideSpark(owner.powerBar)
        if owner.powerBar.text then owner.powerBar.text:SetText("") end
        return
    end

    local current = _G.UnitPower("player", powerType)
    local maximum = _G.UnitPowerMax("player", powerType)
    if CanInspect(current) and CanInspect(maximum) then
        return OriginalUpdatePower(owner)
    end

    -- StatusBar setters are the selected one-way native path. Do not compare,
    -- normalize, cache, format, or read these values back.
    owner._powerLastMax = nil
    owner.powerBar._fguiValue = nil
    owner.powerBar:SetMinMaxValues(0, maximum)
    owner.powerBar:SetValue(current)
    owner.powerBar:SetStatusBarColor(0.25, 0.55, 1, 1)
    HideSpark(owner.powerBar)

    if owner.powerBar.text then
        if owner._showPowerText == true then
            SetOpaqueText(owner.powerBar.text, current)
        else
            owner.powerBar.text:SetText("")
        end
    end
end

local function GetRuneCooldown(index)
    if _G.C_Rune and type(_G.C_Rune.GetRuneCooldown) == "function" then
        return _G.C_Rune.GetRuneCooldown(index)
    end
    if type(_G.GetRuneCooldown) == "function" then
        return _G.GetRuneCooldown(index)
    end
    return nil, nil, nil
end

local function RunesAreInspectable()
    for index = 1, 6 do
        local start, duration, ready = GetRuneCooldown(index)
        if not CanInspect(start) or not CanInspect(duration) or not CanInspect(ready) then
            return false
        end
    end
    return true
end

local function ShowUnavailableRunes(owner)
    local count = 6
    Render.EnsureSegmentPool(owner, count, owner._resourceHeight or 12)
    Render.EnsureResourceLayout(
        owner,
        count,
        owner._centerWidth or 560,
        owner._resourceHeight or 12,
        owner._resourceGap or 2
    )

    for index = 1, count do
        local segment = owner.resourceSegments[index]
        if segment then
            segment._fguiValue = 0
            segment:SetValue(0)
            segment:SetStatusBarColor(0.25, 0.55, 1, 1)
            HideSpark(segment)
            segment:Show()
        end
    end

    Render.StopRuneTicker(owner)
end

function Render.UpdateRunes(owner)
    if not (owner and owner.resourceBar and owner.resourceSegments) then return end
    if RunesAreInspectable() then
        return OriginalUpdateRunes(owner)
    end
    ShowUnavailableRunes(owner)
end
