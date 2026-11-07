from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


path = Path('core/MinimapIcon.lua')
text = path.read_text(encoding='utf-8')
text = replace_once(
    text,
    '''local dataObj
local isRegistered = false
''',
    '''local dataObj
local isRegistered = false
local runtimeCfg = {}
local dragging = false
''',
    'Minimap runtime proxy state',
)

helpers = r'''local function ResolvePosition(value)
    local position = tonumber(value)
    if type(position) ~= "number" then position = 220 end
    if position < 0 then position = 0 end
    if position > 360 then position = 360 end
    return math.floor(position + 0.5)
end

local function SyncRuntimeCfg(cfg)
    runtimeCfg.hide = cfg and cfg.hide == true or false
    runtimeCfg.minimapPos = ResolvePosition(cfg and cfg.minimapPos)
    runtimeCfg.lock = cfg and cfg.lock == true and true or nil
    runtimeCfg.showInCompartment = cfg and cfg.showInCompartment == true and true or nil
    return runtimeCfg
end

local function RefreshRuntimeCfg(cfg)
    if type(cfg) ~= "table" then return false end
    SyncRuntimeCfg(cfg)
    if LDBIcon and isRegistered and type(LDBIcon.Refresh) == "function" then
        LDBIcon:Refresh(addonName, runtimeCfg)
    end
    return true
end

'''
text = replace_once(
    text,
    'local function EnsureDataObject()\n',
    helpers + 'local function EnsureDataObject()\n',
    'Minimap runtime proxy helpers',
)

transaction_helpers = r'''local function RestoreRuntimeFromProfile()
    local cfg = GetCfg()
    if not cfg then return false end
    return RefreshRuntimeCfg(cfg)
end

local function CommitDraggedPosition()
    local position = ResolvePosition(runtimeCfg.minimapPos)
    runtimeCfg.minimapPos = position

    if not HasWriteOwner() then
        RestoreRuntimeFromProfile()
        return false
    end

    local changed, stored = SetTx(
        { "minimap", "minimapPos" },
        position,
        { type = "int", min = 0, max = 360, fallback = 220 }
    )
    if changed == true then
        runtimeCfg.minimapPos = ResolvePosition(stored)
        RequestApply()
        return true
    end

    RestoreRuntimeFromProfile()
    return false
end

local function EnsureDragHooks()
    if not (LDBIcon and type(LDBIcon.GetMinimapButton) == "function") then
        return false
    end

    local button = LDBIcon:GetMinimapButton(addonName)
    if not (button and type(button.HookScript) == "function") then
        return false
    end
    if button._fguiTransactionalDragHooked then
        return true
    end

    button._fguiTransactionalDragHooked = true
    button:HookScript("OnDragStart", function()
        dragging = true
    end)
    button:HookScript("OnDragStop", function()
        if not dragging then return end
        dragging = false

        local ok, err = xpcall(CommitDraggedPosition, function(reason)
            return tostring(reason or "unknown minimap drag commit error")
        end)
        if not ok then
            RestoreRuntimeFromProfile()
            if Log and type(Log.Error) == "function" then
                Log:Error("Minimap drag commit failed: " .. tostring(err))
            end
        end
    end)
    return true
end

'''
text = replace_once(
    text,
    'function MinimapIcon:Init()\n',
    transaction_helpers + 'function MinimapIcon:Init()\n',
    'Minimap drag transaction helpers',
)

old_attach = r'''    if not isRegistered then
        LDBIcon:Register(addonName, obj, cfg)
        isRegistered = true
    end

    return true
end
'''
new_attach = r'''    SyncRuntimeCfg(cfg)
    if not isRegistered then
        LDBIcon:Register(addonName, obj, runtimeCfg)
        isRegistered = true
    else
        LDBIcon:Refresh(addonName, runtimeCfg)
    end
    EnsureDragHooks()

    return true
end
'''
text = replace_once(text, old_attach, new_attach, 'Minimap attach proxy ownership')

