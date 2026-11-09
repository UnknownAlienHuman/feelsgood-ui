from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


options_path = Path("core/OptionsSharedHelpers.lua")
options = options_path.read_text(encoding="utf-8")

registries = '''local adaptiveOwnerRegistry = setmetatable({}, { __mode = "k" })
local adaptiveWidgetRegistry = setmetatable({}, { __mode = "k" })
local numericParentRegistry = setmetatable({}, { __mode = "k" })
local numericSliderRegistry = setmetatable({}, { __mode = "k" })
local wheelProxyRegistry = setmetatable({}, { __mode = "k" })

Shared._adaptiveOwnerRegistry = adaptiveOwnerRegistry
Shared._adaptiveWidgetRegistry = adaptiveWidgetRegistry
Shared._numericParentRegistry = numericParentRegistry
Shared._numericSliderRegistry = numericSliderRegistry
Shared._wheelProxyRegistry = wheelProxyRegistry

local function HookError(scope, record, key, detail)
    detail = tostring(detail or "unknown hook error")
    record.errors = record.errors or {}
    if record.errors[key] == detail then return end
    record.errors[key] = detail
    if Log and type(Log.Warn) == "function" then
        Log:Warn(tostring(scope) .. ": " .. detail)
    end
end

local function ClearHookError(record, key)
    if type(record.errors) == "table" then
        record.errors[key] = nil
    end
end

local function TryHookScript(target, event, callback)
    if not (target and type(target.HookScript) == "function") then
        return false, tostring(event) .. " HookScript unavailable"
    end
    local ok, err = pcall(target.HookScript, target, event, callback)
    if not ok then
        return false, tostring(err)
    end
    return true
end

local function EnsureHook(record, target, event, field, callback, scope)
    if record[field] == true then return true end
    local ok, detail = TryHookScript(target, event, callback)
    if ok then
        record[field] = true
        ClearHookError(record, field)
        return true
    end
    HookError(scope, record, field, detail)
    return false, detail
end

local function ApplyAdaptiveWidget(widget)
    local record = adaptiveWidgetRegistry[widget]
    if not (record and record.active and type(record.apply) == "function") then
        return false
    end

    local ok, detail = pcall(record.apply, widget, record.owner)
    if ok then
        record.applyError = nil
        return true
    end

    detail = tostring(detail)
    if record.applyError ~= detail then
        record.applyError = detail
        if Log and type(Log.Warn) == "function" then
            Log:Warn("Options adaptive width callback failed: " .. detail)
        end
    end
    return false
end

local function ApplyAdaptiveOwner(owner)
    local ownerRecord = adaptiveOwnerRegistry[owner]
    if not ownerRecord then return end

    for widget in pairs(ownerRecord.widgets) do
        local record = adaptiveWidgetRegistry[widget]
        if record and record.owner == owner and record.active then
            ApplyAdaptiveWidget(widget)
        else
            ownerRecord.widgets[widget] = nil
        end
    end
end

local function OnAdaptiveOwnerChanged(owner)
    ApplyAdaptiveOwner(owner)
end

local function OnAdaptiveWidgetShown(widget)
    ApplyAdaptiveWidget(widget)
end

local function HookAdaptiveWidth(widget, owner, applyFn)
    if not (widget and owner and type(applyFn) == "function") then
        return false, "Adaptive width registration requires widget, owner, and callback"
    end

    local previous = adaptiveWidgetRegistry[widget]
    if previous and previous.owner ~= owner then
        previous.active = false
        local previousOwner = adaptiveOwnerRegistry[previous.owner]
        if previousOwner then previousOwner.widgets[widget] = nil end
        previous = nil
    end

    local ownerRecord = adaptiveOwnerRegistry[owner]
    if not ownerRecord then
        ownerRecord = {
            widgets = setmetatable({}, { __mode = "k" }),
        }
        adaptiveOwnerRegistry[owner] = ownerRecord
    end

    local record = previous or { owner = owner, active = true }
    record.owner = owner
    record.apply = applyFn
    record.active = true
    adaptiveWidgetRegistry[widget] = record
    ownerRecord.widgets[widget] = true

    local applied = ApplyAdaptiveWidget(widget)
    local sizeHooked, sizeDetail = EnsureHook(
        ownerRecord,
        owner,
        "OnSizeChanged",
        "sizeHooked",
        OnAdaptiveOwnerChanged,
        "Options adaptive owner hook"
    )
    local ownerShowHooked, ownerShowDetail = EnsureHook(
        ownerRecord,
        owner,
        "OnShow",
        "showHooked",
        OnAdaptiveOwnerChanged,
        "Options adaptive owner hook"
    )
    local widgetShowHooked, widgetShowDetail = EnsureHook(
        record,
        widget,
        "OnShow",
        "showHooked",
        OnAdaptiveWidgetShown,
        "Options adaptive widget hook"
    )

    if applied and sizeHooked and ownerShowHooked and widgetShowHooked then
        return true
    end
    return false, sizeDetail or ownerShowDetail or widgetShowDetail or "Adaptive width callback failed"
end

local function SyncNumericSlider(slider)
    local record = numericSliderRegistry[slider]
    if not (record and record.active and record.editBox and type(record.format) == "function") then
        return false
    end
    if record.updating then return true end

    record.updating = true
    local ok, detail = pcall(function()
        record.editBox:SetText(record.format(slider:GetValue()))
    end)
    record.updating = false

    if ok then
        record.syncError = nil
        return true
    end
    detail = tostring(detail)
    if record.syncError ~= detail then
        record.syncError = detail
        if Log and type(Log.Warn) == "function" then
            Log:Warn("Options numeric slider sync failed: " .. detail)
        end
    end
    return false
end

local function SyncNumericParent(parent)
    local parentRecord = numericParentRegistry[parent]
    if not parentRecord then return end
    for slider in pairs(parentRecord.sliders) do
        local record = numericSliderRegistry[slider]
        if record and record.parent == parent and record.active then
            SyncNumericSlider(slider)
        else
            parentRecord.sliders[slider] = nil
        end
    end
end

local function OnNumericSliderChanged(slider)
    SyncNumericSlider(slider)
end

local function OnNumericParentShown(parent)
    SyncNumericParent(parent)
end

local function RegisterNumericSliderSync(slider, parent, editBox, formatFn)
    if not (slider and parent and editBox and type(formatFn) == "function") then
        return false, "Numeric slider sync requires slider, parent, edit box, and formatter"
    end

    local previous = numericSliderRegistry[slider]
    if previous and previous.parent ~= parent then
        previous.active = false
        local previousParent = numericParentRegistry[previous.parent]
        if previousParent then previousParent.sliders[slider] = nil end
        previous = nil
    end

    local parentRecord = numericParentRegistry[parent]
    if not parentRecord then
        parentRecord = {
            sliders = setmetatable({}, { __mode = "k" }),
        }
        numericParentRegistry[parent] = parentRecord
    end

    local record = previous or { parent = parent, active = true }
    record.parent = parent
    record.editBox = editBox
    record.format = formatFn
    record.active = true
    numericSliderRegistry[slider] = record
    parentRecord.sliders[slider] = true

    local valueHooked, valueDetail = EnsureHook(
        record,
        slider,
        "OnValueChanged",
        "valueHooked",
        OnNumericSliderChanged,
        "Options numeric slider hook"
    )
    local showHooked, showDetail = EnsureHook(
        record,
        slider,
        "OnShow",
        "showHooked",
        OnNumericSliderChanged,
        "Options numeric slider hook"
    )
    local parentHooked, parentDetail = EnsureHook(
        parentRecord,
        parent,
        "OnShow",
        "showHooked",
        OnNumericParentShown,
        "Options numeric parent hook"
    )

    local synced = SyncNumericSlider(slider)
    if valueHooked and showHooked and parentHooked and synced then
        return true
    end
    return false, valueDetail or showDetail or parentDetail or "Numeric slider sync failed"
end

local function OnWheelProxy(frame, delta)
    local record = wheelProxyRegistry[frame]
    if not (record and record.active and type(record.scrollByDelta) == "function") then
        return
    end

    local ok, detail = pcall(record.scrollByDelta, record.scroll, delta)
    if ok then
        record.dispatchError = nil
        return
    end
    detail = tostring(detail)
    if record.dispatchError ~= detail then
        record.dispatchError = detail
        if Log and type(Log.Warn) == "function" then
            Log:Warn("Options wheel proxy failed: " .. detail)
        end
    end
end

local function AttachWheelProxy(frame, scroll, scrollByDelta)
    if not (frame and scroll and type(scrollByDelta) == "function") then
        return false, "Wheel proxy requires frame, scroll owner, and callback"
    end

    local record = wheelProxyRegistry[frame]
    if not record then
        record = { active = true }
        wheelProxyRegistry[frame] = record
    end
    record.active = true
    record.scroll = scroll
    record.scrollByDelta = scrollByDelta

    local enabled = record.mouseWheelEnabled == true
    local enableDetail
    if not enabled then
        if type(frame.EnableMouseWheel) ~= "function" then
            enableDetail = "EnableMouseWheel unavailable"
        else
            local ok, detail = pcall(frame.EnableMouseWheel, frame, true)
            if ok then
                record.mouseWheelEnabled = true
                ClearHookError(record, "mouseWheelEnabled")
                enabled = true
            else
                enableDetail = tostring(detail)
                HookError("Options wheel proxy", record, "mouseWheelEnabled", enableDetail)
            end
        end
    end

    local hooked, hookDetail = EnsureHook(
        record,
        frame,
        "OnMouseWheel",
        "hooked",
        OnWheelProxy,
        "Options wheel proxy hook"
    )

    if enabled and hooked then return true end
    return false, enableDetail or hookDetail or "Wheel proxy registration failed"
end

'''
options = replace_once(
    options,
    'local Shared = ns.OptionsShared or {}\nns.OptionsShared = Shared\n\n',
    'local Shared = ns.OptionsShared or {}\nns.OptionsShared = Shared\n\n' + registries,
    'Options registries insertion',
)

