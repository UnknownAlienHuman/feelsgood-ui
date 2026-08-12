-- FeelsGoodUI: CenterBars
-- Step 3: Center resource bar (combo points / runes) + power bar (energy / runic power).
--
-- Design goals:
--  - event-driven updates (no always-on OnUpdate)
--  - minimal allocations
--  - safe with Secret Values: do not do arithmetic/comparisons unless values are plain numbers
--  - independent owner-module: owns `center` config/runtime/mover contract instead of
--    borrowing player-frame ownership from UnitFrames
--
-- Step 3 scope:
--  - DEATHKNIGHT: Runes (top) + Runic Power (bottom)
--  - ROGUE: Combo Points (top) + Energy (bottom)
--  - Other classes: bottom power only (top hidden) for now

local _, ns = ...

local Center = {}
ns.Center = Center

local DB = ns.DB
local Theme = ns.Theme
local Runtime = ns.CenterBarsRuntime
local Render = ns.CenterBarsRender

assert(Runtime, "FeelsGoodUI: CenterBarsRuntime not loaded")
assert(Render, "FeelsGoodUI: CenterBarsRender not loaded")

Center._inited = false

local function GetSectionTable(section)
    if DB and DB.GetSection then
        local value = DB:GetSection(section)
        if type(value) == "table" then
            return value
        end
    end

    return {}
end

local function GetCenterCfg()
    return GetSectionTable("center")
end

local function GetFormatCfg()
    return GetSectionTable("format")
end

local function GetStyleCfg()
    return GetSectionTable("style")
end

local function GetCenterTextCfg()
    local center = GetCenterCfg()
    local text = (type(center) == "table" and type(center.text) == "table") and center.text or nil
    return text or {}
end

local function GetSharedFontToken()
    if Theme and Theme.GetFontToken then
        return Theme:GetFontToken()
    end
    local theme = Theme and Theme.Get and Theme:Get() or nil
    return (theme and theme.fonts and theme.fonts.primary) or "Fonts\\FRIZQT__.TTF"
end

local function GetSharedFontOutline()
    if Theme and Theme.GetFontOutline then
        return Theme:GetFontOutline()
    end
    local theme = Theme and Theme.Get and Theme:Get() or nil
    return (theme and theme.fonts and theme.fonts.outline) or "OUTLINE"
end

local function GetSharedFontSize()
    if Theme and Theme.GetFontSize then
        return Theme:GetFontSize()
    end
    local theme = Theme and Theme.Get and Theme:Get() or nil
    local size = theme and theme.fonts and theme.fonts.size
    return (type(size) == "number") and size or 12
end

local function GetSharedStatusbarToken()
    if Theme and Theme.GetStatusbarToken then
        return Theme:GetStatusbarToken()
    end
    local theme = Theme and Theme.Get and Theme:Get() or nil
    return (theme and theme.statusbars and theme.statusbars.primary) or "Interface/Buttons/WHITE8x8"
end

local function ResolvePowerType(powerKey)
    local enum = _G.Enum and _G.Enum.PowerType
    if enum and powerKey and enum[powerKey] then
        return enum[powerKey]
    end
    return nil
end

