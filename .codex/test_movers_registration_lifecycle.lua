local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertContains(value, needle, label)
    value = tostring(value)
    if not string.find(value, needle, 1, true) then
        error((label or "value") .. ": missing " .. tostring(needle) .. " in " .. value, 2)
    end
end

local function CountEntries(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do count = count + 1 end
    return count
end

_G = _G or {}
_G.UIParent = {}
_G.InCombatLockdown = function() return false end
_G.CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function() end,
    }
end

local sections = {
    movers = { unlocked = false },
    positions = {
        alpha = { point = "CENTER", relPoint = "CENTER", x = 1, y = 2 },
        beta = { point = "CENTER", relPoint = "CENTER", x = 3, y = 4 },
    },
}

local function NewFrame(name)
    local frame = {
        name = name,
        movableCalls = 0,
        clampCalls = 0,
        applyCalls = 0,
    }
    function frame:SetMovable(value)
        self.movableCalls = self.movableCalls + 1
        if self.failMovable then error("injected movable failure") end
        self.movable = value
    end
    function frame:SetClampedToScreen(value)
        self.clampCalls = self.clampCalls + 1
        if self.failClamp then error("injected clamp failure") end
        self.clamped = value
    end
    return frame
end

local overlays = {}
local function NewOverlay(frame, label)
    local overlay = {
        frame = frame,
        scripts = {},
        shown = false,
        mouseEnabled = true,
        cancelCalls = 0,
        hl = { shown = false },
        handle = { scripts = {}, mouseEnabled = true, shown = true },
        text = { value = label },
    }
    function overlay.hl:SetShown(value) self.shown = value == true end
    function overlay:SetScript(event, callback) self.scripts[event] = callback end
    function overlay:Show() self.shown = true end
    function overlay:Hide() self.shown = false end
    function overlay:EnableMouse(value) self.mouseEnabled = value == true end
    function overlay.handle:SetScript(event, callback) self.scripts[event] = callback end
    function overlay.handle:EnableMouse(value) self.mouseEnabled = value == true end
    function overlay.handle:Hide() self.shown = false end
    function overlay.text:SetText(value) self.value = value end
    overlay._cancelPreview = function() overlay.cancelCalls = overlay.cancelCalls + 1 end
    return overlay
end