old_adaptive = '''local function HookAdaptiveWidth(widget, owner, applyFn)
    if not (widget and owner and type(applyFn) == "function") then
        return
    end

    local function SafeApply()
        local ok = pcall(applyFn)
        if not ok then
            -- noop: avoid breaking settings panel if width calc fails on hidden frames.
        end
    end

    SafeApply()
    if not widget._fguiAdaptiveWidthHooked then
        widget._fguiAdaptiveWidthHooked = true
        if owner.HookScript then
            owner:HookScript("OnSizeChanged", SafeApply)
            owner:HookScript("OnShow", SafeApply)
        end
        if widget.HookScript then
            widget:HookScript("OnShow", SafeApply)
        end
    end
end

'''
options = replace_once(options, old_adaptive, '', 'legacy adaptive width owner')

options = replace_once(
    options,
    '''    HookAdaptiveWidth(fs, parent, function()
        local pw = tonumber(parent:GetWidth()) or 620
        local newWidth = math.floor(pw - 44)
        if newWidth < 180 then newWidth = 180 end
        fs:SetWidth(newWidth)
    end)
''',
    '''    HookAdaptiveWidth(fs, parent, function(target, container)
        local pw = tonumber(container:GetWidth()) or 620
        local newWidth = math.floor(pw - 44)
        if newWidth < 180 then newWidth = 180 end
        target:SetWidth(newWidth)
    end)
''',
    'CreateNote adaptive callback',
)
options = replace_once(
    options,
    '''    HookAdaptiveWidth(s, parent, function()
        local pw = tonumber(parent:GetWidth()) or 620
        -- Keep room for numeric editbox + +/- buttons on the right.
        local w = math.floor(pw - 250)
        if w < 180 then w = 180 end
        if w > 420 then w = 420 end
        s:SetWidth(w)
    end)
''',
    '''    HookAdaptiveWidth(s, parent, function(target, container)
        local pw = tonumber(container:GetWidth()) or 620
        -- Keep room for numeric editbox + +/- buttons on the right.
        local w = math.floor(pw - 250)
        if w < 180 then w = 180 end
        if w > 420 then w = 420 end
        target:SetWidth(w)
    end)
''',
    'CreateSlider adaptive callback',
)
options = replace_once(
    options,
    '''    local updating = false

    local function ClampAndQuantize(v)
''',
    '''    local function ClampAndQuantize(v)
''',
    'remove local numeric updating flag',
)
old_sync = '''    local function SyncFromSlider()
        if updating then return end
        updating = true
        eb:SetText(Format(slider:GetValue()))
        updating = false
    end
'''
new_sync = '''    local function SyncFromSlider()
        return SyncNumericSlider(slider)
    end
'''
options = replace_once(options, old_sync, new_sync, 'numeric slider sync wrapper')
old_numeric_hooks = '''    slider:HookScript("OnValueChanged", function()
        SyncFromSlider()
    end)
    slider:HookScript("OnShow", function()
        SyncFromSlider()
    end)
    local sliderParent = slider:GetParent()
    if sliderParent and sliderParent.HookScript and not slider._fguiNumericParentHooked then
        slider._fguiNumericParentHooked = true
        sliderParent:HookScript("OnShow", function()
            SyncFromSlider()
        end)
    end
'''
new_numeric_hooks = '''    RegisterNumericSliderSync(slider, parent, eb, Format)
'''
options = replace_once(options, old_numeric_hooks, new_numeric_hooks, 'numeric slider hook ownership')
options = replace_once(
    options,
    '''    HookAdaptiveWidth(fs, parent, function()
        local pw = tonumber(parent:GetWidth()) or 620
        local newWidth = math.floor(pw - 36)
        if newWidth < 180 then newWidth = 180 end
        fs:SetWidth(newWidth)
    end)
''',
    '''    HookAdaptiveWidth(fs, parent, function(target, container)
        local pw = tonumber(container:GetWidth()) or 620
        local newWidth = math.floor(pw - 36)
        if newWidth < 180 then newWidth = 180 end
        target:SetWidth(newWidth)
    end)
''',
    'CreateStatusLine adaptive callback',
)
options = replace_once(
    options,
    '''    HookAdaptiveWidth(dd, parent, function()
        local pw = tonumber(parent:GetWidth()) or 620
        local maxWidth = math.floor(pw - 120)
        if maxWidth < 140 then maxWidth = 140 end
        local target = preferred
        if target > maxWidth then
            target = maxWidth
        end
        UIDropDownMenu_SetWidth(dd, target)
    end)
''',
    '''    HookAdaptiveWidth(dd, parent, function(target, container)
        local pw = tonumber(container:GetWidth()) or 620
        local maxWidth = math.floor(pw - 120)
        if maxWidth < 140 then maxWidth = 140 end
        local targetWidth = preferred
        if targetWidth > maxWidth then
            targetWidth = maxWidth
        end
        UIDropDownMenu_SetWidth(target, targetWidth)
    end)
''',
    'CreateDropdown adaptive callback',
)
old_wheel = '''    local function AttachChildWheelProxy(frame)
        if not frame or frame == content or frame == scroll then return end
        if frame._fguiWheelProxy then return end
        if not (frame.EnableMouseWheel and frame.HookScript) then return end

        frame._fguiWheelProxy = true
        frame:EnableMouseWheel(true)
        frame:HookScript("OnMouseWheel", function(_, delta)
            ScrollByDelta(scroll, delta)
        end)
    end

    local function RefreshWheelProxies()
        for _, child in ipairs({ content:GetChildren() }) do
            AttachChildWheelProxy(child)
        end
    end
'''
new_wheel = '''    local function RefreshWheelProxies()
        for _, child in ipairs({ content:GetChildren() }) do
            if child and child ~= content and child ~= scroll then
                AttachWheelProxy(child, scroll, ScrollByDelta)
            end
        end
    end
'''
options = replace_once(options, old_wheel, new_wheel, 'scroll wheel proxy ownership')

