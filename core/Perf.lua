-- FeelsGoodUI: Lightweight performance counters + debug overlay
--
-- Counters: events/sec, apply queue activity, hot-path calls, apply timings,
-- and current Lua memory. The module owns runtime presentation only; persisted
-- enable state is written through Settings and applied by RuntimeSettings.

local _, ns = ...

local Perf = {}
ns.Perf = Perf

local DB = ns.DB
local Log = ns.Log

Perf.enabled = false
Perf._eventsTotal = 0
Perf._calls = {}
Perf._msLast = {}
Perf._msTotal = {}
Perf._msMax = {}
Perf._msCount = {}

local overlay
local ticker
local lastEvents = 0
local lastCalls = {}

local function GetGeneralCfg()
    if not (DB and DB.ReadSection) then
        return nil
    end
    local general = DB:ReadSection("general")
    return type(general) == "table" and general or nil
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
    return general and general.perfOverlay == true or false
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
    if ticker then
        return true
    end
    if not (_G.C_Timer and _G.C_Timer.NewTicker) then
        return false
    end

    lastEvents = Perf._eventsTotal
    for key in pairs(lastCalls) do
        lastCalls[key] = nil
    end
    for key, value in pairs(Perf._calls) do
        lastCalls[key] = value
    end

    ticker = _G.C_Timer.NewTicker(1, function()
        if not overlay or not overlay:IsShown() or Perf.enabled ~= true then
            StopTicker()
            return
        end

        local events = Perf._eventsTotal
        local eventsDelta = events - lastEvents
        lastEvents = events

        local flush = Perf._calls.ApplyFlush or 0
        local requests = Perf._calls.ApplyRequest or 0
        local flushDelta = flush - (lastCalls.ApplyFlush or 0)
        local requestDelta = requests - (lastCalls.ApplyRequest or 0)
        lastCalls.ApplyFlush = flush
        lastCalls.ApplyRequest = requests

        local msUF = Perf._msLast.unitframes or 0
        local msAB = Perf._msLast.actionbars or 0
        local msCP = Perf._msLast.companion or 0

        local memKB = 0
        if _G and _G.collectgarbage then
            local ok, value = pcall(_G.collectgarbage, "count")
            if ok and type(value) == "number" then
                memKB = value
            end
        end

        overlay._line1:SetText(string.format("Events/s: %d", eventsDelta))
        overlay._line2:SetText(string.format("Apply flush/s: %d", flushDelta))
        overlay._line3:SetText(string.format("Req/s: %d", requestDelta))
        overlay._line4:SetText(string.format("Apply ms: UF %.2f  AB %.2f  CP %.2f", msUF, msAB, msCP))
        overlay._line5:SetText(string.format("Mem KB: %.0f", memKB))
    end)
    return true
end

function Perf:IsEnabled()
    return self.enabled == true
end

function Perf:SetEnabled(enabled, options)
    enabled = enabled == true
    options = type(options) == "table" and options or nil

    local changed = self.enabled ~= enabled
    self.enabled = enabled

    local frame = EnsureOverlay()
    if enabled then
        frame:Show()
        StartTicker()
    else
        frame:Hide()
        StopTicker()
    end

    if changed and not (options and options.silent == true) and Log and Log.Info then
        Log:Info(enabled and "Perf overlay enabled" or "Perf overlay disabled")
    end
    return true
end

function Perf:RefreshFromProfile()
    return self:SetEnabled(GetEnabledFromProfile(), { silent = true })
end

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

    local maximum = self._msMax[key] or 0
    if ms > maximum then
        self._msMax[key] = ms
    end
end

function Perf:NowMS()
    return NowMS()
end

if Log and Log.Debug then
    Log:Debug("Perf loaded")
end
