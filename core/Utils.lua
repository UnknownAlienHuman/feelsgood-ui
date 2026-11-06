-- FeelsGoodUI: Utilities
--
-- Retail 12.1.5 Secret Values must be gated before nil/equality checks, type,
-- arithmetic, comparison, conversion, formatting, logging, or persistence.
-- pcall is error containment only; it is never an access probe.

local _, ns = ...

local U = {}
ns.U = U

local Secret = ns.Secret
local EMPTY_OPTIONS = {}
local SHORT_UNITS = {
    { 1e9, "b" },
    { 1e6, "m" },
    { 1e3, "k" },
}

-- -----------------------------
-- Secret-safe numeric helpers
-- -----------------------------

local function CanInspect(v)
    if Secret and Secret.CanAccess then
        return Secret.CanAccess(v)
    end
    if Secret and Secret.IsSecret and Secret.IsSecret(v) then
        return false
    end
    return true
end

local function IsFinitePlainNumber(n)
    return type(n) == "number"
        and n == n
        and n < math.huge
        and n > -math.huge
end

--- Try to obtain an ordinary Lua number.
-- Returns: ok:boolean, n:number|nil
function U.TryNumber(v)
    if not CanInspect(v) then
        return false, nil
    end
    if v == nil then
        return false, nil
    end

    local valueType = type(v)
    if valueType == "number" then
        if IsFinitePlainNumber(v) then
            return true, v
        end
        return false, nil
    end

    if valueType == "string" then
        local n = tonumber(v)
        if IsFinitePlainNumber(n) then
            return true, n
        end
    end

    return false, nil
end

function U.IsPlainNumber(v)
    local ok = U.TryNumber(v)
    return ok
end

function U.SafeToString(v)
    if not CanInspect(v) then
        return ""
    end
    if v == nil then
        return ""
    end
    return tostring(v)
end

function U.Clamp(n, minV, maxV)
    local okN, nn = U.TryNumber(n)
    if not okN then return n end

    local okMin, mn = U.TryNumber(minV)
    if okMin and nn < mn then nn = mn end

    local okMax, mx = U.TryNumber(maxV)
    if okMax and nn > mx then nn = mx end

    return nn
end

function U.ClampWithFallback(n, minV, maxV, fallback)
    local okN, nn = U.TryNumber(n)
    if not okN then
        local okF, fn = U.TryNumber(fallback)
        if not okF then
            return fallback
        end
        nn = fn
    end

    local okMin, mn = U.TryNumber(minV)
    if okMin and nn < mn then nn = mn end

    local okMax, mx = U.TryNumber(maxV)
    if okMax and nn > mx then nn = mx end

    return nn
end

function U.Round(n)
    local okN, nn = U.TryNumber(n)
    if not okN then return n end
    return math.floor(nn + 0.5)
end

-- -----------------------------
-- Numeric formatting
-- -----------------------------

-- Short number formatting (k/m/b) with Secret Value safety.
--
-- Returns: string|nil
--  - string: formatted value
--  - nil: value is unavailable for Lua inspection; caller should use a direct
--    visual sink or an explicit unavailable state.
--
-- opts:
--  - hideZero: boolean (default false)
--  - suffixCase: "lower"|"upper" (default "lower")
--  - decimalsSmall: number (default 1) decimals when unit value < 10
--  - decimalsLarge: number (default 0) decimals when unit value >= 10
function U.FormatNumberShort(v, opts)
    -- Formatting is not an opaque sink. Return an explicit unavailable display
    -- state so callers never fall through to exception-based format probes.
    if not CanInspect(v) then return "" end

    local ok, n = U.TryNumber(v)
    if not ok then return nil end

    opts = opts or EMPTY_OPTIONS
    if opts.hideZero and n == 0 then return "" end

    local abs = math.abs(n)
    local sign = (n < 0) and "-" or ""

    if abs < 1000 then
        return sign .. tostring(U.Round(abs))
    end

    local idx = #SHORT_UNITS
    for i = 1, #SHORT_UNITS do
        if abs >= SHORT_UNITS[i][1] then
            idx = i
            break
        end
    end

    local decimalsSmall = tonumber(opts.decimalsSmall)
    if decimalsSmall == nil then decimalsSmall = 1 end
    if decimalsSmall < 0 then decimalsSmall = 0 end
    if decimalsSmall > 2 then decimalsSmall = 2 end

    local decimalsLarge = tonumber(opts.decimalsLarge)
    if decimalsLarge == nil then decimalsLarge = 0 end
    if decimalsLarge < 0 then decimalsLarge = 0 end
    if decimalsLarge > 2 then decimalsLarge = 2 end

    -- Promote when rounding crosses 1000 (for example, 999.5k -> 1m).
    while idx > 1 do
        local unitVal = SHORT_UNITS[idx][1]
        local base = abs / unitVal
        local decimals = (base < 10) and decimalsSmall or decimalsLarge
        local pow10 = (decimals == 0) and 1 or (10 ^ decimals)
        local rounded = math.floor(base * pow10 + 0.5) / pow10
        if rounded >= 1000 then
            idx = idx - 1
        else
            break
        end
    end

    local unitVal = SHORT_UNITS[idx][1]
    local suffix = SHORT_UNITS[idx][2]
    if opts.suffixCase == "upper" then
        suffix = string.upper(suffix)
    end

    local base = abs / unitVal
    local decimals = (base < 10) and decimalsSmall or decimalsLarge
    local pow10 = (decimals == 0) and 1 or (10 ^ decimals)
    local rounded = math.floor(base * pow10 + 0.5) / pow10

    local fmt = string.format("%%.%df", decimals)
    local s = string.format(fmt, rounded)
    if decimals > 0 then
        s = s:gsub("%.0+$", "")
    end

    return sign .. s .. suffix
