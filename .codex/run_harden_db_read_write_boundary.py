from pathlib import Path
import runpy

source_path = Path('.codex/harden_db_read_write_boundary.py')
source = source_path.read_text(encoding='utf-8')
start = source.index("matrix = replace_once(\n    matrix,\n", source.index("matrix_path = Path('docs/REGRESSION_MATRIX_1_25.md')"))
end = source.index("matrix_path.write_text(matrix, encoding='utf-8')", start)
replacement = '''matrix = replace_once(
    matrix,
    '| 26 | Inject one feature attach/apply failure while other families are valid | Failed feature cleans up and remains disabled; later families still enable; exact owner/error is reported |  |  |',
    '| 26 | Inject one feature attach/apply failure while other families are valid | Failed feature cleans up and remains disabled; later families still enable; exact owner/error is reported |  |  |\\n'
    '| 27 | Delete one core/feature section after DB initialization, then exercise all runtime readers and settings pages | No read path recreates SavedVariables data; explicit `EnsureSection`/Settings normalization repairs the section once |  |  |',
    'regression matrix DB boundary',
)
'''
patched = source[:start] + replacement + source[end:]
temp = Path('.codex/.harden_db_read_write_boundary.runtime.py')
temp.write_text(patched, encoding='utf-8')
runpy.run_path(str(temp), run_name='__main__')
