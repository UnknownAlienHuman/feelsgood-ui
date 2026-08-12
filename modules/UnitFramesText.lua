-- FeelsGoodUI: UnitFrames secret-safe text helpers

local _, ns = ...

local Text = {}
ns.UnitFramesText = Text

local U = ns.U
local Secret = ns.Secret

local IsSecretFn = (Secret and Secret.IsSecretValue) or _G.issecretvalue or _G.IsSecretValue

function Text.IsSecretValue(v)
    if Secret and Secret.IsSecret then
        return Secret.IsSecret(v)
    end
    return (IsSecretFn and IsSecretFn(v)) == true
end

function Text.SafeSetText(fs, v)
    if not fs then return end

    if Secret and Secret.SafeSetText then
        Secret.SafeSetText(fs, v)
        return
    end

    if not v then
        fs:SetText("")
        return
    end

    if Text.IsSecretValue(v) then
        fs:SetText(v)
        return
    end

    fs:SetText(v)
end

function Text.FormatNumberShort(cache, v)
    local shortFmt = type(cache) == "table" and cache.shortFmt or nil
    return U.FormatNumberShort(v, shortFmt) or ""
end

function Text.TryBlizzardAbbrev(v)
    local fns = {
        _G.AbbreviateNumbers,
        _G.AbbreviateLargeNumbers,
        _G.AbbreviateNumber,
        _G.AbbreviateLargeNumber,
    }

    for i = 1, #fns do
        local fn = fns[i]
        if type(fn) == "function" then
            local ok, res = pcall(fn, v)
            if ok then
                local okNil, isNil = pcall(function() return res == nil end)
                if not (okNil and isNil) then
                    local secretish = false
                    local okSecret, isSecret = pcall(Text.IsSecretValue, res)
                    if okSecret and isSecret == true then
                        secretish = true
                    end

                    if (not secretish) and Secret and type(Secret.CanAccessValue) == "function" then
                        local okAccess, canAccess = pcall(Secret.CanAccessValue, res)
                        if okAccess and canAccess == false then
                            secretish = true
                        end
                    end

                    if secretish then
                        return true, res
                    end

                    local okType, valueType = pcall(type, res)
                    if okType and valueType == "string" then
                        local okNormalize, normalized = pcall(function()
                            return (res:gsub("K", "k"):gsub("M", "m"):gsub("B", "b"))
                        end)
                        if okNormalize and normalized ~= nil then
                            return true, normalized
                        end
                    end

                    return true, res
                end
            end
        end
    end

    return false, nil
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
