from pathlib import Path
import runpy

runpy.run_path('.codex/harden_actionbars_native_state.py', run_name='__main__')

path = Path('modules/ActionBarsBlizzardShell.lua')
text = path.read_text(encoding='utf-8')
old_right = '        hideBlizzard and false or IsBarEnabled(4),\n'
old_left = '        hideBlizzard and false or IsBarEnabled(5),\n'
if text.count(old_right) != 1 or text.count(old_left) != 1:
    raise RuntimeError('expected legacy Lua ternary expressions after base transform')
text = text.replace(old_right, '        (not hideBlizzard) and IsBarEnabled(4),\n', 1)
text = text.replace(old_left, '        (not hideBlizzard) and IsBarEnabled(5),\n', 1)
path.write_text(text, encoding='utf-8')

print('Corrected hideBlizzard boolean expressions.')
