-- FeelsGoodUI: shared Options field builders + binding helpers

local _, ns = ...

local Shared = ns.OptionsShared or {}
ns.OptionsShared = Shared

local function Call(fn, ...)
    if type(fn) == "function" then
        return fn(...)
    end
    return nil
end

local function IsRefreshing(spec)
    return Call(spec and spec.isRefreshing) == true
end

local function SetWidgetEnabled(widget, enabled)
    if not widget then
        return
    end

    enabled = (enabled == true)
    if widget.SetEnabled then
        widget:SetEnabled(enabled)
        return
    end

    if enabled then
        if widget.Enable then
            widget:Enable()
        end
    elseif widget.Disable then
        widget:Disable()
    end
end

local function RefreshAfterSet(spec)
    if spec and spec.refreshAfter then
        Call(spec.refresh)
    end
end

local function NormalizeColor(value, fallback)
    value = (type(value) == "table") and value or {}
    fallback = (type(fallback) == "table") and fallback or {}

    return {
        r = tonumber(value.r) or tonumber(fallback.r) or 1,
        g = tonumber(value.g) or tonumber(fallback.g) or 1,
        b = tonumber(value.b) or tonumber(fallback.b) or 1,
        a = tonumber(value.a) or tonumber(fallback.a) or 1,
    }
end

function Shared.ReadBoolWithFallback(fallback)
    return function(value)
        if value == nil then
            return fallback
        end
        return value == true
    end
end

function Shared.ReadNumberWithFallback(fallback)
    return function(value)
        return tonumber(value) or fallback
    end
end

function Shared.ReadIntWithFallback(fallback)
    return Shared.ReadNumberWithFallback(fallback)
end

function Shared.IntTransform(fallback)
    return function(value)
        return math.floor((tonumber(value) or fallback) + 0.5)
    end
end

function Shared.CreateApplySection(ctx, parent, anchor, opts)
    if type(ctx) ~= "table" or not parent or not anchor then
        return nil
    end

    opts = opts or {}

    local panelContract
    if type(Shared.GetPanelContract) == "function" then
        panelContract = Shared.GetPanelContract(opts.panelKey)
    end

    local applyKeys = opts.applyKey or (panelContract and panelContract.applyKeys)
    local resetLabel = opts.resetLabel or (panelContract and panelContract.resetLabel) or "Reset"
    local resetSections = opts.resetSections or opts.resetSection or (panelContract and panelContract.resetSections)
    local restoreApplyKeys = opts.restoreApplyKeys or (panelContract and panelContract.restoreApplyKeys)

    local modeHeader = ctx.CreateSubHeader(parent, opts.title or "Apply mode", anchor, opts.headerOffsetX or 0, opts.headerOffsetY or -12)
    local liveCheck = ctx.CreateCheck(
        parent,
        opts.liveLabel or "Live preview",
        opts.liveTooltip or "Apply changes immediately (debounced). Disable for manual apply.",
        modeHeader
    )
    local applyBtn = ctx.CreateButton(parent, opts.applyLabel or "Apply now", opts.applyWidth or 140, liveCheck, 0, -6)
    local undoBtn = ctx.CreateButton(parent, opts.undoLabel or "Undo last", opts.undoWidth or 140, applyBtn, 0, -6)
    local resetBtn = ctx.CreateButton(parent, resetLabel, opts.resetWidth or 180, undoBtn, 0, -6)
    local status = ctx.CreateStatusLine(parent, resetBtn, 0, -2)
    local applyState = ctx.CreatePanelApplyController(opts.panelKey, applyKeys, liveCheck, applyBtn, status)

    local section = {
        header = modeHeader,
        liveCheck = liveCheck,
        applyBtn = applyBtn,
        undoBtn = undoBtn,
        resetBtn = resetBtn,
        status = status,
        applyState = applyState,
    }

    function section:Bind(refreshFn)
        ctx.BindPanelApplyControls(applyState, undoBtn, resetBtn, resetSections, refreshFn, restoreApplyKeys)
    end

    return section
end

