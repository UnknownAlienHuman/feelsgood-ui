from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


state_path = Path('.codex/test_actionbars_global_state_hooks.lua')
state = state_path.read_text(encoding='utf-8')
state = replace_once(
    state,
    '''assertEqual(rawget(moduleA, "_stateHooksAttached"), nil, "state summary marker absent")

ok, detail = State.EnsureStateHooks(moduleA, false)
''',
    '''assertEqual(rawget(moduleA, "_stateHooksAttached"), nil, "state summary marker absent")
Fire(movers, "SetUnlocked", movers, true)
assertEqual(moduleA.refreshCalls, 0, "partial hooks remain inert before owner publication")

ok, detail = State.EnsureStateHooks(moduleA, false)
''',
    'state partial-owner inertness',
)
state = replace_once(
    state,
    '''assertEqual(HookCount(movers, "SetUnlocked"), 1, "Movers hook not duplicated")

ok = State.EnsureStateHooks(moduleB, false)
''',
    '''assertEqual(HookCount(movers, "SetUnlocked"), 1, "Movers hook not duplicated")
assertEqual(State.SetStateHookOwner(moduleA), true, "first state owner published")

ok = State.EnsureStateHooks(moduleB, false)
''',
    'state first owner publication',
)
state = replace_once(
    state,
    '''assertEqual(HookCount(actionMixin, "UpdateState"), 1, "owner replacement reuses UpdateState hook")
assertEqual(HookCount(movers, "SetUnlocked"), 1, "owner replacement reuses Movers hook")
Fire(movers, "SetUnlocked", movers, true)
''',
    '''assertEqual(HookCount(actionMixin, "UpdateState"), 1, "owner replacement reuses UpdateState hook")
assertEqual(HookCount(movers, "SetUnlocked"), 1, "owner replacement reuses Movers hook")
assertEqual(State.SetStateHookOwner(moduleB), true, "replacement state owner published")
Fire(movers, "SetUnlocked", movers, true)
''',
    'state replacement owner publication',
)
state = replace_once(
    state,
    '''assertEqual(State.EnsureStateHooks(moduleA, false), true, "replacement target registration")
assertEqual(HookCount(replacementSpellManager, "ShowAlert"), 1, "replacement ShowAlert registered")
''',
    '''assertEqual(State.EnsureStateHooks(moduleA, false), true, "replacement target registration")
assertEqual(State.SetStateHookOwner(moduleA), true, "replacement target owner published")
assertEqual(HookCount(replacementSpellManager, "ShowAlert"), 1, "replacement ShowAlert registered")
''',
    'state replacement target owner publication',
)
state_path.write_text(state, encoding='utf-8')


shell_path = Path('.codex/test_actionbars_shell_hooks.lua')
shell = shell_path.read_text(encoding='utf-8')
shell = replace_once(
    shell,
    '''assertEqual(settingsPanel.attempts.OnHide, 2, "panel failure retried once")
assertEqual(SecureAttemptCount(settingsMixin, "TransitionBackOpeningPanel"), 2, "mixin failure retried once")

assertEqual(Shell.EnsureEndCapsHook(moduleB), true, "EndCaps owner replacement succeeds")
''',
    '''assertEqual(settingsPanel.attempts.OnHide, 2, "panel failure retried once")
assertEqual(SecureAttemptCount(settingsMixin, "TransitionBackOpeningPanel"), 2, "mixin failure retried once")
FireSecure(endCapsMixin, "UpdateEndCaps", endCapsMixin)
FireScript(settingsPanel, "OnHide")
assertEqual(#kicks, 0, "installed shell hooks remain inert before owner publication")
assertEqual(moduleA.applyCalls, 0, "installed settings hooks remain inert before owner publication")

assertEqual(Shell.EnsureEndCapsHook(moduleB), true, "EndCaps owner replacement succeeds")
''',
    'shell pre-owner inertness',
)
shell = replace_once(
    shell,
    '''assertEqual(SecureCount(settingsMixin, "TransitionBackOpeningPanel"), 1, "settings mixin hook not duplicated")

FireSecure(endCapsMixin, "UpdateEndCaps", endCapsMixin)
''',
    '''assertEqual(SecureCount(settingsMixin, "TransitionBackOpeningPanel"), 1, "settings mixin hook not duplicated")
assertEqual(Shell.SetHookOwner(moduleB), true, "shell owner published after complete registration")

FireSecure(endCapsMixin, "UpdateEndCaps", endCapsMixin)
''',
    'shell owner publication',
)
shell = replace_once(
    shell,
    '''assertEqual(Shell.EnsureSettingsHooks(moduleA), true, "replacement panel registration succeeds")
assertEqual(ScriptCount(replacementPanel, "OnHide"), 1, "replacement panel hooked")
''',
    '''assertEqual(Shell.EnsureSettingsHooks(moduleA), true, "replacement panel registration succeeds")
assertEqual(Shell.SetHookOwner(moduleA), true, "replacement panel owner published")
assertEqual(ScriptCount(replacementPanel, "OnHide"), 1, "replacement panel hooked")
''',
    'shell replacement owner publication',
)
shell_path.write_text(shell, encoding='utf-8')


