from pathlib import Path
import runpy

source_path = Path('.codex/harden_unitframes_config_purity.py')
source = source_path.read_text(encoding='utf-8')

check_start = source.index("check = replace_once(\n    check,\n", source.index("check_path = Path('check_lua.js')"))
check_end = source.index("check_path.write_text(check, encoding='utf-8')", check_start)
check_replacement = '''check = replace_once(
    check,
    "    for (const name of [\\n"
    "        'modules/ActionBarsEditMode.lua',\\n",
    "    assertSourceExcludes('modules/UnitFramesPolicy.lua', /profile\\\\s*\\\\[\\\\s*section\\\\s*\\\\]\\\\s*=/, 'runtime UnitFrames section creation');\\n"
    "    assertSourceExcludes('modules/UnitFramesPolicy.lua', /function\\\\s+Policy\\\\.NormalizeUF/, 'runtime UnitFrames normalizer owner');\\n"
    "    assertSourceExcludes('modules/UnitFramesRuntime.lua', /NormalizeUF/, 'runtime UnitFrames profile normalization call');\\n"
    "    assertSourceExcludes('modules/UnitFramesRender.lua', /NormalizeUF/, 'render-time UnitFrames profile normalization call');\\n"
    "    assertSourceIncludes('modules/UnitFramesPolicy.lua', 'local EMPTY = {}');\\n\\n"
    "    for (const name of [\\n"
    "        'modules/ActionBarsEditMode.lua',\\n",
    'UnitFrames config-purity contracts',
)
'''
patched = source[:check_start] + check_replacement + source[check_end:]

matrix_start = patched.index("matrix = replace_once(\n    matrix,\n", patched.index("matrix_path = Path('docs/REGRESSION_MATRIX_1_25.md')"))
matrix_end = patched.index("matrix_path.write_text(matrix, encoding='utf-8')", matrix_start)
matrix_replacement = '''matrix = replace_once(
    matrix,
    '| 13 | Target aura mode `MINI` and `CLASSIC` | Ownership filter, layout, and header anchoring update without stale icons |  |  |',
    '| 13 | Target aura mode `MINI` and `CLASSIC` | Ownership filter, layout, and header anchoring update without stale icons |  |  |\\n'
    '| 13a | Remove a UnitFrames section/size/scale field after DB initialization, then create and apply frames | Runtime resolves immutable defaults without recreating or mutating the missing persisted field; explicit DB/schema normalization remains the only repair owner |  |  |',
    'regression matrix UnitFrames purity',
)
'''
patched = patched[:matrix_start] + matrix_replacement + patched[matrix_end:]

temp = Path('.codex/.harden_unitframes_config_purity.runtime.py')
temp.write_text(patched, encoding='utf-8')
runpy.run_path(str(temp), run_name='__main__')
