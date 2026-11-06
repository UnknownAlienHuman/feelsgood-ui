-- FeelsGoodUI: Secret Value helpers
--
-- Retail 12.1.5 rule: gate a value with canaccessvalue before any Lua
-- inspection. Opaque values may only travel directly into an exact native
-- sink that accepts them; pcall does not declassify or authorize inspection.

local _, ns = ...

local Secret = {}
ns.Secret = Secret

local oUF = _G.oUF
local issecret = _G.issecretvalue or _G.IsSecretValue
local canaccess = (oUF and oUF.CanAccessValue) or _G.canaccessvalue or _G.CanAccessValue
local canaccesstable = (oUF and oUF.CanAccessTable) or _G.canaccesstable or _G.CanAccessTable
local canaccessall = _G.canaccessallvalues or _G.CanAccessAllValues

Secret.IsSecretValue = (oUF and oUF.IsSecretValue) or issecret
Secret.NotSecretValue = (oUF and oUF.NotSecretValue) or nil
Secret.CanAccessValue = canaccess
Secret.CanAccessTable = canaccesstable
Secret.CanAccessAllValues = canaccessall

function Secret.IsSecret(v)
    local fn = Secret.IsSecretValue
    if type(fn) ~= "function" then
        return false
    end
    return fn(v) == true
end

function Secret.CanAccess(v)
    local fn = Secret.CanAccessValue
    if type(fn) == "function" then
        return fn(v) == true
    end

    -- Compatibility fallback for clients without the access predicate.
    return not Secret.IsSecret(v)
end

function Secret.IsRestricted(v)
    return not Secret.CanAccess(v)
end

function Secret.CanInspectTable(v)
    if not Secret.CanAccess(v) then
        return false
    end
    if type(v) ~= "table" then
        return false
    end

    local fn = Secret.CanAccessTable
    if type(fn) == "function" then
        return fn(v) == true
    end
    return true
end

function Secret.NotSecret(v)
    local fn = Secret.NotSecretValue
    if type(fn) == "function" then
        return fn(v) == true
    end
    if not Secret.CanAccess(v) then
        return false
    end
    return not Secret.IsSecret(v)
end

-- Returns an ordinary number only after the current caller is allowed to
-- inspect the value. It never probes arithmetic through pcall.
function Secret.TryPlainNumber(v)
    if not Secret.CanAccess(v) then
        return false, nil
    end
    if type(v) ~= "number" then
        return false, nil
    end
    return true, v
end

-- FontString:SetText is an exact one-way presentation sink for opaque text or
-- numbers. Do not read the value back after this call.
function Secret.SafeSetText(fs, v)
    if not fs then
        return false
    end

    if Secret.CanAccess(v) and v == nil then
        fs:SetText("")
    else
        fs:SetText(v)
    end
    return true
end

-- Formatting requires inspecting every argument. Restricted arguments are not
-- formatted; clear the target so callers can fall back to direct SetText.
function Secret.SafeSetFormattedText(fs, fmt, ...)
    if not fs then
        return false
    end
    if not Secret.CanAccess(fmt) or type(fmt) ~= "string" then
        fs:SetText("")
        return false
    end

    local count = select("#", ...)
    for i = 1, count do
        local value = select(i, ...)
        if not Secret.CanAccess(value) then
            fs:SetText("")
            return false
        end
    end

    fs:SetFormattedText(fmt, ...)
    return true
end

-- Returns either an ordinary display string or the original opaque value for a
-- direct visual sink. It never converts or compares a restricted value.
function Secret.TruncateWhenZero(v)
    if not Secret.CanAccess(v) then
        return v
    end
    if v == nil then
        return ""
    end

    local truncate = _G.C_StringUtil and _G.C_StringUtil.TruncateWhenZero
    if type(truncate) == "function" then
        local text = truncate(v)
        if not Secret.CanAccess(text) then
            return text
        end
        return text or ""
    end

    local okNum, n = Secret.TryPlainNumber(v)
    if okNum and n > 0 then
        return tostring(n)
    end
    return ""
end
