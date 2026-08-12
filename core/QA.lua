-- FeelsGoodUI: QA + diagnostics (Stage 45)
--
-- Goals:
--  - Provide a deterministic smoke-test runner the user can execute in-game.
--  - Produce a copyable report to attach to bug reports.
--  - Avoid heavy allocations; no OnUpdate unless the report window is open.
--
-- Notes:
--  - This does NOT replace real gameplay testing; it is a guardrail.
--  - All tests are best-effort and never throw (pcall everywhere).
--
-- Author: Neomorph

local _, ns = ...

local QA = {}
ns.QA = QA

local DB = ns.DB
local Log = ns.Log
local Errors = ns.Errors
local Perf = ns.Perf
local Diagnostics = ns.Diagnostics
local Apply = ns.Apply
local Schema = ns.Schema or {}
local L = ns.L or function(text) return text end

local function GetSavedProfileRoot()
    if type(_G.FeelsGoodUIDB) == "table" and type(_G.FeelsGoodUIDB.profile) == "table" then
        return _G.FeelsGoodUIDB.profile
    end
    return nil
end

local function GetProfileSection(section)
    if DB and DB.GetSection then
        local value = DB:GetSection(section)
        if type(value) == "table" then
            return value
        end
    end
    local profile = GetSavedProfileRoot()
    if type(profile) == "table" then
        local value = profile[section]
        if type(value) == "table" then
            return value
        end
    end
    return {}
end

local function Now()
    if _G and _G.date then
        local ok, s = pcall(_G.date, "%Y-%m-%d %H:%M:%S")
        if ok and type(s) == "string" then return s end
    end
    return ""
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return false, "not a function" end
    local ok, res = pcall(fn, ...)
    if ok then return true, res end
    return false, res
end

