from pathlib import Path

path = Path('.codex/test_companion_pet_preview.lua')
text = path.read_text(encoding='utf-8')
replacements = {
    '    ClampButtonSize = function(value)\n': '    ClampButtonSize = function(_, value)\n',
    '    ClampSpacing = function(value)\n': '    ClampSpacing = function(_, value)\n',
}
for old, new in replacements.items():
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'fixture anchor {old.strip()!r}: expected 1, found {count}')
    text = text.replace(old, new, 1)
path.write_text(text, encoding='utf-8')
print('Fixed Companion preview colon-method fixture.')
