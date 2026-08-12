-- FeelsGoodUI: ActionBars state/autohide runtime
local _, ns = ...

local State = {}
ns.ActionBarsState = State

local Movers = ns.Movers

local InCombat = InCombatLockdown or function() return false end

local function SetMouseEnabledSafe(frame, enabled)
    if not frame or type(frame.EnableMouse) ~= "function" then
        return
    end

    if InCombat() then
        return
    end

    pcall(frame.EnableMouse, frame, enabled == true)
end

local function ForEachHolderButton(holder, fn)
    if not (holder and holder.buttons and type(fn) == "function") then
        return
    end

    local count = holder._maxButtons or 12
    for i = 1, count do
        local btn = holder.buttons[i]
        if btn then
            fn(btn, i)
        end
    end
end

local function EnsureStateLayers(btn)
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
        if b.__fguiHL then b.__fguiHL:Show() end
    end)
    btn:HookScript("OnLeave", function(b)
        if b.__fguiHL then b.__fguiHL:Hide() end
    end)
end

local function EnsureSlotBG(btn)
    if not btn or btn.__fguiSlotBG then return end

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)
    bg:SetColorTexture(1, 1, 1, 0.02)
    bg:Hide()
    btn.__fguiSlotBG = bg
end

local function GetActionID(btn)
    if not btn then return nil end
    if type(btn.action) == "number" then return btn.action end
    if btn.GetAttribute then
        local action = btn:GetAttribute("action")
        if type(action) == "number" then
            return action
        end
    end
    return nil
end

local function IsEmptySlot(btn)
    if not btn then return true end
    if type(_G.GetActionInfo) ~= "function" then return false end

    local action = GetActionID(btn)
    if type(action) ~= "number" or action <= 0 then
        return true
    end

    local actionType = _G.GetActionInfo(action)
    return actionType == nil
end

local function ShouldShowEmpty(btn)
    if not btn then return false end
    local unlocked = (Movers and Movers._unlocked == true)
    local showgrid = (type(btn.showgrid) == "number" and btn.showgrid > 0)
    return unlocked or showgrid
end

local function UpdateEmptySlot(btn)
    if not btn or not btn._fguiSkinned then return end
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

local function UpdateButtonChecked(btn)
    if not (btn and btn.__fguiCK) then return end

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

function State.InitializeButton(btn)
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

function State.AttachButtonAutoHideHooks(btn, module)
    if not btn or btn._fguiAutoHideHooks then
        return
    end

    btn._fguiAutoHideHooks = true
    btn:HookScript("OnEnter", function()
        State.QueueAutoHideUpdate(module or ns.ActionBars)
    end)
    btn:HookScript("OnLeave", function()
        State.QueueAutoHideUpdate(module or ns.ActionBars)
    end)
end

local function SetHolderButtonsMouse(holder, enabled)
    ForEachHolderButton(holder, function(btn)
        if btn.IsShown and btn:IsShown() then
            if enabled then
                if btn.__fguiUpdateEmpty then
                    btn.__fguiUpdateEmpty(btn)
                else
                    SetMouseEnabledSafe(btn, true)
                end
            else
                SetMouseEnabledSafe(btn, false)
            end
        end
    end)
end

function State.SetHolderAutoHidden(holder, hidden)
    if not holder then
        return
    end

    hidden = (hidden == true)
    holder._fguiAutoHidden = hidden
    holder:SetAlpha(hidden and 0 or 1)
    SetHolderButtonsMouse(holder, not hidden)
end

function State.IsAnyHolderHovered(module)
    if type(module) ~= "table" or type(module._ForEachHolder) ~= "function" then
        return false
    end

    local hovered = false
    module:_ForEachHolder(function(holder)
        if hovered then return end
        if holder and holder.IsShown and holder:IsShown() and holder.IsMouseOver and holder:IsMouseOver() then
            hovered = true
        end
    end)
    return hovered
end

function State.QueueAutoHideUpdate(module)
    if type(module) ~= "table" or module._autoHideQueued then
        return
    end

    module._autoHideQueued = true

    local function Flush()
        module._autoHideQueued = false
        State.UpdateAutoHideState(module)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, Flush)
    else
        Flush()
    end
end

function State.UpdateAutoHideState(module)
    if type(module) ~= "table" or type(module._ForEachHolder) ~= "function" then
        return
    end

    local enabled = (module._autoHideEnabled == true)
    local shouldHide = false

    if enabled and not InCombat() and not (Movers and Movers._unlocked == true) then
        shouldHide = not State.IsAnyHolderHovered(module)
    end

    module:_ForEachHolder(function(holder)
        if not holder then return end
        if holder.IsShown and holder:IsShown() then
            State.SetHolderAutoHidden(holder, shouldHide)
        else
            State.SetHolderAutoHidden(holder, false)
        end
    end)
