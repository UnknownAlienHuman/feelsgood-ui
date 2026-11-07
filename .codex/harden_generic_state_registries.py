from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


# Generic animation/timer helpers must not stamp arbitrary owners or frames.
animate_path = Path('core/Animate.lua')
animate = animate_path.read_text(encoding='utf-8')
animate = replace_once(
    animate,
    '''local abs = math.abs
local max = math.max

''',
    '''local abs = math.abs
local max = math.max

Animate._frameRegistry = Animate._frameRegistry or setmetatable({}, { __mode = "k" })
Animate._timerRegistry = Animate._timerRegistry or setmetatable({}, { __mode = "k" })
local FrameRegistry = Animate._frameRegistry
local TimerRegistry = Animate._timerRegistry

''',
    'Animate registry declarations',
)
animate = replace_once(
    animate,
    '''local function GetFrameState(frame)
    local state = frame and frame._fguiAnimateState
    if type(state) ~= "table" then
        state = {}
        if frame then
            frame._fguiAnimateState = state
        end
    end
    return state
end
''',
    '''local function GetFrameState(frame, create)
    local state = frame and FrameRegistry[frame] or nil
    if not state and create == true and frame then
        state = {}
        FrameRegistry[frame] = state
    end
    return state
end
''',
    'Animate frame state registry',
)
animate = replace_once(
    animate,
    '''    group:SetScript("OnFinished", function()
        if group._fguiFinalAlpha ~= nil then
            frame:SetAlpha(group._fguiFinalAlpha)
        end
        if group._fguiHideOnFinished == true and type(frame.Hide) == "function" then
            frame:Hide()
        end
    end)
''',
    '''    group:SetScript("OnFinished", function()
        local finalAlpha = state[key .. "FinalAlpha"]
        if finalAlpha ~= nil then frame:SetAlpha(finalAlpha) end
        if state[key .. "HideOnFinished"] == true and type(frame.Hide) == "function" then
            frame:Hide()
        end
    end)
''',
    'Animate group terminal state registry',
)
animate = replace_once(
    animate,
    '    local state = GetFrameState(frame)\n',
    '    local state = GetFrameState(frame, true)\n',
    'Animate fade state creation',
)
animate = replace_once(
    animate,
    '''    group._fguiFinalAlpha = toAlpha
    group._fguiHideOnFinished = (hideOnFinished == true)
''',
    '''    state[key .. "FinalAlpha"] = toAlpha
    state[key .. "HideOnFinished"] = (hideOnFinished == true)
''',
    'Animate terminal fields registry',
)
animate = replace_once(
    animate,
    '''    local state = GetFrameState(frame)
    StopGroup(state.fadeIn)
    StopGroup(state.fadeOut)
''',
    '''    local state = GetFrameState(frame, false)
    if state then
        StopGroup(state.fadeIn)
        StopGroup(state.fadeOut)
    end
''',
    'Animate non-creating cancel',
)
animate = replace_once(
    animate,
    '''local function GetTimerState(owner)
    local host = (type(owner) == "table") and owner or Animate
    local state = host._fguiAnimateTimers
    if type(state) ~= "table" then
        state = { entries = {}, tokens = {} }
        host._fguiAnimateTimers = state
    end
    return host, state
end
''',
    '''local function GetTimerState(owner)
    local host = (type(owner) == "table") and owner or Animate
    local state = TimerRegistry[host]
    if not state then
        state = { entries = {}, tokens = {} }
        TimerRegistry[host] = state
    end
    return host, state
end
''',
    'Animate timer state registry',
)
animate = replace_once(
    animate,
    '        local current = host._fguiAnimateTimers\n',
    '        local current = TimerRegistry[host]\n',
    'Animate timer callback registry lookup',
)
animate_path.write_text(animate, encoding='utf-8')

