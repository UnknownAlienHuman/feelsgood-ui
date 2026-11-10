from pathlib import Path

runtime_path = Path('modules/CenterBarsRuntime.lua')
runtime = runtime_path.read_text(encoding='utf-8')
old = 'failures[#failures + 1] = "native restore: " .. tostring(restoreDetail)'
new = 'failures[#failures + 1] = "CenterBars native restore failed: " .. tostring(restoreDetail)'
count = runtime.count(old)
if count != 2:
    raise RuntimeError(f'CenterBars native restore aggregation anchors: expected 2, found {count}')
runtime_path.write_text(runtime.replace(old, new), encoding='utf-8')

test_path = Path('.codex/test_centerbars_event_lifecycle.lua')
test = test_path.read_text(encoding='utf-8')
old_expected = 'native restore: forced native restore failure'
new_expected = 'CenterBars native restore failed: forced native restore failure'
count = test.count(old_expected)
if count != 2:
    raise RuntimeError(f'CenterBars native restore fixture anchors: expected 2, found {count}')
test_path.write_text(test.replace(old_expected, new_expected), encoding='utf-8')

print('Preserved CenterBars native restore diagnostics while aggregating event cleanup.')
