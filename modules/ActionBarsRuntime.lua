-- FeelsGoodUI: ActionBars lifecycle and apply coordinator
local _, ns = ...

local Runtime = {}
ns.ActionBarsRuntime = Runtime
Runtime._callbackOwner = nil
Runtime._callbackRecord = nil
Runtime._nextCallbackID = 0

local Log = ns.Log
local DB = ns.DB
local Shell = ns.ActionBarsBlizzardShell
local State = ns.ActionBarsState
local Visuals = ns.ActionBarsVisuals
local EditMode = ns.ActionBarsEditMode

local InCombat = InCombatLockdown or function() return false end
local BUTTONS_PER_BAR = 12
local ACTION_BAR_COUNT = 5

local function GetActionBarsCfg()
    if DB and DB.ReadSection then
        return DB:ReadSection("actionbars") or {}
    end
    return {}
end

local function ResolveBarSpacing(spacing)
    if EditMode and EditMode.ResolveBarSpacing then
        return EditMode.ResolveBarSpacing(spacing)
    end

    spacing = tonumber(spacing) or 0
    if spacing < 0 then
        return 0
    end
    return spacing
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

local function G(prefix, i)
    return _G[prefix .. i]
end

local function NormalizeFrameLevel(level, fallback)
    local value = tonumber(level)
    if type(value) ~= "number" then
        value = fallback
    end
    value = math.floor(value + 0.5)
    if value < 1 then value = 1 end
    if value > 200 then value = 200 end
    return value
end

local function ApplyFrameLayer(frame, strata, level)
    if not frame then
        return
    end

    if frame.GetFrameStrata and frame.SetFrameStrata then
        local okCurrent, currentStrata = pcall(frame.GetFrameStrata, frame)
        if (not okCurrent) or currentStrata ~= strata then
            pcall(frame.SetFrameStrata, frame, strata)
        end
    end

    if frame.GetFrameLevel and frame.SetFrameLevel then
        local frameLevel = NormalizeFrameLevel(level, 10)
        local okCurrent, currentLevel = pcall(frame.GetFrameLevel, frame)
        if (not okCurrent) or currentLevel ~= frameLevel then
            pcall(frame.SetFrameLevel, frame, frameLevel)
        end
    end
end

local BUTTON_CACHE = {}

local function CollectButtons(prefix)
    local cached = BUTTON_CACHE[prefix]
    if cached then
        return cached
    end

    local buttons = {}
    for i = 1, BUTTONS_PER_BAR do
        local button = G(prefix, i)
        if not button then
            return nil
        end
        buttons[i] = button
    end

    BUTTON_CACHE[prefix] = buttons
    return buttons
end

local function LayoutHolder(holder, numButtons, rows, size, spacing)
    if not holder then
        return
    end
    if InCombat() then
        holder._layoutDirty = true
        return
    end

    numButtons = math.max(1, math.min(BUTTONS_PER_BAR, tonumber(numButtons) or BUTTONS_PER_BAR))
    rows = math.max(1, math.min(BUTTONS_PER_BAR, tonumber(rows) or 1))
    size = math.max(10, math.min(80, tonumber(size) or 32))
    spacing = ResolveBarSpacing(spacing)

    local perRow = math.ceil(numButtons / rows)
    local width = perRow * size + (perRow - 1) * spacing
    local height = rows * size + (rows - 1) * spacing
    holder:SetSize(width, height)
    holder._maxButtons = numButtons

    for i = 1, BUTTONS_PER_BAR do
        local button = holder.buttons[i]
        if button then
            button:ClearAllPoints()
            if i <= numButtons then
                button:SetParent(holder)
                button:SetSize(size, size)
                button:Show()
                SetMouseEnabledSafe(button, true)

                local row = math.floor((i - 1) / perRow)
                local column = (i - 1) % perRow
                button:SetPoint("TOPLEFT", holder, "TOPLEFT", column * (size + spacing), -row * (size + spacing))
            else
                button:Hide()
                SetMouseEnabledSafe(button, false)
            end
        end
    end

    holder._layoutDirty = false
end