options = replace_once(
    options,
    'Shared.SetWidgetText = SetWidgetText\n',
    'Shared.SetWidgetText = SetWidgetText\nShared.AttachWheelProxy = AttachWheelProxy\nShared.RegisterNumericSliderSync = RegisterNumericSliderSync\n',
    'Options registry helper exports',
)
options_path.write_text(options, encoding="utf-8")


movers_path = Path("core/Movers.lua")
movers = movers_path.read_text(encoding="utf-8")
movers = replace_once(
    movers,
    'Movers._stateListeners = Movers._stateListeners or {}\n',
    'Movers._stateListeners = setmetatable({}, { __mode = "k" })\n',
    'Movers weak listener registry',
)
movers = replace_once(
    movers,
    '                local ok = pcall(callback, owner._unlocked, owner)\n',
    '                local ok = pcall(callback, owner._unlocked, owner, key)\n',
    'Movers listener key dispatch',
)
old_listener_api = '''function Movers:RegisterStateListener(key, callback)
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
'''
new_listener_api = '''function Movers:RegisterStateListener(key, callback)
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
'''
movers = replace_once(movers, old_listener_api, new_listener_api, 'Movers listener API')
movers_path.write_text(movers, encoding="utf-8")


panel_path = Path("core/OptionsPanelEditMode.lua")
panel = panel_path.read_text(encoding="utf-8")
panel = replace_once(
    panel,
    '    local Apply = ctx.Apply\n',
    '    local Apply = ctx.Apply\n    local Log = ctx.Log\n',
    'EditMode Log dependency',
)
old_panel_listener = '''    if Movers and Movers.RegisterStateListener and not root._fguiMoversStateListenerRegistered then
        root._fguiMoversStateListenerRegistered = true
        Movers:RegisterStateListener(root, function()
            if root and root.refresh and root:IsVisible() then
                root:refresh()
            end
        end)
    end
'''
new_panel_listener = '''    local function RefreshMoverPanel(_, _, panelRoot)
        if panelRoot and panelRoot.refresh and panelRoot:IsVisible() then
            panelRoot:refresh()
        end
    end

    if Movers and type(Movers.RegisterStateListener) == "function" then
        local registered, detail = Movers:RegisterStateListener(root, RefreshMoverPanel)
        if registered == false and Log and type(Log.Warn) == "function" then
            Log:Warn("Edit Mode mover listener registration failed: " .. tostring(detail))
        end
    end
'''
panel = replace_once(panel, old_panel_listener, new_panel_listener, 'EditMode listener ownership')
panel_path.write_text(panel, encoding="utf-8")


