from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


path = Path('modules/CompanionPetState.lua')
text = path.read_text(encoding='utf-8')

old_layout = r'''local function RestoreLayout(original, managed)
    local object = original and original.object
    if not (object and managed and managed.object == object) then return end

    local parentKnown, parent = ReadParent(object)
    if parentKnown and parent == managed.parent and type(object.SetParent) == "function" then
        object:SetParent(original.parent)
    end

    local currentPoints = ReadPoints(object)
    if currentPoints and PointsEqual(currentPoints, managed.points) then
        RestorePoints(object, original.points)
    end

    local currentSize = ReadSize(object)
    if currentSize and NumberEqual(currentSize.width, managed.size.width)
        and NumberEqual(currentSize.height, managed.size.height)
        and type(object.SetSize) == "function" then
        object:SetSize(original.size.width, original.size.height)
    end

    local currentHitRect = ReadHitRect(object)
    if original.hitRect and managed.hitRect and currentHitRect
        and HitRectEqual(currentHitRect, managed.hitRect)
        and type(object.SetHitRectInsets) == "function" then
        object:SetHitRectInsets(
            original.hitRect.left,
            original.hitRect.right,
            original.hitRect.top,
            original.hitRect.bottom
        )
    end

    local currentShown = ReadShown(object)
    if currentShown == managed.shown then
        SetShown(object, original.shown)
    end
end
'''
new_layout = r'''local function ForceRestoreLayout(original)
    local object = original and original.object
    if not object then return false end

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
    SetShown(object, original.shown)
    return true
end

local function RestoreLayout(original, managed)
    local object = original and original.object
    if not (object and managed and managed.object == object) then return end

    local parentKnown, parent = ReadParent(object)
    local currentPoints = ReadPoints(object)
    local currentSize = ReadSize(object)
    local currentShown = ReadShown(object)
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
'''
text = replace_once(text, old_layout, new_layout, 'grouped layout restore')

force_helpers = r'''local function ForceRestoreRegion(original)
    local object = original and original.object
    if not object then return end
    if original.points then RestorePoints(object, original.points) end
    if original.texCoord then RestoreTexCoord(object, original.texCoord) end
    if type(original.alpha) == "number" then SetAlpha(object, original.alpha) end
    if type(original.shown) == "boolean" then SetShown(object, original.shown) end
end

local function ForceRestoreTextRegion(original)
    ForceRestoreRegion(original)
    local object = original and original.object
    if object and original.textKnown and type(object.SetText) == "function" then
        object:SetText(original.text)
    end
end

local function ForceRestoreButtonRecord(record)
    if type(record) ~= "table" or not record.original then return false end
    local original = record.original
    ForceRestoreLayout(original.layout)
    ForceRestoreRegion(original.icon)
    ForceRestoreRegion(original.highlight)
    ForceRestoreRegion(original.cooldown)
    ForceRestoreRegion(original.iconMask)
    ForceRestoreTextRegion(original.name)
    ForceRestoreTextRegion(original.hotkey)
    for _, alpha in pairs(original.alphas or {}) do
        if alpha.object and type(alpha.alpha) == "number" then
            SetAlpha(alpha.object, alpha.alpha)
        end
    end
    return true
end

'''
text = replace_once(
    text,
    'local function RestoreButtonRecord(record)\n',
    force_helpers + 'local function RestoreButtonRecord(record)\n',
    'force rollback helpers',
)
text = replace_once(
    text,
    '''local function RestoreButtonRecord(record)
    if type(record) ~= "table" or not record.original or not record.managed then return false end

    RestoreLayout(record.original.layout, record.managed.layout)
''',
    '''local function RestoreButtonRecord(record)
    if type(record) ~= "table" or not record.original then return false end
    if not record.managed then return ForceRestoreButtonRecord(record) end

    RestoreLayout(record.original.layout, record.managed.layout)
''',
    'unfinished record rollback',
)

text = replace_once(
    text,
    '''    SetAlpha(frame, 0)
    record.managedAlpha = ReadAlpha(frame)
    return type(record.managedAlpha) == "number"
end
''',
    '''    SetAlpha(frame, 0)
    record.managedAlpha = ReadAlpha(frame)
    if type(record.managedAlpha) ~= "number" then
        SetAlpha(frame, record.alpha)
        module._petNativeBarState = nil
        return false, "Native pet-bar alpha could not be verified"
    end
    return true
end
''',
    'native alpha rollback',
)
path.write_text(text, encoding='utf-8')

print('Hardened Companion pet-state grouped and unfinished rollback.')
