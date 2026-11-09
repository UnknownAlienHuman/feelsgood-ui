from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


target_path = Path('modules/UnitFramesTarget.lua')
target = target_path.read_text(encoding='utf-8')
target = replace_once(
    target,
    '''function Target.ReconcileOwner(owner)
    if type(owner) ~= "table" then
        return
    end

    HookTargetHeaderAnchorSignals(owner.target)

    ApplyOwnerAuraMode(owner)
    RefreshFrame(owner.target)
    RefreshFrame(owner.focus)
    RefreshFrame(owner.targettarget)
    RefreshFrame(owner.pet)
end
''',
    '''function Target.ReconcileOwner(owner)
    if type(owner) ~= "table" then
        return false, "UnitFrames target observer owner is unavailable"
    end

    -- Re-open ownership on every reconciliation. oUF or another integration may
    -- replace a frame/aura container after the initial lifecycle attach.
    local attached, detail = Target.AttachOwner(owner)
    if attached == false then
        return false, detail
    end

    ApplyOwnerAuraMode(owner)
    RefreshFrame(owner.target)
    RefreshFrame(owner.focus)
    RefreshFrame(owner.targettarget)
    RefreshFrame(owner.pet)
    return true
end
''',
    'Target.ReconcileOwner replacement ownership',
)
target_path.write_text(target, encoding='utf-8')

runtime_path = Path('modules/UnitFramesRuntime.lua')
runtime = runtime_path.read_text(encoding='utf-8')
runtime = replace_once(
    runtime,
    '''    if Target and Target.ReconcileOwner then
        Target.ReconcileOwner(owner)
    end

    owner.player:Show()
''',
    '''    if Target and Target.ReconcileOwner then
        local reconciled, reconcileDetail = Target.ReconcileOwner(owner)
        if reconciled == false then
            return false, reconcileDetail
        end
    end

    owner.player:Show()
''',
    'Runtime reconciliation result propagation',
)
runtime_path.write_text(runtime, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
check = replace_once(
    check,
    "    assertSourceIncludes('modules/UnitFramesTarget.lua', 'Target._headerHookRegistry');\n",
    "    assertSourceIncludes('modules/UnitFramesTarget.lua', 'Target._headerHookRegistry');\n"
    "    assertSourceIncludes('modules/UnitFramesTarget.lua', 'local attached, detail = Target.AttachOwner(owner)');\n"
    "    assertSourceIncludes('modules/UnitFramesRuntime.lua', 'local reconciled, reconcileDetail = Target.ReconcileOwner(owner)');\n"
    "    assertSourceExcludes('modules/UnitFramesRuntime.lua', /Target\\.ReconcileOwner\\(owner\\)\\s*\\n\\s*end/, 'ignored UnitFrames reconciliation result');\n",
    'UnitFrames reconciliation result contracts',
)
check_path.write_text(check, encoding='utf-8')

print('Hardened UnitFrames replacement reconciliation and failure propagation.')