local function CreateActionBarSection(ctx, parent, anchor, spec)
    if type(spec) ~= "table" or not ctx or not parent then
        return nil
    end

    local header = ctx.CreateSubHeader(parent, spec.header or spec.title or "Bar", anchor or parent, 0, spec.headerOffsetY or -14)
    local enableAnchor = header
    local enableCheck
    if spec.enableLabel then
        enableCheck = ctx.CreateCheck(parent, spec.enableLabel, spec.enableTooltip, header, spec.enableOffsetX or 0, spec.enableOffsetY or -6)
        enableAnchor = enableCheck
    end

    local buttons = ctx.CreateSlider(
        parent,
        spec.buttonsLabel or "Buttons",
        spec.buttonsMin or 1,
        spec.buttonsMax or 12,
        spec.buttonsStep or 1,
        enableAnchor,
        spec.buttonsOffsetX or 0,
        spec.buttonsOffsetY or -16
    )
    if spec.attachNumeric ~= false and type(ctx.AttachNumericEditBox) == "function" then
        ctx.AttachNumericEditBox(buttons, { int = true })
    end

    local rows = ctx.CreateSlider(
        parent,
        spec.rowsLabel or "Rows",
        spec.rowsMin or 1,
        spec.rowsMax or 4,
        spec.rowsStep or 1,
        buttons,
        spec.rowsOffsetX or 0,
        spec.rowsOffsetY or -12
    )
    if spec.attachNumeric ~= false and type(ctx.AttachNumericEditBox) == "function" then
        ctx.AttachNumericEditBox(rows, { int = true })
    end

    return {
        header = header,
        enable = enableCheck,
        buttons = buttons,
        rows = rows,
    }
end

Shared.CreateActionBarSection = CreateActionBarSection

local function ResolveLayoutRef(refs, ref)
    if type(ref) == "string" then
        return refs and refs[ref] or nil
    end

    if type(ref) ~= "table" then
        return ref
    end

    local target = ref.widget
    if target == nil and type(ref.ref) == "string" then
        target = refs and refs[ref.ref] or nil
    end

    if type(ref.field) == "string" and type(target) == "table" then
        return target[ref.field]
    end

    return target
end

local function BuildLayoutItem(ctx, parent, item, refs)
    if type(item) ~= "table" then
        return nil
    end

    local kind = item.type or item.kind
    local anchor = ResolveLayoutRef(refs, item.anchor)

    if kind == "header" then
        return ctx.CreateHeader(parent, item.text, item.y)
    end
    if kind == "subheader" then
        return ctx.CreateSubHeader(parent, item.text, anchor, item.x, item.y)
    end
    if kind == "note" then
        return ctx.CreateNote(parent, item.text, anchor, item.x, item.y)
    end
    if kind == "check" then
        return ctx.CreateCheck(parent, item.label or item.text, item.tooltip, anchor, item.x, item.y)
    end
    if kind == "button" then
        return ctx.CreateButton(parent, item.label or item.text, item.width, anchor, item.x, item.y)
    end
    if kind == "slider" then
        local slider = ctx.CreateSlider(parent, item.label or item.text, item.min, item.max, item.step, anchor, item.x, item.y)
        local numeric = item.numericEdit
        if numeric == true then
            numeric = {}
        end
        if type(numeric) == "table" and type(ctx.AttachNumericEditBox) == "function" then
            ctx.AttachNumericEditBox(slider, numeric)
        end
        return slider
    end
    if kind == "dropdown" then
        return ctx.CreateDropdown(parent, item.label or item.text, item.width, anchor, item.x, item.y)
    end
    if kind == "radio" then
        return ctx.CreateRadio(parent, item.label or item.text, anchor, item.x, item.y)
    end
    if kind == "colorSwatch" then
        local swatch, row = ctx.CreateColorSwatch(parent, item.label or item.text, anchor, item.x, item.y)
        if swatch and row then
            swatch.row = row
        end
        return swatch
    end
    if kind == "applySection" then
        return Shared.CreateApplySection(ctx, parent, anchor, item.options or item.opts or item)
    end
    if kind == "custom" and type(item.build) == "function" then
        return item.build(ctx, parent, anchor, refs)
    end

    return nil