old_detach = r'''function MinimapIcon:Detach()
    if LDBIcon and isRegistered then
        LDBIcon:Hide(addonName)
    end
    return true
end
'''
new_detach = r'''function MinimapIcon:Detach()
    if LDBIcon and isRegistered then
        if dragging and type(LDBIcon.GetMinimapButton) == "function" then
            local button = LDBIcon:GetMinimapButton(addonName)
            if button and type(button.SetScript) == "function" then
                button:SetScript("OnUpdate", nil)
            end
            dragging = false
            RestoreRuntimeFromProfile()
        end
        LDBIcon:Hide(addonName)
    end
    return true
end
'''
text = replace_once(text, old_detach, new_detach, 'Minimap detach drag cancellation')

old_apply = r'''    LDBIcon:Refresh(addonName, cfg)
    if cfg.hide == true then
        LDBIcon:Hide(addonName)
    else
        LDBIcon:Show(addonName)
    end
    return true
end
'''
new_apply = r'''    if dragging then
        return false, "Minimap apply blocked while icon drag is active"
    end

    RefreshRuntimeCfg(cfg)
    EnsureDragHooks()
    if runtimeCfg.hide == true then
        LDBIcon:Hide(addonName)
    else
        LDBIcon:Show(addonName)
    end
    return true
end
'''
text = replace_once(text, old_apply, new_apply, 'Minimap apply proxy ownership')
path.write_text(text, encoding='utf-8')

# Remove the dead addon-owned radius/angle fields. LibDBIcon radius is global,
# so feeding one addon's profile into it would change every registered icon.
db_path = Path('core/DB.lua')
db = db_path.read_text(encoding='utf-8')
db = replace_once(
    db,
    '''        minimap = {
            hide = false,
            minimapPos = 220, -- degrees around minimap center
            radius = 80,
        },
''',
    '''        minimap = {
            hide = false,
            minimapPos = 220, -- degrees around minimap center
        },
''',
    'remove dead minimap radius default',
)
db_path.write_text(db, encoding='utf-8')

