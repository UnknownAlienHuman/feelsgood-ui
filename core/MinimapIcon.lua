local addonName, ns = ...

local DB = ns.DB
local Log = ns.Log
local Actions = ns.MinimapIconActions
local Settings = ns.Settings
local Apply = ns.Apply

local MinimapIcon = {}
ns.MinimapIcon = MinimapIcon

local LDB = _G.LibStub and _G.LibStub("LibDataBroker-1.1", true)
local LDBIcon = _G.LibStub and _G.LibStub("LibDBIcon-1.0", true)

assert(Actions, "FeelsGoodUI: MinimapIconActions not loaded")

local ICON_TEXTURE = "Interface\\Icons\\INV_Misc_Smile"
local APPLY_KEY = "minimap"
local PANEL_KEY = "general"

local dataObj
local isRegistered = false
local runtimeCfg = {}
local dragging = false

local function GetCfg()
    local config = DB and DB.ReadSection and DB:ReadSection("minimap")
    return type(config) == "table" and config or nil
end

local function ResolvePosition(value)
    local position = tonumber(value)
    if type(position) ~= "number" then position = 220 end
    if position < 0 then position = 0 end
    if position > 360 then position = 360 end
    return math.floor(position + 0.5)
end

local function SyncRuntimeCfg(cfg)
    runtimeCfg.hide = cfg and cfg.hide == true or false
    runtimeCfg.minimapPos = ResolvePosition(cfg and cfg.minimapPos)
    runtimeCfg.lock = cfg and cfg.lock == true and true or nil
    runtimeCfg.showInCompartment = cfg and cfg.showInCompartment == true and true or nil
    return runtimeCfg
end

local function RefreshRuntimeCfg(cfg)
    if type(cfg) ~= "table" then return false end
    SyncRuntimeCfg(cfg)
    if LDBIcon and isRegistered and type(LDBIcon.Refresh) == "function" then
        LDBIcon:Refresh(addonName, runtimeCfg)
    end
    return true
end

local function EnsureDataObject()
    if dataObj then return dataObj end
    if not LDB then return nil end

    dataObj = LDB:NewDataObject(addonName, {
        type = "launcher",
        text = addonName,
        icon = ICON_TEXTURE,
    })

    if Actions and Actions.AttachDataObject then
        Actions:AttachDataObject(dataObj, MinimapIcon, addonName)
    end

    return dataObj
end

local function HasWriteOwner()
    return Settings
        and type(Settings.SetTx) == "function"
        and Apply
        and type(Apply.Request) == "function"
end

local function RequestApply()
    Apply:Request(APPLY_KEY)
end

local function SetTx(path, value, rule)
    return Settings:SetTx(APPLY_KEY, path, value, rule, PANEL_KEY)
end

local function RestoreRuntimeFromProfile()
    local cfg = GetCfg()
    if not cfg then return false end
    return RefreshRuntimeCfg(cfg)
end

local function CommitDraggedPosition()
    local position = ResolvePosition(runtimeCfg.minimapPos)
    runtimeCfg.minimapPos = position

    if not HasWriteOwner() then
        RestoreRuntimeFromProfile()
        return false
    end

    local changed, stored = SetTx(
        { "minimap", "minimapPos" },
        position,
        { type = "int", min = 0, max = 360, fallback = 220 }
    )
    if changed == true then
        runtimeCfg.minimapPos = ResolvePosition(stored)
        RequestApply()
        return true
    end

    RestoreRuntimeFromProfile()
    return false
end

local function EnsureDragHooks()
    if not (LDBIcon and type(LDBIcon.GetMinimapButton) == "function") then
        return false
    end

    local button = LDBIcon:GetMinimapButton(addonName)
    if not (button and type(button.HookScript) == "function") then
        return false
    end
    if button._fguiTransactionalDragHooked then
        return true
    end

    button._fguiTransactionalDragHooked = true
    button:HookScript("OnDragStart", function()
        dragging = true
    end)
    button:HookScript("OnDragStop", function()
        if not dragging then return end
        dragging = false

        local ok, err = xpcall(CommitDraggedPosition, function(reason)
            return tostring(reason or "unknown minimap drag commit error")
        end)
        if not ok then
            RestoreRuntimeFromProfile()
            if Log and type(Log.Error) == "function" then
                Log:Error("Minimap drag commit failed: " .. tostring(err))
            end
        end
    end)
    return true
end

function MinimapIcon:Init()
    return self:Attach()
end

function MinimapIcon:Attach()
    if not (LDB and LDBIcon) then
        Log:Warn("LibDataBroker/LibDBIcon missing; minimap icon disabled.")
        return false, "LibDataBroker/LibDBIcon missing"
    end

    local cfg = GetCfg()
    if not cfg then
        return false, "Minimap config unavailable"
    end

    local obj = EnsureDataObject()
    if not obj then
        Log:Warn("Failed to create LDB data object; minimap icon disabled.")
        return false, "Failed to create LDB data object"
    end

    SyncRuntimeCfg(cfg)
    if not isRegistered then
        LDBIcon:Register(addonName, obj, runtimeCfg)
        isRegistered = true
    else
        LDBIcon:Refresh(addonName, runtimeCfg)
    end
    EnsureDragHooks()

    return true
end

function MinimapIcon:Detach()
    if LDBIcon and isRegistered then
        if dragging and type(LDBIcon.GetMinimapButton) == "function" then
            local button = LDBIcon:GetMinimapButton(addonName)
            if button and type(button.SetScript) == "function" then
                button:SetScript("OnUpdate", nil)
            end
            dragging = false
            RestoreRuntimeFromProfile()
        end
        LDBIcon:Hide(addonName)
    end
    return true
end

function MinimapIcon:ApplyConfig()
    if not (LDBIcon and isRegistered) then
        return false, "Minimap icon is not registered"
    end

    local cfg = GetCfg()
    if not cfg then
        return false, "Minimap config unavailable"
    end

    if dragging then
        return false, "Minimap apply blocked while icon drag is active"
    end

    RefreshRuntimeCfg(cfg)
    EnsureDragHooks()
    if runtimeCfg.hide == true then
        LDBIcon:Hide(addonName)
    else
        LDBIcon:Show(addonName)
    end
    return true
end

function MinimapIcon:SetHidden(hidden)
    if not HasWriteOwner() then
        return false, nil
    end

    local changed, stored = SetTx(
        { "minimap", "hide" },
        hidden == true,
        { type = "boolean", fallback = false }
    )
    if changed == true then
        RequestApply()
    end
    return changed == true, stored
end

function MinimapIcon:ResetPosition()
    if not HasWriteOwner() then
        return false
    end

    local batchStarted = type(Settings.BeginPanelUndoBatch) == "function"
        and Settings:BeginPanelUndoBatch(PANEL_KEY) == true

    local ok, positionChanged, legacyChanged = xpcall(function()
        local changedPosition = SetTx(
            { "minimap", "minimapPos" },
            220,
            { type = "number", min = 0, max = 360, fallback = 220 }
        )
        local changedLegacy = SetTx({ "minimap", "angle" }, nil, nil)
        return changedPosition == true, changedLegacy == true
    end, function(err)
        return tostring(err or "unknown minimap reset error")
    end)

    if batchStarted and type(Settings.EndPanelUndoBatch) == "function" then
        Settings:EndPanelUndoBatch(PANEL_KEY)
    end

    if not ok then
        error(positionChanged, 0)
    end

    local changed = positionChanged or legacyChanged
    if changed then
        RequestApply()
    end
    return changed
end

Log:Debug("MinimapIcon loaded")
