from pathlib import Path

state_path = Path('.codex/test_actionbars_state_registry.lua')
state = state_path.read_text(encoding='utf-8')
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
count = state.count(old)
if count != 1:
    raise RuntimeError(f'hook-order fixture anchor: expected 1, found {count}')
state_path.write_text(state.replace(old, new, 1), encoding='utf-8')

visual_path = Path('.codex/test_actionbars_visual_registry.lua')
visual = visual_path.read_text(encoding='utf-8')
replacements = {
    '        ApplyFont = function(region, font, size, outline)\n':
        '        ApplyFont = function(_, region, font, size, outline)\n',
    '        ApplyIconCrop = function(region)\n':
        '        ApplyIconCrop = function(_, region)\n',
}
for old_text, new_text in replacements.items():
    count = visual.count(old_text)
    if count != 1:
        raise RuntimeError(
            f'visual colon-method fixture anchor {old_text.strip()!r}: expected 1, found {count}'
        )
    visual = visual.replace(old_text, new_text, 1)
visual_path.write_text(visual, encoding='utf-8')

print('Fixed ActionBars registry fixtures.')
