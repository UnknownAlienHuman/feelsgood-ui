from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


toc_path = Path('FeelsGoodUI.toc')
toc = toc_path.read_text(encoding='utf-8')
toc = replace_once(
    toc,
    'modules/CompanionShared.lua\nmodules/CompanionPetBar.lua\n',
    'modules/CompanionShared.lua\nmodules/CompanionPetState.lua\nmodules/CompanionPetBar.lua\n',
    'CompanionPetState TOC order',
)
toc = replace_once(toc, '## Version: 0.0.58', '## Version: 0.0.59', 'TOC version')
toc_path.write_text(toc, encoding='utf-8')

pet_path = Path('modules/CompanionPetBar.lua')
pet = pet_path.read_text(encoding='utf-8')
pet = replace_once(
    pet,
    '''local Theme = ns.Theme
local Shared = ns.CompanionShared

local PET_VISIBILITY_DRIVER''',
    '''local Theme = ns.Theme
local Shared = ns.CompanionShared
local PetState = ns.CompanionPetState

assert(PetState, "FeelsGoodUI: CompanionPetState not loaded")

local PET_VISIBILITY_DRIVER''',
    'PetState dependency',
)

components = r'''local function BuildPetButtonComponents(button)
    local hotkey = button and button.HotKey or nil
    if not hotkey and button and button.GetName then
        local name = button:GetName()
        if name then hotkey = _G[name .. "HotKey"] end
    end

    return {
        icon = GetPetButtonIcon(button),
        highlight = button and button.GetHighlightTexture and button:GetHighlightTexture() or nil,
        cooldown = button and button.cooldown or nil,
        iconMask = button and button.IconMask or nil,
        name = button and button.Name or nil,
        hotkey = hotkey,
        alphas = {
            normal = button and button.GetNormalTexture and button:GetNormalTexture() or nil,
            pushed = button and button.GetPushedTexture and button:GetPushedTexture() or nil,
            checked = button and button.GetCheckedTexture and button:GetCheckedTexture() or nil,
            slotBackground = button and button.SlotBackground or nil,
            slotArt = button and button.SlotArt or nil,
            border = button and button.Border or nil,
            newAction = button and button.NewActionTexture or nil,
            spellHighlight = button and button.SpellHighlightTexture or nil,
        },
    }
end

'''
pet = replace_once(
    pet,
    'local function StylePetButton(button, size, showHotkeys, profile)\n',
    components + 'local function StylePetButton(button, size, showHotkeys, profile)\n',
    'pet component builder',
)

restore_start = pet.index('local function ResetPetButtonParent')
restore_end = pet.index('function PetBar:Apply', restore_start)
refresh = r'''local function RefreshBlizzardPetBar()
    local petBar = _G.PetActionBar
    if not petBar then return end

    local function Call(name, ...)
        local method = petBar[name]
        if type(method) == "function" then
            pcall(method, petBar, ...)
        end
    end

    Call("UpdateShownButtons")
    Call("MarkGridLayoutDirty")
    if type(petBar.RefreshGridLayout) == "function" then
        Call("RefreshGridLayout")
    else
        Call("UpdateGridLayout")
    end

    if type(petBar.RefreshBarArt) == "function" then
        Call("RefreshBarArt", true)
    elseif type(petBar.SetBackgroundArtShown) == "function"
        and type(petBar.ShouldShowBackgroundArt) == "function" then
        local ok, shown = pcall(petBar.ShouldShowBackgroundArt, petBar)
        if ok then Call("SetBackgroundArtShown", shown) end
    end

    Call("Update")
    Call("UpdateVisibility")
end

'''
pet = pet[:restore_start] + refresh + pet[restore_end:]

