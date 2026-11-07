from pathlib import Path
import runpy

source_path = Path('.codex/harden_generic_state_registries.py')
source = source_path.read_text(encoding='utf-8')

# The source has one creating read in PlayFade and one non-creating read in
# CancelFade. Patch the transform itself to address them by function context
# instead of a broad one-line anchor that appears twice.
old_frame_transform = '''animate = replace_once(
    animate,
    '    local state = GetFrameState(frame)\\n',
    '    local state = GetFrameState(frame, true)\\n',
    'Animate fade state creation',
)
'''
new_frame_transform = '''animate = replace_once(
    animate,
    '''local function PlayFade(frame, key, duration, fromAlpha, toAlpha, hideOnFinished, showOnStart)
    if not IsAnimFrame(frame) then
        return false
    end

    local state = GetFrameState(frame)
    local oppositeKey = (key == "fadeIn") and "fadeOut" or "fadeIn"
''',
    '''local function PlayFade(frame, key, duration, fromAlpha, toAlpha, hideOnFinished, showOnStart)
    if not IsAnimFrame(frame) then
        return false
    end

    local state = GetFrameState(frame, true)
    local oppositeKey = (key == "fadeIn") and "fadeOut" or "fadeIn"
''',
    'Animate fade state creation',
)
'''
count = source.count(old_frame_transform)
if count != 1:
    raise RuntimeError(f'Animate transform adapter anchor: expected 1, found {count}')
source = source.replace(old_frame_transform, new_frame_transform, 1)

old_readme = '''readme = replace_once(
    readme,
    'Minimap drag uses a detached LibDBIcon runtime proxy:',
    'Shared animation fades and keyed timers keep state in weak-key registries rather than arbitrary frame/owner fields; the dead generic cooldown cache helper is removed. Minimap drag uses a detached LibDBIcon runtime proxy and a weak-key hook registry on the addon side:',
    'README generic state policy',
)
'''
new_readme = '''marker = 'Minimap drag uses'
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
count = source.count(old_readme)
if count != 1:
    raise RuntimeError(f'README transform adapter anchor: expected 1, found {count}')
source = source.replace(old_readme, new_readme, 1)

temp = Path('.codex/.harden_generic_state_registries.runtime.py')
temp.write_text(source, encoding='utf-8')
runpy.run_path(str(temp), run_name='__main__')
