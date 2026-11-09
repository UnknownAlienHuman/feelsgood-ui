from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


path = Path('.codex/test_actionbars_runtime_hook_lifecycle.lua')
text = path.read_text(encoding='utf-8')

old_container = '''local createFailures = 1
local container = {
    registerCalls = 0,
    unregisterCalls = 0,
    registerFailures = 1,
    unregisterFailures = 0,
    callback = nil,
}
function container:RegisterCallback(_, _, callback)
    self.registerCalls = self.registerCalls + 1
    if self.registerFailures > 0 then
        self.registerFailures = self.registerFailures - 1
        error("injected callback registration failure")
    end
    self.callback = callback
end
function container:Unregister()
    self.unregisterCalls = self.unregisterCalls + 1
    if self.unregisterFailures > 0 then
        self.unregisterFailures = self.unregisterFailures - 1
        error("injected callback unregister failure")
    end
    self.callback = nil
end

_G.EventUtil = {
    CreateCallbackHandleContainer = function()
        if createFailures > 0 then
            createFailures = createFailures - 1
            error("injected callback container failure")
        end
        return container
    end,
}
'''
new_container = '''local createFailures = 1
local containers = {}
local container
local totalRegisterCalls = 0
local totalUnregisterCalls = 0
local nextRegisterFailures = 1
local nextUnregisterFailures = 0

local function NewContainer()
    local value = {
        registerCalls = 0,
        unregisterCalls = 0,
        registerFailures = nextRegisterFailures,
        unregisterFailures = nextUnregisterFailures,
        callback = nil,
    }
    nextRegisterFailures = 0
    nextUnregisterFailures = 0

    function value:RegisterCallback(_, _, callback)
        self.registerCalls = self.registerCalls + 1
        totalRegisterCalls = totalRegisterCalls + 1
        if self.registerFailures > 0 then
            self.registerFailures = self.registerFailures - 1
            error("injected callback registration failure")
        end
        self.callback = callback
    end

    function value:Unregister()
        self.unregisterCalls = self.unregisterCalls + 1
        totalUnregisterCalls = totalUnregisterCalls + 1
        if self.unregisterFailures > 0 then
            self.unregisterFailures = self.unregisterFailures - 1
            error("injected callback unregister failure")
        end
        self.callback = nil
    end

    containers[#containers + 1] = value
    container = value
    return value
end

_G.EventUtil = {
    CreateCallbackHandleContainer = function()
        if createFailures > 0 then
            createFailures = createFailures - 1
            error("injected callback container failure")
        end
        return NewContainer()
    end,
}
'''
text = replace_once(text, old_container, new_container, 'callback container factory')
text = replace_once(
    text,
    'assertEqual(container.registerCalls, 2, "callback registration attempted once after initial failure")',
    'assertEqual(totalRegisterCalls, 2, "callback registration attempted once after initial failure")',
    'total callback registration count',
)
text = replace_once(
    text,
    'assertEqual(container.registerCalls, 2, "repeated init does not duplicate callback")',
    'assertEqual(totalRegisterCalls, 2, "repeated init does not duplicate callback")',
    'repeated callback registration count',
)
text = replace_once(
    text,
    '''container.unregisterFailures = 1
ok, detail = Runtime.Detach(module)
''',
    '''local staleContainer = container
container.unregisterFailures = 1
ok, detail = Runtime.Detach(module)
''',
    'capture stale callback container',
)
text = replace_once(
    text,
    '''assertEqual(module._actionChangedCallbackRegistered, nil, "callback flag cleared on failed detach")
assertEqual(Runtime._callbackOwner, nil, "callback owner released on failed detach")
''',
    '''assertEqual(module._actionChangedCallbackRegistered, nil, "callback flag cleared on failed detach")
assertEqual(module._actionChangedCallbackRecord, nil, "callback record cleared on failed detach")
assertEqual(module._callbackHandles, nil, "callback handles released on failed detach")
assertEqual(Runtime._callbackOwner, nil, "callback owner released on failed detach")
assertEqual(Runtime._callbackRecord, nil, "active callback record released on failed detach")
''',
    'failed detach callback record cleanup',
)
text = replace_once(
    text,
    '''container.registerFailures = 1
ok, detail = Runtime.Attach(module)
''',
    '''nextRegisterFailures = 1
ok, detail = Runtime.Attach(module)
''',
    'new-container registration failure',
)
text = replace_once(
    text,
    '''assertEqual(module._actionChangedCallbackRegistered, true, "callback flag republished after retry")
assertEqual(module._eventsAttached, true, "events published after attach")
''',
    '''assertEqual(module._actionChangedCallbackRegistered, true, "callback flag republished after retry")
assertEqual(type(module._actionChangedCallbackRecord), "table", "callback record republished after retry")
assertEqual(Runtime._callbackRecord, module._actionChangedCallbackRecord, "current callback record published")
assertEqual(module._eventsAttached, true, "events published after attach")
local visualBeforeStale = visualCalls
staleContainer.callback(nil, {})
assertEqual(visualCalls, visualBeforeStale, "stale callback remains inert after failed unregister")
container.callback(nil, {})
assertEqual(visualCalls, visualBeforeStale + 1, "new callback dispatches exactly once")
''',
    'stale callback invalidation proof',
)
text = replace_once(
    text,
    '''assertEqual(module._actionChangedCallbackRegistered, nil, "final detach clears callback flag")
assertEqual(module._eventsAttached, false, "final detach clears events")
''',
    '''assertEqual(module._actionChangedCallbackRegistered, nil, "final detach clears callback flag")
assertEqual(module._actionChangedCallbackRecord, nil, "final detach clears callback record")
assertEqual(Runtime._callbackRecord, nil, "final detach clears active callback record")
assertEqual(module._eventsAttached, false, "final detach clears events")
''',
    'final callback record cleanup',
)

path.write_text(text, encoding='utf-8')
print('Extended callback lifecycle fixture for stale-handle invalidation.')
