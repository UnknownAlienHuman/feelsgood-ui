-- FeelsGoodUI: companion pet bar ownership layer

local _, ns = ...

local PetBar = {}
ns.CompanionPetBar = PetBar

local Media = ns.Media
local Movers = ns.Movers
local Theme = ns.Theme
local Shared = ns.CompanionShared
local PetState = ns.CompanionPetState

assert(PetState, "FeelsGoodUI: CompanionPetState not loaded")

local PET_VISIBILITY_DRIVER = "[petbattle][overridebar][vehicleui][possessbar,@vehicle,exists] hide; [@pet,exists] show; hide"

local PreviewPetLayout

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
        buildSizeWrites = function(width, height)
            local rw = tonumber(width) or 32
            local rh = tonumber(height)
            if type(rh) ~= "number" then rh = rw end
            return {
                path = { "companion", "buttonSize" },
                value = Shared:ClampButtonSize((rw + rh) * 0.5),
                rule = { type = "int", min = 24, max = 60, fallback = 32 },
            }
        end,
        previewSize = function(_, width, height)
            local rw = tonumber(width) or 32
            local rh = tonumber(height)
            if type(rh) ~= "number" then rh = rw end
            local cp = Shared:GetCompanionCfg(nil)
            local size = Shared:ClampButtonSize((rw + rh) * 0.5)
            local ok, detail = PreviewPetLayout(ns.Companion, size, Shared:ClampSpacing(cp.spacing))
            if ok == false then return false, detail end
            return size, size
        end,
        buildWheelWrites = function(delta, shiftDown)
            local cp = Shared:GetCompanionCfg(nil)
            if shiftDown then
                return {
                    path = { "companion", "spacing" },
                    value = Shared:ClampSpacing((tonumber(cp.spacing) or 0) + delta),
                    rule = { type = "int", min = 0, max = 12, fallback = 0 },
                }
            end

            return {
                path = { "companion", "buttonSize" },
                value = Shared:ClampButtonSize((tonumber(cp.buttonSize) or 32) + delta),
                rule = { type = "int", min = 24, max = 60, fallback = 32 },
            }
        end,
        previewWheel = function(_, delta, shiftDown)
            local cp = Shared:GetCompanionCfg(nil)
            local size = Shared:ClampButtonSize(cp.buttonSize)
            local spacing = Shared:ClampSpacing(cp.spacing)
            if shiftDown then spacing = Shared:ClampSpacing(spacing + delta)
            else size = Shared:ClampButtonSize(size + delta) end
            local ok, detail = PreviewPetLayout(ns.Companion, size, spacing)
            if ok == false then return false, detail end
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
    local frame = module._petAnchor
    if not frame then
        frame = CreateFrame("Frame", "FGUI_oUF_PetBarHolder", UIParent, "SecureHandlerStateTemplate")
        frame:SetSize(320, 32)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
        frame:Show()
        module._petAnchor = frame
    end

    if not (Movers and type(Movers.Register) == "function" and type(Movers.Apply) == "function") then
        return nil, "Companion pet mover registry unavailable"
    end
    local registered, registerDetail = Movers:Register(Shared.PET_KEY, frame, CreatePetBarMoverSpec())
    if registered == false then
        return nil, "Companion pet mover registration failed: " .. tostring(registerDetail)
    end
    local applied, applyDetail = Movers:Apply(Shared.PET_KEY, frame)
    if applied == false then
        return nil, "Companion pet mover apply failed: " .. tostring(applyDetail)
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

local function ReleasePetButtonStyle(button)
    if Media and type(Media.SetBorderColor) == "function" then
        Media:SetBorderColor(button, 0, 0, 0, 0)
    end
end

local function BuildPetButtonComponents(button)
    local hotkey = button and button.HotKey or nil
    if not hotkey and button and button.GetName then
        local name = button:GetName()
        if name then hotkey = _G[name .. "HotKey"] end
    end

    return {
        release = ReleasePetButtonStyle,
        icon = GetPetButtonIcon(button),
        highlight = button and button.GetHighlightTexture and button:GetHighlightTexture() or nil,
        cooldown = button and button.cooldown or nil,
        iconMask = button and button.IconMask or nil,
        name = button and button.Name or nil,
        hotkey = hotkey,
        alphas = {
            normal = button and button.GetNormalTexture and button:GetNormalTexture() or nil,
            pushed = button and button.GetPushedTexture and button:GetPushedTexture() or nil,
            checked = button and button.GetCheckedTexture and button:GetCheckedTexture() or nil,
            slotBackground = button and button.SlotBackground or nil,
            slotArt = button and button.SlotArt or nil,
            border = button and button.Border or nil,
            newAction = button and button.NewActionTexture or nil,
            spellHighlight = button and button.SpellHighlightTexture or nil,
        },
    }
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

