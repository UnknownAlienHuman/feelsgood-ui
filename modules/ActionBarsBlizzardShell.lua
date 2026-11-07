-- FeelsGoodUI: ActionBars Blizzard shell delegation
local _, ns = ...

local Shell = {}
ns.ActionBarsBlizzardShell = Shell

local DB = ns.DB
local Safety = ns.Safety

local InCombat = InCombatLockdown or function() return false end
local unpack = unpack or table.unpack

local HIDE_KICK_DELAYS = { 0, 1, 2, 5 }
local MANAGED_POSITIONS_REFRESH_DELAY = 0.05
local MANAGED_POSITIONS_REFRESH_KEY = "FGUI_AB_MANAGED_POSITIONS"

local BLIZZARD_ART_FRAME_NAMES = {
    "MainMenuBarCluster",
    "MainActionBar",
    "MainMenuBar",
    "MainActionBarArtFrame",
    "MainMenuBarArtFrame",
    "MultiBarBottomLeft",
    "MultiBarBottomRight",
    "MultiBarRight",
    "MultiBarLeft",
    "MultiBar5",
    "MultiBar6",
    "MultiBar7",
}

Shell._blizzardArtStates = Shell._blizzardArtStates or {}

ns._abPastebin = ns._abPastebin or CreateFrame("Frame")
ns._abPastebin:Hide()
local pastebin = ns._abPastebin

local function IsDetached(module)
    return type(module) == "table" and module._detached == true
end

local function HideKickKey(delay)
    return "FGUI_AB_HIDE_" .. tostring(delay)
end

local function GetActionBarsCfg()
    if DB and DB.GetSection then
        return DB:GetSection("actionbars") or {}
    end
    return {}
end

local function ReadActionBarToggles()
    if type(_G.GetActionBarToggles) ~= "function" then
        return nil
    end

    local values = { _G.GetActionBarToggles() }
    if #values < 4 then
        return nil
    end
    return values
end

local function ApplyActionBarToggles(values, count)
    if type(values) ~= "table" or type(_G.SetActionBarToggles) ~= "function" then
        return false
    end

    count = tonumber(count) or #values
    if count < 4 then
        return false
    end

    local ok = pcall(_G.SetActionBarToggles, unpack(values, 1, count))
    if not ok then
        return false
    end

    if type(_G.MultiActionBar_Update) == "function" then
        pcall(_G.MultiActionBar_Update)
    end
    return true
end

local function CaptureNativeActionBarToggles(module, values)
    if type(module) ~= "table" then
        return false
    end
    if type(module._nativeActionBarToggles) == "table" then
        return true
    end

    values = values or ReadActionBarToggles()
    if type(values) ~= "table" then
        return false
    end

    local snapshot = {}
    for i = 1, #values do snapshot[i] = values[i] end
    module._nativeActionBarToggles = {
        values = snapshot,
        count = #snapshot,
    }
    return true
end

local function RestoreNativeActionBarToggles(module)
    if type(module) ~= "table" then
        return false
    end

    local snapshot = module._nativeActionBarToggles
    if type(snapshot) ~= "table" or type(snapshot.values) ~= "table" then
        return false
    end
    if InCombat() then
        module._pendingRestore = true
        return false
    end

    local restored = ApplyActionBarToggles(snapshot.values, snapshot.count)
    if restored then
        module._nativeActionBarToggles = nil
    end
    return restored
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

local function SafeCall(frame, method, ...)
    if not frame or type(frame[method]) ~= "function" then
        return false, nil
    end
    return pcall(frame[method], frame, ...)
end

local function CaptureFrameState(name, frame)
    if type(name) ~= "string" or name == "" or not frame then
        return nil
    end

    local state = Shell._blizzardArtStates[name] or {}
    if state.active == true then
        return state
    end

    local okParent, parent = SafeCall(frame, "GetParent")
    local okAlpha, alpha = SafeCall(frame, "GetAlpha")
    local okShown, shown = SafeCall(frame, "IsShown")
    local okMouse, mouseEnabled = SafeCall(frame, "IsMouseEnabled")

    state.parent = okParent and parent or nil
    state.alpha = okAlpha and alpha or 1
    state.shown = okShown and shown == true or false
    if okMouse then
        state.mouseEnabled = mouseEnabled
    else
        state.mouseEnabled = nil
    end
    state.active = false
    Shell._blizzardArtStates[name] = state
    return state
end

local function RefreshManagedPositions()
    if type(_G.UIParent_ManageFramePositions) == "function" then
        pcall(_G.UIParent_ManageFramePositions)
    end
