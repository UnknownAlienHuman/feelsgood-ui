-- FeelsGoodUI: UnitFrames secret-safe text helpers

local _, ns = ...

local Text = {}
ns.UnitFramesText = Text

local U = ns.U
local Secret = ns.Secret

local IsSecretFn = (Secret and Secret.IsSecretValue) or _G.issecretvalue or _G.IsSecretValue

local function CanInspect(v)
    if Secret and Secret.CanAccess then
        return Secret.CanAccess(v)
    end
    if type(IsSecretFn) == "function" then
        return IsSecretFn(v) ~= true
    end
    return true
end

-- Kept under the historical name because render/target modules already use it
-- as their opaque-value guard. A value that cannot be inspected is treated as
-- opaque even when a separate secrecy classifier is unavailable.
function Text.IsSecretValue(v)
    if not CanInspect(v) then
        return true
    end
    if Secret and Secret.IsSecret then
        return Secret.IsSecret(v)
    end
    if type(IsSecretFn) == "function" then
        return IsSecretFn(v) == true
    end
    return false
end

function Text.SafeSetText(fs, v)
    if not fs then return false end

    if Secret and Secret.SafeSetText then
        return Secret.SafeSetText(fs, v)
    end

    if Text.IsSecretValue(v) then
        fs:SetText(v)
    elseif v == nil then
        fs:SetText("")
    else
        fs:SetText(v)
    end
    return true
end

function Text.FormatNumberShort(cache, v)
    if Text.IsSecretValue(v) then
        return nil
    end
    local shortFmt = type(cache) == "table" and cache.shortFmt or nil
    return U.FormatNumberShort(v, shortFmt)
end

function Text.FormatNumberFull(v)
    local ok, n = U.TryNumber(v)
    if not ok then return nil end

    local rounded = U.Round(n)
    if _G.BreakUpLargeNumbers then
        local okString, text = pcall(_G.BreakUpLargeNumbers, rounded)
        if okString and type(text) == "string" then
            return text
        end
    end

    return tostring(rounded)
end

function Text.ShouldShortenUnit(cache, unit)
    if unit ~= "player" and unit ~= "target" and unit ~= "targettarget" and unit ~= "focus" then
        return false
    end

    if type(cache) ~= "table" or cache.shortEnabled ~= true then
        return false
    end

    local shortUnits = cache.shortUnits
    if type(shortUnits) == "table" then
        return shortUnits[unit] == true
    end

    return true
end

return Text