local createOverlayCalls = 0
local ns = {
    DB = {
        defaults = { profile = { positions = sections.positions } },
    },
    Log = {
        Warn = function() end,
        Info = function() end,
    },
    Media = {},
    U = {
        DeepCopy = function(value) return value end,
    },
    MoversTransactions = {
        MergeApplyKeys = function(_, a, b) return { a, b } end,
        CommitWrites = function() return true end,
    },
    MoversShared = {
        GetProfileSection = function(name) return sections[name] end,
        IsSafeToEdit = function() return true end,
        UIParentRect = function() return 0, 0, 100, 100 end,
        UIWH = function() return 100, 100 end,
        GetCursorUI = function() return 0, 0 end,
        Clamp = function(value) return value end,
        RoundToStep = function(value) return value end,
        ClampCenterOffsets = function(x, y) return x, y end,
        GetFrameSnapSize = function() return 10, 10 end,
        GetFrameSnapBounds = function() return 0, 0, 10, 10 end,
        ApplyStoredPoint = function(key, frame)
            frame.applyCalls = frame.applyCalls + 1
            if frame.failApply then error("injected position failure") end
            if frame.noPoint or not sections.positions[key] then return nil end
            frame.lastPoint = sections.positions[key]
            return sections.positions[key]
        end,
        GetEditablePosition = function() return 0, 0 end,
        SetEditablePosition = function() return true end,
        EnsureCenterAnchor = function() return true end,
        SavePoint = function() return true end,
        BuildStoredPointWrites = function() return true, {}, "movers", "editmode" end,
        ResolveStoredPointFromFrame = function() return { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 } end,
        GridStep = function() return 10 end,
        EditorCfg = function() return {} end,
        RequestApplyForKeys = function() return true end,
    },
    MoversSnapGrid = {
        Create = function()
            return {
                EnsureGridBuilt = function() end,
                SetGridVisible = function() end,
                BuildSnapTargets = function() return nil, nil end,
                SnapOffsets = function(x, y) return x, y end,
                HideGuides = function() end,
            }
        end,
    },
    MoversInspector = {
        Create = function()
            return {
                EnsureInspector = function() end,
                HideInspector = function() end,
            }
        end,
    },
    MoversEditor = {
        Create = function()
            return {
                SetGlobalHintVisible = function() end,
                EnsureKeyListener = function() end,
                DisableKeyListener = function() end,
                CreateOverlay = function(_, frame, label)
                    createOverlayCalls = createOverlayCalls + 1
                    if frame.failOverlay then error("injected overlay failure") end
                    local overlay = NewOverlay(frame, label)
                    overlays[#overlays + 1] = overlay
                    local function Refresh()
                        if frame.failRefresh then error("injected handle refresh failure") end
                        overlay.refreshCalls = (overlay.refreshCalls or 0) + 1
                    end
                    return overlay, Refresh
                end,
            }
        end,
    },
}

assert(loadfile("core/Movers.lua"))("FeelsGoodUI", ns)
local Movers = assert(ns.Movers)

local alpha = NewFrame("alpha")
local ok, detail = Movers:Register("alpha", alpha, { label = "Alpha", custom = 1 })
assertEqual(ok, true, "initial registration")
assertEqual(detail, "registered", "initial registration detail")
assertEqual(createOverlayCalls, 1, "one overlay created")
assertEqual(Movers:GetEntry("alpha").frame, alpha, "alpha frame stored")
assertEqual(Movers:GetEntry("alpha").spec.custom, 1, "alpha spec stored")
assertEqual(alpha.movable, true, "alpha movable configured")
assertEqual(alpha.clamped, true, "alpha clamp configured")

ok, detail = Movers:Register("alpha", alpha, { label = "Alpha Updated", custom = 2 })
assertEqual(ok, true, "same-frame registration")
assertEqual(detail, "reused", "same-frame detail")
assertEqual(createOverlayCalls, 1, "same frame reuses overlay")
assertEqual(Movers:GetEntry("alpha").spec.custom, 2, "same frame updates spec")
assertEqual(Movers:GetEntry("alpha").overlay.text.value, "Alpha Updated", "same frame updates label")

ok, detail = Movers:Apply("alpha", alpha)
assertEqual(ok, true, "position apply succeeds")
assertEqual(detail, sections.positions.alpha, "position apply returns normalized point")
assertEqual(alpha.applyCalls, 1, "position applied once")

local replacement = NewFrame("alpha replacement")
local oldEntry = Movers:GetEntry("alpha")
local oldOverlay = oldEntry.overlay
oldOverlay:SetScript("OnClick", function() end)
oldOverlay.handle:SetScript("OnMouseDown", function() end)
Movers:SetActiveMover("alpha", oldOverlay)
ok, detail = Movers:Register("alpha", replacement, { label = "Alpha Replacement" })
assertEqual(ok, true, "replacement registration")
assertEqual(detail, "replaced", "replacement detail")
assertEqual(createOverlayCalls, 2, "replacement creates one new overlay")
assertEqual(Movers:GetEntry("alpha").frame, replacement, "replacement frame stored")
assertEqual(oldEntry.retired, true, "old entry retired")
assertEqual(oldOverlay.shown, false, "old overlay hidden")
assertEqual(oldOverlay.mouseEnabled, false, "old overlay mouse disabled")
assertEqual(oldOverlay.handle.mouseEnabled, false, "old handle mouse disabled")
assertEqual(oldOverlay.handle.shown, false, "old handle hidden")
assertEqual(oldOverlay.scripts.OnClick, nil, "old overlay scripts cleared")
assertEqual(oldOverlay.handle.scripts.OnMouseDown, nil, "old handle scripts cleared")
assertEqual(oldOverlay.cancelCalls, 1, "old preview cancelled")
assertEqual(Movers._activeKey, nil, "old active key cleared")
assertEqual(Movers._activeOverlay, nil, "old active overlay cleared")

local failedReplacement = NewFrame("failed replacement")
failedReplacement.failOverlay = true
local currentEntry = Movers:GetEntry("alpha")
ok, detail = Movers:Register("alpha", failedReplacement, { label = "Broken" })
assertEqual(ok, false, "failed replacement result")
assertContains(detail, "overlay creation failed", "failed replacement detail")
assertEqual(Movers:GetEntry("alpha"), currentEntry, "failed replacement preserves current entry")
assertEqual(currentEntry.retired, nil, "current entry remains active")

replacement.failApply = true
ok, detail = Movers:Apply("alpha", replacement)
assertEqual(ok, false, "position exception result")
assertContains(detail, "injected position failure", "position exception detail")
replacement.failApply = nil
replacement.noPoint = true
ok, detail = Movers:Apply("alpha", replacement)
assertEqual(ok, false, "missing position result")
assertContains(detail, "stored mover position unavailable", "missing position detail")
replacement.noPoint = nil

local beta = NewFrame("beta")
assertEqual(Movers:Register("beta", beta, { label = "Beta" }), true, "beta registration")
beta.failApply = true
ok, detail = Movers:ReapplyAll()
assertEqual(ok, false, "reapply aggregate failure")
assertContains(detail, "beta", "reapply failure identifies key")
beta.failApply = nil
assertEqual(Movers:ReapplyAll(), true, "reapply retry succeeds")

local refreshFailure = NewFrame("refresh failure")
refreshFailure.failRefresh = true
ok, detail = Movers:Register("gamma", refreshFailure, { label = "Gamma" })
assertEqual(ok, false, "handle refresh registration failure")
assertContains(detail, "handle refresh failed", "handle refresh detail")
assertEqual(Movers:GetEntry("gamma"), nil, "failed new entry not published")
assertEqual(overlays[#overlays].shown, false, "failed new overlay retired")
assertEqual(overlays[#overlays].mouseEnabled, false, "failed new overlay disabled")

assertEqual(Movers:Register(nil, alpha), false, "nil key rejected")
assertEqual(Movers:Register("", alpha), false, "empty key rejected")
assertEqual(Movers:Register("missing", nil), false, "nil frame rejected")
assertEqual(Movers:Apply("unknown"), false, "unknown apply rejected")
assertEqual(CountEntries(Movers._registered), 2, "only live registrations retained")

print("Mover registration lifecycle tests passed.")
