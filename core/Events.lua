-- FeelsGoodUI: Event dispatcher
-- Centralized events to avoid multiple frames, reduce allocations and keep order deterministic.

local _, ns = ...

local Addon = ns
ns.Addon = Addon

local Perf = ns.Perf
local Safety = ns.Safety

local f = CreateFrame("Frame")
Addon._eventFrame = f

local function OnEvent(_, event, ...)
    if Perf and Perf.enabled then
        Perf._eventsTotal = (Perf._eventsTotal or 0) + 1
    end
    local handler = Addon[event]
    if not handler then return end

    if Safety and Safety.Dispatch then
        Safety.Dispatch(Addon, event, handler, ...)
    else
        handler(Addon, ...)
    end
end

f:SetScript("OnEvent", OnEvent)
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

-- Taint/protected warnings (Stage 45+ diagnostics)
f:RegisterEvent("ADDON_ACTION_BLOCKED")
f:RegisterEvent("ADDON_ACTION_FORBIDDEN")
f:RegisterEvent("MACRO_ACTION_FORBIDDEN")

-- Common UI lifecycle events (safe, low frequency)
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
