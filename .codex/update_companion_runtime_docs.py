from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one current-source anchor, found {count}")
    return text.replace(old, new, 1)


check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
contracts = r'''    assertSourceIncludes('modules/CompanionRuntime.lua', 'Runtime._nextExpandRecordID');
    assertSourceIncludes('modules/CompanionRuntime.lua', 'module._expandCallbackRecord ~= record');
    assertSourceIncludes('modules/CompanionRuntime.lua', 'local function PrepareWatcherRecord(module, events, mode)');
    assertSourceIncludes('modules/CompanionRuntime.lua', 'module._watcherRecord ~= record or record.active ~= true');
    assertSourceIncludes('modules/CompanionRuntime.lua', 'callback unregister failed');
    assertSourceIncludes('modules/CompanionRuntime.lua', 'Companion restore deferred until combat ends');
    assertSourceIncludes('modules/CompanionRuntime.lua', 'local expandRecord, expandDetail = PrepareExpandRecord(module)');
    assertSourceIncludes('modules/CompanionRuntime.lua', 'local watcherRecord, watcherDetail = PrepareWatcherRecord');
    assertSourceExcludes('modules/CompanionRuntime.lua', /module\._callbackHandles:Unregister\(\)/, 'unchecked Companion callback unregister');
    assertSourceExcludes('modules/CompanionRuntime.lua', /watcher:RegisterEvent\(/, 'unchecked Companion watcher registration');
    assertSourceExcludes('modules/CompanionRuntime.lua', /watcher:UnregisterAllEvents\(\)/, 'unchecked Companion watcher unregister');

'''
check = replace_once(
    check,
    "    assertSourceIncludes('modules/CompanionRuntime.lua', 'local callbackReady, callbackDetail = EnsureExpandChangedCallback(module)');\n",
    contracts,
    'Companion runtime static contracts',
)
check_path.write_text(check, encoding='utf-8')


