-- FeelsGoodUI: Secret Value helpers
--
-- WoW 12.0+ introduces "Secret Values" for many Unit/Aura/Cast APIs in instances/combat.
-- Rule: never do arithmetic/comparisons/boolean tests on secret values.
-- Visual APIs (SetText/SetValue/etc.) can accept secrets; Lua logic often cannot.
--
-- Strategy:
--  - Prefer oUF secret helpers when available (oUF 13+ / Midnight).
--  - Fallback to global issecretvalue/IsSecretValue if present.
--  - Provide safe formatting helpers that never explode on secrets.

local _, ns = ...

local Secret = {}
ns.Secret = Secret

local oUF = _G.oUF
local issecret = _G.issecretvalue or _G.IsSecretValue
local canaccess = (oUF and oUF.CanAccessValue) or _G.canaccessvalue or _G.CanAccessValue
local canaccessall = _G.canaccessallvalues or _G.CanAccessAllValues

-- Prefer oUF helpers when available.
Secret.IsSecretValue = (oUF and oUF.IsSecretValue) or issecret
Secret.NotSecretValue = (oUF and oUF.NotSecretValue) or nil
-- WoW 12.x exposes canaccessvalue/canaccessallvalues; oUF may proxy these.
Secret.CanAccessValue  = canaccess
Secret.CanAccessAllValues = canaccessall

local function CallBool(fn, v)
    if type(fn) ~= "function" then return false end
    local ok, res = pcall(fn, v)
    if not ok then return false end
    return res == true
end

function Secret.IsSecret(v)
    return CallBool(Secret.IsSecretValue, v)
end

function Secret.NotSecret(v)
    if type(Secret.NotSecretValue) == "function" then
        -- oUF.NotSecretValue may itself be secret-safe.
        local ok, res = pcall(Secret.NotSecretValue, v)
        if ok then return res == true end
    end
    return not Secret.IsSecret(v)
end

function Secret.CanAccess(v)
    local fn = Secret.CanAccessValue
    if type(fn) ~= "function" then
        -- If predicate API is missing, assume accessible to avoid breaking older clients.
        return true
    end
    local ok, res = pcall(fn, v)
    if not ok then return false end
    return res == true
end

-- "Plain" number = safe for Lua arithmetic/comparisons.
function Secret.TryPlainNumber(v)
    if type(v) ~= "number" then return false, nil end
    if Secret.IsSecret(v) then return false, v end
    return true, v
end

function Secret.SafeSetText(fs, v)
    if not fs then return end
    if v == nil then
        pcall(fs.SetText, fs, "")
        return
    end
    -- FontString:SetText can accept secret values.
    pcall(fs.SetText, fs, v)
end

function Secret.SafeSetFormattedText(fs, fmt, ...)
    if not fs then return end
    -- string.format can choke on secret values depending on format.
    local ok = pcall(fs.SetFormattedText, fs, fmt, ...)
    if ok then return end

    -- Fallback: stringify args without formatting.
    local n = select("#", ...)
    if n <= 0 then
        pcall(fs.SetText, fs, "")
        return
    end

    local out = ""
    for i = 1, n do
        local a = select(i, ...)
        if a ~= nil then
            if out ~= "" then out = out .. " " end
            local okS, s = pcall(tostring, a)
            if okS and s ~= nil then
                out = out .. s
            end
        end
    end
    pcall(fs.SetText, fs, out)
end

function Secret.TruncateWhenZero(v)
    if _G.C_StringUtil and _G.C_StringUtil.TruncateWhenZero then
        local ok, text = pcall(_G.C_StringUtil.TruncateWhenZero, v)
        if ok then return text or "" end
    end

    local okNum, n = Secret.TryPlainNumber(v)
    if okNum and n and n > 0 then
        return tostring(n)
    end
    return ""
end
