-- FeelsGoodUI: ActionBars lifecycle and apply coordinator
local _, ns = ...

local Runtime = {}
ns.ActionBarsRuntime = Runtime

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
    if DB and DB.GetSection then
        return DB:GetSection("actionbars") or {}
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
        return false
    end

    for i = 1, BUTTONS_PER_BAR do
        local button = buttons[i]
        holder.buttons[i] = button

        if Visuals and Visuals.SkinButton then
            Visuals.SkinButton(button, style)
        end
        if Visuals and Visuals.RefreshButtonVisualState then
            Visuals.RefreshButtonVisualState(button, style, showHotkeys)
        end

        if State and State.AttachButtonAutoHideHooks then
            State.AttachButtonAutoHideHooks(button, module)
        end
    end

    return true
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
        return false
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

    local ok = AssignButtons(module, holder, prefix, styleCfg, showHotkeys)
    if not ok then
        holder:Hide()
        return false
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

local function EnsureActionChangedCallback(module)
    if (not module._callbackHandles)
        and EventUtil
        and type(EventUtil.CreateCallbackHandleContainer) == "function" then
        module._callbackHandles = EventUtil.CreateCallbackHandleContainer()
    end

    if module._actionChangedCallbackRegistered
        or not module._callbackHandles
        or not _G.EventRegistry
        or type(module._callbackHandles.RegisterCallback) ~= "function" then
        return
    end

    module._actionChangedCallbackRegistered = true
    module._callbackHandles:RegisterCallback(_G.EventRegistry, "ActionButton.OnActionChanged", function(_, button)
        if Visuals and Visuals.RefreshButtonVisualState then
            if Visuals.RefreshButtonVisualState(button) then
                return
            end
        end
        if button and button.__fguiUpdateChecked then
            button.__fguiUpdateChecked(button)
        end
        if button and button.__fguiUpdateEmpty then
            button.__fguiUpdateEmpty(button)
        end
    end, module)
end

function Runtime.ApplyNow(module)
    local db = DB or ns.DB
    if not db then
        if Log and type(Log.Error) == "function" then
            Log:Error("ActionBarsRuntime.ApplyNow: DB not initialized")
        end
        return false
    end
    if not IsReady(module) or IsDetached(module) then
        return false
    end

    local ab = GetActionBarsCfg()
    module:EnsureCreated()
    module:EnsureAutoHideHooks()

    ab.autoHide = (type(ab.autoHide) == "table") and ab.autoHide or {}
    module._autoHideEnabled = (ab.autoHide.enabled == true)

    for id = 1, ACTION_BAR_COUNT do
        ApplyFrameLayer(module.bars and module.bars[id], "LOW", 10)
    end

    local barsCfg = (type(ab.bars) == "table") and ab.bars or {}

    if Shell and Shell.ImportSideBarStateFromBlizzard then
        Shell.ImportSideBarStateFromBlizzard(module, barsCfg)
    end
    if Shell and Shell.EnsureBlizzardMultiBars then
        Shell.EnsureBlizzardMultiBars(module, barsCfg)
    end
    if Shell and Shell.EnsureSettingsHooks then
        Shell.EnsureSettingsHooks(module)
    end

    local size = ab.buttonSize or 32
    local spacing = ResolveBarSpacing(ab.spacing)
    local showHotkeys = (ab.showHotkeys == true)
    local styleCfg = (Visuals and Visuals.BuildStyleConfig and Visuals.BuildStyleConfig(size)) or {}

    local allOk = true
    for id = 1, ACTION_BAR_COUNT do
        local holder = module.bars[id]
        local cfg = barsCfg[id]
        if not ApplyBarHolderConfig(module, holder, cfg, styleCfg, size, spacing, showHotkeys) then
            allOk = false
        end
    end

    if not allOk then
        return false
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

    local ok = Runtime.ApplyNow(module)
    if not ok then
        module._pending = true
    end
    return ok
end

function Runtime.QueueInitialApply(module, delay)
    if not IsReady(module) or IsDetached(module) or module._initialApplyQueued then
        return
    end

    module._initialApplyQueued = true

    local function Run()
        local activeModule = ns.ActionBars or module
        if not activeModule then
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
        return false
    end
    if module._initDone then
        return true
    end

    module._initDone = true
    module._inited = true
    module:EnsureStateHooks()

    if Shell and Shell.EnsureEndCapsHook then
        Shell.EnsureEndCapsHook(module)
    end

    if Log and type(Log.Info) == "function" then
        Log:Info("ActionBars (Blizzard-button layout) loaded")
    end
    return true
end

function Runtime.Attach(module)
    if Runtime.Init(module) == false then
        return false
    end
    module._detached = nil
    if module._eventsAttached then
        return true
    end

    local frame = module._eventFrame
    if not frame then
        frame = CreateFrame("Frame")
        module._eventFrame = frame
    end

    EnsureActionChangedCallback(module)

    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(_, event)
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

    module._detached = true
    module._initialApplyQueued = nil

    if not InCombat() and Shell and Shell.RestoreBlizzardArt then
        Shell.RestoreBlizzardArt(module, GetBarsConfig())
    end

    if not module._eventFrame then
        module._eventsAttached = false
        return false
    end

    module._eventFrame:UnregisterAllEvents()
    module._eventFrame:SetScript("OnEvent", nil)
    if module._callbackHandles and type(module._callbackHandles.Unregister) == "function" then
        module._callbackHandles:Unregister()
    end
    module._actionChangedCallbackRegistered = nil
    module._eventsAttached = false
    module._pending = nil
    module._pendingHide = nil
    module._pendingRestore = nil
    module._pendingManagedPositionsRefresh = nil
    return true
end

return Runtime