local function AddLine(out, s)
    out[#out + 1] = tostring(s or "")
end

local function SnapshotEnv(out)
    AddLine(out, "== FeelsGoodUI QA Report ==")
    AddLine(out, "Time: " .. Now())

    local ver = tostring(ns.VERSION or "?")
    local iface = "?"
    if _G and _G.C_AddOns and _G.C_AddOns.GetAddOnMetadata then
        local ok, v = pcall(_G.C_AddOns.GetAddOnMetadata, ns.ADDON_NAME, "Interface")
        if ok and v then iface = tostring(v) end
    end
    AddLine(out, "Addon: " .. tostring(ns.ADDON_NAME or "FeelsGoodUI") .. " v" .. ver .. " (Interface " .. iface .. ")")

    if _G and _G.GetBuildInfo then
        local ok, version, build, date, toc = pcall(_G.GetBuildInfo)
        if ok then
            AddLine(out, "Client: " .. tostring(version) .. " (build " .. tostring(build) .. ", toc " .. tostring(toc) .. ", date " .. tostring(date) .. ")")
        end
    end

    if _G and _G.GetScreenWidth and _G.GetScreenHeight then
        local okW, w = pcall(_G.GetScreenWidth)
        local okH, h = pcall(_G.GetScreenHeight)
        if okW and okH and type(w) == "number" and type(h) == "number" and h > 0 then
            local aspect = w / h
            AddLine(out, ("Screen: %dx%d (aspect %.2f)"):format(w, h, aspect))
        end
    end

    if _G and _G.UIParent and _G.UIParent.GetEffectiveScale then
        local ok, s = pcall(_G.UIParent.GetEffectiveScale, _G.UIParent)
        if ok and type(s) == "number" then
            AddLine(out, ("UI scale: %.3f"):format(s))
        end
    end

    local inCombat = (InCombatLockdown and InCombatLockdown()) == true
    AddLine(out, "InCombat: " .. tostring(inCombat))

    AddLine(out, "")
end

local function CheckSavedVars(out)
    AddLine(out, "== SavedVariables ==")
    if type(_G.FeelsGoodUIDB) ~= "table" then
        AddLine(out, "FAIL: FeelsGoodUIDB is not a table")
        AddLine(out, "")
        return false
    end

    local okP, p = SafeCall(GetSavedProfileRoot)
    if not okP or type(p) ~= "table" then
        AddLine(out, "FAIL: saved profile root missing")
        AddLine(out, "")
        return false
    end

    local schemaState = (type(Schema.GetProfileState) == "function")
        and Schema.GetProfileState(p)
        or {
            currentVersion = tonumber(Schema.CURRENT_VERSION) or tonumber(p.version) or "?",
            oldVersion = tonumber(p.version),
            status = (type(p.version) == "number") and "current" or "missing_or_invalid",
            needsReset = type(p.version) ~= "number",
        }

    AddLine(out, "Profile version: " .. tostring(p.version or "?"))
    AddLine(out, "Schema state: " .. tostring(schemaState.status or "?") .. " (current " .. tostring(schemaState.currentVersion or "?") .. ")")
    if schemaState.needsReset then
        AddLine(out, "FAIL: profile schema is not compatible with the current live tree")
        AddLine(out, "")
        return false
    end

    AddLine(out, "PASS: profile schema matches the current live tree")
    AddLine(out, "")
    return true
end

local function CheckLegacySchemaDebt(out, profile)
    AddLine(out, "== Removed/legacy schema debt ==")
    if type(profile) ~= "table" then
        AddLine(out, "WARN: profile root unavailable")
        AddLine(out, "")
        return true
    end

    local issues = 0

    local function Fail(path)
        issues = issues + 1
        AddLine(out, "FAIL: legacy field still persisted: " .. tostring(path))
    end

    if profile.cooldownViewer ~= nil then
        Fail("profile.cooldownViewer")
        if type(profile.cooldownViewer) == "table" then
            local dock = profile.cooldownViewer.dock
            if type(dock) == "table" and dock.captured ~= nil then
                Fail("profile.cooldownViewer.dock.captured")
            end
        end
    end

    if profile.customBars ~= nil then
        Fail("profile.customBars")
    end
    if profile.weakBars ~= nil then
        Fail("profile.weakBars")
    end

    local positions = profile.positions
    if type(positions) == "table" then
        if positions.cooldownviewer ~= nil then Fail("profile.positions.cooldownviewer") end
        if positions.actionbar6 ~= nil then Fail("profile.positions.actionbar6") end
        if positions.actionbar7 ~= nil then Fail("profile.positions.actionbar7") end
    end

    local actionbars = profile.actionbars
    if type(actionbars) == "table" then
        if actionbars._bar45Imported ~= nil then Fail("profile.actionbars._bar45Imported") end
        if actionbars.keepMicroBags ~= nil then Fail("profile.actionbars.keepMicroBags") end
        if actionbars.compactBags ~= nil then Fail("profile.actionbars.compactBags") end

        local bars = actionbars.bars
        if type(bars) == "table" then
            if bars[6] ~= nil then Fail("profile.actionbars.bars[6]") end
            if bars[7] ~= nil then Fail("profile.actionbars.bars[7]") end
        end

        local layering = actionbars.layering
        if type(layering) == "table" then
            if layering.petBarStrata ~= nil then Fail("profile.actionbars.layering.petBarStrata") end
            if layering.petBarLevel ~= nil then Fail("profile.actionbars.layering.petBarLevel") end
        end
    end

    local options = profile.options
    if type(options) == "table" and type(options.livePreview) == "table" then
        if options.livePreview.cooldownViewer ~= nil then
            Fail("profile.options.livePreview.cooldownViewer")
        end
    end

    if issues == 0 then
        AddLine(out, "PASS: removed scope and legacy persisted fields are absent")
        AddLine(out, "")
        return true
    end

    AddLine(out, "")
    return false
end

local function ScanForUnsafe(out, root)
    -- Ensure profile doesn't contain unserializable types (function/userdata/thread).
    -- Cap depth and node count to avoid runaway.
    local seen = {}
    local stack = { { t = root, path = "profile", d = 0 } }
    local nodes = 0
    local unsafe = 0

    while #stack > 0 do
        local cur = table.remove(stack)
        local t = cur.t
        if type(t) == "table" and not seen[t] then
            seen[t] = true
            nodes = nodes + 1
            if nodes > 5000 then
                AddLine(out, "WARN: SavedVariables scan aborted (node cap)")
                break
            end
            if cur.d <= 12 then
                for k, v in pairs(t) do
                    local kt = type(k)
                    if kt ~= "string" and kt ~= "number" and kt ~= "boolean" then
                        unsafe = unsafe + 1
                        AddLine(out, "WARN: Non-serializable key at " .. cur.path)
                    end
                    local vt = type(v)
                    if vt == "function" or vt == "userdata" or vt == "thread" then
                        unsafe = unsafe + 1
                        AddLine(out, "FAIL: Non-serializable value (" .. vt .. ") at " .. cur.path .. "." .. tostring(k))
                    elseif vt == "table" then
                        stack[#stack + 1] = { t = v, path = cur.path .. "." .. tostring(k), d = cur.d + 1 }
                    end
                end
            end
        end
    end

    if unsafe == 0 then
        AddLine(out, "PASS: SavedVariables contain only serializable types")
        return true
    end
    return false
end

local function CheckModules(out)
    AddLine(out, "== Modules ==")
    local required = {
        { "DB", DB },
        { "Options", ns.Options },
        { "Apply", ns.Apply },
        { "Movers", ns.Movers },
        { "UnitFrames", ns.UF },
        { "CenterBars", ns.Center },
        { "ActionBars", ns.ActionBars },
        { "Companion", ns.Companion },
        { "Safety", ns.Safety },
        { "Perf", ns.Perf },
    }

    local okAll = true
    for _, r in ipairs(required) do
        local name, mod = r[1], r[2]
        if mod == nil then
            okAll = false
            AddLine(out, "FAIL: missing module: " .. tostring(name))
        else
            AddLine(out, "PASS: " .. tostring(name))
        end
    end

    if not _G.oUF then
        AddLine(out, "FAIL: oUF not loaded (RequiredDeps missing)")
        okAll = false
    else
        AddLine(out, "PASS: oUF loaded")
    end

    AddLine(out, "")
    return okAll
end

local function CheckFrames(out)
    AddLine(out, "== Frames (post-login) ==")

    if _G and _G.IsLoggedIn and not _G.IsLoggedIn() then
        AddLine(out, "WARN: Not logged in yet; run /fgui qa after PLAYER_LOGIN")
        AddLine(out, "")
        return true
    end

    local uf = ns.UF
    if uf and uf._inited then
        local ufp = GetProfileSection("unitframes")
        local showFocus = not (ufp.showFocus == false)
        local showTT = not (ufp.showTargetTarget == false)
        local showPet = not (ufp.showPet == false)
        AddLine(out, "UnitFrames: inited")
        AddLine(out, "  player: " .. tostring(uf.player and uf.player.GetName and uf.player:GetName() or "nil"))
        AddLine(out, "  target: " .. tostring(uf.target and uf.target.GetName and uf.target:GetName() or "nil"))
        AddLine(out, "  focus: " .. tostring(uf.focus and uf.focus.GetName and uf.focus:GetName() or "nil") .. " (enabled=" .. tostring(showFocus) .. ")")
        AddLine(out, "  targettarget: " .. tostring(uf.targettarget and uf.targettarget.GetName and uf.targettarget:GetName() or "nil") .. " (enabled=" .. tostring(showTT) .. ")")
        AddLine(out, "  pet: " .. tostring(uf.pet and uf.pet.GetName and uf.pet:GetName() or "nil") .. " (enabled=" .. tostring(showPet) .. ")")
    else
        AddLine(out, "WARN: UnitFrames not initialized")
    end

    local ab = ns.ActionBars
    if ab and ab._inited and type(ab.bars) == "table" then
        AddLine(out, "ActionBars: inited")
        for i = 1, 5 do
            local h = ab.bars[i]
            AddLine(out, ("  bar%d holder: %s"):format(i, tostring(h and h.GetName and h:GetName() or "nil")))
        end
    else
        AddLine(out, "WARN: ActionBars not initialized")
    end

    local companion = ns.Companion
    if companion and companion._initDone then
        local petAnchor = companion._petAnchor
        local microAnchor = companion._microAnchor
        AddLine(out, "Companion: initialized")
        AddLine(out, "  pet anchor: " .. tostring(petAnchor and petAnchor.GetName and petAnchor:GetName() or "nil"))
        AddLine(out, "  micro anchor: " .. tostring(microAnchor and microAnchor.GetName and microAnchor:GetName() or "nil"))
        AddLine(out, "  pet owner active: " .. tostring(petAnchor ~= nil))
        AddLine(out, "  micro owner active: " .. tostring(microAnchor ~= nil))
    else
        AddLine(out, "WARN: Companion not initialized")
    end

    if _G.FGUI_oUF_PetBarHolder then
        AddLine(out, "PASS: canonical holder found: FGUI_oUF_PetBarHolder")
    else
        AddLine(out, "WARN: canonical holder missing: FGUI_oUF_PetBarHolder")
    end

    if _G.FGUI_oUF_MicroMenuHolder then
        AddLine(out, "PASS: canonical holder found: FGUI_oUF_MicroMenuHolder")
    else
        AddLine(out, "WARN: canonical holder missing: FGUI_oUF_MicroMenuHolder")
    end

    local mv = ns.Movers
    if mv and type(mv._registered) == "table" then
        local hasPetMover = mv._registered.petbar ~= nil
        local hasMicroMover = mv._registered.micromenu ~= nil
        AddLine(out, "Movers: petbar=" .. tostring(hasPetMover) .. ", micromenu=" .. tostring(hasMicroMover))
    end

    AddLine(out, "")
    return true
end

local function CheckErrors(out)
    AddLine(out, "== Captured errors ==")
    if not (Errors and Errors.GetAll) then
        AddLine(out, "WARN: Errors module not available")
        AddLine(out, "")
        return true
    end
    local list = Errors:GetAll()
    if #list == 0 then
        AddLine(out, "PASS: none")
        AddLine(out, "")
        return true
    end

    AddLine(out, "WARN: captured errors = " .. tostring(#list))
    local start = math.max(1, #list - 5 + 1)
    for i = start, #list do
        local e = list[i]
        AddLine(out, ("  [%0.1fs] %s: %s"):format(e.t or 0, tostring(e.src or ""), tostring(e.msg or "")))
    end
    AddLine(out, "")
    return false
end

local function CheckDiagnostics(out)
    AddLine(out, "== Protected action warnings (taint/protected) ==")
    if not (Diagnostics and Diagnostics.GetAll) then
        AddLine(out, "WARN: Diagnostics module not available")
        AddLine(out, "")
        return true
    end

    local list = Diagnostics:GetAll()
    if #list == 0 then
        AddLine(out, "PASS: none captured")
        AddLine(out, "")
        return true
    end

    AddLine(out, "WARN: captured = " .. tostring(#list))
    local start = math.max(1, #list - 5 + 1)
    for i = start, #list do
        local e = list[i]
        AddLine(out, ("  [%0.1fs] %s %s: %s"):format(e.t or 0, tostring(e.event or ""), tostring(e.addon or ""), tostring(e.func or "")))
    end
    AddLine(out, "")
    return false
end

local function CheckPerf(out)
    AddLine(out, "== Perf ==")
    if not (Perf and Perf.IsEnabled) then
        AddLine(out, "WARN: Perf module not available")
        AddLine(out, "")
        return true
    end

    AddLine(out, "Perf overlay enabled: " .. tostring(Perf:IsEnabled() == true))
    if Perf._eventsTotal then
        AddLine(out, "Events total (session): " .. tostring(Perf._eventsTotal))
    end
    if Perf._calls then
        local ar = Perf._calls["ApplyRequest"]
        local af = Perf._calls["ApplyFlush"]
        if ar or af then
            AddLine(out, "ApplyRequest: " .. tostring(ar or 0) .. ", ApplyFlush: " .. tostring(af or 0))
        end
    end
    AddLine(out, "")
    return true
end

-- -----------------------------
-- Report window
-- -----------------------------

QA._reportFrame = QA._reportFrame or nil
QA._lastReportText = QA._lastReportText or nil

local function EnsureReportFrame()
    if QA._reportFrame then return QA._reportFrame end

    local f = CreateFrame("Frame", "FGUI_QAReportFrame", UIParent, "BackdropTemplate")
    f:SetSize(760, 520)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:Hide()

    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
    title:SetText(L("FeelsGoodUI - QA Report"))

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -42)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 48)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject("ChatFontNormal")
    edit:SetWidth(700)
    edit:SetText("")
    edit:SetScript("OnEscapePressed", function() f:Hide() end)

    scroll:SetScrollChild(edit)
    f._edit = edit

    local copy = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    copy:SetSize(120, 24)
    copy:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 16)
    copy:SetText(L("Select All"))
    copy:SetScript("OnClick", function()
        if not f._edit then return end
        f._edit:SetFocus()
        f._edit:HighlightText(0, -1)
    end)

    local refresh = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    refresh:SetSize(120, 24)
    refresh:SetPoint("BOTTOMLEFT", copy, "BOTTOMRIGHT", 10, 0)
    refresh:SetText(L("Refresh"))
    refresh:SetScript("OnClick", function()
        QA:Run(true)
        QA:ShowReport(QA._lastReportText)
    end)

    QA._reportFrame = f
    return f
end

function QA:ShowReport(text)
    local f = EnsureReportFrame()
    if not f then return end
    local t = tostring(text or "")
    f._edit:SetText(t)
    f._edit:ClearFocus()
    f:Show()
end

-- -----------------------------
-- Public API
-- -----------------------------

function QA:Run(silent)
    local out = {}
    SnapshotEnv(out)

    local okSV = CheckSavedVars(out)
    local profile = okSV and GetSavedProfileRoot() or nil
    if profile then
        CheckLegacySchemaDebt(out, profile)
        ScanForUnsafe(out, profile)
        AddLine(out, "")
    end

    CheckModules(out)
    CheckFrames(out)
    CheckErrors(out)
    CheckDiagnostics(out)
    CheckPerf(out)

    if self._soakResult then
        AddLine(out, "== Soak test (last run) ==")
        AddLine(out, self._soakResult)
        AddLine(out, "")
    end

    AddLine(out, "== Manual QA checklist ==")
    AddLine(out, "1) /reload -> no Lua errors")
    AddLine(out, "2) Enter combat -> no taint/protected warnings (ADDON_ACTION_BLOCKED/FORBIDDEN)")
    AddLine(out, "3) Open Settings -> move sliders rapidly -> layout stable")
    AddLine(out, "4) Edit Mode (Shift+Drag) -> move/snap/resize out of combat")
    AddLine(out, "5) Relog -> settings persisted")
    AddLine(out, "6) Optional: /fgui soak 30 -> check memDelta is stable")

    local report = table.concat(out, "\n")
    self._lastReportText = report

    if silent ~= true and Log and Log.Info then
        Log:Info(L("QA report generated. Use /fgui report to view/copy."))
    end

    return report
end

-- -----------------------------
-- Soak test (Stage 45 helper)
-- -----------------------------

QA._soakTicker = QA._soakTicker or nil
QA._soakResult = QA._soakResult or nil
QA._soakStartMem = QA._soakStartMem or nil
QA._soakStartTime = QA._soakStartTime or nil
QA._soakTargetSec = QA._soakTargetSec or nil

local function MemKB()
    local ok, v = pcall(collectgarbage, "count")
    if ok and type(v) == "number" then return v end
    return nil
end

function QA:StopSoak()
    if self._soakTicker then
        self._soakTicker:Cancel()
        self._soakTicker = nil
    end

    if self._soakStartTime and self._soakStartMem then
        local dt = (GetTime and GetTime() or 0) - self._soakStartTime
        local memNow = MemKB()
        local dmem = (memNow and (memNow - self._soakStartMem)) or 0
        self._soakResult = ("duration=%0.1fs, memDelta=%0.0f KB"):format(dt, dmem)
    end

    self._soakStartMem = nil
    self._soakStartTime = nil
    self._soakTargetSec = nil
end

function QA:StartSoak(seconds)
    seconds = tonumber(seconds) or 30
    if seconds < 5 then seconds = 5 end
    if seconds > 180 then seconds = 180 end

    if InCombatLockdown and InCombatLockdown() then
        if Log and Log.Warn then
            Log:Warn(L("Soak test blocked in combat."))
        end
        return
    end

    self:StopSoak()
    self._soakStartMem = MemKB() or 0
    self._soakStartTime = (GetTime and GetTime()) or 0
    self._soakTargetSec = seconds
    self._soakResult = ("running (%ds)..."):format(seconds)

    local interval = 0.20 -- 5 Hz
    self._soakTicker = C_Timer.NewTicker(interval, function()
        if InCombatLockdown and InCombatLockdown() then
            return
        end

        -- Request applies (coalesced) without forcing full re-layout each tick.
        if Apply and Apply.Request then
            Apply:Request("unitframes")
            Apply:Request("center")
            Apply:Request("actionbars")
            Apply:Request("companion")
        end

        -- Stop when time is reached.
        local now = (GetTime and GetTime()) or 0
        if self._soakStartTime and (now - self._soakStartTime) >= seconds then
            self:StopSoak()
            if Log and Log.Info then
                Log:Info(L("Soak test finished. Use /fgui qa or /fgui report to view result."))
            end
        end
    end)

    if Log and Log.Info then
        Log:Info(L("Soak test started for %ss."):format(tostring(seconds)))
    end
end

function QA:SoakCmd(rest)
    rest = tostring(rest or "")
    rest = rest:lower():match("^%s*(.-)%s*$")
    if rest == "" then
        self:StartSoak(30)
        return
    end
    if rest == "stop" then
        self:StopSoak()
        if Log and Log.Info then Log:Info(L("Soak test stopped.")) end
        return
    end
    local n = tonumber(rest)
    if n then
        self:StartSoak(n)
        return
    end
    if Log and Log.Warn then
        Log:Warn(L("Usage: /fgui soak <seconds>|stop"))
    end
end

function QA:Cmd(sub)
    sub = tostring(sub or "")
    if sub == "report" then
        if not self._lastReportText then
            self:Run(true)
        end
        self:ShowReport(self._lastReportText)
        return
    end

    self:Run(false)
    self:ShowReport(self._lastReportText)
end
