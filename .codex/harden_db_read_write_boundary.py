from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


db_path = Path('core/DB.lua')
db = db_path.read_text(encoding='utf-8')
old_get = r'''function DB:GetSection(section)
    if type(section) ~= "string" or section == "" then
        return nil
    end

    local profile = self:GetProfile()
    if type(profile) ~= "table" then
        return nil
    end

    local value = profile[section]
    if value ~= nil then
        return value
    end

    local defaults = self.defaults and self.defaults.profile
    local fallback = defaults and defaults[section] or nil
    if type(fallback) == "table" then
        return self:EnsureSection(section)
    end

    return fallback
end
'''
new_get = r'''function DB:ReadSection(section)
    if type(section) ~= "string" or section == "" then
        return nil
    end

    local profile = self:GetProfile()
    if type(profile) ~= "table" then
        return nil
    end

    local value = profile[section]
    if type(value) == "table" then
        return value
    end
    return nil
end

-- Compatibility reader. Persisted section creation belongs to EnsureSection.
function DB:GetSection(section)
    return self:ReadSection(section)
end
'''
db = replace_once(db, old_get, new_get, 'DB pure section reader')
db = replace_once(
    db,
    '    local actionbars = self:GetSection("actionbars")\n',
    '    local actionbars = self:ReadSection("actionbars")\n',
    'DB action-bar policy read',
)
db_path.write_text(db, encoding='utf-8')

readers = [
    'core/Theme.lua',
    'core/Safety.lua',
    'core/MinimapIcon.lua',
    'core/Perf.lua',
    'core/QA.lua',
    'core/Commands.lua',
    'core/MoversShared.lua',
    'modules/ActionBarsEditMode.lua',
    'modules/ActionBarsRuntime.lua',
    'modules/ActionBarsBlizzardShell.lua',
    'modules/CenterBars.lua',
    'modules/CompanionShared.lua',
]
for filename in readers:
    path = Path(filename)
    text = path.read_text(encoding='utf-8')
    before = text
    text = text.replace('DB.GetSection', 'DB.ReadSection')
    text = text.replace('DB:GetSection', 'DB:ReadSection')
    text = text.replace('db.GetSection', 'db.ReadSection')
    text = text.replace('db:GetSection', 'db:ReadSection')
    if text == before:
        raise RuntimeError(f'{filename}: no GetSection reader found')
    path.write_text(text, encoding='utf-8')

