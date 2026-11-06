-- FeelsGoodUI: Movers (Stage 43: Visual editor v2)
-- Draggable overlays for our own frames + snap/guides/resize/inspector/nudge.
--
-- Design goals:
--  - no heavy frameworks
--  - no taint: never touch Blizzard EditMode frames; block movement/resizing in combat
--  - safe with Secure frames: only move our holders, and only out of combat
--  - low overhead: snap targets are cached per-drag; guides/inspector are reused
--  - persisted mover mutations commit through Settings/Apply, never during preview

local _, ns = ...

local Movers = {}
ns.Movers = Movers

local DB = ns.DB
local Log = ns.Log
local Media = ns.Media
local Settings = ns.Settings
local U = ns.U
local L = ns.L or function(text) return text end
local Shared = ns.MoversShared or {}
local SnapGridModule = ns.MoversSnapGrid
local InspectorModule = ns.MoversInspector
local EditorModule = ns.MoversEditor

local GetProfileSection = Shared.GetProfileSection
local EnsureProfileSection = Shared.EnsureProfileSection
local IsSafeToEdit = Shared.IsSafeToEdit
local UIParentRect = Shared.UIParentRect
local UIWH = Shared.UIWH
local GetCursorUI = Shared.GetCursorUI
local Clamp = Shared.Clamp
local RoundToStep = Shared.RoundToStep
local ClampCenterOffsets = Shared.ClampCenterOffsets
local GetFrameSnapSize = Shared.GetFrameSnapSize
local GetFrameSnapBounds = Shared.GetFrameSnapBounds
local ApplyStoredPoint = Shared.ApplyStoredPoint
local GetEditablePosition = Shared.GetEditablePosition
local SetEditablePosition = Shared.SetEditablePosition
local EnsureCenterAnchor = Shared.EnsureCenterAnchor
local SavePoint = Shared.SavePoint
local GridStep = Shared.GridStep
local EditorCfg = Shared.EditorCfg
local NormalizeApplyKeys = Shared.NormalizeApplyKeys or function(keys)
    if type(keys) == "string" and keys ~= "" then return { keys } end
    return type(keys) == "table" and keys or {}
end
local RequestApplyForKeys = Shared.RequestApplyForKeys

local MOVERS_APPLY_KEY = Shared.MOVERS_APPLY_KEY or "movers"
local PANEL_KEY = Shared.PANEL_KEY or "editmode"
local unpackValues = unpack or table.unpack

local APPLY_SECTION_MAP = {
    unitframes = "unitframes",
    center = "center",
    experience = "experience",
    actionbars = "actionbars",
    companion = "companion",
}

Movers._registered = Movers._registered or {}
Movers._unlocked = Movers._unlocked or false
Movers._activeKey = Movers._activeKey or nil
Movers._activeOverlay = Movers._activeOverlay or nil
Movers._stateListeners = Movers._stateListeners or {}

Movers._grid = Movers._grid or {
    frame = nil,
    textures = nil,
    builtW = 0,
    builtH = 0,
    step = 0,
}

Movers._snapScratch = Movers._snapScratch or { xt = {}, yt = {} }
Movers._globalHint = Movers._globalHint or nil

local SnapGrid = (type(SnapGridModule) == "table" and type(SnapGridModule.Create) == "function") and SnapGridModule.Create({
    Movers = Movers,
    UIWH = UIWH,
    UIParentRect = UIParentRect,
    GridStep = GridStep,
    EditorCfg = EditorCfg,
    GetFrameSnapBounds = GetFrameSnapBounds,
    ClampCenterOffsets = ClampCenterOffsets,
    RoundToStep = RoundToStep,
}) or {}

local EnsureGridBuilt = SnapGrid.EnsureGridBuilt or function() end
local SetGridVisible = SnapGrid.SetGridVisible or function() end
local BuildSnapTargets = SnapGrid.BuildSnapTargets or function() return nil, nil end
local SnapOffsets = SnapGrid.SnapOffsets or function(x, y) return x, y end
local HideGuides = SnapGrid.HideGuides or function() end

