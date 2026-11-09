-- FeelsGoodUI: ActionBars state/autohide runtime
local _, ns = ...

local State = {}
ns.ActionBarsState = State

local Movers = ns.Movers

local InCombat = InCombatLockdown or function() return false end

State._buttonRegistry = State._buttonRegistry or setmetatable({}, { __mode = "k" })
State._holderRegistry = State._holderRegistry or setmetatable({}, { __mode = "k" })
local ButtonRegistry = State._buttonRegistry
local HolderRegistry = State._holderRegistry

State._secureHookRegistry = State._secureHookRegistry or setmetatable({}, { __mode = "k" })
State._globalHookState = State._globalHookState or {}
local SecureHookRegistry = State._secureHookRegistry
local GlobalHookState = State._globalHookState

local function GetSecureHookRecord(target, create)
    if type(target) ~= "table" then return nil end
    local record = SecureHookRegistry[target]
    if not record and create then
        record = {}
        SecureHookRegistry[target] = record
    end
    return record
end

local function EnsureSecureMethodHook(target, method, callback)
    if type(target) ~= "table" or type(method) ~= "string" or type(callback) ~= "function" then
        return false, "Invalid secure hook registration"
    end

    local record = GetSecureHookRecord(target, true)
    if record[method] == true then return true end

    local secureHook = _G.hooksecurefunc or hooksecurefunc
    if type(secureHook) ~= "function" then
        return false, "hooksecurefunc unavailable"
    end

    local ok, detail = pcall(secureHook, target, method, callback)
    if not ok then
        record[method .. "Error"] = tostring(detail)
        return false, tostring(detail)
    end

    record[method] = true
    record[method .. "Error"] = nil
    return true
end

function State.SetStateHookOwner(module)
    if type(module) ~= "table" or module._detached == true then
        return false, "ActionBars state hook owner unavailable"
    end
    GlobalHookState.owner = module
    return true
end

function State.ReleaseStateHookOwner(module)
    if GlobalHookState.owner == module then
        GlobalHookState.owner = nil
        return true
    end
    return false
end

local function GetHolderRecord(holder, create)
    if not holder then return nil end
    local record = HolderRegistry[holder]
    if not record and create then
        record = {}
        HolderRegistry[holder] = record
    end
    return record
end

function State.GetHolderRecord(holder, create)
    return GetHolderRecord(holder, create == true)
end

local function TryHookScript(target, event, callback)
    if not (target and type(target.HookScript) == "function") then
        return false, tostring(event) .. " HookScript unavailable"
    end

    local ok, detail = pcall(target.HookScript, target, event, callback)
    if not ok then
        return false, tostring(detail)
    end
    return true
end

local function EnsureScriptHook(record, target, event, field, callback)
    if record[field] == true then return true end

    local ok, detail = TryHookScript(target, event, callback)
    if ok then
        record[field] = true
        record[field .. "Error"] = nil
        return true
    end

    record[field .. "Error"] = detail
    return false, detail
end

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

local function IsDetached(module)
    return type(module) ~= "table" or module._detached == true
end

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

local function OnButtonStateEnter(btn)
    local record = GetButtonRecord(btn, false)
    local owner = record and record.module
    if owner and owner._detached == true then return end
    local layer = record and record.layers and record.layers.highlight
    if layer then layer:Show() end
end

local function OnButtonStateLeave(btn)
    local record = GetButtonRecord(btn, false)
    local layer = record and record.layers and record.layers.highlight
    if layer then layer:Hide() end
end

local function EnsureStateTexture(btn, record, name, drawLayer, subLevel, alpha, blendMode)
    record.layers = record.layers or {}
    local readyField = name .. "Ready"
    if record[readyField] == true and record.layers[name] then
        return true
    end

    local texture = record.layers[name]
    if not texture then
        if type(btn.CreateTexture) ~= "function" then
            return false, "ActionButton CreateTexture unavailable"
        end
        local ok, created = pcall(btn.CreateTexture, btn, nil, drawLayer, nil, subLevel)
        if not ok or not created then
            return false, ok and "ActionButton texture creation returned nil" or tostring(created)
        end
        texture = created
        record.layers[name] = texture
    end

    local ok, detail = pcall(function()
        texture:SetAllPoints(btn)
        texture:SetColorTexture(1, 1, 1, alpha)
        if blendMode then texture:SetBlendMode(blendMode) end
        texture:Hide()
    end)
    if not ok then
        return false, tostring(detail)
    end

    record[readyField] = true
    return true
