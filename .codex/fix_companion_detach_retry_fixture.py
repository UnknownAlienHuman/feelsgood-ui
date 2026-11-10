from pathlib import Path

path = Path('.codex/test_companion_detach_retry.lua')
text = path.read_text(encoding='utf-8')
old = 'local leakedWatcher = watchersCreated[1]\n'
new = 'local leakedWatcher = watchersCreated[#watchersCreated]\n'
count = text.count(old)
if count != 1:
    raise RuntimeError(f'Companion leaked-watcher fixture anchor: expected one, found {count}')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
print('Selected the exact latest failed Companion watcher record.')