options_path = Path('core/OptionsSharedHelpers.lua')
options = options_path.read_text(encoding='utf-8')
options = replace_once(
    options,
    '''    if DB and DB.EnsureSection then
        root = DB:EnsureSection(path[1])
    elseif DB and DB.GetSection then
        root = DB:GetSection(path[1])
    end
''',
    '''    if DB and DB.EnsureSection then
        root = DB:EnsureSection(path[1])
    end
''',
    'Options write-root ownership',
)
options_path.write_text(options, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
check = replace_once(
    check,
    '''    for (const file of luaFiles) {
        const name = relative(file);
        const firstParty = name === 'FeelsGoodUI.lua'
            || name.startsWith('core/')
            || name.startsWith('modules/');
        if (firstParty && !tocSet.has(name)) {
            errors.push(`FeelsGoodUI.toc: first-party Lua file is not loaded: '${name}'`);
        }
    }

''',
    '''    for (const file of luaFiles) {
        const name = relative(file);
        const firstParty = name === 'FeelsGoodUI.lua'
            || name.startsWith('core/')
            || name.startsWith('modules/');
        if (firstParty && !tocSet.has(name)) {
            errors.push(`FeelsGoodUI.toc: first-party Lua file is not loaded: '${name}'`);
        }
        if (firstParty && name !== 'core/DB.lua') {
            const source = fs.readFileSync(file, 'utf8');
            if (/\\b(?:DB|db)(?:\\.|:)\\s*GetSection\\b/.test(source)) {
                errors.push(`${name}: use DB:ReadSection for reads or DB:EnsureSection for writes; GetSection is compatibility-only`);
            }
        }
    }

''',
    'global DB section ownership scan',
)
check = replace_once(
    check,
    "    assertBefore(tocEntries, 'core/Secret.lua', 'core/Utils.lua');\n",
    "    assertSourceIncludes('core/DB.lua', 'function DB:ReadSection(section)');\n"
    "    assertSourceIncludes('core/DB.lua', 'return self:ReadSection(section)');\n"
    "    assertSourceExcludes('core/DB.lua', /function DB:GetSection[\\s\\S]*?EnsureSection/, 'write-on-read DB compatibility path');\n\n"
    "    assertBefore(tocEntries, 'core/Secret.lua', 'core/Utils.lua');\n",
    'DB read/write static contracts',
)
check_path.write_text(check, encoding='utf-8')

# Release metadata and documentation.
toc_path = Path('FeelsGoodUI.toc')
toc = toc_path.read_text(encoding='utf-8')
toc = replace_once(toc, '## Version: 0.0.52', '## Version: 0.0.53', 'TOC version')
toc_path.write_text(toc, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(readme, '- FeelsGoodUI `0.0.52`', '- FeelsGoodUI `0.0.53`', 'README version')
readme = replace_once(
    readme,
    'UnitFrames runtime/render paths are read-only consumers of normalized configuration:',
    'Configuration access has an explicit read/write boundary: `DB:ReadSection` never creates or repairs SavedVariables, while `DB:EnsureSection` is reserved for Settings, migrations, and other validated write owners. Core presentation services and every feature runtime use the pure reader. UnitFrames runtime/render paths are read-only consumers of normalized configuration:',
    'README DB ownership policy',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    '`core/DB.lua:DB:Init` creates/migrates `FeelsGoodUIDB`, profiles, and sections.',
    '`core/DB.lua:DB:Init` creates/migrates `FeelsGoodUIDB`, profiles, and sections. `DB:ReadSection` is the non-mutating runtime reader; `DB:EnsureSection` is the explicit section-creation boundary and `DB:GetSection` is compatibility-only.',
    'AGENT_GUIDE DB boundary',
)
agent = replace_once(
    agent,
    '- Add or migrate a setting: `core/DB.lua` defaults/migration, `core/Settings.lua` validation/normalization, then the relevant options panel; use `Settings:SetTx` and `Apply:Request`.',
    '- Add or migrate a setting: `core/DB.lua` defaults/migration, `core/Settings.lua` validation/normalization, then the relevant options panel; use `Settings:SetTx` and `Apply:Request`. Runtime/core readers use `DB:ReadSection`; only validated write owners may call `DB:EnsureSection`.',
    'AGENT_GUIDE setting routing',
)
agent = replace_once(
    agent,
    '- Settings transaction rollback and apply-key ordering are correctness invariants:',
    '- Read paths must never create SavedVariables sections: `DB:GetSection` is not used by first-party runtime code, `DB:ReadSection` returns nil for missing/non-table sections, and repair is explicit through `DB:EnsureSection`/Settings/Schema.\n- Settings transaction rollback and apply-key ordering are correctness invariants:',
    'AGENT_GUIDE read ownership invariant',
)
agent_path.write_text(agent, encoding='utf-8')

index_path = Path('CODE_INDEX.md')
index = index_path.read_text(encoding='utf-8')
index = replace_once(
    index,
    '| `core/DB.lua`, `core/Schema.lua`, `core/Settings.lua`, `core/Apply.lua` | Saved variables, migrations, validated setting writes, apply ordering, and runtime restoration. |',
    '| `core/DB.lua`, `core/Schema.lua`, `core/Settings.lua`, `core/Apply.lua` | Saved variables, migrations, pure `ReadSection` vs explicit `EnsureSection`, validated setting writes, apply ordering, and runtime restoration. |',
    'CODE_INDEX DB boundary',
)
index_path.write_text(index, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(todo, '- [x] Target Interface `120105` and release `0.0.52`.', '- [x] Target Interface `120105` and release `0.0.53`.', 'TODO version')
todo = replace_once(
    todo,
    '- [x] Make UnitFrames runtime configuration read-only: remove render/apply-time size/scale normalizers, stop getters from creating profile sections, and resolve missing values through local immutable fallbacks while DB/Settings/schema remain the only repair owners.\n',
    '- [x] Make UnitFrames runtime configuration read-only: remove render/apply-time size/scale normalizers, stop getters from creating profile sections, and resolve missing values through local immutable fallbacks while DB/Settings/schema remain the only repair owners.\n'
    '- [x] Enforce one DB read/write boundary across core and feature families: `ReadSection` is pure, `EnsureSection` is explicit mutation, the compatibility `GetSection` no longer creates data, and static checks reject first-party runtime use of it.\n',
    'TODO DB boundary status',
)
todo = replace_once(
    todo,
    '- [ ] `/fgui qa` and `/fgui report` complete without legacy-field or schema failures.\n',
    '- [ ] `/fgui qa` and `/fgui report` complete without legacy-field or schema failures.\n'
    '- [ ] Remove a core/feature section after DB initialization, then open Theme, Safety, Minimap, QA, Movers, ActionBars, CenterBars, Companion and their settings panels; readers must not recreate the section, while one explicit `EnsureSection`/Settings normalization repairs it.\n',
    'TODO DB boundary validation',
)
todo_path.write_text(todo, encoding='utf-8')

matrix_path = Path('docs/REGRESSION_MATRIX_1_25.md')
matrix = matrix_path.read_text(encoding='utf-8')
matrix = replace_once(
    matrix,
    '| 27 | Open every settings page | Current profile values displayed; controls remain responsive |  |  |',
    '| 27 | Open every settings page | Current profile values displayed; controls remain responsive |  |  |\n'
    '| 27a | Delete one core/feature section after DB initialization, then exercise all runtime readers and settings pages | No read path recreates SavedVariables data; explicit `EnsureSection`/Settings normalization repairs the section once |  |  |',
    'regression matrix DB boundary',
)
matrix_path.write_text(matrix, encoding='utf-8')

print('Hardened DB section read/write ownership boundary.')
