from pathlib import Path

path = Path('.codex/harden_actionbars_hook_ownership.py')
text = path.read_text(encoding='utf-8')

old = '''index = replace_once(
    index,
    "| `modules/ActionBars.lua`, `modules/ActionBarsRuntime.lua`, `modules/ActionBarsState.lua`, `modules/ActionBarsVisuals.lua`, `modules/ActionBarsEditMode.lua` | Secure holders, event/lifecycle coordination, state, visuals, and mover integration without direct profile mutation. |",
    "| `modules/ActionBars.lua`, `modules/ActionBarsRuntime.lua`, `modules/ActionBarsState.lua`, `modules/ActionBarsVisuals.lua`, `modules/ActionBarsEditMode.lua` | Secure holders, event/lifecycle coordination, weak holder/button hook ownership, result-bearing state-layer initialization, visuals, and mover integration without direct profile mutation. |",
    "CODE_INDEX ActionBars hooks",
)
'''
new = '''index = replace_once(
    index,
    "| `modules/ActionBarsState.lua`, `modules/ActionBarsVisuals.lua` | Weak-key ActionButton/region runtime registries, custom state layers, typography/cooldown caches, empty-slot and hotkey presentation. |",
    "| `modules/ActionBarsState.lua`, `modules/ActionBarsVisuals.lua` | Weak-key ActionButton/holder/region runtime registries, result-bearing custom state-layer and auto-hide hook ownership, typography/cooldown caches, empty-slot and hotkey presentation. |",
    "CODE_INDEX ActionBars hooks",
)
'''
if text.count(old) != 1:
    raise RuntimeError(f'CODE_INDEX transform block: expected one anchor, found {text.count(old)}')
text = text.replace(old, new, 1)

# Avoid Python invalid-escape warnings in the generated static-check contract.
if text.count("contracts = '''") != 1:
    raise RuntimeError('static contract string anchor not unique')
text = text.replace("contracts = '''", "contracts = r'''", 1)

path.write_text(text, encoding='utf-8')
print('Rebased ActionBars transform documentation and regex anchors.')