runtime_path = Path('.codex/test_actionbars_runtime_hook_lifecycle.lua')
runtime = runtime_path.read_text(encoding='utf-8')
runtime = replace_once(
    runtime,
    '''local stateReleaseCalls = 0
local resetCalls = 0
local shellReleaseCalls = 0
''',
    '''local stateReleaseCalls = 0
local stateOwnerSetCalls = 0
local resetCalls = 0
local shellReleaseCalls = 0
local shellOwnerSetCalls = 0
''',
    'runtime owner counters',
)
runtime = replace_once(
    runtime,
    '''        ReleaseStateHookOwner = function() stateReleaseCalls = stateReleaseCalls + 1; return true end,
        UpdateButtonChecked = function() end,
''',
    '''        SetStateHookOwner = function() stateOwnerSetCalls = stateOwnerSetCalls + 1; return true end,
        ReleaseStateHookOwner = function() stateReleaseCalls = stateReleaseCalls + 1; return true end,
        UpdateButtonChecked = function() end,
''',
    'runtime state owner stub',
)
runtime = replace_once(
    runtime,
    '''        ReleaseHookOwner = function() shellReleaseCalls = shellReleaseCalls + 1; return true end,
    },
''',
    '''        SetHookOwner = function() shellOwnerSetCalls = shellOwnerSetCalls + 1; return true end,
        ReleaseHookOwner = function() shellReleaseCalls = shellReleaseCalls + 1; return true end,
    },
''',
    'runtime shell owner stub',
)
runtime = replace_once(
    runtime,
    '''assertEqual(module._actionChangedCallbackRegistered, true, "callback flag published after success")
assertEqual(module._initDone, nil, "init flag absent after state failure")
assertEqual(module.stateCallbackFlags[#module.stateCallbackFlags], true, "state hooks know callback is registered")

stateFailure = nil
''',
    '''assertEqual(module._actionChangedCallbackRegistered, true, "callback flag published after success")
assertEqual(module._initDone, nil, "init flag absent after state failure")
assertEqual(module.stateCallbackFlags[#module.stateCallbackFlags], true, "state hooks know callback is registered")
container.callback(nil, {})
assertEqual(visualCalls, 0, "registered callback remains inert before full init publishes owner")
assertEqual(stateOwnerSetCalls, 0, "state owner unpublished after state failure")
assertEqual(shellOwnerSetCalls, 0, "shell owner unpublished after state failure")

stateFailure = nil
''',
    'runtime callback inertness before init',
)
runtime = replace_once(
    runtime,
    '''assertEqual(module._initDone, nil, "init flag absent after EndCaps failure")

endCapsFailure = nil
''',
    '''assertEqual(module._initDone, nil, "init flag absent after EndCaps failure")
assertEqual(stateOwnerSetCalls, 0, "state owner unpublished after EndCaps failure")
assertEqual(shellOwnerSetCalls, 0, "shell owner unpublished after EndCaps failure")

endCapsFailure = nil
''',
    'runtime owner inertness after EndCaps failure',
)
runtime = replace_once(
    runtime,
    '''assertEqual(module._inited, true, "legacy inited flag published after success")
assertEqual(container.registerCalls, 2, "callback registration attempted once after initial failure")
''',
    '''assertEqual(module._inited, true, "legacy inited flag published after success")
assertEqual(stateOwnerSetCalls, 1, "state owner published after full init")
assertEqual(shellOwnerSetCalls, 1, "shell owner published after full init")
assertEqual(Runtime._callbackOwner, module, "callback owner published after full init")
assertEqual(container.registerCalls, 2, "callback registration attempted once after initial failure")
''',
    'runtime successful owner publication',
)
runtime = replace_once(
    runtime,
    '''assertEqual(module._actionChangedCallbackRegistered, nil, "callback flag cleared on failed detach")
assertEqual(stateReleaseCalls, 1, "state owner released on failed detach")
''',
    '''assertEqual(module._actionChangedCallbackRegistered, nil, "callback flag cleared on failed detach")
assertEqual(Runtime._callbackOwner, nil, "callback owner released on failed detach")
assertEqual(stateReleaseCalls, 1, "state owner released on failed detach")
''',
    'runtime callback owner release',
)
runtime_path.write_text(runtime, encoding='utf-8')

print('Aligned global-hook fixtures with post-success active-owner publication.')