local function AssignButtons(module, holder, prefix, style, showHotkeys)
    local buttons = CollectButtons(prefix)
    if not buttons then
        return false, "ActionButtons unavailable for " .. tostring(prefix)
    end

    local allOK = true
    local firstDetail
    for i = 1, BUTTONS_PER_BAR do
        local button = buttons[i]
        holder.buttons[i] = button

        local skinOK = true
        if Visuals and Visuals.SkinButton then
            local ok, detail = Visuals.SkinButton(button, style)
            if ok == false then
                skinOK = false
                allOK = false
                firstDetail = firstDetail
                    or (tostring(prefix) .. tostring(i) .. ": " .. tostring(detail or "skin initialization failed"))
            end
        end
        if skinOK and Visuals and Visuals.RefreshButtonVisualState then
            local ok, detail = Visuals.RefreshButtonVisualState(button, style, showHotkeys)
            if ok == false then
                allOK = false
                firstDetail = firstDetail
                    or (tostring(prefix) .. tostring(i) .. ": " .. tostring(detail or "visual refresh failed"))
            end
        end

        if State and State.AttachButtonAutoHideHooks then
            local ok, detail = State.AttachButtonAutoHideHooks(button, module)
            if ok == false then
                allOK = false
                firstDetail = firstDetail
                    or (tostring(prefix) .. tostring(i) .. ": " .. tostring(detail or "auto-hide hook registration failed"))
            end
        end
    end

    if allOK then return true end
    return false, firstDetail
end

local function ApplyHolderHotkeys(holder, showHotkeys)
    if not (holder and holder.buttons) then
        return
    end

    for i = 1, BUTTONS_PER_BAR do
        local button = holder.buttons[i]
        if button and Visuals and Visuals.SetButtonHotkey then
            Visuals.SetButtonHotkey(button, showHotkeys)
        end
    end
end

local function ApplyBarHolderConfig(module, holder, cfg, styleCfg, size, spacing, showHotkeys)
    if not holder then
        return false, "ActionBar holder unavailable"
    end

    cfg = (type(cfg) == "table") and cfg or {}
    if cfg.enabled == false then
        holder:Hide()
        return true
    end

    local prefix = cfg.prefix
    if type(prefix) ~= "string" or prefix == "" then
        holder:Hide()
        return true
    end

    local ok, detail = AssignButtons(module, holder, prefix, styleCfg, showHotkeys)
    if not ok then
        holder:Hide()
        return false, detail
    end

    LayoutHolder(holder, cfg.buttons or 12, cfg.rows or 1, size, spacing)
    holder:Show()
    ApplyHolderHotkeys(holder, showHotkeys)
    return true
end

local function ShouldHideManagedBlizzardArt()
    if Shell and Shell.ShouldHideBlizzardArt then
        return Shell.ShouldHideBlizzardArt()
    end
    if DB and DB.ShouldHideBlizzardActionBars then
        return DB:ShouldHideBlizzardActionBars()
    end

    local ab = GetActionBarsCfg()
    return ab.hideBlizzard ~= false
end

local function GetBarsConfig()
    local ab = GetActionBarsCfg()
    return (type(ab.bars) == "table") and ab.bars or {}
end

local function IsReady(module)
    return type(module) == "table"
end

local function IsDetached(module)
    return module and module._detached == true
end

local function InvalidateInitialApply(module)
    if not IsReady(module) then
        return
    end
    module._initialApplyGeneration = (module._initialApplyGeneration or 0) + 1
    module._initialApplyQueued = nil
end

local function CancelDetachedRestore(module)
    if not IsReady(module) then
        return
    end

    module._detachRestoreGeneration = (module._detachRestoreGeneration or 0) + 1
    module._pendingDetachedRestore = nil

    local frame = module._detachRestoreFrame
    if frame then
        frame:UnregisterAllEvents()
        frame:SetScript("OnEvent", nil)
    end
end

local function QueueDetachedRestore(module)
    if not IsReady(module) then
        return
    end

    CancelDetachedRestore(module)
    local generation = module._detachRestoreGeneration
    module._pendingDetachedRestore = true

    local frame = module._detachRestoreFrame
    if not frame then
        frame = CreateFrame("Frame")
        module._detachRestoreFrame = frame
    end

    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(self)
        if module._detachRestoreGeneration ~= generation then
            return
        end
        if not IsDetached(module) then
            CancelDetachedRestore(module)
            return
        end
        if InCombat() then
            return
        end

        if Shell and Shell.RestoreBlizzardArt then
            Shell.RestoreBlizzardArt(module, GetBarsConfig())
        end
        CancelDetachedRestore(module)
    end)
end

local function OnActionChanged(_, button)
    local activeModule = Runtime._callbackOwner
    if not IsReady(activeModule) or IsDetached(activeModule) then return end

    if Visuals and Visuals.RefreshButtonVisualState then
        if Visuals.RefreshButtonVisualState(button) then return end
    end
    if State and State.UpdateButtonChecked then State.UpdateButtonChecked(button) end
    if State and State.UpdateButtonEmpty then State.UpdateButtonEmpty(button) end