end

local function EnsureStateLayers(btn)
    local record = GetButtonRecord(btn, true)
    if not record then return false, "ActionButton record unavailable" end

    local highlightOK, highlightDetail = EnsureStateTexture(btn, record, "highlight", "HIGHLIGHT", nil, 0.08)
    local checkedOK, checkedDetail = EnsureStateTexture(btn, record, "checked", "OVERLAY", 1, 0.14, "ADD")
    local pressedOK, pressedDetail = EnsureStateTexture(btn, record, "pressed", "OVERLAY", 2, 0.22, "ADD")

    local enterOK, enterDetail = EnsureScriptHook(
        record,
        btn,
        "OnEnter",
        "stateEnterHooked",
        OnButtonStateEnter
    )
    local leaveOK, leaveDetail = EnsureScriptHook(
        record,
        btn,
        "OnLeave",
        "stateLeaveHooked",
        OnButtonStateLeave
    )

    local dhl = btn.GetHighlightTexture and btn:GetHighlightTexture()
    if dhl and dhl.SetAlpha then pcall(dhl.SetAlpha, dhl, 0) end
    local dck = btn.GetCheckedTexture and btn:GetCheckedTexture()
    if dck and dck.SetAlpha then pcall(dck.SetAlpha, dck, 0) end
    local pushed = btn.GetPushedTexture and btn:GetPushedTexture()
    if pushed and pushed.SetAlpha then pcall(pushed.SetAlpha, pushed, 0) end

    local complete = highlightOK and checkedOK and pressedOK and enterOK and leaveOK
    record.stateLayers = complete == true
    if complete then return true end
    return false, highlightDetail or checkedDetail or pressedDetail or enterDetail or leaveDetail
end

local function EnsureSlotBG(btn)
    local record = GetButtonRecord(btn, true)
    if not record then return false, "ActionButton record unavailable" end
    if record.slotBackgroundReady == true and record.slotBackground then
        return true
    end

    local bg = record.slotBackground
    if not bg then
        if type(btn.CreateTexture) ~= "function" then
            return false, "ActionButton CreateTexture unavailable"
        end
        local ok, created = pcall(btn.CreateTexture, btn, nil, "BACKGROUND")
        if not ok or not created then
            return false, ok and "ActionButton slot background creation returned nil" or tostring(created)
        end
        bg = created
        record.slotBackground = bg
    end

    local ok, detail = pcall(function()
        bg:SetAllPoints(btn)
        bg:SetColorTexture(1, 1, 1, 0.02)
        bg:Hide()
    end)
    if not ok then
        return false, tostring(detail)
    end

    record.slotBackgroundReady = true
    return true
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
    local record = GetButtonRecord(btn, false)
    if not (btn and record and record.skinned) then return end
    if record.module and record.module._detached == true then return end
    EnsureSlotBG(btn)
    record = GetButtonRecord(btn, false)

    local holder = btn.GetParent and btn:GetParent() or nil
    local holderRecord = GetHolderRecord(holder, false)
    local holderAutoHidden = holderRecord and holderRecord.autoHidden == true or false
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

local function UpdateButtonChecked(btn)
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

function State.InitializeButton(btn)
    local record = GetButtonRecord(btn, false)
    if not (btn and record and record.skinned) then return false, "ActionButton is not managed" end

    local slotOK, slotDetail = EnsureSlotBG(btn)
    local layersOK, layersDetail = EnsureStateLayers(btn)
    if not slotOK or not layersOK then
        return false, slotDetail or layersDetail
    end

    UpdateButtonChecked(btn)
    UpdateEmptySlot(btn)
    return true
end

local function OnButtonAutoHideEdge(btn)
    local record = GetButtonRecord(btn, false)
    local owner = record and record.module
    if owner then State.QueueAutoHideUpdate(owner) end
end

