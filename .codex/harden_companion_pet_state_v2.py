from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


path = Path('modules/CompanionPetState.lua')
text = path.read_text(encoding='utf-8')

validation = r'''local function HasMethods(object, ...)
    if not object then return false end
    for i = 1, select("#", ...) do
        if type(object[select(i, ...)]) ~= "function" then return false end
    end
    return true
end

local function ValidateCapturedComponents(state, components)
    local icon = components.icon
    if icon and not (
        state.icon and state.icon.points and state.icon.texCoord
        and HasMethods(icon, "ClearAllPoints", "SetPoint", "SetTexCoord")
    ) then
        return false
    end

    local highlight = components.highlight
    if highlight and not (
        state.highlight and state.highlight.points and type(state.highlight.alpha) == "number"
        and HasMethods(highlight, "ClearAllPoints", "SetPoint", "SetAlpha")
    ) then
        return false
    end

    local cooldown = components.cooldown
    if cooldown and not (
        state.cooldown and state.cooldown.points
        and HasMethods(cooldown, "ClearAllPoints", "SetPoint")
    ) then
        return false
    end

    local iconMask = components.iconMask
    if iconMask and not (
        state.iconMask and type(state.iconMask.shown) == "boolean"
        and HasMethods(iconMask, "Show", "Hide")
    ) then
        return false
    end

    local name = components.name
    if name and not (
        state.name and state.name.textKnown and type(state.name.shown) == "boolean"
        and HasMethods(name, "SetText", "Show", "Hide")
    ) then
        return false
    end

    local hotkey = components.hotkey
    if hotkey and not (
        state.hotkey and type(state.hotkey.alpha) == "number"
        and type(state.hotkey.shown) == "boolean"
        and HasMethods(hotkey, "SetAlpha", "Show", "Hide")
    ) then
        return false
    end

    for key, object in pairs(components.alphas or {}) do
        local captured = state.alphas[key]
        if object and not (
            captured and captured.object == object and type(captured.alpha) == "number"
            and HasMethods(object, "SetAlpha")
        ) then
            return false
        end
    end
    return true
end

local function CapturedObject(record)
    return record and record.object or nil
end

local function ComponentsMatch(original, components)
    if type(original) ~= "table" then return false end
    if CapturedObject(original.icon) ~= components.icon
        or CapturedObject(original.highlight) ~= components.highlight
        or CapturedObject(original.cooldown) ~= components.cooldown
        or CapturedObject(original.iconMask) ~= components.iconMask
        or CapturedObject(original.name) ~= components.name
        or CapturedObject(original.hotkey) ~= components.hotkey then
        return false
    end

    local capturedAlphas = original.alphas or {}
    local currentAlphas = components.alphas or {}
    for key, object in pairs(currentAlphas) do
        if CapturedObject(capturedAlphas[key]) ~= object then return false end
    end
    for key, captured in pairs(capturedAlphas) do
        if CapturedObject(captured) ~= currentAlphas[key] then return false end
    end
    return true
end

'''
text = replace_once(
    text,
    'local function CaptureButtonState(button, components)\n',
    validation + 'local function CaptureButtonState(button, components)\n',
    'component ownership validation helpers',
)
text = replace_once(
    text,
    '''    for key, object in pairs(components.alphas or {}) do
        state.alphas[key] = {
            object = object,
            alpha = ReadAlpha(object),
        }
    end
    return state
end
''',
    '''    for key, object in pairs(components.alphas or {}) do
        state.alphas[key] = {
            object = object,
            alpha = ReadAlpha(object),
        }
    end
    if not ValidateCapturedComponents(state, components) then return nil end
    return state
end
''',
    'component capture validation',
)

