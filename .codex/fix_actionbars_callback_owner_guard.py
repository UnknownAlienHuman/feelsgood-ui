from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


runtime_path = Path('modules/ActionBarsRuntime.lua')
runtime = runtime_path.read_text(encoding='utf-8')
runtime = replace_once(
    runtime,
    '''local function OnActionChanged(_, button)
    local activeModule = Runtime._callbackOwner
    if IsDetached(activeModule) then return end
''',
    '''local function OnActionChanged(_, button)
    local activeModule = Runtime._callbackOwner
    if not IsReady(activeModule) or IsDetached(activeModule) then return end
''',
    'ActionBars callback active-owner guard',
)
runtime_path.write_text(runtime, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
check = replace_once(
    check,
    "    assertSourceIncludes('modules/ActionBarsRuntime.lua', 'local activeModule = Runtime._callbackOwner');\n",
    "    assertSourceIncludes('modules/ActionBarsRuntime.lua', 'local activeModule = Runtime._callbackOwner');\n"
    "    assertSourceIncludes('modules/ActionBarsRuntime.lua', 'if not IsReady(activeModule) or IsDetached(activeModule) then return end');\n",
    'ActionBars callback owner guard static contract',
)
check_path.write_text(check, encoding='utf-8')

print('Blocked ActionBars action-change callbacks without an active owner.')
