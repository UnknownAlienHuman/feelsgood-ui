from pathlib import Path

path = Path('.codex/test_actionbars_hook_ownership.lua')
text = path.read_text(encoding='utf-8')
old = '''Fire(button, "OnEnter")
assertEqual(buttonRecord.layers.highlight.shown, true, "state enter shows highlight")
Fire(button, "OnLeave")
'''
new = '''Fire(button, "OnEnter")
assertEqual(buttonRecord.layers.highlight.shown, true, "state enter shows highlight")
buttonRecord.layers.pressed:Show()
assertEqual(State.InitializeButton(button), true, "refresh after active layers succeeds")
assertEqual(buttonRecord.layers.highlight.shown, true, "refresh preserves active highlight")
assertEqual(buttonRecord.layers.pressed.shown, true, "refresh preserves active pressed layer")
Fire(button, "OnLeave")
'''
if text.count(old) != 1:
    raise RuntimeError(f'active-layer fixture anchor: expected one, found {text.count(old)}')
text = text.replace(old, new, 1)
path.write_text(text, encoding='utf-8')
print('Extended ActionBars hook fixture for active-layer preservation.')
