from pathlib import Path

path = Path('.codex/harden_options_hook_registries.py')
text = path.read_text(encoding='utf-8')

replacements = {
'''        previous.active = false
        local previousOwner = adaptiveOwnerRegistry[previous.owner]
        if previousOwner then previousOwner.widgets[widget] = nil end
        previous = nil
''':
'''        previous.active = false
        local previousOwner = adaptiveOwnerRegistry[previous.owner]
        if previousOwner then previousOwner.widgets[widget] = nil end
''',
'''        previous.active = false
        local previousParent = numericParentRegistry[previous.parent]
        if previousParent then previousParent.sliders[slider] = nil end
        previous = nil
''':
'''        previous.active = false
        local previousParent = numericParentRegistry[previous.parent]
        if previousParent then previousParent.sliders[slider] = nil end
''',
}

for old, new in replacements.items():
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'expected one transform anchor, found {count}: {old!r}')
    text = text.replace(old, new, 1)

path.write_text(text, encoding='utf-8')
print('Preserved installed generic hooks across owner replacement.')
