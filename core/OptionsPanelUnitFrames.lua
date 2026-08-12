-- FeelsGoodUI: Options panel builder (UnitFrames)

local _, ns = ...

local Shared = ns.OptionsShared or {}
local BuildPanelContext = Shared.BuildPanelContext

local function BuildPanel_UnitFrames()
    local ctxFactory = Shared.CreateBuilderContext
    if type(ctxFactory) ~= "function" then
        return nil
    end

    local ctx = ctxFactory()
    local DB = ctx.DB
    local CreateScrollablePanel = ctx.CreateScrollablePanel
    local CreatePanelValueSetter = ctx.CreatePanelValueSetter
    local Settings = ctx.Settings
    local SetProfileValue = ctx.SetProfileValue
    local GetProfileSection = ctx.GetProfileSection
    local GetLivePreview = ctx.GetLivePreview

    local CreateBindingState = Shared.CreateBindingState
    local AddDescriptorBindings = Shared.AddDescriptorBindings
    local BuildLayout = Shared.BuildLayout
    local BindPanelRefresh = Shared.BindPanelRefresh
    local ReadBoolWithFallback = Shared.ReadBoolWithFallback
    local ReadNumberWithFallback = Shared.ReadNumberWithFallback
    local ReadIntWithFallback = Shared.ReadIntWithFallback
    local IntTransform = Shared.IntTransform

    local PANEL_KEY = "unitframes"
    local APPLY_KEY = "unitframes"
    local root, p = CreateScrollablePanel("UnitFrames", 1500)

    local Refresh
    local bindingState = CreateBindingState()
    local widgets = BuildLayout(ctx, p, {
        { id = "title", type = "header", text = "UnitFrames", y = -12 },
        { id = "header", type = "subheader", text = "Core", anchor = "title", y = -10 },
        {
            id = "applySection",
            type = "applySection",
            anchor = "header",
            options = {
                panelKey = PANEL_KEY,
                applyKey = APPLY_KEY,
            },
        },
        {
            id = "ufScale",
            type = "slider",
            label = "UnitFrames scale",
            min = 0.60,
            max = 1.30,
            step = 0.01,
            anchor = { ref = "applySection", field = "status" },
            y = -14,
            numericEdit = { decimals = 2 },
        },
        {
            id = "ufW",
            type = "slider",
            label = "Player health width",
            min = 120,
            max = 520,
            step = 1,
            anchor = "ufScale",
            y = -12,
            numericEdit = { int = true },
        },
        {
            id = "ufH",
            type = "slider",
            label = "Player health height",
            min = 14,
            max = 40,
            step = 1,
            anchor = "ufW",
            y = -12,
            numericEdit = { int = true },
        },
        {
            id = "tgtW",
            type = "slider",
            label = "Target width",
            min = 120,
            max = 520,
            step = 1,
            anchor = "ufH",
            y = -12,
            numericEdit = { int = true },
        },
        {
            id = "tgtH",
            type = "slider",
            label = "Target height",
            min = 14,
            max = 40,
            step = 1,
            anchor = "tgtW",
            y = -12,
            numericEdit = { int = true },
        },
        {
            id = "focusW",
            type = "slider",
            label = "Focus width",
            min = 120,
            max = 520,
            step = 1,
            anchor = "tgtH",
            y = -12,
            numericEdit = { int = true },
        },
        {
            id = "focusH",
            type = "slider",
            label = "Focus height",
            min = 14,
            max = 40,
            step = 1,
            anchor = "focusW",
            y = -12,
            numericEdit = { int = true },
        },
        {
            id = "ttW",
            type = "slider",
            label = "TargetTarget width",
            min = 120,
            max = 520,
            step = 1,
            anchor = "focusH",
            y = -12,
            numericEdit = { int = true },
        },
        {
            id = "ttH",
            type = "slider",
            label = "TargetTarget height",
            min = 14,
            max = 40,
            step = 1,
            anchor = "ttW",
            y = -12,
            numericEdit = { int = true },
        },
        { id = "extraHeader", type = "subheader", text = "Extra units", anchor = "ttH", y = -14 },
        { id = "showFocus", type = "check", label = "Show Focus frame", anchor = "extraHeader" },
        { id = "showTT", type = "check", label = "Show Target-of-Target frame", anchor = "showFocus", y = -2 },
        { id = "showPet", type = "check", label = "Show Pet frame", anchor = "showTT", y = -2 },
        { id = "cbHeader", type = "subheader", text = "Castbar", anchor = "showPet", y = -14 },
        { id = "cbEnable", type = "check", label = "Enable Castbar", anchor = "cbHeader" },
        {
            id = "cbHeight",
            type = "slider",
            label = "Castbar height",
            min = 8,
            max = 24,
            step = 1,
            anchor = "cbEnable",
            y = -12,
            numericEdit = { int = true },
        },
        { id = "auraHeader", type = "subheader", text = "Target Auras", anchor = "cbHeight", y = -14 },
        { id = "auraMini", type = "radio", label = "MINI: only my debuffs above target", anchor = "auraHeader" },
        { id = "auraClassic", type = "radio", label = "CLASSIC: buffs above, debuffs below", anchor = "auraMini", y = -2 },
        {
            id = "auraNote",
            type = "note",
            text = "HP value is right-aligned; percent is centered on the health bar.",
            anchor = "auraClassic",
            y = -8,
        },
        { id = "fmtHeader", type = "subheader", text = "Number Format", anchor = "auraClassic", y = -14 },
        {
            id = "fmtEnable",
            type = "check",
            label = "Short numbers (k/m/b)",
            tooltip = "Applies to UnitFrames health values and CenterBars power text",
            anchor = "fmtHeader",
        },
        { id = "fmtUpper", type = "check", label = "Uppercase suffixes (K/M/B)", anchor = "fmtEnable", x = 20, y = -2 },
        {
            id = "fmtSmall",
            type = "slider",
            label = "Decimals for 1k..9.9k",
            min = 0,
            max = 2,
            step = 1,
            anchor = "fmtUpper",
            y = -12,
            numericEdit = { int = true },
        },
        {
            id = "fmtLarge",
            type = "slider",
            label = "Decimals for 10k+",
            min = 0,
            max = 2,
            step = 1,
            anchor = "fmtSmall",
            y = -12,
            numericEdit = { int = true },
        },
        { id = "tiHeader", type = "subheader", text = "Target Info", anchor = "fmtLarge", y = -16 },
        { id = "tiEnable", type = "check", label = "Enable target name/info", anchor = "tiHeader" },
        { id = "tiName", type = "check", label = "Show target name", anchor = "tiEnable", x = 20, y = -2 },
        { id = "tiInfo", type = "check", label = "Show target info line", anchor = "tiName", y = -2 },
        { id = "tiPower", type = "check", label = "Show target power bar", anchor = "tiInfo", y = -2 },
        {
            id = "tiPowH",
            type = "slider",
            label = "Target power height",
            min = 6,
            max = 20,
            step = 1,
            anchor = "tiPower",
            y = -12,
            numericEdit = { int = true },
        },
        { id = "tiAnchorFrame", type = "radio", label = "Name anchor: above frame", anchor = "tiPowH", y = -8 },
        { id = "tiAnchorAuras", type = "radio", label = "Name anchor: above buffs/debuffs", anchor = "tiAnchorFrame", y = -2 },
        { id = "tiFontRegular", type = "radio", label = "Name font weight: regular", anchor = "tiAnchorAuras", y = -8 },
        { id = "tiFontBold", type = "radio", label = "Name font weight: bold", anchor = "tiFontRegular", y = -2 },
        { id = "tiColorInherit", type = "radio", label = "Name color: inherit from health bar", anchor = "tiFontBold", y = -8 },
        { id = "tiColorCustom", type = "radio", label = "Name color: custom", anchor = "tiColorInherit", y = -2 },
        { id = "tiColorSwatch", type = "colorSwatch", label = "Target name color", anchor = "tiColorCustom", y = -10 },
        {
            id = "colorHeader",
            type = "subheader",
            text = "Colors",
            anchor = { ref = "tiColorSwatch", field = "row" },
            y = -14,
        },
        { id = "playerHealthColor", type = "colorSwatch", label = "Player health color", anchor = "colorHeader", y = -10 },
        {
            id = "targetFallbackColor",
            type = "colorSwatch",
            label = "Target fallback color",
            anchor = { ref = "playerHealthColor", field = "row" },
            y = -10,
        },
        {
            id = "lowHPGlow",
            type = "check",
            label = "Enable low HP glow",
            anchor = { ref = "targetFallbackColor", field = "row" },
            y = -8,
        },
        {
            id = "lowHPPct",
            type = "slider",
            label = "Low HP threshold (%)",
            min = 5,
            max = 80,
            step = 1,
            anchor = "lowHPGlow",
            y = -12,
            numericEdit = { int = true },
        },
        {
            id = "lowHPAlpha",
            type = "slider",
            label = "Low HP max glow alpha",
            min = 0.10,
            max = 1.00,
            step = 0.01,
            anchor = "lowHPPct",
            y = -12,
            numericEdit = { decimals = 2 },
        },
        { id = "lowHPGlowColor", type = "colorSwatch", label = "Low HP glow color", anchor = "lowHPAlpha", y = -10 },
    })

    local applySection = widgets.applySection
    local applyState = applySection.applyState
    local ufScale = widgets.ufScale
    local ufW = widgets.ufW
    local ufH = widgets.ufH
    local tgtW = widgets.tgtW
    local tgtH = widgets.tgtH
    local focusW = widgets.focusW
    local focusH = widgets.focusH
    local ttW = widgets.ttW
    local ttH = widgets.ttH
    local showFocus = widgets.showFocus
    local showTT = widgets.showTT
    local showPet = widgets.showPet
    local cbEnable = widgets.cbEnable
    local cbHeight = widgets.cbHeight
    local auraMini = widgets.auraMini
    local auraClassic = widgets.auraClassic
    local fmtEnable = widgets.fmtEnable
    local fmtUpper = widgets.fmtUpper
    local fmtSmall = widgets.fmtSmall
    local fmtLarge = widgets.fmtLarge
    local tiEnable = widgets.tiEnable
    local tiName = widgets.tiName
    local tiInfo = widgets.tiInfo
    local tiPower = widgets.tiPower
    local tiPowH = widgets.tiPowH
    local tiAnchorFrame = widgets.tiAnchorFrame
    local tiAnchorAuras = widgets.tiAnchorAuras
    local tiFontRegular = widgets.tiFontRegular
    local tiFontBold = widgets.tiFontBold
    local tiColorInherit = widgets.tiColorInherit
    local tiColorCustom = widgets.tiColorCustom
    local tiColorSwatch = widgets.tiColorSwatch
    local playerHealthColor = widgets.playerHealthColor
    local targetFallbackColor = widgets.targetFallbackColor
    local lowHPGlow = widgets.lowHPGlow
    local lowHPPct = widgets.lowHPPct
    local lowHPAlpha = widgets.lowHPAlpha
    local lowHPGlowColor = widgets.lowHPGlowColor

    local SetPV = CreatePanelValueSetter(applyState, function()
        return bindingState:IsRefreshing()
    end)

    local function IsRefreshing()
        return bindingState:IsRefreshing()
    end

    local function GetUnitFrameDefaults()
        local profile = DB and DB.defaults and DB.defaults.profile or {}
        local unitframes = profile.unitframes
        if type(unitframes) == "table" then
            return unitframes
        end
        return {}
    end

    local function GetNestedTable(root, key)
        if type(root) ~= "table" then
            return {}
        end
        local value = root[key]
        if type(value) == "table" then
            return value
        end
        return {}
    end

    local function SetUFScaleAll(value)
        if bindingState:IsRefreshing() then
            return
        end

        local stored = tonumber(value) or 1.0
        local rule = { type = "number", min = 0.60, max = 1.30, fallback = 1.0 }
        local units = { "player", "target", "focus", "targettarget", "pet" }
        local beganUndoBatch = false

        if Settings and Settings.BeginPanelUndoBatch then
            beganUndoBatch = Settings:BeginPanelUndoBatch(PANEL_KEY) == true
        end

        local ok, err = pcall(function()
            for i = 1, #units do
                SetProfileValue({ "unitframes", "scales", units[i] }, stored, rule, APPLY_KEY, PANEL_KEY)
            end
        end)

        if beganUndoBatch and Settings and Settings.EndPanelUndoBatch then
            Settings:EndPanelUndoBatch(PANEL_KEY)
        end
        if not ok then
            error(err, 0)
        end

        if GetLivePreview(PANEL_KEY) then
            applyState:ApplyNow()
        else
            applyState:MarkPending()
        end
    end

    local function GetUFSize(uf, unit)
        uf = (type(uf) == "table") and uf or {}
        local defUF = GetUnitFrameDefaults()
        local defSizes = GetNestedTable(defUF, "sizes")
        local fallback = defSizes[unit] or defSizes.player or {}
        local baseW = tonumber(fallback.width) or 160
        local baseH = tonumber(fallback.height) or 20
        local sizes = GetNestedTable(uf, "sizes")
        local size = sizes[unit]
        local width = (type(size) == "table" and tonumber(size.width)) or baseW
        local height = (type(size) == "table" and tonumber(size.height)) or baseH
        return width, height
    end

    local function GetUFScale(uf, unit)
        uf = (type(uf) == "table") and uf or {}
        local defUF = GetUnitFrameDefaults()
        local defScales = GetNestedTable(defUF, "scales")
        local scales = GetNestedTable(uf, "scales")
        local scale = tonumber(scales[unit])
        if type(scale) == "number" then
            return scale
        end
        return tonumber(defScales[unit]) or tonumber(defScales.player) or 1.0
    end

    local descriptors = {
        {
            kind = "slider",
            widget = ufScale,
            transform = function(value)
                return tonumber(value) or 1.0
            end,
            get = function(context)
                return GetUFScale(context and context.uf, "player")
            end,
            set = function(value)
                SetUFScaleAll(value)
            end,
        },
        {
            kind = "check",
            widget = showFocus,
            contextKey = "uf",
            sectionPath = { "unitframes" },
            contextPath = { "showFocus" },
            read = ReadBoolWithFallback(true),
            rule = { type = "boolean", fallback = true },
        },
        {
            kind = "check",
            widget = showTT,
            contextKey = "uf",
            sectionPath = { "unitframes" },
            contextPath = { "showTargetTarget" },
            read = ReadBoolWithFallback(true),
            rule = { type = "boolean", fallback = true },
        },
        {
            kind = "check",
            widget = showPet,
            contextKey = "uf",
            sectionPath = { "unitframes" },
            contextPath = { "showPet" },
            read = ReadBoolWithFallback(true),
            rule = { type = "boolean", fallback = true },
        },
        {
            kind = "check",
            widget = cbEnable,
            contextKey = "uf",
            sectionPath = { "unitframes" },
            contextPath = { "castbar", "enabled" },
            read = ReadBoolWithFallback(true),
            rule = { type = "boolean", fallback = true },
        },
        {
            kind = "slider",
            widget = cbHeight,
            contextKey = "uf",
            sectionPath = { "unitframes" },
            contextPath = { "castbar", "height" },
            read = ReadIntWithFallback(14),
            transform = IntTransform(14),
            rule = { type = "int", min = 8, max = 24, fallback = 14 },
        },
        {
            kind = "radioGroup",
            contextKey = "uf",
            sectionPath = { "unitframes" },
            contextPath = { "targetAuras", "mode" },
            entries = {
                { widget = auraMini, value = "MINI" },
                { widget = auraClassic, value = "CLASSIC" },
            },
            read = function(value)
                return (value == "CLASSIC") and "CLASSIC" or "MINI"
            end,
            rule = {
                type = "enum",
                values = { "MINI", "CLASSIC" },
                fallback = "MINI",
            },
        },
        {
            kind = "check",
            widget = fmtEnable,
            contextKey = "format",
            sectionPath = { "format" },
            contextPath = { "shortNumbers", "enabled" },
            read = ReadBoolWithFallback(true),
            rule = { type = "boolean", fallback = true },
        },
        {
            kind = "check",
            widget = fmtUpper,
            contextKey = "format",
            sectionPath = { "format" },
            contextPath = { "shortNumbers", "suffixCase" },
            read = function(value)
                return value == "upper"
            end,
            write = function(checked)
                return checked and "upper" or "lower"
            end,
            rule = {
                type = "enum",
                values = { "lower", "upper" },
                fallback = "lower",
            },
        },
        {
            kind = "slider",
            widget = fmtSmall,
            contextKey = "format",
            sectionPath = { "format" },
            contextPath = { "shortNumbers", "decimalsSmall" },
            read = ReadIntWithFallback(1),
            transform = IntTransform(1),
            rule = { type = "int", min = 0, max = 2, fallback = 1 },
        },
        {
            kind = "slider",
            widget = fmtLarge,
            contextKey = "format",
            sectionPath = { "format" },
            contextPath = { "shortNumbers", "decimalsLarge" },
            read = ReadIntWithFallback(0),
            transform = IntTransform(0),
            rule = { type = "int", min = 0, max = 2, fallback = 0 },
        },
        {
            kind = "check",
            widget = tiEnable,
            contextKey = "uf",
            sectionPath = { "unitframes" },
            contextPath = { "targetInfo", "enabled" },
            read = ReadBoolWithFallback(false),
            rule = { type = "boolean", fallback = false },
        },
        {
            kind = "check",
            widget = tiName,
            contextKey = "uf",
            sectionPath = { "unitframes" },
            contextPath = { "targetInfo", "showName" },
            read = ReadBoolWithFallback(true),
            rule = { type = "boolean", fallback = true },
        },
        {
            kind = "check",
            widget = tiInfo,
            contextKey = "uf",
            sectionPath = { "unitframes" },
            contextPath = { "targetInfo", "showInfo" },
            read = ReadBoolWithFallback(true),
            rule = { type = "boolean", fallback = true },
        },
        {
            kind = "check",
            widget = tiPower,
            contextKey = "uf",
            sectionPath = { "unitframes" },
            contextPath = { "targetInfo", "showPower" },
            read = ReadBoolWithFallback(true),
            rule = { type = "boolean", fallback = true },
        },
        {
            kind = "slider",
            widget = tiPowH,
            contextKey = "uf",
            sectionPath = { "unitframes" },
            contextPath = { "targetInfo", "powerHeight" },
            read = ReadIntWithFallback(10),
            transform = IntTransform(10),
            rule = { type = "int", min = 6, max = 20, fallback = 10 },
        },
        {
            kind = "radioGroup",
            contextKey = "uf",
            sectionPath = { "unitframes" },
            contextPath = { "targetInfo", "nameAnchor" },
            entries = {
                { widget = tiAnchorFrame, value = "FRAME" },
                { widget = tiAnchorAuras, value = "AURAS" },
            },
            read = function(value)
                return (value == "AURAS") and "AURAS" or "FRAME"
            end,
            rule = {
                type = "enum",
                values = { "FRAME", "AURAS" },
                fallback = "FRAME",
            },
        },
        {
            kind = "radioGroup",
            contextKey = "uf",
            sectionPath = { "unitframes" },
            contextPath = { "targetInfo", "fontWeight" },
            entries = {
                { widget = tiFontRegular, value = "regular" },
                { widget = tiFontBold, value = "bold" },
            },
            read = function(value)
                return (value == "bold") and "bold" or "regular"
            end,
            rule = {
                type = "enum",
                values = { "regular", "bold" },
                fallback = "regular",
            },
        },
        {
            kind = "radioGroup",
            contextKey = "uf",
            sectionPath = { "unitframes" },
            contextPath = { "targetInfo", "colorMode" },
            entries = {
                { widget = tiColorInherit, value = "inherit" },
                { widget = tiColorCustom, value = "custom" },
            },
            read = function(value)
                return (value == "custom") and "custom" or "inherit"
            end,
            rule = {
                type = "enum",
                values = { "inherit", "custom" },
                fallback = "inherit",
            },
        },
        {
            kind = "colorSwatch",
            widget = tiColorSwatch,
            contextKey = "uf",
            sectionPath = { "unitframes" },
            contextPath = { "targetInfo", "color" },
            defaultColor = { r = 1.00, g = 1.00, b = 1.00, a = 1.00 },
        },
        {
            kind = "colorSwatch",
            widget = playerHealthColor,
            contextKey = "uf",
            sectionPath = { "unitframes" },
            contextPath = { "colors", "playerHealth" },
            defaultColor = { r = 0.65, g = 0.00, b = 0.00, a = 1.00 },
        },
        {
            kind = "colorSwatch",
            widget = targetFallbackColor,
            contextKey = "uf",
            sectionPath = { "unitframes" },
            contextPath = { "colors", "targetFallback" },
            defaultColor = { r = 0.12, g = 0.12, b = 0.12, a = 1.00 },
        },
        {
            kind = "check",
            widget = lowHPGlow,
            contextKey = "uf",
            sectionPath = { "unitframes" },
            contextPath = { "playerLowHP", "enabled" },
            read = ReadBoolWithFallback(true),
            rule = { type = "boolean", fallback = true },
        },
        {
            kind = "slider",
            widget = lowHPPct,
            contextKey = "uf",
            sectionPath = { "unitframes" },
            contextPath = { "playerLowHP", "threshold" },
            read = ReadIntWithFallback(30),
            transform = IntTransform(30),
            rule = { type = "int", min = 5, max = 80, fallback = 30 },
        },
        {
            kind = "slider",
            widget = lowHPAlpha,
            contextKey = "uf",
            sectionPath = { "unitframes" },
            contextPath = { "playerLowHP", "maxAlpha" },
            read = ReadNumberWithFallback(0.65),
            rule = { type = "number", min = 0.10, max = 1.00, fallback = 0.65 },
        },
        {
            kind = "colorSwatch",
            widget = lowHPGlowColor,
            contextKey = "uf",
            sectionPath = { "unitframes" },
            contextPath = { "playerLowHP", "color" },
            defaultColor = { r = 1.00, g = 0.12, b = 0.12, a = 1.00 },
        },
    }

    local sizeDescriptors = {
        { widget = ufW, unit = "player", key = "width", fallback = 160, min = 120, max = 520 },
        { widget = ufH, unit = "player", key = "height", fallback = 20, min = 14, max = 40 },
        { widget = tgtW, unit = "target", key = "width", fallback = 160, min = 120, max = 520 },
        { widget = tgtH, unit = "target", key = "height", fallback = 20, min = 14, max = 40 },
        { widget = focusW, unit = "focus", key = "width", fallback = 160, min = 120, max = 520 },
        { widget = focusH, unit = "focus", key = "height", fallback = 20, min = 14, max = 40 },
        { widget = ttW, unit = "targettarget", key = "width", fallback = 160, min = 120, max = 520 },
        { widget = ttH, unit = "targettarget", key = "height", fallback = 20, min = 14, max = 40 },
    }

    for i = 1, #sizeDescriptors do
        local spec = sizeDescriptors[i]
        descriptors[#descriptors + 1] = {
            kind = "slider",
            widget = spec.widget,
            transform = IntTransform(spec.fallback),
            get = function(context)
                local width, height = GetUFSize(context and context.uf, spec.unit)
                if spec.key == "width" then
                    return width
                end
                return height
            end,
            set = function(value)
                SetPV({ "unitframes", "sizes", spec.unit, spec.key }, value, {
                    type = "int",
                    min = spec.min,
                    max = spec.max,
                    fallback = spec.fallback,
                })
            end,
        }
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
                uf = GetProfileSection("unitframes"),
                format = GetProfileSection("format"),
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

Shared.RegisterPanelBuilder("unitframes", BuildPanel_UnitFrames)