local Inspector = (type(InspectorModule) == "table" and type(InspectorModule.Create) == "function") and InspectorModule.Create({
    Movers = Movers,
    DB = DB,
    Log = Log,
    Media = Media,
    U = U,
    L = L,
    GetProfileSection = GetProfileSection,
    EnsureProfileSection = EnsureProfileSection,
    IsSafeToEdit = IsSafeToEdit,
    UIParentRect = UIParentRect,
    GetFrameSnapSize = GetFrameSnapSize,
    Clamp = Clamp,
    ClampCenterOffsets = ClampCenterOffsets,
    GetMoverSpec = function(key)
        return Movers:GetSpec(key)
    end,
    RequestApplyForRegisteredKey = function(key)
        return Movers:RequestApplyFor(key)
    end,
    GetEditablePosition = function(key, frame)
        return GetEditablePosition(key, frame, Movers:GetSpec(key))
    end,
    SetEditablePosition = function(key, frame, x, y)
        return SetEditablePosition(key, frame, x, y, Movers:GetSpec(key))
    end,
    SavePoint = function(key, frame)
        return SavePoint(key, frame, Movers:GetSpec(key))
    end,
}) or {}

local EnsureInspector = Inspector.EnsureInspector or function() end
local HideInspector = Inspector.HideInspector or function() end
local GetPosition = Inspector.GetPosition or function() return 0, 0 end
local SetPosition = Inspector.SetPosition or function() end
local SupportsScale = Inspector.SupportsScale or function() return false end
local SupportsResize = Inspector.SupportsResize or function() return false end
local GetResizeValue = Inspector.GetResizeValue or function() return 160, 20 end
local PreviewResizeValue = Inspector.PreviewResizeValue or function(_, w, h) return w, h end
local SetResizeValue = Inspector.SetResizeValue or function() return false end
local GetScaleValue = Inspector.GetScaleValue or function() return 1 end
local SetScaleValue = Inspector.SetScaleValue or function() return false end
local ComputeWheelResizePair = Inspector.ComputeWheelResizePair or function(w, h) return w, h end
local UpdateInspector = Inspector.UpdateInspector or function() end
local ShowInspectorFor = Inspector.ShowInspectorFor or function() end
local HandleWheelAction = Inspector.HandleWheelAction or function() return false end

local Editor = (type(EditorModule) == "table" and type(EditorModule.Create) == "function") and EditorModule.Create({
    Movers = Movers,
    Log = Log,
    Media = Media,
    L = L,
    IsSafeToEdit = IsSafeToEdit,
    GetCursorUI = GetCursorUI,
    Clamp = Clamp,
    EditorCfg = EditorCfg,
    EnsureCenterAnchor = function(key, frame)
        return EnsureCenterAnchor(key, frame, Movers:GetSpec(key))
    end,
    GetPosition = GetPosition,
    BuildSnapTargets = BuildSnapTargets,
    SnapOffsets = SnapOffsets,
    GetFrameSnapSize = GetFrameSnapSize,
    ClampCenterOffsets = ClampCenterOffsets,
    SetPosition = SetPosition,
    UpdateInspector = UpdateInspector,
    ShowInspectorFor = ShowInspectorFor,
    HideInspector = HideInspector,
    HideGuides = HideGuides,
    SetActiveMover = function(key, overlay)
        Movers:SetActiveMover(key, overlay)
    end,
    SavePoint = function(key, frame)
        return SavePoint(key, frame, Movers:GetSpec(key))
    end,
    SupportsScale = SupportsScale,
    SupportsResize = SupportsResize,
    GetResizeValue = GetResizeValue,
    PreviewResizeValue = PreviewResizeValue,
    SetResizeValue = SetResizeValue,
    GetScaleValue = GetScaleValue,
    SetScaleValue = SetScaleValue,
    ComputeWheelResizePair = ComputeWheelResizePair,
    EnsureProfileSection = EnsureProfileSection,
    HandleWheelAction = HandleWheelAction,
}) or {}

local SetGlobalHintVisible = Editor.SetGlobalHintVisible or function() end
local CreateOverlay = Editor.CreateOverlay or function() return nil, function() end end
local EnsureKeyListener = Editor.EnsureKeyListener or function() end
local DisableKeyListener = Editor.DisableKeyListener or function() end

local function DeepCopy(value)
    if type(value) == "table" and U and type(U.DeepCopy) == "function" then
        return U.DeepCopy(value)
    end
    return value
end

local function DeepEqual(a, b, seen)
    if rawequal(a, b) then return true end
    if type(a) ~= type(b) or type(a) ~= "table" then return false end

    seen = seen or {}
    if seen[a] == b then return true end
    seen[a] = b

    for key, value in pairs(a) do
        if not DeepEqual(value, b[key], seen) then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end

local function CopyPath(path)
    local out = {}
    for i = 1, #(path or {}) do out[i] = path[i] end
    return out
end

