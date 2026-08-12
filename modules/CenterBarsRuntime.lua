-- FeelsGoodUI: CenterBars owner/runtime and config apply helpers

local _, ns = ...

local Runtime = {}
ns.CenterBarsRuntime = Runtime

local Log = ns.Log
local Media = ns.Media
local Movers = ns.Movers
local Safety = ns.Safety

local EMPTY = {}

Runtime._ctx = Runtime._ctx or EMPTY

function Runtime:Configure(context)
    if type(context) == "table" then
        self._ctx = context
    else
        self._ctx = EMPTY
    end
end

local function Ctx()
    return Runtime._ctx or EMPTY
end

local function Call(name, ...)
    local fn = Ctx()[name]
    if type(fn) == "function" then
        return fn(...)
    end
    return nil
end

local function GetCenterCfg()
    local value = Call("GetCenterCfg")
    if type(value) == "table" then
        return value
    end
    return {}
end

local function GetCenterTextCfg()
    local value = Call("GetCenterTextCfg")
    if type(value) == "table" then
        return value
    end
    return {}
end

local function GetSharedFontToken()
    return Call("GetSharedFontToken") or "Fonts\\FRIZQT__.TTF"
end

local function GetSharedFontOutline()
    return Call("GetSharedFontOutline") or "OUTLINE"
end

local function GetSharedFontSize()
    local value = tonumber(Call("GetSharedFontSize"))
    if type(value) == "number" then
        return value
    end
    return 12
end

local function GetSharedStatusbarToken()
    return Call("GetSharedStatusbarToken") or "Interface/Buttons/WHITE8x8"
end

local CENTER_EVENT_HANDLERS = {
    PLAYER_ENTERING_WORLD = function(owner)
        Call("RefreshResourceMode", owner)
        Call("UpdatePower", owner)
    end,
    PLAYER_SPECIALIZATION_CHANGED = function(owner, unit)
        if unit ~= "player" then return end
        Call("RefreshResourceMode", owner)
        Call("UpdatePower", owner)
    end,
    PLAYER_TALENT_UPDATE = function(owner)
        Call("RefreshResourceMode", owner)
        Call("UpdatePower", owner)
    end,
    UNIT_DISPLAYPOWER = function(owner, unit)
        if unit ~= "player" then return end
        Call("UpdatePower", owner)
    end,
    UNIT_POWER_UPDATE = function(owner, unit, powerType)
        Call("OnUnitPower", owner, unit, powerType)
    end,
    UNIT_POWER_FREQUENT = function(owner, unit, powerType)
        Call("OnUnitPower", owner, unit, powerType)
    end,
    UNIT_MAXPOWER = function(owner, unit, powerType)
        Call("OnUnitPower", owner, unit, powerType)
    end,
    RUNE_POWER_UPDATE = function(owner)
        Call("OnRuneEvent", owner)
    end,
    RUNE_TYPE_UPDATE = function(owner)
        Call("OnRuneEvent", owner)
    end,
}

function Runtime:Attach(owner)
    if not owner._inited then
        owner:Init()
    end
    if not owner._inited then
        return false
    end

    if owner._eventsAttached then
        return true
    end

    local frame = owner._eventFrame
    if not frame then
        frame = CreateFrame("Frame")
        owner._eventFrame = frame
    end

    frame:SetScript("OnEvent", function(_, event, ...)
        local handler = CENTER_EVENT_HANDLERS[event]
        if not handler then return end
        if Safety and Safety.Dispatch then
            Safety.Dispatch(owner, event, handler, ...)
        else
            handler(owner, ...)
        end
    end)

    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    frame:RegisterEvent("PLAYER_TALENT_UPDATE")

    if frame.RegisterUnitEvent then
        frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
        frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
        frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
        frame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    else
        frame:RegisterEvent("UNIT_DISPLAYPOWER")
        frame:RegisterEvent("UNIT_POWER_UPDATE")
        frame:RegisterEvent("UNIT_POWER_FREQUENT")
        frame:RegisterEvent("UNIT_MAXPOWER")
    end

    frame:RegisterEvent("RUNE_POWER_UPDATE")
    frame:RegisterEvent("RUNE_TYPE_UPDATE")

    owner._eventsAttached = true
    return true
end

function Runtime:Detach(owner)
    Call("StopRuneTicker", owner)
    Call("RestoreDefaultClassResources", owner)

    if owner.frame then
        owner.frame:Hide()
    end

    if not owner._eventFrame then
        owner._eventsAttached = false
        return false
    end

    owner._eventFrame:UnregisterAllEvents()
    owner._eventFrame:SetScript("OnEvent", nil)
    owner._eventsAttached = false
    return true
