-- FeelsGoodUI: Movers (Stage 43: Visual editor v2)
-- Draggable overlays for our own frames + snap/guides/resize/inspector/nudge.
--
-- Design goals:
--  - no heavy frameworks
--  - no taint: never touch Blizzard EditMode frames; block movement/resizing in combat
--  - safe with Secure frames: only move our holders, and only out of combat
--  - low overhead: snap targets are cached per-drag; guides/inspector are reused

local _, ns = ...

local Movers = {}
ns.Movers = Movers

local DB = ns.DB
local Log = ns.Log
local Media = ns.Media
local U = ns.U
local L = ns.L or function(text) return text end
local Shared = ns.MoversShared or {}
local SnapGridModule = ns.MoversSnapGrid
local Transactions = ns.MoversTransactions
local InspectorModule = ns.MoversInspector
local EditorModule = ns.MoversEditor

local GetProfileSection = Shared.GetProfileSection
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
local BuildStoredPointWrites = Shared.BuildStoredPointWrites
local ResolveStoredPointFromFrame = Shared.ResolveStoredPointFromFrame
local GridStep = Shared.GridStep
local EditorCfg = Shared.EditorCfg
local RequestApplyForKeys = Shared.RequestApplyForKeys

Movers._registered = Movers._registered or {}
Movers._unlocked = Movers._unlocked or false
Movers._activeKey = Movers._activeKey or nil
Movers._activeOverlay = Movers._activeOverlay or nil
Movers._stateListeners = setmetatable({}, { __mode = "k" })

-- Grid state
Movers._grid = Movers._grid or {
    frame = nil,
    textures = nil,
    builtW = 0,
    builtH = 0,
    step = 0,
}

-- Reused scratch tables for snap targets (avoid allocs in OnUpdate)
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
    Log = Log,
    Media = Media,
    L = L,
    Transactions = Transactions,
    IsSafeToEdit = IsSafeToEdit,
    UIParentRect = UIParentRect,
    GetFrameSnapSize = GetFrameSnapSize,
    Clamp = Clamp,
    ClampCenterOffsets = ClampCenterOffsets,
    GetMoverSpec = function(key)
        return Movers:GetSpec(key)
    end,
    RequestApplyForRegisteredKey = function(key)
        Movers:RequestApplyFor(key)
    end,
    GetEditablePosition = function(key, frame)
        return GetEditablePosition(key, frame, Movers:GetSpec(key))
    end,
    SetEditablePosition = function(key, frame, x, y)
        return SetEditablePosition(key, frame, x, y, Movers:GetSpec(key))
    end,
    BuildStoredPointWrites = function(key, frame)
        local spec = Movers:GetSpec(key)
        local point = ResolveStoredPointFromFrame(key, frame, spec)
        if not point then return nil, nil, nil, "Mover position unavailable" end
        local _, writes, applyKeys, panelKey, detail = BuildStoredPointWrites(key, spec, point, frame)
        return writes, applyKeys, panelKey, detail
    end,
}) or {}

local EnsureInspector = Inspector.EnsureInspector or function() end
local HideInspector = Inspector.HideInspector or function() end
local GetPosition = Inspector.GetPosition or function() return 0, 0 end
local SetPosition = Inspector.SetPosition or function() end
local SupportsScale = Inspector.SupportsScale or function() return false end
local SupportsResize = Inspector.SupportsResize or function() return false end
local GetResizeValue = Inspector.GetResizeValue or function() return 160, 20 end
local PreviewResizeValue = Inspector.PreviewResizeValue or function(_, width, height) return width, height end
local CancelResizePreview = Inspector.CancelResizePreview or function() return false end
local SetResizeValue = Inspector.SetResizeValue or function() end
local GetScaleValue = Inspector.GetScaleValue or function() return 1 end
local SetScaleValue = Inspector.SetScaleValue or function() end
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
    CancelResizePreview = CancelResizePreview,
    SetResizeValue = SetResizeValue,
    GetScaleValue = GetScaleValue,
    SetScaleValue = SetScaleValue,
    ComputeWheelResizePair = ComputeWheelResizePair,
    HandleWheelAction = HandleWheelAction,
}) or {}