# LibDBIcon owns its button. Keep hook metadata outside that third-party frame
# and bind active drag state to the exact button that started it.
minimap_path = Path('core/MinimapIcon.lua')
minimap = minimap_path.read_text(encoding='utf-8')
minimap = replace_once(
    minimap,
    '''local dataObj
local isRegistered = false
local runtimeCfg = {}
local dragging = false
''',
    '''local dataObj
local isRegistered = false
local runtimeCfg = {}
local draggingButton = nil
local dragHookRegistry = setmetatable({}, { __mode = "k" })
MinimapIcon._dragHookRegistry = dragHookRegistry
''',
    'Minimap drag registry declaration',
)
old_hooks = '''local function EnsureDragHooks()
    if not (LDBIcon and type(LDBIcon.GetMinimapButton) == "function") then
        return false
    end

    local button = LDBIcon:GetMinimapButton(addonName)
    if not (button and type(button.HookScript) == "function") then
        return false
    end
    if button._fguiTransactionalDragHooked then
        return true
    end

    button._fguiTransactionalDragHooked = true
    button:HookScript("OnDragStart", function()
        dragging = true
    end)
    button:HookScript("OnDragStop", function()
        if not dragging then return end
        dragging = false

        local ok, err = xpcall(CommitDraggedPosition, function(reason)
            return tostring(reason or "unknown minimap drag commit error")
        end)
        if not ok then
            RestoreRuntimeFromProfile()
            if Log and type(Log.Error) == "function" then
                Log:Error("Minimap drag commit failed: " .. tostring(err))
            end
        end
    end)
    return true
end
'''
new_hooks = '''local function EnsureDragHooks()
    if not (LDBIcon and type(LDBIcon.GetMinimapButton) == "function") then
        return false
    end

    local button = LDBIcon:GetMinimapButton(addonName)
    if not (button and type(button.HookScript) == "function") then
        return false
    end

    local record = dragHookRegistry[button]
    if not record then
        record = {}
        dragHookRegistry[button] = record
    end

    if not record.startHooked then
        local ok = pcall(button.HookScript, button, "OnDragStart", function(startedButton)
            draggingButton = startedButton
        end)
        if not ok then return false end
        record.startHooked = true
    end

    if not record.stopHooked then
        local ok = pcall(button.HookScript, button, "OnDragStop", function(stoppedButton)
            if draggingButton ~= stoppedButton then return end
            draggingButton = nil

            local committed, err = xpcall(CommitDraggedPosition, function(reason)
                return tostring(reason or "unknown minimap drag commit error")
            end)
            if not committed then
                RestoreRuntimeFromProfile()
                if Log and type(Log.Error) == "function" then
                    Log:Error("Minimap drag commit failed: " .. tostring(err))
                end
            end
        end)
        if not ok then return false end
        record.stopHooked = true
    end
    return true
end
'''
minimap = replace_once(minimap, old_hooks, new_hooks, 'Minimap drag hook registry')
minimap = replace_once(
    minimap,
    '''    if LDBIcon and isRegistered then
        if dragging and type(LDBIcon.GetMinimapButton) == "function" then
            local button = LDBIcon:GetMinimapButton(addonName)
            if button and type(button.SetScript) == "function" then
                button:SetScript("OnUpdate", nil)
            end
            dragging = false
            RestoreRuntimeFromProfile()
        end
        LDBIcon:Hide(addonName)
    end
''',
    '''    if LDBIcon and isRegistered then
        local activeButton = draggingButton
        if activeButton then
            if type(activeButton.SetScript) == "function" then
                activeButton:SetScript("OnUpdate", nil)
            end
            draggingButton = nil
            RestoreRuntimeFromProfile()
        end
        LDBIcon:Hide(addonName)
    end
''',
    'Minimap exact drag detach owner',
)
minimap = replace_once(
    minimap,
    '    if dragging then\n',
    '    if draggingButton then\n',
    'Minimap active drag apply guard',
)
minimap_path.write_text(minimap, encoding='utf-8')

