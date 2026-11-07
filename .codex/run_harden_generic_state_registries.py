from pathlib import Path
import runpy

source_path = Path('.codex/harden_generic_state_registries.py')
source = source_path.read_text(encoding='utf-8')
old = '''readme = replace_once(
    readme,
    'Minimap drag uses a detached LibDBIcon runtime proxy:',
    'Shared animation fades and keyed timers keep state in weak-key registries rather than arbitrary frame/owner fields; the dead generic cooldown cache helper is removed. Minimap drag uses a detached LibDBIcon runtime proxy and a weak-key hook registry on the addon side:',
    'README generic state policy',
)
'''
new = '''marker = 'Minimap drag uses'
position = readme.find(marker)
if position < 0:
    raise RuntimeError('README generic state policy: marker not found')
prefix = (
    'Shared animation fades and keyed timers keep state in weak-key registries '
    'rather than arbitrary frame/owner fields; the dead generic cooldown cache '
    'helper is removed. '
)
readme = readme[:position] + prefix + readme[position:]
proxy_anchor = 'Minimap drag uses a detached LibDBIcon runtime proxy:'
if proxy_anchor not in readme:
    raise RuntimeError('README generic state policy: proxy anchor not found')
readme = readme.replace(
    proxy_anchor,
    'Minimap drag uses a detached LibDBIcon runtime proxy and a weak-key hook registry on the addon side:',
    1,
)
'''
count = source.count(old)
if count != 1:
    raise RuntimeError(f'README transform adapter anchor: expected 1, found {count}')
source = source.replace(old, new, 1)

temp = Path('.codex/.harden_generic_state_registries.runtime.py')
temp.write_text(source, encoding='utf-8')
runpy.run_path(str(temp), run_name='__main__')