end

local function DispatchActionChanged(record, _, button)
    if not (record and record.active == true and Runtime._callbackRecord == record) then
        return
    end
    OnActionChanged(nil, button)
end

local function EnsureActionChangedCallback(module)
    local existingRecord = module._actionChangedCallbackRecord
    if module._actionChangedCallbackRegistered == true
        and type(existingRecord) == "table"
        and existingRecord.active == true
        and module._callbackHandles then
        return true, nil, true, existingRecord
    end

    module._actionChangedCallbackRegistered = nil
    module._actionChangedCallbackRecord = nil
    module._callbackHandles = nil

    if not _G.EventRegistry then
        return true, nil, false, nil
    end
    if not (EventUtil and type(EventUtil.CreateCallbackHandleContainer) == "function") then
        return true, nil, false, nil
    end

    local createOK, container = pcall(EventUtil.CreateCallbackHandleContainer)
    if not createOK or not container then
        return false, createOK and "Callback handle container unavailable" or tostring(container), false, nil
    end
    if type(container.RegisterCallback) ~= "function" then
        return false, "Callback handle container lacks RegisterCallback", false, nil
    end

    Runtime._nextCallbackID = Runtime._nextCallbackID + 1
    local record = {
        id = Runtime._nextCallbackID,
        active = true,
    }
    local callback = function(...)
        DispatchActionChanged(record, ...)
    end

    local registeredOK, registeredDetail = pcall(
        container.RegisterCallback,
        container,
        _G.EventRegistry,
        "ActionButton.OnActionChanged",
        callback,
        module
    )
    if not registeredOK then
        record.active = false
        if type(container.Unregister) == "function" then
            pcall(container.Unregister, container)
        end
        return false, tostring(registeredDetail), false, nil
    end

    module._callbackHandles = container
    module._actionChangedCallbackRecord = record
    module._actionChangedCallbackRegistered = true
    return true, nil, true, record
end

function Runtime.PreviewMoverLayout(module, size, spacing)
    if not IsReady(module) or IsDetached(module) then
        return false, "ActionBars preview owner unavailable"
    end
    if InCombat() then
        return false, "ActionBars preview blocked in combat"
    end

    local ab = GetActionBarsCfg()
    local created, createDetail = module:EnsureCreated()
    if created == false then
        return false, tostring(createDetail or "ActionBars holder initialization failed")
    end

    local barsCfg = (type(ab.bars) == "table") and ab.bars or {}
    local showHotkeys = (ab.showHotkeys == true)
    local styleCfg = (Visuals and Visuals.BuildStyleConfig and Visuals.BuildStyleConfig(size)) or {}
    local allOk = true
    local firstDetail

    for id = 1, ACTION_BAR_COUNT do
        local holder = module.bars and module.bars[id]
        local ok, detail = ApplyBarHolderConfig(module, holder, barsCfg[id], styleCfg, size, spacing, showHotkeys)
        if not ok then
            allOk = false
            firstDetail = firstDetail or ("ActionBar " .. tostring(id) .. ": " .. tostring(detail or "apply failed"))
        end
    end

    if not allOk then
        return false, firstDetail or "ActionBars preview could not acquire every button"
    end
    return true
end

