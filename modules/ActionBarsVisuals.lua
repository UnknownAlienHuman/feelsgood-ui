-- FeelsGoodUI: ActionBars visual sync helpers
local _, ns = ...

local Visuals = {}
ns.ActionBarsVisuals = Visuals

local Media = ns.Media
local Theme = ns.Theme
local State = ns.ActionBarsState

local InCombat = InCombatLockdown or function() return false end

Visuals._regionRegistry = Visuals._regionRegistry or setmetatable({}, { __mode = "k" })
local RegionRegistry = Visuals._regionRegistry

local function GetButtonRecord(button, create)
    if State and type(State.GetButtonRecord) == "function" then
        return State.GetButtonRecord(button, create == true)
    end
    return nil
end

local function GetRegionRecord(region, create)
    if not region then return nil end
    local record = RegionRegistry[region]
    if not record and create then
        record = {}
        RegionRegistry[region] = record
    end
    return record
end

local function Tex(btn, suffix)
    if not btn or not btn.GetName then return nil end
    local name = btn:GetName()
    if not name then return nil end
    return _G[name .. suffix]
end

local function HideTexture(tex)
    if not tex then return end
    if tex.SetAlpha then
        tex:SetAlpha(0)
    end
    if tex.Hide then
        tex:Hide()
    end
end

local function HideDefaultStateTextures(btn)
    if not btn then return end

    local highlight = btn.GetHighlightTexture and btn:GetHighlightTexture()
    if highlight then
        highlight:SetAlpha(0)
        if highlight.Hide then
            highlight:Hide()
        end
    end

    local checked = btn.GetCheckedTexture and btn:GetCheckedTexture()
    if checked then
        checked:SetAlpha(0)
        if checked.Hide then
            checked:Hide()
        end
    end

    local pushed = btn.GetPushedTexture and btn:GetPushedTexture()
    if pushed then
        pushed:SetAlpha(0)
        if pushed.Hide then
            pushed:Hide()
        end
    end
end

local function RefreshDefaultButtonArt(btn)
    if not btn then
        return
    end

    local icon = btn.icon or Tex(btn, "Icon")
    if icon then
        icon:SetAllPoints(btn)
        Media:ApplyIconCrop(icon)
    end

    HideTexture(Tex(btn, "Border"))

    local normal = btn.GetNormalTexture and btn:GetNormalTexture()
    if normal then
        HideTexture(normal)
    end

    HideTexture(Tex(btn, "Flash"))
    HideTexture(Tex(btn, "NormalTexture"))
    HideTexture(btn.SlotBackground or Tex(btn, "SlotBackground"))
    HideTexture(btn.SlotArt or Tex(btn, "SlotArt"))
    HideDefaultStateTextures(btn)
end

local function ApplyTypography(region, button, style, size, point, relativePoint, x, y, justify)
    if not region then return end
    local record = GetRegionRecord(region, true)

    if record.font ~= style.font or record.size ~= size or record.outline ~= style.outline then
        Media:ApplyFont(region, style.font, size, style.outline)
        record.font, record.size, record.outline = style.font, size, style.outline
    end
    if not record.anchored then
        region:ClearAllPoints()
        region:SetPoint(point, button, relativePoint, x, y)
        region:SetJustifyH(justify)
        record.anchored = true
    end
    region:SetDrawLayer("OVERLAY")
end

function Visuals.ApplyButtonTypography(btn, style)
    if not (btn and style) then return end

    ApplyTypography(
        btn.HotKey or Tex(btn, "HotKey"),
        btn,
        style,
        style.hotkeySize,
        "TOPRIGHT",
        "TOPRIGHT",
        -1,
        -1,
        "RIGHT"
    )
    ApplyTypography(
        btn.Count or Tex(btn, "Count"),
        btn,
        style,
        style.countSize,
        "BOTTOMRIGHT",
        "BOTTOMRIGHT",
        -1,
        1,
        "RIGHT"
    )
    ApplyTypography(
        btn.Name or Tex(btn, "Name"),
        btn,
        style,
        style.nameSize or style.hotkeySize,
        "BOTTOM",
        "BOTTOM",
        0,
        1,
        "CENTER"
    )
end

local function GetCooldownTimerText(cooldownFrame)
    if not cooldownFrame then return nil end
    local record = GetRegionRecord(cooldownFrame, true)
    local cached = record and record.timerText
    if cached and cached.GetObjectType and cached:GetObjectType() == "FontString" then
        return cached
    end

    local regions = { cooldownFrame:GetRegions() }
    for i = 1, #regions do
        local region = regions[i]
        if region and region.GetObjectType and region:GetObjectType() == "FontString" then
            record.timerText = region
            return region
        end
    end
    record.timerText = nil
    return nil
