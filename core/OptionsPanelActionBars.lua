-- FeelsGoodUI: Options panel builder (ActionBars)

local _, ns = ...

local Shared = ns.OptionsShared or {}
local BuildPanelContext = Shared.BuildPanelContext

local function BuildPanel_ActionBars()
    local ctxFactory = Shared.CreateBuilderContext
    if type(ctxFactory) ~= "function" then
        return nil
    end

    local ctx = ctxFactory()
    local CreateScrollablePanel = ctx.CreateScrollablePanel
    local CreatePanelValueSetter = ctx.CreatePanelValueSetter
    local GetProfileSection = ctx.GetProfileSection
    local APPLY_KEYS_ACTIONBAR_HIDE = ctx.APPLY_KEYS_ACTIONBAR_HIDE

    local CreateBindingState = Shared.CreateBindingState
    local AddDescriptorBindings = Shared.AddDescriptorBindings
    local BuildLayout = Shared.BuildLayout
    local BindPanelRefresh = Shared.BindPanelRefresh
    local CreateActionBarSection = Shared.CreateActionBarSection
    local ReadBoolWithFallback = Shared.ReadBoolWithFallback
    local ReadIntWithFallback = Shared.ReadIntWithFallback
    local IntTransform = Shared.IntTransform

    local PANEL_KEY = "actionbars"
    local APPLY_KEY = "actionbars"
    local root, p = CreateScrollablePanel("ActionBars", 1500)
    local Refresh
    local bindingState = CreateBindingState()

    local centerBarSpecs = {
        {
            header = "Bar1",
            buttonsLabel = "Bar1 buttons (bottom)",
            rowsLabel = "Bar1 rows",
            buttonsPath = { "bars", 1, "buttons" },
            rowsPath = { "bars", 1, "rows" },
            buttonsDefault = 12,
            rowsDefault = 1,
            buttonsMin = 1,
            buttonsMax = 12,
            rowsMin = 1,
            rowsMax = 4,
        },
        {
            header = "Bar2",
            buttonsLabel = "Bar2 buttons (middle)",
            rowsLabel = "Bar2 rows",
            buttonsPath = { "bars", 2, "buttons" },
            rowsPath = { "bars", 2, "rows" },
            buttonsDefault = 12,
            rowsDefault = 1,
            buttonsMin = 1,
            buttonsMax = 12,
            rowsMin = 1,
            rowsMax = 4,
        },
        {
            header = "Bar3",
            buttonsLabel = "Bar3 buttons (top)",
            rowsLabel = "Bar3 rows",
            buttonsPath = { "bars", 3, "buttons" },
            rowsPath = { "bars", 3, "rows" },
            buttonsDefault = 12,
            rowsDefault = 1,
            buttonsMin = 1,
            buttonsMax = 12,
            rowsMin = 1,
            rowsMax = 4,
        },
    }
    local sideBarSpecs = {
        {
            header = "Bar4",
            enableLabel = "Enable Bar4 (right outer)",
            buttonsLabel = "Bar4 buttons",
            rowsLabel = "Bar4 rows",
            enablePath = { "bars", 4, "enabled" },
            buttonsPath = { "bars", 4, "buttons" },
            rowsPath = { "bars", 4, "rows" },
            enableDefault = false,
            buttonsDefault = 12,
            rowsDefault = 12,
            buttonsMin = 1,
            buttonsMax = 12,
            rowsMin = 1,
            rowsMax = 12,
        },
        {
            header = "Bar5",
            enableLabel = "Enable Bar5 (right inner)",
            buttonsLabel = "Bar5 buttons",
            rowsLabel = "Bar5 rows",
            enablePath = { "bars", 5, "enabled" },
            buttonsPath = { "bars", 5, "buttons" },
            rowsPath = { "bars", 5, "rows" },
            enableDefault = false,
            buttonsDefault = 12,
            rowsDefault = 12,
            buttonsMin = 1,
            buttonsMax = 12,
            rowsMin = 1,
            rowsMax = 12,
        },
    }

    local function BuildBarSectionGroup(specs, anchor)
        local latest = anchor
        local sections = {}
        for _, spec in ipairs(specs) do
            local widgets = CreateActionBarSection(ctx, p, latest, spec)
            if widgets and widgets.rows then
                latest = widgets.rows
            end
            sections[#sections + 1] = { spec = spec, widgets = widgets }
        end
        return {
            anchor = latest or anchor,
            sections = sections,
        }
    end

    local widgets = BuildLayout(ctx, p, {
        { id = "title", type = "header", text = "ActionBars", y = -12 },
        { id = "header", type = "subheader", text = "Core", anchor = "title", y = -10 },
        {
            id = "applySection",
            type = "applySection",
            anchor = "header",
            options = {
                panelKey = PANEL_KEY,
                applyKey = APPLY_KEY,
                restoreApplyKeys = APPLY_KEYS_ACTIONBAR_HIDE,
            },
        },
        {
            id = "abHideBlizz",
            type = "check",
            label = "Hide Blizzard bars",
            tooltip = "Hides Blizzard action bars so only FeelsGoodUI bars remain",
            anchor = { ref = "applySection", field = "status" },
            y = -10,
        },
        { id = "abHotkeys", type = "check", label = "Show action button hotkeys", anchor = "abHideBlizz", y = -2 },
        {
            id = "abAutoHide",
            type = "check",
            label = "Auto-hide out of combat",
            tooltip = "Hides FeelsGoodUI action bars while out of combat and not hovered",
            anchor = "abHotkeys",
            y = -2,
        },
        {
            id = "abSize",
            type = "slider",
            label = "Button size",
            min = 24,
            max = 60,
            step = 1,
            anchor = "abAutoHide",
            y = -16,
            numericEdit = { int = true },
        },
        {
            id = "abSpacing",
            type = "slider",
            label = "Spacing",
            min = 0,
            max = 12,
            step = 1,
            anchor = "abSize",
            y = -12,
            numericEdit = { int = true },
        },
        { id = "centerHeader", type = "subheader", text = "Center Bars (1-3)", anchor = "abSpacing", y = -14 },
        {
            id = "centerBars",
            type = "custom",
            anchor = "centerHeader",
            build = function(_, _, anchor)
                return BuildBarSectionGroup(centerBarSpecs, anchor)
            end,
        },
        {
            id = "sideHeader",
            type = "subheader",
            text = "Side Bars (4-5 right)",
            anchor = { ref = "centerBars", field = "anchor" },
            y = -14,
        },
        {
            id = "sideBars",
            type = "custom",
            anchor = "sideHeader",
            build = function(_, _, anchor)
                return BuildBarSectionGroup(sideBarSpecs, anchor)
            end,
        },
    })

    local applySection = widgets.applySection
    local applyState = applySection.applyState
    local abHideBlizz = widgets.abHideBlizz
    local abHotkeys = widgets.abHotkeys
    local abAutoHide = widgets.abAutoHide
    local abSize = widgets.abSize
    local abSpacing = widgets.abSpacing
    local barSections = {}

    local function AppendBarSections(group)
        if type(group) ~= "table" or type(group.sections) ~= "table" then
            return
        end
        for _, entry in ipairs(group.sections) do
            barSections[#barSections + 1] = entry
        end
    end

    AppendBarSections(widgets.centerBars)
    AppendBarSections(widgets.sideBars)

    local SetPV = CreatePanelValueSetter(applyState, function()
        return bindingState:IsRefreshing()
    end)

    local function IsRefreshing()
        return bindingState:IsRefreshing()
    end

    local descriptors = {
        {
            kind = "check",
            widget = abHideBlizz,
            contextKey = "ab",
            sectionPath = { "actionbars" },
            contextPath = { "hideBlizzard" },
            read = ReadBoolWithFallback(true),
            rule = { type = "boolean", fallback = true },
            applyKeys = APPLY_KEYS_ACTIONBAR_HIDE,
        },
        {
            kind = "check",
            widget = abHotkeys,
            contextKey = "ab",
            sectionPath = { "actionbars" },
            contextPath = { "showHotkeys" },
            read = ReadBoolWithFallback(false),
            rule = { type = "boolean", fallback = false },
        },
        {
            kind = "check",
            widget = abAutoHide,
            contextKey = "ab",
            sectionPath = { "actionbars" },
            contextPath = { "autoHide", "enabled" },
            read = ReadBoolWithFallback(false),
            rule = { type = "boolean", fallback = false },
        },
        {
            kind = "slider",
            widget = abSize,
            contextKey = "ab",
            sectionPath = { "actionbars" },
            contextPath = { "buttonSize" },
            read = ReadIntWithFallback(32),
            transform = IntTransform(32),
            rule = { type = "int", min = 24, max = 60, fallback = 32 },
        },
        {
            kind = "slider",
            widget = abSpacing,
            contextKey = "ab",
            sectionPath = { "actionbars" },
            contextPath = { "spacing" },
            read = ReadIntWithFallback(0),
            transform = IntTransform(0),
            rule = { type = "int", min = 0, max = 12, fallback = 0 },
        },
    }

    local function AddBarDescriptors(entry)
        local spec = entry.spec
        local widgets = entry.widgets
        if not widgets then
            return
        end

        descriptors[#descriptors + 1] = {
            kind = "slider",
            widget = widgets.buttons,
            contextKey = "ab",
            sectionPath = { "actionbars" },
            contextPath = spec.buttonsPath,
            read = ReadIntWithFallback(spec.buttonsDefault or 12),
            transform = IntTransform(spec.buttonsDefault or 12),
            rule = {
                type = "int",
                min = spec.buttonsMin or 1,
                max = spec.buttonsMax or 12,
                fallback = spec.buttonsDefault or 12,
            },
        }

        descriptors[#descriptors + 1] = {
            kind = "slider",
            widget = widgets.rows,
            contextKey = "ab",
            sectionPath = { "actionbars" },
            contextPath = spec.rowsPath,
            read = ReadIntWithFallback(spec.rowsDefault or 1),
            transform = IntTransform(spec.rowsDefault or 1),
            rule = {
                type = "int",
                min = spec.rowsMin or 1,
                max = spec.rowsMax or 4,
                fallback = spec.rowsDefault or 1,
            },
        }

        if spec.enablePath and widgets.enable then
            descriptors[#descriptors + 1] = {
                kind = "check",
                widget = widgets.enable,
                contextKey = "ab",
                sectionPath = { "actionbars" },
                contextPath = spec.enablePath,
                read = ReadBoolWithFallback(spec.enableDefault == true),
                rule = { type = "boolean", fallback = spec.enableDefault or false },
            }
        end
    end

    for _, entry in ipairs(barSections) do
        AddBarDescriptors(entry)
    end

    AddDescriptorBindings(bindingState.bindings, descriptors, {
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
                ab = GetProfileSection("actionbars"),
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

Shared.RegisterPanelBuilder("actionbars", BuildPanel_ActionBars)
