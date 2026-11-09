from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


state_path = Path("modules/ActionBarsState.lua")
state = state_path.read_text(encoding="utf-8")

registry_block = r'''State._buttonRegistry = State._buttonRegistry or setmetatable({}, { __mode = "k" })
State._holderRegistry = State._holderRegistry or setmetatable({}, { __mode = "k" })
local ButtonRegistry = State._buttonRegistry
local HolderRegistry = State._holderRegistry

local function GetHolderRecord(holder, create)
    if not holder then return nil end
    local record = HolderRegistry[holder]
    if not record and create then
        record = {}
        HolderRegistry[holder] = record
    end
    return record
end

function State.GetHolderRecord(holder, create)
    return GetHolderRecord(holder, create == true)
end

local function TryHookScript(target, event, callback)
    if not (target and type(target.HookScript) == "function") then
        return false, tostring(event) .. " HookScript unavailable"
    end

    local ok, detail = pcall(target.HookScript, target, event, callback)
    if not ok then
        return false, tostring(detail)
    end
    return true
end

local function EnsureScriptHook(record, target, event, field, callback)
    if record[field] == true then return true end

    local ok, detail = TryHookScript(target, event, callback)
    if ok then
        record[field] = true
        record[field .. "Error"] = nil
        return true
    end

    record[field .. "Error"] = detail
    return false, detail
end
'''
state = replace_once(
    state,
    '''State._buttonRegistry = State._buttonRegistry or setmetatable({}, { __mode = "k" })
local ButtonRegistry = State._buttonRegistry
''',
    registry_block,
    "ActionBars holder/hook registry",
)

layers_start = state.index("local function EnsureStateLayers(btn)")
layers_end = state.index("local function EnsureSlotBG(btn)", layers_start)
new_layers = r'''local function OnButtonStateEnter(btn)
    local record = GetButtonRecord(btn, false)
    local owner = record and record.module
    if owner and owner._detached == true then return end
    local layer = record and record.layers and record.layers.highlight
    if layer then layer:Show() end
end

local function OnButtonStateLeave(btn)
    local record = GetButtonRecord(btn, false)
    local layer = record and record.layers and record.layers.highlight
    if layer then layer:Hide() end
end

local function EnsureStateTexture(btn, record, name, drawLayer, subLevel, alpha, blendMode)
    record.layers = record.layers or {}
    local texture = record.layers[name]
    if not texture then
        if type(btn.CreateTexture) ~= "function" then
            return false, "ActionButton CreateTexture unavailable"
        end
        local ok, created = pcall(btn.CreateTexture, btn, nil, drawLayer, nil, subLevel)
        if not ok or not created then
            return false, ok and "ActionButton texture creation returned nil" or tostring(created)
        end
        texture = created
        record.layers[name] = texture
    end

    local ok, detail = pcall(function()
        texture:SetAllPoints(btn)
        texture:SetColorTexture(1, 1, 1, alpha)
        if blendMode then texture:SetBlendMode(blendMode) end
        texture:Hide()
    end)
    if not ok then
        return false, tostring(detail)
    end
    return true
end

local function EnsureStateLayers(btn)
    local record = GetButtonRecord(btn, true)
    if not record then return false, "ActionButton record unavailable" end

    local highlightOK, highlightDetail = EnsureStateTexture(btn, record, "highlight", "HIGHLIGHT", nil, 0.08)
    local checkedOK, checkedDetail = EnsureStateTexture(btn, record, "checked", "OVERLAY", 1, 0.14, "ADD")
    local pressedOK, pressedDetail = EnsureStateTexture(btn, record, "pressed", "OVERLAY", 2, 0.22, "ADD")

    local enterOK, enterDetail = EnsureScriptHook(
        record,
        btn,
        "OnEnter",
        "stateEnterHooked",
        OnButtonStateEnter
    )
    local leaveOK, leaveDetail = EnsureScriptHook(
        record,
        btn,
        "OnLeave",
        "stateLeaveHooked",
        OnButtonStateLeave
    )

    local dhl = btn.GetHighlightTexture and btn:GetHighlightTexture()
    if dhl and dhl.SetAlpha then pcall(dhl.SetAlpha, dhl, 0) end
    local dck = btn.GetCheckedTexture and btn:GetCheckedTexture()
    if dck and dck.SetAlpha then pcall(dck.SetAlpha, dck, 0) end
    local pushed = btn.GetPushedTexture and btn:GetPushedTexture()
    if pushed and pushed.SetAlpha then pcall(pushed.SetAlpha, pushed, 0) end

    local complete = highlightOK and checkedOK and pressedOK and enterOK and leaveOK
    record.stateLayers = complete == true
    if complete then return true end
    return false, highlightDetail or checkedDetail or pressedDetail or enterDetail or leaveDetail
end

'''
state = state[:layers_start] + new_layers + state[layers_end:]

