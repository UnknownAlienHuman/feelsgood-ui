-- FeelsGoodUI: Diagnostics ring-buffer
-- Captures protected/taint-related warnings such as:
--  - ADDON_ACTION_BLOCKED
--  - ADDON_ACTION_FORBIDDEN
--  - MACRO_ACTION_FORBIDDEN
--
-- Lightweight: fixed-size ring, strings only.
-- Author: Neomorph

local _, ns = ...

local Diagnostics = {}
ns.Diagnostics = Diagnostics

local CAP = 200
local buf = {}
local head = 1
local count = 0

local function Now()
    return (GetTime and GetTime()) or 0
end

local function WrapIndex(i)
    return ((i - 1) % CAP) + 1
end

function Diagnostics:Capture(event, addonName, funcName, extra)
    local idx = WrapIndex(head + count)
    buf[idx] = {
        t = Now(),
        event = tostring(event or ""),
        addon = tostring(addonName or ""),
        func = tostring(funcName or ""),
        extra = tostring(extra or ""),
    }

    if count < CAP then
        count = count + 1
    else
        head = WrapIndex(head + 1)
    end
end

function Diagnostics:GetAll()
    local out = {}
    for i = 1, count do
        out[i] = buf[WrapIndex(head + i - 1)]
    end
    return out
end

function Diagnostics:Last()
    if count == 0 then return nil end
    return buf[WrapIndex(head + count - 1)]
end

function Diagnostics:Count()
    return count
end

function Diagnostics:Clear()
    for i = 1, CAP do
        buf[i] = nil
    end
    head = 1
    count = 0
end
