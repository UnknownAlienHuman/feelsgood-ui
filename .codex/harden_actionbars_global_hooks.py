from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# ActionBarsState: permanent secure hooks live in one target/method registry.
# ---------------------------------------------------------------------------
state_path = Path('modules/ActionBarsState.lua')
state = state_path.read_text(encoding='utf-8')
state = replace_once(
    state,
    '''local ButtonRegistry = State._buttonRegistry
local HolderRegistry = State._holderRegistry
''',
    '''local ButtonRegistry = State._buttonRegistry
local HolderRegistry = State._holderRegistry

State._secureHookRegistry = State._secureHookRegistry or setmetatable({}, { __mode = "k" })
State._globalHookState = State._globalHookState or {}
local SecureHookRegistry = State._secureHookRegistry
local GlobalHookState = State._globalHookState

local function GetSecureHookRecord(target, create)
    if type(target) ~= "table" then return nil end
    local record = SecureHookRegistry[target]
    if not record and create then
        record = {}
        SecureHookRegistry[target] = record
    end
    return record
end

local function EnsureSecureMethodHook(target, method, callback)
    if type(target) ~= "table" or type(method) ~= "string" or type(callback) ~= "function" then
        return false, "Invalid secure hook registration"
    end

    local record = GetSecureHookRecord(target, true)
    if record[method] == true then return true end

    local secureHook = _G.hooksecurefunc or hooksecurefunc
    if type(secureHook) ~= "function" then
        return false, "hooksecurefunc unavailable"
    end

    local ok, detail = pcall(secureHook, target, method, callback)
    if not ok then
        record[method .. "Error"] = tostring(detail)
        return false, tostring(detail)
    end

    record[method] = true
    record[method .. "Error"] = nil
    return true
end

function State.ReleaseStateHookOwner(module)
    if GlobalHookState.owner == module then
        GlobalHookState.owner = nil
        return true
    end
    return false
end
''',
    'State global hook registry',
)

state_hook_start = state.index('function State.EnsureStateHooks(module)')
state_hook_end = state.index('function State.RefreshEmptySlots(module)', state_hook_start)
new_state_hooks = r'''local function ActiveStateHookOwner()
    local module = GlobalHookState.owner
    if IsDetached(module) then return nil end
    return module
end

local function OnActionButtonUpdateState(btn)
    local module = ActiveStateHookOwner()
    if module then RunButtonVisualSync(module, btn, true, true) end
end

local function OnActionButtonUpdateUsable(btn)
    local module = ActiveStateHookOwner()
    if module then RunButtonVisualSync(module, btn, false, true) end
end

local function OnActionButtonUpdateAction(btn)
    local module = ActiveStateHookOwner()
    if module then RunButtonVisualSync(module, btn, true, true) end
end

local function OnBaseActionButtonShowGrid(btn)
    local module = ActiveStateHookOwner()
    if module then UpdateEmptySlot(btn) end
end

local function OnMoversUnlocked()
    local module = ActiveStateHookOwner()
    if not module then return end
    State.RefreshEmptySlots(module)
    State.UpdateAutoHideState(module)
end

local function OnSpellAlertShown(_, btn)
    local module = ActiveStateHookOwner()
    if not module or not btn then return end

    local record = GetButtonRecord(btn, false)
    local pressed = record and record.layers and record.layers.pressed
    if pressed then pressed:Show() end

    local overlay = btn.SpellActivationAlert or btn.overlay
    if overlay and overlay.SetAlpha then
        overlay:SetAlpha(0)
        if overlay.Hide then overlay:Hide() end
    end
end

local function OnSpellAlertHidden(_, btn)
    local module = ActiveStateHookOwner()
    if not module then return end

    local record = GetButtonRecord(btn, false)
    local pressed = record and record.layers and record.layers.pressed
    if pressed then pressed:Hide() end
end

function State.EnsureStateHooks(module, hasActionChangedCallback)
    if type(module) ~= "table" then
        return false, "ActionBars state hook owner unavailable"
    end

    GlobalHookState.owner = module
    local firstDetail

    local function Ensure(target, method, callback, label)
        if type(target) ~= "table" or type(target[method]) ~= "function" then
            return true
        end
        local ok, detail = EnsureSecureMethodHook(target, method, callback)
        if not ok then
            firstDetail = firstDetail or (tostring(label) .. ": " .. tostring(detail))
        end
        return ok
    end

    local actionButtonMixin = _G.ActionBarActionButtonMixin
    Ensure(actionButtonMixin, "UpdateState", OnActionButtonUpdateState, "ActionBarActionButtonMixin.UpdateState")
    Ensure(actionButtonMixin, "UpdateUsable", OnActionButtonUpdateUsable, "ActionBarActionButtonMixin.UpdateUsable")
    if hasActionChangedCallback ~= true then
        Ensure(actionButtonMixin, "UpdateAction", OnActionButtonUpdateAction, "ActionBarActionButtonMixin.UpdateAction")
    end

    local baseActionButtonMixin = _G.BaseActionButtonMixin
    Ensure(baseActionButtonMixin, "SetShowGrid", OnBaseActionButtonShowGrid, "BaseActionButtonMixin.SetShowGrid")

    if Movers and type(Movers.SetUnlocked) == "function" then
        Ensure(Movers, "SetUnlocked", OnMoversUnlocked, "Movers.SetUnlocked")
    end

    local spellAlertManager = _G.ActionButtonSpellAlertManager
    Ensure(spellAlertManager, "ShowAlert", OnSpellAlertShown, "ActionButtonSpellAlertManager.ShowAlert")
    Ensure(spellAlertManager, "HideAlert", OnSpellAlertHidden, "ActionButtonSpellAlertManager.HideAlert")

    if firstDetail then
        return false, "ActionBars state hook registration failed: " .. firstDetail
    end
    return true
end

'''
state = state[:state_hook_start] + new_state_hooks + state[state_hook_end:]
state_path.write_text(state, encoding='utf-8')