local SetGlobalHintVisible = Editor.SetGlobalHintVisible or function() end
local CreateOverlay = Editor.CreateOverlay or function() return nil, function() end end
local EnsureKeyListener = Editor.EnsureKeyListener or function() end
local DisableKeyListener = Editor.DisableKeyListener or function() end

-- -----------------------------
-- Overlay creation
-- -----------------------------

-- -----------------------------
-- Public API
-- -----------------------------

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
    if normalized.positionApplyKeys == nil then
        normalized.positionApplyKeys = "movers"
    end
    if type(normalized.panelKey) ~= "string" or normalized.panelKey == "" then
        normalized.panelKey = "editmode"
    end
    if type(normalized.label) ~= "string" or normalized.label == "" then
        normalized.label = label or key
    end
    return normalized
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
    overlay:SetScript("OnUpdate", nil)
    if type(overlay._cancelPreview) == "function" then
        overlay._cancelPreview()
    end
    SetOverlayActiveVisual(overlay, false)
end

local RETIRED_OVERLAY_SCRIPTS = {
    "OnShow",
    "OnHide",
    "OnClick",
    "OnEnter",
    "OnLeave",
    "OnDragStart",
    "OnDragStop",
    "OnMouseWheel",
    "OnUpdate",
}

local RETIRED_HANDLE_SCRIPTS = {
    "OnEnter",
    "OnLeave",
    "OnMouseDown",
    "OnMouseUp",
    "OnUpdate",
}

local function ConfigureMoverFrame(frame)
    if not frame then return false, "Mover frame unavailable" end
    if type(frame.SetMovable) ~= "function" then
        return false, "Mover frame lacks SetMovable"
    end
    if type(frame.SetClampedToScreen) ~= "function" then
        return false, "Mover frame lacks SetClampedToScreen"
    end

    local movableOK, movableDetail = pcall(frame.SetMovable, frame, true)
    if not movableOK then
        return false, "SetMovable failed: " .. tostring(movableDetail)
    end
    local clampOK, clampDetail = pcall(frame.SetClampedToScreen, frame, true)
    if not clampOK then
        return false, "SetClampedToScreen failed: " .. tostring(clampDetail)
    end
    return true
end

local function ClearScripts(target, scripts)
    if not (target and type(target.SetScript) == "function") then return end
    for i = 1, #scripts do
        pcall(target.SetScript, target, scripts[i], nil)
    end
end

local function RetireMoverEntry(owner, entry)
    if type(entry) ~= "table" or entry.retired == true then return end

    local overlay = entry.overlay
    if overlay then
        AbortOverlayInteraction(overlay)
        ClearScripts(overlay, RETIRED_OVERLAY_SCRIPTS)
        overlay._cancelPreview = nil
        if type(overlay.EnableMouse) == "function" then
            pcall(overlay.EnableMouse, overlay, false)
        end

        local handle = overlay.handle
        if handle then
            ClearScripts(handle, RETIRED_HANDLE_SCRIPTS)
            if type(handle.EnableMouse) == "function" then
                pcall(handle.EnableMouse, handle, false)
            end
            if type(handle.Hide) == "function" then pcall(handle.Hide, handle) end
        end
        if type(overlay.Hide) == "function" then pcall(overlay.Hide, overlay) end
    end

    if owner._activeOverlay == overlay or owner._activeKey == entry.key then
        owner._activeKey = nil
        owner._activeOverlay = nil
        HideGuides()
        HideInspector()
    end

    entry.retired = true
    entry._handleRefresh = nil
end

local function CreateMoverEntry(key, frame, descriptor)
    local configured, configureDetail = ConfigureMoverFrame(frame)
    if not configured then return nil, configureDetail end

    local created, overlay, handleRefresh = pcall(
        CreateOverlay,
        key,
        frame,
        descriptor.label
    )
    if not created then
        return nil, "Mover overlay creation failed: " .. tostring(overlay)
    end
    if not overlay then
        return nil, "Mover overlay creation returned nil"
    end

    return {
        key = key,
        frame = frame,
        overlay = overlay,
        label = descriptor.label,
        spec = descriptor,
        _handleRefresh = handleRefresh,
    }
