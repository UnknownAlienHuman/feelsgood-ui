from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one current-source anchor, found {count}")
    return text.replace(old, new, 1)


check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
contracts = r'''    assertSourceIncludes('modules/CenterBarsRuntime.lua', 'Runtime._nextEventRecordID');
    assertSourceIncludes('modules/CenterBarsRuntime.lua', 'local CENTER_EVENT_REGISTRATIONS = {');
    assertSourceIncludes('modules/CenterBarsRuntime.lua', 'owner._eventRecord ~= record or record.active ~= true');
    assertSourceIncludes('modules/CenterBarsRuntime.lua', 'CenterBars event callback setup failed');
    assertSourceIncludes('modules/CenterBarsRuntime.lua', 'CenterBars previous event cleanup failed');
    assertSourceIncludes('modules/CenterBarsRuntime.lua', 'CenterBars event cleanup failed');
    assertSourceExcludes('modules/CenterBarsRuntime.lua', /frame:RegisterEvent\(/, 'unchecked CenterBars event registration');
    assertSourceExcludes('modules/CenterBarsRuntime.lua', /frame:RegisterUnitEvent\(/, 'unchecked CenterBars unit-event registration');
    assertSourceExcludes('modules/CenterBarsRuntime.lua', /owner\._eventFrame:UnregisterAllEvents\(\)/, 'unchecked CenterBars event unregister');

'''
check = replace_once(
    check,
    "    assertSourceIncludes('modules/CenterBarsRuntime.lua', 'CenterBars initialization failed');\n",
    "    assertSourceIncludes('modules/CenterBarsRuntime.lua', 'CenterBars initialization failed');\n" + contracts,
    'CenterBars event static contracts',
)
check_path.write_text(check, encoding='utf-8')


