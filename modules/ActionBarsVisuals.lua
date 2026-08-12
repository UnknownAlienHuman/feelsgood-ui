-- FeelsGoodUI: ActionBars visual sync helpers
local _, ns = ...

local Visuals = {}
ns.ActionBarsVisuals = Visuals

local Media = ns.Media
local Theme = ns.Theme
local State = ns.ActionBarsState

local InCombat = InCombatLockdown or function() return false end

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

function Visuals.ApplyButtonTypography(btn, style)
    if not (btn and style) then return end

    local hotkey = btn.HotKey or Tex(btn, "HotKey")
    if hotkey then
        if hotkey._fguiFont ~= style.font or hotkey._fguiSize ~= style.hotkeySize or hotkey._fguiOutline ~= style.outline then
            Media:ApplyFont(hotkey, style.font, style.hotkeySize, style.outline)
            hotkey._fguiFont, hotkey._fguiSize, hotkey._fguiOutline = style.font, style.hotkeySize, style.outline
        end
        if not hotkey._fguiAnchored then
            hotkey:ClearAllPoints()
            hotkey:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -1, -1)
            hotkey:SetJustifyH("RIGHT")
            hotkey._fguiAnchored = true
        end
        hotkey:SetDrawLayer("OVERLAY")
    end

    local count = btn.Count or Tex(btn, "Count")
    if count then
        if count._fguiFont ~= style.font or count._fguiSize ~= style.countSize or count._fguiOutline ~= style.outline then
            Media:ApplyFont(count, style.font, style.countSize, style.outline)
            count._fguiFont, count._fguiSize, count._fguiOutline = style.font, style.countSize, style.outline
        end
        if not count._fguiAnchored then
            count:ClearAllPoints()
            count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
            count:SetJustifyH("RIGHT")
            count._fguiAnchored = true
        end
        count:SetDrawLayer("OVERLAY")
    end

    local name = btn.Name or Tex(btn, "Name")
    if name then
        local size = style.nameSize or style.hotkeySize
        if name._fguiFont ~= style.font or name._fguiSize ~= size or name._fguiOutline ~= style.outline then
            Media:ApplyFont(name, style.font, size, style.outline)
            name._fguiFont, name._fguiSize, name._fguiOutline = style.font, size, style.outline
        end
        if not name._fguiAnchored then
            name:ClearAllPoints()
            name:SetPoint("BOTTOM", btn, "BOTTOM", 0, 1)
            name:SetJustifyH("CENTER")
            name._fguiAnchored = true
        end
        name:SetDrawLayer("OVERLAY")
    end
end

local function GetCooldownTimerText(cooldownFrame)
    if not cooldownFrame then return nil end
    if cooldownFrame._fguiTimerText and cooldownFrame._fguiTimerText.GetObjectType and cooldownFrame._fguiTimerText:GetObjectType() == "FontString" then
        return cooldownFrame._fguiTimerText
    end

    local regions = { cooldownFrame:GetRegions() }
    for i = 1, #regions do
        local region = regions[i]
        if region and region.GetObjectType and region:GetObjectType() == "FontString" then
            cooldownFrame._fguiTimerText = region
            return region
        end
    end
    return nil
end

function Visuals.StyleButtonCooldown(btn, style)
    if not (btn and style) then return end

    local cooldown = btn.cooldown or btn.Cooldown or Tex(btn, "Cooldown")
    if not cooldown then return end

    if not InCombat() then
        if not cooldown._fguiAnchored then
            cooldown:ClearAllPoints()
            cooldown:SetAllPoints(btn)
            cooldown._fguiAnchored = true
        end
    end

    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
    if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture("Interface/Buttons/WHITE8x8") end
    if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(true) end
    if cooldown.SetSwipeColor then cooldown:SetSwipeColor(0, 0, 0, 0.78) end

    local timer = GetCooldownTimerText(cooldown)
    if timer then
        if timer._fguiFont ~= style.font or timer._fguiSize ~= style.cooldownSize or timer._fguiOutline ~= style.outline then
            Media:ApplyFont(timer, style.font, style.cooldownSize, style.outline)
            timer._fguiFont, timer._fguiSize, timer._fguiOutline = style.font, style.cooldownSize, style.outline
        end
        if not timer._fguiAnchored then
            timer:ClearAllPoints()
            timer:SetPoint("CENTER", cooldown, "CENTER", 0, 0)
            timer:SetJustifyH("CENTER")
            timer._fguiAnchored = true
        end
        timer:SetDrawLayer("OVERLAY")
    end
end

function Visuals.SkinButton(btn, style)
    if not btn then
        return
    end

    if not btn._fguiSkinned then
        btn._fguiSkinned = true
        Media:CreateBorder(btn)
    end

    RefreshDefaultButtonArt(btn)
    if type(style) == "table" then
        btn._fguiVisualStyle = style
        Visuals.ApplyButtonTypography(btn, style)
        Visuals.StyleButtonCooldown(btn, style)
    end

    if State and State.InitializeButton then
        State.InitializeButton(btn)
    end
end

function Visuals.SetButtonHotkey(btn, show)
    local hotkey = btn.HotKey or Tex(btn, "HotKey")
    if btn then
        btn._fguiShowHotkeys = (show == true)
    end
    if not hotkey then return end

    if show then
        hotkey:SetAlpha(1)
        hotkey:Show()
    else
        hotkey:SetAlpha(0)
        hotkey:Hide()
    end
end

function Visuals.RefreshButtonVisualState(btn, style, showHotkeys)
    if not (btn and btn._fguiSkinned) then
        return false
    end

    style = (type(style) == "table") and style or btn._fguiVisualStyle
    if type(style) == "table" then
        btn._fguiVisualStyle = style
    end

    if showHotkeys ~= nil then
        btn._fguiShowHotkeys = (showHotkeys == true)
    end

    RefreshDefaultButtonArt(btn)

    if type(style) == "table" then
        Visuals.ApplyButtonTypography(btn, style)
        Visuals.StyleButtonCooldown(btn, style)
    end

    Visuals.SetButtonHotkey(btn, btn._fguiShowHotkeys == true)

    if State and State.InitializeButton then
        State.InitializeButton(btn)
    end

    if btn.__fguiUpdateChecked then
        btn.__fguiUpdateChecked(btn)
    end
    if btn.__fguiUpdateEmpty then
        btn.__fguiUpdateEmpty(btn)
    end

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