# ---------------------------------------------------------------------------
# Blizzard shell: EndCaps and Settings hooks are addon-owned, replacement-safe.
# ---------------------------------------------------------------------------
shell_path = Path('modules/ActionBarsBlizzardShell.lua')
shell = shell_path.read_text(encoding='utf-8')
shell = replace_once(
    shell,
    '''Shell._blizzardArtStates = Shell._blizzardArtStates or {}

ns._abPastebin = ns._abPastebin or CreateFrame("Frame")
''',
    '''Shell._blizzardArtStates = Shell._blizzardArtStates or {}
Shell._secureHookRegistry = Shell._secureHookRegistry or setmetatable({}, { __mode = "k" })
Shell._scriptHookRegistry = Shell._scriptHookRegistry or setmetatable({}, { __mode = "k" })
Shell._globalHookState = Shell._globalHookState or {}
local SecureHookRegistry = Shell._secureHookRegistry
local ScriptHookRegistry = Shell._scriptHookRegistry
local GlobalHookState = Shell._globalHookState

local function GetHookRecord(registry, target, create)
    if type(target) ~= "table" then return nil end
    local record = registry[target]
    if not record and create then
        record = {}
        registry[target] = record
    end
    return record
end

local function EnsureSecureMethodHook(target, method, callback)
    local record = GetHookRecord(SecureHookRegistry, target, true)
    if not record then return false, "Invalid secure hook target" end
    if record[method] == true then return true end

    local secureHook = _G.hooksecurefunc or hooksecurefunc
    if type(secureHook) ~= "function" then
        return false, "hooksecurefunc unavailable"
    end

    local ok, detail = pcall(secureHook, target, method, callback)
    if not ok then
        record[method .. "Error"] = tostring(detail)
        return false, tostring(detail)
    end
    record[method] = true
    record[method .. "Error"] = nil
    return true
end

local function EnsureScriptHook(target, event, callback)
    local record = GetHookRecord(ScriptHookRegistry, target, true)
    if not record then return false, "Invalid script hook target" end
    if record[event] == true then return true end
    if type(target.HookScript) ~= "function" then
        return false, tostring(event) .. " HookScript unavailable"
    end

    local ok, detail = pcall(target.HookScript, target, event, callback)
    if not ok then
        record[event .. "Error"] = tostring(detail)
        return false, tostring(detail)
    end
    record[event] = true
    record[event .. "Error"] = nil
    return true
end

function Shell.ReleaseHookOwner(module)
    if GlobalHookState.owner == module then
        GlobalHookState.owner = nil
        return true
    end
    return false
end

ns._abPastebin = ns._abPastebin or CreateFrame("Frame")
''',
    'Shell global hook registry',
)

