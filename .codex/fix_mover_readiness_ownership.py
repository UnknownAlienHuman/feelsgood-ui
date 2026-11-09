from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


xp_path = Path('modules/ExperienceBar.lua')
xp = xp_path.read_text(encoding='utf-8')
xp = replace_once(
    xp,
    '''    if module._moverReadyFrame ~= bar then
''',
    '''    local moverEntry = Movers and type(Movers.GetEntry) == "function" and Movers:GetEntry("xpbar") or nil
    if module._moverReadyFrame ~= bar or not moverEntry or moverEntry.frame ~= bar then
''',
    'ExperienceBar mover owner verification',
)
xp_path.write_text(xp, encoding='utf-8')

pet_path = Path('modules/CompanionPetBar.lua')
pet = pet_path.read_text(encoding='utf-8')
pet = replace_once(
    pet,
    '''    if module._petMoverReadyFrame ~= frame then
''',
    '''    local moverEntry = Movers and type(Movers.GetEntry) == "function" and Movers:GetEntry(Shared.PET_KEY) or nil
    if module._petMoverReadyFrame ~= frame or not moverEntry or moverEntry.frame ~= frame then
''',
    'Companion pet mover owner verification',
)
pet_path.write_text(pet, encoding='utf-8')

micro_path = Path('modules/CompanionMicroBags.lua')
micro = micro_path.read_text(encoding='utf-8')
micro = replace_once(
    micro,
    '''    if module._microMoverReadyFrame ~= frame then
''',
    '''    local moverEntry = Movers and type(Movers.GetEntry) == "function" and Movers:GetEntry(Shared.MICRO_KEY) or nil
    if module._microMoverReadyFrame ~= frame or not moverEntry or moverEntry.frame ~= frame then
''',
    'Companion micro mover owner verification',
)
micro_path.write_text(micro, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
check = replace_once(
    check,
    "    assertSourceIncludes('modules/ExperienceBar.lua', 'module._moverReadyFrame ~= bar');\n",
    "    assertSourceIncludes('modules/ExperienceBar.lua', 'module._moverReadyFrame ~= bar or not moverEntry or moverEntry.frame ~= bar');\n",
    'ExperienceBar mover readiness contract',
)
check = replace_once(
    check,
    "    assertSourceIncludes('modules/CompanionPetBar.lua', 'module._petMoverReadyFrame ~= frame');\n",
    "    assertSourceIncludes('modules/CompanionPetBar.lua', 'module._petMoverReadyFrame ~= frame or not moverEntry or moverEntry.frame ~= frame');\n",
    'Companion pet mover readiness contract',
)
check = replace_once(
    check,
    "    assertSourceIncludes('modules/CompanionMicroBags.lua', 'module._microMoverReadyFrame ~= frame');\n",
    "    assertSourceIncludes('modules/CompanionMicroBags.lua', 'module._microMoverReadyFrame ~= frame or not moverEntry or moverEntry.frame ~= frame');\n",
    'Companion micro mover readiness contract',
)
check_path.write_text(check, encoding='utf-8')

print('Bound hot-path mover readiness to the current registry owner.')