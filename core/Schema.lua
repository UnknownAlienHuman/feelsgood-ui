-- FeelsGoodUI: pure profile schema/reset/normalize policy

local _, ns = ...

local Schema = ns.Schema or {}
ns.Schema = Schema

local U = ns.U

local CURRENT_VERSION = 1
local UNITFRAME_SIZE_KEYS = { "player", "target", "focus", "targettarget", "pet" }
local UNITFRAME_SCALE_KEYS = { "player", "target", "focus", "targettarget", "pet" }

local VALID_POINTS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true,
    LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local RESOLUTION_PRESETS = {
    ["1080"] = {
        id = "1080",
        positionScale = 1.00,
        ufScale = 0.90,
        ufSizeScale = 1.00,
        centerScale = 0.90,
        centerWidthScale = 1.00,
        centerHeightScale = 1.00,
        actionButtonSize = 32,
        textScale = 1.00,
        cooldownScale = 1.00,
    },
    ["2k"] = {
        id = "2k",
        positionScale = 1.20,
        ufScale = 1.00,
        ufSizeScale = 1.12,
        centerScale = 1.00,
        centerWidthScale = 1.12,
        centerHeightScale = 1.10,
        actionButtonSize = 38,
        textScale = 1.10,
        cooldownScale = 1.08,
    },
    ["4k"] = {
        id = "4k",
        positionScale = 1.40,
        ufScale = 1.15,
        ufSizeScale = 1.30,
        centerScale = 1.15,
        centerWidthScale = 1.30,
        centerHeightScale = 1.22,
        actionButtonSize = 46,
        textScale = 1.22,
        cooldownScale = 1.18,
    },
    ["8k"] = {
        id = "8k",
        positionScale = 1.65,
        ufScale = 1.30,
        ufSizeScale = 1.60,
        centerScale = 1.30,
        centerWidthScale = 1.60,
        centerHeightScale = 1.40,
        actionButtonSize = 56,
        textScale = 1.35,
        cooldownScale = 1.30,
    },
}

local function RoundInt(n)
    if type(n) ~= "number" then
        return 0
    end
    if n >= 0 then
        return math.floor(n + 0.5)
    end
    return math.ceil(n - 0.5)
end

local function ClampInt(v, minV, maxV, fallback)
    local n = tonumber(v)
    if type(n) ~= "number" then
        n = fallback
    end
    if type(n) ~= "number" then
        n = minV
    end
    n = RoundInt(n)
    if n < minV then n = minV end
    if n > maxV then n = maxV end
    return n
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

local function ValidatePositions(profile, defaults)
    if type(profile) ~= "table" or type(defaults) ~= "table" then
        return
    end

    profile.positions = profile.positions or {}
    for key, def in pairs(defaults) do
        if type(def) == "table" then
            local pos = profile.positions[key]
            if type(pos) ~= "table" then
                profile.positions[key] = U.DeepCopy(def)
            else
                if type(pos.point) ~= "string" or not VALID_POINTS[pos.point] then
                    pos.point = def.point
                end
                if type(pos.relPoint) ~= "string" or not VALID_POINTS[pos.relPoint] then
                    pos.relPoint = def.relPoint
                end
                local okX, x = U.TryNumber(pos.x)
                local okY, y = U.TryNumber(pos.y)
                pos.x = okX and x or (def.x or 0)
                pos.y = okY and y or (def.y or 0)
            end
        end
    end
end

local function PurgeLegacyProfileFields(profile)
    if type(profile) ~= "table" then
        return
    end

    profile.cooldownViewer = nil
    profile.customBars = nil
    profile.weakBars = nil

    local positions = profile.positions
    if type(positions) == "table" then
        positions.cooldownviewer = nil
        positions.actionbar6 = nil
        positions.actionbar7 = nil
    end

    local actionbars = profile.actionbars
    if type(actionbars) == "table" then
        actionbars._bar45Imported = nil
        actionbars.keepMicroBags = nil
        actionbars.compactBags = nil

        if type(actionbars.bars) == "table" then
            actionbars.bars[6] = nil
            actionbars.bars[7] = nil
        end

        if type(actionbars.layering) == "table" then
            actionbars.layering.petBarStrata = nil
            actionbars.layering.petBarLevel = nil
            if next(actionbars.layering) == nil then
                actionbars.layering = nil
            end
        end
    end

    local options = profile.options
    if type(options) == "table" and type(options.livePreview) == "table" then
        options.livePreview.cooldownViewer = nil
    end
end

local function DetectResolutionPreset()
    local w, h = nil, nil

    if _G.GetPhysicalScreenSize then
        local ok, sw, sh = pcall(_G.GetPhysicalScreenSize)
        if ok then
            w = tonumber(sw)
            h = tonumber(sh)
        end
    end

    if (type(h) ~= "number" or h <= 0) and _G.GetScreenWidth and _G.GetScreenHeight then
        local okW, sw = pcall(_G.GetScreenWidth)
        local okH, sh = pcall(_G.GetScreenHeight)
        if okW then w = tonumber(sw) end
        if okH then h = tonumber(sh) end
    end

    local key = "1080"
    if type(h) == "number" then
        if h >= 4320 then
            key = "8k"
        elseif h >= 2160 then
            key = "4k"
        elseif h >= 1440 then
            key = "2k"
        else
            key = "1080"
        end
    end

    return key, w, h
end

local function ScalePositions(positions, mul)
    if type(positions) ~= "table" or type(mul) ~= "number" or mul == 1 then
        return
    end

    for _, pos in pairs(positions) do
        if type(pos) == "table" then
            if type(pos.x) == "number" then
                pos.x = RoundInt(pos.x * mul)
            end
            if type(pos.y) == "number" then
                pos.y = RoundInt(pos.y * mul)
            end
        end
    end