shell_hook_start = shell.index('function Shell.EnsureEndCapsHook(module)')
shell_hook_end = shell.index('return Shell', shell_hook_start)
new_shell_hooks = r'''local function ActiveShellHookOwner()
    local module = GlobalHookState.owner
    if IsDetached(module) then return nil end
    return module
end

local function OnEndCapsUpdated()
    local module = ActiveShellHookOwner()
    if module and Shell.ShouldHideBlizzardArt() then
        Shell.KickHideBlizzardArt(module)
    end
end

local function RepairSettingsShell()
    local module = ActiveShellHookOwner()
    if not module or type(module.ApplyConfig) ~= "function" then return end
    if InCombat() then
        module._pending = true
        return
    end
    module:ApplyConfig()
end

function Shell.EnsureEndCapsHook(module)
    if type(module) ~= "table" then
        return false, "ActionBars shell hook owner unavailable"
    end
    GlobalHookState.owner = module

    local mainActionBarMixin = _G.MainActionBarMixin
    if type(mainActionBarMixin) == "table" and type(mainActionBarMixin.UpdateEndCaps) == "function" then
        local ok, detail = EnsureSecureMethodHook(mainActionBarMixin, "UpdateEndCaps", OnEndCapsUpdated)
        if not ok then
            return false, "MainActionBarMixin.UpdateEndCaps: " .. tostring(detail)
        end
        return true
    end

    if type(_G.MainMenuBarArtFrame_UpdateEndCaps) == "function" then
        local ok, detail = EnsureSecureMethodHook(_G, "MainMenuBarArtFrame_UpdateEndCaps", OnEndCapsUpdated)
        if not ok then
            return false, "MainMenuBarArtFrame_UpdateEndCaps: " .. tostring(detail)
        end
    end
    return true
end

function Shell.EnsureSettingsHooks(module)
    if type(module) ~= "table" then
        return false, "ActionBars settings hook owner unavailable"
    end
    GlobalHookState.owner = module

    local firstDetail
    local settingsPanel = _G.SettingsPanel
    if type(settingsPanel) == "table" and type(settingsPanel.HookScript) == "function" then
        local ok, detail = EnsureScriptHook(settingsPanel, "OnHide", RepairSettingsShell)
        if not ok then
            firstDetail = firstDetail or ("SettingsPanel.OnHide: " .. tostring(detail))
        end
    end

    local settingsMixin = _G.SettingsPanelMixin
    if type(settingsMixin) == "table" and type(settingsMixin.TransitionBackOpeningPanel) == "function" then
        local ok, detail = EnsureSecureMethodHook(
            settingsMixin,
            "TransitionBackOpeningPanel",
            RepairSettingsShell
        )
        if not ok then
            firstDetail = firstDetail
                or ("SettingsPanelMixin.TransitionBackOpeningPanel: " .. tostring(detail))
        end
    end

    if firstDetail then
        return false, "ActionBars settings hook registration failed: " .. firstDetail
    end
    return true
end

'''
shell = shell[:shell_hook_start] + new_shell_hooks + shell[shell_hook_end:]
shell_path.write_text(shell, encoding='utf-8')


