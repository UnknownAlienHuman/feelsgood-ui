from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


path = Path('modules/CompanionPetBar.lua')
text = path.read_text(encoding='utf-8')
old_preview = r'''PreviewPetLayout = function(module, size, spacing)
    if not module then
        return false, "Companion preview owner unavailable"
    end
    if Shared:IsInCombat() then
        return false, "Companion preview blocked in combat"
    end

    local holder = EnsurePetAnchor(module)
    if not holder then
        return false, "Pet bar holder unavailable"
    end

    holder:SetSize((Shared.PET_BUTTONS * size) + ((Shared.PET_BUTTONS - 1) * spacing), size)
    for i = 1, Shared.PET_BUTTONS do
        local button = _G["PetActionButton" .. i]
        if button then
            button:SetParent(holder)
            button:ClearAllPoints()
            button:SetPoint("LEFT", holder, "LEFT", (i - 1) * (size + spacing), 0)
            button:SetSize(size, size)
        end
    end
    return true
end
'''
new_preview = r'''PreviewPetLayout = function(module, size, spacing)
    if not module then
        return false, "Companion preview owner unavailable"
    end
    if Shared:IsInCombat() then
        return false, "Companion preview blocked in combat"
    end

    local holder = EnsurePetAnchor(module)
    if not holder then
        return false, "Pet bar holder unavailable"
    end

    local pending = {}
    for i = 1, Shared.PET_BUTTONS do
        local button = _G["PetActionButton" .. i]
        if button then
            local components = BuildPetButtonComponents(button)
            local captured, detail = PetState:BeginButton(module, i, button, components)
            if captured ~= true then
                return false, detail or "Pet action button preview capture failed"
            end
            pending[#pending + 1] = {
                index = i,
                button = button,
                components = components,
            }
        else
            PetState:ReleaseButton(module, i)
        end
    end

    holder:SetSize((Shared.PET_BUTTONS * size) + ((Shared.PET_BUTTONS - 1) * spacing), size)
    for i = 1, #pending do
        local entry = pending[i]
        local button = entry.button
        button:SetParent(holder)
        button:ClearAllPoints()
        button:SetPoint("LEFT", holder, "LEFT", (entry.index - 1) * (size + spacing), 0)
        button:SetSize(size, size)

        local finished, detail = PetState:FinishButton(
            module,
            entry.index,
            button,
            entry.components
        )
        if finished ~= true then
            return false, detail or "Managed pet action button preview capture failed"
        end
    end
    return true
end
'''
text = replace_once(text, old_preview, new_preview, 'snapshot-aware pet preview')
path.write_text(text, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
check = replace_once(
    check,
    "    assertSourceIncludes('modules/CompanionPetBar.lua', 'PetState:BeginButton');\n",
    "    assertSourceIncludes('modules/CompanionPetBar.lua', 'PetState:BeginButton');\n"
    "    assertSourceIncludes('modules/CompanionPetBar.lua', 'local pending = {}');\n"
    "    assertSourceIncludes('modules/CompanionPetBar.lua', 'Managed pet action button preview capture failed');\n",
    'pet preview journal contracts',
)
check_path.write_text(check, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(
    readme,
    'component-object replacement reopens the snapshot, unreadable mutable components are refused before mutation,',
    'component-object replacement reopens the snapshot, mover preview updates the same managed journal, unreadable mutable components are refused before mutation,',
    'README preview ownership',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    'reopens snapshots when component objects are replaced, and refuses unreadable mutable state.',
    'reopens snapshots when component objects are replaced, records mover preview as managed state, and refuses unreadable mutable state.',
    'AGENT_GUIDE preview ownership',
)
agent_path.write_text(agent, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(
    todo,
    'reopen snapshots on component replacement, refuse unreadable mutable components, and restore exact still-owned texture/text/cooldown/native-bar-alpha state.',
    'reopen snapshots on component replacement, journal mover preview, refuse unreadable mutable components, and restore exact still-owned texture/text/cooldown/native-bar-alpha state.',
    'TODO preview ownership',
)
todo_path.write_text(todo, encoding='utf-8')

print('Journaled Companion pet-bar mover preview state.')