text = replace_once(
    text,
    '''    local currentShown = ReadShown(object)
    local currentHitRect = ReadHitRect(object)

    local owned = parentKnown
        and parent == managed.parent
        and currentPoints and PointsEqual(currentPoints, managed.points)
        and currentSize
        and NumberEqual(currentSize.width, managed.size.width)
        and NumberEqual(currentSize.height, managed.size.height)
        and currentShown == managed.shown

    if owned and managed.hitRect then
        owned = currentHitRect and HitRectEqual(currentHitRect, managed.hitRect)
    end
    if owned then ForceRestoreLayout(original) end
end
''',
    '''    local currentShown = ReadShown(object)
    local currentHitRect = ReadHitRect(object)

    local structuralOwned = parentKnown
        and parent == managed.parent
        and currentPoints and PointsEqual(currentPoints, managed.points)
        and currentSize
        and NumberEqual(currentSize.width, managed.size.width)
        and NumberEqual(currentSize.height, managed.size.height)

    if structuralOwned and managed.hitRect then
        structuralOwned = currentHitRect and HitRectEqual(currentHitRect, managed.hitRect)
    end
    if structuralOwned then
        if type(object.SetParent) == "function" then object:SetParent(original.parent) end
        RestorePoints(object, original.points)
        if type(object.SetSize) == "function" then
            object:SetSize(original.size.width, original.size.height)
        end
        if original.hitRect and type(object.SetHitRectInsets) == "function" then
            object:SetHitRectInsets(
                original.hitRect.left,
                original.hitRect.right,
                original.hitRect.top,
                original.hitRect.bottom
            )
        end
    end

    if currentShown == managed.shown then
        SetShown(object, original.shown)
    end
end
''',
    'independent visibility ownership',
)

text = replace_once(
    text,
    '''    local registry = GetRegistry(module)
    local record = registry[index]
    if record and record.button ~= button then
        RestoreButtonRecord(record)
        registry[index] = nil
        record = nil
    end

    if not record then
        local original = CaptureButtonState(button, components or {})
''',
    '''    components = type(components) == "table" and components or {}
    local registry = GetRegistry(module)
    local record = registry[index]
    if record and (
        record.button ~= button
        or not ComponentsMatch(record.original, components)
    ) then
        RestoreButtonRecord(record)
        registry[index] = nil
        record = nil
    end

    if not record then
        local original = CaptureButtonState(button, components)
''',
    'component replacement reopening',
)
text = replace_once(
    text,
    '            release = components and components.release or nil,\n',
    '            release = components.release,\n',
    'normalized release capture',
)
path.write_text(text, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
check = replace_once(
    check,
    "    assertSourceIncludes('modules/CompanionPetState.lua', 'pcall(record.release, record.button)');\n",
    "    assertSourceIncludes('modules/CompanionPetState.lua', 'pcall(record.release, record.button)');\n"
    "    assertSourceIncludes('modules/CompanionPetState.lua', 'ValidateCapturedComponents');\n"
    "    assertSourceIncludes('modules/CompanionPetState.lua', 'ComponentsMatch');\n"
    "    assertSourceIncludes('modules/CompanionPetState.lua', 'local structuralOwned = parentKnown');\n"
    "    assertSourceIncludes('modules/CompanionPetState.lua', 'if currentShown == managed.shown then');\n",
    'PetState v2 static contracts',
)
check_path.write_text(check, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(
    readme,
    'PetActionButton takeover is journaled property-by-property in `CompanionPetState`: original and managed parent/points/size/visibility, textures, masks, text, cooldown and native PetActionBar alpha restore only while still addon-owned, so newer external changes are preserved.',
    'PetActionButton takeover is journaled property-by-property in `CompanionPetState`: structural layout and dynamic visibility have separate ownership, component-object replacement reopens the snapshot, unreadable mutable components are refused before mutation, and original/managed textures, masks, text, cooldown and native PetActionBar alpha restore only while still addon-owned.',
    'README PetState v2 policy',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    '`CompanionPetState` journals exact original/managed PetActionButton and native PetActionBar properties and restores only still-owned values.',
    '`CompanionPetState` journals exact original/managed PetActionButton and native PetActionBar properties, treats structural layout and dynamic visibility as separate ownership groups, reopens snapshots when component objects are replaced, and refuses unreadable mutable state.',
    'AGENT_GUIDE PetState v2 policy',
)
agent_path.write_text(agent, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(
    todo,
    '- [x] Journal PetActionButton takeover in `CompanionPetState`: exact original and managed layout/visibility/texture/text/cooldown/native-bar-alpha properties restore only when still addon-owned, preserving newer external changes and frame replacement.\n',
    '- [x] Journal PetActionButton takeover in `CompanionPetState`: separate structural layout from dynamic visibility ownership, reopen snapshots on component replacement, refuse unreadable mutable components, and restore exact still-owned texture/text/cooldown/native-bar-alpha state.\n',
    'TODO PetState v2 status',
)
todo_path.write_text(todo, encoding='utf-8')

print('Hardened PetState visibility, component replacement, and readability contracts.')