end

function Shared.BuildLayout(ctx, parent, items, seedRefs)
    if type(ctx) ~= "table" or not parent or type(items) ~= "table" then
        return seedRefs or {}
    end

    local refs = seedRefs or {}
    for i = 1, #items do
        local item = items[i]
        local widget = BuildLayoutItem(ctx, parent, item, refs)
        if type(item) == "table" and type(item.id) == "string" and item.id ~= "" then
            refs[item.id] = widget
        end
    end

    return refs
end

function Shared.BindCheck(widget, spec)
    spec = spec or {}

    widget:SetScript("OnClick", function(self)
        if IsRefreshing(spec) then
            return
        end

        local checked = self:GetChecked() and true or false
        Call(spec.set, checked, self)
        Call(spec.afterSet, checked, self)
        RefreshAfterSet(spec)
    end)

    return {
        Refresh = function(_, context)
            local checked = Call(spec.get, context) == true
            widget:SetChecked(checked)
            if spec.enabled ~= nil then
                SetWidgetEnabled(widget, Call(spec.enabled, context) == true)
            end
        end,
    }
end

function Shared.BindSlider(widget, spec)
    spec = spec or {}

    widget:SetScript("OnValueChanged", function(_, rawValue)
        if IsRefreshing(spec) then
            return
        end

        local value = rawValue
        if type(spec.transform) == "function" then
            value = spec.transform(rawValue)
        end

        Call(spec.set, value, rawValue)
        Call(spec.afterSet, value, rawValue)
        RefreshAfterSet(spec)
    end)

    return {
        Refresh = function(_, context)
            local value = Call(spec.get, context)
            if type(value) == "number" then
                widget:SetValue(value)
            end
            if spec.enabled ~= nil then
                SetWidgetEnabled(widget, Call(spec.enabled, context) == true)
            end
        end,
    }
end

function Shared.BindRadioGroup(entries, spec)
    spec = spec or {}
    entries = (type(entries) == "table") and entries or {}

    local function ApplySelection(selectedValue)
        for i = 1, #entries do
            local entry = entries[i]
            if entry and entry.widget and entry.widget.SetChecked then
                entry.widget:SetChecked(entry.value == selectedValue)
            end
        end
    end

    local function SetEntriesEnabled(enabled)
        for i = 1, #entries do
            local entry = entries[i]
            if entry and entry.widget then
                SetWidgetEnabled(entry.widget, enabled)
            end
        end
    end

    for i = 1, #entries do
        local entry = entries[i]
        if entry and entry.widget then
            entry.widget:SetScript("OnClick", function(self)
                if IsRefreshing(spec) then
                    return
                end

                ApplySelection(entry.value)
                Call(spec.set, entry.value, self)
                Call(spec.afterSet, entry.value, self)
                RefreshAfterSet(spec)
            end)
        end
    end

    return {
        Refresh = function(_, context)
            ApplySelection(Call(spec.get, context))
            if spec.enabled ~= nil then
                SetEntriesEnabled(Call(spec.enabled, context) == true)
            end
        end,
    }
end

local function ResolveDropdownOptions(spec, context)
    local options = Call(spec and spec.options, context)
    if type(options) == "table" then
        return options
    end
    if type(spec and spec.options) == "table" then
        return spec.options
    end
    return {}
end

local function GetDropdownOptionValue(spec, option, context)
    if type(spec and spec.optionValue) == "function" then
        return spec.optionValue(option, context)
    end
    if type(option) == "table" and option.value ~= nil then
        return option.value
    end
    return option
end

local function GetDropdownOptionText(spec, option, context)
    if type(spec and spec.optionText) == "function" then
        return spec.optionText(option, context)
    end
    if type(option) == "table" and option.text ~= nil then
        return option.text
    end
    local value = GetDropdownOptionValue(spec, option, context)
    if value == nil then
        return ""
    end
    return tostring(value)
end