function Runtime.ApplyNow(module)
    local db = DB or ns.DB
    if not db then
        if Log and type(Log.Error) == "function" then
            Log:Error("ActionBarsRuntime.ApplyNow: DB not initialized")
        end
        return false, "ActionBars DB unavailable"
    end
    if not IsReady(module) or IsDetached(module) then
        return false, "ActionBars apply owner unavailable"
    end

    local ab = GetActionBarsCfg()
    local created, createDetail = module:EnsureCreated()
    if created == false then
        return false, tostring(createDetail or "ActionBars holder initialization failed")
    end

    local stateHooksOK, stateHooksDetail = module:EnsureStateHooks(
        module._actionChangedCallbackRegistered == true
    )
    if stateHooksOK == false then
        return false, tostring(stateHooksDetail or "ActionBars state hook registration failed")
    end

    if Shell and Shell.EnsureEndCapsHook then
        local endCapsOK, endCapsDetail = Shell.EnsureEndCapsHook(module)
        if endCapsOK == false then
            return false, "ActionBars end-cap hook registration failed: " .. tostring(endCapsDetail)
        end
    end

    local hooksOK, hooksDetail = module:EnsureAutoHideHooks()
    if hooksOK == false then
        if Log and type(Log.Warn) == "function" then
            Log:Warn("ActionBars auto-hide hook registration failed: " .. tostring(hooksDetail))
        end
        return false, "ActionBars auto-hide hook registration failed: " .. tostring(hooksDetail)
    end

    local autoHide = (type(ab.autoHide) == "table") and ab.autoHide or nil
    module._autoHideEnabled = autoHide and autoHide.enabled == true or false

    for id = 1, ACTION_BAR_COUNT do
        ApplyFrameLayer(module.bars and module.bars[id], "LOW", 10)
    end

    local barsCfg = (type(ab.bars) == "table") and ab.bars or {}

    if Shell and Shell.EnsureBlizzardMultiBars then
        Shell.EnsureBlizzardMultiBars(module, barsCfg)
    end
    if Shell and Shell.EnsureSettingsHooks then
        local settingsOK, settingsDetail = Shell.EnsureSettingsHooks(module)
        if settingsOK == false then
            return false, tostring(settingsDetail or "ActionBars settings hook registration failed")
        end
    end

    local size = ab.buttonSize or 32
    local spacing = ResolveBarSpacing(ab.spacing)
    local showHotkeys = (ab.showHotkeys == true)
    local styleCfg = (Visuals and Visuals.BuildStyleConfig and Visuals.BuildStyleConfig(size)) or {}

    local allOk = true
    local firstDetail
    for id = 1, ACTION_BAR_COUNT do
        local holder = module.bars[id]
        local cfg = barsCfg[id]
        local ok, detail = ApplyBarHolderConfig(module, holder, cfg, styleCfg, size, spacing, showHotkeys)
        if not ok then
            allOk = false
            firstDetail = firstDetail or ("ActionBar " .. tostring(id) .. ": " .. tostring(detail or "apply failed"))
        end
    end

    if not allOk then
        return false, firstDetail or "ActionBars could not acquire every button"
    end

    if Shell then
        if ShouldHideManagedBlizzardArt() and Shell.KickHideBlizzardArt then
            Shell.KickHideBlizzardArt(module)
        elseif Shell.RestoreBlizzardArt then
            Shell.RestoreBlizzardArt(module, barsCfg)
        end
    end

    module:RefreshEmptySlots()
    module:UpdateAutoHideState()
    return true
end

function Runtime.ApplyConfig(module)
    if not IsReady(module) or IsDetached(module) then
        return false
    end
    if InCombat() then
        module._pending = true
        return false
    end

    local ok, detail = Runtime.ApplyNow(module)
    if not ok then
        module._pending = true
    end
    return ok, detail
end

function Runtime.QueueInitialApply(module, delay)
    if not IsReady(module) or IsDetached(module) or module._initialApplyQueued then
        return
    end

    local generation = (module._initialApplyGeneration or 0) + 1
    module._initialApplyGeneration = generation
    module._initialApplyQueued = true

    local function Run()
        local activeModule = ns.ActionBars or module
        if not activeModule or activeModule._initialApplyGeneration ~= generation then
            return
        end
        activeModule._initialApplyQueued = nil
        if IsDetached(activeModule) then
            return
        end
        Runtime.ApplyConfig(activeModule)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(tonumber(delay) or 0, Run)
    else
        Run()
    end
end

function Runtime.Init(module)
    if not IsReady(module) then
        return false, "ActionBars init owner unavailable"
    end

    local callbackOK, callbackDetail, callbackRegistered, callbackRecord = EnsureActionChangedCallback(module)
    if callbackOK == false then
        return false, "ActionBars action-change callback registration failed: " .. tostring(callbackDetail)
    end

    local stateOK, stateDetail = module:EnsureStateHooks(callbackRegistered == true)
    if stateOK == false then
        return false, tostring(stateDetail or "ActionBars state hook registration failed")
    end

    if Shell and Shell.EnsureEndCapsHook then
        local endCapsOK, endCapsDetail = Shell.EnsureEndCapsHook(module)
        if endCapsOK == false then
            return false, "ActionBars end-cap hook registration failed: " .. tostring(endCapsDetail)
        end
    end

    if State and type(State.SetStateHookOwner) == "function" then
        local ownerOK, ownerDetail = State.SetStateHookOwner(module)
        if ownerOK == false then
            return false, tostring(ownerDetail or "ActionBars state hook owner publication failed")
        end
    end

    if Shell and type(Shell.SetHookOwner) == "function" then
        local ownerOK, ownerDetail = Shell.SetHookOwner(module)
        if ownerOK == false then
            if State and type(State.ReleaseStateHookOwner) == "function" then
                State.ReleaseStateHookOwner(module)
            end
            return false, tostring(ownerDetail or "ActionBars shell hook owner publication failed")
        end
    end

    Runtime._callbackOwner = callbackRegistered == true and module or nil
    Runtime._callbackRecord = callbackRegistered == true and callbackRecord or nil

    if module._initDone then
        return true
    end

    module._initDone = true
    module._inited = true
    if Log and type(Log.Info) == "function" then
        Log:Info("ActionBars (Blizzard-button layout) loaded")
    end
    return true