check_path = Path("check_lua.js")
check = check_path.read_text(encoding="utf-8")
contract = '''    assertSourceIncludes('core/OptionsSharedHelpers.lua', 'Shared._adaptiveOwnerRegistry');
    assertSourceIncludes('core/OptionsSharedHelpers.lua', 'Shared._wheelProxyRegistry');
    assertSourceIncludes('core/OptionsSharedHelpers.lua', 'RegisterNumericSliderSync');
    assertSourceIncludes('core/Movers.lua', 'Movers._stateListeners = setmetatable({}, { __mode = "k" })');
    assertSourceIncludes('core/OptionsPanelEditMode.lua', 'local registered, detail = Movers:RegisterStateListener');
    assertSourceExcludes('core/OptionsSharedHelpers.lua', /_fgui(?:AdaptiveWidthHooked|NumericParentHooked|WheelProxy)/, 'Options widget hook metadata');
    assertSourceExcludes('core/OptionsPanelEditMode.lua', /_fguiMoversStateListenerRegistered/, 'Edit Mode listener metadata');
    assertSourceExcludes('core/OptionsSharedHelpers.lua', /\._fgui\w*Hooked\s*=\s*true/, 'preemptive Options hook publication');

'''
check = replace_once(
    check,
    "    assertSourceIncludes('core/Animate.lua', 'Animate._frameRegistry');\n",
    contract + "    assertSourceIncludes('core/Animate.lua', 'Animate._frameRegistry');\n",
    'Options hook static contracts',
)
check_path.write_text(check, encoding="utf-8")


