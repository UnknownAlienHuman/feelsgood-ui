-- FeelsGoodUI: Options panel builder (CenterBars)

local _, ns = ...

local Shared = ns.OptionsShared or {}
local BuildPanelContext = Shared.BuildPanelContext

local function BuildPanel_CenterBars()
    local ctxFactory = Shared.CreateBuilderContext
    if type(ctxFactory) ~= "function" then
        return nil
    end

    local ctx = ctxFactory()
    local CreateScrollablePanel = ctx.CreateScrollablePanel
    local CreatePanelValueSetter = ctx.CreatePanelValueSetter
    local GetProfileSection = ctx.GetProfileSection

    local CreateBindingState = Shared.CreateBindingState
    local AddDescriptorBindings = Shared.AddDescriptorBindings
    local BuildLayout = Shared.BuildLayout
    local BindPanelRefresh = Shared.BindPanelRefresh
    local ReadBoolWithFallback = Shared.ReadBoolWithFallback
    local ReadIntWithFallback = Shared.ReadIntWithFallback
    local IntTransform = Shared.IntTransform

    local PANEL_KEY = "center"
    local root, p = CreateScrollablePanel("CenterBars", 1200)
    local Refresh
    local bindingState = CreateBindingState()

    local widgets = BuildLayout(ctx, p, {
        { id = "title", type = "header", text = "CenterBars", y = -12 },
        { id = "header", type = "subheader", text = "Core", anchor = "title", y = -10 },
        {
            id = "applySection",
            type = "applySection",
            anchor = "header",
            options = {
                panelKey = PANEL_KEY,
                applyKey = "center",
            },
        },
        {
            id = "cScale",
            type = "slider",
            label = "Center scale",
            min = 0.60,
            max = 1.30,
            step = 0.01,
            anchor = { ref = "applySection", field = "status" },
            y = -14,
            numericEdit = { decimals = 2 },
        },
        {
            id = "cWidth",
            type = "slider",
            label = "Center width",
            min = 200,
            max = 900,
            step = 1,
            anchor = "cScale",
            y = -12,
            numericEdit = { int = true },
        },
        {
            id = "cResH",
            type = "slider",
            label = "Resource height",
            min = 6,
            max = 24,
            step = 1,
            anchor = "cWidth",
            y = -12,
            numericEdit = { int = true },
        },
        {
            id = "cPowH",
            type = "slider",
            label = "Power height",
            min = 6,
            max = 24,
            step = 1,
            anchor = "cResH",
            y = -12,
            numericEdit = { int = true },
        },
        {
            id = "cGap",
            type = "slider",
            label = "Bars gap",
            min = 0,
            max = 20,
            step = 1,
            anchor = "cPowH",
            y = -12,
            numericEdit = { int = true },
        },
        {
            id = "cMaxSeg",
            type = "slider",
            label = "Max class segments",
            min = 1,
            max = 20,
            step = 1,
            anchor = "cGap",
            y = -12,
            numericEdit = { int = true },
        },
        { id = "cShowClass", type = "check", label = "Show class resource bar (top)", anchor = "cMaxSeg", y = -14 },
        { id = "cHideBlizzClass", type = "check", label = "Hide Blizzard class resources", anchor = "cShowClass", y = -2 },
        { id = "cPowerText", type = "check", label = "Show power value text", anchor = "cHideBlizzClass", y = -2 },
        {
            id = "cClassResourceColor",
            type = "check",
            label = "Use class color for class resource bar",
            tooltip = "Applies player class color to runes/combo points/class segments",
            anchor = "cPowerText",
            y = -2,
        },
        {
            id = "cSpecRunes",
            type = "check",
            label = "Use spec color for DK runes",
            tooltip = "Blood/Frost/Unholy-specific override for DK runes",
            anchor = "cClassResourceColor",
            y = -2,
        },
        { id = "cLowHeader", type = "subheader", text = "Resource recolor", anchor = "cSpecRunes", y = -14 },
        {
            id = "cLowEnable",
            type = "check",
            label = "Enable resource recolor",
            tooltip = "Recolors both top resource and bottom power bars",
            anchor = "cLowHeader",
        },
        {
            id = "cLowPct",
            type = "slider",
            label = "Threshold (%)",
            min = 10,
            max = 95,
            step = 1,
            anchor = "cLowEnable",
            y = -12,
            numericEdit = { int = true },
        },
        { id = "cLowModeBelow", type = "radio", label = "Condition: below threshold", anchor = "cLowPct", y = -8 },
        { id = "cLowModeAbove", type = "radio", label = "Condition: above threshold", anchor = "cLowModeBelow", y = -2 },
        { id = "cLowSpark", type = "check", label = "Enable spark effect", anchor = "cLowModeAbove", y = -8 },
        { id = "cLowColor", type = "colorSwatch", label = "Low resource color", anchor = "cLowSpark", y = -10 },
    })

    local applySection = widgets.applySection
    local applyState = applySection.applyState
    local cScale = widgets.cScale
    local cWidth = widgets.cWidth
    local cResH = widgets.cResH
    local cPowH = widgets.cPowH
    local cGap = widgets.cGap
    local cMaxSeg = widgets.cMaxSeg
    local cShowClass = widgets.cShowClass
    local cHideBlizzClass = widgets.cHideBlizzClass
    local cPowerText = widgets.cPowerText
    local cClassResourceColor = widgets.cClassResourceColor
    local cSpecRunes = widgets.cSpecRunes
    local cLowEnable = widgets.cLowEnable
    local cLowPct = widgets.cLowPct
    local cLowModeBelow = widgets.cLowModeBelow
    local cLowModeAbove = widgets.cLowModeAbove
    local cLowSpark = widgets.cLowSpark
    local cLowColor = widgets.cLowColor

    local SetPV = CreatePanelValueSetter(applyState, function()
        return bindingState:IsRefreshing()
    end)

    local function IsRefreshing()
        return bindingState:IsRefreshing()
    end

    AddDescriptorBindings(bindingState.bindings, {
        {
            kind = "slider",
            widget = cScale,
            contextKey = "center",
            sectionPath = { "center" },
            contextPath = { "scale" },
            read = function(value)
                return tonumber(value) or 1.0
            end,
            rule = { type = "number", min = 0.60, max = 1.30, fallback = 1.0 },
        },
        {
            kind = "slider",
            widget = cWidth,
            contextKey = "center",
            sectionPath = { "center" },
            contextPath = { "width" },
            read = ReadIntWithFallback(420),
            transform = IntTransform(420),
            rule = { type = "int", min = 200, max = 900, fallback = 420 },
        },
        {
            kind = "slider",
            widget = cResH,
            contextKey = "center",
            sectionPath = { "center" },
            contextPath = { "resourceHeight" },
            read = ReadIntWithFallback(10),
            transform = IntTransform(10),
            rule = { type = "int", min = 6, max = 24, fallback = 10 },
        },
        {
            kind = "slider",
            widget = cPowH,
            contextKey = "center",
            sectionPath = { "center" },
            contextPath = { "powerHeight" },
            read = ReadIntWithFallback(12),
            transform = IntTransform(12),
            rule = { type = "int", min = 6, max = 24, fallback = 12 },
        },
        {
            kind = "slider",
            widget = cGap,
            contextKey = "center",
            sectionPath = { "center" },
            contextPath = { "spacing" },
            read = ReadIntWithFallback(5),
            transform = IntTransform(5),
            rule = { type = "int", min = 0, max = 20, fallback = 5 },
        },
        {
            kind = "slider",
            widget = cMaxSeg,
            contextKey = "center",
            sectionPath = { "center" },
            contextPath = { "maxSegments" },
            read = ReadIntWithFallback(10),
            transform = IntTransform(10),
            rule = { type = "int", min = 1, max = 20, fallback = 10 },
        },
        {
            kind = "check",
            widget = cShowClass,
            contextKey = "center",
            sectionPath = { "center" },
            contextPath = { "showClassBar" },
            read = ReadBoolWithFallback(true),
            rule = { type = "boolean", fallback = true },
        },
        {
            kind = "check",
            widget = cHideBlizzClass,
            contextKey = "center",
            sectionPath = { "center" },
            contextPath = { "hideBlizzardClassResources" },
            read = ReadBoolWithFallback(true),
            rule = { type = "boolean", fallback = true },
        },
        {
            kind = "check",
            widget = cPowerText,
            contextKey = "center",
            sectionPath = { "center" },
            contextPath = { "showPowerText" },
            read = ReadBoolWithFallback(true),
            rule = { type = "boolean", fallback = true },
        },
        {
            kind = "check",
            widget = cClassResourceColor,
            contextKey = "center",
            sectionPath = { "center" },
            contextPath = { "useClassColorForResource" },
            read = ReadBoolWithFallback(true),
            rule = { type = "boolean", fallback = true },
        },
        {
            kind = "check",
            widget = cSpecRunes,
            contextKey = "center",
            sectionPath = { "center" },
            contextPath = { "useSpecColorForRunes" },
            read = ReadBoolWithFallback(false),
            rule = { type = "boolean", fallback = false },
        },
        {
            kind = "check",
            widget = cLowEnable,
            contextKey = "center",
            sectionPath = { "center" },
            contextPath = { "threshold", "enabled" },
            read = ReadBoolWithFallback(false),
            rule = { type = "boolean", fallback = false },
        },
        {
            kind = "slider",
            widget = cLowPct,
            contextKey = "center",
            sectionPath = { "center" },
            contextPath = { "threshold", "percent" },
            read = ReadIntWithFallback(70),
            transform = IntTransform(70),
            rule = { type = "int", min = 10, max = 95, fallback = 70 },
        },
        {
            kind = "radioGroup",
            contextKey = "center",
            sectionPath = { "center" },
            contextPath = { "threshold", "mode" },
            entries = {
                { widget = cLowModeBelow, value = "below" },
                { widget = cLowModeAbove, value = "above" },
            },
            read = function(value)
                return (value == "above") and "above" or "below"
            end,
            rule = {
                type = "enum",
                values = { "below", "above" },
                fallback = "below",
            },
        },
        {
            kind = "check",
            widget = cLowSpark,
            contextKey = "center",
            sectionPath = { "center" },
            contextPath = { "threshold", "spark" },
            read = ReadBoolWithFallback(true),
            rule = { type = "boolean", fallback = true },
        },
        {
            kind = "colorSwatch",
            widget = cLowColor,
            contextKey = "center",
            sectionPath = { "center" },
            contextPath = { "threshold", "color" },
            defaultColor = { r = 1.00, g = 0.34, b = 0.12, a = 1.00 },
        },
    }, {
        isRefreshing = IsRefreshing,
        setValue = function(path, value, rule, applyKeys)
            SetPV(path, value, rule, applyKeys)
        end,
        getProfileSection = GetProfileSection,
    })

    Refresh = function()
        local context = (type(BuildPanelContext) == "function")
            and BuildPanelContext(GetProfileSection, PANEL_KEY)
            or {
                center = GetProfileSection("center"),
            }
        bindingState:Refresh(context)
        applyState:UpdateUI()
        if root._reflow then
            root._reflow()
        end
    end

    applySection:Bind(Refresh)
    BindPanelRefresh(root, Refresh)
    Refresh()

    return root
end

Shared.RegisterPanelBuilder("center", BuildPanel_CenterBars)
