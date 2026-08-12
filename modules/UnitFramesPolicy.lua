-- FeelsGoodUI: UnitFrames cache/profile and mover policy helpers

local _, ns = ...

local Policy = {}
ns.UnitFramesPolicy = Policy

local DB = ns.DB
local Theme = ns.Theme

Policy.Cache = Policy.Cache or { _ready = false, shortFmt = {} }
local Cache = Policy.Cache

local function GetSectionTable(profile, section)
    if type(profile) == "table" then
        local value = profile[section]
        if type(value) ~= "table" then
            value = {}
            profile[section] = value
        end
        return value
    end

    if DB and DB.GetSection then
        local value = DB:GetSection(section)
        if type(value) == "table" then
            return value
        end
    end

    return {}
end

function Policy.GetFormatCfg(profile)
    return GetSectionTable(profile, "format")
end

function Policy.GetStyleCfg(profile)
    return GetSectionTable(profile, "style")
end

function Policy.GetUnitFramesCfg(profile)
    return GetSectionTable(profile, "unitframes")
end

function Policy.GetSharedFontToken()
    if Theme and Theme.GetFontToken then
        return Theme:GetFontToken()
    end
    local theme = Theme and Theme.Get and Theme:Get() or nil
    return (theme and theme.fonts and theme.fonts.primary) or "Fonts\\FRIZQT__.TTF"
end

function Policy.GetSharedStatusbarToken()
    if Theme and Theme.GetStatusbarToken then
        return Theme:GetStatusbarToken()
    end
    local theme = Theme and Theme.Get and Theme:Get() or nil
    return (theme and theme.statusbars and theme.statusbars.primary) or "Interface/Buttons/WHITE8x8"
end

local function ClampNum(v, minV, maxV, fallback)
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
    return math.floor(ClampNum(v, minV, maxV, fallback) + 0.5)
end

function Policy.RefreshCache(profile)
    Cache._ready = true

    local format = Policy.GetFormatCfg(profile)
    local sn = (type(format.shortNumbers) == "table") and format.shortNumbers or {}
    Cache.shortEnabled = sn.enabled == true
    Cache.shortUnits = (type(sn.units) == "table") and sn.units or nil
    Cache.shortFmt = Cache.shortFmt or {}
    Cache.shortFmt.suffixCase = sn.suffixCase or "lower"
    Cache.shortFmt.decimalsSmall = sn.decimalsSmall
    Cache.shortFmt.decimalsLarge = sn.decimalsLarge

    local style = Policy.GetStyleCfg(profile)
    Cache.iconInset = (type(style.iconInset) == "number" and style.iconInset) or 0.08
    Cache.borderSize = (type(style.borderSize) == "number" and style.borderSize) or 1

    local uf = Policy.GetUnitFramesCfg(profile)
    local t = uf.text or {}
    Cache.font = t.font or Policy.GetSharedFontToken()
    Cache.auraFont = Cache.font
    Cache.combatHz = (uf.combatTimer and uf.combatTimer.updateHz) or 5
    Cache.targetInfo = uf.targetInfo or {}
    Cache.targetAuras = uf.targetAuras or {}

    local colors = (type(uf.colors) == "table") and uf.colors or {}
    local fallback = (type(colors.targetFallback) == "table") and colors.targetFallback or {}
    Cache.healthColor = Cache.healthColor or {}
    Cache.healthColor.useClassColorForEnemyPlayers = (colors.useClassColorForEnemyPlayers ~= false)
    Cache.healthColor.useReactionColorForNPC = (colors.useReactionColorForNPC ~= false)
    Cache.healthColor.fallbackR = ClampNum(fallback.r, 0.00, 1.00, 0.12)
    Cache.healthColor.fallbackG = ClampNum(fallback.g, 0.00, 1.00, 0.12)
    Cache.healthColor.fallbackB = ClampNum(fallback.b, 0.00, 1.00, 0.12)
    Cache.healthColor.fallbackA = ClampNum(fallback.a, 0.00, 1.00, 1.00)

    local low = (type(uf.playerLowHP) == "table") and uf.playerLowHP or {}
    local lowColor = (type(low.color) == "table") and low.color or {}
    Cache.lowHPEnabled = (low.enabled ~= false)
    Cache.lowHPThreshold = ClampNum(low.threshold, 5, 80, 30)
    Cache.lowHPMaxAlpha = ClampNum(low.maxAlpha, 0.10, 1.00, 0.65)
    Cache.lowHPColor = Cache.lowHPColor or {}
    Cache.lowHPColor.r = ClampNum(lowColor.r, 0.00, 1.00, 1.00)
    Cache.lowHPColor.g = ClampNum(lowColor.g, 0.00, 1.00, 0.12)
    Cache.lowHPColor.b = ClampNum(lowColor.b, 0.00, 1.00, 0.12)
    Cache.lowHPColor.a = ClampNum(lowColor.a, 0.00, 1.00, 1.00)
end

function Policy.EnsureCache()
    if not Cache._ready then
        Policy.RefreshCache()
    end