slot_start = state.index("local function EnsureSlotBG(btn)")
slot_end = state.index("local function GetActionID(btn)", slot_start)
new_slot = r'''local function EnsureSlotBG(btn)
    local record = GetButtonRecord(btn, true)
    if not record then return false, "ActionButton record unavailable" end

    local bg = record.slotBackground
    if not bg then
        if type(btn.CreateTexture) ~= "function" then
            return false, "ActionButton CreateTexture unavailable"
        end
        local ok, created = pcall(btn.CreateTexture, btn, nil, "BACKGROUND")
        if not ok or not created then
            return false, ok and "ActionButton slot background creation returned nil" or tostring(created)
        end
        bg = created
        record.slotBackground = bg
    end

    local ok, detail = pcall(function()
        bg:SetAllPoints(btn)
        bg:SetColorTexture(1, 1, 1, 0.02)
        bg:Hide()
    end)
    if not ok then
        return false, tostring(detail)
    end
    return true
end

'''
state = state[:slot_start] + new_slot + state[slot_end:]

state = replace_once(
    state,
    '''    local holder = btn.GetParent and btn:GetParent() or nil
    local holderAutoHidden = (holder and holder._fguiAutoHidden == true) or false
''',
    '''    local holder = btn.GetParent and btn:GetParent() or nil
    local holderRecord = GetHolderRecord(holder, false)
    local holderAutoHidden = holderRecord and holderRecord.autoHidden == true or false
''',
    "ActionBars auto-hidden registry read",
)

old_initialize = '''function State.InitializeButton(btn)
    local record = GetButtonRecord(btn, false)
    if not (btn and record and record.skinned) then return false end

    EnsureSlotBG(btn)
    EnsureStateLayers(btn)
    UpdateButtonChecked(btn)
    UpdateEmptySlot(btn)
    return true
end
'''
new_initialize = '''function State.InitializeButton(btn)
    local record = GetButtonRecord(btn, false)
    if not (btn and record and record.skinned) then return false end

    local slotOK, slotDetail = EnsureSlotBG(btn)
    local layersOK, layersDetail = EnsureStateLayers(btn)
    if not slotOK or not layersOK then
        return false, slotDetail or layersDetail
    end

    UpdateButtonChecked(btn)
    UpdateEmptySlot(btn)
    return true
end
'''
state = replace_once(state, old_initialize, new_initialize, "ActionBars button initialization result")

button_hook_start = state.index("function State.AttachButtonAutoHideHooks(btn, module)")
button_hook_end = state.index("local function SetHolderButtonsMouse", button_hook_start)
new_button_hooks = r'''local function OnButtonAutoHideEdge(btn)
    local record = GetButtonRecord(btn, false)
    local owner = record and record.module
    if owner then State.QueueAutoHideUpdate(owner) end
end

function State.AttachButtonAutoHideHooks(btn, module)
    local record = GetButtonRecord(btn, true)
    if not record then return false, "ActionButton record unavailable" end

    record.module = module or ns.ActionBars
    local enterOK, enterDetail = EnsureScriptHook(
        record,
        btn,
        "OnEnter",
        "autoHideEnterHooked",
        OnButtonAutoHideEdge
    )
    local leaveOK, leaveDetail = EnsureScriptHook(
        record,
        btn,
        "OnLeave",
        "autoHideLeaveHooked",
        OnButtonAutoHideEdge
    )

    record.autoHideHooks = enterOK and leaveOK or false
    if record.autoHideHooks then return true end
    return false, enterDetail or leaveDetail
end

'''
state = state[:button_hook_start] + new_button_hooks + state[button_hook_end:]

