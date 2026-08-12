-- FeelsGoodUI: companion micro menu and bags ownership layer

local _, ns = ...

local MicroBags = {}
ns.CompanionMicroBags = MicroBags

local Media = ns.Media
local Movers = ns.Movers
local Safety = ns.Safety
local Theme = ns.Theme
local Shared = ns.CompanionShared

local MICRO_LAYOUT_RETRY_KEY = "FGUI_COMPANION_MICRO_LAYOUT"
local MICRO_LAYOUT_RETRY_DELAY = 0.05

local function IsManagedModuleActive(module)
    return module
        and module._applyingMicroLayout ~= true
        and module._detached ~= true
        and module._eventsAttached == true
end

local function CancelRetryTimer()
    if not (Safety and Safety._timers) then
        return
    end

    local timer = Safety._timers[MICRO_LAYOUT_RETRY_KEY]
    if type(timer) == "table" and type(timer.Cancel) == "function" then
        pcall(timer.Cancel, timer)
    end
    Safety._timers[MICRO_LAYOUT_RETRY_KEY] = nil
end

local function CreateMicroMenuMoverSpec()
    return {
        label = "Micro Menu",
        applyKeys = "companion",
        positionKey = Shared.MICRO_KEY,
    }
end

local function EnsureMicroAnchor(module)
    if module._microAnchor then return module._microAnchor end

    local frame = CreateFrame("Frame", "FGUI_oUF_MicroMenuHolder", UIParent)
    frame:SetSize(360, 40)
    frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 4)
    frame:Show()
    module._microAnchor = frame

    if Movers and Movers.Register then
        Movers:Register(Shared.MICRO_KEY, frame, CreateMicroMenuMoverSpec())
        Movers:Apply(Shared.MICRO_KEY, frame)
    end

    return frame
end

local function ResolveMicroFrame()
    return _G.MicroButtonAndBagsBar or _G.MicroMenuContainer or _G.MicroMenu
end