# ---------------------------------------------------------------------------
# Facade and runtime: publish init/callback state only after successful edges.
# ---------------------------------------------------------------------------
facade_path = Path('modules/ActionBars.lua')
facade = facade_path.read_text(encoding='utf-8')
facade = replace_once(
    facade,
    '''function ActionBars:EnsureStateHooks()
    if State and State.EnsureStateHooks then
        State.EnsureStateHooks(self)
    end
end
''',
    '''function ActionBars:EnsureStateHooks(hasActionChangedCallback)
    if State and State.EnsureStateHooks then
        return State.EnsureStateHooks(self, hasActionChangedCallback == true)
    end
    return false, "ActionBars state hook owner unavailable"
end
''',
    'ActionBars state hook facade',
)
facade_path.write_text(facade, encoding='utf-8')

runtime_path = Path('modules/ActionBarsRuntime.lua')
runtime = runtime_path.read_text(encoding='utf-8')
callback_start = runtime.index('local function EnsureActionChangedCallback(module)')
callback_end = runtime.index('function Runtime.PreviewMoverLayout', callback_start)
new_callback = r'''local function OnActionChanged(_, button)
    local activeModule = ns.ActionBars
    if IsDetached(activeModule) then return end

    if Visuals and Visuals.RefreshButtonVisualState then
        if Visuals.RefreshButtonVisualState(button) then return end
    end
    if State and State.UpdateButtonChecked then State.UpdateButtonChecked(button) end
    if State and State.UpdateButtonEmpty then State.UpdateButtonEmpty(button) end
end

local function EnsureActionChangedCallback(module)
    if module._actionChangedCallbackRegistered == true then
        return true, nil, true
    end
    if not _G.EventRegistry then
        return true, nil, false
    end
    if not (EventUtil and type(EventUtil.CreateCallbackHandleContainer) == "function") then
        return true, nil, false
    end

    if not module._callbackHandles then
        local ok, container = pcall(EventUtil.CreateCallbackHandleContainer)
        if not ok or not container then
            return false, ok and "Callback handle container unavailable" or tostring(container), false
        end
        module._callbackHandles = container
    end

    if type(module._callbackHandles.RegisterCallback) ~= "function" then
        return false, "Callback handle container lacks RegisterCallback", false
    end

    local registeredOK, registeredDetail = pcall(
        module._callbackHandles.RegisterCallback,
        module._callbackHandles,
        _G.EventRegistry,
        "ActionButton.OnActionChanged",
        OnActionChanged,
        module
    )
    if not registeredOK then
        return false, tostring(registeredDetail), false
    end

    module._actionChangedCallbackRegistered = true
    return true, nil, true
end

'''
runtime = runtime[:callback_start] + new_callback + runtime[callback_end:]

