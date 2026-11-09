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
local NATIVE_TOGGLE_RECOVERY_KEY = "_actionBarsNativeToggleRecovery"
local NATIVE_TOGGLE_RECOVERY_VERSION = 1

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
Shell._secureHookRegistry = Shell._secureHookRegistry or setmetatable({}, { __mode = "k" })
Shell._scriptHookRegistry = Shell._scriptHookRegistry or setmetatable({}, { __mode = "k" })
Shell._globalHookState = Shell._globalHookState or {}
local SecureHookRegistry = Shell._secureHookRegistry
local ScriptHookRegistry = Shell._scriptHookRegistry
local GlobalHookState = Shell._globalHookState

local function GetHookRecord(registry, target, create)
    if type(target) ~= "table" then return nil end
    local record = registry[target]
    if not record and create then
        record = {}
        registry[target] = record
    end
    return record
end

local function EnsureSecureMethodHook(target, method, callback)
    local record = GetHookRecord(SecureHookRegistry, target, true)
    if not record then return false, "Invalid secure hook target" end
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

local function EnsureScriptHook(target, event, callback)
    local record = GetHookRecord(ScriptHookRegistry, target, true)
    if not record then return false, "Invalid script hook target" end
    if record[event] == true then return true end
    if type(target.HookScript) ~= "function" then
        return false, tostring(event) .. " HookScript unavailable"
    end

    local ok, detail = pcall(target.HookScript, target, event, callback)
    if not ok then
        record[event .. "Error"] = tostring(detail)
        return false, tostring(detail)
    end
    record[event] = true
    record[event .. "Error"] = nil
    return true
end

function Shell.ReleaseHookOwner(module)
    if GlobalHookState.owner == module then
        GlobalHookState.owner = nil
        return true
    end
    return false
end

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
    if DB and DB.ReadSection then
        return DB:ReadSection("actionbars") or {}
    end
    return {}
end

local function CopyToggleVector(values, count)
    if type(values) ~= "table" then return nil end
    count = tonumber(count) or #values
    if count < 4 then return nil end

    local copy = {}
    for i = 1, count do copy[i] = values[i] end
    return copy, count
end

local function GetNativeToggleRecoveryRoot()
    local root = DB and type(DB.data) == "table" and DB.data or _G.FeelsGoodUIDB
    return type(root) == "table" and root or nil
end

local function GetNativeToggleRecoveryID()
    if type(_G.UnitGUID) == "function" then
        local guid = _G.UnitGUID("player")
        if type(guid) == "string" and guid ~= "" then
            return guid
        end
    end

    if type(_G.UnitFullName) == "function" then
        local name, realm = _G.UnitFullName("player")
        if type(name) == "string" and name ~= "" then
            return name .. "-" .. tostring(realm or "")
        end
    end
    return "default"
end

local function ReadPersistedNativeActionBarToggles()
    local root = GetNativeToggleRecoveryRoot()
    local recovery = root and root[NATIVE_TOGGLE_RECOVERY_KEY] or nil
    if type(recovery) ~= "table" or recovery.version ~= NATIVE_TOGGLE_RECOVERY_VERSION
        or type(recovery.records) ~= "table" then
        return nil
    end

    local record = recovery.records[GetNativeToggleRecoveryID()]
    if type(record) ~= "table" then return nil end
    local values, count = CopyToggleVector(record.values, record.count)
    if not values then return nil end
    return values, count
end

local function PersistNativeActionBarToggles(values, count)
    local root = GetNativeToggleRecoveryRoot()
    local copy, resolvedCount = CopyToggleVector(values, count)
    if not root or not copy then return false end

    local recovery = root[NATIVE_TOGGLE_RECOVERY_KEY]
    if type(recovery) ~= "table" or recovery.version ~= NATIVE_TOGGLE_RECOVERY_VERSION then
        recovery = {
            version = NATIVE_TOGGLE_RECOVERY_VERSION,
            records = {},
        }
        root[NATIVE_TOGGLE_RECOVERY_KEY] = recovery
    end
    recovery.records = type(recovery.records) == "table" and recovery.records or {}
    recovery.records[GetNativeToggleRecoveryID()] = {
        values = copy,
        count = resolvedCount,
    }
    return true
end

