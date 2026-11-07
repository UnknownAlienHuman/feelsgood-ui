from pathlib import Path
import runpy

source_path = Path('.codex/harden_unitframes_config_purity.py')
source = source_path.read_text(encoding='utf-8')
start = source.index("check = replace_once(\n    check,\n", source.index("check_path = Path('check_lua.js')"))
end = source.index("check_path.write_text(check, encoding='utf-8')", start)
replacement = '''check = replace_once(
    check,
    "    for (const name of [\\n",
    "    assertSourceExcludes('modules/UnitFramesPolicy.lua', /profile\\\\s*\\\\[\\\\s*section\\\\s*\\\\]\\\\s*=/, 'runtime UnitFrames section creation');\\n"
    "    assertSourceExcludes('modules/UnitFramesPolicy.lua', /function\\\\s+Policy\\\\.NormalizeUF/, 'runtime UnitFrames normalizer owner');\\n"
    "    assertSourceExcludes('modules/UnitFramesRuntime.lua', /NormalizeUF/, 'runtime UnitFrames profile normalization call');\\n"
    "    assertSourceExcludes('modules/UnitFramesRender.lua', /NormalizeUF/, 'render-time UnitFrames profile normalization call');\\n"
    "    assertSourceIncludes('modules/UnitFramesPolicy.lua', 'local EMPTY = {}');\\n\\n"
    "    for (const name of [\\n",
    'UnitFrames config-purity contracts',
)
'''
patched = source[:start] + replacement + source[end:]
temp = Path('.codex/.harden_unitframes_config_purity.runtime.py')
temp.write_text(patched, encoding='utf-8')
runpy.run_path(str(temp), run_name='__main__')