runtime = replace_once(
    runtime,
    '''    local ab = GetActionBarsCfg()
    module:EnsureCreated()
    local hooksOK, hooksDetail = module:EnsureAutoHideHooks()
''',
    '''    local ab = GetActionBarsCfg()
    module:EnsureCreated()

    local stateHooksOK, stateHooksDetail = module:EnsureStateHooks(
        module._actionChangedCallbackRegistered == true
    )
    if stateHooksOK == false then
        return false, tostring(stateHooksDetail or "ActionBars state hook registration failed")
    end

    if Shell and Shell.EnsureEndCapsHook then
        local endCapsOK, endCapsDetail = Shell.EnsureEndCapsHook(module)
        if endCapsOK == false then
            return false, "ActionBars end-cap hook registration failed: " .. tostring(endCapsDetail)
        end
    end

    local hooksOK, hooksDetail = module:EnsureAutoHideHooks()
''',
    'ApplyNow global hook validation',
)
runtime = replace_once(
    runtime,
    '''    if Shell and Shell.EnsureSettingsHooks then
        Shell.EnsureSettingsHooks(module)
    end
''',
    '''    if Shell and Shell.EnsureSettingsHooks then
        local settingsOK, settingsDetail = Shell.EnsureSettingsHooks(module)
        if settingsOK == false then
            return false, tostring(settingsDetail or "ActionBars settings hook registration failed")
        end
    end
''',
    'ApplyNow settings hook result',
)
old_init = '''function Runtime.Init(module)
    if not IsReady(module) then
        return false
    end
    if module._initDone then
        return true
    end

    module._initDone = true
    module._inited = true
    module:EnsureStateHooks()

    if Shell and Shell.EnsureEndCapsHook then
        Shell.EnsureEndCapsHook(module)
    end

    if Log and type(Log.Info) == "function" then
        Log:Info("ActionBars (Blizzard-button layout) loaded")
    end
    return true
end
'''
new_init = '''function Runtime.Init(module)
    if not IsReady(module) then
        return false, "ActionBars init owner unavailable"
    end

    local callbackOK, callbackDetail, callbackRegistered = EnsureActionChangedCallback(module)
    if callbackOK == false then
        return false, "ActionBars action-change callback registration failed: " .. tostring(callbackDetail)
    end

    local stateOK, stateDetail = module:EnsureStateHooks(callbackRegistered == true)
    if stateOK == false then
        return false, tostring(stateDetail or "ActionBars state hook registration failed")
    end

    if Shell and Shell.EnsureEndCapsHook then
        local endCapsOK, endCapsDetail = Shell.EnsureEndCapsHook(module)
        if endCapsOK == false then
            return false, "ActionBars end-cap hook registration failed: " .. tostring(endCapsDetail)
        end
    end

    if module._initDone then
        return true
    end

    module._initDone = true
    module._inited = true
    if Log and type(Log.Info) == "function" then
        Log:Info("ActionBars (Blizzard-button layout) loaded")
    end
    return true
end
'''
runtime = replace_once(runtime, old_init, new_init, 'Runtime.Init publication ordering')
runtime = replace_once(
    runtime,
    '''    if Runtime.Init(module) == false then
        return false
    end
''',
    '''    local initOK, initDetail = Runtime.Init(module)
    if initOK == false then
        return false, initDetail
    end
''',
    'Runtime.Attach init detail',
)
runtime = replace_once(
    runtime,
    '''    EnsureActionChangedCallback(module)

    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
''',
    '''    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
''',
    'remove late callback registration',
)
old_detach_tail = '''    if not module._eventFrame then
        module._eventsAttached = false
        return false
    end

    module._eventFrame:UnregisterAllEvents()
    module._eventFrame:SetScript("OnEvent", nil)
    if module._callbackHandles and type(module._callbackHandles.Unregister) == "function" then
        module._callbackHandles:Unregister()
    end
    module._actionChangedCallbackRegistered = nil
    module._eventsAttached = false
    module._pending = nil
    module._pendingHide = nil
    module._pendingRestore = nil
    module._pendingManagedPositionsRefresh = nil
    return true
end
'''
new_detach_tail = '''    local cleanupOK = true
    local cleanupDetail
    if module._eventFrame then
        local okEvents, eventDetail = pcall(module._eventFrame.UnregisterAllEvents, module._eventFrame)
        local okScript, scriptDetail = pcall(module._eventFrame.SetScript, module._eventFrame, "OnEvent", nil)
        if not okEvents or not okScript then
            cleanupOK = false
            cleanupDetail = tostring((not okEvents and eventDetail) or scriptDetail)
        end
    end

    if module._callbackHandles and type(module._callbackHandles.Unregister) == "function" then
        local ok, detail = pcall(module._callbackHandles.Unregister, module._callbackHandles)
        if not ok then
            cleanupOK = false
            cleanupDetail = cleanupDetail or tostring(detail)
        end
    end
    module._actionChangedCallbackRegistered = nil

    if State and type(State.ReleaseStateHookOwner) == "function" then
        State.ReleaseStateHookOwner(module)
    end
    if Shell and type(Shell.ReleaseHookOwner) == "function" then
        Shell.ReleaseHookOwner(module)
    end

    module._eventsAttached = false
    module._pending = nil
    module._pendingHide = nil
    module._pendingRestore = nil
    module._pendingManagedPositionsRefresh = nil
    if not cleanupOK then
        return false, "ActionBars detach cleanup failed: " .. tostring(cleanupDetail)
    end
    return true
end
'''
runtime = replace_once(runtime, old_detach_tail, new_detach_tail, 'Runtime.Detach hook cleanup')
runtime_path.write_text(runtime, encoding='utf-8')


