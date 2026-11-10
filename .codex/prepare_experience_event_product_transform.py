from pathlib import Path

path = Path('.codex/harden_experience_event_lifecycle.py')
text = path.read_text(encoding='utf-8')
marker = '''# ---------------------------------------------------------------------------
# Static contracts, docs, release metadata.
# ---------------------------------------------------------------------------
'''
count = text.count(marker)
if count != 1:
    raise RuntimeError(f'ExperienceBar product/docs boundary: expected one, found {count}')
product = text.split(marker, 1)[0].rstrip() + "\n\nprint('Applied ExperienceBar event-generation product transform.')\n"
path.write_text(product, encoding='utf-8')
print('Separated ExperienceBar product transform from documentation updates.')