local function ResolveDropdownText(spec, value, options, context)
    local text = Call(spec and spec.text, value, options, context)
    if text ~= nil then
        return text
    end

    for i = 1, #options do
        local option = options[i]
        if GetDropdownOptionValue(spec, option, context) == value then
            return GetDropdownOptionText(spec, option, context)
        end
    end

    if value == nil then
        return ""
    end
    return tostring(value)
end

function Shared.BindDropdown(widget, spec)
    spec = spec or {}

    UIDropDownMenu_Initialize(widget, function(_, level)
        level = level or 1
        local context = Call(spec.menuContext)
        local options = ResolveDropdownOptions(spec, context)
        local currentValue = Call(spec.get, context)

        for i = 1, #options do
            local option = options[i]
            local value = GetDropdownOptionValue(spec, option, context)
            local text = GetDropdownOptionText(spec, option, context)
            local info = UIDropDownMenu_CreateInfo()
            info.text = text
            info.checked = (value == currentValue)
            info.func = function()
                if IsRefreshing(spec) then
                    return
                end

                UIDropDownMenu_SetText(widget, text)
                Call(spec.set, value, option)
                Call(spec.afterSet, value, option)
                RefreshAfterSet(spec)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    return {
        Refresh = function(_, context)
            local options = ResolveDropdownOptions(spec, context)
            local value = Call(spec.get, context)
            UIDropDownMenu_SetText(widget, ResolveDropdownText(spec, value, options, context))
        end,
    }
end

function Shared.BindColorSwatch(widget, spec)
    spec = spec or {}

    widget:SetScript("OnClick", function()
        if IsRefreshing(spec) then
            return
        end

        local openColorPicker = Shared.OpenColorPicker
        local setSwatchColor = Shared.SetSwatchColor
        if type(openColorPicker) ~= "function" or type(setSwatchColor) ~= "function" then
            return
        end

        local current = NormalizeColor(Call(spec.get), spec.defaultColor)
        openColorPicker(current, spec.hasAlpha == true, function(r, g, b, a)
            local color = {
                r = r,
                g = g,
                b = b,
                a = (spec.hasAlpha == true) and (a or current.a) or 1,
            }
            setSwatchColor(widget, color.r, color.g, color.b, color.a)
            Call(spec.set, color)
            Call(spec.afterSet, color)
            RefreshAfterSet(spec)
        end)
    end)

    return {
        Refresh = function(_, context)
            local setSwatchColor = Shared.SetSwatchColor
            if type(setSwatchColor) ~= "function" then
                return
            end

            local color = NormalizeColor(Call(spec.get, context), spec.defaultColor)
            setSwatchColor(widget, color.r, color.g, color.b, color.a)
            if spec.enabled ~= nil then
                SetWidgetEnabled(widget, Call(spec.enabled, context) == true)
            end
        end,
    }
end

function Shared.RefreshBindings(bindings, context)
    if type(bindings) ~= "table" then
        return
    end

    for i = 1, #bindings do
        local binding = bindings[i]
        if binding and type(binding.Refresh) == "function" then
            binding:Refresh(context)
        end
    end
end

function Shared.BindPanelRefresh(root, refreshFn)
    if not root or type(refreshFn) ~= "function" then
        return
    end

    root.refresh = refreshFn
    root:SetScript("OnShow", refreshFn)

    function root:OnRefresh()
        if self.refresh then
            self:refresh()
        end
    end
end

function Shared.CreateBindingState()
    local state = {
        bindings = {},
        refreshing = false,
    }

    function state:IsRefreshing()
        return self.refreshing == true
    end

    function state:Add(binding)
        if binding then
            self.bindings[#self.bindings + 1] = binding
        end
        return binding
    end

    function state:Refresh(context)
        self.refreshing = true
        Shared.RefreshBindings(self.bindings, context)
        self.refreshing = false
    end

    return state
end

local function CopyPath(path)
    if type(path) ~= "table" then
        return nil
    end

    local out = {}
    for i = 1, #path do
        out[i] = path[i]
    end
    return out
end

local function JoinPath(prefix, suffix)
    if type(prefix) ~= "table" and type(suffix) ~= "table" then
        return nil
    end

    local out = {}
    if type(prefix) == "table" then
        for i = 1, #prefix do
            out[#out + 1] = prefix[i]
        end
    end
    if type(suffix) == "table" then
        for i = 1, #suffix do
            out[#out + 1] = suffix[i]
        end
    end
    return out
end

local function GetValueAtPath(root, path)
    if type(path) ~= "table" or #path == 0 then
        return root
    end

    local cursor = root
    for i = 1, #path do
        if type(cursor) ~= "table" then
            return nil
        end
        cursor = cursor[path[i]]
    end
    return cursor
end

local function ResolveDescriptorRoot(context, descriptor)
    if type(descriptor) ~= "table" then
        return context
    end

    if type(descriptor.contextProvider) == "function" then
        return descriptor.contextProvider(context, descriptor)
    end

    if type(descriptor.contextKey) == "string" and type(context) == "table" then
        local value = context[descriptor.contextKey]
        if value ~= nil then
            return value
        end
    end

    return context
end

local function ResolveDescriptorValue(context, descriptor)
    if type(descriptor) ~= "table" then
        return nil
    end

    if type(descriptor.get) == "function" then
        return descriptor.get(context, descriptor)
    end

    local root = ResolveDescriptorRoot(context, descriptor)
    local value = GetValueAtPath(root, descriptor.contextPath)
    if type(descriptor.read) == "function" then
        return descriptor.read(value, context, root, descriptor)
    end
    return value
end

local function ResolveDescriptorEnabled(context, descriptor)
    if descriptor == nil or descriptor.enabled == nil then
        return nil
    end
    if type(descriptor.enabled) == "function" then
        return descriptor.enabled(context, descriptor)
    end
    return descriptor.enabled == true
end

local function ResolveDescriptorWritePath(descriptor)
    if type(descriptor) ~= "table" then
        return nil
    end
    if type(descriptor.writePath) == "table" then
        return CopyPath(descriptor.writePath)
    end
    return JoinPath(descriptor.sectionPath, descriptor.contextPath)
end

local function ResolveDescriptorMenuContext(descriptor, env)
    if type(descriptor) == "table" then
        if type(descriptor.menuContext) == "function" then
            return descriptor.menuContext(descriptor, env)
        end
        if type(descriptor.menuContext) == "table" then
            return descriptor.menuContext
        end

        if type(descriptor.menuSection) == "string" and env and type(env.getProfileSection) == "function" then
            local value = env.getProfileSection(descriptor.menuSection)
            local key = descriptor.menuContextKey or descriptor.contextKey or descriptor.menuSection
            return {
                [key] = value,
            }
        end
    end
    return {}
end

local function BuildDescriptorFallbackContext(descriptor, env)
    local getProfileSection = env and env.getProfileSection
    if type(descriptor) ~= "table" or type(getProfileSection) ~= "function" then
        return {}
    end

    local sectionPath = descriptor.sectionPath
    local sectionName = descriptor.fallbackSection
        or descriptor.menuSection
        or (type(sectionPath) == "table" and sectionPath[1])
    local contextKey = descriptor.contextKey or sectionName
    if type(sectionName) ~= "string" or sectionName == "" or type(contextKey) ~= "string" or contextKey == "" then
        return {}
    end

    return {
        [contextKey] = getProfileSection(sectionName),
    }
end

local function DispatchDescriptorSet(inputValue, descriptor, env, ...)
    env = env or {}

    if type(descriptor and descriptor.set) == "function" then
        return descriptor.set(inputValue, descriptor, env, ...)
    end

    local setValue = env.setValue
    if type(setValue) ~= "function" then
        return nil
    end

    local value = inputValue
    if type(descriptor and descriptor.write) == "function" then
        value = descriptor.write(inputValue, descriptor, env, ...)
    end

    local path = ResolveDescriptorWritePath(descriptor)
    if not path then
        return nil
    end

    return setValue(path, value, descriptor.rule, descriptor.applyKeys, descriptor)
end

function Shared.AddDescriptorBindings(bindings, descriptors, env)
    if type(bindings) ~= "table" or type(descriptors) ~= "table" then
        return
    end

    env = env or {}

    for i = 1, #descriptors do
        local descriptor = descriptors[i]
        local widget = descriptor and descriptor.widget
        local kind = descriptor and descriptor.kind
        local binding

        if kind == "check" and widget then
            binding = Shared.BindCheck(widget, {
                isRefreshing = env.isRefreshing,
                get = function(context)
                    return ResolveDescriptorValue(context, descriptor) == true
                end,
                set = function(checked, clickedWidget)
                    DispatchDescriptorSet(checked, descriptor, env, clickedWidget)
                end,
                afterSet = function(checked, clickedWidget)
                    Call(descriptor.afterSet, checked, clickedWidget, descriptor, env)
                end,
                enabled = (descriptor.enabled ~= nil) and function(context)
                    return ResolveDescriptorEnabled(context, descriptor) == true
                end or nil,
                refresh = env.refresh,
                refreshAfter = descriptor.refreshAfter,
            })
        elseif kind == "slider" and widget then
            binding = Shared.BindSlider(widget, {
                isRefreshing = env.isRefreshing,
                transform = descriptor.transform,
                get = function(context)
                    return ResolveDescriptorValue(context, descriptor)
                end,
                set = function(value, rawValue)
                    DispatchDescriptorSet(value, descriptor, env, rawValue)
                end,
                afterSet = function(value, rawValue)
                    Call(descriptor.afterSet, value, rawValue, descriptor, env)
                end,
                enabled = (descriptor.enabled ~= nil) and function(context)
                    return ResolveDescriptorEnabled(context, descriptor) == true
                end or nil,
                refresh = env.refresh,
                refreshAfter = descriptor.refreshAfter,
            })
        elseif kind == "dropdown" and widget then
            binding = Shared.BindDropdown(widget, {
                isRefreshing = env.isRefreshing,
                menuContext = function()
                    return ResolveDescriptorMenuContext(descriptor, env)
                end,
                options = descriptor.options,
                optionValue = descriptor.optionValue,
                optionText = descriptor.optionText,
                text = descriptor.text,
                get = function(context)
                    return ResolveDescriptorValue(context, descriptor)
                end,
                set = function(value, option)
                    DispatchDescriptorSet(value, descriptor, env, option)
                end,
                afterSet = function(value, option)
                    Call(descriptor.afterSet, value, option, descriptor, env)
                end,
                refresh = env.refresh,
                refreshAfter = descriptor.refreshAfter,
            })
        elseif kind == "radioGroup" and type(descriptor.entries) == "table" then
            binding = Shared.BindRadioGroup(descriptor.entries, {
                isRefreshing = env.isRefreshing,
                get = function(context)
                    return ResolveDescriptorValue(context, descriptor)
                end,
                set = function(value, clickedWidget)
                    DispatchDescriptorSet(value, descriptor, env, clickedWidget)
                end,
                afterSet = function(value, clickedWidget)
                    Call(descriptor.afterSet, value, clickedWidget, descriptor, env)
                end,
                enabled = (descriptor.enabled ~= nil) and function(context)
                    return ResolveDescriptorEnabled(context, descriptor) == true
                end or nil,
                refresh = env.refresh,
                refreshAfter = descriptor.refreshAfter,
            })
        elseif (kind == "color" or kind == "colorSwatch") and widget then
            binding = Shared.BindColorSwatch(widget, {
                isRefreshing = env.isRefreshing,
                defaultColor = descriptor.defaultColor,
                hasAlpha = descriptor.hasAlpha,
                get = function(context)
                    local effectiveContext = context or BuildDescriptorFallbackContext(descriptor, env)
                    return ResolveDescriptorValue(effectiveContext, descriptor)
                end,
                set = function(color)
                    DispatchDescriptorSet(color, descriptor, env)
                end,
                afterSet = function(color)
                    Call(descriptor.afterSet, color, descriptor, env)
                end,
                enabled = (descriptor.enabled ~= nil) and function(context)
                    return ResolveDescriptorEnabled(context, descriptor) == true
                end or nil,
                refresh = env.refresh,
                refreshAfter = descriptor.refreshAfter,
            })
        end

        if binding then
            bindings[#bindings + 1] = binding
        end
    end
end
