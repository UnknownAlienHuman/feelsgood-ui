from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


policy_path = Path('modules/UnitFramesPolicy.lua')
policy = policy_path.read_text(encoding='utf-8')
policy = replace_once(
    policy,
    'local Theme = ns.Theme\n\n',
    'local Theme = ns.Theme\n\nlocal EMPTY = {}\n\n',
    'UnitFramesPolicy EMPTY sentinel',
)
old_get = r'''local function GetSectionTable(profile, section)
    if type(profile) == "table" then
        local value = profile[section]
        if type(value) ~= "table" then
            value = {}
            profile[section] = value
        end
        return value
    end

    if DB and DB.GetSection then
        local value = DB:GetSection(section)
        if type(value) == "table" then
            return value
        end
    end

    return {}
end
'''
new_get = r'''local function GetSectionTable(profile, section)
    local source = profile
    if type(source) ~= "table" and DB and type(DB.GetProfile) == "function" then
        source = DB:GetProfile()
    end

    local value = type(source) == "table" and source[section] or nil
    if type(value) == "table" then
        return value
    end
    return EMPTY
end
'''
policy = replace_once(policy, old_get, new_get, 'pure section reader')
policy = policy.replace('    local sn = (type(format.shortNumbers) == "table") and format.shortNumbers or {}\n', '    local sn = (type(format.shortNumbers) == "table") and format.shortNumbers or EMPTY\n', 1)
policy = policy.replace('    local style = Policy.GetStyleCfg(profile)\n', '    local style = Policy.GetStyleCfg(profile)\n', 1)
policy = policy.replace('    local t = uf.text or {}\n', '    local t = (type(uf.text) == "table") and uf.text or EMPTY\n', 1)
policy = policy.replace('    Cache.targetInfo = uf.targetInfo or {}\n', '    Cache.targetInfo = (type(uf.targetInfo) == "table") and uf.targetInfo or EMPTY\n', 1)
policy = policy.replace('    Cache.targetAuras = uf.targetAuras or {}\n', '    Cache.targetAuras = (type(uf.targetAuras) == "table") and uf.targetAuras or EMPTY\n', 1)

size_start = policy.index('function Policy.NormalizeUFSizeTables')
size_end = policy.index('function Policy.GetUnitFrameSize', size_start)
policy = policy[:size_start] + policy[size_end:]
scale_start = policy.index('function Policy.NormalizeUFScaleTables')
scale_end = policy.index('function Policy.GetUnitFrameScale', scale_start)
policy = policy[:scale_start] + policy[scale_end:]
policy_path.write_text(policy, encoding='utf-8')

unit_path = Path('modules/UnitFrames.lua')
unit = unit_path.read_text(encoding='utf-8')
for line in [
    '    NormalizeUFScaleTables = Policy.NormalizeUFScaleTables,\n',
    '    NormalizeUFSizeTables = Policy.NormalizeUFSizeTables,\n',
]:
    count = unit.count(line)
    if count != 2:
        raise RuntimeError(f'UnitFrames context line {line.strip()}: expected 2, found {count}')
    unit = unit.replace(line, '')
unit_path.write_text(unit, encoding='utf-8')

runtime_path = Path('modules/UnitFramesRuntime.lua')
runtime = runtime_path.read_text(encoding='utf-8')
runtime = replace_once(
    runtime,
    '''    local defaults = (DB.defaults and DB.defaults.profile and DB.defaults.profile.unitframes) or {}
    Call("NormalizeUFSizeTables", unitframesCfg, defaults)
    Call("NormalizeUFScaleTables", unitframesCfg, defaults)

''',
    '''    local defaults = (DB.defaults and DB.defaults.profile and DB.defaults.profile.unitframes) or {}

''',
    'UnitFramesRuntime normalizer removal',
)
runtime_path.write_text(runtime, encoding='utf-8')