old_apply = r'''function PetBar:Apply(module, cp, profile)
    if not (module and cp) then return false, "Companion pet-bar apply owner unavailable" end
    if Shared:IsInCombat() then
        module._pendingAfterCombat = true
        return false, "Companion pet-bar apply deferred in combat"
    end

    local holder = EnsurePetAnchor(module)
    if not holder then return false, "Companion pet-bar holder unavailable" end

    holder:Show()
    Shared:ApplyFrameLayer(holder, cp.petBar.strata, cp.petBar.level)

    local size = cp.buttonSize or 32
    local spacing = cp.spacing or 0
    local width = (Shared.PET_BUTTONS * size) + ((Shared.PET_BUTTONS - 1) * spacing)
    holder:SetSize(width, size)

    if _G.PetActionBar then
        pcall(_G.PetActionBar.SetAlpha, _G.PetActionBar, 0)
    end

    local allReady = true
    for i = 1, Shared.PET_BUTTONS do
        local button = _G["PetActionButton" .. i]
        if not button then
            allReady = false
        else
            button:SetParent(holder)
            button:ClearAllPoints()
            button:SetPoint("LEFT", holder, "LEFT", (i - 1) * (size + spacing), 0)
            StylePetButton(button, size, cp.petBar.showHotkeys == true, profile)
            button:Show()
        end
    end

    if not allReady then
        module._pendingPetButtons = true
        module._pendingAfterCombat = true
        return true, "Pet action buttons pending runtime creation"
    end

    module._pendingPetButtons = nil
    module._pendingAfterCombat = nil
    return true
end
'''
new_apply = r'''function PetBar:Apply(module, cp, profile)
    if not (module and cp) then return false, "Companion pet-bar apply owner unavailable" end
    if Shared:IsInCombat() then
        module._pendingAfterCombat = true
        return false, "Companion pet-bar apply deferred in combat"
    end

    local holder = EnsurePetAnchor(module)
    if not holder then return false, "Companion pet-bar holder unavailable" end

    local nativeOK, nativeDetail = PetState:SuppressNativeBar(module, _G.PetActionBar)
    if nativeOK ~= true then
        return false, nativeDetail or "Native pet bar could not be suppressed reversibly"
    end

    holder:Show()
    Shared:ApplyFrameLayer(holder, cp.petBar.strata, cp.petBar.level)

    local size = cp.buttonSize or 32
    local spacing = cp.spacing or 0
    local width = (Shared.PET_BUTTONS * size) + ((Shared.PET_BUTTONS - 1) * spacing)
    holder:SetSize(width, size)

    local allReady = true
    for i = 1, Shared.PET_BUTTONS do
        local button = _G["PetActionButton" .. i]
        if not button then
            PetState:ReleaseButton(module, i)
            allReady = false
        else
            local components = BuildPetButtonComponents(button)
            local captured, captureDetail = PetState:BeginButton(module, i, button, components)
            if captured ~= true then
                PetState:RestoreAll(module)
                holder:Hide()
                return false, captureDetail or "Pet action button state capture failed"
            end

            button:SetParent(holder)
            button:ClearAllPoints()
            button:SetPoint("LEFT", holder, "LEFT", (i - 1) * (size + spacing), 0)
            StylePetButton(button, size, cp.petBar.showHotkeys == true, profile)
            button:Show()

            local finished, finishDetail = PetState:FinishButton(module, i, button, components)
            if finished ~= true then
                PetState:RestoreAll(module)
                holder:Hide()
                return false, finishDetail or "Managed pet action button state capture failed"
            end
        end
    end

    if not allReady then
        module._pendingPetButtons = true
        module._pendingAfterCombat = true
        return true, "Pet action buttons pending runtime creation"
    end

    module._pendingPetButtons = nil
    module._pendingAfterCombat = nil
    return true
end
'''
pet = replace_once(pet, old_apply, new_apply, 'snapshot-aware pet apply')

