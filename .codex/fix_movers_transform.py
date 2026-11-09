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

old_agent = '''agent = replace_once(
    agent,
    '- Change mover behavior:',
    '- Change mover registration/lifecycle: `Movers:Register` and `Movers:Apply` are result-bearing; callers must propagate failure before publishing feature `_inited`/`_created`. Re-registering a key may replace the frame, so overlays/scripts must be retired atomically and partial feature frames retained for retry.\\n- Change mover behavior:',
    'AGENT_GUIDE mover lifecycle routing',
)
'''
new_agent = '''agent = replace_once(
    agent,
    '- Options/movers/commands: modify the corresponding adapter and preserve Settings/Apply ownership. Continuous mover input may preview runtime frames only; build validated writes in the feature mover spec and commit through `MoversTransactions` once at the terminal input event.',
    '- Change mover registration/lifecycle: `Movers:Register` and `Movers:Apply` are result-bearing; callers must propagate failure before publishing feature `_inited`/`_created`. Re-registering a key may replace the frame, so overlays/scripts must be retired atomically and partial feature frames retained for retry.\\n- Options/movers/commands: modify the corresponding adapter and preserve Settings/Apply ownership. Continuous mover input may preview runtime frames only; build validated writes in the feature mover spec and commit through `MoversTransactions` once at the terminal input event.',
    'AGENT_GUIDE mover lifecycle routing',
)
'''
count = text.count(old_agent)
if count != 1:
    raise RuntimeError(f'AGENT_GUIDE transform block: expected one, found {count}')
text = text.replace(old_agent, new_agent, 1)

old_index = '''index = replace_once(
    index,
    '| `core/Movers.lua`, `core/MoversEditor.lua`, `core/MoversInspector.lua`, `core/MoversSnapGrid.lua` | Mover registry, editor overlays, inspector, snapping/grid and lock-state presentation. |',
    '| `core/Movers.lua`, `core/MoversEditor.lua`, `core/MoversInspector.lua`, `core/MoversSnapGrid.lua` | Result-bearing replacement-safe mover registry, retired-overlay cleanup, position apply, editor overlays, inspector, snapping/grid and lock-state presentation. |',
    'CODE_INDEX mover lifecycle',
)
'''
new_index = '''index = replace_once(
    index,
    '| `core/Options*.lua`, `core/Movers*.lua`, `core/Commands.lua` | Settings pages, frame editing/movement UI, and command adapters over Settings/Apply. |',
    '| `core/Movers.lua`, `core/MoversEditor.lua`, `core/MoversInspector.lua`, `core/MoversSnapGrid.lua` | Result-bearing replacement-safe mover registry, retired-overlay cleanup, position apply, editor overlays, inspector, snapping/grid and lock-state presentation. |\\n| `core/Options*.lua`, `core/Commands.lua` | Settings pages and command adapters over Settings/Apply. |',
    'CODE_INDEX mover lifecycle',
)
'''
count = text.count(old_index)
if count != 1:
    raise RuntimeError(f'CODE_INDEX transform block: expected one, found {count}')
text = text.replace(old_index, new_index, 1)

old_matrix = '''anchor = '| 15 | Drag, resize, wheel-adjust, reset, undo, and lock movers | Preview does not write SavedVariables; each terminal action is one transaction; rollback restores exact geometry |  |  |'
replacement = anchor + '\\n| 15a | Re-register each mover key with same and replacement frames; inject overlay/position failure and retry | Same frame reuses one overlay; replacement retires old scripts/handle; failed replacement preserves prior owner; feature init publishes only after register+apply success |  |  |'
'''
new_matrix = '''anchor = '| 8 | Unlock/lock movers; drag near every screen edge | Inspector and frames remain clamped; positions persist after reload |  |  |'
replacement = anchor + '\\n| 8a | Re-register each mover key with same and replacement frames; inject overlay/position failure and retry | Same frame reuses one overlay; replacement retires old scripts/handle; failed replacement preserves prior owner; feature init publishes only after register+apply success |  |  |'
'''
count = text.count(old_matrix)
if count != 1:
    raise RuntimeError(f'regression matrix transform block: expected one, found {count}')
text = text.replace(old_matrix, new_matrix, 1)

path.write_text(text, encoding='utf-8')
print('Rebased mover lifecycle transform onto current source and documentation.')