# Release metadata and documentation.
toc_path = Path("FeelsGoodUI.toc")
toc = toc_path.read_text(encoding="utf-8")
toc = replace_once(toc, "## Version: 0.0.64", "## Version: 0.0.65", "TOC version")
toc_path.write_text(toc, encoding="utf-8")

readme_path = Path("README.md")
readme = readme_path.read_text(encoding="utf-8")
readme = replace_once(readme, "- FeelsGoodUI `0.0.64`", "- FeelsGoodUI `0.0.65`", "README version")
readme = replace_once(
    readme,
    "General commands and options never write runtime settings directly:",
    "Options layout hooks and mover-panel listeners use addon-owned weak registries: hook ownership is published only after `HookScript` or listener registration succeeds, partial failures retry only missing edges, rebuilt widgets/panels do not inherit stale markers, and permanent callbacks resolve the current record at dispatch time. General commands and options never write runtime settings directly:",
    "README Options hook policy",
)
readme_path.write_text(readme, encoding="utf-8")

agent_path = Path("AGENT_GUIDE.md")
agent = agent_path.read_text(encoding="utf-8")
agent = replace_once(
    agent,
    "- Options/minimap/commands are adapters over Settings/Apply.",
    "- Options: `core/OptionsSharedHelpers.lua` owns adaptive-width, numeric-sync, and wheel-proxy hooks through weak registries; `core/OptionsPanelEditMode.lua` registers mover refresh through the weak listener API. Never publish hook/listener ownership before the native registration call succeeds or stamp `_fgui*` markers on widgets/panels.\n- Options/minimap/commands are adapters over Settings/Apply.",
    "AGENT_GUIDE Options ownership",
)
agent = replace_once(
    agent,
    "- User-facing adapters must not update runtime optimistically after a profile write;",
    "- Permanent UI hooks/listeners must be retryable and replacement-safe: publish each edge only after successful registration, keep state in addon-owned registries, and make stale callbacks resolve current ownership instead of trusting object markers.\n- User-facing adapters must not update runtime optimistically after a profile write;",
    "AGENT_GUIDE hook invariant",
)
agent_path.write_text(agent, encoding="utf-8")