render_path = Path('modules/UnitFramesRender.lua')
render = render_path.read_text(encoding='utf-8')
render = replace_once(
    render,
    '''    local defaults = (DB.defaults and DB.defaults.profile and DB.defaults.profile.unitframes) or {}
    Call("NormalizeUFSizeTables", unitframesCfg, defaults)
    Call("NormalizeUFScaleTables", unitframesCfg, defaults)

''',
    '''    local defaults = (DB.defaults and DB.defaults.profile and DB.defaults.profile.unitframes) or {}

''',
    'UnitFramesRender normalizer removal',
)
render_path.write_text(render, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
check = replace_once(
    check,
    "    assertSourceExcludes('modules/ActionBarsRuntime.lua', /\\bab\\.autoHide\\s*=(?!=)/, 'runtime action-bar profile normalization');\n\n",
    "    assertSourceExcludes('modules/ActionBarsRuntime.lua', /\\bab\\.autoHide\\s*=(?!=)/, 'runtime action-bar profile normalization');\n"
    "    assertSourceExcludes('modules/UnitFramesPolicy.lua', /profile\\s*\\[\\s*section\\s*\\]\\s*=/, 'runtime UnitFrames section creation');\n"
    "    assertSourceExcludes('modules/UnitFramesPolicy.lua', /function\\s+Policy\\.NormalizeUF/, 'runtime UnitFrames normalizer owner');\n"
    "    assertSourceExcludes('modules/UnitFramesRuntime.lua', /NormalizeUF/, 'runtime UnitFrames profile normalization call');\n"
    "    assertSourceExcludes('modules/UnitFramesRender.lua', /NormalizeUF/, 'render-time UnitFrames profile normalization call');\n"
    "    assertSourceIncludes('modules/UnitFramesPolicy.lua', 'local EMPTY = {}');\n\n",
    'UnitFrames config-purity contracts',
)
check_path.write_text(check, encoding='utf-8')

# Release metadata and documentation.
toc_path = Path('FeelsGoodUI.toc')
toc = toc_path.read_text(encoding='utf-8')
toc = replace_once(toc, '## Version: 0.0.51', '## Version: 0.0.52', 'TOC version')
toc_path.write_text(toc, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(readme, '- FeelsGoodUI `0.0.51`', '- FeelsGoodUI `0.0.52`', 'README version')
readme = replace_once(
    readme,
    'Unit Frames and Center Bars own those gates directly in their render paths:',
    'Unit Frames and Center Bars own those gates directly in their render paths. UnitFrames runtime/render paths are read-only consumers of normalized configuration: missing sections, sizes, and scales resolve through local immutable fallbacks and are repaired only by DB/Settings/schema owners, never while frames are being created or refreshed. Each restricted-value producer is queried once:',
    'README UnitFrames purity policy',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    '- Unit frames: `modules/UnitFrames.lua` configures `UnitFramesPolicy`, `UnitFramesRender`, `UnitFramesRuntime`, `UnitFramesTarget`, and `UnitFramesText`, using external `oUF` frames. `UnitFramesRuntime`/`UnitFramesTarget` attach event observers for target/name/faction/level/auras.',
    '- Unit frames: `modules/UnitFrames.lua` configures `UnitFramesPolicy`, `UnitFramesRender`, `UnitFramesRuntime`, `UnitFramesTarget`, and `UnitFramesText`, using external `oUF` frames. Policy getters are read-only and resolve missing sections/size/scale data locally; only DB/Settings/schema may repair persisted UnitFrames configuration. `UnitFramesRuntime`/`UnitFramesTarget` attach event observers for target/name/faction/level/auras.',
    'AGENT_GUIDE UnitFrames ownership',
)
agent = replace_once(
    agent,
    '- Unit-frame/center-bar runtime handlers are event-driven hot paths. Preserve caches and narrow unit filters; avoid per-event allocations and unsafe arithmetic/comparisons on secret values (`core/Secret.lua`, `modules/UnitFramesText.lua`).',
    '- Unit-frame/center-bar runtime handlers are event-driven hot paths. Preserve caches and narrow unit filters; avoid per-event allocations, persisted profile repair, and unsafe arithmetic/comparisons on secret values (`core/Secret.lua`, `modules/UnitFramesText.lua`).',
    'AGENT_GUIDE UnitFrames invariant',
)
agent_path.write_text(agent, encoding='utf-8')

index_path = Path('CODE_INDEX.md')
index = index_path.read_text(encoding='utf-8')
index = replace_once(
    index,
    '| `modules/UnitFrames*.lua` | Unit-frame runtime, render, policy, target, and text behavior. |',
    '| `modules/UnitFramesPolicy.lua` | Read-only UnitFrames configuration/cache policy, immutable fallbacks, and transactional mover write builders. |\n| `modules/UnitFramesRuntime.lua`, `modules/UnitFramesRender.lua`, `modules/UnitFramesTarget.lua`, `modules/UnitFramesText.lua`, `modules/UnitFrames.lua` | Unit-frame lifecycle, rendering, target/aura observers, text safety, and facade wiring without persisted configuration repair. |',
    'CODE_INDEX UnitFrames ownership',
)
index_path.write_text(index, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(todo, '- [x] Target Interface `120105` and release `0.0.51`.', '- [x] Target Interface `120105` and release `0.0.52`.', 'TODO version')
todo = replace_once(
    todo,
    '- [x] Make ActionBars native toggle takeover reversible: never copy Blizzard side-bar state into addon profile data, persist a per-character recovery vector across reload/interruption, avoid redundant `SetActionBarToggles` calls, and restore the exact pre-attach vector after out-of-combat or deferred detach.\n',
    '- [x] Make ActionBars native toggle takeover reversible: never copy Blizzard side-bar state into addon profile data, persist a per-character recovery vector across reload/interruption, avoid redundant `SetActionBarToggles` calls, and restore the exact pre-attach vector after out-of-combat or deferred detach.\n'
    '- [x] Make UnitFrames runtime configuration read-only: remove render/apply-time size/scale normalizers, stop getters from creating profile sections, and resolve missing values through local immutable fallbacks while DB/Settings/schema remain the only repair owners.\n',
    'TODO UnitFrames purity status',
)
todo = replace_once(
    todo,
    '- [ ] Player/target/focus/targettarget frames handle ordinary and restricted health/name/classification values without formatting errors or opaque readback.\n',
    '- [ ] Player/target/focus/targettarget frames handle ordinary and restricted health/name/classification values without formatting errors or opaque readback.\n'
    '- [ ] Remove a UnitFrames section/size/scale field in a test profile after DB initialization, then create/apply frames; runtime must use defaults without recreating or mutating the missing persisted field, while the next explicit DB/schema normalization repairs it.\n',
    'TODO UnitFrames purity validation',
)
todo_path.write_text(todo, encoding='utf-8')

matrix_path = Path('docs/REGRESSION_MATRIX_1_25.md')
matrix = matrix_path.read_text(encoding='utf-8')
matrix = replace_once(
    matrix,
    '| 13 | Apply/import/reset UnitFrame configuration | Runtime updates without stale values or unexpected profile mutation |  |  |',
    '| 13 | Apply/import/reset UnitFrame configuration, including a deliberately missing section/size/scale field after DB initialization | Runtime uses immutable defaults without render/apply-time profile repair; explicit DB/schema normalization remains the only persisted repair owner |  |  |',
    'regression matrix UnitFrames purity',
)
matrix_path.write_text(matrix, encoding='utf-8')

print('Hardened UnitFrames runtime configuration purity.')
