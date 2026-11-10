from pathlib import Path

transform_path = Path('.codex/harden_unitframes_observer_atomicity.py')
transform = transform_path.read_text(encoding='utf-8')

old = '    local frames = setmetatable({}, { __mode = "k" })\n'
new = '    local frames = {}\n'
count = transform.count(old)
if count != 1:
    raise RuntimeError(f'UnitFrames detach frame set anchor: expected one, found {count}')
transform = transform.replace(old, new, 1)

old_readme = '''readme = replace_once(
    readme,
    'Unit-frame runtime state is also registry-owned: target/focus/targettarget observers, aura roles, header-hook state, low-health cache and `RegisterUnitWatch` ownership are kept off oUF frames/elements; target-aura reads do not repair SavedVariables, native watch failures propagate, and frame replacement reconciles through the current owner.',
    'Unit-frame runtime state is also registry-owned: target/focus/targettarget observers, aura roles, header-hook state, low-health cache and `RegisterUnitWatch` ownership are kept off oUF frames/elements. Observer replacement prepares every new subscription before owner publication, rolls back a failed multi-frame prepare without dropping prior observers, gates stale callbacks by exact observer identity, retains failed cleanup for retry, propagates detach failures, and target-aura reads never repair SavedVariables.',
    'README UnitFrames observer atomicity',
)
'''
new_readme = '''readme = replace_once(
    readme,
    'oUF frame, aura-container, observer-hook, low-health, and unit-watch state stays in addon-owned weak registries; native watch failures propagate instead of publishing a false attached state.',
    'oUF frame, aura-container, observer-hook, low-health, and unit-watch state stays in addon-owned weak registries. Observer replacement prepares every new subscription before owner publication, rolls back failed multi-frame preparation without dropping prior observers, gates stale callbacks by exact observer identity, retains failed cleanup for retry, and propagates detach failures instead of publishing a false attached state.',
    'README UnitFrames observer atomicity',
)
'''
count = transform.count(old_readme)
if count != 1:
    raise RuntimeError(f'UnitFrames README transform block: expected one, found {count}')
transform = transform.replace(old_readme, new_readme, 1)
transform_path.write_text(transform, encoding='utf-8')

test_path = Path('.codex/test_unitframes_observer_atomicity.lua')
test = test_path.read_text(encoding='utf-8')
old = '    assertEqual(#Target._frameRegistry[oldTarget].retiredObservers, 0, "retired observer cleanup retried")\n'
new = '    assertEqual(Target._frameRegistry[oldTarget].retiredObservers, nil, "retired observer cleanup retried")\n'
count = test.count(old)
if count != 1:
    raise RuntimeError(f'UnitFrames retired observer assertion anchor: expected one, found {count}')
test_path.write_text(test.replace(old, new, 1), encoding='utf-8')

print('Rebased UnitFrames observer transform and harness onto current source.')