toc_path = Path('FeelsGoodUI.toc')
toc = toc_path.read_text(encoding='utf-8')
toc = replace_once(toc, '## Version: 0.0.71', '## Version: 0.0.72', 'TOC version')
toc_path.write_text(toc, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(readme, '- FeelsGoodUI `0.0.71`', '- FeelsGoodUI `0.0.72`', 'README version')
readme = replace_once(
    readme,
    'Companion micro-menu/bag hook state, compact-count font strings, and summaries likewise live on the Companion owner. Micro source, reset, bag-texture, and expand callbacks publish hook state only after successful registration; weak-key records are reconciled on replacement, stale-object callbacks are inert, partial failures retry only the missing edge, and the backpack texture hook never recursively calls `UpdateTextures`. Layer apply functions return explicit results, a failed layer restores already-applied presentation before reporting failure, and transient pet-button creation is queued for an event-driven retry instead of disabling the feature.',
    'Companion callback/watcher generations, micro-menu/bag hook state, compact-count font strings, and summaries live on addon-owned records. `CompanionRuntime` prepares the EventRegistry callback and watcher frame completely before publishing either owner, invalidates exact records before unregister, retains failed callback/watcher cleanup for retry, and uses a dedicated post-combat detach watcher whose restore failure remains pending and inert until a later exact retry. Micro source, reset, bag-texture, and expand hook edges publish only after successful registration; weak-key records reconcile replacement, stale-object callbacks stay inert, and the backpack texture hook never recursively calls `UpdateTextures`. Layer apply functions return explicit results, failed cleanup is aggregated, a failed layer restores already-applied presentation before reporting failure, and transient pet-button creation is queued instead of disabling the feature.',
    'README Companion runtime lifecycle',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    '- Companion: `CompanionRuntime` coordinates PetBar and MicroBags as result-bearing layers; weak-key hook records, compact count objects, and summaries live on the Companion owner, never on Blizzard buttons. Hook state is published only after `HookScript`/`hooksecurefunc`/callback registration succeeds, and replacement reconciliation makes stale callbacks inert. `CompanionPetState` journals exact original/managed PetActionButton and native PetActionBar properties, treats structural layout and dynamic visibility as separate ownership groups, reopens snapshots when component objects are replaced, records mover preview as managed state, and refuses unreadable mutable state. A failed layer restores partial presentation and propagates failure to Apply/Lifecycle; missing PetActionButton frames are transient queued work, not a fatal lifecycle failure.',
    '- Companion: `CompanionRuntime` owns exact EventRegistry-callback and watcher-frame generations in addition to coordinating PetBar and MicroBags as result-bearing layers. Attach prepares both generations before publication; callbacks resolve the exact current record; detach invalidates records before unregister; failed callback/watcher cleanup remains inert and retryable; and combat detach uses a dedicated watcher until exact layout restore succeeds. Weak-key hook records, compact count objects, and summaries live on the Companion owner, never on Blizzard buttons. Hook state is published only after `HookScript`/`hooksecurefunc` registration succeeds, and replacement reconciliation makes stale callbacks inert. `CompanionPetState` journals exact original/managed PetActionButton and native PetActionBar properties, treats structural layout and dynamic visibility as separate ownership groups, reopens snapshots when component objects are replaced, records mover preview as managed state, and refuses unreadable mutable state. A failed layer restores partial presentation and propagates failure to Apply/Lifecycle; missing PetActionButton frames are transient queued work, not a fatal lifecycle failure.',
    'AGENT_GUIDE Companion runtime lifecycle',
)
agent_path.write_text(agent, encoding='utf-8')

index_path = Path('CODE_INDEX.md')
index = index_path.read_text(encoding='utf-8')
index = replace_once(
    index,
    '| `modules/CompanionRuntime.lua` | Result-bearing Companion lifecycle/apply coordinator and partial-layer cleanup. |',
    '| `modules/CompanionRuntime.lua` | Result-bearing Companion lifecycle/apply coordinator with prepare/commit EventRegistry and watcher generations, retryable teardown, deferred-detach finalization, and partial-layer cleanup. |',
    'CODE_INDEX Companion runtime lifecycle',
)
index_path.write_text(index, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(todo, '- [x] Target Interface `120105` and release `0.0.71`.', '- [x] Target Interface `120105` and release `0.0.72`.', 'TODO version')
todo = replace_once(
    todo,
    '- [x] Make Companion permanent hooks replacement-aware and retryable: weak-key records publish each edge only after successful HookScript/hooksecurefunc/EventRegistry registration, partial failures retry only missing edges, and stale source/button callbacks are inert.',
    '- [x] Make Companion runtime registrations generation-owned and retryable: EventRegistry callback and watcher-frame edges prepare before joint publication, exact records are invalidated before unregister, partial attach and stale callbacks remain inert, failed teardown is retained for retry, and a dedicated post-combat watcher finalizes layout restore before release; permanent source/button hooks remain weak-key and replacement-aware.',
    'TODO Companion runtime status',
)
todo = replace_once(
    todo,
    '- [ ] Force HookScript, hooksecurefunc, EventRegistry registration, missing pet buttons, and MicroBags layer failures; Companion publishes no false hook flags, retries only missing edges, replacement makes stale callbacks inert, partial layers restore, and the exact failure reaches Lifecycle/Apply.',
    '- [ ] Force callback-container creation/RegisterCallback/Unregister, watcher CreateFrame/SetScript/RegisterEvent/UnregisterAllEvents, HookScript, hooksecurefunc, missing pet buttons, layer cleanup, and post-combat layout-restore failures; Companion publishes callback/watcher owners only after complete prepare, invalidates stale generations before cleanup, retries exact unresolved teardown, retains the dedicated detach watcher until restore succeeds, keeps permanent hook edges single, restores partial layers, and reports exact failure to Lifecycle/Apply.',
    'TODO Companion runtime validation',
)
todo_path.write_text(todo, encoding='utf-8')

matrix_path = Path('docs/REGRESSION_MATRIX_1_25.md')
matrix = matrix_path.read_text(encoding='utf-8')
matrix = replace_once(
    matrix,
    '| 22 | Companion micro/reset/bag-texture/expand hooks fail partially, retry, then source/buttons are replaced; pet and micro/bag layers also receive conflicting external changes and one injected failure | Only successful hook edges are published, retry adds no duplicates, stale callbacks are inert, backpack texture refresh does not recurse, owner-local journals preserve newer conflicts, partial presentation restores, and exact failure reaches Lifecycle/Apply |  |  |',
    '| 22 | Companion callback-container creation/RegisterCallback/Unregister and watcher CreateFrame/SetScript/RegisterEvent/UnregisterAllEvents fail partially; repeat attach/detach in and out of combat; then fail post-combat restore, permanent hooks and pet/micro layers | Callback and watcher generations publish only after joint complete prepare; partial/stale callbacks stay inert; failed cleanup remains retryable; combat detach owns one dedicated watcher until exact restore succeeds; permanent hook edges stay single; partial presentation restores; newer conflicts survive; exact failure reaches Lifecycle/Apply |  |  |',
    'regression matrix Companion runtime lifecycle',
)
matrix_path.write_text(matrix, encoding='utf-8')

print('Updated Companion runtime lifecycle contracts and documentation.')