end

-- -----------------------------
-- Tables
-- -----------------------------

function U.CopyTableShallow(src, dst)
    dst = dst or {}
    if type(src) ~= "table" then return dst end
    for k, v in pairs(src) do
        dst[k] = v
    end
    return dst
end

function U.DeepCopy(src, dst, seen)
    if type(src) ~= "table" then return src end
    seen = seen or {}
    if seen[src] then return seen[src] end

    dst = dst or {}
    seen[src] = dst
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = U.DeepCopy(v, nil, seen)
        else
            dst[k] = v
        end
    end
    return dst
end

function U.MergeDefaults(dst, defaults)
    if type(dst) ~= "table" then dst = {} end
    if type(defaults) ~= "table" then return dst end

    for k, v in pairs(defaults) do
        if dst[k] == nil then
            if type(v) == "table" then
                dst[k] = U.DeepCopy(v)
            else
                dst[k] = v
            end
        elseif type(v) == "table" and type(dst[k]) == "table" then
            U.MergeDefaults(dst[k], v)
        end
    end
    return dst
end

-- -----------------------------
-- Textures
-- -----------------------------

function U.IconTexCoord(inset)
    local okInset, ii = U.TryNumber(inset)
    if not okInset then ii = 0.08 end
    return ii, 1 - ii, ii, 1 - ii
end

-- -----------------------------
-- UI frame helpers
-- -----------------------------

U.VALID_FRAME_STRATA = U.VALID_FRAME_STRATA or {
    BACKGROUND = true,
    LOW = true,
    MEDIUM = true,
    HIGH = true,
    DIALOG = true,
    FULLSCREEN = true,
    FULLSCREEN_DIALOG = true,
    TOOLTIP = true,
}

function U.NormalizeFrameStrata(strata, fallback)
    if type(strata) == "string" and U.VALID_FRAME_STRATA[strata] then
        return strata
    end
    return fallback
end

function U.NormalizeFrameLevel(level, fallback, minLevel, maxLevel)
    local v = tonumber(level)
    if type(v) ~= "number" then
        v = tonumber(fallback) or 10
    end
    v = math.floor(v + 0.5)
    minLevel = tonumber(minLevel) or 1
    maxLevel = tonumber(maxLevel) or 200
    if v < minLevel then v = minLevel end
    if v > maxLevel then v = maxLevel end
    return v
end

function U.ApplyFrameLayer(frame, strata, level, fallbackLevel)
    if not frame then return end

    if frame.GetFrameStrata and frame.SetFrameStrata then
        local targetStrata = U.NormalizeFrameStrata(strata, "LOW")
        local okCur, cur = pcall(frame.GetFrameStrata, frame)
        if (not okCur) or cur ~= targetStrata then
            pcall(frame.SetFrameStrata, frame, targetStrata)
        end
    end

    if frame.GetFrameLevel and frame.SetFrameLevel then
        local targetLevel = U.NormalizeFrameLevel(level, fallbackLevel or 10, 1, 200)
        local okCur, cur = pcall(frame.GetFrameLevel, frame)
        if (not okCur) or cur ~= targetLevel then
            pcall(frame.SetFrameLevel, frame, targetLevel)
        end
    end
end

function U.ResolveBarSpacing(spacing, maxSpacing)
    local maxV = tonumber(maxSpacing)
    if type(maxV) ~= "number" then
        maxV = 12
    end
    local v = tonumber(spacing) or 0
    if v < 0 then v = 0 end
    if v > maxV then v = maxV end
    if v <= 1 then return 0 end
    return v
end

function U.GetCooldownTimerText(cooldownFrame, cacheField)
    if not cooldownFrame then return nil end
    cacheField = cacheField or "_fguiTimerText"

    local cached = cooldownFrame[cacheField]
    if cached and cached.GetObjectType and cached:GetObjectType() == "FontString" then
        return cached
    end

    local regions = { cooldownFrame:GetRegions() }
    for i = 1, #regions do
        local region = regions[i]
        if region and region.GetObjectType and region:GetObjectType() == "FontString" then
            cooldownFrame[cacheField] = region
            return region
        end
    end

    return nil
end
