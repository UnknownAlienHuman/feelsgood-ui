from pathlib import Path

path = Path('.codex/harden_experience_event_lifecycle.py')
text = path.read_text(encoding='utf-8')

old = '''check = replace_once(
    check,
    "    assertSourceIncludes('modules/ExperienceBar.lua', 'function XP:ApplyConfig()');\\n",
    "    assertSourceIncludes('modules/ExperienceBar.lua', 'function XP:ApplyConfig()');\\n" + contracts,
    'ExperienceBar event lifecycle static contracts',
)
'''
new = '''check = replace_once(
    check,
    "    assertSourceIncludes('modules/ExperienceBar.lua', 'SuppressBlizzardStatusTracking');\\n",
    "    assertSourceIncludes('modules/ExperienceBar.lua', 'SuppressBlizzardStatusTracking');\\n" + contracts,
    'ExperienceBar event lifecycle static contracts',
)
'''
count = text.count(old)
if count != 1:
    raise RuntimeError(f'ExperienceBar checker transform block: expected one, found {count}')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
print('Rebased ExperienceBar event transform onto current checker.')
