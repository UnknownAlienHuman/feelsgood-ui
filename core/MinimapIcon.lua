local addonName, ns = ...

local DB = ns.DB
local Log = ns.Log
local Actions = ns.MinimapIconActions

local MinimapIcon = {}
ns.MinimapIcon = MinimapIcon

local LDB = _G.LibStub and _G.LibStub("LibDataBroker-1.1", true)
local LDBIcon = _G.LibStub and _G.LibStub("LibDBIcon-1.0", true)

assert(Actions, "FeelsGoodUI: MinimapIconActions not loaded")

-- Built-in icon (no packaged media file required).
local ICON_TEXTURE = "Interface\\Icons\\INV_Misc_Smile"

local dataObj
local isRegistered = false

local function GetCfg()
    local m = DB and DB.GetSection and DB:GetSection("minimap")
    if type(m) ~= "table" then
        m = {}
    end

    if m.hide == nil then m.hide = false end

    -- LibDBIcon uses 'minimapPos'. Older builds stored an internal angle field.
    if type(m.minimapPos) ~= "number" then
        if type(m.angle) == "number" then
            m.minimapPos = m.angle
        else
            m.minimapPos = 220
        end
    end

    if type(m.radius) ~= "number" then m.radius = 80 end
    return m
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

function MinimapIcon:Init()
    return self:Attach()
end

function MinimapIcon:Attach()
    if not (LDB and LDBIcon) then
        Log:Warn("LibDataBroker/LibDBIcon missing; minimap icon disabled.")
        return false
    end

    local cfg = GetCfg()
    local obj = EnsureDataObject()
    if not obj then
        Log:Warn("Failed to create LDB data object; minimap icon disabled.")
        return false
    end

    if not isRegistered then
        LDBIcon:Register(addonName, obj, cfg)
        isRegistered = true
    end

    return true
end

function MinimapIcon:Detach()
    if not (LDBIcon and isRegistered) then
        return false
    end

    LDBIcon:Hide(addonName)
    return true
end

function MinimapIcon:ApplyConfig()
    if not (LDBIcon and isRegistered) then return end

    local cfg = GetCfg()
    LDBIcon:Refresh(addonName, cfg)

    if cfg.hide then
        LDBIcon:Hide(addonName)
    else
        LDBIcon:Show(addonName)
    end
end

function MinimapIcon:SetHidden(hidden)
    local cfg = GetCfg()
    cfg.hide = hidden and true or false
    self:ApplyConfig()
end

function MinimapIcon:ResetPosition()
    local cfg = GetCfg()
    cfg.minimapPos = 220
    cfg.angle = nil
    self:ApplyConfig()
end

Log:Debug("MinimapIcon loaded")