end

function Visuals.StyleButtonCooldown(btn, style)
    if not (btn and style) then return end

    local cooldown = btn.cooldown or btn.Cooldown or Tex(btn, "Cooldown")
    if not cooldown then return end
    local cooldownRecord = GetRegionRecord(cooldown, true)

    if not InCombat() and not cooldownRecord.anchored then
        cooldown:ClearAllPoints()
        cooldown:SetAllPoints(btn)
        cooldownRecord.anchored = true
    end

    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
    if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture("Interface/Buttons/WHITE8x8") end
    if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(true) end
    if cooldown.SetSwipeColor then cooldown:SetSwipeColor(0, 0, 0, 0.78) end

    local timer = GetCooldownTimerText(cooldown)
    if timer then
        local timerRecord = GetRegionRecord(timer, true)
        if timerRecord.font ~= style.font
            or timerRecord.size ~= style.cooldownSize
            or timerRecord.outline ~= style.outline then
            Media:ApplyFont(timer, style.font, style.cooldownSize, style.outline)
            timerRecord.font = style.font
            timerRecord.size = style.cooldownSize
            timerRecord.outline = style.outline
        end
        if not timerRecord.anchored then
            timer:ClearAllPoints()
            timer:SetPoint("CENTER", cooldown, "CENTER", 0, 0)
            timer:SetJustifyH("CENTER")
            timerRecord.anchored = true
        end
        timer:SetDrawLayer("OVERLAY")
    end
end

function Visuals.SkinButton(btn, style)
    if not btn then return false end
    local record = GetButtonRecord(btn, true)
    if not record then return false end

    if not record.skinned then
        record.skinned = true
        Media:CreateBorder(btn)
    end

    RefreshDefaultButtonArt(btn)
    if type(style) == "table" then
        record.visualStyle = style
        Visuals.ApplyButtonTypography(btn, style)
        Visuals.StyleButtonCooldown(btn, style)
    end

    if State and State.InitializeButton then
        local ok, detail = State.InitializeButton(btn)
        if ok == false then return false, detail end
    end
    return true
end

function Visuals.SetButtonHotkey(btn, show)
    local record = GetButtonRecord(btn, true)
    if record then record.showHotkeys = (show == true) end

    local hotkey = btn and (btn.HotKey or Tex(btn, "HotKey")) or nil
    if not hotkey then return false end

    if show then
        hotkey:SetAlpha(1)
        hotkey:Show()
    else
        hotkey:SetAlpha(0)
        hotkey:Hide()
    end
    return true
end

function Visuals.RefreshButtonVisualState(btn, style, showHotkeys)
    local record = GetButtonRecord(btn, false)
    if not (btn and record and record.skinned) then return false end

    style = (type(style) == "table") and style or record.visualStyle
    if type(style) == "table" then record.visualStyle = style end
    if showHotkeys ~= nil then record.showHotkeys = (showHotkeys == true) end

    RefreshDefaultButtonArt(btn)
    if type(style) == "table" then
        Visuals.ApplyButtonTypography(btn, style)
        Visuals.StyleButtonCooldown(btn, style)
    end

    Visuals.SetButtonHotkey(btn, record.showHotkeys == true)
    if State and State.InitializeButton then
        local ok, detail = State.InitializeButton(btn)
        if ok == false then return false, detail end
    end
    if State and State.UpdateButtonChecked then State.UpdateButtonChecked(btn) end
    if State and State.UpdateButtonEmpty then State.UpdateButtonEmpty(btn) end
    return true
end

function Visuals.BuildStyleConfig(size)
    local font = (Theme and Theme.GetFontToken and Theme:GetFontToken()) or "Fonts\\FRIZQT__.TTF"
    local outline = ((Theme and Theme.GetFontOutline and Theme:GetFontOutline())
        or "OUTLINE")

    local function ScaleSize(base, mult, minv, maxv)
        local value = math.floor((base * mult) + 0.5)
        if value < minv then value = minv end
        if value > maxv then value = maxv end
        return value
    end

    return {
        font = font,
        outline = outline,
        hotkeySize = ScaleSize(size, 0.32, 8, 16),
        countSize = ScaleSize(size, 0.36, 8, 18),
        cooldownSize = ScaleSize(size, 0.40, 8, 20),
        nameSize = ScaleSize(size, 0.28, 8, 14),
    }
end

return Visuals
