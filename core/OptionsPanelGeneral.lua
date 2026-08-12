-- FeelsGoodUI: Options panel builder (General)

local _, ns = ...

local Shared = ns.OptionsShared or {}
local BuildPanelContext = Shared.BuildPanelContext

local function BuildPanel_General()
    local ctxFactory = Shared.CreateBuilderContext
    if type(ctxFactory) ~= "function" then
        return nil
    end

    local ctx = ctxFactory()
    local CreateScrollablePanel = ctx.CreateScrollablePanel
    local SetProfileValue = ctx.SetProfileValue
    local RequestApply = ctx.RequestApply
    local GetProfileSection = ctx.GetProfileSection
    local APPLY_KEY_THEME = ctx.APPLY_KEY_THEME
    local Media = ctx.Media
    local Perf = ctx.Perf
    local MinimapIcon = ctx.MinimapIcon

    local CreateBindingState = Shared.CreateBindingState
    local AddDescriptorBindings = Shared.AddDescriptorBindings
    local BuildLayout = Shared.BuildLayout
    local BindPanelRefresh = Shared.BindPanelRefresh

    local root, p = CreateScrollablePanel("FeelsGoodUI", 900)

    local PANEL_KEY = "general"
    local Refresh
    local bindingState = CreateBindingState()

    local widgets = BuildLayout(ctx, p, {
        { id = "title", type = "header", text = "FeelsGoodUI", y = -12 },
        { id = "genHeader", type = "subheader", text = "General", anchor = "title", y = -10 },
        { id = "debugCheck", type = "check", label = "Debug logging", tooltip = "More log spam in /fgui debug", anchor = "genHeader" },
        { id = "perfCheck", type = "check", label = "Perf overlay", tooltip = "Lightweight counters (events/sec)", anchor = "debugCheck", y = -2 },
        { id = "mmCheck", type = "check", label = "Minimap icon", tooltip = "Show a minimap button for quick access", anchor = "perfCheck", y = -2 },
        { id = "fontDD", type = "dropdown", label = "Font (LibSharedMedia key)", width = 260, anchor = "mmCheck", y = -10 },
        { id = "barDD", type = "dropdown", label = "Statusbar (LibSharedMedia key)", width = 260, anchor = "fontDD", y = -6 },
        { id = "resetHeader", type = "subheader", text = "Reset", anchor = "barDD", y = -18 },
        { id = "resetAllBtn", type = "button", label = "Reset All (Reload)", width = 180, anchor = "resetHeader", y = -8 },
    })
    local debugCheck = widgets.debugCheck
    local perfCheck = widgets.perfCheck
    local mmCheck = widgets.mmCheck
    local fontDD = widgets.fontDD
    local barDD = widgets.barDD
    local resetAllBtn = widgets.resetAllBtn

    resetAllBtn:SetScript("OnClick", function()
        FeelsGoodUIDB = nil
        ReloadUI()
    end)

    local function IsRefreshing()
        return bindingState:IsRefreshing()
    end

    AddDescriptorBindings(bindingState.bindings, {
        {
            kind = "check",
            widget = debugCheck,
            contextKey = "general",
            sectionPath = { "general" },
            contextPath = { "debug" },
            read = function(value)
                return value == true
            end,
            rule = { type = "boolean", fallback = false },
            applyKeys = "runtime",
        },
        {
            kind = "check",
            widget = perfCheck,
            contextKey = "general",
            sectionPath = { "general" },
            contextPath = { "perfOverlay" },
            read = function(value)
                return value == true
            end,
            rule = { type = "boolean", fallback = false },
            afterSet = function(checked)
                if Perf and Perf.SetEnabled then
                    Perf:SetEnabled(checked)
                end
            end,
        },
        {
            kind = "check",
            widget = mmCheck,
            contextKey = "minimap",
            sectionPath = { "minimap" },
            contextPath = { "hide" },
            read = function(value)
                return value ~= true
            end,
            write = function(checked)
                return not checked
            end,
            rule = { type = "boolean", fallback = false },
            applyKeys = "minimap",
            afterSet = function(checked)
                if MinimapIcon and MinimapIcon.SetHidden then
                    MinimapIcon:SetHidden(not checked)
                end
            end,
        },
        {
            kind = "dropdown",
            widget = fontDD,
            contextKey = "media",
            sectionPath = { "media" },
            contextPath = { "font" },
            menuContext = function()
                return {
                    media = GetProfileSection("media"),
                }
            end,
            options = function()
                if Media and Media.GetFontList then
                    return Media:GetFontList()
                end
                return {}
            end,
            read = function(value)
                return tostring(value or "")
            end,
            rule = { type = "string", fallback = "" },
            applyKeys = APPLY_KEY_THEME,
        },
        {
            kind = "dropdown",
            widget = barDD,
            contextKey = "media",
            sectionPath = { "media" },
            contextPath = { "statusbar" },
            menuContext = function()
                return {
                    media = GetProfileSection("media"),
                }
            end,
            options = function()
                if Media and Media.GetStatusbarList then
                    return Media:GetStatusbarList()
                end
                return {}
            end,
            read = function(value)
                return tostring(value or "")
            end,
            rule = { type = "string", fallback = "" },
            applyKeys = APPLY_KEY_THEME,
        },
    }, {
        isRefreshing = IsRefreshing,
        setValue = function(path, value, rule, applyKeys)
            if bindingState:IsRefreshing() then
                return
            end

            local keys = applyKeys or "runtime"
            SetProfileValue(path, value, rule, keys, PANEL_KEY)
            RequestApply(keys, PANEL_KEY)
        end,
        getProfileSection = GetProfileSection,
    })

    Refresh = function()
        local context = (type(BuildPanelContext) == "function")
            and BuildPanelContext(GetProfileSection, PANEL_KEY)
            or {
                general = GetProfileSection("general"),
                minimap = GetProfileSection("minimap"),
                media = GetProfileSection("media"),
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

Shared.RegisterPanelBuilder("general", BuildPanel_General)