old_set_holder = '''function State.SetHolderAutoHidden(holder, hidden)
    if not holder then
        return
    end

    hidden = (hidden == true)
    holder._fguiAutoHidden = hidden
    holder:SetAlpha(hidden and 0 or 1)
    SetHolderButtonsMouse(holder, not hidden)
end
'''
new_set_holder = '''function State.SetHolderAutoHidden(holder, hidden)
    if not holder then
        return false
    end

    hidden = (hidden == true)
    local record = GetHolderRecord(holder, true)
    record.autoHidden = hidden
    holder:SetAlpha(hidden and 0 or 1)
    SetHolderButtonsMouse(holder, not hidden)
    return true
end
'''
state = replace_once(state, old_set_holder, new_set_holder, "ActionBars holder auto-hidden ownership")

holder_hooks_start = state.index("function State.EnsureAutoHideHooks(module)")
holder_hooks_end = state.index("local function RunButtonVisualSync", holder_hooks_start)
new_holder_hooks = r'''local function OnHolderAutoHideEdge(holder)
    local record = GetHolderRecord(holder, false)
    local owner = record and record.module
    if owner then State.QueueAutoHideUpdate(owner) end
end

function State.EnsureAutoHideHooks(module)
    if IsDetached(module) then
        return false, "ActionBars auto-hide owner detached"
    end
    if type(module._ForEachHolder) ~= "function" then
        return false, "ActionBars holder iterator unavailable"
    end

    local allOK = true
    local firstDetail
    module:_ForEachHolder(function(holder)
        if not holder then return end

        local record = GetHolderRecord(holder, true)
        record.module = module
        SetMouseEnabledSafe(holder, true)

        local enterOK, enterDetail = EnsureScriptHook(
            record,
            holder,
            "OnEnter",
            "autoHideEnterHooked",
            OnHolderAutoHideEdge
        )
        local leaveOK, leaveDetail = EnsureScriptHook(
            record,
            holder,
            "OnLeave",
            "autoHideLeaveHooked",
            OnHolderAutoHideEdge
        )

        record.autoHideHooks = enterOK and leaveOK or false
        if not record.autoHideHooks then
            allOK = false
            firstDetail = firstDetail or enterDetail or leaveDetail
        end
    end)

    if allOK then return true end
    return false, firstDetail or "ActionBars holder auto-hide hook registration failed"
end

'''
state = state[:holder_hooks_start] + new_holder_hooks + state[holder_hooks_end:]
state_path.write_text(state, encoding="utf-8")


facade_path = Path("modules/ActionBars.lua")
facade = facade_path.read_text(encoding="utf-8")
facade = replace_once(
    facade,
    '''function ActionBars:_SetHolderAutoHidden(holder, hidden)
    if State and State.SetHolderAutoHidden then
        State.SetHolderAutoHidden(holder, hidden)
    end
end
''',
    '''function ActionBars:_SetHolderAutoHidden(holder, hidden)
    if State and State.SetHolderAutoHidden then
        return State.SetHolderAutoHidden(holder, hidden)
    end
    return false
end
''',
    "ActionBars holder state facade result",
)
facade = replace_once(
    facade,
    '''function ActionBars:EnsureAutoHideHooks()
    if State and State.EnsureAutoHideHooks then
        State.EnsureAutoHideHooks(self)
    end
end
''',
    '''function ActionBars:EnsureAutoHideHooks()
    if State and State.EnsureAutoHideHooks then
        return State.EnsureAutoHideHooks(self)
    end
    return false, "ActionBars state owner unavailable"
end
''',
    "ActionBars auto-hide facade result",
)
facade_path.write_text(facade, encoding="utf-8")