# This unused helper wrote a caller-selected cache field into arbitrary
# cooldown frames. ActionBars has an owner-local region registry now.
utils_path = Path('core/Utils.lua')
utils = utils_path.read_text(encoding='utf-8')
start = utils.index('function U.GetCooldownTimerText(')
utils = utils[:start].rstrip() + '\n'
utils_path.write_text(utils, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
check = replace_once(
    check,
    "    assertSourceIncludes('modules/ActionBarsState.lua', 'State._buttonRegistry');\n",
    "    assertSourceIncludes('core/Animate.lua', 'Animate._frameRegistry');\n"
    "    assertSourceIncludes('core/Animate.lua', 'Animate._timerRegistry');\n"
    "    assertSourceExcludes('core/Animate.lua', /_fguiAnimate(?:State|Timers)/, 'generic animation owner metadata');\n"
    "    assertSourceExcludes('core/Animate.lua', /group\\._fgui/, 'animation-group metadata fields');\n"
    "    assertSourceExcludes('core/Utils.lua', /function U\\.GetCooldownTimerText/, 'dead cooldown frame cache helper');\n"
    "    assertSourceIncludes('core/MinimapIcon.lua', 'local dragHookRegistry = setmetatable');\n"
    "    assertSourceIncludes('core/MinimapIcon.lua', 'local draggingButton = nil');\n"
    "    assertSourceExcludes('core/MinimapIcon.lua', /_fguiTransactionalDragHooked/, 'LibDBIcon button metadata');\n"
    "    assertSourceExcludes('core/MinimapIcon.lua', /local dragging = false/, 'global minimap drag boolean');\n\n"
    "    assertSourceIncludes('modules/ActionBarsState.lua', 'State._buttonRegistry');\n",
    'generic state registry contracts',
)
check_path.write_text(check, encoding='utf-8')

# Release metadata and documentation.
toc_path = Path('FeelsGoodUI.toc')
toc = toc_path.read_text(encoding='utf-8')
toc = replace_once(toc, '## Version: 0.0.60', '## Version: 0.0.61', 'TOC version')
toc_path.write_text(toc, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(readme, '- FeelsGoodUI `0.0.60`', '- FeelsGoodUI `0.0.61`', 'README version')
readme = replace_once(
    readme,
    'Minimap drag uses a detached LibDBIcon runtime proxy:',
    'Shared animation fades and keyed timers keep state in weak-key registries rather than arbitrary frame/owner fields; the dead generic cooldown cache helper is removed. Minimap drag uses a detached LibDBIcon runtime proxy and a weak-key hook registry on the addon side:',
    'README generic state policy',
)
readme = replace_once(
    readme,
    'mouse-up creates one validated `Settings:SetTx` transaction, and failed apply/cancel restores the persisted position.',
    'the exact button that starts a drag owns its stop/cancel path, mouse-up creates one validated `Settings:SetTx` transaction, and failed apply/cancel restores the persisted position.',
    'README exact minimap drag owner',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    '- Media: `core/Media.lua` owns borders through a weak-key registry keyed by target frame;',
    '- Animation/timers: `core/Animate.lua` owns fade groups and keyed timer state through weak-key frame/owner registries; generic helpers never add cache fields to callers.\n- Media: `core/Media.lua` owns borders through a weak-key registry keyed by target frame;',
    'AGENT_GUIDE Animate owner',
)
agent = replace_once(
    agent,
    '- Minimap: `core/MinimapIcon.lua` passes a detached runtime proxy to LibDBIcon, hooks drag start/stop, and commits only the terminal position through Settings/Apply;',
    '- Minimap: `core/MinimapIcon.lua` passes a detached runtime proxy to LibDBIcon, keeps hook records in an addon-owned weak registry, binds active drag state to the exact LibDBIcon button, and commits only the terminal position through Settings/Apply;',
    'AGENT_GUIDE minimap hook owner',
)
agent_path.write_text(agent, encoding='utf-8')

index_path = Path('CODE_INDEX.md')
index = index_path.read_text(encoding='utf-8')
index = replace_once(
    index,
    '| `core/RuntimeSettings.lua` | Canonical apply owner for general runtime state: logging level and performance overlay. |',
    '| `core/RuntimeSettings.lua` | Canonical apply owner for general runtime state: logging level and performance overlay. |\n| `core/Animate.lua`, `core/Utils.lua` | Weak-key fade/timer ownership and stateless shared helpers without caller-object cache fields. |',
    'CODE_INDEX generic state owner',
)
index = replace_once(
    index,
    '| `core/MinimapIcon.lua` | LibDBIcon runtime proxy, terminal drag-position transaction, visibility apply owner, and rollback reconciliation. |',
    '| `core/MinimapIcon.lua` | LibDBIcon runtime proxy, weak-key button-hook ownership, exact active-drag owner, terminal position transaction, and rollback reconciliation. |',
    'CODE_INDEX minimap state owner',
)
index_path.write_text(index, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(todo, '- [x] Target Interface `120105` and release `0.0.60`.', '- [x] Target Interface `120105` and release `0.0.61`.', 'TODO version')
todo = replace_once(
    todo,
    '- [x] Move ActionBars runtime metadata off Blizzard ActionButton/FontString/Cooldown objects into weak-key button/region registries; hooks resolve current owner/layers through the registry and no callback/style cache is stored on foreign frames.\n',
    '- [x] Move ActionBars runtime metadata off Blizzard ActionButton/FontString/Cooldown objects into weak-key button/region registries; hooks resolve current owner/layers through the registry and no callback/style cache is stored on foreign frames.\n'
    '- [x] Remove generic caller-object metadata: Animate fade/timer state and Minimap LibDBIcon hook state live in weak registries, active drag is button-specific, and the unused arbitrary cooldown-frame cache helper is deleted.\n',
    'TODO generic registry status',
)
todo = replace_once(
    todo,
    '- [ ] Show/hide/reset and drag the minimap icon from settings and slash commands; OnUpdate performs zero SavedVariables writes, drag stop creates one undoable transaction, no-op drag creates none, and failed apply/cancel restores the persisted position.\n',
    '- [ ] Show/hide/reset and drag the minimap icon from settings and slash commands; OnUpdate performs zero SavedVariables writes, each LibDBIcon button is hooked once without foreign metadata, stale-button stop events are inert, drag stop creates one undoable transaction, and failed apply/cancel restores the persisted position.\n'
    '- [ ] Exercise repeated ExperienceBar fades and keyed timer replacement/cancellation; frame/owner tables receive no `_fguiAnimate*` fields, animation groups are reused, stale callbacks remain invalidated, and terminal alpha/visibility is exact.\n',
    'TODO generic registry validation',
)
todo_path.write_text(todo, encoding='utf-8')

matrix_path = Path('docs/REGRESSION_MATRIX_1_25.md')
matrix = matrix_path.read_text(encoding='utf-8')
matrix = replace_once(
    matrix,
    '| 24 | Theme/media/minimap icon/profile switch; drag icon and force one minimap apply failure | Fonts/textures/colors remain coherent; drag preview writes only the proxy, mouse-up commits once, no-op drag creates no transaction, and failure restores the persisted position |  |  |',
    '| 24 | Theme/media/minimap icon/profile switch; replace the LibDBIcon button, drag it, and force one minimap apply failure | Hook state stays in an addon weak registry, stale-button stop is inert, drag preview writes only the proxy, mouse-up commits once, and failure restores persisted position |  |  |\n'
    '| 24a | Repeat ExperienceBar fades and replace/cancel keyed timers | Frame/owner objects receive no generic metadata; fade groups are reused, stale timer callbacks are invalidated, and terminal alpha/visibility is exact |  |  |',
    'regression matrix generic state registries',
)
matrix_path.write_text(matrix, encoding='utf-8')

print('Moved generic animation, timer, and minimap hook state into weak registries.')
