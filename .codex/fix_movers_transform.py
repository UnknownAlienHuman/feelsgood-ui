from pathlib import Path

path = Path('.codex/harden_movers_registration_lifecycle.py')
text = path.read_text(encoding='utf-8')

old_anchor = '''    Movers:Register("player", player, Call("CreateUnitMoverSpec", "player", "Player"))
    Movers:Register("target", target, Call("CreateUnitMoverSpec", "target", "Target"))
    Movers:Register("focus", focus, Call("CreateUnitMoverSpec", "focus", "Focus"))
    Movers:Register("targettarget", targettarget, Call("CreateUnitMoverSpec", "targettarget", "TargetTarget"))

    Movers:Apply("player", player)
    Movers:Apply("target", target)
    Movers:Apply("focus", focus)
    Movers:Apply("targettarget", targettarget)

    if Movers.ApplyUnlockFromDB then
        Movers:ApplyUnlockFromDB()
    end

    owner._inited = true
'''

current_anchor = '''    Movers:Register("player", player, createUnitMoverSpec("player", "Player"))
    Movers:Register("target", target, createUnitMoverSpec("target", "Target"))
    Movers:Register("focus", focus, createUnitMoverSpec("focus", "Focus"))
    Movers:Register("targettarget", targettarget, createUnitMoverSpec("targettarget", "TargetTarget"))
    Movers:Register("pet", pet, createUnitMoverSpec("pet", "Pet"))

    Movers:Apply("player", player)
    Movers:Apply("target", target)
    Movers:Apply("focus", focus)
    Movers:Apply("targettarget", targettarget)
    Movers:Apply("pet", pet)
    Movers:ApplyUnlockFromDB()

    owner._inited = true
'''

count = text.count(old_anchor)
if count != 1:
    raise RuntimeError(f'UnitFrames transform source anchor: expected one, found {count}')
text = text.replace(old_anchor, current_anchor, 1)

old_builder = '            Call("CreateUnitMoverSpec", record.key, record.label)\n'
new_builder = '            createUnitMoverSpec(record.key, record.label)\n'
count = text.count(old_builder)
if count != 1:
    raise RuntimeError(f'UnitFrames mover-spec builder anchor: expected one, found {count}')
text = text.replace(old_builder, new_builder, 1)

old_records = '''        { key = "targettarget", frame = targettarget, label = "TargetTarget" },
    }
'''
new_records = '''        { key = "targettarget", frame = targettarget, label = "TargetTarget" },
        { key = "pet", frame = pet, label = "Pet" },
    }
'''
count = text.count(old_records)
if count != 1:
    raise RuntimeError(f'UnitFrames mover records anchor: expected one, found {count}')
text = text.replace(old_records, new_records, 1)

path.write_text(text, encoding='utf-8')
print('Rebased UnitFrames mover lifecycle transform onto current source.')
