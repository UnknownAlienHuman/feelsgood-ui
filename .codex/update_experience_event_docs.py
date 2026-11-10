from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one current-source anchor, found {count}")
    return text.replace(old, new, 1)


check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
contracts = r'''    assertSourceIncludes('modules/ExperienceBar.lua', 'local EXPERIENCE_EVENTS = {');
    assertSourceIncludes('modules/ExperienceBar.lua', 'module._eventRecord ~= record or record.active ~= true');
    assertSourceIncludes('modules/ExperienceBar.lua', 'previous event cleanup failed');
    assertSourceIncludes('modules/ExperienceBar.lua', 'event rollback: ');
    assertSourceIncludes('modules/ExperienceBar.lua', 'record.active = false');
    assertSourceIncludes('modules/ExperienceBar.lua', 'ExperienceBar event callback setup failed');
    assertSourceExcludes('modules/ExperienceBar.lua', /ev:RegisterEvent\(/, 'unchecked ExperienceBar event registration');
    assertSourceExcludes('modules/ExperienceBar.lua', /self\._events:UnregisterAllEvents\(/, 'unchecked ExperienceBar event unregister');

'''
check = replace_once(
    check,
    "    assertSourceIncludes('modules/ExperienceBar.lua', 'SuppressBlizzardStatusTracking');\n",
    "    assertSourceIncludes('modules/ExperienceBar.lua', 'SuppressBlizzardStatusTracking');\n" + contracts,
    'ExperienceBar checker contracts',
)
check_path.write_text(check, encoding='utf-8')


toc_path = Path('FeelsGoodUI.toc')
toc = toc_path.read_text(encoding='utf-8')
toc = replace_once(toc, '## Version: 0.0.70', '## Version: 0.0.71', 'TOC version')
toc_path.write_text(toc, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(readme, '- FeelsGoodUI `0.0.70`', '- FeelsGoodUI `0.0.71`', 'README version')
readme = replace_once(
    readme,
    'ExperienceBar suppresses native status tracking through a verified per-frame/per-property alpha/mouse journal: unreadable properties are never mutated, every write is read back, hook/suppression/restore failures propagate to Apply/Lifecycle, unresolved restore records remain retryable, and newer conflicting external values are preserved.',
    'ExperienceBar uses a result-bearing event generation plus a verified per-frame/per-property native status journal. Event-frame creation, callback setup, registration, partial-registration cleanup, disable and detach are checked explicitly; callbacks require the exact active record, failed generations remain inert and retryable, first-enable failure rolls back both events and native ownership, and reapply failure preserves the previously committed generation. Unreadable native properties are never mutated, every write is read back, hook/suppression/restore failures propagate to Apply/Lifecycle, unresolved restore records remain retryable, and newer conflicting external values are preserved.',
    'README ExperienceBar event lifecycle',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    '- ExperienceBar owns one lifecycle apply path and a verified property journal for Blizzard status-tracking frames: alpha/mouse channels are captured only when readable, writes are read back, partial restore records survive for retry, manager replacement reopens hook ownership, and exact failures propagate to Apply/Lifecycle.',
    '- ExperienceBar owns one lifecycle apply path, an exact active event-generation record, and a verified property journal for Blizzard status-tracking frames. Event creation/setup/register/unregister edges are result-bearing; partial generations stay inert until complete apply, cleanup remains retryable, first-enable failure rolls back events and native ownership, and reapply failure preserves the prior committed generation. Alpha/mouse channels are captured only when readable, writes are read back, partial restore records survive for retry, manager replacement reopens hook ownership, and exact failures propagate to Apply/Lifecycle.',
    'AGENT_GUIDE ExperienceBar event lifecycle',
)
agent_path.write_text(agent, encoding='utf-8')

index_path = Path('CODE_INDEX.md')
index = index_path.read_text(encoding='utf-8')
index = replace_once(
    index,
    '| `modules/ExperienceBar.lua` | XP/reputation/honor presentation, single lifecycle apply owner, and a verified, retryable per-property Blizzard status-tracking journal. |',
    '| `modules/ExperienceBar.lua` | XP/reputation/honor presentation, result-bearing event-generation lifecycle, single apply owner, and a verified, retryable per-property Blizzard status-tracking journal. |',
    'CODE_INDEX ExperienceBar event lifecycle',
)
index_path.write_text(index, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(todo, '- [x] Target Interface `120105` and release `0.0.70`.', '- [x] Target Interface `120105` and release `0.0.71`.', 'TODO version')
todo = replace_once(
    todo,
    '- [x] Make ExperienceBar native takeover a verified property journal: refuse unreadable channels, read back every write, retain unresolved restore state for retry, reopen hooks on manager replacement, preserve newer conflicts, and propagate exact hook/suppress/restore failures.',
    '- [x] Make ExperienceBar event/native lifecycle result-bearing: publish callbacks only for the exact active complete generation, clean partial registration before retry, keep failed generations inert, aggregate disable/detach cleanup, roll back first-enable native ownership, preserve the prior committed generation on reapply failure, and retain the verified native property journal.',
    'TODO ExperienceBar lifecycle status',
)
todo = replace_once(
    todo,
    '- [ ] Give Blizzard status-tracking manager/containers distinctive alpha, mouse and visibility states; inject unreadable alpha/mouse, stubborn setters, hook failure, manager replacement and restore failure; ExperienceBar must never mutate unreadable channels, must report exact failures, retain retryable unresolved records, avoid duplicate hooks/writes, restore exact still-owned values, and preserve newer conflicts without foreign `Hide`/`Show`.',
    '- [ ] Give Blizzard status-tracking manager/containers distinctive alpha, mouse and visibility states; inject event-frame creation/SetScript/RegisterEvent/UnregisterAllEvents failure plus unreadable alpha/mouse, stubborn setters, hook failure, manager replacement and restore failure; ExperienceBar must publish no partial event generation, keep stale callbacks inert, retry cleanup exactly, never mutate unreadable channels, retain unresolved native records, avoid duplicates, restore exact still-owned values, and preserve newer conflicts without foreign `Hide`/`Show`.',
    'TODO ExperienceBar validation',
)
todo_path.write_text(todo, encoding='utf-8')

matrix_path = Path('docs/REGRESSION_MATRIX_1_25.md')
matrix = matrix_path.read_text(encoding='utf-8')
matrix = replace_once(
    matrix,
    '| 23 | Experience/reputation/honor states; unreadable/stubborn native properties; hook/restore failure; manager replacement; repeated enable/disable and native refresh | Custom progress remains correct; only readable alpha/mouse channels are mutated and verified; failures reach Apply/Lifecycle; unresolved restore retries; hooks do not duplicate; exact still-owned values restore while newer conflicts and native visibility survive |  |  |',
    '| 23 | Experience/reputation/honor states with event-frame creation/SetScript/RegisterEvent/UnregisterAllEvents failure, unreadable/stubborn native properties, manager replacement, hook/update/restore failure | Only a complete exact event generation dispatches; partial/stale callbacks stay inert and cleanup retries; first-enable failure rolls back events/native ownership while reapply preserves the prior generation; correct mode/text/rested state remains; only readable alpha/mouse channels mutate and verify; exact failures reach Apply/Lifecycle; unresolved restore retries; hooks stay single; exact still-owned values restore and newer conflicts survive |  |  |',
    'regression matrix ExperienceBar lifecycle',
)
matrix_path.write_text(matrix, encoding='utf-8')

print('Updated ExperienceBar event lifecycle contracts and documentation from current source.')
