-- FeelsGoodUI: Bootstrap & globals
-- Author: Neomorph
-- Notes:
--  - Keep global namespace clean; expose a single global for debugging only.
--  - Avoid heavy allocations / OnUpdate unless explicitly required.

local ADDON_NAME, ns = ...

ns.ADDON_NAME = ADDON_NAME
ns.VERSION = C_AddOns and C_AddOns.GetAddOnMetadata and (C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "0.0.0") or "0.0.0"
ns.DEBUG_GLOBAL_NAME = "FeelsGoodUI"

function ns:ExposeDebugGlobal()
    local name = rawget(self, "DEBUG_GLOBAL_NAME")
    if type(name) ~= "string" or name == "" then
        return false
    end

    local current = rawget(_G, name)
    if current ~= nil and current ~= self then
        return false
    end

    rawset(_G, name, self)
    return true
end

function ns:HideDebugGlobal()
    local name = rawget(self, "DEBUG_GLOBAL_NAME")
    if type(name) ~= "string" or name == "" then
        return false
    end
    if rawget(_G, name) == self then
        rawset(_G, name, nil)
        return true
    end
    return false
end

-- Debug global stays opt-out, but publication is now explicit and owned by bootstrap.
ns:ExposeDebugGlobal()
