from pathlib import Path

path = Path('.codex/refine_movers_registration_atomicity.py')
text = path.read_text(encoding='utf-8')

old = '''readme = replace_once(
    readme,
    'failed replacement preserves the previous registry entry. No feature may ignore mover registration/apply results and then publish initialized state.',
    'failed replacement preserves the previous registry entry, same-frame refresh rolls back descriptor changes, stale frames cannot apply a key, and unlock presentation restores the previous state on error. Hot-path feature updates retain mover readiness instead of re-registering every event. No feature may ignore mover registration/apply results and then publish initialized state.',
    'README mover atomicity policy',
)
'''
new = '''readme = replace_once(
    readme,
    'Mover registration is replacement-safe and result-bearing: re-registering the same key updates its descriptor, replacing a frame atomically installs a new overlay and retires every old script/handle, apply reports missing/invalid stored positions, and feature `_inited`/`_created` flags publish only after registration and position apply succeed.',
    'Mover registration is replacement-safe and result-bearing: same-frame descriptor updates roll back when label or handle refresh fails, replacement prepares the new overlay before retiring the previous owner and cleans every old script/handle, stale frames cannot apply another owner’s key, apply reports missing/invalid stored positions, unlock presentation restores the previous state on error, hot-path owners retain frame-specific mover readiness, and feature `_inited`/`_created` flags publish only after registration and position apply succeed.',
    'README mover atomicity policy',
)
'''

count = text.count(old)
if count != 1:
    raise RuntimeError(f'README transform block: expected one, found {count}')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
print('Rebased mover atomicity README transform onto current source.')
