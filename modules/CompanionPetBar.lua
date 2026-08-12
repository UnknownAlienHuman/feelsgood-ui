-- FeelsGoodUI: companion pet bar ownership layer

local _, ns = ...

local PetBar = {}
ns.CompanionPetBar = PetBar

local Media = ns.Media
local Movers = ns.Movers
local Theme = ns.Theme
local Shared = ns.CompanionShared

local PET_VISIBILITY_DRIVER = "[petbattle][overridebar][vehicleui][possessbar,@vehicle,exists] hide; [@pet,exists] show; hide"

local function CreatePetBarMoverSpec()
    return {
        label = "PetBar",
        applyKeys = "companion",
        positionKey = Shared.PET_KEY,
        getSize = function()
            local cp = Shared:GetCompanionCfg(nil)
            local size = Shared:ClampButtonSize(cp.buttonSize)
            return size, size
        end,
        setSize = function(width, height)
            local rw = tonumber(width) or 32
            local rh = tonumber(height)
            if type(rh) ~= "number" then
                rh = rw
            end

            local cp = Shared:GetCompanionCfg(nil)
            cp.buttonSize = Shared:ClampButtonSize((rw + rh) * 0.5)
        end,
        onWheel = function(delta, shiftDown)
            local cp = Shared:GetCompanionCfg(nil)
            if shiftDown then
                cp.spacing = Shared:ClampSpacing((tonumber(cp.spacing) or 0) + delta)
            else
                cp.buttonSize = Shared:ClampButtonSize((tonumber(cp.buttonSize) or 32) + delta)
            end
            return true
        end,
    }
end

local function ApplyPetAnchorVisibility(frame)
    if not frame then
        return
    end

    if type(_G.UnregisterStateDriver) == "function" then
        pcall(_G.UnregisterStateDriver, frame, "visibility")
    end

    if type(_G.RegisterStateDriver) == "function" then
        _G.RegisterStateDriver(frame, "visibility", PET_VISIBILITY_DRIVER)
    end
end

local function EnsurePetAnchor(module)
    if module._petAnchor then
        ApplyPetAnchorVisibility(module._petAnchor)
        return module._petAnchor
    end

    local frame = CreateFrame("Frame", "FGUI_oUF_PetBarHolder", UIParent, "SecureHandlerStateTemplate")
    frame:SetSize(320, 32)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
    frame:Show()
    module._petAnchor = frame

    if Movers and Movers.Register then
        Movers:Register(Shared.PET_KEY, frame, CreatePetBarMoverSpec())
        Movers:Apply(Shared.PET_KEY, frame)
    end

    ApplyPetAnchorVisibility(frame)

    return frame
end

local function GetPetButtonIcon(button)
    if not button then return nil end
    if button.icon then return button.icon end
    if button.Icon and button.Icon.GetObjectType and button.Icon:GetObjectType() == "Texture" then
        return button.Icon
    end
    if button.GetName then
        local name = button:GetName()
        if name then
            return _G[name .. "Icon"]
        end
    end
    return nil
end

local function StylePetButton(button, size, showHotkeys, profile)
    if not button then return end

    button:SetSize(size, size)
    if button.SetHitRectInsets then
        button:SetHitRectInsets(0, 0, 0, 0)
    end

    local icon = GetPetButtonIcon(button)
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        Media:ApplyIconCrop(icon, Shared.PET_ICON_CROP)
    end

    local normal = button.GetNormalTexture and button:GetNormalTexture() or nil
    local pushed = button.GetPushedTexture and button:GetPushedTexture() or nil
    local checked = button.GetCheckedTexture and button:GetCheckedTexture() or nil
    local highlight = button.GetHighlightTexture and button:GetHighlightTexture() or nil
    if normal and normal.SetAlpha then normal:SetAlpha(0) end
    if pushed and pushed.SetAlpha then pushed:SetAlpha(0) end
    if checked and checked.SetAlpha then checked:SetAlpha(0) end
    if highlight then
        highlight:SetAlpha(0.20)
        pcall(highlight.SetAllPoints, highlight, button)
    end

    if button.SlotBackground then button.SlotBackground:SetAlpha(0) end
    if button.SlotArt then button.SlotArt:SetAlpha(0) end
    if button.Border then button.Border:SetAlpha(0) end
    if button.NewActionTexture then button.NewActionTexture:SetAlpha(0) end
    if button.SpellHighlightTexture then button.SpellHighlightTexture:SetAlpha(0) end
    if button.IconMask then button.IconMask:Hide() end
    if button.Name then
        button.Name:SetText("")
        button.Name:Hide()
    end

    if button.cooldown then
        button.cooldown:ClearAllPoints()
        button.cooldown:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button.cooldown:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    end

    local theme = Theme and Theme.Get and Theme:Get() or nil
    local style = Shared:GetConfigSection(profile, "style") or {}
    local borderSize = ((theme and theme.style and theme.style.borderSize) or style.borderSize or 1)
    Media:CreateBorder(button, borderSize)

    local hotkey = button.HotKey
    if not hotkey and button.GetName then
        local name = button:GetName()
        if name then
            hotkey = _G[name .. "HotKey"]
        end
    end
    if hotkey then
        if showHotkeys then
            hotkey:SetAlpha(1)
            hotkey:Show()
        else
            hotkey:SetAlpha(0)
            hotkey:Hide()
        end
    end
end

