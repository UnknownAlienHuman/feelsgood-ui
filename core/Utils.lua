-- FeelsGoodUI: Utilities
--
-- IMPORTANT (WoW 12.0+): "Secret Values" may have type(v)=="number" but throw on
-- arithmetic/comparisons/tonumber/string.format("%d", v), etc.
--
-- Policy:
--  - Only treat something as a *plain number* if it survives a trivial arithmetic op in pcall.
--  - Any helper that performs math/comparisons must use pcall or first convert via TryNumber.

local _, ns = ...

local U = {}
ns.U = U

local Secret = ns.Secret

-- -----------------------------
-- Secret-safe numeric helpers
-- -----------------------------

local function IsFinitePlainNumber(n)
    if type(n) ~= "number" then return false end
    local ok, finite = pcall(function()
        -- Reject NaN and infinities to avoid rare formatting/math explosions in hot paths.
        return (n == n) and (n < math.huge) and (n > -math.huge)
    end)
    return ok and finite == true
end

--- Try to obtain a safe Lua number.
-- Returns: ok:boolean, n:number|nil
function U.TryNumber(v)
    if v == nil then return false, nil end

    -- WoW 12.x Secret Values may present as type=="number" but will throw on
    -- comparisons/arithmetic. We only treat a value as a plain number if it
    -- survives a trivial comparison inside pcall.
    if type(v) == "number" then
        -- If we have explicit secret detection (oUF / issecretvalue), prefer it.
        if Secret and Secret.IsSecret and Secret.IsSecret(v) then
            return false, nil
        end

        -- Use arithmetic (v + 0) rather than comparisons.
        -- Secret Values can sometimes survive comparisons but fail on math/formatting.
        local ok = pcall(function() return v + 0 end)
        if ok and IsFinitePlainNumber(v) then
            return true, v
        end
        return false, nil
    end

    if type(v) == "string" then
        local n = tonumber(v)
        if IsFinitePlainNumber(n) then
            return true, n
        end
        return false, nil
    end

    -- Last resort: guarded tostring->tonumber for unusual userdata.
    local okS, s = pcall(tostring, v)
    if okS and type(s) == "string" then
        local n = tonumber(s)
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
    local ok, s = pcall(tostring, v)
    if ok then return s end
    return ""
end

function U.Clamp(n, minV, maxV)
    local okN, nn = U.TryNumber(n)
    if not okN then return n end

    if minV ~= nil then
        local okMin, mn = U.TryNumber(minV)
        if okMin and nn < mn then nn = mn end
    end

    if maxV ~= nil then
        local okMax, mx = U.TryNumber(maxV)
        if okMax and nn > mx then nn = mx end
    end

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

    if minV ~= nil then
        local okMin, mn = U.TryNumber(minV)
        if okMin and nn < mn then nn = mn end
    end

    if maxV ~= nil then
        local okMax, mx = U.TryNumber(maxV)
        if okMax and nn > mx then nn = mx end
    end

    return nn
end

function U.Round(n)
    local okN, nn = U.TryNumber(n)
    if not okN then return n end

    local ok, r = pcall(function()
        return math.floor(nn + 0.5)
    end)

    if ok then return r end
    return n
end

-- -----------------------------
-- Numeric formatting
-- -----------------------------

-- Short number formatting (k/m/b) with Secret Value safety.
--
-- Returns: string|nil
--  - string: formatted value
--  - nil: not a plain number (caller should fallback to Secret-safe SetText)
--
-- opts:
--  - hideZero: boolean (default false)
--  - suffixCase: "lower"|"upper" (default "lower")
--  - decimalsSmall: number (default 1) decimals when unit value < 10
--  - decimalsLarge: number (default 0) decimals when unit value >= 10
function U.FormatNumberShort(v, opts)
    local ok, n = U.TryNumber(v)
    if not ok then return nil end

    opts = opts or {}
    if opts.hideZero and n == 0 then return "" end

    local abs = math.abs(n)
    local sign = (n < 0) and "-" or ""

    -- < 1000: show integer (no separators)
    if abs < 1000 then
        return sign .. tostring(U.Round(abs))
    end

    local units = {
        { 1e9,  "b" },
        { 1e6,  "m" },
        { 1e3,  "k" },
    }

    local idx = #units
    for i = 1, #units do
        if abs >= units[i][1] then
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

    -- Promote when rounding crosses 1000 (e.g. 999.5k -> 1.0m)
    while idx > 1 do
        local unitVal = units[idx][1]
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

    local unitVal = units[idx][1]
    local suffix = units[idx][2]
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
        -- Strip trailing ".0" to match expected style (e.g. 1.0m -> 1m)
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
    -- Merge `defaults` into `dst` recursively without overriding existing keys.
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

-- Texture coords helper: remove rounded corners from icons.
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
