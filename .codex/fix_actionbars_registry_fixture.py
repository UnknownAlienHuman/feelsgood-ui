from pathlib import Path

path = Path('.codex/test_actionbars_state_registry.lua')
text = path.read_text(encoding='utf-8')
old = '''-- Permanent hover hooks resolve the current owner/layer from the registry.
record.layers.highlight:Hide()
button.hooks.OnEnter[1](button)
assertEqual(record.layers.highlight.shown, true, "highlight shown while attached")
button.hooks.OnLeave[1](button)
assertEqual(record.layers.highlight.shown, false, "highlight hidden on leave")
module._detached = true
button.hooks.OnEnter[1](button)
assertEqual(record.layers.highlight.shown, false, "detached highlight hook inert")
module._detached = nil
'''
new = '''local function FireHooks(name)
    for i = 1, #(button.hooks[name] or {}) do
        button.hooks[name][i](button)
    end
end

-- Permanent hover hooks resolve the current owner/layer from the registry.
-- Hook order is intentionally irrelevant: Blizzard and addon integrations may
-- register independent permanent hooks in either order.
record.layers.highlight:Hide()
FireHooks("OnEnter")
assertEqual(record.layers.highlight.shown, true, "highlight shown while attached")
FireHooks("OnLeave")
assertEqual(record.layers.highlight.shown, false, "highlight hidden on leave")
module._detached = true
FireHooks("OnEnter")
assertEqual(record.layers.highlight.shown, false, "detached highlight hook inert")
module._detached = nil
'''
count = text.count(old)
if count != 1:
    raise RuntimeError(f'hook-order fixture anchor: expected 1, found {count}')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
print('Fixed ActionBars hook-order fixture.')
