from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


state_path = Path('modules/ActionBarsState.lua')
state = state_path.read_text(encoding='utf-8')
state = replace_once(
    state,
    'local InCombat = InCombatLockdown or function() return false end\n\n',
    '''local InCombat = InCombatLockdown or function() return false end

State._buttonRegistry = State._buttonRegistry or setmetatable({}, { __mode = "k" })
local ButtonRegistry = State._buttonRegistry

local function GetButtonRecord(button, create)
    if not button then return nil end
    local record = ButtonRegistry[button]
    if not record and create then
        record = { layers = {} }
        ButtonRegistry[button] = record
    end
    return record
end

function State.GetButtonRecord(button, create)
    return GetButtonRecord(button, create == true)
end

function State.IsManagedButton(button)
    local record = GetButtonRecord(button, false)
    return record and record.skinned == true or false
end

''',
    'ActionBars button registry',
)

old_layers = '''local function EnsureStateLayers(btn)
    if not btn or btn.__fguiStateLayers then return end
    btn.__fguiStateLayers = true

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(btn)
    hl:SetColorTexture(1, 1, 1, 0.08)
    hl:Hide()

    local ck = btn:CreateTexture(nil, "OVERLAY", nil, 1)
    ck:SetAllPoints(btn)
    ck:SetColorTexture(1, 1, 1, 0.14)
    ck:SetBlendMode("ADD")
    ck:Hide()

    local pr = btn:CreateTexture(nil, "OVERLAY", nil, 2)
    pr:SetAllPoints(btn)
    pr:SetColorTexture(1, 1, 1, 0.22)
    pr:SetBlendMode("ADD")
    pr:Hide()

    btn.__fguiHL = hl
    btn.__fguiCK = ck
    btn.__fguiPR = pr

    local dhl = btn.GetHighlightTexture and btn:GetHighlightTexture()
    if dhl then dhl:SetAlpha(0) end
    local dck = btn.GetCheckedTexture and btn:GetCheckedTexture()
    if dck then dck:SetAlpha(0) end
    local pushed = btn.GetPushedTexture and btn:GetPushedTexture()
    if pushed then pushed:SetAlpha(0) end

    btn:HookScript("OnEnter", function(b)
        if b._fguiModule and b._fguiModule._detached == true then
            return
        end
        if b.__fguiHL then b.__fguiHL:Show() end
    end)
    btn:HookScript("OnLeave", function(b)
        if b.__fguiHL then b.__fguiHL:Hide() end
    end)
end
'''
new_layers = '''local function EnsureStateLayers(btn)
    local record = GetButtonRecord(btn, true)
    if not record or record.stateLayers then return end
    record.stateLayers = true
    record.layers = record.layers or {}

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(btn)
    hl:SetColorTexture(1, 1, 1, 0.08)
    hl:Hide()

    local ck = btn:CreateTexture(nil, "OVERLAY", nil, 1)
    ck:SetAllPoints(btn)
    ck:SetColorTexture(1, 1, 1, 0.14)
    ck:SetBlendMode("ADD")
    ck:Hide()

    local pr = btn:CreateTexture(nil, "OVERLAY", nil, 2)
    pr:SetAllPoints(btn)
    pr:SetColorTexture(1, 1, 1, 0.22)
    pr:SetBlendMode("ADD")
    pr:Hide()

    record.layers.highlight = hl
    record.layers.checked = ck
    record.layers.pressed = pr

    local dhl = btn.GetHighlightTexture and btn:GetHighlightTexture()
    if dhl then dhl:SetAlpha(0) end
    local dck = btn.GetCheckedTexture and btn:GetCheckedTexture()
    if dck then dck:SetAlpha(0) end
    local pushed = btn.GetPushedTexture and btn:GetPushedTexture()
    if pushed then pushed:SetAlpha(0) end

    btn:HookScript("OnEnter", function(button)
        local current = GetButtonRecord(button, false)
        local owner = current and current.module
        if owner and owner._detached == true then return end
        local layer = current and current.layers and current.layers.highlight
        if layer then layer:Show() end
    end)
    btn:HookScript("OnLeave", function(button)
        local current = GetButtonRecord(button, false)
        local layer = current and current.layers and current.layers.highlight
        if layer then layer:Hide() end
    end)
end
'''
state = replace_once(state, old_layers, new_layers, 'state layers registry')

