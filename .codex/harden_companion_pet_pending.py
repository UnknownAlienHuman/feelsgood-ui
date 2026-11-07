from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


pet_path = Path('modules/CompanionPetBar.lua')
pet = pet_path.read_text(encoding='utf-8')
pet = replace_once(
    pet,
    '''    if not allReady then
        module._pendingAfterCombat = true
        return false, "Pet action buttons unavailable"
    end
    return true
end
''',
    '''    if not allReady then
        module._pendingPetButtons = true
        module._pendingAfterCombat = true
        return true, "Pet action buttons pending runtime creation"
    end

    module._pendingPetButtons = nil
    module._pendingAfterCombat = nil
    return true
end
''',
    'transient pet-button creation',
)
pet_path.write_text(pet, encoding='utf-8')

runtime_path = Path('modules/CompanionRuntime.lua')
runtime = runtime_path.read_text(encoding='utf-8')
runtime = replace_once(
    runtime,
    '''    module._pendingAfterCombat = nil
    module._pendingDetachRestore = nil
''',
    '''    module._pendingAfterCombat = nil
    module._pendingPetButtons = nil
    module._pendingDetachRestore = nil
''',
    'pet pending detach cleanup',
)
runtime_path.write_text(runtime, encoding='utf-8')

micro_path = Path('modules/CompanionMicroBags.lua')
micro = micro_path.read_text(encoding='utf-8')
micro = replace_once(
    micro,
    '''    if type(free) ~= "number" or type(total) ~= "number" then
        text:SetText("")
        return
    end
''',
    '''    if type(free) ~= "number" or type(total) ~= "number" then
        text:SetText("")
        module._compactBagSummary = nil
        return
    end
''',
    'stale compact bag summary cleanup',
)
micro_path.write_text(micro, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
check = replace_once(
    check,
    "    assertSourceIncludes('modules/CompanionPetBar.lua', 'return false, \"Pet action buttons unavailable\"');\n",
    "    assertSourceIncludes('modules/CompanionPetBar.lua', 'return true, \"Pet action buttons pending runtime creation\"');\n"
    "    assertSourceIncludes('modules/CompanionPetBar.lua', 'module._pendingPetButtons = nil');\n"
    "    assertSourceExcludes('modules/CompanionPetBar.lua', /return false, \"Pet action buttons unavailable\"/, 'fatal transient pet-button startup');\n",
    'pet-button pending static contract',
)
check_path.write_text(check, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(
    readme,
    'Companion micro-menu/bag hook state, compact-count font strings, and summaries likewise live on the Companion owner; layer apply functions return explicit terminal results, and a failed layer restores already-applied companion presentation before reporting failure to the shared journal.',
    'Companion micro-menu/bag hook state, compact-count font strings, and summaries likewise live on the Companion owner; layer apply functions return explicit results, a failed layer restores already-applied presentation before reporting failure, and transient pet-button creation is queued for an event-driven retry instead of disabling the feature.',
    'README pet-button pending policy',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    'A failed layer restores partial companion presentation and propagates failure to Apply/Lifecycle.',
    'A failed layer restores partial companion presentation and propagates failure to Apply/Lifecycle; missing PetActionButton frames are transient queued work, not a fatal lifecycle failure.',
    'AGENT_GUIDE pet-button pending policy',
)
agent_path.write_text(agent, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(
    todo,
    '- [x] Move Companion hooks/count caches/summaries off Blizzard frames and make PetBar/MicroBags apply terminal-result aware; failed layers clean partial presentation and propagate failure instead of reporting false success.\n',
    '- [x] Move Companion hooks/count caches/summaries off Blizzard frames and make PetBar/MicroBags apply result-aware; failed layers clean partial presentation, while transient PetActionButton creation queues an event-driven retry instead of disabling Companion.\n',
    'TODO pet-button pending status',
)
todo_path.write_text(todo, encoding='utf-8')

print('Separated transient Companion pet-button creation from fatal apply failure.')