end

local function CancelHideKicks(module)
    if type(module) == "table" then
        module._hideKickGeneration = (module._hideKickGeneration or 0) + 1
        module._pendingHide = nil
    end

    if Safety and type(Safety.CancelDebounce) == "function" then
        for i = 1, #HIDE_KICK_DELAYS do
            Safety.CancelDebounce(HideKickKey(HIDE_KICK_DELAYS[i]))
        end
    end

    return type(module) == "table" and module._hideKickGeneration or 0
end

function Shell.CancelPendingWork(module)
    CancelHideKicks(module)

    if Safety and type(Safety.CancelDebounce) == "function" then
        Safety.CancelDebounce(MANAGED_POSITIONS_REFRESH_KEY)
    end

    if type(module) == "table" then
        module._pendingManagedPositionsRefresh = nil
    end
end

function Shell.QueueManagedPositionsRefresh(module, immediate)
    if IsDetached(module) then
        return false
    end

    if InCombat() then
        if type(module) == "table" then
            module._pendingManagedPositionsRefresh = true
        end
        return false
    end

    local function Run()
        if IsDetached(module) then
            return
        end
        RefreshManagedPositions()
    end

    if immediate == true then
        Run()
        return true
    end

    if Safety and Safety.Debounce then
        Safety.Debounce(MANAGED_POSITIONS_REFRESH_KEY, MANAGED_POSITIONS_REFRESH_DELAY, Run)
        return true
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(MANAGED_POSITIONS_REFRESH_DELAY, Run)
        return true
    end

    Run()
    return true
end

function Shell.ShouldHideBlizzardArt()
    if DB and DB.ShouldHideBlizzardActionBars then
        return DB:ShouldHideBlizzardActionBars()
    end

    local ab = GetActionBarsCfg()
    return ab.hideBlizzard ~= false
end

local function SoftHide(name, frame)
    if not frame then
        return false
    end

    local state = CaptureFrameState(name, frame)
    if state then
        state.active = true
    end

    pcall(frame.SetAlpha, frame, 0)
    SetMouseEnabledSafe(frame, false)

    if InCombat() then
        return true
    end

    pcall(frame.SetParent, frame, pastebin)
    pcall(frame.Hide, frame)
    return true
end

local function RestoreFrame(name, frame)
    local state = Shell._blizzardArtStates[name]
    if not frame or type(state) ~= "table" or state.active ~= true then
        return false
    end

    if InCombat() then
        return false
    end

    if state.parent then
        pcall(frame.SetParent, frame, state.parent)
    end
    pcall(frame.SetAlpha, frame, state.alpha or 1)

    if state.mouseEnabled ~= nil then
        SetMouseEnabledSafe(frame, state.mouseEnabled)
    end

    if state.shown == true then
        pcall(frame.Show, frame)
    else
        pcall(frame.Hide, frame)
    end

    state.active = false
    return true
end

function Shell.HideBlizzardArt(module)
    if IsDetached(module) then
        return false
    end

    for i = 1, #BLIZZARD_ART_FRAME_NAMES do
        local name = BLIZZARD_ART_FRAME_NAMES[i]
        SoftHide(name, _G[name])
    end

    if type(module) == "table" then
        module._blizzardArtHidden = true
        module._pendingRestore = nil
    end

    Shell.QueueManagedPositionsRefresh(module)
    return true
end

function Shell.RestoreBlizzardArt(module, barsCfg)
    if InCombat() then
        if type(module) == "table" then
            module._pendingRestore = true
            module._pendingHide = nil
        end
        return false
    end

    local restored = false
    for i = 1, #BLIZZARD_ART_FRAME_NAMES do
        local name = BLIZZARD_ART_FRAME_NAMES[i]
        restored = RestoreFrame(name, _G[name]) or restored
    end

    local restoredNativeToggles = false
    if IsDetached(module) then
        restoredNativeToggles = RestoreNativeActionBarToggles(module)
    elseif type(barsCfg) == "table" and Shell.EnsureBlizzardMultiBars then
        Shell.EnsureBlizzardMultiBars(module, barsCfg, false)
    end

    if not restoredNativeToggles and type(_G.MultiActionBar_Update) == "function" then
        pcall(_G.MultiActionBar_Update)
    end

    if type(module) == "table" then
        module._blizzardArtHidden = false
        module._pendingRestore = nil
    end

    if IsDetached(module) then
        Shell.QueueManagedPositionsRefresh(nil, true)
    elseif restored then
        Shell.QueueManagedPositionsRefresh(module)
    end

    return restored or restoredNativeToggles
