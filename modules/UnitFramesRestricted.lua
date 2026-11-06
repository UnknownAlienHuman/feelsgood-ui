-- FeelsGoodUI: Retail 12.1.5 restricted-value adapter for unit frames
--
-- The existing render path remains the owner for ordinary values. This adapter
-- routes inaccessible values around legacy nil/type/format checks and keeps
-- them on exact visual sinks only.

local _, ns = ...

local Secret = ns.Secret
local Text = ns.UnitFramesText
local Target = ns.UnitFramesTarget
local Render = ns.UnitFramesRender
local U = ns.U

if not (Secret and Text and Target and Render and U) then
    return
end

local EMPTY = {}
local AURA_SOURCE_FIELDS = { "sourceUnit", "unitCaster", "caster", "source" }
local AURA_BOOLEAN_FIELDS = { "isFromPlayerOrPlayerPet", "isCastByPlayer" }
local AURA_UNIT_FIELDS = { "sourceUnit", "unitCaster" }

local OriginalShouldShortenUnit = Text.ShouldShortenUnit
local OriginalUpdateUnitHealthColor = Target.UpdateUnitHealthColor
local OriginalUpdateTargetInfoFrame = Target.UpdateTargetInfoFrame
local OriginalRenderConfigure = Render.Configure
local OriginalRenderStyle = Render.Style

local function CanInspect(value)
    if Secret.CanAccess then
        return Secret.CanAccess(value)
    end
    if Secret.IsSecret then
        return not Secret.IsSecret(value)
    end
    return true
end

local function SafeSetText(fontString, value)
    if not fontString then return end
    if Secret.SafeSetText then
        Secret.SafeSetText(fontString, value)
    else
        fontString:SetText(value)
    end
end

local function CanInspectTable(value)
    if Secret.CanInspectTable then
        return Secret.CanInspectTable(value)
    end
    return CanInspect(value) and type(value) == "table"
end

local function SafeAuraExtractSourceUnit(...)
    local first = ...
    if not CanInspect(first) then
        return nil, nil
    end

    if type(first) == "table" then
        if not CanInspectTable(first) then
            return nil, nil
        end

        for index = 1, #AURA_SOURCE_FIELDS do
            local value = first[AURA_SOURCE_FIELDS[index]]
            if not CanInspect(value) then
                return nil, first
            end
            if type(value) == "string" then
                return value, first
            end
        end
        return nil, first
    end

    for index = 7, 12 do
        local value = select(index, ...)
        if not CanInspect(value) then
            return nil, nil
        end
        if type(value) == "string" then
            return value, nil
        end
    end

    return nil, nil
end

local function SafeAuraIsFromPlayerOrPet(sourceUnit, auraData)
    if not CanInspect(sourceUnit) then
        return nil
    end
    if sourceUnit == "player" or sourceUnit == "pet" or sourceUnit == "vehicle" then
        return true
    end

    if not CanInspect(auraData) then
        return nil
    end
    if auraData == nil then
        return nil
    end
    if not CanInspectTable(auraData) then
        return nil
    end

    for index = 1, #AURA_BOOLEAN_FIELDS do
        local value = auraData[AURA_BOOLEAN_FIELDS[index]]
        if not CanInspect(value) then
            return nil
        end
        if value == true then
            return true
        end
    end

    for index = 1, #AURA_UNIT_FIELDS do
        local value = auraData[AURA_UNIT_FIELDS[index]]
        if not CanInspect(value) then
            return nil
        end
        if value == "player" or value == "pet" then
            return true
        end
    end

    return false
end

function Render:Configure(context)
    local result = OriginalRenderConfigure(self, context)
    local targetContext = Target._ctx
    if type(targetContext) == "table" then
        targetContext.AuraExtractSourceUnit = SafeAuraExtractSourceUnit
        targetContext.AuraIsFromPlayerOrPet = SafeAuraIsFromPlayerOrPet
    end
    return result
end

local function GetTargetCache()
    local context = Target._ctx
    if type(context) ~= "table" then
        return EMPTY
    end
    if type(context.EnsureCache) == "function" then
        context.EnsureCache()
    end
    if type(context.Cache) == "table" then
        return context.Cache
    end
    return EMPTY
end

local function ApplyFallbackHealthColor(frame)
    if not (frame and frame.Health) then return end

    local cache = GetTargetCache()
    local cfg = type(cache.healthColor) == "table" and cache.healthColor or EMPTY
    local r = tonumber(cfg.fallbackR) or 0.12
    local g = tonumber(cfg.fallbackG) or 0.12
    local b = tonumber(cfg.fallbackB) or 0.12
    local a = tonumber(cfg.fallbackA) or 1

    Render.SetStatusBarColorSafe(frame.Health, r, g, b, a)
    if Target.ApplyTargetHeaderTextColor then
        Target.ApplyTargetHeaderTextColor(frame)
    end
end

-- ParseLooseNumber is intentionally unreachable for inaccessible health values.
function Text.ShouldShortenUnit(cache, unit)
    local shorten = OriginalShouldShortenUnit(cache, unit)
    if shorten ~= true then
        return false
    end
    if type(_G.UnitHealth) ~= "function" then
        return shorten
    end

    local value = _G.UnitHealth(unit)
    return CanInspect(value)
end