runtime_path = Path("modules/ActionBarsRuntime.lua")
runtime = runtime_path.read_text(encoding="utf-8")
assign_start = runtime.index("local function AssignButtons(module, holder, prefix, style, showHotkeys)")
assign_end = runtime.index("local function ApplyHolderHotkeys", assign_start)
new_assign = r'''local function AssignButtons(module, holder, prefix, style, showHotkeys)
    local buttons = CollectButtons(prefix)
    if not buttons then
        return false, "ActionButtons unavailable for " .. tostring(prefix)
    end

    local allOK = true
    local firstDetail
    for i = 1, BUTTONS_PER_BAR do
        local button = buttons[i]
        holder.buttons[i] = button

        if Visuals and Visuals.SkinButton then
            local ok, detail = Visuals.SkinButton(button, style)
            if ok == false then
                allOK = false
                firstDetail = firstDetail or detail or "ActionButton skin initialization failed"
            end
        end
        if Visuals and Visuals.RefreshButtonVisualState then
            local ok, detail = Visuals.RefreshButtonVisualState(button, style, showHotkeys)
            if ok == false then
                allOK = false
                firstDetail = firstDetail or detail or "ActionButton visual refresh failed"
            end
        end

        if State and State.AttachButtonAutoHideHooks then
            local ok, detail = State.AttachButtonAutoHideHooks(button, module)
            if ok == false then
                allOK = false
                firstDetail = firstDetail or detail or "ActionButton auto-hide hook registration failed"
            end
        end
    end

    if allOK then return true end
    return false, firstDetail
end

'''
runtime = runtime[:assign_start] + new_assign + runtime[assign_end:]

runtime = replace_once(
    runtime,
    '''    local ok = AssignButtons(module, holder, prefix, styleCfg, showHotkeys)
    if not ok then
        holder:Hide()
        return false
    end
''',
    '''    local ok, detail = AssignButtons(module, holder, prefix, styleCfg, showHotkeys)
    if not ok then
        holder:Hide()
        return false, detail
    end
''',
    "ActionBars holder assignment detail",
)

runtime = replace_once(
    runtime,
    '''    local ab = GetActionBarsCfg()
    module:EnsureCreated()
    module:EnsureAutoHideHooks()

    local autoHide = (type(ab.autoHide) == "table") and ab.autoHide or nil
''',
    '''    local ab = GetActionBarsCfg()
    module:EnsureCreated()
    local hooksOK, hooksDetail = module:EnsureAutoHideHooks()
    if hooksOK == false then
        if Log and type(Log.Warn) == "function" then
            Log:Warn("ActionBars auto-hide hook registration failed: " .. tostring(hooksDetail))
        end
        return false
    end

    local autoHide = (type(ab.autoHide) == "table") and ab.autoHide or nil
''',
    "ActionBars holder hook result propagation",
)
runtime_path.write_text(runtime, encoding="utf-8")


visuals_path = Path("modules/ActionBarsVisuals.lua")
visuals = visuals_path.read_text(encoding="utf-8")
visuals = replace_once(
    visuals,
    '''    if State and State.InitializeButton then State.InitializeButton(btn) end
    return true
end
''',
    '''    if State and State.InitializeButton then
        local ok, detail = State.InitializeButton(btn)
        if ok == false then return false, detail end
    end
    return true
end
''',
    "ActionBars skin initialization propagation",
)
visuals = replace_once(
    visuals,
    '''    Visuals.SetButtonHotkey(btn, record.showHotkeys == true)
    if State and State.InitializeButton then State.InitializeButton(btn) end
    if State and State.UpdateButtonChecked then State.UpdateButtonChecked(btn) end
''',
    '''    Visuals.SetButtonHotkey(btn, record.showHotkeys == true)
    if State and State.InitializeButton then
        local ok, detail = State.InitializeButton(btn)
        if ok == false then return false, detail end
    end
    if State and State.UpdateButtonChecked then State.UpdateButtonChecked(btn) end
''',
    "ActionBars refresh initialization propagation",
)
visuals_path.write_text(visuals, encoding="utf-8")