# ---------------------------------------------------------------------------
# Static contracts and release documentation.
# ---------------------------------------------------------------------------
check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
contracts = r'''    assertSourceIncludes('modules/ActionBarsState.lua', 'State._secureHookRegistry');
    assertSourceIncludes('modules/ActionBarsState.lua', 'State.ReleaseStateHookOwner');
    assertSourceIncludes('modules/ActionBarsState.lua', 'GlobalHookState.owner = module');
    assertSourceIncludes('modules/ActionBarsBlizzardShell.lua', 'Shell._secureHookRegistry');
    assertSourceIncludes('modules/ActionBarsBlizzardShell.lua', 'Shell._scriptHookRegistry');
    assertSourceIncludes('modules/ActionBarsBlizzardShell.lua', 'Shell.ReleaseHookOwner');
    assertSourceIncludes('modules/ActionBarsRuntime.lua', 'local registeredOK, registeredDetail = pcall');
    assertSourceIncludes('modules/ActionBarsRuntime.lua', 'local initOK, initDetail = Runtime.Init(module)');
    assertSourceExcludes('modules/ActionBarsState.lua', /_stateHooksAttached/, 'pre-published ActionBars global-hook summary');
    assertSourceExcludes('modules/ActionBarsBlizzardShell.lua', /_endCapsHooked|_settingsPanelHooked|_settingsTransitionHooked|_settingsShellRepair/, 'module-local ActionBars shell hook metadata');
    assertSourceExcludes('modules/ActionBarsRuntime.lua', /_actionChangedCallbackRegistered\s*=\s*true\s*\n\s*module\._callbackHandles:RegisterCallback/, 'pre-published ActionBars callback registration');
    assertSourceExcludes('modules/ActionBarsRuntime.lua', /module\._initDone\s*=\s*true[\s\S]{0,120}EnsureStateHooks/, 'pre-published ActionBars initialization');

'''
check = replace_once(
    check,
    "    assertSourceIncludes('modules/ActionBarsState.lua', 'State._holderRegistry');\n",
    "    assertSourceIncludes('modules/ActionBarsState.lua', 'State._holderRegistry');\n" + contracts,
    'ActionBars global hook static contracts',
)
check_path.write_text(check, encoding='utf-8')