local RESOURCE_DEFS = {
    DEATHKNIGHT = {
        kind = "RUNES",
        segments = 6,
        color = { 0.0, 0.65, 1.0 },
        hideFrames = { "RuneFrame", "DeathKnightResourceOverlayFrame" },
    },
    ROGUE = {
        kind = "POWER_POINTS",
        powerKey = "ComboPoints",
        maxSegments = 10,
        color = { 0.0, 0.75, 1.0 },
        hideFrames = { "ComboPointPlayerFrame" },
    },
    DRUID = {
        kind = "POWER_POINTS",
        powerKey = "ComboPoints",
        maxSegments = 10,
        color = { 0.0, 0.75, 1.0 },
        hideFrames = { "ComboPointPlayerFrame" },
    },
    PALADIN = {
        kind = "POWER_POINTS",
        powerKey = "HolyPower",
        maxSegments = 5,
        color = { 1.0, 0.85, 0.1 },
        hideFrames = { "PaladinPowerBarFrame" },
    },
    MONK = {
        kind = "POWER_POINTS",
        powerKey = "Chi",
        maxSegments = 6,
        color = { 0.25, 1.0, 0.55 },
        hideFrames = { "MonkHarmonyBarFrame" },
    },
    WARLOCK = {
        kind = "POWER_POINTS",
        powerKey = "SoulShards",
        maxSegments = 5,
        allowPartial = true,
        color = { 0.75, 0.25, 1.0 },
        hideFrames = { "WarlockPowerFrame" },
    },
    MAGE = {
        kind = "POWER_POINTS",
        powerKey = "ArcaneCharges",
        maxSegments = 4,
        color = { 0.7, 0.35, 1.0 },
        hideFrames = { "MageArcaneChargesFrame" },
    },
    EVOKER = {
        kind = "POWER_POINTS",
        powerKey = "Essence",
        maxSegments = 6,
        color = { 0.0, 0.65, 1.0 },
        hideFrames = { "EssencePlayerFrame" },
    },
}

local DK_SPEC_COLORS = {
    [250] = { 0.85, 0.10, 0.10 },
    [251] = { 0.10, 0.65, 1.00 },
    [252] = { 0.20, 0.85, 0.35 },
}

local function GetDKSpecColor()
    local getSpecInfo = (_G.C_SpecializationInfo and _G.C_SpecializationInfo.GetSpecializationInfo) or _G.GetSpecializationInfo
    if not (_G.GetSpecialization and getSpecInfo) then return nil end
    local specIndex = _G.GetSpecialization()
    if not specIndex then return nil end
    local specID = getSpecInfo(specIndex)
    if type(specID) ~= "number" then return nil end
    return DK_SPEC_COLORS[specID]
end

local function GetPlayerClassColor()
    local _, class = UnitClass("player")
    if type(class) ~= "string" or class == "" then
        return nil
    end

    local color = nil
    if _G.C_ClassColor and _G.C_ClassColor.GetClassColor then
        color = _G.C_ClassColor.GetClassColor(class)
    end
    if not color and _G.RAID_CLASS_COLORS then
        color = _G.RAID_CLASS_COLORS[class]
    end
    if type(color) ~= "table" then
        return nil
    end

    local r = tonumber(color.r)
    local g = tonumber(color.g)
    local b = tonumber(color.b)
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return nil
    end
    return { r, g, b }
end

local function ClampNumber(v, minV, maxV, fallback)
    local n = tonumber(v)
    if type(n) ~= "number" then
        n = fallback
    end
    if type(n) ~= "number" then
        n = minV
    end
    if n < minV then n = minV end
    if n > maxV then n = maxV end
    return n
end

local function ClampWhole(v, minV, maxV, fallback)
    return math.floor(ClampNumber(v, minV, maxV, fallback) + 0.5)
end

local function CreateCenterMoverSpec(label)
    return {
        label = label,
        applyKeys = "center",
        positionKey = "center",
        getScale = function()
            local center = GetCenterCfg()
            return ClampNumber(center.scale, 0.60, 1.30, 1.0)
        end,
        setScale = function(value)
            local center = GetCenterCfg()
            center.scale = ClampNumber(value, 0.60, 1.30, 1.0)
        end,
        getSize = function()
            local center = GetCenterCfg()
            return ClampWhole(center.width, 260, 720, 420), ClampWhole(center.powerHeight, 6, 28, 12)
        end,
        setSize = function(width, height)
            local center = GetCenterCfg()
            local clampedWidth = ClampWhole(width, 260, 720, 420)
            local clampedHeight = ClampWhole(height, 6, 28, 12)
            center.width = clampedWidth
            center.powerHeight = clampedHeight
            center.resourceHeight = ClampWhole(clampedHeight, 6, 24, 10)
        end,
        onWheel = function(delta, shiftDown)
            local center = GetCenterCfg()
            if shiftDown then
                center.powerHeight = ClampWhole((tonumber(center.powerHeight) or 12) + delta, 6, 28, 12)
                center.resourceHeight = ClampWhole((tonumber(center.resourceHeight) or 10) + delta, 6, 24, 10)
            else
                center.width = ClampWhole((tonumber(center.width) or 420) + ((tonumber(delta) or 0) * 10), 260, 720, 420)
            end
            return true
        end,
    }