check_path = Path("check_lua.js")
check = check_path.read_text(encoding="utf-8")
contracts = '''    assertSourceIncludes('modules/ActionBarsState.lua', 'State._holderRegistry');
    assertSourceIncludes('modules/ActionBarsState.lua', 'local function EnsureScriptHook');
    assertSourceIncludes('modules/ActionBarsState.lua', 'OnButtonAutoHideEdge');
    assertSourceIncludes('modules/ActionBarsState.lua', 'OnHolderAutoHideEdge');
    assertSourceExcludes('modules/ActionBarsState.lua', /holder\._fguiAutoHidden/, 'ActionBars holder auto-hide metadata');
    assertSourceExcludes('modules/ActionBarsState.lua', /holder\._fguiAutoHideHooks/, 'ActionBars holder hook metadata');
    assertSourceExcludes('modules/ActionBarsState.lua', /module\._autoHideHooksAttached\s*=\s*true/, 'preemptive ActionBars holder-hook publication');
    assertSourceExcludes('modules/ActionBarsState.lua', /record\.autoHideHooks\s*=\s*true\s*\n\s*btn:HookScript/, 'preemptive ActionButton hook publication');
    assertSourceIncludes('modules/ActionBarsRuntime.lua', 'local hooksOK, hooksDetail = module:EnsureAutoHideHooks()');
    assertSourceIncludes('modules/ActionBarsVisuals.lua', 'if ok == false then return false, detail end');

'''
check = replace_once(
    check,
    "    assertSourceIncludes('modules/ActionBarsState.lua', 'State._buttonRegistry');\n",
    "    assertSourceIncludes('modules/ActionBarsState.lua', 'State._buttonRegistry');\n" + contracts,
    "ActionBars hook ownership static contracts",
)
check_path.write_text(check, encoding="utf-8")


# Release metadata and docs.
toc_path = Path("FeelsGoodUI.toc")
toc = toc_path.read_text(encoding="utf-8")
toc = replace_once(toc, "## Version: 0.0.65", "## Version: 0.0.66", "TOC version")
toc_path.write_text(toc, encoding="utf-8")

readme_path = Path("README.md")
readme = readme_path.read_text(encoding="utf-8")
readme = replace_once(readme, "- FeelsGoodUI `0.0.65`", "- FeelsGoodUI `0.0.66`", "README version")
readme = replace_once(
    readme,
    "Protected action-bar and Blizzard-frame mutations remain deferred outside combat.",
    "ActionBars holder/button auto-hide and state-layer hooks are result-bearing: weak registries own holder/button state, each `HookScript` edge is published only after success, callbacks resolve the current module record, partial registration retries without duplicate textures/hooks, and failures reach Apply instead of leaving a false attached state. Protected action-bar and Blizzard-frame mutations remain deferred outside combat.",
    "README ActionBars hook policy",
)
readme_path.write_text(readme, encoding="utf-8")

agent_path = Path("AGENT_GUIDE.md")
agent = agent_path.read_text(encoding="utf-8")
agent = replace_once(
    agent,
    "- Action bars: `modules/ActionBars.lua` owns secure holders and delegates state, visual, Blizzard shell, Edit Mode, and runtime updates to the `ActionBars*` files.",
    "- Action bars: `modules/ActionBars.lua` owns secure holders and delegates state, visual, Blizzard shell, Edit Mode, and runtime updates to the `ActionBars*` files. `ActionBarsState` keeps button/holder state and per-edge hook completion in weak registries; callbacks resolve current ownership and hook failures propagate through `ActionBarsVisuals`/`ActionBarsRuntime`.",
    "AGENT_GUIDE ActionBars hook ownership",
)
agent = replace_once(
    agent,
    "- Secure action-bar holders, state drivers, Edit Mode, `SetAttribute`, Blizzard shell visibility, and native action-bar toggles are protected ownership boundaries.",
    "- Secure action-bar holders, state drivers, Edit Mode, `SetAttribute`, Blizzard shell visibility, and native action-bar toggles are protected ownership boundaries. Per-button/holder hooks are independent result-bearing edges: never publish a summary flag before every required edge succeeds, and never capture a stale module in a permanent callback.",
    "AGENT_GUIDE ActionBars hook invariant",
)
agent_path.write_text(agent, encoding="utf-8")