end

function Shell.KickHideBlizzardArt(module)
    if IsDetached(module) then
        return
    end

    local generation = CancelHideKicks(module)
    Shell.HideBlizzardArt(module)

    if InCombat() then
        if type(module) == "table" then
            module._pendingHide = true
        end
        return
    end

    local function Rehide()
        if IsDetached(module) then
            return
        end
        if type(module) == "table" and module._hideKickGeneration ~= generation then
            return
        end
        Shell.HideBlizzardArt(module)
    end

    if Safety and Safety.Debounce then
        for i = 1, #HIDE_KICK_DELAYS do
            local delay = HIDE_KICK_DELAYS[i]
            Safety.Debounce(HideKickKey(delay), delay, Rehide)
        end
        return
    end

    if not (C_Timer and C_Timer.After) then
        return
    end

    for i = 1, #HIDE_KICK_DELAYS do
        C_Timer.After(HIDE_KICK_DELAYS[i], Rehide)
    end
end

function Shell.EnsureBlizzardMultiBars(module, barsCfg, hideBlizzardOverride)
    if InCombat() then return false end

    local toggles = ReadActionBarToggles()
    if not toggles or type(_G.SetActionBarToggles) ~= "function" then
        return false
    end
    CaptureNativeActionBarToggles(module, toggles)

    local function IsBarEnabled(index)
        local cfg = barsCfg[index]
        return type(cfg) ~= "table" or cfg.enabled ~= false
    end

    local hideBlizzard = hideBlizzardOverride
    if hideBlizzard == nil then
        hideBlizzard = Shell.ShouldHideBlizzardArt()
    end

    local desired = {
        IsBarEnabled(2),
        IsBarEnabled(3),
        (not hideBlizzard) and IsBarEnabled(4),
        (not hideBlizzard) and IsBarEnabled(5),
    }
    local didChange = false
    for i = 1, 4 do
        if toggles[i] ~= desired[i] then
            toggles[i] = desired[i]
            didChange = true
        end
    end

    if didChange then
        if not ApplyActionBarToggles(toggles, #toggles) then
            return false
        end
        Shell.QueueManagedPositionsRefresh(module)
    end
    return true
end

function Shell.EnsureEndCapsHook(module)
    if type(module) ~= "table" or module._endCapsHooked then
        return
    end

    local function Rehide()
        if IsDetached(module) then
            return
        end
        if Shell.ShouldHideBlizzardArt() then
            Shell.KickHideBlizzardArt(module)
        end
    end

    local mainActionBarMixin = _G.MainActionBarMixin
    if type(mainActionBarMixin) == "table" and type(mainActionBarMixin.UpdateEndCaps) == "function" then
        hooksecurefunc(mainActionBarMixin, "UpdateEndCaps", Rehide)
        module._endCapsHooked = "MainActionBarMixin.UpdateEndCaps"
        return
    end

    if type(_G.MainMenuBarArtFrame_UpdateEndCaps) == "function" then
        hooksecurefunc(_G, "MainMenuBarArtFrame_UpdateEndCaps", Rehide)
        module._endCapsHooked = "MainMenuBarArtFrame_UpdateEndCaps"
    end
end

function Shell.EnsureSettingsHooks(module)
    if type(module) ~= "table" then
        return false
    end

    if type(module._settingsShellRepair) ~= "function" then
        module._settingsShellRepair = function()
            local activeModule = ns.ActionBars or module
            if not activeModule or activeModule._detached == true or type(activeModule.ApplyConfig) ~= "function" then
                return
            end
            if InCombat() then
                activeModule._pending = true
                return
            end
            activeModule:ApplyConfig()
        end
    end

    if (not module._settingsPanelHooked)
        and type(_G.SettingsPanel) == "table"
        and type(_G.SettingsPanel.HookScript) == "function" then
        _G.SettingsPanel:HookScript("OnHide", module._settingsShellRepair)
        module._settingsPanelHooked = true
    end

    local settingsMixin = _G.SettingsPanelMixin
    if (not module._settingsTransitionHooked)
        and type(settingsMixin) == "table"
        and type(settingsMixin.TransitionBackOpeningPanel) == "function" then
        hooksecurefunc(settingsMixin, "TransitionBackOpeningPanel", module._settingsShellRepair)
        module._settingsTransitionHooked = true
    end

    return module._settingsPanelHooked == true or module._settingsTransitionHooked == true
end

return Shell
