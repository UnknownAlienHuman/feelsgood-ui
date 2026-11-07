from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


path = Path('modules/CenterBarsRender.lua')
text = path.read_text(encoding='utf-8')
text = replace_once(
    text,
    '''local function ApplyClassResourceSuppression(frame)
    if not frame then return false end
    SetNativeFrameAlpha(frame, 0)
    SetNativeFrameMouseEnabled(frame, false)
    return true
end
''',
    '''local function ApplyClassResourceSuppression(record)
    local frame = record and record.frame
    if not frame then return false end

    local applied = false
    if type(record.alpha) == "number" then
        SetNativeFrameAlpha(frame, 0)
        applied = true
    end
    if type(record.mouseEnabled) == "boolean" then
        SetNativeFrameMouseEnabled(frame, false)
        applied = true
    end
    return applied
end
''',
    'capture-aware suppression',
)
text = replace_once(
    text,
    '''            if record.frame == shownFrame then
                ApplyClassResourceSuppression(shownFrame)
                return
            end
''',
    '''            if record.frame == shownFrame then
                ApplyClassResourceSuppression(record)
                return
            end
''',
    'OnShow record ownership',
)
text = replace_once(
    text,
    '''    if not record then
        record = {
            frame = frame,
            alpha = ReadNativeFrameAlpha(frame),
            mouseEnabled = ReadNativeFrameMouseEnabled(frame),
        }
        registry[name] = record
    end

    EnsureClassResourceShowHook(owner, frame)
    return ApplyClassResourceSuppression(frame)
end
''',
    '''    if not record then
        record = {
            frame = frame,
            alpha = ReadNativeFrameAlpha(frame),
            mouseEnabled = ReadNativeFrameMouseEnabled(frame),
        }
        if type(record.alpha) ~= "number" and type(record.mouseEnabled) ~= "boolean" then
            return false
        end
        registry[name] = record
    end

    EnsureClassResourceShowHook(owner, frame)
    return ApplyClassResourceSuppression(record)
end
''',
    'reversible property requirement',
)
text = replace_once(
    text,
    '''            local frame = _G[name]
            if frame then
                SuppressClassResourceFrame(owner, name, frame)
            end
''',
    '''            local frame = _G[name]
            if frame then
                SuppressClassResourceFrame(owner, name, frame)
            elseif registry[name] then
                RestoreClassResourceRecord(registry[name])
                registry[name] = nil
            end
''',
    'missing global frame recovery',
)
path.write_text(text, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
check = replace_once(
    check,
    "    assertSourceIncludes('modules/CenterBarsRender.lua', 'RestoreClassResourceRecord');\n",
    "    assertSourceIncludes('modules/CenterBarsRender.lua', 'RestoreClassResourceRecord');\n"
    "    assertSourceIncludes('modules/CenterBarsRender.lua', 'ApplyClassResourceSuppression(record)');\n"
    "    assertSourceIncludes('modules/CenterBarsRender.lua', 'elseif registry[name] then');\n",
    'CenterBars edge contracts',
)
check_path.write_text(check, encoding='utf-8')

print('Hardened CenterBars missing-frame and unreadable-property ownership.')
