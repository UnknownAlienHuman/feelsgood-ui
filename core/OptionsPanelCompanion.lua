-- FeelsGoodUI: Options panel builder (Companion)

local _, ns = ...

local Shared = ns.OptionsShared or {}
local BuildPanelContext = Shared.BuildPanelContext

local function BuildPanel_Companion()
    local ctxFactory = Shared.CreateBuilderContext
    if type(ctxFactory) ~= "function" then
        return nil
    end

    local ctx = ctxFactory()
    local DB = ctx.DB
    local L = ctx.L or function(text) return text end
    local CreateScrollablePanel = ctx.CreateScrollablePanel
    local FRAME_STRATA_VALUES = ctx.FRAME_STRATA_VALUES
    local CreatePanelValueSetter = ctx.CreatePanelValueSetter
    local GetProfileSection = ctx.GetProfileSection

    local CreateApplySection = Shared.CreateApplySection
    local CreateBindingState = Shared.CreateBindingState
    local AddDescriptorBindings = Shared.AddDescriptorBindings
    local BuildLayout = Shared.BuildLayout
    local BindPanelRefresh = Shared.BindPanelRefresh
    local ReadBoolWithFallback = Shared.ReadBoolWithFallback
    local ReadIntWithFallback = Shared.ReadIntWithFallback
    local IntTransform = Shared.IntTransform

    local root, p = CreateScrollablePanel("Companion", 1100)

    local Refresh
    local bindingState = CreateBindingState()
    local widgets = BuildLayout(ctx, p, {
        { id = "title", type = "header", text = "Companion", y = -12 },
        { id = "header", type = "subheader", text = "Pet Bar / Micro Menu / Bags", anchor = "title", y = -10 },
    })

    local PANEL_KEY = "companion"
    local APPLY_KEY = "companion"

    local applySection = CreateApplySection(ctx, p, widgets.header, {
        panelKey = PANEL_KEY,
        applyKey = APPLY_KEY,
    })
    local applyState = applySection.applyState
    widgets = BuildLayout(ctx, p, {
        {
            id = "note",
            type = "note",
            text = "Micro Menu and Bags stay under Blizzard ownership while ActionBars -> Hide Blizzard bars is disabled. Pet Bar settings remain active either way.",
            anchor = { ref = "applySection", field = "status" },
            y = -8,
        },
        {
            id = "cpSize",
            type = "slider",
            label = "Companion button size",
            min = 24,
            max = 60,
            step = 1,
            anchor = "note",
            y = -14,
            numericEdit = { int = true },
        },
        {
            id = "cpSpacing",
            type = "slider",
            label = "Companion spacing",
            min = 0,
            max = 12,
            step = 1,
            anchor = "cpSize",
            y = -12,
            numericEdit = { int = true },
        },
        { id = "microHeader", type = "subheader", text = "Micro Menu + Bags", anchor = "cpSpacing", y = -14 },
        {
            id = "cpMicroEnable",
            type = "check",
            label = "Enable Micro Menu takeover",
            tooltip = "When ActionBars hide Blizzard bars, move the Micro Menu into the Companion holder.",
            anchor = "microHeader",
        },
        {
            id = "cpBagsEnable",
            type = "check",
            label = "Enable Bags takeover",
            tooltip = "When ActionBars hide Blizzard bars, move Bags into the Companion holder.",
            anchor = "cpMicroEnable",
            y = -2,
        },
        {
            id = "cpCompactBags",
            type = "check",
            label = "Compact bags (single trunk icon)",
            tooltip = "Show only backpack icon near the Micro Menu and render free slots count on top of it.",
            anchor = "cpBagsEnable",
            x = 20,
            y = -2,
        },
        { id = "petHeader", type = "subheader", text = "Pet Bar", anchor = "cpCompactBags", y = -14 },
        { id = "cpPetHotkeys", type = "check", label = "Show pet bar hotkeys", anchor = "petHeader" },
        { id = "cpPetStrataDD", type = "dropdown", label = "Pet Bar strata", width = 220, anchor = "cpPetHotkeys", y = -10 },
        {
            id = "cpPetLevel",
            type = "slider",
            label = "Pet Bar frame level",
            min = 1,
            max = 200,
            step = 1,
            anchor = "cpPetStrataDD",
            y = -14,
            numericEdit = { int = true },
        },
    }, {
        title = widgets.title,
        header = widgets.header,
        applySection = applySection,
    })
    local note = widgets.note
    local cpSize = widgets.cpSize
    local cpSpacing = widgets.cpSpacing
    local cpMicroEnable = widgets.cpMicroEnable
    local cpBagsEnable = widgets.cpBagsEnable
    local cpCompactBags = widgets.cpCompactBags
    local cpPetHotkeys = widgets.cpPetHotkeys
    local cpPetStrataDD = widgets.cpPetStrataDD
    local cpPetLevel = widgets.cpPetLevel

    local SetPV = CreatePanelValueSetter(applyState, function()
        return bindingState:IsRefreshing()
    end)

    local function IsRefreshing()
        return bindingState:IsRefreshing()
    end

    AddDescriptorBindings(bindingState.bindings, {
        {
            kind = "slider",
            widget = cpSize,
            contextKey = "cp",
            sectionPath = { "companion" },
            contextPath = { "buttonSize" },
            read = ReadIntWithFallback(32),
            transform = IntTransform(32),
            rule = { type = "int", min = 24, max = 60, fallback = 32 },
        },
        {
            kind = "slider",
            widget = cpSpacing,
            contextKey = "cp",
            sectionPath = { "companion" },
            contextPath = { "spacing" },
            read = ReadIntWithFallback(0),
            transform = IntTransform(0),
            rule = { type = "int", min = 0, max = 12, fallback = 0 },
        },
        {
            kind = "check",
            widget = cpMicroEnable,
            contextKey = "cp",
            sectionPath = { "companion" },
            contextPath = { "microMenu", "enabled" },
            read = ReadBoolWithFallback(true),
            rule = { type = "boolean", fallback = true },
        },
        {
            kind = "check",
            widget = cpBagsEnable,
            contextKey = "cp",
            sectionPath = { "companion" },
            contextPath = { "bags", "enabled" },
            read = ReadBoolWithFallback(true),
            rule = { type = "boolean", fallback = true },
        },
        {
            kind = "check",
            widget = cpCompactBags,
            contextKey = "cp",
            sectionPath = { "companion" },
            contextPath = { "bags", "compact" },
            read = ReadBoolWithFallback(true),
            rule = { type = "boolean", fallback = true },
        },
        {
            kind = "check",
            widget = cpPetHotkeys,
            contextKey = "cp",
            sectionPath = { "companion" },
            contextPath = { "petBar", "showHotkeys" },
            read = ReadBoolWithFallback(false),
            rule = { type = "boolean", fallback = false },
        },
        {
            kind = "dropdown",
            widget = cpPetStrataDD,
            contextKey = "cp",
            sectionPath = { "companion" },
            contextPath = { "petBar", "strata" },
            menuContext = function()
                return {
                    cp = GetProfileSection("companion"),
                }
            end,
            options = FRAME_STRATA_VALUES,
            read = function(value)
                return value or "LOW"
            end,
            rule = {
                type = "enum",
                values = FRAME_STRATA_VALUES,
                fallback = "LOW",
            },
        },
        {
            kind = "slider",
            widget = cpPetLevel,
            contextKey = "cp",
            sectionPath = { "companion" },
            contextPath = { "petBar", "level" },
            read = ReadIntWithFallback(35),
            transform = IntTransform(35),
            rule = { type = "int", min = 1, max = 200, fallback = 35 },
        },
    }, {
        isRefreshing = IsRefreshing,
        setValue = function(path, value, rule)
            SetPV(path, value, rule)
        end,
        getProfileSection = GetProfileSection,
    })

    Refresh = function()
        local context = (type(BuildPanelContext) == "function")
            and BuildPanelContext(GetProfileSection, PANEL_KEY)
            or {
                cp = GetProfileSection("companion"),
            }
        bindingState:Refresh(context)

        local usesCompanionOwner = DB and DB.ShouldHideBlizzardActionBars and DB:ShouldHideBlizzardActionBars()
        if usesCompanionOwner == false then
            note:SetText(L("Micro Menu and Bags are currently using Blizzard ownership because ActionBars -> Hide Blizzard bars is OFF."))
        else
            note:SetText(L("Micro Menu and Bags are currently managed by the Companion owner frame."))
        end

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

Shared.RegisterPanelBuilder("companion", BuildPanel_Companion)