local function GetMicroButtons()
    local out = {}

    local names = _G.MICRO_BUTTONS
    if type(names) == "table" then
        for i = 1, #names do
            local button = _G[names[i]]
            if button then
                out[#out + 1] = button
            end
        end
    end

    if #out == 0 and _G.MicroMenu and _G.MicroMenu.GetChildren then
        local children = { _G.MicroMenu:GetChildren() }
        for i = 1, #children do
            local child = children[i]
            if child and child.layoutIndex then
                out[#out + 1] = child
            end
        end
        table.sort(out, function(a, b)
            return (a.layoutIndex or 0) < (b.layoutIndex or 0)
        end)
    end

    return out
end

local function GetBagButtons()
    local out = {}

    if _G.MainMenuBarBagManager and type(_G.MainMenuBarBagManager.EnumerateBagButtons) == "function" then
        for _, bagButton in _G.MainMenuBarBagManager:EnumerateBagButtons() do
            out[#out + 1] = bagButton
        end
        return out
    end

    if _G.MainMenuBarBackpackButton then
        out[#out + 1] = _G.MainMenuBarBackpackButton
    end
    for i = 0, 4 do
        local button = _G["CharacterBag" .. i .. "Slot"]
        if button then
            out[#out + 1] = button
        end
    end
    if _G.CharacterReagentBag0Slot then
        out[#out + 1] = _G.CharacterReagentBag0Slot
    end

    return out
end

local function ShouldRepairManagedMicroMenu(module)
    if not IsManagedModuleActive(module) then
        return false
    end

    local cp = Shared:GetCompanionCfg(nil)
    if not Shared:ShouldManageMicroMenu(cp) then
        return false
    end

    local microMenu = _G.MicroMenu
    if type(microMenu) ~= "table" then
        return true
    end

    local anchor = module._microAnchor
    if not anchor then
        return true
    end

    if type(microMenu.GetParent) ~= "function" then
        return true
    end

    local ok, parent = pcall(microMenu.GetParent, microMenu)
    if not ok then
        return true
    end

    return parent ~= anchor
end

local function RequestManagedMicroRefresh()
    local module = ns.Companion
    if not IsManagedModuleActive(module) then
        return
    end

    local cp = Shared:GetCompanionCfg(nil)
    if not Shared:ShouldManageMicroMenu(cp) then
        return
    end

    local function Run()
        local activeModule = ns.Companion or module
        if not IsManagedModuleActive(activeModule) then
            return
        end

        local activeCfg = Shared:GetCompanionCfg(nil)
        if not Shared:ShouldManageMicroMenu(activeCfg) then
            return
        end

        activeModule:RequestApply()
    end

    if Safety and Safety.Debounce and Safety.Debounce(MICRO_LAYOUT_RETRY_KEY, 0, Run) then
        return
    end

    Run()
end

local function HookMicroSourceWidgets(module)
    if not module then return end

    local microMenu = _G.MicroMenu
    if microMenu and not microMenu._fguiCompanionHooked and type(microMenu.HookScript) == "function" then
        microMenu._fguiCompanionHooked = true
        microMenu:HookScript("OnShow", RequestManagedMicroRefresh)
        microMenu:HookScript("OnHide", RequestManagedMicroRefresh)
    end

    local microButtons = GetMicroButtons()
    for i = 1, #microButtons do
        local button = microButtons[i]
        if button and not button._fguiCompanionHooked and type(button.HookScript) == "function" then
            button._fguiCompanionHooked = true
            button:HookScript("OnShow", RequestManagedMicroRefresh)
            button:HookScript("OnHide", RequestManagedMicroRefresh)
        end
    end
end

local function StyleMicroButton(button, size)
    if not button then return end

    button:SetSize(size, size)
    if button.SetHitRectInsets then
        button:SetHitRectInsets(0, 0, 0, 0)
    end

    if button.Background then
        button.Background:SetAlpha(0)
        button.Background:Hide()
    end
    if button.PushedBackground then
        button.PushedBackground:SetAlpha(0)
        button.PushedBackground:Hide()
    end

    local function SkinTexture(texture, alpha)
        if not texture then return end
        pcall(texture.SetAllPoints, texture, button)
        if texture.SetTexCoord then
            Media:ApplyIconCrop(texture, Shared.MICRO_ICON_CROP)
        end
        if alpha ~= nil and texture.SetAlpha then
            texture:SetAlpha(alpha)
        end
    end

    local normal = button.GetNormalTexture and button:GetNormalTexture() or nil
    local pushed = button.GetPushedTexture and button:GetPushedTexture() or nil
    local disabled = button.GetDisabledTexture and button:GetDisabledTexture() or nil
    local highlight = button.GetHighlightTexture and button:GetHighlightTexture() or nil

    SkinTexture(normal, 1)
    SkinTexture(pushed, 1)
    SkinTexture(disabled, 0.70)
    SkinTexture(highlight, 0.20)
    if highlight and highlight.SetBlendMode then
        highlight:SetBlendMode("ADD")
    end

    if button.Portrait then
        pcall(button.Portrait.SetAllPoints, button.Portrait, button)
        if button.Portrait.SetTexCoord then
            Media:ApplyIconCrop(button.Portrait, Shared.MICRO_ICON_CROP)
        end
    end
    if button.PortraitMask then
        button.PortraitMask:Hide()
    end

    if button.FlashBorder then
        pcall(button.FlashBorder.SetAllPoints, button.FlashBorder, button)
        if button.FlashBorder.SetTexCoord then
            Media:ApplyIconCrop(button.FlashBorder, Shared.MICRO_ICON_CROP)
        end
    end
    if button.FlashContent then
        pcall(button.FlashContent.SetAllPoints, button.FlashContent, button)
        if button.FlashContent.SetTexCoord then
            Media:ApplyIconCrop(button.FlashContent, Shared.MICRO_ICON_CROP)
        end
    end
end

local function GetBagButtonIcon(button)
    if not button then return nil end
    if button.icon then return button.icon end
    if button.Icon and button.Icon.GetObjectType and button.Icon:GetObjectType() == "Texture" then
        return button.Icon
    end
    if button.GetName then
        local name = button:GetName()
        if name then
            return _G[name .. "IconTexture"]
        end
    end
    return nil
end

local function IsBackpackButton(button)
    if not button then return false end
    if type(button.IsBackpack) == "function" then
        local ok, isBackpack = pcall(button.IsBackpack, button)
        if ok and isBackpack == true then
            return true
        end
    end
    local name = button.GetName and button:GetName() or nil
    return (type(name) == "string" and name:find("Backpack", 1, true) ~= nil) or false
end

local function StyleBagButton(button, size)
    if not button then return end

    button:SetSize(size, size)
    if button.SetHitRectInsets then
        button:SetHitRectInsets(0, 0, 0, 0)
    end

    local normal = button.GetNormalTexture and button:GetNormalTexture() or nil
    local pushed = button.GetPushedTexture and button:GetPushedTexture() or nil
    local disabled = button.GetDisabledTexture and button:GetDisabledTexture() or nil
    local highlight = button.GetHighlightTexture and button:GetHighlightTexture() or nil

    if normal and normal.SetAlpha then normal:SetAlpha(0) end
    if pushed and pushed.SetAlpha then pushed:SetAlpha(0) end
    if disabled and disabled.SetAlpha then disabled:SetAlpha(0.55) end
    if highlight then
        if highlight.SetColorTexture then
            highlight:SetColorTexture(1, 1, 1, 0.20)
        end
        pcall(highlight.SetAllPoints, highlight, button)
    end
    if button.SlotHighlightTexture then
        button.SlotHighlightTexture:SetAlpha(0)
    end

    if button.Background then
        button.Background:SetAlpha(0)
        button.Background:Hide()
    end
    if button.PushedBackground then
        button.PushedBackground:SetAlpha(0)
        button.PushedBackground:Hide()
    end
    if button.IconBorder then button.IconBorder:SetAlpha(0) end
    if button.IconOverlay then button.IconOverlay:SetAlpha(0) end
    if button.CircleMask then button.CircleMask:Hide() end

    local icon = GetBagButtonIcon(button)
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        Media:ApplyIconCrop(icon, Shared.MICRO_ICON_CROP)
    end

    if button.Count then
        button.Count:ClearAllPoints()
        button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    end
end

local function StyleBackpackButton(button, size)
    if not button then return end

    button:SetSize(size, size)
    if button.SetHitRectInsets then
        button:SetHitRectInsets(0, 0, 0, 0)
    end

    if type(button.UpdateTextures) == "function" then
        pcall(button.UpdateTextures, button)
    end

    local normal = button.GetNormalTexture and button:GetNormalTexture() or nil
    local pushed = button.GetPushedTexture and button:GetPushedTexture() or nil
    local disabled = button.GetDisabledTexture and button:GetDisabledTexture() or nil
    local highlight = button.GetHighlightTexture and button:GetHighlightTexture() or nil

    if normal then
        pcall(normal.SetAllPoints, normal, button)
        if normal.SetAlpha then normal:SetAlpha(1) end
    end
    if pushed then
        pcall(pushed.SetAllPoints, pushed, button)
        if pushed.SetAlpha then pushed:SetAlpha(1) end
    end
    if disabled and disabled.SetAlpha then
        disabled:SetAlpha(0.70)
    end
    if highlight then
        pcall(highlight.SetAllPoints, highlight, button)
        if highlight.SetBlendMode then
            highlight:SetBlendMode("ADD")
        end
        highlight:SetAlpha(0.25)
    end

    if button.Background then
        button.Background:SetAlpha(0)
        button.Background:Hide()
    end
    if button.PushedBackground then
        button.PushedBackground:SetAlpha(0)
        button.PushedBackground:Hide()
    end
    if button.IconBorder then button.IconBorder:SetAlpha(0) end
    if button.IconOverlay then button.IconOverlay:SetAlpha(0) end
    if button.CircleMask then button.CircleMask:Hide() end
    if button.SlotHighlightTexture then button.SlotHighlightTexture:SetAlpha(0) end

    local icon = GetBagButtonIcon(button)
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        Media:ApplyIconCrop(icon, Shared.MICRO_ICON_CROP)
    end
end

local function SetBagCountShown(button, shown)
    if not button then return end

    if type(button.SetCountShown) == "function" then
        pcall(button.SetCountShown, button, shown == true)
    elseif button.Count then
        if shown then
            button.Count:Show()
        else
            button.Count:SetText("")
            button.Count:Hide()
        end
    end
end

local function GetCompactBackpackButton(bagButtons)
    if _G.MainMenuBarBackpackButton then
        return _G.MainMenuBarBackpackButton
    end

    local buttons = bagButtons or GetBagButtons()
    for i = 1, #buttons do
        local button = buttons[i]
        if IsBackpackButton(button) then
            return button
        end
    end
    return buttons[1]
end

local function GetBagSlotsSummary()
    local api = _G.C_Container
    if not (api and api.GetContainerNumSlots and api.GetContainerNumFreeSlots) then
        return nil, nil
    end

    local maxBag = tonumber(_G.NUM_TOTAL_BAG_FRAMES) or tonumber(_G.NUM_TOTAL_EQUIPPED_BAG_SLOTS) or 5
    if maxBag < 1 then
        maxBag = 5
    end

    local total, free = 0, 0
    for bagIndex = 0, maxBag do
        local slots = tonumber(api.GetContainerNumSlots(bagIndex)) or 0
        if slots > 0 then
            total = total + slots
            local bagFree = api.GetContainerNumFreeSlots(bagIndex)
            if type(bagFree) == "number" then
                free = free + bagFree
            end
        end
    end

    return free, total
end

local function EnsureCompactBagCountText(button, profile)
    if not button then return nil end
    if button._fguiBagCountText and button._fguiBagCountText.GetObjectType and button._fguiBagCountText:GetObjectType() == "FontString" then
        return button._fguiBagCountText
    end

    local fontString = button:CreateFontString(nil, "OVERLAY")
    fontString:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    fontString:SetJustifyH("RIGHT")
    fontString:SetJustifyV("BOTTOM")

    local font = ((Theme and Theme.GetFontToken and Theme:GetFontToken()) or "Fonts\\FRIZQT__.TTF")
    local outline = ((Theme and Theme.GetFontOutline and Theme:GetFontOutline()) or "OUTLINE")
    Media:ApplyFont(fontString, font, 11, outline)

    button._fguiBagCountText = fontString
    return fontString
end

local function UpdateCompactBagCountText(module, profile)
    if not module then return end
    local button = module._compactBackpackButton
    if not button then return end

    local free, total = GetBagSlotsSummary()
    local text = EnsureCompactBagCountText(button, profile)
    if not text then return end

    if type(free) ~= "number" or type(total) ~= "number" then
        text:SetText("")
        return
    end

    text:SetText(tostring(free))
    text:SetTextColor(1.00, 0.92, 0.45, 1.00)
    button._fguiBagSummary = string.format("%d/%d", free, total)
end

local function HideAllBagButtons(bagButtons)
    local buttons = bagButtons or GetBagButtons()
    for i = 1, #buttons do
        local bagButton = buttons[i]
        if bagButton then
            pcall(bagButton.SetAlpha, bagButton, 0)
            if not Shared:IsInCombat() then
                pcall(bagButton.Hide, bagButton)
            end
        end
    end
end

local function ShowFrameSafe(frame)
    if not frame then return end
    pcall(frame.SetAlpha, frame, 1)
    pcall(frame.Show, frame)
end

local function HideFrameSafe(frame)
    if not frame then return end
    pcall(frame.SetAlpha, frame, 0)
    if not Shared:IsInCombat() then
        pcall(frame.Hide, frame)
    end
end

local function ClearCompactBagState(module)
    if module and module._compactBackpackButton and module._compactBackpackButton._fguiBagCountText then
        module._compactBackpackButton._fguiBagCountText:SetText("")
    end
    if module then
        module._compactBackpackButton = nil
    end
end

local function GetManagedBagAnchorTarget(anchor, microMenu, showMicro, gap)
    if showMicro and microMenu then
        return microMenu, "RIGHT", gap
    end
    return anchor, "LEFT", 0
end

local function BuildManagedBagLayoutPlan(cp, anchor, microMenu, showMicro, showBags, size, spacing, gap)
    local bagButtons = GetBagButtons()
    local backpackButton = nil
    local compactBags = showBags and (cp.bags.compact ~= false)
    if compactBags then
        backpackButton = GetCompactBackpackButton(bagButtons)
    end

    local anchorTarget, relativePoint, offsetX = GetManagedBagAnchorTarget(anchor, microMenu, showMicro, gap)
    local mode = "hidden"
    if showBags then
        mode = (compactBags and backpackButton) and "compact" or "expanded"
    end

    return {
        anchor = anchor,
        anchorTarget = anchorTarget,
        bagsBar = _G.BagsBar,
        bagButtons = bagButtons,
        backpackButton = backpackButton,
        mode = mode,
        offsetX = offsetX,
        relativePoint = relativePoint,
        size = size,
        spacing = spacing,
    }
end

local function ConfigureBagsBarLayout(bagsBar, spacing)
    if not bagsBar then return end

    bagsBar.hideExpandToggle = true
    bagsBar.isHorizontal = true
    bagsBar.bagPadding = math.max(0, tonumber(spacing) or 0)
    if _G.Enum and _G.Enum.BagsDirection and _G.Enum.BagsDirection.Right then
        bagsBar.direction = _G.Enum.BagsDirection.Right
    end
end

local function RestoreBagsBarLayout(bagsBar)
    if not bagsBar then return end

    bagsBar.hideExpandToggle = nil
    bagsBar.bagPadding = nil
end

local function PrepareManagedBagsBar(plan)
    if not (plan and plan.bagsBar) then
        return
    end

    ConfigureBagsBarLayout(plan.bagsBar, plan.spacing)
    if _G.BagBarExpandToggle then
        HideFrameSafe(_G.BagBarExpandToggle)
    end

    if _G.MainMenuBarBagManager and type(_G.MainMenuBarBagManager.SetExpandBar) == "function" then
        pcall(_G.MainMenuBarBagManager.SetExpandBar, _G.MainMenuBarBagManager, true)
    end

    if type(plan.bagsBar.Layout) == "function" then
        pcall(plan.bagsBar.Layout, plan.bagsBar)
    end
end

local function ApplyCompactBagLayout(module, plan)
    if not (module and plan and plan.backpackButton) then
        return 0, 0
    end

    ClearCompactBagState(module)

    for i = 1, #plan.bagButtons do
        local bagButton = plan.bagButtons[i]
        if bagButton == plan.backpackButton then
            if type(bagButton.SetBarExpanded) == "function" then
                pcall(bagButton.SetBarExpanded, bagButton, true)
            end
            StyleBackpackButton(bagButton, plan.size)
            SetBagCountShown(bagButton, false)
            pcall(bagButton.SetParent, bagButton, plan.anchor)
            pcall(bagButton.ClearAllPoints, bagButton)
            pcall(bagButton.SetPoint, bagButton, "LEFT", plan.anchorTarget, plan.relativePoint, plan.offsetX, 0)
            ShowFrameSafe(bagButton)
        else
            HideFrameSafe(bagButton)
        end
    end

    HideFrameSafe(plan.bagsBar)
    module._compactBackpackButton = plan.backpackButton
    UpdateCompactBagCountText(module)

    local width = (plan.backpackButton.GetWidth and plan.backpackButton:GetWidth()) or plan.size
    local height = (plan.backpackButton.GetHeight and plan.backpackButton:GetHeight()) or plan.size
    return width, height
end

local function ApplyExpandedBagLayout(module, plan)
    if not (plan and plan.bagsBar) then
        return 0, 0
    end

    ClearCompactBagState(module)

    for i = 1, #plan.bagButtons do
        local bagButton = plan.bagButtons[i]
        if type(bagButton.SetBarExpanded) == "function" then
            pcall(bagButton.SetBarExpanded, bagButton, true)
        end
        if IsBackpackButton(bagButton) then
            StyleBackpackButton(bagButton, plan.size)
            SetBagCountShown(bagButton, true)
        else
            StyleBagButton(bagButton, plan.size)
            if bagButton.Count then
                bagButton.Count:Show()
            end
        end
        ShowFrameSafe(bagButton)
    end

    pcall(plan.bagsBar.SetParent, plan.bagsBar, plan.anchor)
    pcall(plan.bagsBar.ClearAllPoints, plan.bagsBar)
    pcall(plan.bagsBar.SetPoint, plan.bagsBar, "LEFT", plan.anchorTarget, plan.relativePoint, plan.offsetX, 0)
    ShowFrameSafe(plan.bagsBar)

    local width = (plan.bagsBar.GetWidth and plan.bagsBar:GetWidth()) or (plan.size * math.max(1, #plan.bagButtons))
    local height = (plan.bagsBar.GetHeight and plan.bagsBar:GetHeight()) or plan.size
    return width, height
end

local function ApplyManagedBagLayout(module, plan)
    if not (module and plan) then
        return 0, 0
    end

    if plan.mode == "hidden" then
        ClearCompactBagState(module)
        HideFrameSafe(plan.bagsBar)
        HideAllBagButtons(plan.bagButtons)
        return 0, 0
    end

    PrepareManagedBagsBar(plan)
    if plan.mode == "compact" then
        return ApplyCompactBagLayout(module, plan)
    end

    return ApplyExpandedBagLayout(module, plan)
end

local function RestoreDefaultMicroLayout(module)
    if Shared:IsInCombat() then
        module._pendingAfterCombat = true
        return
    end

    if type(_G.MicroMenu) == "table" and type(_G.MicroMenu.ResetMicroMenuPosition) == "function" then
        pcall(_G.MicroMenu.ResetMicroMenuPosition, _G.MicroMenu)
    end

    local micro = ResolveMicroFrame()
    if micro then
        ShowFrameSafe(micro)
    end
    if _G.BagsBar then
        RestoreBagsBarLayout(_G.BagsBar)
        pcall(_G.BagsBar.SetParent, _G.BagsBar, UIParent)
        if type(_G.BagsBar.Layout) == "function" then
            pcall(_G.BagsBar.Layout, _G.BagsBar)
        end
        ShowFrameSafe(_G.BagsBar)
    end
    if _G.BagBarExpandToggle then
        ShowFrameSafe(_G.BagBarExpandToggle)
    end
    if _G.MainMenuBarBagManager and type(_G.MainMenuBarBagManager.OnExpandBarChanged) == "function" then
        pcall(_G.MainMenuBarBagManager.OnExpandBarChanged, _G.MainMenuBarBagManager)
    end

    if _G.MainMenuBarBackpackButton then
        SetBagCountShown(_G.MainMenuBarBackpackButton, true)
    end

    if module then
        ClearCompactBagState(module)
        if module._microAnchor then
            HideFrameSafe(module._microAnchor)
        end
    end
end

local function ApplyMicroMenuOverride(anchor)
    local microMenu = _G.MicroMenu
    if not (anchor and type(microMenu) == "table" and type(microMenu.OverrideMicroMenuPosition) == "function") then
        return false
    end

    local ok = pcall(microMenu.OverrideMicroMenuPosition, microMenu, anchor, "LEFT", anchor, "LEFT", 0, 0, false)
    if not ok then
        return false
    end

    ShowFrameSafe(microMenu)
    return true
end

local function HasStableMicroGeometry()
    local buttons = GetMicroButtons()
    if #buttons == 0 then
        return false
    end

    local firstButton = buttons[1]
    local lastButton = buttons[#buttons]
    if not firstButton or not lastButton then
        return false
    end

    if type(firstButton.GetCenter) ~= "function" or type(lastButton.GetCenter) ~= "function" then
        return false
    end

    local firstX, firstY = firstButton:GetCenter()
    local lastX, lastY = lastButton:GetCenter()
    if not (type(firstX) == "number"
        and type(firstY) == "number"
        and type(lastX) == "number"
        and type(lastY) == "number") then
        return false
    end

    if #buttons == 1 then
        return true
    end

    local spanX = math.abs(lastX - firstX)
    local spanY = math.abs(lastY - firstY)
    return spanX > 1 or spanY > 1
end

local function QueueMicroLayoutRetry(module)
    local activeModule = ns.Companion or module
    if not activeModule then
        return
    end

    if Shared:IsInCombat() then
        activeModule._pendingAfterCombat = true
        return
    end

    local function Run()
        local currentModule = ns.Companion or activeModule
        if not currentModule or currentModule._applyingMicroLayout then
            return
        end

        local cp = Shared:GetCompanionCfg(nil)
        if not Shared:ShouldManageMicroMenu(cp) then
            return
        end

        currentModule:RequestApply()
    end

    if Safety and Safety.Debounce and Safety.Debounce(MICRO_LAYOUT_RETRY_KEY, MICRO_LAYOUT_RETRY_DELAY, Run) then
        return
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(MICRO_LAYOUT_RETRY_DELAY, Run)
        return
    end

    Run()
end

function MicroBags:Apply(module, cp, profile)
    if not (module and cp) then return end
    if Shared:IsInCombat() then
        module._pendingAfterCombat = true
        return
    end

    local takeOver = Shared:ShouldTakeOverMicroAndBags()
    local showMicro = (cp.microMenu.enabled ~= false)
    local showBags = (cp.bags.enabled ~= false)
    local micro = _G.MicroMenu or ResolveMicroFrame()
    local bags = _G.BagsBar

    if not takeOver then
        RestoreDefaultMicroLayout(module)
        return
    end

    if not showMicro and not showBags then
        HideFrameSafe(micro)
        HideFrameSafe(bags)
        HideAllBagButtons()
        if module._microAnchor then
            HideFrameSafe(module._microAnchor)
        end
        ClearCompactBagState(module)
        return
    end

    local anchor = EnsureMicroAnchor(module)
    if not anchor then return end

    local size = cp.buttonSize or 32
    local spacing = cp.spacing or 0
    local gap = (showMicro and showBags) and (Shared.MICRO_BAGS_GAP + spacing) or 0

    module._applyingMicroLayout = true
    ShowFrameSafe(anchor)

    if _G.MicroMenu and _G.BagsBar then
        local microMenu = _G.MicroMenu
        local totalWidth = 0
        local maxHeight = 24

        if showMicro then
            local microButtons = GetMicroButtons()
            for i = 1, #microButtons do
                StyleMicroButton(microButtons[i], size)
            end

            if not HasStableMicroGeometry() then
                module._applyingMicroLayout = nil
                QueueMicroLayoutRetry(module)
                return
            end

            local usedOverride = ApplyMicroMenuOverride(anchor)
            if (not usedOverride) and type(microMenu.Layout) == "function" then
                if not HasStableMicroGeometry() then
                    module._applyingMicroLayout = nil
                    QueueMicroLayoutRetry(module)
                    return
                end

                microMenu.isStacked = false
                microMenu.isHorizontal = true
                microMenu.layoutFramesGoingRight = true
                microMenu.layoutFramesGoingUp = false
                if type(microMenu.numButtons) == "number" and microMenu.numButtons > 0 then
                    microMenu.stride = microMenu.numButtons
                end
                local okLayout = pcall(microMenu.Layout, microMenu)
                if not okLayout then
                    module._applyingMicroLayout = nil
                    QueueMicroLayoutRetry(module)
                    return
                end
                pcall(microMenu.SetParent, microMenu, anchor)
                pcall(microMenu.ClearAllPoints, microMenu)
                pcall(microMenu.SetPoint, microMenu, "LEFT", anchor, "LEFT", 0, 0)
                ShowFrameSafe(microMenu)
            end

            microButtons = GetMicroButtons()
            for i = 1, #microButtons do
                StyleMicroButton(microButtons[i], size)
            end

            local mw = (microMenu.GetWidth and microMenu:GetWidth()) or (size * math.max(1, #microButtons))
            local mh = (microMenu.GetHeight and microMenu:GetHeight()) or size
            totalWidth = mw
            maxHeight = math.max(maxHeight, mh)
        else
            HideFrameSafe(microMenu)
        end

        local bagPlan = BuildManagedBagLayoutPlan(cp, anchor, microMenu, showMicro, showBags, size, spacing, gap)
        local bagWidth, bagHeight = ApplyManagedBagLayout(module, bagPlan)
        if bagWidth > 0 then
            totalWidth = totalWidth + ((showMicro and gap) or 0) + bagWidth
            maxHeight = math.max(maxHeight, bagHeight)
        end

        anchor:SetSize(math.max(120, totalWidth > 0 and totalWidth or size), math.max(24, maxHeight))
    else
        ClearCompactBagState(module)
        local totalWidth = 0
        local maxHeight = 24

        if showMicro and micro then
            pcall(micro.SetParent, micro, anchor)
            pcall(micro.ClearAllPoints, micro)
            pcall(micro.SetPoint, micro, "BOTTOM", anchor, "BOTTOM", 0, 0)
            ShowFrameSafe(micro)

            local mw = (micro.GetWidth and micro:GetWidth()) or 360
            local mh = (micro.GetHeight and micro:GetHeight()) or 40
            totalWidth = mw
            maxHeight = math.max(maxHeight, mh)
        else
            HideFrameSafe(micro)
        end

        if showBags and bags and bags ~= micro and _G.MicroButtonAndBagsBar ~= micro then
            pcall(bags.SetParent, bags, anchor)
            pcall(bags.ClearAllPoints, bags)
            pcall(bags.SetPoint, bags, "LEFT", showMicro and (micro or anchor) or anchor, showMicro and "RIGHT" or "LEFT", showMicro and gap or 0, 0)
            ShowFrameSafe(bags)
            local bw = (bags.GetWidth and bags:GetWidth()) or (size * math.max(1, #GetBagButtons()))
            local bh = (bags.GetHeight and bags:GetHeight()) or size
            totalWidth = totalWidth + ((showMicro and gap) or 0) + bw
            maxHeight = math.max(maxHeight, bh)
        else
            HideFrameSafe(bags)
        end

        anchor:SetSize(math.max(120, totalWidth > 0 and totalWidth or size), math.max(24, maxHeight))
    end

    module._applyingMicroLayout = nil
end

function MicroBags:EnsureHooks(module)
    if not module then return end

    HookMicroSourceWidgets(module)

    if (not module._microResetHooked)
        and type(_G.MicroMenu) == "table"
        and type(_G.MicroMenu.ResetMicroMenuPosition) == "function" then
        module._microResetHooked = true
        hooksecurefunc(_G.MicroMenu, "ResetMicroMenuPosition", function()
            local selfModule = ns.Companion
            if not ShouldRepairManagedMicroMenu(selfModule) then return end
            selfModule:RequestApply()
        end)
    end

    local bagButtons = GetBagButtons()
    for i = 1, #bagButtons do
        local bagButton = bagButtons[i]
        if bagButton and (not bagButton._fguiSquareSkinHooked) and type(bagButton.UpdateTextures) == "function" then
            bagButton._fguiSquareSkinHooked = true
            hooksecurefunc(bagButton, "UpdateTextures", function(button)
                local selfModule = ns.Companion
                if not IsManagedModuleActive(selfModule) then return end
                local cp = Shared:GetCompanionCfg(nil)
                if not Shared:ShouldManageBags(cp) then return end
                if IsBackpackButton(button) then
                    StyleBackpackButton(button, cp.buttonSize or 32)
                    if type(button.SetCountShown) == "function" then
                        pcall(button.SetCountShown, button, (cp.bags.compact ~= false) and false or true)
                    end
                else
                    StyleBagButton(button, cp.buttonSize or 32)
                end
            end)
        end
    end
end

function MicroBags:CancelPendingLayoutRetry()
    CancelRetryTimer()
end

function MicroBags:RestoreDefaultLayout(module)
    CancelRetryTimer()
    RestoreDefaultMicroLayout(module)
end

function MicroBags:UpdateCompactBagCountText(module, profile)
    UpdateCompactBagCountText(module, profile)
end

function MicroBags:HandleExpandChanged(module)
    local selfModule = module or ns.Companion
    if not IsManagedModuleActive(selfModule) then return end

    local cp = Shared:GetCompanionCfg(nil)
    if not Shared:ShouldManageBags(cp) then return end

    selfModule:RequestApply()
end

function MicroBags:HandleBagUpdate(module, profile)
    if not IsManagedModuleActive(module or ns.Companion) then
        return false
    end

    local cp = Shared:GetCompanionCfg(nil)
    if not (Shared:ShouldManageBags(cp) and cp.bags.compact ~= false) then
        return false
    end

    UpdateCompactBagCountText(module, profile)
    return true
end

return MicroBags