end

function State.EnsureAutoHideHooks(module)
    if type(module) ~= "table" or module._autoHideHooksAttached or type(module._ForEachHolder) ~= "function" then
        return
    end

    module._autoHideHooksAttached = true
    module:_ForEachHolder(function(holder)
        if not holder or holder._fguiAutoHideHooks then
            return
        end

        holder._fguiAutoHideHooks = true
        SetMouseEnabledSafe(holder, true)
        holder:HookScript("OnEnter", function()
            State.QueueAutoHideUpdate(module)
        end)
        holder:HookScript("OnLeave", function()
            State.QueueAutoHideUpdate(module)
        end)
    end)
end

local function RunButtonVisualSync(btn, updateChecked, updateEmpty)
    if not btn then return end
    local visuals = ns.ActionBarsVisuals
    if type(visuals) == "table" and type(visuals.RefreshButtonVisualState) == "function" then
        if visuals.RefreshButtonVisualState(btn) then
            return
        end
    end
    if updateChecked and btn.__fguiUpdateChecked then
        btn.__fguiUpdateChecked(btn)
    end
    if updateEmpty and btn.__fguiUpdateEmpty then
        btn.__fguiUpdateEmpty(btn)
    end
end

function State.EnsureStateHooks(module)
    if type(module) ~= "table" or module._stateHooksAttached then
        return
    end

    module._stateHooksAttached = true

    local actionButtonMixin = _G.ActionBarActionButtonMixin
    if type(actionButtonMixin) == "table" then
        if type(actionButtonMixin.UpdateState) == "function" then
            hooksecurefunc(actionButtonMixin, "UpdateState", function(btn)
                RunButtonVisualSync(btn, true, true)
            end)
        end
        if type(actionButtonMixin.UpdateUsable) == "function" then
            hooksecurefunc(actionButtonMixin, "UpdateUsable", function(btn)
                RunButtonVisualSync(btn, false, true)
            end)
        end
    end

    local hasActionChangedCallback = _G.EventRegistry and type(_G.EventRegistry.RegisterCallback) == "function"
    if (not hasActionChangedCallback) and type(actionButtonMixin) == "table" and type(actionButtonMixin.UpdateAction) == "function" then
        hooksecurefunc(actionButtonMixin, "UpdateAction", function(btn)
            RunButtonVisualSync(btn, true, true)
        end)
    end

    local baseActionButtonMixin = _G.BaseActionButtonMixin
    if type(baseActionButtonMixin) == "table" and type(baseActionButtonMixin.SetShowGrid) == "function" then
        hooksecurefunc(baseActionButtonMixin, "SetShowGrid", function(btn)
            if btn and btn.__fguiUpdateEmpty then
                btn.__fguiUpdateEmpty(btn)
            end
        end)
    end

    if Movers and type(Movers.SetUnlocked) == "function" then
        hooksecurefunc(Movers, "SetUnlocked", function()
            State.RefreshEmptySlots(module)
            State.UpdateAutoHideState(module)
        end)
    end

    local spellAlertManager = _G.ActionButtonSpellAlertManager
    if type(spellAlertManager) == "table" and type(spellAlertManager.ShowAlert) == "function" then
        hooksecurefunc(spellAlertManager, "ShowAlert", function(_, btn)
            if not btn then return end
            if btn.__fguiPR then btn.__fguiPR:Show() end
            local overlay = btn.SpellActivationAlert or btn.overlay
            if overlay and overlay.SetAlpha then
                overlay:SetAlpha(0)
                if overlay.Hide then overlay:Hide() end
            end
        end)
    end

    if type(spellAlertManager) == "table" and type(spellAlertManager.HideAlert) == "function" then
        hooksecurefunc(spellAlertManager, "HideAlert", function(_, btn)
            if btn and btn.__fguiPR then
                btn.__fguiPR:Hide()
            end
        end)
    end
end

function State.RefreshEmptySlots(module)
    if type(module) ~= "table" or not module.bars then
        return
    end

    for i = 1, #module.bars do
        local holder = module.bars[i]
        if holder and holder.buttons then
            ForEachHolderButton(holder, function(btn)
                if btn.__fguiUpdateEmpty then
                    btn.__fguiUpdateEmpty(btn)
                end
            end)
        end
    end
end

return State