index_path = Path("CODE_INDEX.md")
index = index_path.read_text(encoding="utf-8")
index = replace_once(
    index,
    "| `core/Options*.lua`, `core/Movers*.lua`, `core/Commands.lua` | Settings pages, frame editing/movement UI, and command adapters over Settings/Apply. |",
    "| `core/OptionsSharedHelpers.lua`, `core/OptionsPanelEditMode.lua` | Weak-key adaptive/numeric/wheel hook ownership, retryable mover-panel listener registration, and marker-free settings UI wiring. |\n| `core/Options*.lua`, `core/Movers*.lua`, `core/Commands.lua` | Settings pages, frame editing/movement UI, and command adapters over Settings/Apply. |",
    "CODE_INDEX Options hooks",
)
index_path.write_text(index, encoding="utf-8")

todo_path = Path("todo.md")
todo = todo_path.read_text(encoding="utf-8")
todo = replace_once(todo, "- [x] Target Interface `120105` and release `0.0.64`.", "- [x] Target Interface `120105` and release `0.0.65`.", "TODO version")
todo = replace_once(
    todo,
    "- [x] Remove generic caller-object metadata: Animate fade/timer state and Minimap LibDBIcon hook state live in weak registries, active drag is button-specific, and the unused arbitrary cooldown-frame cache helper is deleted.\n",
    "- [x] Remove generic caller-object metadata: Animate fade/timer state and Minimap LibDBIcon hook state live in weak registries, active drag is button-specific, and the unused arbitrary cooldown-frame cache helper is deleted.\n- [x] Move Options adaptive-width, numeric-sync, wheel-proxy, and Edit Mode mover-listener ownership into weak registries; publish each hook edge only after successful registration and retry partial failures without widget/panel markers.\n",
    "TODO Options hook status",
)
todo = replace_once(
    todo,
    "- [ ] `/fgui qa` and `/fgui report` complete without legacy-field or schema failures.\n",
    "- [ ] `/fgui qa` and `/fgui report` complete without legacy-field or schema failures.\n- [ ] Rebuild/show/resize every Options page while injecting one failure into owner/widget `HookScript` and mover-listener registration; successful edges remain single, only missing edges retry, widgets/panels receive no `_fgui*` markers, wheel forwarding fires once, and stale rebuilt-panel listeners are collectible/inert.\n",
    "TODO Options hook validation",
)
todo_path.write_text(todo, encoding="utf-8")

matrix_path = Path("docs/REGRESSION_MATRIX_1_25.md")
matrix = matrix_path.read_text(encoding="utf-8")
anchor = "| 27 | Delete one core/feature section after DB initialization, then exercise all runtime readers and settings pages | No read path recreates SavedVariables data; explicit `EnsureSection`/Settings normalization repairs the section once |  |  |"
replacement = anchor + "\n| 28 | Rebuild/show/resize Options pages with injected partial HookScript/listener failure | Weak registries own hooks/listeners; successful edges stay single, missing edges retry, wheel forwarding fires once, and no widget/panel `_fgui*` markers remain |  |  |"
matrix = replace_once(matrix, anchor, replacement, "regression matrix Options hooks")
matrix_path.write_text(matrix, encoding="utf-8")

print("Moved Options hook and listener ownership into retryable weak registries.")
