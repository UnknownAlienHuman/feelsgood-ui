from pathlib import Path

path = Path('.codex/test_companion_runtime_lifecycle.lua')
text = path.read_text(encoding='utf-8')

old_reset = '''    callbackConfigs = {}
    watcherConfigs = {}
    debounceCallbacks = {}
    cancelledKeys = {}
'''
new_reset = '''    callbackConfigs = {}
    callbackHandles = {}
    watcherConfigs = {}
    watchers = {}
    debounceCallbacks = {}
    cancelledKeys = {}
'''
count = text.count(old_reset)
if count != 1:
    raise RuntimeError(f'Companion fixture reset anchor: expected one, found {count}')
text = text.replace(old_reset, new_reset, 1)

old_assert = 'assertEqual(#debounceCallbacks, 0, "failed watcher generation inert")\n'
new_assert = 'assertEqual(debounceCallbacks[Shared.APPLY_DEBOUNCE_KEY], nil, "failed watcher generation inert")\n'
count = text.count(old_assert)
if count != 1:
    raise RuntimeError(f'Companion debounce assertion anchor: expected one, found {count}')
text = text.replace(old_assert, new_assert, 1)

old_attach = 'assertEqual(module._eventsAttached, nil, "failed attach publishes no events")\n'
new_attach = 'assertEqual(module._eventsAttached, false, "failed attach remains explicitly unattached")\n'
count = text.count(old_attach)
if count != 1:
    raise RuntimeError(f'Companion failed-attach assertion anchor: expected one, found {count}')
text = text.replace(old_attach, new_attach, 1)

path.write_text(text, encoding='utf-8')
print('Tightened Companion runtime harness isolation and failed-attach assertions.')