state = replace_once(
    state,
    '''local function EnsureSlotBG(btn)
    if not btn or btn.__fguiSlotBG then return end

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)
    bg:SetColorTexture(1, 1, 1, 0.02)
    bg:Hide()
    btn.__fguiSlotBG = bg
end
''',
    '''local function EnsureSlotBG(btn)
    local record = GetButtonRecord(btn, true)
    if not record or record.slotBackground then return end

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)
    bg:SetColorTexture(1, 1, 1, 0.02)
    bg:Hide()
    record.slotBackground = bg
end
''',
    'slot background registry',
)

old_empty = '''local function UpdateEmptySlot(btn)
    if not btn or not btn._fguiSkinned then return end
    if btn._fguiModule and btn._fguiModule._detached == true then return end
    EnsureSlotBG(btn)

    local holder = btn.GetParent and btn:GetParent() or nil
    local holderAutoHidden = (holder and holder._fguiAutoHidden == true) or false
    local empty = IsEmptySlot(btn)

    if not empty then
        if btn.__fguiSlotBG then btn.__fguiSlotBG:Hide() end
        btn:SetAlpha(1)
        SetMouseEnabledSafe(btn, not holderAutoHidden)
        return
    end

    if ShouldShowEmpty(btn) then
        if btn.__fguiSlotBG then btn.__fguiSlotBG:Show() end
        btn:SetAlpha(0.35)
        SetMouseEnabledSafe(btn, not holderAutoHidden)
        return
    end

    if btn.__fguiSlotBG then btn.__fguiSlotBG:Hide() end
    btn:SetAlpha(0)
    SetMouseEnabledSafe(btn, false)
end
'''
new_empty = '''local function UpdateEmptySlot(btn)
    local record = GetButtonRecord(btn, false)
    if not (btn and record and record.skinned) then return end
    if record.module and record.module._detached == true then return end
    EnsureSlotBG(btn)
    record = GetButtonRecord(btn, false)

    local holder = btn.GetParent and btn:GetParent() or nil
    local holderAutoHidden = (holder and holder._fguiAutoHidden == true) or false
    local empty = IsEmptySlot(btn)
    local background = record and record.slotBackground

    if not empty then
        if background then background:Hide() end
        btn:SetAlpha(1)
        SetMouseEnabledSafe(btn, not holderAutoHidden)
        return
    end

    if ShouldShowEmpty(btn) then
        if background then background:Show() end
        btn:SetAlpha(0.35)
        SetMouseEnabledSafe(btn, not holderAutoHidden)
        return
    end

    if background then background:Hide() end
    btn:SetAlpha(0)
    SetMouseEnabledSafe(btn, false)
end
'''
state = replace_once(state, old_empty, new_empty, 'empty-slot registry')

state = replace_once(
    state,
    '''local function UpdateButtonChecked(btn)
    if not (btn and btn.__fguiCK) then return end
    if btn._fguiModule and btn._fguiModule._detached == true then return end

    local checked = false
    if btn.GetChecked then
        local value = btn:GetChecked()
        checked = (value == true or value == 1)
    elseif btn.Checked and btn.Checked.IsShown then
        checked = (btn.Checked:IsShown() == true)
    end

    if checked then
        btn.__fguiCK:Show()
    else
        btn.__fguiCK:Hide()
    end
end
''',
    '''local function UpdateButtonChecked(btn)
    local record = GetButtonRecord(btn, false)
    local layer = record and record.layers and record.layers.checked
    if not (btn and layer) then return end
    if record.module and record.module._detached == true then return end

    local checked = false
    if btn.GetChecked then
        local value = btn:GetChecked()
        checked = (value == true or value == 1)
    elseif btn.Checked and btn.Checked.IsShown then
        checked = (btn.Checked:IsShown() == true)
    end

    if checked then layer:Show() else layer:Hide() end
end

State.UpdateButtonChecked = UpdateButtonChecked
State.UpdateButtonEmpty = UpdateEmptySlot
''',
    'checked-state registry',
)

state = replace_once(
    state,
    '''function State.InitializeButton(btn)
    if not btn or not btn._fguiSkinned then
        return
    end

    EnsureSlotBG(btn)
    EnsureStateLayers(btn)

    btn.__fguiUpdateChecked = UpdateButtonChecked
    btn.__fguiUpdateEmpty = UpdateEmptySlot

    UpdateButtonChecked(btn)
    UpdateEmptySlot(btn)
end
''',
    '''function State.InitializeButton(btn)
    local record = GetButtonRecord(btn, false)
    if not (btn and record and record.skinned) then return false end

    EnsureSlotBG(btn)
    EnsureStateLayers(btn)
    UpdateButtonChecked(btn)
    UpdateEmptySlot(btn)
    return true
end
''',
    'button initialization registry',
)

