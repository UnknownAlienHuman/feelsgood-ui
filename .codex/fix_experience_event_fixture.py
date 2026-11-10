from pathlib import Path

path = Path('.codex/test_experience_event_lifecycle.lua')
text = path.read_text(encoding='utf-8')
old = '''    function texture:SetAllPoints() end
    function texture:SetColorTexture() end
'''
new = '''    function texture:SetAllPoints() end
    function texture:ClearAllPoints() end
    function texture:SetColorTexture() end
'''
count = text.count(old)
if count != 1:
    raise RuntimeError(f'ExperienceBar texture fixture anchor: expected one, found {count}')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
print('Completed ExperienceBar Texture mock.')
