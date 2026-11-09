from pathlib import Path

path = Path('core/Movers.lua')
text = path.read_text(encoding='utf-8')
old = '''    local visible, visibilityDetail = SetEntryOverlayVisible(replacement, self._unlocked)
    local refreshed, refreshDetail = visible and RefreshEntryHandle(replacement) or false, nil
    if visible then
        refreshed, refreshDetail = RefreshEntryHandle(replacement)
    end
'''
new = '''    local visible, visibilityDetail = SetEntryOverlayVisible(replacement, self._unlocked)
    local refreshed, refreshDetail = false, nil
    if visible then
        refreshed, refreshDetail = RefreshEntryHandle(replacement)
    end
'''
count = text.count(old)
if count != 1:
    raise RuntimeError(f'mover replacement refresh anchor: expected one, found {count}')
text = text.replace(old, new, 1)
path.write_text(text, encoding='utf-8')
print('Removed duplicate replacement handle refresh.')