old_restore = r'''function PetBar:RestoreDefaultLayout(module)
    if not module then
        return false
    end

    local holder = module._petAnchor
    if holder and type(_G.UnregisterStateDriver) == "function" then
        pcall(_G.UnregisterStateDriver, holder, "visibility")
    end

    for i = 1, Shared.PET_BUTTONS do
        RestorePetButton(_G["PetActionButton" .. i])
    end

    RefreshBlizzardPetBar()

    if holder and holder.Hide then
        holder:Hide()
    end

    return true
end
'''
new_restore = r'''function PetBar:RestoreDefaultLayout(module)
    if not module then return false end

    local holder = module._petAnchor
    if holder and type(_G.UnregisterStateDriver) == "function" then
        pcall(_G.UnregisterStateDriver, holder, "visibility")
    end

    PetState:RestoreAll(module)
    RefreshBlizzardPetBar()

    if holder and holder.Hide then holder:Hide() end
    module._pendingPetButtons = nil
    return true
end
'''
pet = replace_once(pet, old_restore, new_restore, 'snapshot-aware pet restore')
pet_path.write_text(pet, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
check = replace_once(
    check,
    "    assertBefore(tocEntries, 'modules/CenterBarsRender.lua', 'modules/CenterBars.lua');\n",
    "    assertBefore(tocEntries, 'modules/CenterBarsRender.lua', 'modules/CenterBars.lua');\n"
    "    assertBefore(tocEntries, 'modules/CompanionPetState.lua', 'modules/CompanionPetBar.lua');\n",
    'PetState TOC contract',
)
check = replace_once(
    check,
    "    assertSourceIncludes('modules/CompanionMicroBags.lua', 'module._microSourceHooks');\n",
    "    assertSourceIncludes('modules/CompanionPetState.lua', 'function State:BeginButton');\n"
    "    assertSourceIncludes('modules/CompanionPetState.lua', 'function State:FinishButton');\n"
    "    assertSourceIncludes('modules/CompanionPetState.lua', 'function State:SuppressNativeBar');\n"
    "    assertSourceIncludes('modules/CompanionPetState.lua', 'function State:RestoreAll');\n"
    "    assertSourceIncludes('modules/CompanionPetBar.lua', 'PetState:BeginButton');\n"
    "    assertSourceIncludes('modules/CompanionPetBar.lua', 'PetState:FinishButton');\n"
    "    assertSourceIncludes('modules/CompanionPetBar.lua', 'PetState:RestoreAll(module)');\n"
    "    assertSourceExcludes('modules/CompanionPetBar.lua', /RestoreTextureAlpha/, 'default-value pet texture restore');\n"
    "    assertSourceExcludes('modules/CompanionPetBar.lua', /ResetPetButtonParent/, 'guessed pet-button parent restore');\n"
    "    assertSourceExcludes('modules/CompanionPetBar.lua', /pcall\\(_G\\.PetActionBar\\.SetAlpha/, 'direct native pet-bar alpha takeover');\n\n"
    "    assertSourceIncludes('modules/CompanionMicroBags.lua', 'module._microSourceHooks');\n",
    'PetState source contracts',
)
check_path.write_text(check, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(readme, '- FeelsGoodUI `0.0.58`', '- FeelsGoodUI `0.0.59`', 'README version')
readme = replace_once(
    readme,
    'Companion micro-menu/bag hook state, compact-count font strings, and summaries likewise live on the Companion owner; layer apply functions return explicit results, a failed layer restores already-applied presentation before reporting failure, and transient pet-button creation is queued for an event-driven retry instead of disabling the feature.',
    'Companion micro-menu/bag hook state, compact-count font strings, and summaries likewise live on the Companion owner; layer apply functions return explicit results, a failed layer restores already-applied presentation before reporting failure, and transient pet-button creation is queued for an event-driven retry instead of disabling the feature. PetActionButton takeover is journaled property-by-property in `CompanionPetState`: original and managed parent/points/size/visibility, textures, masks, text, cooldown and native PetActionBar alpha restore only while still addon-owned, so newer external changes are preserved.',
    'README pet snapshot policy',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    '- Companion: `CompanionRuntime` coordinates PetBar and MicroBags as result-bearing layers; hook registries, compact count objects, and summaries live on the Companion owner, never on Blizzard buttons. A failed layer restores partial companion presentation and propagates failure to Apply/Lifecycle; missing PetActionButton frames are transient queued work, not a fatal lifecycle failure.',
    '- Companion: `CompanionRuntime` coordinates PetBar and MicroBags as result-bearing layers; hook registries, compact count objects, and summaries live on the Companion owner, never on Blizzard buttons. `CompanionPetState` journals exact original/managed PetActionButton and native PetActionBar properties and restores only still-owned values. A failed layer restores partial presentation and propagates failure to Apply/Lifecycle; missing PetActionButton frames are transient queued work, not a fatal lifecycle failure.',
    'AGENT_GUIDE PetState owner',
)
agent_path.write_text(agent, encoding='utf-8')

index_path = Path('CODE_INDEX.md')
index = index_path.read_text(encoding='utf-8')
index = replace_once(
    index,
    '| `modules/CompanionMicroBags.lua`, `modules/CompanionPetBar.lua`, `modules/CompanionShared.lua` | Owner-local hook/cache state plus pet-bar, micro-menu, and bag presentation layers. |',
    '| `modules/CompanionPetState.lua` | Exact original/managed PetActionButton and native PetActionBar snapshot journal with conflict-aware restore. |\n| `modules/CompanionMicroBags.lua`, `modules/CompanionPetBar.lua`, `modules/CompanionShared.lua` | Owner-local hook/cache state plus pet-bar, micro-menu, and bag presentation layers. |',
    'CODE_INDEX PetState owner',
)
index_path.write_text(index, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(todo, '- [x] Target Interface `120105` and release `0.0.58`.', '- [x] Target Interface `120105` and release `0.0.59`.', 'TODO version')
todo = replace_once(
    todo,
    '- [x] Move Companion hooks/count caches/summaries off Blizzard frames and make PetBar/MicroBags apply result-aware; failed layers clean partial presentation, while transient PetActionButton creation queues an event-driven retry instead of disabling Companion.\n',
    '- [x] Move Companion hooks/count caches/summaries off Blizzard frames and make PetBar/MicroBags apply result-aware; failed layers clean partial presentation, while transient PetActionButton creation queues an event-driven retry instead of disabling Companion.\n'
    '- [x] Journal PetActionButton takeover in `CompanionPetState`: exact original and managed layout/visibility/texture/text/cooldown/native-bar-alpha properties restore only when still addon-owned, preserving newer external changes and frame replacement.\n',
    'TODO PetState status',
)
todo = replace_once(
    todo,
    '- [ ] Force hook initialization, missing pet buttons, and MicroBags layer failures; Companion never stamps `_fguiCompanionHooked`/`_fguiSquareSkinHooked`/count metadata on Blizzard frames, partial layers restore, and the exact failure reaches Lifecycle/Apply.\n',
    '- [ ] Force hook initialization, missing pet buttons, and MicroBags layer failures; Companion never stamps `_fguiCompanionHooked`/`_fguiSquareSkinHooked`/count metadata on Blizzard frames, partial layers restore, and the exact failure reaches Lifecycle/Apply.\n'
    '- [ ] Give each PetActionButton and PetActionBar distinctive parent/points/size/hit-rect/visibility/alpha/texture/mask/name/cooldown/hotkey state, apply twice, replace one button, make one conflicting external change, then detach; exact still-owned state restores without guessed defaults or overwriting the conflict.\n',
    'TODO PetState validation',
)
todo_path.write_text(todo, encoding='utf-8')

matrix_path = Path('docs/REGRESSION_MATRIX_1_25.md')
matrix = matrix_path.read_text(encoding='utf-8')
matrix = replace_once(
    matrix,
    '| 22 | Companion micro menu, bags, and pet bar lifecycle, repeated restyling, and injected layer failure | Controls attach/update/restore without duplicate ownership; all hook/count/border metadata stays on addon owners, partial presentation is cleaned, and failure propagates to Lifecycle/Apply |  |  |',
    '| 22 | Companion micro menu, bags, and pet bar lifecycle, repeated restyling, button replacement, conflicting external changes, and injected layer failure | Owner-local journals restore exact still-owned PetActionButton/PetActionBar state, preserve newer conflicts, avoid duplicate metadata/owners, clean partial presentation, and propagate failure to Lifecycle/Apply |  |  |',
    'regression matrix PetState',
)
matrix_path.write_text(matrix, encoding='utf-8')

print('Integrated reversible Companion pet-button state ownership.')
