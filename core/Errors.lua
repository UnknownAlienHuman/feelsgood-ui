-- FeelsGoodUI: Errors ring-buffer
-- Captures runtime failures from safe-dispatched handlers (Safety.Dispatch).
-- Stores only strings + timestamps; no heavy allocations.

local _, ns = ...

local Errors = {}
ns.Errors = Errors

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

function Errors:Capture(src, msg, stack)
    local idx = WrapIndex(head + count)
    buf[idx] = {
        t = Now(),
        src = tostring(src or ""),
        msg = tostring(msg or ""),
        stack = tostring(stack or ""),
    }

    if count < CAP then
        count = count + 1
    else
        head = WrapIndex(head + 1)
    end
end

function Errors:GetAll()
    local out = {}
    for i = 1, count do
        out[i] = buf[WrapIndex(head + i - 1)]
    end
    return out
end

function Errors:Last()
    if count == 0 then return nil end
    return buf[WrapIndex(head + count - 1)]
end

function Errors:Clear()
    for i = 1, CAP do
        buf[i] = nil
    end
    head = 1
    count = 0
end