function State.AttachButtonAutoHideHooks(btn, module)
    local record = GetButtonRecord(btn, true)
    if not record then return false, "ActionButton record unavailable" end

    record.module = module or ns.ActionBars
    local enterOK, enterDetail = EnsureScriptHook(
        record,
        btn,
        "OnEnter",
        "autoHideEnterHooked",
        OnButtonAutoHideEdge
    )
    local leaveOK, leaveDetail = EnsureScriptHook(
        record,
        btn,
        "OnLeave",
        "autoHideLeaveHooked",
        OnButtonAutoHideEdge
    )

    record.autoHideHooks = enterOK and leaveOK or false
    if record.autoHideHooks then return true end
    return false, enterDetail or leaveDetail
end

local function SetHolderButtonsMouse(holder, enabled)
    ForEachHolderButton(holder, function(btn)
        if btn.IsShown and btn:IsShown() then
            if enabled then
                if State.IsManagedButton(btn) then
                    UpdateEmptySlot(btn)
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
        return false
    end

    hidden = (hidden == true)
    local record = GetHolderRecord(holder, true)
    record.autoHidden = hidden
    holder:SetAlpha(hidden and 0 or 1)
    SetHolderButtonsMouse(holder, not hidden)
    return true
end

function State.IsAnyHolderHovered(module)
    if IsDetached(module) or type(module._ForEachHolder) ~= "function" then
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

local function InvalidateAutoHideQueue(module)
    if type(module) ~= "table" then
        return
    end
    module._autoHideGeneration = (module._autoHideGeneration or 0) + 1
    module._autoHideQueued = nil
end

function State.QueueAutoHideUpdate(module)
    if IsDetached(module) or module._autoHideQueued then
        return
    end

    local generation = (module._autoHideGeneration or 0) + 1
    module._autoHideGeneration = generation
    module._autoHideQueued = true

    local function Flush()
        if module._autoHideGeneration ~= generation then
            return
        end
        module._autoHideQueued = nil
        if IsDetached(module) then
            return
        end
        State.UpdateAutoHideState(module)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, Flush)
    else
        Flush()
    end
end

function State.ResetAutoHideState(module)
    if type(module) ~= "table" then
        return
    end

    InvalidateAutoHideQueue(module)
    module._autoHideEnabled = false

    if type(module._ForEachHolder) ~= "function" then
        return
    end

    module:_ForEachHolder(function(holder)
        if holder then
            State.SetHolderAutoHidden(holder, false)
        end
    end)
end

function State.UpdateAutoHideState(module)
    if IsDetached(module) or type(module._ForEachHolder) ~= "function" then
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

local function OnHolderAutoHideEdge(holder)
    local record = GetHolderRecord(holder, false)
    local owner = record and record.module
    if owner then State.QueueAutoHideUpdate(owner) end
end

function State.EnsureAutoHideHooks(module)
    if IsDetached(module) then
        return false, "ActionBars auto-hide owner detached"
    end
    if type(module._ForEachHolder) ~= "function" then
        return false, "ActionBars holder iterator unavailable"
    end

    local allOK = true
    local firstDetail
    module:_ForEachHolder(function(holder)
        if not holder then return end

        local record = GetHolderRecord(holder, true)
        record.module = module
        SetMouseEnabledSafe(holder, true)

        local enterOK, enterDetail = EnsureScriptHook(
            record,
            holder,
            "OnEnter",
            "autoHideEnterHooked",
            OnHolderAutoHideEdge
        )
        local leaveOK, leaveDetail = EnsureScriptHook(
            record,
            holder,
            "OnLeave",
            "autoHideLeaveHooked",
            OnHolderAutoHideEdge
        )

        record.autoHideHooks = enterOK and leaveOK or false
        if not record.autoHideHooks then
            allOK = false
            firstDetail = firstDetail or enterDetail or leaveDetail
        end
    end)

    if allOK then return true end
    return false, firstDetail or "ActionBars holder auto-hide hook registration failed"
end

local function RunButtonVisualSync(module, btn, updateChecked, updateEmpty)
    if IsDetached(module) or not btn then return end
    local visuals = ns.ActionBarsVisuals
    if type(visuals) == "table" and type(visuals.RefreshButtonVisualState) == "function" then
        if visuals.RefreshButtonVisualState(btn) then
            return
        end
    end
    if updateChecked then UpdateButtonChecked(btn) end
    if updateEmpty then UpdateEmptySlot(btn) end
