from pathlib import Path
import runpy

source_path = Path('.codex/harden_companion_pet_state.py')
source = source_path.read_text(encoding='utf-8')
old = '    if type(record.managedAlpha) ~= "number" then\n'
new = '    if type(record.managedAlpha) ~= "number" or not NumberEqual(record.managedAlpha, 0) then\n'
if source.count(old) != 1:
    raise RuntimeError(f'native alpha verification anchor: {source.count(old)}')
source = source.replace(old, new, 1)

temp = Path('.codex/.harden_companion_pet_state.runtime.py')
temp.write_text(source, encoding='utf-8')
runpy.run_path(str(temp), run_name='__main__')
