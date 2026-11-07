from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


state_path = Path('modules/CompanionPetState.lua')
state = state_path.read_text(encoding='utf-8')
state = replace_once(
    state,
    '''    for _, alpha in pairs(original.alphas or {}) do
        if alpha.object and type(alpha.alpha) == "number" then
            SetAlpha(alpha.object, alpha.alpha)
        end
    end
    return true
end

local function RestoreButtonRecord(record)
''',
    '''    for _, alpha in pairs(original.alphas or {}) do
        if alpha.object and type(alpha.alpha) == "number" then
            SetAlpha(alpha.object, alpha.alpha)
        end
    end
    if type(record.release) == "function" then
        pcall(record.release, record.button)
    end
    return true
end

local function RestoreButtonRecord(record)
''',
    'force release callback',
)
state = replace_once(
    state,
    '''    for key, original in pairs(record.original.alphas or {}) do
        local managed = record.managed.alphas and record.managed.alphas[key]
        local object = original and original.object
        if object and managed and managed.object == object
            and type(original.alpha) == "number" and type(managed.alpha) == "number"
            and NumberEqual(ReadAlpha(object), managed.alpha) then
            SetAlpha(object, original.alpha)
        end
    end
    return true
end
''',
    '''    for key, original in pairs(record.original.alphas or {}) do
        local managed = record.managed.alphas and record.managed.alphas[key]
        local object = original and original.object
        if object and managed and managed.object == object
            and type(original.alpha) == "number" and type(managed.alpha) == "number"
            and NumberEqual(ReadAlpha(object), managed.alpha) then
            SetAlpha(object, original.alpha)
        end
    end
    if type(record.release) == "function" then
        pcall(record.release, record.button)
    end
    return true
end
''',
    'normal release callback',
)
state = replace_once(
    state,
    '''        record = {
            button = button,
            original = original,
        }
''',
    '''        record = {
            button = button,
            original = original,
            release = components and components.release or nil,
        }
''',
    'capture release callback',
)
state_path.write_text(state, encoding='utf-8')

pet_path = Path('modules/CompanionPetBar.lua')
pet = pet_path.read_text(encoding='utf-8')
release_helper = r'''local function ReleasePetButtonStyle(button)
    if Media and type(Media.SetBorderColor) == "function" then
        Media:SetBorderColor(button, 0, 0, 0, 0)
    end
end

'''
pet = replace_once(
    pet,
    'local function BuildPetButtonComponents(button)\n',
    release_helper + 'local function BuildPetButtonComponents(button)\n',
    'pet style release helper',
)
pet = replace_once(
    pet,
    '''    return {
        icon = GetPetButtonIcon(button),
''',
    '''    return {
        release = ReleasePetButtonStyle,
        icon = GetPetButtonIcon(button),
''',
    'pet component release callback',
)
pet_path.write_text(pet, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
check = replace_once(
    check,
    "    assertSourceIncludes('modules/CompanionPetState.lua', 'function State:RestoreAll');\n",
    "    assertSourceIncludes('modules/CompanionPetState.lua', 'function State:RestoreAll');\n"
    "    assertSourceIncludes('modules/CompanionPetState.lua', 'pcall(record.release, record.button)');\n"
    "    assertSourceIncludes('modules/CompanionPetBar.lua', 'release = ReleasePetButtonStyle');\n",
    'pet release static contracts',
)
check_path.write_text(check, encoding='utf-8')

print('Added explicit release for addon-owned pet-button styling.')
