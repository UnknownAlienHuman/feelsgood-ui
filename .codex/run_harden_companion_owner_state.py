from pathlib import Path
import runpy

source_path = Path('.codex/harden_companion_owner_state.py')
source = source_path.read_text(encoding='utf-8')
old = '''if micro.count(queued_anchor) != 2:
    raise RuntimeError(f'micro retry anchors: expected 2, found {micro.count(queued_anchor)}')
'''
new = '''if micro.count(queued_anchor) != 3:
    raise RuntimeError(f'micro retry anchors: expected 3, found {micro.count(queued_anchor)}')
'''
if source.count(old) != 1:
    raise RuntimeError(f'companion retry-count adapter anchor: {source.count(old)}')
source = source.replace(old, new, 1)

temp = Path('.codex/.harden_companion_owner_state.runtime.py')
temp.write_text(source, encoding='utf-8')
runpy.run_path(str(temp), run_name='__main__')