toc_path = Path('FeelsGoodUI.toc')
toc = toc_path.read_text(encoding='utf-8')
toc = replace_once(toc, '## Version: 0.0.72', '## Version: 0.0.73', 'TOC version')
toc_path.write_text(toc, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(readme, '- FeelsGoodUI `0.0.72`', '- FeelsGoodUI `0.0.73`', 'README version')
readme = replace_once(
    readme,
    'CenterBars follows the same verified property-journal policy for Blizzard class-resource frames: alpha and mouse channels are captured only when readable, every suppression and restore write is checked by readback, hook/write/restore failures propagate to Apply/Lifecycle, unresolved restores remain retryable, frame replacement cannot adopt a new instance until the old ownership record releases, and newer conflicting values are preserved. Combat-sensitive CenterBars apply is centrally deferred and never guesses visibility or calls native setup.',
    'CenterBars owns both an exact event-generation record and a verified property journal for Blizzard class-resource frames. Event-frame creation, callback setup, every RegisterEvent/RegisterUnitEvent edge, disable and detach are result-bearing; only a complete exact generation becomes active, partial or failed-cleanup callbacks stay inert, unresolved teardown remains retryable, and event cleanup failures are aggregated with native restore failures. Alpha and mouse channels are captured only when readable, every suppression and restore write is checked by readback, hook/write/restore failures propagate to Apply/Lifecycle, unresolved restores remain retryable, frame replacement cannot adopt a new instance until the old ownership record releases, and newer conflicting values are preserved. Combat-sensitive CenterBars apply is centrally deferred and never guesses visibility or calls native setup.',
    'README CenterBars event lifecycle',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    '- Center bars: `CenterBars.lua` delegates render/runtime and listens to player power/rune/world/spec events. `CenterBarsRender` owns a verified, retryable alpha/mouse property journal for Blizzard class-resource frames: capture and write-readback are per channel, unresolved restores stay owned for retry, replacement waits for old-owner release, permanent OnShow hooks resolve the current record, and exact failures reach Apply/Lifecycle. It never adds fields to foreign frames or calls their `Hide`/`Show`/`Setup`.',
    '- Center bars: `CenterBars.lua` delegates render/runtime and listens to player power/rune/world/spec events. `CenterBarsRuntime` owns an exact event-generation record: CreateFrame, SetScript, RegisterEvent/RegisterUnitEvent and teardown edges are result-bearing; only a complete record is published; partial/stale callbacks are inert; failed cleanup remains retryable; and disable/detach aggregate event and native-restore failures. `CenterBarsRender` owns a verified, retryable alpha/mouse property journal for Blizzard class-resource frames: capture and write-readback are per channel, unresolved restores stay owned for retry, replacement waits for old-owner release, permanent OnShow hooks resolve the current record, and exact failures reach Apply/Lifecycle. It never adds fields to foreign frames or calls their `Hide`/`Show`/`Setup`.',
    'AGENT_GUIDE CenterBars event lifecycle',
)
agent_path.write_text(agent, encoding='utf-8')

index_path = Path('CODE_INDEX.md')
index = index_path.read_text(encoding='utf-8')
index = replace_once(
    index,
    '| `modules/CenterBars*.lua` | Center-resource rendering/runtime plus verified, retryable and conflict-aware Blizzard class-resource alpha/mouse property ownership. |',
    '| `modules/CenterBars*.lua` | Center-resource rendering/runtime with result-bearing event generations plus verified, retryable and conflict-aware Blizzard class-resource alpha/mouse property ownership. |',
    'CODE_INDEX CenterBars event lifecycle',
)
index_path.write_text(index, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(todo, '- [x] Target Interface `120105` and release `0.0.72`.', '- [x] Target Interface `120105` and release `0.0.73`.', 'TODO version')
todo = replace_once(
    todo,
    '- [x] Make CenterBars class-resource takeover a verified property journal: capture readable alpha/mouse independently, verify every suppression/restore write, retain unresolved restore records, block frame replacement until old ownership releases, centrally defer combat-sensitive apply, propagate exact failure, and preserve newer conflicts without foreign Hide/Show/Setup calls.',
    '- [x] Make CenterBars event/native lifecycle result-bearing: publish only a complete exact event generation, check CreateFrame/SetScript/RegisterEvent/RegisterUnitEvent and teardown edges, keep partial or failed-cleanup callbacks inert and retryable, aggregate disable/detach event cleanup with native restore, retain the verified class-resource property journal, and centrally defer combat-sensitive apply.',
    'TODO CenterBars event status',
)
todo = replace_once(
    todo,
    '- [ ] Across DK/Rogue/Druid/Paladin/Monk/Warlock/Mage/Evoker, give native class-resource frames distinctive alpha/mouse/visibility states; inject unreadable channels, stubborn setters, HookScript failure, restore failure, OnShow, named-frame replacement and combat toggle; verify exact failure reaches Apply/Lifecycle, unresolved restore retries, zero addon Hide/Show/Setup calls, exact still-owned restore, and preservation of newer conflicts.',
    '- [ ] Across DK/Rogue/Druid/Paladin/Monk/Warlock/Mage/Evoker, inject CenterBars event-frame CreateFrame/SetScript/RegisterEvent/RegisterUnitEvent/UnregisterAllEvents failure plus unreadable native channels, stubborn setters, HookScript/restore failure, OnShow, named-frame replacement and combat toggle; verify no partial event generation publishes, stale callbacks stay inert, teardown retries exactly, event/native failures aggregate into Apply/Lifecycle, zero addon Hide/Show/Setup calls occur, exact still-owned state restores, and newer conflicts survive.',
    'TODO CenterBars event validation',
)
todo_path.write_text(todo, encoding='utf-8')

matrix_path = Path('docs/REGRESSION_MATRIX_1_25.md')
matrix = matrix_path.read_text(encoding='utf-8')
anchor = '| 18a | Native class-resource takeover across supported classes with unreadable alpha/mouse, stubborn setters, HookScript/restore failure, OnShow, frame replacement, combat-deferred toggle, and conflicts | Only readable channels mutate; every write is read back; exact failures reach Apply/Lifecycle; unresolved restores retry; replacement waits for old-owner release; no addon `Hide`/`Show`/`Setup` or foreign markers; exact still-owned values restore and newer conflicts survive |  |  |'
row = '| 18b | CenterBars event owner under CreateFrame, SetScript, RegisterEvent, RegisterUnitEvent and UnregisterAllEvents failure; repeat attach/disable/detach and fire stale frames | Only a complete exact generation publishes; partial/stale callbacks remain inert; failed teardown stays retryable; repeated attach stays single; disable/detach aggregate event and native restore failures; exact errors reach Lifecycle/Apply |  |  |'
matrix = replace_once(matrix, anchor, anchor + '\n' + row, 'regression matrix CenterBars event lifecycle')
matrix_path.write_text(matrix, encoding='utf-8')

print('Updated CenterBars event lifecycle contracts and documentation.')
