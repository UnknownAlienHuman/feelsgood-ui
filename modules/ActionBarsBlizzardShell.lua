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

local function GetActionBarsCfg()
    if DB and DB.GetSection then
        return DB:GetSection("actionbars") or {}
    end
    return {}
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

function Shell.QueueManagedPositionsRefresh(module, immediate)
    if InCombat() then
        if type(module) == "table" then
            module._pendingManagedPositionsRefresh = true
        end
        return false
    end

    if immediate == true then
        RefreshManagedPositions()
        return true
    end

    if Safety and Safety.Debounce then
        Safety.Debounce(MANAGED_POSITIONS_REFRESH_KEY, MANAGED_POSITIONS_REFRESH_DELAY, RefreshManagedPositions)
        return true
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(MANAGED_POSITIONS_REFRESH_DELAY, RefreshManagedPositions)
        return true
    end

    RefreshManagedPositions()
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
    for i = 1, #BLIZZARD_ART_FRAME_NAMES do
        local name = BLIZZARD_ART_FRAME_NAMES[i]
        SoftHide(name, _G[name])
    end

    if type(module) == "table" then
        module._blizzardArtHidden = true
        module._pendingRestore = nil
    end

    Shell.QueueManagedPositionsRefresh(module)
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

    if type(barsCfg) == "table" and Shell.EnsureBlizzardMultiBars then
        Shell.EnsureBlizzardMultiBars(module, barsCfg, false)
    end

    if type(_G.MultiActionBar_Update) == "function" then
        pcall(_G.MultiActionBar_Update)
    end

    if type(module) == "table" then
        module._blizzardArtHidden = false
        module._pendingRestore = nil
    end

    if restored then
        Shell.QueueManagedPositionsRefresh(module)
    end

    return restored
end

function Shell.KickHideBlizzardArt(module)
    Shell.HideBlizzardArt(module)

    if InCombat() then
        if type(module) == "table" then
            module._pendingHide = true
        end
        return
    end

    if Safety and Safety.Debounce then
        for i = 1, #HIDE_KICK_DELAYS do
            local delay = HIDE_KICK_DELAYS[i]
            Safety.Debounce("FGUI_AB_HIDE_" .. tostring(delay), delay, function()
                Shell.HideBlizzardArt(module)
            end)
        end
        return
    end

    if not (C_Timer and C_Timer.After) then
        return
    end

    for i = 1, #HIDE_KICK_DELAYS do
        local delay = HIDE_KICK_DELAYS[i]
        C_Timer.After(delay, function()
            Shell.HideBlizzardArt(module)
        end)
    end
end

local function IsUntouchedSideBar(cfg, prefix)
    if type(cfg) ~= "table" then return false end
    local buttons = tonumber(cfg.buttons) or 12
    local rows = tonumber(cfg.rows) or 12
    local enabled = (cfg.enabled ~= false)
    local configuredPrefix = (type(cfg.prefix) == "string" and cfg.prefix ~= "") and cfg.prefix or prefix
    return enabled and buttons == 12 and rows == 12 and configuredPrefix == prefix
end

function Shell.ImportSideBarStateFromBlizzard(module, barsCfg)
    if type(module) ~= "table" or module._bar45Imported == true then
        return
    end
    if type(_G.GetActionBarToggles) ~= "function" then
        return
    end

    local toggles = { _G.GetActionBarToggles() }
    if #toggles < 4 then
        return
    end

    if IsUntouchedSideBar(barsCfg[4], "MultiBarRightButton") then
        barsCfg[4].enabled = (toggles[3] == true)
    end
    if IsUntouchedSideBar(barsCfg[5], "MultiBarLeftButton") then
        barsCfg[5].enabled = (toggles[4] == true)
    end

    module._bar45Imported = true
end

function Shell.EnsureBlizzardMultiBars(module, barsCfg, hideBlizzardOverride)
    if InCombat() then return end
    if type(_G.GetActionBarToggles) ~= "function" or type(_G.SetActionBarToggles) ~= "function" then
        return
    end

    local function IsBarEnabled(index)
        local cfg = barsCfg[index]
        return type(cfg) ~= "table" or cfg.enabled ~= false
    end

    local toggles = { _G.GetActionBarToggles() }
    local count = #toggles
    local hideBlizzard = hideBlizzardOverride
    if hideBlizzard == nil then
        hideBlizzard = Shell.ShouldHideBlizzardArt()
    end
    local desiredBottomLeft = IsBarEnabled(2)
    local desiredBottomRight = IsBarEnabled(3)
    local desiredRight = hideBlizzard and false or IsBarEnabled(4)
    local desiredLeft = hideBlizzard and false or IsBarEnabled(5)
    local didChange = false

    if count >= 4 then
        didChange = toggles[1] ~= desiredBottomLeft
            or toggles[2] ~= desiredBottomRight
            or toggles[3] ~= desiredRight
            or toggles[4] ~= desiredLeft

        toggles[1] = desiredBottomLeft
        toggles[2] = desiredBottomRight
        toggles[3] = desiredRight
        toggles[4] = desiredLeft
        pcall(_G.SetActionBarToggles, unpack(toggles, 1, count))
    else
        didChange = true
        pcall(_G.SetActionBarToggles,
            desiredBottomLeft,
            desiredBottomRight,
            desiredRight,
            desiredLeft
        )
    end

    if type(_G.MultiActionBar_Update) == "function" then
        pcall(_G.MultiActionBar_Update)
    end

    if didChange then
        Shell.QueueManagedPositionsRefresh(module)
    end
end

function Shell.EnsureEndCapsHook(module)
    if type(module) ~= "table" or module._endCapsHooked then
        return
    end

    local function Rehide()
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
            if not activeModule or type(activeModule.ApplyConfig) ~= "function" then
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
