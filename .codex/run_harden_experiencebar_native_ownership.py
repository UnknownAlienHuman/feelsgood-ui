from pathlib import Path
import runpy

source_path = Path('.codex/harden_experiencebar_native_ownership.py')
source = source_path.read_text(encoding='utf-8')
old = '''    local ok, value = pcall(frame.IsMouseEnabled, frame)
    return ok and type(value) == "boolean" and value or nil
end

local function SetFrameAlpha(frame, value)
'''
new = '''    local ok, value = pcall(frame.IsMouseEnabled, frame)
    if not ok or type(value) ~= "boolean" then return nil end
    return value
end

local function SetFrameAlpha(frame, value)
'''
if source.count(old) != 1:
    raise RuntimeError(f'boolean-state fix anchor count: {source.count(old)}')
source = source.replace(old, new, 1)

temp = Path('.codex/.harden_experiencebar_native_ownership.runtime.py')
temp.write_text(source, encoding='utf-8')
runpy.run_path(str(temp), run_name='__main__')
