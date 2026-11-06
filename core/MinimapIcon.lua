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

local function GetCfg()
    local config = DB and DB.GetSection and DB:GetSection("minimap")
    return type(config) == "table" and config or nil
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

    if not isRegistered then
        LDBIcon:Register(addonName, obj, cfg)
        isRegistered = true
    end

    return true
end

function MinimapIcon:Detach()
    if LDBIcon and isRegistered then
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

    LDBIcon:Refresh(addonName, cfg)
    if cfg.hide == true then
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