end

local function ActiveStateHookOwner()
    local module = GlobalHookState.owner
    if IsDetached(module) then return nil end
    return module
end

local function OnActionButtonUpdateState(btn)
    local module = ActiveStateHookOwner()
    if module then RunButtonVisualSync(module, btn, true, true) end
end

local function OnActionButtonUpdateUsable(btn)
    local module = ActiveStateHookOwner()
    if module then RunButtonVisualSync(module, btn, false, true) end
end

local function OnActionButtonUpdateAction(btn)
    local module = ActiveStateHookOwner()
    if module then RunButtonVisualSync(module, btn, true, true) end
end

local function OnBaseActionButtonShowGrid(btn)
    local module = ActiveStateHookOwner()
    if module then UpdateEmptySlot(btn) end
end

local function OnMoversUnlocked()
    local module = ActiveStateHookOwner()
    if not module then return end
    State.RefreshEmptySlots(module)
    State.UpdateAutoHideState(module)
end

local function OnSpellAlertShown(_, btn)
    local module = ActiveStateHookOwner()
    if not module or not btn then return end

    local record = GetButtonRecord(btn, false)
    local pressed = record and record.layers and record.layers.pressed
    if pressed then pressed:Show() end

    local overlay = btn.SpellActivationAlert or btn.overlay
    if overlay and overlay.SetAlpha then
        overlay:SetAlpha(0)
        if overlay.Hide then overlay:Hide() end
    end
end

local function OnSpellAlertHidden(_, btn)
    local module = ActiveStateHookOwner()
    if not module then return end

    local record = GetButtonRecord(btn, false)
    local pressed = record and record.layers and record.layers.pressed
    if pressed then pressed:Hide() end
end

function State.EnsureStateHooks(module, hasActionChangedCallback)
    if type(module) ~= "table" then
        return false, "ActionBars state hook owner unavailable"
    end

    local firstDetail

    local function Ensure(target, method, callback, label)
        if type(target) ~= "table" or type(target[method]) ~= "function" then
            return true
        end
        local ok, detail = EnsureSecureMethodHook(target, method, callback)
        if not ok then
            firstDetail = firstDetail or (tostring(label) .. ": " .. tostring(detail))
        end
        return ok
    end

    local actionButtonMixin = _G.ActionBarActionButtonMixin
    Ensure(actionButtonMixin, "UpdateState", OnActionButtonUpdateState, "ActionBarActionButtonMixin.UpdateState")
    Ensure(actionButtonMixin, "UpdateUsable", OnActionButtonUpdateUsable, "ActionBarActionButtonMixin.UpdateUsable")
    if hasActionChangedCallback ~= true then
        Ensure(actionButtonMixin, "UpdateAction", OnActionButtonUpdateAction, "ActionBarActionButtonMixin.UpdateAction")
    end

    local baseActionButtonMixin = _G.BaseActionButtonMixin
    Ensure(baseActionButtonMixin, "SetShowGrid", OnBaseActionButtonShowGrid, "BaseActionButtonMixin.SetShowGrid")

    if Movers and type(Movers.SetUnlocked) == "function" then
        Ensure(Movers, "SetUnlocked", OnMoversUnlocked, "Movers.SetUnlocked")
    end

    local spellAlertManager = _G.ActionButtonSpellAlertManager
    Ensure(spellAlertManager, "ShowAlert", OnSpellAlertShown, "ActionButtonSpellAlertManager.ShowAlert")
    Ensure(spellAlertManager, "HideAlert", OnSpellAlertHidden, "ActionButtonSpellAlertManager.HideAlert")

    if firstDetail then
        return false, "ActionBars state hook registration failed: " .. firstDetail
    end
    return true
end

function State.RefreshEmptySlots(module)
    if IsDetached(module) or not module.bars then
        return
    end

    for i = 1, #module.bars do
        local holder = module.bars[i]
        if holder and holder.buttons then
            ForEachHolderButton(holder, function(btn)
                UpdateEmptySlot(btn)
            end)
        end
    end
end

return State
