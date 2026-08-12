-- FeelsGoodUI: Options panel builder (Edit Mode)

local _, ns = ...

local Shared = ns.OptionsShared or {}
local BuildPanelContext = Shared.BuildPanelContext
local GetPanelContract = Shared.GetPanelContract
local ResetProfileSections = Shared.ResetProfileSections

local function BuildPanel_EditMode()
    local ctxFactory = Shared.CreateBuilderContext
    if type(ctxFactory) ~= "function" then
        return nil
    end

    local ctx = ctxFactory()
    local Movers = ctx.Movers
    local Settings = ctx.Settings
    local CreateScrollablePanel = ctx.CreateScrollablePanel
    local SetProfileValue = ctx.SetProfileValue
    local GetProfileSection = ctx.GetProfileSection

    local CreateBindingState = Shared.CreateBindingState
    local AddDescriptorBindings = Shared.AddDescriptorBindings
    local BuildLayout = Shared.BuildLayout
    local BindPanelRefresh = Shared.BindPanelRefresh
    local ReadBoolWithFallback = Shared.ReadBoolWithFallback
    local ReadIntWithFallback = Shared.ReadIntWithFallback
    local IntTransform = Shared.IntTransform

    local root, p = CreateScrollablePanel("Edit Mode", 1200)

    local PANEL_KEY = "editmode"
    local panelContract = (type(GetPanelContract) == "function") and GetPanelContract(PANEL_KEY) or nil
    local RESET_SECTIONS = (panelContract and panelContract.resetSections) or { "movers", "editor" }

    local Refresh
    local bindingState = CreateBindingState()
    local widgets = BuildLayout(ctx, p, {
        { id = "title", type = "header", text = "Edit Mode", y = -12 },
        { id = "header", type = "subheader", text = "Frames", anchor = "title", y = -10 },
        {
            id = "unlockedCheck",
            type = "check",
            label = "Unlock frames (Edit mode)",
            tooltip = "Shows move overlays + grid; drag overlays to reposition",
            anchor = "header",
        },
        {
            id = "gridStep",
            type = "slider",
            label = "Grid step (px)",
            min = 4,
            max = 64,
            step = 1,
            anchor = "unlockedCheck",
            y = -16,
            numericEdit = { int = true },
        },
        { id = "snapHeader", type = "subheader", text = "Snapping", anchor = "gridStep", y = -16 },
        {
            id = "snapEnable",
            type = "check",
            label = "Enable snap",
            tooltip = "Snap while dragging (screen + other frames)",
            anchor = "snapHeader",
        },
        {
            id = "snapThreshold",
            type = "slider",
            label = "Snap threshold (px)",
            min = 2,
            max = 30,
            step = 1,
            anchor = "snapEnable",
            y = -12,
            numericEdit = { int = true },
        },
        { id = "snapToFrames", type = "check", label = "Snap to other frames", anchor = "snapThreshold", y = -8 },
        { id = "snapToGrid", type = "check", label = "Snap to grid", anchor = "snapToFrames", y = -2 },
        { id = "snapGuides", type = "check", label = "Show snap guides", anchor = "snapToGrid", y = -2 },
        { id = "nudgeHeader", type = "subheader", text = "Keyboard nudge", anchor = "snapGuides", y = -16 },
        {
            id = "nudgeStep",
            type = "slider",
            label = "Nudge step",
            min = 1,
            max = 20,
            step = 1,
            anchor = "nudgeHeader",
            y = -12,
            numericEdit = { int = true },
        },
        {
            id = "nudgeLarge",
            type = "slider",
            label = "Nudge step (Shift)",
            min = 5,
            max = 50,
            step = 1,
            anchor = "nudgeStep",
            y = -12,
            numericEdit = { int = true },
        },
        { id = "resizeHeader", type = "subheader", text = "Resize handle", anchor = "nudgeLarge", y = -16 },
        {
            id = "resizeEnable",
            type = "check",
            label = "Enable corner resize handle",
            tooltip = "BOTTOMRIGHT handle on supported frames",
            anchor = "resizeHeader",
        },
        { id = "resetPosBtn", type = "button", label = "Reset Positions", width = 160, anchor = "resizeEnable", y = -14 },
        { id = "undoBtn", type = "button", label = "Undo last", width = 160, anchor = "resetPosBtn", y = -6 },
        { id = "resetSectionBtn", type = "button", label = "Reset EditMode settings", width = 200, anchor = "undoBtn", y = -6 },
        {
            id = "usageNote",
            type = "note",
            text = "Movement is blocked in combat. Shift+Drag to move (snap/guides). Ctrl+Wheel scales selected frame; Ctrl+Alt+Wheel resizes. Click overlay for numeric inspector. Arrow keys nudge (Shift=large).",
            anchor = "resetSectionBtn",
            y = -8,
        },
    })
    local unlockedCheck = widgets.unlockedCheck
    local gridStep = widgets.gridStep
    local snapEnable = widgets.snapEnable
    local snapThreshold = widgets.snapThreshold
    local snapToFrames = widgets.snapToFrames
    local snapToGrid = widgets.snapToGrid
    local snapGuides = widgets.snapGuides
    local nudgeStep = widgets.nudgeStep
    local nudgeLarge = widgets.nudgeLarge
    local resizeEnable = widgets.resizeEnable
    local resetPosBtn = widgets.resetPosBtn
    local undoBtn = widgets.undoBtn
    local resetSectionBtn = widgets.resetSectionBtn

    if Movers and Movers.RegisterStateListener and not root._fguiMoversStateListenerRegistered then
        root._fguiMoversStateListenerRegistered = true
        Movers:RegisterStateListener(root, function()
            if root and root.refresh and root:IsVisible() then
                root:refresh()
            end
        end)
    end

    resetPosBtn:SetScript("OnClick", function()
        if Movers and Movers.ResetPositions then
            Movers:ResetPositions()
        end
    end)

    local function SyncMoversFromProfile()
        if Movers and Movers.SyncFromProfile then
            Movers:SyncFromProfile()
            return
        end

        local movers = GetProfileSection("movers")
        if Movers and Movers.SetUnlocked then
            Movers:SetUnlocked(movers.unlocked == true)
        end
        if Movers and Movers.RefreshEditorSettings then
            Movers:RefreshEditorSettings()
        end
    end

    undoBtn:SetScript("OnClick", function()
        if Settings and Settings.UndoPanel and Settings:UndoPanel(PANEL_KEY) then
            SyncMoversFromProfile()
            Refresh()
        end
    end)

    resetSectionBtn:SetScript("OnClick", function()
        if type(ResetProfileSections) == "function" and ResetProfileSections(RESET_SECTIONS) then
            if Settings and Settings.InvalidatePanelHistory then
                Settings:InvalidatePanelHistory(PANEL_KEY, (panelContract and panelContract.applyKeys) or "runtime")
            end
            SyncMoversFromProfile()
            Refresh()
        end
    end)

    local function RefreshEditorSettings()
        if Movers and Movers.RefreshEditorSettings then
            Movers:RefreshEditorSettings()
        end
    end

    local function RefreshUnlockedState()
        if Movers and Movers.SetUnlocked then
            local movers = GetProfileSection("movers")
            if movers.unlocked then
                Movers:SetUnlocked(true)
            end
        end
    end

    local function IsRefreshing()
        return bindingState:IsRefreshing()
    end

    AddDescriptorBindings(bindingState.bindings, {
        {
            kind = "check",
            widget = unlockedCheck,
            contextKey = "movers",
            sectionPath = { "movers" },
            contextPath = { "unlocked" },
            read = ReadBoolWithFallback(false),
            rule = { type = "boolean", fallback = false },
            afterSet = function(checked)
                if Movers and Movers.SetUnlocked then
                    Movers:SetUnlocked(checked)
                end
            end,
        },
        {
            kind = "slider",
            widget = gridStep,
            contextKey = "movers",
            sectionPath = { "movers" },
            contextPath = { "gridStep" },
            read = ReadIntWithFallback(10),
            transform = IntTransform(10),
            rule = { type = "int", min = 4, max = 64, fallback = 10 },
            afterSet = function()
                RefreshUnlockedState()
            end,
        },
        {
            kind = "check",
            widget = snapEnable,
            contextKey = "editor",
            sectionPath = { "editor" },
            contextPath = { "snap", "enabled" },
            read = ReadBoolWithFallback(true),
            rule = { type = "boolean", fallback = true },
            afterSet = RefreshEditorSettings,
        },
        {
            kind = "slider",
            widget = snapThreshold,
            contextKey = "editor",
            sectionPath = { "editor" },
            contextPath = { "snap", "threshold" },
            read = ReadIntWithFallback(10),
            transform = IntTransform(10),
            rule = { type = "int", min = 2, max = 30, fallback = 10 },
            afterSet = RefreshEditorSettings,
        },
        {
            kind = "check",
            widget = snapToFrames,
            contextKey = "editor",
            sectionPath = { "editor" },
            contextPath = { "snap", "toFrames" },
            read = ReadBoolWithFallback(true),
            rule = { type = "boolean", fallback = true },
            afterSet = RefreshEditorSettings,
        },
        {
            kind = "check",
            widget = snapToGrid,
            contextKey = "editor",
            sectionPath = { "editor" },
            contextPath = { "snap", "toGrid" },
            read = ReadBoolWithFallback(true),
            rule = { type = "boolean", fallback = true },
            afterSet = RefreshEditorSettings,
        },
        {
            kind = "check",
            widget = snapGuides,
            contextKey = "editor",
            sectionPath = { "editor" },
            contextPath = { "snap", "showGuides" },
            read = ReadBoolWithFallback(true),
            rule = { type = "boolean", fallback = true },
            afterSet = RefreshEditorSettings,
        },
        {
            kind = "slider",
            widget = nudgeStep,
            contextKey = "editor",
            sectionPath = { "editor" },
            contextPath = { "nudge", "step" },
            read = ReadIntWithFallback(1),
            transform = IntTransform(1),
            rule = { type = "int", min = 1, max = 20, fallback = 1 },
            afterSet = RefreshEditorSettings,
        },
        {
            kind = "slider",
            widget = nudgeLarge,
            contextKey = "editor",
            sectionPath = { "editor" },
            contextPath = { "nudge", "stepLarge" },
            read = ReadIntWithFallback(10),
            transform = IntTransform(10),
            rule = { type = "int", min = 5, max = 50, fallback = 10 },
            afterSet = RefreshEditorSettings,
        },
        {
            kind = "check",
            widget = resizeEnable,
            contextKey = "editor",
            sectionPath = { "editor" },
            contextPath = { "resize", "enabled" },
            read = ReadBoolWithFallback(true),
            rule = { type = "boolean", fallback = true },
            afterSet = RefreshEditorSettings,
        },
    }, {
        isRefreshing = IsRefreshing,
        setValue = function(path, value, rule)
            if bindingState:IsRefreshing() then
                return
            end

            SetProfileValue(path, value, rule, nil, PANEL_KEY)
        end,
    })

    Refresh = function()
        local context = (type(BuildPanelContext) == "function")
            and BuildPanelContext(GetProfileSection, PANEL_KEY)
            or {
                movers = GetProfileSection("movers"),
                editor = GetProfileSection("editor"),
            }
        bindingState:Refresh(context)
        if root._reflow then
            root._reflow()
        end
    end

    BindPanelRefresh(root, Refresh)
    Refresh()

    return root
end

Shared.RegisterPanelBuilder("edit", BuildPanel_EditMode)