local function ResetPetButtonParent(button)
    if not button then
        return false
    end

    -- Blizzard pet bars lay out buttons through per-button containers.
    local defaultParent = button.container
    if not defaultParent and _G.PetActionBar and type(button.index) == "number" then
        local actionButtons = _G.PetActionBar.actionButtons
        local defaultButton = type(actionButtons) == "table" and actionButtons[button.index] or nil
        defaultParent = defaultButton and defaultButton.container or nil
    end
    if not defaultParent then
        return false
    end

    button:SetParent(defaultParent)
    button:ClearAllPoints()
    button:SetPoint("CENTER")

    local width = defaultParent.GetWidth and defaultParent:GetWidth() or nil
    local height = defaultParent.GetHeight and defaultParent:GetHeight() or nil
    if type(width) == "number" and type(height) == "number" and button.SetSize then
        button:SetSize(width, height)
    end

    return true
end

local function RestoreTextureAlpha(texture)
    if texture and texture.SetAlpha then
        texture:SetAlpha(1)
    end
end

local function RestorePetButton(button)
    if not button then
        return
    end

    ResetPetButtonParent(button)

    local icon = GetPetButtonIcon(button)
    if icon then
        icon:ClearAllPoints()
        icon:SetAllPoints(button)
        if icon.SetTexCoord then
            icon:SetTexCoord(0, 1, 0, 1)
        end
    end

    RestoreTextureAlpha(button.GetNormalTexture and button:GetNormalTexture() or nil)
    RestoreTextureAlpha(button.GetPushedTexture and button:GetPushedTexture() or nil)
    RestoreTextureAlpha(button.GetCheckedTexture and button:GetCheckedTexture() or nil)
    RestoreTextureAlpha(button.GetHighlightTexture and button:GetHighlightTexture() or nil)
    RestoreTextureAlpha(button.SlotBackground)
    RestoreTextureAlpha(button.SlotArt)
    RestoreTextureAlpha(button.Border)
    RestoreTextureAlpha(button.NewActionTexture)
    RestoreTextureAlpha(button.SpellHighlightTexture)

    if button.IconMask and button.IconMask.Show then
        button.IconMask:Show()
    end

    if button.cooldown and button.cooldown.SetAllPoints then
        button.cooldown:ClearAllPoints()
        button.cooldown:SetAllPoints(button)
    end

    if button.SetHotkeys then
        pcall(button.SetHotkeys, button)
    end

    local hotkey = button.HotKey
    if hotkey then
        hotkey:SetAlpha(1)
        hotkey:Show()
    end

    if button.__fguiBorder and button.__fguiBorder.SetBackdropBorderColor then
        button.__fguiBorder:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

local function RefreshBlizzardPetBar()
    local petBar = _G.PetActionBar
    if not petBar then
        return
    end

    if petBar.SetAlpha then
        pcall(petBar.SetAlpha, petBar, 1)
    end

    if petBar.UpdateShownButtons then
        petBar:UpdateShownButtons()
    end

    if petBar.MarkGridLayoutDirty then
        petBar:MarkGridLayoutDirty()
    end
    if petBar.RefreshGridLayout then
        petBar:RefreshGridLayout()
    elseif petBar.UpdateGridLayout then
        petBar:UpdateGridLayout()
    end

    if petBar.RefreshBarArt then
        petBar:RefreshBarArt(true)
    elseif petBar.SetBackgroundArtShown and petBar.ShouldShowBackgroundArt then
        petBar:SetBackgroundArtShown(petBar:ShouldShowBackgroundArt())
    end

    if petBar.Update then
        petBar:Update()
    end

    if petBar.UpdateVisibility then
        petBar:UpdateVisibility()
    elseif petBar.Show then
        petBar:Show()
    end
end

function PetBar:Apply(module, cp, profile)
    if not (module and cp) then return end
    if Shared:IsInCombat() then
        module._pendingAfterCombat = true
        return
    end

    local holder = EnsurePetAnchor(module)
    if not holder then return end

    holder:Show()
    Shared:ApplyFrameLayer(holder, cp.petBar.strata, cp.petBar.level)

    local size = cp.buttonSize or 32
    local spacing = cp.spacing or 0
    local width = (Shared.PET_BUTTONS * size) + ((Shared.PET_BUTTONS - 1) * spacing)
    holder:SetSize(width, size)

    if _G.PetActionBar then
        pcall(_G.PetActionBar.SetAlpha, _G.PetActionBar, 0)
    end

    local allReady = true
    for i = 1, Shared.PET_BUTTONS do
        local button = _G["PetActionButton" .. i]
        if not button then
            allReady = false
        else
            button:SetParent(holder)
            button:ClearAllPoints()
            button:SetPoint("LEFT", holder, "LEFT", (i - 1) * (size + spacing), 0)
            StylePetButton(button, size, cp.petBar.showHotkeys == true, profile)
            button:Show()
        end
    end

    if not allReady then
        module._pendingAfterCombat = true
    end
end

function PetBar:RestoreDefaultLayout(module)
    if not module then
        return false
    end

    local holder = module._petAnchor
    if holder and type(_G.UnregisterStateDriver) == "function" then
        pcall(_G.UnregisterStateDriver, holder, "visibility")
    end

    for i = 1, Shared.PET_BUTTONS do
        RestorePetButton(_G["PetActionButton" .. i])
    end

    RefreshBlizzardPetBar()

    if holder and holder.Hide then
        holder:Hide()
    end

    return true
end

return PetBar