function Target.UpdateUnitHealthColor(frame, unit)
    unit = unit or (frame and frame.unit)
    if not unit then return end

    local cache = GetTargetCache()
    local cfg = type(cache.healthColor) == "table" and cache.healthColor or EMPTY
    local isPlayer = _G.UnitIsPlayer(unit)
    if not CanInspect(isPlayer) then
        ApplyFallbackHealthColor(frame)
        return
    end

    if isPlayer and cfg.useClassColorForEnemyPlayers ~= false then
        local _, classToken = _G.UnitClass(unit)
        if not CanInspect(classToken) then
            ApplyFallbackHealthColor(frame)
            return
        end
        if classToken ~= nil and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[classToken] then
            return OriginalUpdateUnitHealthColor(frame, unit)
        end
    end

    local reaction = _G.UnitReaction(unit, "player")
    if not CanInspect(reaction) then
        ApplyFallbackHealthColor(frame)
        return
    end

    return OriginalUpdateUnitHealthColor(frame, unit)
end

local function ClassificationTag(value)
    if not CanInspect(value) or value == nil or value == "normal" then return "" end
    if value == "elite" then return "+" end
    if value == "rare" then return "R" end
    if value == "rareelite" then return "R+" end
    if value == "worldboss" then return "B" end
    return type(value) == "string" and value or ""
end

local function BuildAccessibleTargetInfo(unit)
    local out = {}

    if type(_G.UnitLevel) == "function" then
        local level = _G.UnitLevel(unit)
        local okLevel, numericLevel = U.TryNumber(level)
        if okLevel then
            out[#out + 1] = "Lv"
            out[#out + 1] = tostring(U.Round(numericLevel))
        end
    end

    if type(_G.UnitClassification) == "function" then
        local classification = _G.UnitClassification(unit)
        local tag = ClassificationTag(classification)
        if tag ~= "" then
            out[#out + 1] = tag
        end
    end

    if type(_G.UnitClass) == "function" then
        local className = _G.UnitClass(unit)
        if CanInspect(className) and className ~= nil then
            out[#out + 1] = tostring(className)
        end
    end

    return table.concat(out, " ")
end

local function UpdateRestrictedTargetInfo(frame, hasTarget, name)
    local cache = GetTargetCache()
    local cfg = type(cache.targetInfo) == "table" and cache.targetInfo or EMPTY
    local showHeader = cfg.enabled == true and hasTarget == true

    if showHeader then
        frame.TargetHeader:Show()
    else
        frame.TargetHeader:Hide()
        if frame.TargetNameText then frame.TargetNameText:SetText("") end
        if frame.TargetInfoText then frame.TargetInfoText:SetText("") end
        return
    end

    if frame.TargetNameText then
        if cfg.showName ~= false then
            SafeSetText(frame.TargetNameText, name)
            frame.TargetNameText:Show()
        else
            frame.TargetNameText:SetText("")
            frame.TargetNameText:Hide()
        end
    end

    if frame.TargetInfoText then
        if cfg.showInfo ~= false then
            frame.TargetInfoText:SetText(BuildAccessibleTargetInfo(frame.unit))
            frame.TargetInfoText:Show()
        else
            frame.TargetInfoText:SetText("")
            frame.TargetInfoText:Hide()
        end
    end

    if Target.LayoutTargetHeader then
        Target.LayoutTargetHeader(frame)
    end
    if Target.ApplyTargetHeaderTextColor then
        Target.ApplyTargetHeaderTextColor(frame)
    end
end

function Target.UpdateTargetInfoFrame(frame)
    local unit = frame and frame.unit
    if not frame or unit ~= "target" or not frame.TargetHeader then return end

    local exists = _G.UnitExists(unit)
    if not CanInspect(exists) then
        UpdateRestrictedTargetInfo(frame, false, nil)
        return
    end
    if exists ~= true then
        return OriginalUpdateTargetInfoFrame(frame)
    end

    local name = _G.UnitName(unit)
    local level = _G.UnitLevel(unit)
    local classification = _G.UnitClassification(unit)
    local className = _G.UnitClass(unit)

    if CanInspect(name)
        and CanInspect(level)
        and CanInspect(classification)
        and CanInspect(className) then
        return OriginalUpdateTargetInfoFrame(frame)
    end

    UpdateRestrictedTargetInfo(frame, true, name)
end

local function SafePostUpdatePower(power, unit)
    if not (power and unit) then return end

    local _, powerToken = _G.UnitPowerType(unit)
    if not CanInspect(powerToken) then
        Render.SetStatusBarColorSafe(power, 0.25, 0.55, 1, 1)
        return
    end

    if powerToken == nil or not _G.PowerBarColor then
        return
    end

    local color = _G.PowerBarColor[powerToken]
    if type(color) == "table"
        and type(color.r) == "number"
        and type(color.g) == "number"
        and type(color.b) == "number" then
        Render.SetStatusBarColorSafe(power, color.r, color.g, color.b, 1)
    end
end

function Render.Style(frame, unit)
    local result = OriginalRenderStyle(frame, unit)

    if frame and frame.Power then
        frame.Power.PostUpdate = SafePostUpdatePower
    end

    -- Child geometry and icon cropping are owned by PostCreateIcon. Avoid
    -- touching aura children again from secret-capable update callbacks.
    if frame and frame.Buffs then
        frame.Buffs.PostUpdateIcon = nil
    end
    if frame and frame.Debuffs then
        frame.Debuffs.PostUpdateIcon = nil
    end

    return result
end