end

Render:Configure({
    GetCenterCfg = GetCenterCfg,
    GetFormatCfg = GetFormatCfg,
    GetStyleCfg = GetStyleCfg,
    GetCenterTextCfg = GetCenterTextCfg,
    GetSharedFontToken = GetSharedFontToken,
    GetSharedFontOutline = GetSharedFontOutline,
    GetSharedFontSize = GetSharedFontSize,
    GetSharedStatusbarToken = GetSharedStatusbarToken,
    ResourceDefs = RESOURCE_DEFS,
    ResolvePowerType = ResolvePowerType,
    GetPlayerClassColor = GetPlayerClassColor,
    GetDKSpecColor = GetDKSpecColor,
})

Runtime:Configure({
    CreateCenterMoverSpec = CreateCenterMoverSpec,
    CreatePowerBar = Render.CreatePowerBar,
    EnsureSegmentPool = Render.EnsureSegmentPool,
    GetCenterTextCfg = GetCenterTextCfg,
    GetCenterCfg = GetCenterCfg,
    GetSharedFontOutline = GetSharedFontOutline,
    GetSharedFontSize = GetSharedFontSize,
    GetSharedFontToken = GetSharedFontToken,
    GetSharedStatusbarToken = GetSharedStatusbarToken,
    RefreshThresholdConfig = Render.RefreshThresholdConfig,
    RefreshResourceMode = Render.RefreshResourceMode,
    RestoreDefaultClassResources = Render.RestoreDefaultClassResources,
    StopRuneTicker = Render.StopRuneTicker,
    UpdatePower = Render.UpdatePower,
    OnUnitPower = Render.OnUnitPower,
    OnRuneEvent = Render.OnRuneEvent,
})

function Center:RefreshThresholdConfig()
    return Render.RefreshThresholdConfig(self)
end

function Center:IsThresholdActive(ratio)
    return Render.IsThresholdActive(self, ratio)
end

function Center:EnsureResourceLayout(count, totalWidth, height, gap)
    return Render.EnsureResourceLayout(self, count, totalWidth, height, gap)
end

function Center:_StartRuneTicker()
    return Render.StartRuneTicker(self)
end

function Center:_StopRuneTicker()
    return Render.StopRuneTicker(self)
end

function Center:UpdatePower()
    return Render.UpdatePower(self)
end

function Center:UpdatePointResource()
    return Render.UpdatePointResource(self)
end

function Center:UpdateComboPoints()
    return Render.UpdateComboPoints(self)
end

function Center:UpdateRunes()
    return Render.UpdateRunes(self)
end

function Center:HideDefaultClassResources()
    return Render.HideDefaultClassResources(self)
end

function Center:OnCombatEnd()
    return Render.OnCombatEnd(self)
end

function Center:RefreshResourceMode()
    return Render.RefreshResourceMode(self)
end

function Center:OnUnitPower(unit, powerToken)
    return Render.OnUnitPower(self, unit, powerToken)
end

function Center:OnRuneEvent()
    return Render.OnRuneEvent(self)
end

function Center:Attach()
    return Runtime:Attach(self)
end

function Center:Detach()
    return Runtime:Detach(self)
end

function Center:Init()
    return Runtime:Init(self)
end

function Center:ApplyConfig()
    return Runtime:ApplyConfig(self)
end