# Release metadata.
toc_path = Path('FeelsGoodUI.toc')
toc = toc_path.read_text(encoding='utf-8')
toc = replace_once(toc, '## Version: 0.0.66', '## Version: 0.0.67', 'TOC version')
toc_path.write_text(toc, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(readme, '- FeelsGoodUI `0.0.66`', '- FeelsGoodUI `0.0.67`', 'README version')
readme = replace_once(
    readme,
    'ActionBars holder/button auto-hide and state-layer hooks are result-bearing:',
    'ActionBars permanent secure, SettingsPanel, action-change, holder/button auto-hide, and state-layer hooks are result-bearing and replacement-safe: target/method edges live in weak registries, init/callback summaries publish only after successful registration, callbacks resolve the current active owner, detach releases owners and unregisters callback handles, and retry installs only missing edges. Holder/button hooks remain result-bearing:',
    'README ActionBars global hook policy',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    '`ActionBarsState` keeps button/holder state and per-edge hook completion in weak registries; callbacks resolve current ownership and hook failures propagate through `ActionBarsVisuals`/`ActionBarsRuntime`.',
    '`ActionBarsState` keeps button/holder state plus permanent target/method hook completion in weak registries; `ActionBarsBlizzardShell` does the same for EndCaps and Settings hooks; callbacks resolve current ownership and every registration failure propagates through `ActionBarsRuntime` before `_initDone` or callback summaries publish.',
    'AGENT_GUIDE ActionBars global hooks',
)
agent = replace_once(
    agent,
    'Per-button/holder hooks are independent result-bearing edges: never publish a summary flag before every required edge succeeds, and never capture a stale module in a permanent callback.',
    'Permanent secure/script/callback and per-button/holder hooks are independent result-bearing edges: never publish a summary flag before registration succeeds, key permanent hooks by target+method/event, resolve the current owner at dispatch, and release owner references on detach.',
    'AGENT_GUIDE ActionBars global hook invariant',
)
agent_path.write_text(agent, encoding='utf-8')

index_path = Path('CODE_INDEX.md')
index = index_path.read_text(encoding='utf-8')
index = replace_once(
    index,
    '| `modules/ActionBarsBlizzardShell.lua` | Reversible Blizzard shell/native-toggle takeover, per-character recovery across reload/interruption, exact detach restore, and managed-position synchronization. |',
    '| `modules/ActionBarsBlizzardShell.lua` | Reversible Blizzard shell/native-toggle takeover, weak target/method Settings/EndCaps hook ownership, per-character recovery across reload/interruption, exact detach restore, and managed-position synchronization. |',
    'CODE_INDEX shell hooks',
)
index = replace_once(
    index,
    '| `modules/ActionBars.lua`, `modules/ActionBarsRuntime.lua`, `modules/ActionBarsEditMode.lua` | Secure holders, event/lifecycle coordination, and mover integration without direct profile mutation. |',
    '| `modules/ActionBars.lua`, `modules/ActionBarsRuntime.lua`, `modules/ActionBarsEditMode.lua` | Secure holders, result-bearing global-hook/callback initialization and detach cleanup, event/lifecycle coordination, and mover integration without direct profile mutation. |',
    'CODE_INDEX runtime hooks',
)
index_path.write_text(index, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(todo, '- [x] Target Interface `120105` and release `0.0.66`.', '- [x] Target Interface `120105` and release `0.0.67`.', 'TODO version')
todo = replace_once(
    todo,
    '- [x] Make ActionBars holder/button auto-hide and state-layer hooks result-bearing: weak registries own state, callbacks resolve current owners, partial failures retry only missing edges, and visual/apply callers propagate failure.\n',
    '- [x] Make ActionBars holder/button auto-hide and state-layer hooks result-bearing: weak registries own state, callbacks resolve current owners, partial failures retry only missing edges, and visual/apply callers propagate failure.\n- [x] Make ActionBars permanent state, EndCaps, SettingsPanel and action-change hooks result-bearing: weak target/method registries prevent duplicates, init/callback flags publish after success, owner replacement is dynamic, and detach releases owners/handles.\n',
    'TODO ActionBars global hooks',
)
todo = replace_once(
    todo,
    '- [ ] Rapid `Disable -> Enable` before queued callbacks fire does not execute an older lifecycle generation.\n',
    '- [ ] Rapid `Disable -> Enable` before queued callbacks fire does not execute an older lifecycle generation.\n- [ ] Inject one failure into each permanent ActionBars `hooksecurefunc`, SettingsPanel `HookScript`, callback-container creation/registration, and detach `Unregister`; successful edges remain single, only missing edges retry, `_initDone`/callback flags never publish early, callbacks follow the current owner, and detach releases owner references.\n',
    'TODO global hook validation',
)
todo_path.write_text(todo, encoding='utf-8')

matrix_path = Path('docs/REGRESSION_MATRIX_1_25.md')
matrix = matrix_path.read_text(encoding='utf-8')
anchor = '| 21 | Disable/re-enable action bars and reload after setting a distinctive native multi-bar toggle vector | Exact pre-attach Blizzard toggles and shell state restore after reload or detach; recovery marker clears after restore; addon profile bars do not change; no detached delayed callback re-enters |  |  |'
replacement = anchor + '\n| 21a | Inject failures into ActionBars permanent secure/script/callback registration, retry, detach, replace owner/targets, and fire old callbacks | Init/callback flags publish only after success; target/method edges stay single; only missing edges retry; current owner handles callbacks; detach releases owner/handles and reports cleanup failure |  |  |'
matrix = replace_once(matrix, anchor, replacement, 'regression matrix global hooks')
matrix_path.write_text(matrix, encoding='utf-8')

print('Made ActionBars permanent hooks and callback lifecycle result-bearing.')
