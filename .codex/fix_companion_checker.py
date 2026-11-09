from pathlib import Path

path = Path('check_lua.js')
text = path.read_text(encoding='utf-8')
replacements = {
    "    assertSourceIncludes('modules/CompanionMicroBags.lua', 'module._microSourceHooks');\n":
        "    assertSourceIncludes('modules/CompanionMicroBags.lua', 'GetWeakHookRegistry(module, \"_microSourceHooks\")');\n",
    "    assertSourceIncludes('modules/CompanionMicroBags.lua', 'module._bagTextureHooks');\n":
        "    assertSourceIncludes('modules/CompanionMicroBags.lua', 'GetWeakHookRegistry(module, \"_bagTextureHooks\")');\n",
}
for old, new in replacements.items():
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'Companion checker anchor {old!r}: expected 1, found {count}')
    text = text.replace(old, new, 1)
path.write_text(text, encoding='utf-8')
print('Updated Companion hook registry static contracts.')