state = replace_once(
    state,
    '''function State.AttachButtonAutoHideHooks(btn, module)
    if not btn or btn._fguiAutoHideHooks then
        return
    end

    local owner = module or ns.ActionBars
    btn._fguiModule = owner
    btn._fguiAutoHideHooks = true
    btn:HookScript("OnEnter", function()
        State.QueueAutoHideUpdate(owner)
    end)
    btn:HookScript("OnLeave", function()
        State.QueueAutoHideUpdate(owner)
    end)
end
''',
    '''function State.AttachButtonAutoHideHooks(btn, module)
    local record = GetButtonRecord(btn, true)
    if not record then return false end

    local owner = module or ns.ActionBars
    record.module = owner
    if record.autoHideHooks then return true end

    record.autoHideHooks = true
    btn:HookScript("OnEnter", function()
        State.QueueAutoHideUpdate(owner)
    end)
    btn:HookScript("OnLeave", function()
        State.QueueAutoHideUpdate(owner)
    end)
    return true
end
''',
    'auto-hide hook registry',
)

state = replace_once(
    state,
    '''            if enabled then
                if btn.__fguiUpdateEmpty then
                    btn.__fguiUpdateEmpty(btn)
                else
                    SetMouseEnabledSafe(btn, true)
                end
            else
''',
    '''            if enabled then
                if State.IsManagedButton(btn) then
                    UpdateEmptySlot(btn)
                else
                    SetMouseEnabledSafe(btn, true)
                end
            else
''',
    'holder mouse registry',
)

state = replace_once(
    state,
    '''    if updateChecked and btn.__fguiUpdateChecked then
        btn.__fguiUpdateChecked(btn)
    end
    if updateEmpty and btn.__fguiUpdateEmpty then
        btn.__fguiUpdateEmpty(btn)
    end
end
''',
    '''    if updateChecked then UpdateButtonChecked(btn) end
    if updateEmpty then UpdateEmptySlot(btn) end
end
''',
    'visual sync registry',
)

state = replace_once(
    state,
    '''        hooksecurefunc(baseActionButtonMixin, "SetShowGrid", function(btn)
            if IsDetached(module) then return end
            if btn and btn.__fguiUpdateEmpty then
                btn.__fguiUpdateEmpty(btn)
            end
        end)
''',
    '''        hooksecurefunc(baseActionButtonMixin, "SetShowGrid", function(btn)
            if IsDetached(module) then return end
            UpdateEmptySlot(btn)
        end)
''',
    'grid hook registry',
)

state = replace_once(
    state,
    '''        hooksecurefunc(spellAlertManager, "ShowAlert", function(_, btn)
            if IsDetached(module) or not btn then return end
            if btn.__fguiPR then btn.__fguiPR:Show() end
            local overlay = btn.SpellActivationAlert or btn.overlay
''',
    '''        hooksecurefunc(spellAlertManager, "ShowAlert", function(_, btn)
            if IsDetached(module) or not btn then return end
            local record = GetButtonRecord(btn, false)
            local pressed = record and record.layers and record.layers.pressed
            if pressed then pressed:Show() end
            local overlay = btn.SpellActivationAlert or btn.overlay
''',
    'spell alert show registry',
)
state = replace_once(
    state,
    '''        hooksecurefunc(spellAlertManager, "HideAlert", function(_, btn)
            if IsDetached(module) then return end
            if btn and btn.__fguiPR then
                btn.__fguiPR:Hide()
            end
        end)
''',
    '''        hooksecurefunc(spellAlertManager, "HideAlert", function(_, btn)
            if IsDetached(module) then return end
            local record = GetButtonRecord(btn, false)
            local pressed = record and record.layers and record.layers.pressed
            if pressed then pressed:Hide() end
        end)
''',
    'spell alert hide registry',
)

state = replace_once(
    state,
    '''            ForEachHolderButton(holder, function(btn)
                if btn.__fguiUpdateEmpty then
                    btn.__fguiUpdateEmpty(btn)
                end
            end)
''',
    '''            ForEachHolderButton(holder, function(btn)
                UpdateEmptySlot(btn)
            end)
''',
    'empty-slot refresh registry',
)
state_path.write_text(state, encoding='utf-8')

visuals_path = Path('modules/ActionBarsVisuals.lua')
visuals = visuals_path.read_text(encoding='utf-8')
visuals = replace_once(
    visuals,
    'local InCombat = InCombatLockdown or function() return false end\n\n',
    '''local InCombat = InCombatLockdown or function() return false end

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

''',
    'visual region registry',
)

