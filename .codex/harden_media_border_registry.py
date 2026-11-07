from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


media_path = Path('core/Media.lua')
media = media_path.read_text(encoding='utf-8')
media = replace_once(
    media,
    'Media.LSM = LSM\n\n',
    'Media.LSM = LSM\n\nMedia._borderRegistry = Media._borderRegistry or setmetatable({}, { __mode = "k" })\nlocal BorderRegistry = Media._borderRegistry\n\n',
    'border registry declaration',
)
old_border = r'''-- 1px border (simple, fast, no complex backdrops).
function Media:CreateBorder(frame, size)
    -- Default to theme border size when not specified.
    local t = Theme and Theme.Get and Theme:Get() or nil
    local defaultSize = (t and t.style and t.style.borderSize) or 1
    size = (type(size) == "number") and size or defaultSize

    -- If border already exists, allow lightweight updates (size/color) without realloc.
    if frame.__fguiBorder then
        local b = frame.__fguiBorder
        if frame.__fguiBorderSize ~= size then
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", -size, size)
            b:SetPoint("BOTTOMRIGHT", size, -size)
            if b.SetBackdrop then
                local bd = b:GetBackdrop() or { edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = size }
                bd.edgeSize = size
                b:SetBackdrop(bd)
            end
            frame.__fguiBorderSize = size
        end
        -- Color refresh
        local bc = (t and t.colors and t.colors.border) or { r=0,g=0,b=0,a=1 }
        if b.SetBackdropBorderColor then
            b:SetBackdropBorderColor(bc.r or 0, bc.g or 0, bc.b or 0, bc.a or 1)
        end
        return b
    end

    local b = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    b:SetFrameLevel(frame:GetFrameLevel() + 1)
    b:SetPoint("TOPLEFT", -size, size)
    b:SetPoint("BOTTOMRIGHT", size, -size)

    b:SetBackdrop({
        edgeFile = "Interface/Buttons/WHITE8x8",
        edgeSize = size,
    })
    local bc = (t and t.colors and t.colors.border) or { r=0,g=0,b=0,a=1 }
    b:SetBackdropBorderColor(bc.r or 0, bc.g or 0, bc.b or 0, bc.a or 1)

    frame.__fguiBorder = b
    frame.__fguiBorderSize = size
    return b
end
'''
new_border = r'''local function ResolveBorderColor(theme)
    local color = theme and theme.colors and theme.colors.border or nil
    if type(color) ~= "table" then
        return 0, 0, 0, 1
    end
    return color.r or 0, color.g or 0, color.b or 0, color.a or 1
end

local function ApplyBorderGeometry(border, size)
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", -size, size)
    border:SetPoint("BOTTOMRIGHT", size, -size)
    if border.SetBackdrop then
        local backdrop = border:GetBackdrop() or {
            edgeFile = "Interface/Buttons/WHITE8x8",
            edgeSize = size,
        }
        backdrop.edgeSize = size
        border:SetBackdrop(backdrop)
    end
end

function Media:GetBorder(frame)
    local record = frame and BorderRegistry[frame] or nil
    return record and record.border or nil
end

function Media:SetBorderColor(frame, r, g, b, a)
    local border = self:GetBorder(frame)
    if not (border and type(border.SetBackdropBorderColor) == "function") then
        return false
    end
    border:SetBackdropBorderColor(r or 0, g or 0, b or 0, a or 0)
    return true
end

-- 1px border (simple, fast, no complex backdrops). Border ownership stays in
-- Media's weak-key registry; foreign Blizzard frames are never stamped with
-- addon-specific fields.
function Media:CreateBorder(frame, size)
    if not frame then return nil end

    local theme = Theme and Theme.Get and Theme:Get() or nil
    local defaultSize = (theme and theme.style and theme.style.borderSize) or 1
    size = (type(size) == "number") and size or defaultSize

    local record = BorderRegistry[frame]
    local border = record and record.border or nil
    if border then
        if record.size ~= size then
            ApplyBorderGeometry(border, size)
            record.size = size
        end
        local r, g, b, a = ResolveBorderColor(theme)
        if border.SetBackdropBorderColor then
            border:SetBackdropBorderColor(r, g, b, a)
        end
        return border
    end

    border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    border:SetFrameLevel(frame:GetFrameLevel() + 1)
    border:SetBackdrop({
        edgeFile = "Interface/Buttons/WHITE8x8",
        edgeSize = size,
    })
    ApplyBorderGeometry(border, size)

    local r, g, b, a = ResolveBorderColor(theme)
    border:SetBackdropBorderColor(r, g, b, a)

    BorderRegistry[frame] = {
        border = border,
        size = size,
    }
    return border
end
'''
media = replace_once(media, old_border, new_border, 'Media border owner')
media_path.write_text(media, encoding='utf-8')