end

local function RefreshEntryHandle(entry)
    if not (entry and type(entry._handleRefresh) == "function") then
        return true
    end
    local ok, detail = pcall(entry._handleRefresh)
    if not ok then
        return false, "Mover handle refresh failed: " .. tostring(detail)
    end
    return true
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
        spec.requestApply(spec, key)
        return
    end

    local keys
    if Transactions and type(Transactions.MergeApplyKeys) == "function" then
        keys = Transactions:MergeApplyKeys(
            spec and spec.applyKeys,
            (spec and spec.positionApplyKeys) or "movers"
        )
    else
        keys = {}
        local seen = {}
        local function Add(value)
            if type(value) == "string" then
                if value ~= "" and not seen[value] then
                    seen[value] = true
                    keys[#keys + 1] = value
                end
            elseif type(value) == "table" then
                for i = 1, #value do Add(value[i]) end
            end
        end
        Add(spec and spec.applyKeys)
        Add((spec and spec.positionApplyKeys) or "movers")
    end
    return RequestApplyForKeys(keys, key)
end

function Movers:Register(key, frame, label, spec)
    if type(key) ~= "string" or key == "" then
        return false, "Mover registration key is required"
    end
    if not frame then
        return false, "Mover frame is required for " .. key
    end

    if type(label) == "table" and spec == nil then
        spec = label
        label = spec.label
    end

    local descriptor = NormalizeRegistrationSpec(key, label, spec)
    local existing = self._registered[key]
    if existing and existing.frame == frame and existing.retired ~= true then
        local configured, configureDetail = ConfigureMoverFrame(frame)
        if not configured then return false, key .. ": " .. tostring(configureDetail) end

        existing.label = descriptor.label
        existing.spec = descriptor
        existing.key = key
        if existing.overlay and existing.overlay.text and type(existing.overlay.text.SetText) == "function" then
            pcall(existing.overlay.text.SetText, existing.overlay.text, descriptor.label)
        end
        local refreshed, refreshDetail = RefreshEntryHandle(existing)
        if not refreshed then return false, key .. ": " .. tostring(refreshDetail) end
        return true, "reused"
    end

    local replacement, createDetail = CreateMoverEntry(key, frame, descriptor)
    if not replacement then
        return false, key .. ": " .. tostring(createDetail)
    end

    self._registered[key] = replacement
    if self._unlocked then replacement.overlay:Show() else replacement.overlay:Hide() end
    local refreshed, refreshDetail = RefreshEntryHandle(replacement)
    if not refreshed then
        self._registered[key] = existing
        RetireMoverEntry(self, replacement)
        return false, key .. ": " .. tostring(refreshDetail)
    end

    if existing then
        RetireMoverEntry(self, existing)
    end
    return true, existing and "replaced" or "registered"
end

function Movers:Apply(key, frame)
    if type(key) ~= "string" or key == "" then
        return false, "Mover apply key is required"
    end

    local entry = self:GetEntry(key)
    local target = frame or (entry and entry.frame) or nil
    if not target then
        return false, "Mover frame unavailable for " .. key
    end

    local ok, normalized = pcall(ApplyStoredPoint, key, target, entry and entry.spec or nil)
    if not ok then
        return false, key .. ": mover position apply failed: " .. tostring(normalized)
    end
    if type(normalized) ~= "table" then
        return false, key .. ": stored mover position unavailable"
    end
    return true, normalized
end

function Movers:ReapplyAll()
    local firstDetail
    for key, entry in pairs(self._registered) do
        if entry and entry.frame and entry.retired ~= true then
            local applied, detail = self:Apply(key, entry.frame)
            if applied == false and not firstDetail then
                firstDetail = tostring(detail)
            end
        end
    end
    if firstDetail then return false, firstDetail end
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

    self:ClearActiveInteraction()

    if not (Transactions and type(Transactions.CommitWrites) == "function") then
        Log:Warn("Mover transaction owner unavailable.")
        return false
    end

    local positions = GetProfileSection("positions")
    local writes = {}

    for key in pairs(positions) do
        if defaults[key] == nil then
            writes[#writes + 1] = { path = { "positions", key }, value = nil }
        end
    end

    for key, value in pairs(defaults) do
        local current = positions[key]
        local same = type(current) == "table"
            and current.point == value.point
            and current.relPoint == value.relPoint
            and tonumber(current.x) == tonumber(value.x)
            and tonumber(current.y) == tonumber(value.y)
        if not same then
            writes[#writes + 1] = {
                path = { "positions", key },
                value = U.DeepCopy(value),
            }
        end
    end

    if #writes == 0 then
        Log:Info("Positions already match defaults")
        return false
    end

    local changed, detail = Transactions:CommitWrites("movers", writes, "editmode")
    if changed == false then
        if detail then Log:Warn("Position reset failed: " .. tostring(detail)) end
        return false
    end

    Log:Info("Positions reset to defaults")
    return true
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
                local ok = pcall(callback, owner._unlocked, owner, key)
                if not ok then
                    Log:Warn("Movers state listener failed for " .. tostring(key))
                end
            end
        end
    end

    if not opts.silent then
        Log:Info("Movers " .. (owner._unlocked and "UNLOCKED" or "LOCKED"))
    end
end

function Movers:RegisterStateListener(key, callback)
    if key == nil then
        return false, "Mover state listener key is required"
    end
    if type(callback) ~= "function" then
        return false, "Mover state listener callback is required"
    end

    self._stateListeners[key] = callback
    return true
end

function Movers:UnregisterStateListener(key)
    if key == nil then
        return false
    end

    local existed = self._stateListeners[key] ~= nil
    self._stateListeners[key] = nil
    return existed
end

function Movers:PreviewUnlocked(state, opts)
    if not IsSafeToEdit() then
        return false, "Mover preview blocked in combat"
    end
    ApplyUnlockedState(self, state, opts)
    return true
end

function Movers:SetUnlocked(state)
    local unlocked = state == true
    if not (Transactions and type(Transactions.CommitWrites) == "function") then
        Log:Warn("Mover state transaction owner unavailable.")
        return false
    end

    local changed, detail = Transactions:CommitWrites("movers", {
        path = { "movers", "unlocked" },
        value = unlocked,
        rule = { type = "boolean", fallback = false },
    }, "editmode")
    if changed == false and detail then
        Log:Warn("Mover lock-state commit failed: " .. tostring(detail))
        return false
    end

    if IsSafeToEdit() then
        ApplyUnlockedState(self, unlocked)
    end
    return changed == true
end

function Movers:SyncFromProfile()
    self:ClearActiveInteraction()
    local movers = GetProfileSection("movers")
    ApplyUnlockedState(self, movers.unlocked, { silent = true })
    return self:RefreshEditorSettings()
end

function Movers:ApplyUnlockFromDB()
    return self:SyncFromProfile()
end

function Movers:RefreshEditorSettings()
    -- Called from Options when editor toggles change.
    if self._unlocked then
        SetGridVisible(true)
    end
    local firstDetail
    for _, entry in pairs(self._registered) do
        if entry and entry.retired ~= true then
            local refreshed, detail = RefreshEntryHandle(entry)
            if refreshed == false and not firstDetail then
                firstDetail = tostring(detail)
            end
        end
    end
    if firstDetail then return false, firstDetail end
    return true
end

function Movers:ApplyConfig()
    if InCombatLockdown() then
        return false, "Movers apply blocked in combat"
    end

    self:ClearActiveInteraction()
    local movers = GetProfileSection("movers")
    ApplyUnlockedState(self, movers.unlocked == true, { silent = true })

    local applied, applyDetail = self:ReapplyAll()
    if applied == false then return false, applyDetail end
    local refreshed, refreshDetail = self:RefreshEditorSettings()
    if refreshed == false then return false, refreshDetail end
    return true
end

-- Rebuild grid on resize/scale changes (only while unlocked)
local gridEvents = CreateFrame("Frame")
gridEvents:RegisterEvent("DISPLAY_SIZE_CHANGED")
gridEvents:RegisterEvent("UI_SCALE_CHANGED")
gridEvents:SetScript("OnEvent", function()
    if not Movers._unlocked then return end
    EnsureGridBuilt()
end)
