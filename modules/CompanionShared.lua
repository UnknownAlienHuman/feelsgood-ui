-- FeelsGoodUI: shared companion config/ownership helpers

local _, ns = ...

local Shared = {}
ns.CompanionShared = Shared

local DB = ns.DB

local InCombat = InCombatLockdown or function() return false end

Shared.APPLY_DEBOUNCE_KEY = "FGUI_COMPANION_APPLY"
Shared.PET_BUTTONS = (_G.NUM_PET_ACTION_SLOTS) or 10
Shared.PET_KEY = "petbar"
Shared.MICRO_KEY = "micromenu"
Shared.MICRO_BAGS_GAP = 4
Shared.MICRO_ICON_CROP = 0.06
Shared.PET_ICON_CROP = 0.06

local COMPANION_FALLBACK = {
    buttonSize = 32,
    spacing = 0,
    microMenu = { enabled = true },
    bags = { enabled = true, compact = true },
    petBar = { showHotkeys = false, strata = "LOW", level = 35 },
}

function Shared:GetConfigSection(profile, section)
    if type(section) ~= "string" or section == "" then
        return nil
    end

    if type(profile) == "table" then
        local value = profile[section]
        if type(value) == "table" then
            return value
        end
    end

    if DB and DB.GetSection then
        local value = DB:GetSection(section)
        if type(value) == "table" then
            return value
        end
    end

    return nil
end

function Shared:GetCompanionCfg(profile)
    local value = self:GetConfigSection(profile, "companion")
    if type(value) == "table" then
        return value
    end
    return COMPANION_FALLBACK
end

function Shared:ClampButtonSize(value)
    local size = math.floor((tonumber(value) or 32) + 0.5)
    if size < 24 then size = 24 end
    if size > 60 then size = 60 end
    return size
end

function Shared:ClampSpacing(value)
    local spacing = math.floor((tonumber(value) or 0) + 0.5)
    if spacing < 0 then spacing = 0 end
    if spacing > 12 then spacing = 12 end
    return spacing
end

function Shared:ApplyFrameLayer(frame, strata, level)
    if not frame then return end
    if frame.GetFrameStrata and frame.SetFrameStrata then
        local okCur, cur = pcall(frame.GetFrameStrata, frame)
        if (not okCur) or cur ~= strata then
            pcall(frame.SetFrameStrata, frame, strata)
        end
    end
    if frame.GetFrameLevel and frame.SetFrameLevel then
        local lvl = tonumber(level)
        if type(lvl) ~= "number" then lvl = 10 end
        if lvl < 1 then lvl = 1 end
        if lvl > 200 then lvl = 200 end
        lvl = math.floor(lvl + 0.5)
        local okCur, cur = pcall(frame.GetFrameLevel, frame)
        if (not okCur) or cur ~= lvl then
            pcall(frame.SetFrameLevel, frame, lvl)
        end
    end
end

function Shared:IsInCombat()
    return InCombat()
end

function Shared:ShouldTakeOverMicroAndBags()
    if DB and DB.ShouldHideBlizzardActionBars then
        return DB:ShouldHideBlizzardActionBars()
    end
    return true
end

function Shared:ShouldManageMicroMenu(cp)
    return self:ShouldTakeOverMicroAndBags() and type(cp) == "table" and cp.microMenu.enabled ~= false
end

function Shared:ShouldManageBags(cp)
    return self:ShouldTakeOverMicroAndBags() and type(cp) == "table" and cp.bags.enabled ~= false
end

return Shared
