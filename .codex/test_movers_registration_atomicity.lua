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
        refreshCalls = 0,
        hl = { shown = false },
        handle = { scripts = {}, mouseEnabled = true, shown = true },
        text = { value = label },
    }
    function overlay.hl:SetShown(value) self.shown = value == true end
    function overlay:SetScript(event, callback) self.scripts[event] = callback end
    function overlay:Show()
        if self.frame.failShow then error("injected show failure") end
        self.shown = true
    end
    function overlay:Hide()
        if self.frame.failHide then error("injected hide failure") end
        self.shown = false
    end
    function overlay:EnableMouse(value) self.mouseEnabled = value == true end
    function overlay.handle:SetScript(event, callback) self.scripts[event] = callback end
    function overlay.handle:EnableMouse(value) self.mouseEnabled = value == true end
    function overlay.handle:Hide() self.shown = false end
    function overlay.text:SetText(value)
        if frame.failLabel then error("injected label failure") end
        self.value = value
    end
    overlay._cancelPreview = function() overlay.cancelCalls = overlay.cancelCalls + 1 end
    return overlay
end

local ns = {
    DB = {
        defaults = { profile = { positions = sections.positions } },
    },
    Log = {
        Warn = function() end,
        Info = function() end,
    },
    Media = {},
    U = { DeepCopy = function(value) return value end },
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
            local point = sections.positions[key]
            if not point then return nil end
            frame.lastPoint = point
            return point
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
                    if frame.failOverlay then error("injected overlay failure") end
                    local overlay = NewOverlay(frame, label)
                    overlays[#overlays + 1] = overlay
                    local function Refresh()
                        overlay.refreshCalls = overlay.refreshCalls + 1
                        if frame.failRefresh then error("injected handle refresh failure") end
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
local entry = Movers:GetEntry("alpha")
assertEqual(entry.spec.custom, 1, "initial spec")
assertEqual(entry.overlay.text.value, "Alpha", "initial label")
assertEqual(entry.overlay.refreshCalls, 1, "initial refresh exactly once")

alpha.failRefresh = true
ok, detail = Movers:Register("alpha", alpha, { label = "Broken Refresh", custom = 2 })
assertEqual(ok, false, "same-frame refresh failure")
assertContains(detail, "handle refresh failed", "same-frame refresh detail")
assertEqual(entry.spec.custom, 1, "same-frame spec rolled back")
assertEqual(entry.label, "Alpha", "same-frame label rolled back")
assertEqual(entry.overlay.text.value, "Alpha", "same-frame text rolled back")
alpha.failRefresh = nil

alpha.failLabel = true
ok, detail = Movers:Register("alpha", alpha, { label = "Broken Label", custom = 3 })
assertEqual(ok, false, "same-frame label failure")
assertContains(detail, "label refresh failed", "same-frame label detail")
assertEqual(entry.spec.custom, 1, "label failure spec rolled back")
assertEqual(entry.label, "Alpha", "label failure label rolled back")
alpha.failLabel = nil

ok, detail = Movers:Register("alpha", alpha, { label = "Alpha Updated", custom = 4 })
assertEqual(ok, true, "same-frame retry succeeds")
assertEqual(detail, "reused", "same-frame retry detail")
assertEqual(entry.spec.custom, 4, "same-frame retry updates spec")
assertEqual(entry.overlay.text.value, "Alpha Updated", "same-frame retry updates label")

local badReplacement = NewFrame("bad replacement")
badReplacement.failHide = true
ok, detail = Movers:Register("alpha", badReplacement, { label = "Bad Replacement" })
assertEqual(ok, false, "replacement visibility failure")
assertContains(detail, "visibility failed", "replacement visibility detail")
assertEqual(Movers:GetEntry("alpha"), entry, "failed replacement preserves current entry")

local replacement = NewFrame("replacement")
local oldOverlay = entry.overlay
oldOverlay:SetScript("OnClick", function() end)
oldOverlay.handle:SetScript("OnMouseDown", function() end)
Movers:SetActiveMover("alpha", oldOverlay)
ok, detail = Movers:Register("alpha", replacement, { label = "Replacement", custom = 5 })
assertEqual(ok, true, "replacement succeeds")
assertEqual(detail, "replaced", "replacement detail")
local replacementEntry = Movers:GetEntry("alpha")
assertEqual(replacementEntry.frame, replacement, "replacement owns key")
assertEqual(entry.retired, true, "old entry retired")
assertEqual(oldOverlay.scripts.OnClick, nil, "old overlay scripts cleared")
assertEqual(oldOverlay.handle.scripts.OnMouseDown, nil, "old handle scripts cleared")
assertEqual(oldOverlay.mouseEnabled, false, "old overlay disabled")
assertEqual(oldOverlay.handle.mouseEnabled, false, "old handle disabled")
assertEqual(Movers._activeKey, nil, "old active key cleared")
assertEqual(Movers._activeOverlay, nil, "old active overlay cleared")

ok, detail = Movers:Apply("alpha", alpha)
assertEqual(ok, false, "stale frame apply rejected")
assertContains(detail, "does not own mover key", "stale frame detail")
assertEqual(alpha.applyCalls, 0, "stale frame untouched")
ok, detail = Movers:Apply("alpha", replacement)
assertEqual(ok, true, "current frame apply succeeds")
assertEqual(detail, sections.positions.alpha, "current frame normalized point")
assertEqual(replacement.applyCalls, 1, "current frame moved once")

replacement.failShow = true
ok, detail = Movers:PreviewUnlocked(true, { silent = true })
assertEqual(ok, false, "unlock presentation failure")
assertContains(detail, "visibility failed", "unlock presentation detail")
assertEqual(Movers._unlocked, false, "unlock state rolled back")
assertEqual(replacementEntry.overlay.shown, false, "overlay presentation rolled back")
replacement.failShow = nil
assertEqual(Movers:PreviewUnlocked(true, { silent = true }), true, "unlock retry succeeds")
assertEqual(Movers._unlocked, true, "unlock state committed")
assertEqual(replacementEntry.overlay.shown, true, "overlay shown after retry")

replacement.failRefresh = true
ok, detail = Movers:PreviewUnlocked(false, { silent = true })
assertEqual(ok, false, "lock refresh failure")
assertContains(detail, "handle refresh failed", "lock refresh detail")
assertEqual(Movers._unlocked, true, "lock failure restores unlocked state")
assertEqual(replacementEntry.overlay.shown, true, "lock failure restores overlay visibility")
replacement.failRefresh = nil

sections.movers.unlocked = false
replacement.failHide = true
ok, detail = Movers:ApplyConfig()
assertEqual(ok, false, "profile lock apply failure")
assertContains(detail, "visibility failed", "profile lock detail")
assertEqual(Movers._unlocked, true, "profile lock failure preserves runtime state")
replacement.failHide = nil
assertEqual(Movers:ApplyConfig(), true, "profile lock retry succeeds")
assertEqual(Movers._unlocked, false, "profile lock committed")

local beta = NewFrame("beta")
assertEqual(Movers:Register("beta", beta, { label = "Beta" }), true, "beta registration")
beta.failApply = true
ok, detail = Movers:ReapplyAll()
assertEqual(ok, false, "reapply failure propagates")
assertContains(detail, "beta", "reapply identifies key")
beta.failApply = nil
assertEqual(Movers:ReapplyAll(), true, "reapply retry succeeds")

assertEqual(Movers:Apply("unknown"), false, "unknown key rejected")
assertEqual(Movers:Register(nil, alpha), false, "nil key rejected")
assertEqual(Movers:Register("", alpha), false, "empty key rejected")
assertEqual(Movers:Register("missing", nil), false, "missing frame rejected")

print("Mover registration atomicity tests passed.")