end

function Runtime:Init(owner)
    if owner._inited then return end

    local createCenterMoverSpec = Ctx().CreateCenterMoverSpec
    local createPowerBar = Ctx().CreatePowerBar
    local ensureSegmentPool = Ctx().EnsureSegmentPool
    if type(createCenterMoverSpec) ~= "function"
        or type(createPowerBar) ~= "function"
        or type(ensureSegmentPool) ~= "function" then
        Log:Warn("CenterBars runtime helpers missing; init aborted.")
        return
    end

    local center = GetCenterCfg()
    if center.enabled == false then
        Log:Info("CenterBars disabled (DB).")
        return
    end
    Call("RefreshThresholdConfig", owner)

    local w = tonumber(center.width) or 560
    local h1 = tonumber(center.resourceHeight) or 12
    local h2 = tonumber(center.powerHeight) or 14
    local gap = tonumber(center.spacing) or 6

    local f = CreateFrame("Frame", "FGUI_Center", UIParent)
    f:SetSize(w, h1 + gap + h2)

    owner.frame = f

    local resource = CreateFrame("Frame", nil, f)
    resource:SetPoint("TOP", f, "TOP", 0, 0)
    resource:SetSize(w, h1)

    owner.resourceBar = resource
    owner.resourceSegments = {}

    local maxSeg = tonumber(center.maxSegments) or 10
    if maxSeg < 6 then maxSeg = 6 end
    ensureSegmentPool(owner, maxSeg, h1)

    local power = createPowerBar(f, w, h2)
    if not power then
        owner.frame = nil
        owner.resourceBar = nil
        owner.resourceSegments = nil
        Log:Warn("CenterBars power bar helper returned nil; init aborted.")
        return
    end
    power:SetPoint("TOP", resource, "BOTTOM", 0, -gap)
    owner.powerBar = power

    Movers:Register("center", f, createCenterMoverSpec("Center"))
    Movers:Apply("center", f)

    owner._inited = true

    Call("RefreshResourceMode", owner)
    Call("UpdatePower", owner)

    Log:Info("CenterBars initialized.")
end

function Runtime:ApplyConfig(owner)
    local center = GetCenterCfg()
    local text = GetCenterTextCfg()

    if center.enabled == false then
        Call("StopRuneTicker", owner)
        Call("RestoreDefaultClassResources", owner)
        if owner.frame then
            owner.frame:Hide()
        end
        return
    end

    Call("RefreshThresholdConfig", owner)

    if not owner._inited then
        owner:Init()
    end
    if not owner.frame then return end

    local w = tonumber(center.width) or 560
    local h1 = tonumber(center.resourceHeight) or 12
    local h2 = tonumber(center.powerHeight) or 14
    local gap = tonumber(center.spacing) or 6
    local maxSeg = tonumber(owner._maxSegmentsCap) or tonumber(center.maxSegments) or 10
    if maxSeg < 6 then maxSeg = 6 end
    Call("EnsureSegmentPool", owner, maxSeg, h1)

    local scale = tonumber(center.scale) or 1.0
    owner.frame:SetScale(scale)

    local sb = Media:FetchStatusbar(GetSharedStatusbarToken())
    if owner.powerBar then owner.powerBar:SetStatusBarTexture(sb) end
    if owner.resourceSegments then
        for _, seg in ipairs(owner.resourceSegments) do
            if seg then seg:SetStatusBarTexture(sb) end
        end
    end

    local font = text.font or GetSharedFontToken()
    local size = tonumber(text.size) or GetSharedFontSize()
    local outline = text.outline or GetSharedFontOutline()
    if owner.powerBar and owner.powerBar.text then
        Media:ApplyFont(owner.powerBar.text, font, size, outline)
    end

    owner.frame:SetSize(w, h1 + gap + h2)
    if owner.resourceBar then
        owner.resourceBar:SetSize(w, h1)
    end
    if owner.powerBar then
        owner.powerBar:SetSize(w, h2)
        owner.powerBar:ClearAllPoints()
        if owner.resourceBar then
            owner.powerBar:SetPoint("TOP", owner.resourceBar, "BOTTOM", 0, -gap)
        else
            owner.powerBar:SetPoint("TOP", owner.frame, "TOP", 0, 0)
        end
    end

    owner.frame:Show()
    Call("RefreshResourceMode", owner)
    Call("UpdatePower", owner)
end

return Runtime
