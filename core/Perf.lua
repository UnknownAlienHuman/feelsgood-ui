-- FeelsGoodUI: Lightweight performance counters + debug overlay
--
-- Stage 44: perf pass
--  - Counters: events/sec, apply queue flushes/sec, a few hot-path call counters.
--  - Timings: last apply times per module (ms).
--  - Memory: current Lua memory (KB).
--
-- Goals:
--  - Near-zero overhead when disabled.
--  - When enabled: readable, low-frequency refresh (1 Hz) only while visible.
--  - No permanent OnUpdate loops.

local _, ns = ...

local Perf = {}
ns.Perf = Perf

local DB  = ns.DB
local Log = ns.Log

Perf.enabled = false

-- Counters
Perf._eventsTotal = 0
Perf._calls = {}

-- Timings (ms)
Perf._msLast  = {}
Perf._msTotal = {}
Perf._msMax   = {}
Perf._msCount = {}

local overlay
local ticker
local lastEvents = 0
local lastCalls = {}
local lastFlush = 0

local function GetGeneralCfg()
    if not (DB and DB.GetSection) then
        return nil
    end
    local general = DB:GetSection("general")
    if type(general) ~= "table" then
        return nil
    end
    return general
end

local function NowMS()
    if _G and _G.debugprofilestop then
        return _G.debugprofilestop()
    end
    if _G and _G.GetTime then
        return _G.GetTime() * 1000
    end
    return 0
end

local function GetEnabledFromProfile()
    local general = GetGeneralCfg()
    return general and general.perfOverlay == true
end

local function EnsureOverlay()
    if overlay then return overlay end

    overlay = CreateFrame("Frame", "FGUI_PerfOverlay", UIParent, "BackdropTemplate")
    overlay:SetFrameStrata("DIALOG")
    overlay:SetFrameLevel(200)
    overlay:SetSize(300, 110)
    overlay:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 12, -12)
    overlay:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Buttons/WHITE8x8",
        edgeSize = 1,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    overlay:SetBackdropColor(0, 0, 0, 0.55)
    overlay:SetBackdropBorderColor(0, 0, 0, 1)

    local title = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", 8, -6)
    title:SetText("FeelsGoodUI Perf")

    local line1 = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line1:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    line1:SetJustifyH("LEFT")
    line1:SetText("Events/s: 0")

    local line2 = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line2:SetPoint("TOPLEFT", line1, "BOTTOMLEFT", 0, -4)
    line2:SetJustifyH("LEFT")
    line2:SetText("Apply flush/s: 0")

    local line3 = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line3:SetPoint("TOPLEFT", line2, "BOTTOMLEFT", 0, -4)
    line3:SetJustifyH("LEFT")
    line3:SetText("Req/s: 0")

    local line4 = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line4:SetPoint("TOPLEFT", line3, "BOTTOMLEFT", 0, -4)
    line4:SetJustifyH("LEFT")
    line4:SetText("Apply ms: UF 0.0  AB 0.0  CP 0.0")

    local line5 = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line5:SetPoint("TOPLEFT", line4, "BOTTOMLEFT", 0, -4)
    line5:SetJustifyH("LEFT")
    line5:SetText("Mem KB: 0")

    overlay._title = title
    overlay._line1 = line1
    overlay._line2 = line2
    overlay._line3 = line3
    overlay._line4 = line4
    overlay._line5 = line5

    overlay:Hide()
    return overlay
end

local function StopTicker()
    if ticker and ticker.Cancel then
        ticker:Cancel()
    end
    ticker = nil
end

local function StartTicker()
    if not _G.C_Timer or not _G.C_Timer.NewTicker then
        return
    end

    StopTicker()

    lastEvents = Perf._eventsTotal
    for k, v in pairs(Perf._calls) do
        lastCalls[k] = v
    end

    ticker = _G.C_Timer.NewTicker(1, function()
        if not overlay or not overlay:IsShown() then
            StopTicker()
            return
        end

        -- events/sec
        local ev = Perf._eventsTotal
        local eps = ev - lastEvents
        lastEvents = ev

        -- apply flush/sec + requests/sec
        local flush = (Perf._calls["ApplyFlush"] or 0)
        local req = (Perf._calls["ApplyRequest"] or 0)
        local flushDelta = flush - (lastCalls["ApplyFlush"] or 0)
        local reqDelta = req - (lastCalls["ApplyRequest"] or 0)
        lastCalls["ApplyFlush"] = flush
        lastCalls["ApplyRequest"] = req

        -- last apply timings (ms)
        local msUF = Perf._msLast["unitframes"] or 0
        local msAB = Perf._msLast["actionbars"] or 0
        local msCP = Perf._msLast["companion"] or 0

        local memKB = 0
        if _G and _G.collectgarbage then
            local ok, v = pcall(_G.collectgarbage, "count")
            if ok and type(v) == "number" then
                memKB = v
            end
        end

        overlay._line1:SetText(string.format("Events/s: %d", eps))
        overlay._line2:SetText(string.format("Apply flush/s: %d", flushDelta))
        overlay._line3:SetText(string.format("Req/s: %d", reqDelta))
        overlay._line4:SetText(string.format("Apply ms: UF %.2f  AB %.2f  CP %.2f", msUF, msAB, msCP))
        overlay._line5:SetText(string.format("Mem KB: %.0f", memKB))
    end)
end

function Perf:IsEnabled()
    return self.enabled == true
end

function Perf:SetEnabled(enabled)
    enabled = enabled == true
    self.enabled = enabled

    local general = GetGeneralCfg()
    if general then
        general.perfOverlay = enabled
    end

    local f = EnsureOverlay()
    if enabled then
        f:Show()
        StartTicker()
        if Log and Log.Info then Log:Info("Perf overlay enabled") end
    else
        f:Hide()
        StopTicker()
        if Log and Log.Info then Log:Info("Perf overlay disabled") end
    end
end

function Perf:RefreshFromProfile()
    local enabled = GetEnabledFromProfile()
    self.enabled = enabled
    local f = EnsureOverlay()
    if enabled then
        f:Show()
        StartTicker()
    else
        f:Hide()
        StopTicker()
    end
end

-- Hot-path increments (guarded; no-op when disabled)
function Perf:OnEvent()
    if not self.enabled then return end
    self._eventsTotal = self._eventsTotal + 1
end

function Perf:Inc(key)
    if not self.enabled then return end
    if type(key) ~= "string" or key == "" then return end
    self._calls[key] = (self._calls[key] or 0) + 1
end

function Perf:Time(key, ms)
    if not self.enabled then return end
    if type(key) ~= "string" or key == "" then return end
    if type(ms) ~= "number" or ms < 0 then return end

    self._msLast[key] = ms
    self._msTotal[key] = (self._msTotal[key] or 0) + ms
    self._msCount[key] = (self._msCount[key] or 0) + 1

    local mx = self._msMax[key] or 0
    if ms > mx then
        self._msMax[key] = ms
    end
end

function Perf:NowMS()
    return NowMS()
end

if Log and Log.Debug then
    Log:Debug("Perf loaded")
end