local function CollectDiff(before, after, path, out)
    if DeepEqual(before, after) then return end

    if type(before) == "table" and type(after) == "table" then
        local seen = {}
        for key, value in pairs(before) do
            seen[key] = true
            local nextPath = CopyPath(path)
            nextPath[#nextPath + 1] = key
            CollectDiff(value, after[key], nextPath, out)
        end
        for key, value in pairs(after) do
            if not seen[key] then
                local nextPath = CopyPath(path)
                nextPath[#nextPath + 1] = key
                CollectDiff(nil, value, nextPath, out)
            end
        end
        return
    end

    out[#out + 1] = {
        path = CopyPath(path),
        value = DeepCopy(after),
    }
end

local function ResolveMutationSections(spec)
    local out, seen = {}, {}
    local explicit = type(spec) == "table" and spec.settingsSections or nil

    local function Add(section)
        if type(section) == "string" and section ~= "" and not seen[section] then
            seen[section] = true
            out[#out + 1] = section
        end
    end

    if type(explicit) == "string" then
        Add(explicit)
    elseif type(explicit) == "table" then
        for i = 1, #explicit do Add(explicit[i]) end
    end

    if #out == 0 then
        for _, applyKey in ipairs(NormalizeApplyKeys(spec and spec.applyKeys)) do
            Add(APPLY_SECTION_MAP[applyKey])
        end
    end

    return out
end

local function SnapshotMutationSections(spec)
    local profile = DB and type(DB.EnsureProfileRoot) == "function" and DB:EnsureProfileRoot() or nil
    if type(profile) ~= "table" then return nil end

    local sections = ResolveMutationSections(spec)
    if #sections == 0 then return nil end

    local records = {}
    for i = 1, #sections do
        local name = sections[i]
        local section = type(profile[name]) == "table" and profile[name] or nil
        if not section and DB and type(DB.EnsureSection) == "function" then
            section = DB:EnsureSection(name)
        end
        if type(section) ~= "table" then return nil end

        records[i] = {
            name = name,
            ref = section,
            before = DeepCopy(section),
            working = DeepCopy(section),
        }
    end

    for i = 1, #records do
        local record = records[i]
        profile[record.name] = record.working
    end
    return records
end

local function CaptureMutationSections(records)
    local profile = DB and type(DB.EnsureProfileRoot) == "function" and DB:EnsureProfileRoot() or nil
    if type(profile) ~= "table" then return false end

    for i = 1, #(records or {}) do
        local record = records[i]
        record.after = DeepCopy(profile[record.name])
    end
    return true
end

local function RestoreMutationSections(records)
    local profile = DB and type(DB.EnsureProfileRoot) == "function" and DB:EnsureProfileRoot() or nil
    if type(profile) ~= "table" then return false end

    for i = 1, #(records or {}) do
        local record = records[i]
        profile[record.name] = record.ref
    end
    return true
end

local function Pack(...)
    return { n = select("#", ...), ... }
end

local function CallPacked(fn, args)
    return fn(unpackValues(args, 1, args.n))
end

local function CommitSpecMutation(spec, setter, ...)
    if not (Settings and type(Settings.SetTx) == "function") then
        error("Movers settings transaction owner unavailable", 0)
    end

    local records = SnapshotMutationSections(spec)
    if not records then
        error("Movers mutation has no settings-section mapping for " .. tostring(spec and spec.key), 0)
    end

    local args = Pack(...)
    local ok, result = pcall(CallPacked, setter, args)
    local captured = ok and CaptureMutationSections(records)
    RestoreMutationSections(records)

    if not ok then
        error(result, 0)
    end
    if not captured then
        error("Movers mutation snapshot failed", 0)
    end

    local changes = {}
    for i = 1, #records do
        local record = records[i]
        local relative = {}
        CollectDiff(record.before, record.after, relative, changes)
        for j = 1, #changes do
            if changes[j].section == nil then
                changes[j].section = record.name
            end
        end
    end

    if #changes == 0 then
        return false, result
    end

    local began = type(Settings.BeginPanelUndoBatch) == "function"
        and Settings:BeginPanelUndoBatch(PANEL_KEY) == true
        or false

    local writeOK, writeErr = pcall(function()
        local changed = false
        for i = 1, #changes do
            local change = changes[i]
            local path = { change.section }
            for j = 1, #change.path do path[#path + 1] = change.path[j] end
            changed = Settings:SetTx(spec.applyKeys, path, change.value, nil, PANEL_KEY) == true or changed
        end
        result = changed
    end)

    if began and type(Settings.EndPanelUndoBatch) == "function" then
        Settings:EndPanelUndoBatch(PANEL_KEY)
    end
    if not writeOK then
        error(writeErr, 0)
    end

    return result == true
end

local function PreviewSpecMutation(spec, setter, reader, ...)
    local records = SnapshotMutationSections(spec)
    if not records then return false end

    local args = Pack(...)
    local ok, err = pcall(CallPacked, setter, args)
    local values
    if ok and type(reader) == "function" then
        values = Pack(reader(spec, spec.key))
    end
    RestoreMutationSections(records)

    if not ok then
        if Log and Log.Warn then
            Log:Warn("Mover preview failed for " .. tostring(spec and spec.key) .. ": " .. tostring(err))
        end
        return false
    end

    if values then
        return true, unpackValues(values, 1, values.n)
    end
    return true
end

local function WrapTransactionalMutators(spec)
    if type(spec) ~= "table" then return spec end

    local originalSetScale = spec.setScale
    if type(originalSetScale) == "function" then
        spec.setScale = function(...)
            return CommitSpecMutation(spec, originalSetScale, ...)
        end
        if type(spec.getScale) == "function" then
            spec.previewScale = function(...)
                return PreviewSpecMutation(spec, originalSetScale, spec.getScale, ...)
            end
        end
    end

    local originalSetSize = spec.setSize
    if type(originalSetSize) == "function" then
        spec.setSize = function(...)
            return CommitSpecMutation(spec, originalSetSize, ...)
        end
        if type(spec.getSize) == "function" then
            spec.previewSize = function(...)
                return PreviewSpecMutation(spec, originalSetSize, spec.getSize, ...)
            end
        end
    end

    local originalOnWheel = spec.onWheel
    if type(originalOnWheel) == "function" then
        spec.onWheel = function(...)
            return CommitSpecMutation(spec, originalOnWheel, ...)
        end
    end

    return spec
end

local function NormalizeRegistrationSpec(key, label, spec)
    local normalized = {}
    if type(spec) == "table" then
        for name, value in pairs(spec) do
            normalized[name] = value
        end
    end

    normalized.key = key
    if type(normalized.positionKey) ~= "string" or normalized.positionKey == "" then
        normalized.positionKey = key
    end
    if type(normalized.label) ~= "string" or normalized.label == "" then
        normalized.label = label or key
    end
    return WrapTransactionalMutators(normalized)
end

local function SetOverlayActiveVisual(overlay, active)
    if overlay and overlay.hl then
        overlay.hl:SetShown(active == true)
    end
end

local function HighlightActiveOverlay(owner, key)
    for registeredKey, entry in pairs(owner._registered) do
        if entry and entry.overlay then
            SetOverlayActiveVisual(entry.overlay, registeredKey == key)
        end
    end
end

local function AbortOverlayInteraction(overlay)
    if not overlay then
        return
    end

    overlay._dragging = false
    overlay._resizing = false
    overlay._snapXT = nil
    overlay._snapYT = nil
    overlay._previewW = nil
    overlay._previewH = nil
    overlay:SetScript("OnUpdate", nil)
    SetOverlayActiveVisual(overlay, false)
end

function Movers:GetEntry(key)
    if type(key) ~= "string" or key == "" then
        return nil
    end
    return self._registered[key]
end

function Movers:GetSpec(key)
    local entry = self:GetEntry(key)
    return entry and entry.spec or nil
end

function Movers:SetActiveMover(key, overlay)
    self._activeKey = key
    self._activeOverlay = overlay
    HighlightActiveOverlay(self, key)
end

function Movers:ClearActiveInteraction()
    for _, entry in pairs(self._registered) do
        if entry and entry.overlay then
            AbortOverlayInteraction(entry.overlay)
        end
    end

    HideGuides()
    HideInspector()
    self._activeKey = nil
    self._activeOverlay = nil
end

function Movers:RequestApplyFor(key)
    local spec = self:GetSpec(key)
    if spec and type(spec.requestApply) == "function" then
        return spec.requestApply(spec, key)
    end
    return RequestApplyForKeys(spec and spec.applyKeys, key)
end

function Movers:Register(key, frame, label, spec)
    if not key or not frame or self._registered[key] then return end

    if type(label) == "table" and spec == nil then
        spec = label
        label = spec.label
    end

    local descriptor = NormalizeRegistrationSpec(key, label, spec)

    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    local overlay, handleRefresh = CreateOverlay(key, frame, descriptor.label)
    if self._unlocked then overlay:Show() else overlay:Hide() end

    self._registered[key] = {
        frame = frame,
        overlay = overlay,
        label = descriptor.label,
        spec = descriptor,
        _handleRefresh = handleRefresh,
    }
end

function Movers:Apply(key, frame)
    local entry = self:GetEntry(key)
    local target = frame or (entry and entry.frame) or nil
    if not target then
        return false
    end

    ApplyStoredPoint(key, target, entry and entry.spec or nil)
    return true
end

function Movers:ReapplyAll()
    for key, entry in pairs(self._registered) do
        if entry and entry.frame then
            self:Apply(key, entry.frame)
        end
    end
    return true
end

function Movers:ResetPositions()
    local defaults = DB.defaults and DB.defaults.profile and DB.defaults.profile.positions
    if type(defaults) ~= "table" then
        Log:Warn("No default positions found.")
        return false
    end

    if not IsSafeToEdit() then
        Log:Warn("Cannot reset positions in combat.")
        return false
    end

    if not (Settings and type(Settings.SetTx) == "function") then
        Log:Warn("Movers settings transaction owner unavailable.")
        return false
    end

    local current = GetProfileSection("positions")
    if DeepEqual(current, defaults) then
        return false
    end

    self:ClearActiveInteraction()
    local changed = Settings:SetTx(
        MOVERS_APPLY_KEY,
        { "positions" },
        DeepCopy(defaults),
        nil,
        PANEL_KEY
    )
    if changed == true then
        RequestApplyForKeys(MOVERS_APPLY_KEY, "reset positions")
        Log:Info("Positions reset to defaults")
        return true
    end
    return false
end

local function ApplyUnlockedState(owner, state, opts)
    opts = opts or {}
    local unlocked = state == true
    local changed = owner._unlocked ~= unlocked
    owner._unlocked = unlocked

    for _, entry in pairs(owner._registered) do
        if entry.overlay then
            if owner._unlocked then entry.overlay:Show() else entry.overlay:Hide() end
        end
        if entry._handleRefresh then
            entry._handleRefresh()
        end
    end

    if not owner._unlocked then
        owner:ClearActiveInteraction()
    end

    SetGridVisible(owner._unlocked)
    SetGlobalHintVisible(owner._unlocked)

    if owner._unlocked then
        EnsureInspector()
        EnsureKeyListener()
    else
        DisableKeyListener()
    end

    if changed then
        for key, callback in pairs(owner._stateListeners) do
            if type(callback) == "function" then
                local ok = pcall(callback, owner._unlocked, owner)
                if not ok then
                    Log:Warn("Movers state listener failed for " .. tostring(key))
                end
            end
        end
    end

    if not opts.silent then
        Log:Info("Movers " .. (owner._unlocked and "UNLOCKED" or "LOCKED"))
    end
    return true
end

function Movers:RegisterStateListener(key, callback)
    if key == nil or type(callback) ~= "function" then
        return
    end

    self._stateListeners[key] = callback
end

function Movers:UnregisterStateListener(key)
    if key == nil then
        return
    end

    self._stateListeners[key] = nil
end

function Movers:SetUnlocked(state, options)
    local desired = state == true
    options = type(options) == "table" and options or nil
    if options and options.runtimeOnly == true then
        return ApplyUnlockedState(self, desired, options)
    end

    if not (Settings and type(Settings.SetTx) == "function") then
        Log:Warn("Movers settings transaction owner unavailable.")
        return false
    end

    local changed = Settings:SetTx(
        MOVERS_APPLY_KEY,
        { "movers", "unlocked" },
        desired,
        { type = "boolean", fallback = false },
        PANEL_KEY
    )
    if changed == true or self._unlocked ~= desired then
        RequestApplyForKeys(MOVERS_APPLY_KEY, "unlock state")
    end
    return changed == true
end

function Movers:SyncFromProfile()
    self:ClearActiveInteraction()
    self:ReapplyAll()
    local movers = GetProfileSection("movers")
    ApplyUnlockedState(self, movers.unlocked, { silent = true, runtimeOnly = true })
    self:RefreshEditorSettings()
    return true
end

function Movers:ApplyUnlockFromDB()
    return self:SyncFromProfile()
end

function Movers:ApplyConfig()
    if InCombatLockdown and InCombatLockdown() then
        return false, "Movers apply blocked in combat"
    end

    self:ReapplyAll()
    local movers = GetProfileSection("movers")
    ApplyUnlockedState(self, movers.unlocked, { silent = true, runtimeOnly = true })
    self:RefreshEditorSettings()
    return true
end

function Movers:RefreshEditorSettings()
    if self._unlocked then
        SetGridVisible(true)
    end
    for _, entry in pairs(self._registered) do
        if entry and entry._handleRefresh then
            entry._handleRefresh()
        end
    end
end

local gridEvents = CreateFrame("Frame")
gridEvents:RegisterEvent("DISPLAY_SIZE_CHANGED")
gridEvents:RegisterEvent("UI_SCALE_CHANGED")
gridEvents:SetScript("OnEvent", function()
    if not Movers._unlocked then return end
    EnsureGridBuilt()
end)