end

function Runtime.Attach(module)
    if not IsReady(module) then
        return false
    end

    CancelDetachedRestore(module)
    module._detached = nil

    local initOK, initDetail = Runtime.Init(module)
    if initOK == false then
        return false, initDetail
    end
    if module._eventsAttached then
        return true
    end

    local frame = module._eventFrame
    if not frame then
        frame = CreateFrame("Frame")
        module._eventFrame = frame
    end

    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(_, event)
        if IsDetached(module) then
            return
        end

        if event == "PLAYER_REGEN_DISABLED" then
            module:UpdateAutoHideState()
            return
        end

        if event == "PLAYER_REGEN_ENABLED" then
            if module._pending then
                module._pending = false
                module:ApplyConfig()
            end
            if module._pendingRestore then
                module._pendingRestore = nil
                if Shell and Shell.RestoreBlizzardArt then
                    Shell.RestoreBlizzardArt(module, GetBarsConfig())
                end
            end
            if module._pendingHide then
                module._pendingHide = nil
                if ShouldHideManagedBlizzardArt() and Shell and Shell.KickHideBlizzardArt then
                    Shell.KickHideBlizzardArt(module)
                end
            end
            if module._pendingManagedPositionsRefresh then
                module._pendingManagedPositionsRefresh = nil
                if Shell and Shell.QueueManagedPositionsRefresh then
                    Shell.QueueManagedPositionsRefresh(module, true)
                end
            end
            module:UpdateAutoHideState()
            return
        end

        Runtime.QueueInitialApply(module, 0.1)
    end)

    module._eventsAttached = true
    Runtime.QueueInitialApply(module, 0.2)
    return true
end

function Runtime.Detach(module)
    if not IsReady(module) then
        return false
    end

    if State and State.ResetAutoHideState then
        State.ResetAutoHideState(module)
    end
    InvalidateInitialApply(module)
    if Shell and Shell.CancelPendingWork then
        Shell.CancelPendingWork(module)
    end

    module._detached = true

    local callbackRecord = module._actionChangedCallbackRecord
    if type(callbackRecord) == "table" then
        callbackRecord.active = false
    end
    if Runtime._callbackRecord == callbackRecord then
        Runtime._callbackRecord = nil
    end
    if Runtime._callbackOwner == module then
        Runtime._callbackOwner = nil
    end

    if InCombat() then
        QueueDetachedRestore(module)
    else
        CancelDetachedRestore(module)
        if Shell and Shell.RestoreBlizzardArt then
            Shell.RestoreBlizzardArt(module, GetBarsConfig())
        end
    end

    local cleanupOK = true
    local cleanupDetail
    if module._eventFrame then
        local okEvents, eventDetail = pcall(module._eventFrame.UnregisterAllEvents, module._eventFrame)
        local okScript, scriptDetail = pcall(module._eventFrame.SetScript, module._eventFrame, "OnEvent", nil)
        if not okEvents or not okScript then
            cleanupOK = false
            cleanupDetail = tostring((not okEvents and eventDetail) or scriptDetail)
        end
    end

    local callbackHandles = module._callbackHandles
    module._callbackHandles = nil
    module._actionChangedCallbackRecord = nil
    module._actionChangedCallbackRegistered = nil
    if callbackHandles and type(callbackHandles.Unregister) == "function" then
        local ok, detail = pcall(callbackHandles.Unregister, callbackHandles)
        if not ok then
            cleanupOK = false
            cleanupDetail = cleanupDetail or tostring(detail)
        end
    end

    if State and type(State.ReleaseStateHookOwner) == "function" then
        State.ReleaseStateHookOwner(module)
    end
    if Shell and type(Shell.ReleaseHookOwner) == "function" then
        Shell.ReleaseHookOwner(module)
    end

    module._eventsAttached = false
    module._pending = nil
    module._pendingHide = nil
    module._pendingRestore = nil
    module._pendingManagedPositionsRefresh = nil
    if not cleanupOK then
        return false, "ActionBars detach cleanup failed: " .. tostring(cleanupDetail)
    end
    return true
end

return Runtime
