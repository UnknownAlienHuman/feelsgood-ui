from pathlib import Path

transform_path = Path('.codex/harden_unitframes_observer_atomicity.py')
transform = transform_path.read_text(encoding='utf-8')
old = '    local frames = setmetatable({}, { __mode = "k" })\n'
new = '    local frames = {}\n'
count = transform.count(old)
if count != 1:
    raise RuntimeError(f'UnitFrames detach frame set anchor: expected one, found {count}')
transform_path.write_text(transform.replace(old, new, 1), encoding='utf-8')

test_path = Path('.codex/test_unitframes_observer_atomicity.lua')
test = test_path.read_text(encoding='utf-8')
old = '    assertEqual(#Target._frameRegistry[oldTarget].retiredObservers, 0, "retired observer cleanup retried")\n'
new = '    assertEqual(Target._frameRegistry[oldTarget].retiredObservers, nil, "retired observer cleanup retried")\n'
count = test.count(old)
if count != 1:
    raise RuntimeError(f'UnitFrames retired observer assertion anchor: expected one, found {count}')
test_path.write_text(test.replace(old, new, 1), encoding='utf-8')

print('Fixed UnitFrames observer transform and harness fixtures.')