pet_path = Path('modules/CompanionPetBar.lua')
pet = pet_path.read_text(encoding='utf-8')
pet = replace_once(
    pet,
    '''    if button.__fguiBorder and button.__fguiBorder.SetBackdropBorderColor then
        button.__fguiBorder:SetBackdropBorderColor(0, 0, 0, 0)
    end
''',
    '''    if Media and type(Media.SetBorderColor) == "function" then
        Media:SetBorderColor(button, 0, 0, 0, 0)
    end
''',
    'PetBar border release adapter',
)
pet_path.write_text(pet, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
check = replace_once(
    check,
    '''        if (firstParty && name !== 'core/DB.lua') {
            const source = fs.readFileSync(file, 'utf8');
            if (/\\b(?:DB|db)(?:\\.|:)\\s*GetSection\\b/.test(source)) {
                errors.push(`${name}: use DB:ReadSection for reads or DB:EnsureSection for writes; GetSection is compatibility-only`);
            }
        }
''',
    '''        if (firstParty) {
            const source = fs.readFileSync(file, 'utf8');
            if (name !== 'core/DB.lua' && /\\b(?:DB|db)(?:\\.|:)\\s*GetSection\\b/.test(source)) {
                errors.push(`${name}: use DB:ReadSection for reads or DB:EnsureSection for writes; GetSection is compatibility-only`);
            }
            if (/__fguiBorder(?:Size)?/.test(source)) {
                errors.push(`${name}: border ownership must stay in Media's registry, not on target frames`);
            }
        }
''',
    'global border marker scan',
)
check = replace_once(
    check,
    "    assertSourceIncludes('modules/CenterBarsRender.lua', 'owner._classResourceSuppression');\n",
    "    assertSourceIncludes('core/Media.lua', 'Media._borderRegistry');\n"
    "    assertSourceIncludes('core/Media.lua', 'function Media:GetBorder(frame)');\n"
    "    assertSourceIncludes('core/Media.lua', 'function Media:SetBorderColor(frame, r, g, b, a)');\n"
    "    assertSourceIncludes('modules/CompanionPetBar.lua', 'Media:SetBorderColor(button, 0, 0, 0, 0)');\n\n"
    "    assertSourceIncludes('modules/CenterBarsRender.lua', 'owner._classResourceSuppression');\n",
    'Media border registry contracts',
)
check_path.write_text(check, encoding='utf-8')

# Release metadata and documentation.
toc_path = Path('FeelsGoodUI.toc')
toc = toc_path.read_text(encoding='utf-8')
toc = replace_once(toc, '## Version: 0.0.56', '## Version: 0.0.57', 'TOC version')
toc_path.write_text(toc, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(readme, '- FeelsGoodUI `0.0.56`', '- FeelsGoodUI `0.0.57`', 'README version')
readme = replace_once(
    readme,
    'Each restricted-value producer is queried once: each producer is queried once, ordinary data stays on the normal path,',
    'Each restricted-value producer is queried once, ordinary data stays on the normal path,',
    'README duplicate phrase cleanup',
)
readme = replace_once(
    readme,
    'CenterBars follows the same narrow policy for Blizzard class-resource frames: owner-local snapshots and hooks replace foreign-frame markers, frame replacement restores the old instance before adopting the new one, and combat-deferred sync never guesses visibility or calls native setup.',
    'CenterBars follows the same narrow policy for Blizzard class-resource frames: owner-local snapshots and hooks replace foreign-frame markers, frame replacement restores the old instance before adopting the new one, and combat-deferred sync never guesses visibility or calls native setup. Styling helpers follow the same boundary: `Media:CreateBorder` keeps border records in a weak-key owner registry and never writes `__fgui*` metadata onto Blizzard or third-party frames.',
    'README Media ownership policy',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    '- Minimap: `core/MinimapIcon.lua` passes a detached runtime proxy to LibDBIcon, hooks drag start/stop, and commits only the terminal position through Settings/Apply; never pass the live `profile.minimap` table to third-party code.\n',
    '- Media: `core/Media.lua` owns borders through a weak-key registry keyed by target frame; consumers use `CreateBorder`, `GetBorder`, and `SetBorderColor` and never stamp addon metadata onto Blizzard/third-party frames.\n- Minimap: `core/MinimapIcon.lua` passes a detached runtime proxy to LibDBIcon, hooks drag start/stop, and commits only the terminal position through Settings/Apply; never pass the live `profile.minimap` table to third-party code.\n',
    'AGENT_GUIDE Media owner',
)
agent = replace_once(
    agent,
    '- Foreign Blizzard-frame takeover must mutate the narrowest properties, capture them before first write, avoid duplicate lifecycle owners, and restore only values still owned by the addon.\n',
    '- Foreign Blizzard-frame takeover must mutate the narrowest properties, capture them before first write, avoid duplicate lifecycle owners, restore only values still owned by the addon, and keep all ownership metadata on addon-owned registries rather than foreign frame fields.\n',
    'AGENT_GUIDE foreign metadata invariant',
)
agent_path.write_text(agent, encoding='utf-8')

index_path = Path('CODE_INDEX.md')
index = index_path.read_text(encoding='utf-8')
index = replace_once(
    index,
    '| `core/RuntimeSettings.lua` | Canonical apply owner for general runtime state: logging level and performance overlay. |',
    '| `core/RuntimeSettings.lua` | Canonical apply owner for general runtime state: logging level and performance overlay. |\n| `core/Media.lua` | Media lookup, icon crop/font helpers, and weak-key border ownership without foreign-frame metadata. |',
    'CODE_INDEX Media owner',
)
index_path.write_text(index, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(todo, '- [x] Target Interface `120105` and release `0.0.56`.', '- [x] Target Interface `120105` and release `0.0.57`.', 'TODO version')
todo = replace_once(
    todo,
    '- [x] Make CenterBars class-resource takeover narrow and reversible: keep snapshots/hooks on the owner, never stamp or Hide/Show/Setup foreign frames, handle native frame replacement, and preserve newer conflicting alpha/mouse changes on release.\n',
    '- [x] Make CenterBars class-resource takeover narrow and reversible: keep snapshots/hooks on the owner, never stamp or Hide/Show/Setup foreign frames, handle native frame replacement, and preserve newer conflicting alpha/mouse changes on release.\n'
    '- [x] Move border ownership out of target frames: `Media` now keeps weak-key records, exposes explicit lookup/color APIs, and static validation rejects `__fguiBorder*` metadata anywhere in first-party Lua.\n',
    'TODO Media ownership status',
)
todo = replace_once(
    todo,
    '- [ ] Give Blizzard status-tracking manager/containers distinctive alpha, mouse and visibility states, enable/disable ExperienceBar repeatedly, trigger native refreshes, and verify no foreign `Hide`/`Show`, one lifecycle apply, exact owned-property restore, and preservation of conflicting newer changes.\n',
    '- [ ] Give Blizzard status-tracking manager/containers distinctive alpha, mouse and visibility states, enable/disable ExperienceBar repeatedly, trigger native refreshes, and verify no foreign `Hide`/`Show`, one lifecycle apply, exact owned-property restore, and preservation of conflicting newer changes.\n'
    '- [ ] Repeatedly skin and restore Blizzard pet/micro/bag buttons; border frames are reused through `Media` without any `__fguiBorder*` fields on the target buttons, and transparent release is reversed by the next theme/style apply.\n',
    'TODO Media ownership validation',
)
todo_path.write_text(todo, encoding='utf-8')

matrix_path = Path('docs/REGRESSION_MATRIX_1_25.md')
matrix = matrix_path.read_text(encoding='utf-8')
matrix = replace_once(
    matrix,
    '| 22 | Companion micro menu, bags, and pet bar lifecycle | Controls attach, update, restore, and detach without duplicate ownership |  |  |',
    '| 22 | Companion micro menu, bags, and pet bar lifecycle, including repeated border restyling | Controls attach, update, restore, and detach without duplicate ownership; border objects are reused and target Blizzard frames receive no `__fguiBorder*` metadata |  |  |',
    'regression matrix Media border ownership',
)
matrix_path.write_text(matrix, encoding='utf-8')

print('Moved Media border ownership into a weak-key registry.')