local function ClearPersistedNativeActionBarToggles()
    local root = GetNativeToggleRecoveryRoot()
    local recovery = root and root[NATIVE_TOGGLE_RECOVERY_KEY] or nil
    if type(recovery) ~= "table" or type(recovery.records) ~= "table" then
        return false
    end

    recovery.records[GetNativeToggleRecoveryID()] = nil
    if next(recovery.records) == nil then
        root[NATIVE_TOGGLE_RECOVERY_KEY] = nil
    end
    return true
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

    local persistedValues, persistedCount = ReadPersistedNativeActionBarToggles()
    local snapshot, count
    if persistedValues then
        snapshot, count = persistedValues, persistedCount
    else
        values = values or ReadActionBarToggles()
        snapshot, count = CopyToggleVector(values)
        if not snapshot then return false end
        PersistNativeActionBarToggles(snapshot, count)
    end

    module._nativeActionBarToggles = {
        values = snapshot,
        count = count,
    }
    return true
end

local function RestoreNativeActionBarToggles(module)
    if type(module) ~= "table" then
        return false
    end

    local snapshot = module._nativeActionBarToggles
    if type(snapshot) ~= "table" or type(snapshot.values) ~= "table" then
        local values, count = ReadPersistedNativeActionBarToggles()
        if not values then return false end
        snapshot = { values = values, count = count }
        module._nativeActionBarToggles = snapshot
    end
    if InCombat() then
        module._pendingRestore = true
        return false
    end

    local restored = ApplyActionBarToggles(snapshot.values, snapshot.count)
    if restored then
        module._nativeActionBarToggles = nil
        ClearPersistedNativeActionBarToggles()
    end
    return restored
end

function Shell.RestorePersistedNativeActionBarToggles()
    if InCombat() then return false end

    local values, count = ReadPersistedNativeActionBarToggles()
    if not values then return false end

    local restored = ApplyActionBarToggles(values, count)
    if restored then
        ClearPersistedNativeActionBarToggles()
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

local function ActiveShellHookOwner()
    local module = GlobalHookState.owner
    if IsDetached(module) then return nil end
    return module
end

local function OnEndCapsUpdated()
    local module = ActiveShellHookOwner()
    if module and Shell.ShouldHideBlizzardArt() then
        Shell.KickHideBlizzardArt(module)
    end
end

local function RepairSettingsShell()
    local module = ActiveShellHookOwner()
    if not module or type(module.ApplyConfig) ~= "function" then return end
    if InCombat() then
        module._pending = true
        return
    end
    module:ApplyConfig()
end

function Shell.EnsureEndCapsHook(module)
    if type(module) ~= "table" then
        return false, "ActionBars shell hook owner unavailable"
    end
    GlobalHookState.owner = module

    local mainActionBarMixin = _G.MainActionBarMixin
    if type(mainActionBarMixin) == "table" and type(mainActionBarMixin.UpdateEndCaps) == "function" then
        local ok, detail = EnsureSecureMethodHook(mainActionBarMixin, "UpdateEndCaps", OnEndCapsUpdated)
        if not ok then
            return false, "MainActionBarMixin.UpdateEndCaps: " .. tostring(detail)
        end
        return true
    end

    if type(_G.MainMenuBarArtFrame_UpdateEndCaps) == "function" then
        local ok, detail = EnsureSecureMethodHook(_G, "MainMenuBarArtFrame_UpdateEndCaps", OnEndCapsUpdated)
        if not ok then
            return false, "MainMenuBarArtFrame_UpdateEndCaps: " .. tostring(detail)
        end
    end
    return true
end

function Shell.EnsureSettingsHooks(module)
    if type(module) ~= "table" then
        return false, "ActionBars settings hook owner unavailable"
    end
    GlobalHookState.owner = module

    local firstDetail
    local settingsPanel = _G.SettingsPanel
    if type(settingsPanel) == "table" and type(settingsPanel.HookScript) == "function" then
        local ok, detail = EnsureScriptHook(settingsPanel, "OnHide", RepairSettingsShell)
        if not ok then
            firstDetail = firstDetail or ("SettingsPanel.OnHide: " .. tostring(detail))
        end
    end

    local settingsMixin = _G.SettingsPanelMixin
    if type(settingsMixin) == "table" and type(settingsMixin.TransitionBackOpeningPanel) == "function" then
        local ok, detail = EnsureSecureMethodHook(
            settingsMixin,
            "TransitionBackOpeningPanel",
            RepairSettingsShell
        )
        if not ok then
            firstDetail = firstDetail
                or ("SettingsPanelMixin.TransitionBackOpeningPanel: " .. tostring(detail))
        end
    end

    if firstDetail then
        return false, "ActionBars settings hook registration failed: " .. firstDetail
    end
    return true
end

return Shell