old_typography = '''function Visuals.ApplyButtonTypography(btn, style)
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
'''
new_typography = '''local function ApplyTypography(region, button, style, size, point, relativePoint, x, y, justify)
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
'''
visuals = replace_once(visuals, old_typography, new_typography, 'typography registry')

visuals = replace_once(
    visuals,
    '''local function GetCooldownTimerText(cooldownFrame)
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
''',
    '''local function GetCooldownTimerText(cooldownFrame)
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
''',
    'cooldown timer registry',
)

old_cooldown = '''function Visuals.StyleButtonCooldown(btn, style)
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
'''
new_cooldown = '''function Visuals.StyleButtonCooldown(btn, style)
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
'''
visuals = replace_once(visuals, old_cooldown, new_cooldown, 'cooldown registry')

visuals = replace_once(
    visuals,
    '''function Visuals.SkinButton(btn, style)
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
''',
    '''function Visuals.SkinButton(btn, style)
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

    if State and State.InitializeButton then State.InitializeButton(btn) end
    return true
end
''',
    'skin registry',
)

visuals = replace_once(
    visuals,
    '''function Visuals.SetButtonHotkey(btn, show)
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
''',
    '''function Visuals.SetButtonHotkey(btn, show)
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
''',
    'hotkey registry',
)

old_refresh = '''function Visuals.RefreshButtonVisualState(btn, style, showHotkeys)
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
'''
new_refresh = '''function Visuals.RefreshButtonVisualState(btn, style, showHotkeys)
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
    if State and State.InitializeButton then State.InitializeButton(btn) end
    if State and State.UpdateButtonChecked then State.UpdateButtonChecked(btn) end
    if State and State.UpdateButtonEmpty then State.UpdateButtonEmpty(btn) end
    return true
end
'''
visuals = replace_once(visuals, old_refresh, new_refresh, 'visual refresh registry')
visuals_path.write_text(visuals, encoding='utf-8')

