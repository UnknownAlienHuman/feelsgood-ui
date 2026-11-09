from pathlib import Path

path = Path('/tmp/test_experiencebar_native_journal.lua')
text = path.read_text(encoding='utf-8')
old = "assertContains(detail, 'SetAlpha failed: blocked alpha', 'throwing alpha detail')"
new = "assertContains(detail, 'SetAlpha failed:', 'throwing alpha operation detail')\nassertContains(detail, 'blocked alpha', 'throwing alpha source detail')"
count = text.count(old)
if count != 1:
    raise RuntimeError(f'ExperienceBar harness exception anchor: expected 1, found {count}')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
print('Normalized ExperienceBar exception-detail fixture.')