settings_path = Path('core/Settings.lua')
settings = settings_path.read_text(encoding='utf-8')
settings = replace_once(
    settings,
    '''    mm.hide = ValidateBoolean(mm.hide, false)
    mm.minimapPos = ValidateNumber(mm.minimapPos, 0, 360, 220, true)
    mm.radius = ValidateNumber(mm.radius, 40, 200, 80, true)
''',
    '''    mm.hide = ValidateBoolean(mm.hide, false)
    mm.minimapPos = ValidateNumber(mm.minimapPos, 0, 360, 220, true)
    mm.radius = nil
    mm.angle = nil
''',
    'retire dead minimap fields',
)
settings_path.write_text(settings, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
check = replace_once(
    check,
    "    assertSourceIncludes('core/DB.lua', 'function DB:ReadSection(section)');\n",
    "    assertSourceIncludes('core/MinimapIcon.lua', 'local runtimeCfg = {}');\n"
    "    assertSourceIncludes('core/MinimapIcon.lua', 'EnsureDragHooks');\n"
    "    assertSourceIncludes('core/MinimapIcon.lua', 'CommitDraggedPosition');\n"
    "    assertSourceIncludes('core/MinimapIcon.lua', 'LDBIcon:Register(addonName, obj, runtimeCfg)');\n"
    "    assertSourceExcludes('core/MinimapIcon.lua', /LDBIcon:Register\\(addonName,\\s*obj,\\s*cfg\\)/, 'live minimap profile registration');\n"
    "    assertSourceExcludes('core/MinimapIcon.lua', /LDBIcon:Refresh\\(addonName,\\s*cfg\\)/, 'live minimap profile refresh');\n"
    "    assertSourceExcludes('core/DB.lua', /minimapPos:\\s*220[\\s\\S]{0,120}radius\\s*=/, 'dead minimap radius default');\n"
    "    assertSourceExcludes('core/Settings.lua', /mm\\.radius\\s*=\\s*ValidateNumber/, 'dead minimap radius normalization');\n\n"
    "    assertSourceIncludes('core/DB.lua', 'function DB:ReadSection(section)');\n",
    'Minimap ownership static contracts',
)
check_path.write_text(check, encoding='utf-8')

# Release metadata and documentation.
toc_path = Path('FeelsGoodUI.toc')
toc = toc_path.read_text(encoding='utf-8')
toc = replace_once(toc, '## Version: 0.0.53', '## Version: 0.0.54', 'TOC version')
toc_path.write_text(toc, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(readme, '- FeelsGoodUI `0.0.53`', '- FeelsGoodUI `0.0.54`', 'README version')
readme = replace_once(
    readme,
    'General commands and options never write runtime settings directly:',
    'Minimap drag uses a detached LibDBIcon runtime proxy: per-frame movement never touches SavedVariables, mouse-up creates one validated `Settings:SetTx` transaction, and failed apply/cancel restores the persisted position. The dead addon `radius` field is removed because LibDBIcon radius is library-global rather than per button. General commands and options never write runtime settings directly:',
    'README minimap transaction policy',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    '- Options/minimap/commands are adapters over Settings/Apply.',
    '- Minimap: `core/MinimapIcon.lua` passes a detached runtime proxy to LibDBIcon, hooks drag start/stop, and commits only the terminal position through Settings/Apply; never pass the live `profile.minimap` table to third-party code.\n- Options/minimap/commands are adapters over Settings/Apply.',
    'AGENT_GUIDE minimap ownership',
)
agent = replace_once(
    agent,
    '- Read paths must never create SavedVariables sections:',
    '- Third-party runtime adapters must not receive live SavedVariables tables when they can mutate them; use detached proxies and translate terminal changes into validated Settings transactions.\n- Read paths must never create SavedVariables sections:',
    'AGENT_GUIDE third-party mutation invariant',
)
agent_path.write_text(agent, encoding='utf-8')

index_path = Path('CODE_INDEX.md')
index = index_path.read_text(encoding='utf-8')
index = replace_once(
    index,
    '| `core/Options*.lua`, `core/Movers*.lua`, `core/Commands.lua` | Settings pages, frame editing/movement UI, and command adapters over Settings/Apply. |',
    '| `core/MinimapIcon.lua` | LibDBIcon runtime proxy, terminal drag-position transaction, visibility apply owner, and rollback reconciliation. |\n| `core/Options*.lua`, `core/Movers*.lua`, `core/Commands.lua` | Settings pages, frame editing/movement UI, and command adapters over Settings/Apply. |',
    'CODE_INDEX minimap owner',
)
index_path.write_text(index, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(todo, '- [x] Target Interface `120105` and release `0.0.53`.', '- [x] Target Interface `120105` and release `0.0.54`.', 'TODO version')
todo = replace_once(
    todo,
    '- [x] Enforce one DB read/write boundary across core and feature families: `ReadSection` is pure, `EnsureSection` is explicit mutation, the compatibility `GetSection` no longer creates data, and static checks reject first-party runtime use of it.\n',
    '- [x] Enforce one DB read/write boundary across core and feature families: `ReadSection` is pure, `EnsureSection` is explicit mutation, the compatibility `GetSection` no longer creates data, and static checks reject first-party runtime use of it.\n'
    '- [x] Isolate LibDBIcon from SavedVariables: use a detached minimap proxy during drag, commit one normalized position on drag stop, restore persisted state on failure/cancel, and remove the dead per-addon radius field.\n',
    'TODO minimap status',
)
todo = replace_once(
    todo,
    '- [ ] Show/hide/reset the minimap icon from settings and slash commands; position reset is one undo action and failed `LibDBIcon` apply rolls back hide/position values.\n',
    '- [ ] Show/hide/reset and drag the minimap icon from settings and slash commands; OnUpdate performs zero SavedVariables writes, drag stop creates one undoable transaction, no-op drag creates none, and failed apply/cancel restores the persisted position.\n',
    'TODO minimap validation',
)
todo_path.write_text(todo, encoding='utf-8')

matrix_path = Path('docs/REGRESSION_MATRIX_1_25.md')
matrix = matrix_path.read_text(encoding='utf-8')
matrix = replace_once(
    matrix,
    '| 24 | Theme/media/minimap icon/profile switch | Fonts, textures, colors, icon actions, and profile refresh remain coherent |  |  |',
    '| 24 | Theme/media/minimap icon/profile switch; drag icon and force one minimap apply failure | Fonts/textures/colors remain coherent; drag preview writes only the proxy, mouse-up commits once, no-op drag creates no transaction, and failure restores the persisted position |  |  |',
    'regression matrix minimap transaction',
)
matrix_path.write_text(matrix, encoding='utf-8')

print('Hardened transactional minimap drag ownership.')