PreviewPetLayout = function(module, size, spacing)
    if not module then
        return false, "Companion preview owner unavailable"
    end
    if Shared:IsInCombat() then
        return false, "Companion preview blocked in combat"
    end

    local holder, holderDetail = EnsurePetAnchor(module)
    if not holder then
        return false, holderDetail or "Pet bar holder unavailable"
    end

    local pending = {}
    for i = 1, Shared.PET_BUTTONS do
        local button = _G["PetActionButton" .. i]
        if button then
            local components = BuildPetButtonComponents(button)
            local captured, detail = PetState:BeginButton(module, i, button, components)
            if captured ~= true then
                return false, detail or "Pet action button preview capture failed"
            end
            pending[#pending + 1] = {
                index = i,
                button = button,
                components = components,
            }
        else
            PetState:ReleaseButton(module, i)
        end
    end

    holder:SetSize((Shared.PET_BUTTONS * size) + ((Shared.PET_BUTTONS - 1) * spacing), size)
    for i = 1, #pending do
        local entry = pending[i]
        local button = entry.button
        button:SetParent(holder)
        button:ClearAllPoints()
        button:SetPoint("LEFT", holder, "LEFT", (entry.index - 1) * (size + spacing), 0)
        button:SetSize(size, size)

        local finished, detail = PetState:FinishButton(
            module,
            entry.index,
            button,
            entry.components
        )
        if finished ~= true then
            return false, detail or "Managed pet action button preview capture failed"
        end
    end
    return true
end

local function RefreshBlizzardPetBar()
    local petBar = _G.PetActionBar
    if not petBar then return end

    local function Call(name, ...)
        local method = petBar[name]
        if type(method) == "function" then
            pcall(method, petBar, ...)
        end
    end

    Call("UpdateShownButtons")
    Call("MarkGridLayoutDirty")
    if type(petBar.RefreshGridLayout) == "function" then
        Call("RefreshGridLayout")
    else
        Call("UpdateGridLayout")
    end

    if type(petBar.RefreshBarArt) == "function" then
        Call("RefreshBarArt", true)
    elseif type(petBar.SetBackgroundArtShown) == "function"
        and type(petBar.ShouldShowBackgroundArt) == "function" then
        local ok, shown = pcall(petBar.ShouldShowBackgroundArt, petBar)
        if ok then Call("SetBackgroundArtShown", shown) end
    end

    Call("Update")
    Call("UpdateVisibility")
end

function PetBar:Apply(module, cp, profile)
    if not (module and cp) then return false, "Companion pet-bar apply owner unavailable" end
    if Shared:IsInCombat() then
        module._pendingAfterCombat = true
        return false, "Companion pet-bar apply deferred in combat"
    end

    local holder, holderDetail = EnsurePetAnchor(module)
    if not holder then return false, holderDetail or "Companion pet-bar holder unavailable" end

    local nativeOK, nativeDetail = PetState:SuppressNativeBar(module, _G.PetActionBar)
    if nativeOK ~= true then
        return false, nativeDetail or "Native pet bar could not be suppressed reversibly"
    end

    holder:Show()
    Shared:ApplyFrameLayer(holder, cp.petBar.strata, cp.petBar.level)

    local size = cp.buttonSize or 32
    local spacing = cp.spacing or 0
    local width = (Shared.PET_BUTTONS * size) + ((Shared.PET_BUTTONS - 1) * spacing)
    holder:SetSize(width, size)

    local allReady = true
    for i = 1, Shared.PET_BUTTONS do
        local button = _G["PetActionButton" .. i]
        if not button then
            PetState:ReleaseButton(module, i)
            allReady = false
        else
            local components = BuildPetButtonComponents(button)
            local captured, captureDetail = PetState:BeginButton(module, i, button, components)
            if captured ~= true then
                PetState:RestoreAll(module)
                holder:Hide()
                return false, captureDetail or "Pet action button state capture failed"
            end

            button:SetParent(holder)
            button:ClearAllPoints()
            button:SetPoint("LEFT", holder, "LEFT", (i - 1) * (size + spacing), 0)
            StylePetButton(button, size, cp.petBar.showHotkeys == true, profile)
            button:Show()

            local finished, finishDetail = PetState:FinishButton(module, i, button, components)
            if finished ~= true then
                PetState:RestoreAll(module)
                holder:Hide()
                return false, finishDetail or "Managed pet action button state capture failed"
            end
        end
    end

    if not allReady then
        module._pendingPetButtons = true
        module._pendingAfterCombat = true
        return true, "Pet action buttons pending runtime creation"
    end

    module._pendingPetButtons = nil
    module._pendingAfterCombat = nil
    return true
end

function PetBar:RestoreDefaultLayout(module)
    if not module then return false end

    local holder = module._petAnchor
    if holder and type(_G.UnregisterStateDriver) == "function" then
        pcall(_G.UnregisterStateDriver, holder, "visibility")
    end

    PetState:RestoreAll(module)
    RefreshBlizzardPetBar()

    if holder and holder.Hide then holder:Hide() end
    module._pendingPetButtons = nil
    return true
end

return PetBar