end

local UF_SIZE_UNITS = {
    player = true,
    target = true,
    focus = true,
    targettarget = true,
    pet = true,
}

local UF_SCALE_UNITS = {
    player = true,
    target = true,
    focus = true,
    targettarget = true,
    pet = true,
}

local function GetDefaultUFSize(defUF, unit)
    local sizes = (type(defUF) == "table" and type(defUF.sizes) == "table") and defUF.sizes or nil
    local entry = sizes and sizes[unit] or nil
    local fallback = sizes and sizes.player or nil
    local width = tonumber(entry and entry.width) or tonumber(fallback and fallback.width) or 160
    local height = tonumber(entry and entry.height) or tonumber(fallback and fallback.height) or 20
    return width, height
end

function Policy.NormalizeUFSizeTables(uf, defUF)
    if type(uf) ~= "table" then return end
    uf.sizes = (type(uf.sizes) == "table") and uf.sizes or {}

    local units = { "player", "target", "focus", "targettarget", "pet" }
    for i = 1, #units do
        local unit = units[i]
        local s = uf.sizes[unit]
        if type(s) ~= "table" then
            s = {}
            uf.sizes[unit] = s
        end
        local baseW, baseH = GetDefaultUFSize(defUF, unit)
        if type(s.width) ~= "number" then s.width = baseW end
        if type(s.height) ~= "number" then s.height = baseH end
    end
end

function Policy.GetUnitFrameSize(uf, defUF, unit)
    local defaultW, defaultH = GetDefaultUFSize(defUF, unit)
    if not UF_SIZE_UNITS[unit] then
        return defaultW, defaultH
    end

    local sizes = uf.sizes
    local s = (type(sizes) == "table") and sizes[unit] or nil
    if type(s) ~= "table" then
        return defaultW, defaultH
    end

    local w = (type(s.width) == "number") and s.width or defaultW
    local h = (type(s.height) == "number") and s.height or defaultH
    return w, h
end

local function GetDefaultUFScale(defUF, unit)
    local scales = (type(defUF) == "table" and type(defUF.scales) == "table") and defUF.scales or nil
    local scale = tonumber(scales and scales[unit]) or tonumber(scales and scales.player) or 1
    return scale
end

function Policy.NormalizeUFScaleTables(uf, defUF)
    if type(uf) ~= "table" then return end

    uf.scales = (type(uf.scales) == "table") and uf.scales or {}

    local units = { "player", "target", "focus", "targettarget", "pet" }
    for i = 1, #units do
        local unit = units[i]
        if type(uf.scales[unit]) ~= "number" then
            uf.scales[unit] = GetDefaultUFScale(defUF, unit)
        end
    end
end

function Policy.GetUnitFrameScale(uf, defUF, unit)
    local defaultScale = GetDefaultUFScale(defUF, unit)
    if not UF_SCALE_UNITS[unit] then
        return defaultScale
    end

    local scales = uf.scales
    local s = (type(scales) == "table") and scales[unit] or nil
    if type(s) ~= "number" then
        return defaultScale
    end
    return s
end

function Policy.CreateUnitMoverSpec(unit, label)
    local spec = {
        label = label,
        applyKeys = "unitframes",
        positionKey = unit,
        getScale = function()
            local uf = Policy.GetUnitFramesCfg()
            local defUF = (DB.defaults and DB.defaults.profile and DB.defaults.profile.unitframes) or {}
            Policy.NormalizeUFScaleTables(uf, defUF)
            return Policy.GetUnitFrameScale(uf, defUF, unit)
        end,
        setScale = function(value)
            local uf = Policy.GetUnitFramesCfg()
            local defUF = (DB.defaults and DB.defaults.profile and DB.defaults.profile.unitframes) or {}
            Policy.NormalizeUFScaleTables(uf, defUF)
            uf.scales[unit] = ClampNum(value, 0.60, 1.30, GetDefaultUFScale(defUF, unit))
        end,
    }

    if unit ~= "pet" then
        spec.getSize = function()
            local uf = Policy.GetUnitFramesCfg()
            local defUF = (DB.defaults and DB.defaults.profile and DB.defaults.profile.unitframes) or {}
            Policy.NormalizeUFSizeTables(uf, defUF)
            return Policy.GetUnitFrameSize(uf, defUF, unit)
        end

        spec.setSize = function(width, height)
            local uf = Policy.GetUnitFramesCfg()
            local defUF = (DB.defaults and DB.defaults.profile and DB.defaults.profile.unitframes) or {}
            Policy.NormalizeUFSizeTables(uf, defUF)

            local entry = uf.sizes and uf.sizes[unit]
            if type(entry) ~= "table" then
                entry = {}
                uf.sizes[unit] = entry
            end

            local fallbackW, fallbackH = GetDefaultUFSize(defUF, unit)
            entry.width = ClampWhole(width, 120, 520, fallbackW)
            entry.height = ClampWhole(height, 14, 40, fallbackH)
        end
    end

    return spec
end

return Policy