runtime_path = Path('modules/ActionBarsRuntime.lua')
runtime = runtime_path.read_text(encoding='utf-8')
runtime = replace_once(
    runtime,
    '''        if button and button.__fguiUpdateChecked then
            button.__fguiUpdateChecked(button)
        end
        if button and button.__fguiUpdateEmpty then
            button.__fguiUpdateEmpty(button)
        end
''',
    '''        if State and State.UpdateButtonChecked then State.UpdateButtonChecked(button) end
        if State and State.UpdateButtonEmpty then State.UpdateButtonEmpty(button) end
''',
    'runtime button callback registry',
)
runtime_path.write_text(runtime, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
check = replace_once(
    check,
    "    assertSourceIncludes('modules/CompanionPetState.lua', 'function State:BeginButton');\n",
    "    assertSourceIncludes('modules/ActionBarsState.lua', 'State._buttonRegistry');\n"
    "    assertSourceIncludes('modules/ActionBarsState.lua', 'function State.GetButtonRecord');\n"
    "    assertSourceIncludes('modules/ActionBarsVisuals.lua', 'Visuals._regionRegistry');\n"
    "    assertSourceIncludes('modules/ActionBarsVisuals.lua', 'local function GetRegionRecord');\n"
    "    assertSourceExcludes('modules/ActionBarsState.lua', /btn\\.(?:__fgui|_fgui(?:Skinned|Module|AutoHideHooks))/, 'ActionButton runtime metadata');\n"
    "    assertSourceExcludes('modules/ActionBarsVisuals.lua', /(?:btn|hotkey|count|name|cooldown|timer)\\._fgui/, 'ActionButton visual metadata');\n"
    "    assertSourceExcludes('modules/ActionBarsRuntime.lua', /button\\.__fgui/, 'ActionButton callback metadata');\n\n"
    "    assertSourceIncludes('modules/CompanionPetState.lua', 'function State:BeginButton');\n",
    'ActionBars registry contracts',
)
check_path.write_text(check, encoding='utf-8')

# Release metadata and documentation.
toc_path = Path('FeelsGoodUI.toc')
toc = toc_path.read_text(encoding='utf-8')
toc = replace_once(toc, '## Version: 0.0.59', '## Version: 0.0.60', 'TOC version')
toc_path.write_text(toc, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(readme, '- FeelsGoodUI `0.0.59`', '- FeelsGoodUI `0.0.60`', 'README version')
readme = replace_once(
    readme,
    'ActionBars snapshots the complete native `GetActionBarToggles()` state before takeover and restores it exactly on detach;',
    'ActionBars keeps button layers, owner pointers, callbacks, styles, typography anchors, cooldown timer caches, and hotkey policy in weak-key owner registries rather than stamping `_fgui*` fields onto Blizzard ActionButton/FontString/Cooldown objects. It snapshots the complete native `GetActionBarToggles()` state before takeover and restores it exactly on detach;',
    'README ActionBars registry policy',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    '- Action bars: `modules/ActionBars.lua` owns secure holders and delegates state, visual, Blizzard shell, Edit Mode, and runtime updates to the `ActionBars*` files.',
    '- Action bars: `modules/ActionBars.lua` owns secure holders and delegates state, visual, Blizzard shell, Edit Mode, and runtime updates to the `ActionBars*` files. `ActionBarsState` and `ActionBarsVisuals` keep per-button and per-region metadata in weak-key registries; Blizzard buttons and regions receive no addon cache/callback fields.',
    'AGENT_GUIDE ActionBars registry owner',
)
agent_path.write_text(agent, encoding='utf-8')

index_path = Path('CODE_INDEX.md')
index = index_path.read_text(encoding='utf-8')
index = replace_once(
    index,
    '| `modules/ActionBars.lua`, `modules/ActionBarsRuntime.lua`, `modules/ActionBarsState.lua`, `modules/ActionBarsVisuals.lua`, `modules/ActionBarsEditMode.lua` | Secure holders, event/lifecycle coordination, state, visuals, and mover integration without direct profile mutation. |',
    '| `modules/ActionBars.lua`, `modules/ActionBarsRuntime.lua`, `modules/ActionBarsEditMode.lua` | Secure holders, event/lifecycle coordination, and mover integration without direct profile mutation. |\n| `modules/ActionBarsState.lua`, `modules/ActionBarsVisuals.lua` | Weak-key ActionButton/region runtime registries, custom state layers, typography/cooldown caches, empty-slot and hotkey presentation. |',
    'CODE_INDEX ActionBars registries',
)
index_path.write_text(index, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(todo, '- [x] Target Interface `120105` and release `0.0.59`.', '- [x] Target Interface `120105` and release `0.0.60`.', 'TODO version')
todo = replace_once(
    todo,
    '- [x] Journal PetActionButton takeover in `CompanionPetState`: separate structural layout from dynamic visibility ownership, reopen snapshots on component replacement, journal mover preview, refuse unreadable mutable components, and restore exact still-owned texture/text/cooldown/native-bar-alpha state.\n',
    '- [x] Journal PetActionButton takeover in `CompanionPetState`: separate structural layout from dynamic visibility ownership, reopen snapshots on component replacement, journal mover preview, refuse unreadable mutable components, and restore exact still-owned texture/text/cooldown/native-bar-alpha state.\n'
    '- [x] Move ActionBars runtime metadata off Blizzard ActionButton/FontString/Cooldown objects into weak-key button/region registries; hooks resolve current owner/layers through the registry and no callback/style cache is stored on foreign frames.\n',
    'TODO ActionBars registry status',
)
todo = replace_once(
    todo,
    '- [ ] Disable ActionBars both out of combat and during combat; after combat, Blizzard shell is restored once and no stale delayed hide/apply callback reclaims it.\n',
    '- [ ] Disable ActionBars both out of combat and during combat; after combat, Blizzard shell is restored once and no stale delayed hide/apply callback reclaims it.\n'
    '- [ ] Repeatedly skin, refresh, detach and re-enable all five ActionBars; custom layers, typography and cooldown caches are reused through weak-key registries, Blizzard buttons/regions contain no `_fgui*` metadata, and permanent hooks become inert while detached.\n',
    'TODO ActionBars registry validation',
)
todo_path.write_text(todo, encoding='utf-8')

matrix_path = Path('docs/REGRESSION_MATRIX_1_25.md')
matrix = matrix_path.read_text(encoding='utf-8')
matrix = replace_once(
    matrix,
    '| 19 | Configure action bars out of combat | Geometry, visibility, bindings, and Blizzard shell handoff apply once |  |  |',
    '| 19 | Configure and repeatedly refresh action bars out of combat | Geometry/visibility/bindings apply once; custom layers and typography caches are reused from weak registries; Blizzard buttons/regions receive no `_fgui*` metadata |  |  |',
    'regression matrix ActionBars registries',
)
matrix_path.write_text(matrix, encoding='utf-8')

print('Moved ActionBars button and region runtime metadata into weak registries.')