end

local function ApplyResolutionPreset(profile, presetKey, screenW, screenH)
    if type(profile) ~= "table" then
        return
    end

    local preset = RESOLUTION_PRESETS[presetKey] or RESOLUTION_PRESETS["1080"]
    if type(preset) ~= "table" then
        return
    end

    ScalePositions(profile.positions, preset.positionScale)

    profile.unitframes = profile.unitframes or {}
    local uf = profile.unitframes
    uf.scales = (type(uf.scales) == "table") and uf.scales or {}
    uf.sizes = (type(uf.sizes) == "table") and uf.sizes or {}

    for i = 1, #UNITFRAME_SCALE_KEYS do
        local unit = UNITFRAME_SCALE_KEYS[i]
        uf.scales[unit] = ClampNum(preset.ufScale, 0.60, 1.30, 0.90)
    end

    for i = 1, #UNITFRAME_SIZE_KEYS do
        local unit = UNITFRAME_SIZE_KEYS[i]
        local size = uf.sizes[unit]
        size = (type(size) == "table") and size or {}
        local baseW = tonumber(size.width) or 160
        local baseH = tonumber(size.height) or 20
        size.width = ClampInt(baseW * preset.ufSizeScale, 120, 520, 160)
        size.height = ClampInt(baseH * preset.ufSizeScale, 14, 40, 20)
        uf.sizes[unit] = size
    end

    uf.text = (type(uf.text) == "table") and uf.text or {}
    uf.text.size = ClampInt((tonumber(uf.text.size) or 12) * preset.textScale, 8, 28, 12)

    uf.castbar = (type(uf.castbar) == "table") and uf.castbar or {}
    uf.castbar.height = ClampInt((tonumber(uf.castbar.height) or 14) * preset.ufSizeScale, 8, 24, 14)

    uf.targetInfo = (type(uf.targetInfo) == "table") and uf.targetInfo or {}
    uf.targetInfo.fontSize = ClampInt((tonumber(uf.targetInfo.fontSize) or 12) * preset.textScale, 8, 28, 12)
    uf.targetInfo.powerHeight = ClampInt((tonumber(uf.targetInfo.powerHeight) or 10) * preset.ufSizeScale, 6, 20, 10)

    profile.center = (type(profile.center) == "table") and profile.center or {}
    local center = profile.center
    center.scale = ClampNum(preset.centerScale, 0.60, 1.30, 0.90)
    center.width = ClampInt((tonumber(center.width) or 420) * preset.centerWidthScale, 200, 900, 420)
    center.resourceHeight = ClampInt((tonumber(center.resourceHeight) or 10) * preset.centerHeightScale, 6, 24, 10)
    center.powerHeight = ClampInt((tonumber(center.powerHeight) or 12) * preset.centerHeightScale, 6, 24, 12)
    center.spacing = ClampInt((tonumber(center.spacing) or 5) * preset.centerHeightScale, 0, 20, 5)

    profile.actionbars = (type(profile.actionbars) == "table") and profile.actionbars or {}
    profile.actionbars.buttonSize = ClampInt(preset.actionButtonSize, 24, 60, 32)

    profile.companion = (type(profile.companion) == "table") and profile.companion or {}
    profile.companion.buttonSize = ClampInt(preset.actionButtonSize, 24, 60, 32)

    profile.install = (type(profile.install) == "table") and profile.install or {}
    profile.install.resolutionPresetApplied = true
    profile.install.resolutionPreset = preset.id or presetKey or "1080"
    if type(screenW) == "number" then
        profile.install.screenWidth = RoundInt(screenW)
    end
    if type(screenH) == "number" then
        profile.install.screenHeight = RoundInt(screenH)
    end
end

Schema.CURRENT_VERSION = CURRENT_VERSION

local function BuildProfileCompatibilityState(profile)
    local hadProfile = type(profile) == "table"
    local oldVersion = hadProfile and tonumber(profile.version) or nil
    local status

    if not hadProfile then
        status = "missing_or_invalid"
    elseif type(oldVersion) ~= "number" then
        status = "missing_or_invalid"
    elseif oldVersion == CURRENT_VERSION then
        status = "current"
    elseif oldVersion < CURRENT_VERSION then
        status = "unsupported_older"
    else
        status = "future_version"
    end

    return {
        currentVersion = CURRENT_VERSION,
        hadProfile = hadProfile,
        oldVersion = oldVersion,
        status = status,
        needsReset = status ~= "current",
        canImport = status == "current",
    }
end

function Schema.GetCurrentVersion()
    return CURRENT_VERSION
end

function Schema.GetProfileState(profile)
    return BuildProfileCompatibilityState(profile)
end

function Schema.CreateFreshProfile(defaultProfile)
    if type(defaultProfile) ~= "table" then
        return { version = CURRENT_VERSION }
    end

    local profile = U.DeepCopy(defaultProfile)
    local presetKey, screenW, screenH = DetectResolutionPreset()
    ApplyResolutionPreset(profile, presetKey, screenW, screenH)
    profile.version = CURRENT_VERSION
    return profile
end

function Schema.NormalizeProfile(profile, defaultProfile)
    if type(profile) ~= "table" then
        return profile
    end

    profile.version = CURRENT_VERSION
    if type(defaultProfile) == "table" and type(defaultProfile.positions) == "table" then
        ValidatePositions(profile, defaultProfile.positions)
    end
    PurgeLegacyProfileFields(profile)
    return profile
end