index_path = Path("CODE_INDEX.md")
index = index_path.read_text(encoding="utf-8")
index = replace_once(
    index,
    "| `modules/ActionBars.lua`, `modules/ActionBarsRuntime.lua`, `modules/ActionBarsState.lua`, `modules/ActionBarsVisuals.lua`, `modules/ActionBarsEditMode.lua` | Secure holders, event/lifecycle coordination, state, visuals, and mover integration without direct profile mutation. |",
    "| `modules/ActionBars.lua`, `modules/ActionBarsRuntime.lua`, `modules/ActionBarsState.lua`, `modules/ActionBarsVisuals.lua`, `modules/ActionBarsEditMode.lua` | Secure holders, event/lifecycle coordination, weak holder/button hook ownership, result-bearing state-layer initialization, visuals, and mover integration without direct profile mutation. |",
    "CODE_INDEX ActionBars hooks",
)
index_path.write_text(index, encoding="utf-8")

todo_path = Path("todo.md")
todo = todo_path.read_text(encoding="utf-8")
todo = replace_once(todo, "- [x] Target Interface `120105` and release `0.0.65`.", "- [x] Target Interface `120105` and release `0.0.66`.", "TODO version")
todo = replace_once(
    todo,
    "- [x] Move Options adaptive-width, numeric-sync, wheel-proxy, and Edit Mode mover-listener ownership into weak registries; publish each hook edge only after successful registration and retry partial failures without widget/panel markers.\n",
    "- [x] Move Options adaptive-width, numeric-sync, wheel-proxy, and Edit Mode mover-listener ownership into weak registries; publish each hook edge only after successful registration and retry partial failures without widget/panel markers.\n- [x] Make ActionBars holder/button auto-hide and state-layer hooks result-bearing: weak registries own state, callbacks resolve current owners, partial failures retry only missing edges, and visual/apply callers propagate failure.\n",
    "TODO ActionBars hook status",
)
todo = replace_once(
    todo,
    "- [ ] Repeatedly skin, refresh, detach and re-enable all five ActionBars; custom layers, typography and cooldown caches are reused through weak-key registries, Blizzard buttons/regions contain no `_fgui*` metadata, and permanent hooks become inert while detached.\n",
    "- [ ] Repeatedly skin, refresh, detach and re-enable all five ActionBars while injecting one holder/button `HookScript` failure; successful edges and textures remain single, only missing edges retry, callbacks follow the current module, no holder `_fguiAutoHidden`/`_fguiAutoHideHooks` fields appear, and the exact failure reaches Apply.\n",
    "TODO ActionBars hook validation",
)
todo_path.write_text(todo, encoding="utf-8")

matrix_path = Path("docs/REGRESSION_MATRIX_1_25.md")
matrix = matrix_path.read_text(encoding="utf-8")
old = "| 19 | Configure and repeatedly refresh action bars out of combat | Geometry/visibility/bindings apply once; custom layers and typography caches are reused from weak registries; Blizzard buttons/regions receive no `_fgui*` metadata |  |  |"
new = "| 19 | Configure and repeatedly refresh action bars out of combat; inject one holder/button HookScript failure and retry | Geometry/visibility/bindings apply once; holder/button hooks and custom layers are reused from weak registries; only missing edges retry; failures reach Apply; Blizzard buttons/regions receive no `_fgui*` metadata |  |  |"
matrix = replace_once(matrix, old, new, "regression matrix ActionBars hooks")
matrix_path.write_text(matrix, encoding="utf-8")

print("Made ActionBars holder/button hooks result-bearing and replacement-safe.")
