from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


micro_path = Path('modules/CompanionMicroBags.lua')
micro = micro_path.read_text(encoding='utf-8')

old_hooks = r'''local function HookMicroSourceWidgets(module)
    if not module then return end

    local microMenu = _G.MicroMenu
    if microMenu and not microMenu._fguiCompanionHooked and type(microMenu.HookScript) == "function" then
        microMenu._fguiCompanionHooked = true
        microMenu:HookScript("OnShow", RequestManagedMicroRefresh)
        microMenu:HookScript("OnHide", RequestManagedMicroRefresh)
    end

    local microButtons = GetMicroButtons()
    for i = 1, #microButtons do
        local button = microButtons[i]
        if button and not button._fguiCompanionHooked and type(button.HookScript) == "function" then
            button._fguiCompanionHooked = true
            button:HookScript("OnShow", RequestManagedMicroRefresh)
            button:HookScript("OnHide", RequestManagedMicroRefresh)
        end
    end
end
'''
new_hooks = r'''local function HookMicroSourceWidgets(module)
    if not module then return false end

    module._microSourceHooks = type(module._microSourceHooks) == "table"
        and module._microSourceHooks
        or {}
    local hooks = module._microSourceHooks

    local microMenu = _G.MicroMenu
    if microMenu and not hooks[microMenu] and type(microMenu.HookScript) == "function" then
        hooks[microMenu] = true
        microMenu:HookScript("OnShow", RequestManagedMicroRefresh)
        microMenu:HookScript("OnHide", RequestManagedMicroRefresh)
    end

    local microButtons = GetMicroButtons()
    for i = 1, #microButtons do
        local button = microButtons[i]
        if button and not hooks[button] and type(button.HookScript) == "function" then
            hooks[button] = true
            button:HookScript("OnShow", RequestManagedMicroRefresh)
            button:HookScript("OnHide", RequestManagedMicroRefresh)
        end
    end
    return true
end
'''
micro = replace_once(micro, old_hooks, new_hooks, 'owner-local micro hooks')

old_count = r'''local function EnsureCompactBagCountText(button, profile)
    if not button then return nil end
    if button._fguiBagCountText and button._fguiBagCountText.GetObjectType and button._fguiBagCountText:GetObjectType() == "FontString" then
        return button._fguiBagCountText
    end

    local fontString = button:CreateFontString(nil, "OVERLAY")
    fontString:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    fontString:SetJustifyH("RIGHT")
    fontString:SetJustifyV("BOTTOM")

    local font = ((Theme and Theme.GetFontToken and Theme:GetFontToken()) or "Fonts\\FRIZQT__.TTF")
    local outline = ((Theme and Theme.GetFontOutline and Theme:GetFontOutline()) or "OUTLINE")
    Media:ApplyFont(fontString, font, 11, outline)

    button._fguiBagCountText = fontString
    return fontString
end
'''
new_count = r'''local function EnsureCompactBagCountText(module, button, profile)
    if not (module and button) then return nil end

    module._bagCountTextByButton = type(module._bagCountTextByButton) == "table"
        and module._bagCountTextByButton
        or {}
    local fontString = module._bagCountTextByButton[button]
    if fontString and fontString.GetObjectType and fontString:GetObjectType() == "FontString" then
        if type(fontString.Show) == "function" then fontString:Show() end
        return fontString
    end

    fontString = button:CreateFontString(nil, "OVERLAY")
    fontString:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    fontString:SetJustifyH("RIGHT")
    fontString:SetJustifyV("BOTTOM")

    local font = ((Theme and Theme.GetFontToken and Theme:GetFontToken()) or "Fonts\\FRIZQT__.TTF")
    local outline = ((Theme and Theme.GetFontOutline and Theme:GetFontOutline()) or "OUTLINE")
    Media:ApplyFont(fontString, font, 11, outline)

    module._bagCountTextByButton[button] = fontString
    return fontString
end
'''
micro = replace_once(micro, old_count, new_count, 'owner-local bag count text')
micro = replace_once(
    micro,
    '    local text = EnsureCompactBagCountText(button, profile)\n',
    '    local text = EnsureCompactBagCountText(module, button, profile)\n',
    'bag count text owner argument',
)
micro = replace_once(
    micro,
    '    button._fguiBagSummary = string.format("%d/%d", free, total)\n',
    '    module._compactBagSummary = string.format("%d/%d", free, total)\n',
    'owner-local bag summary',
)

old_clear = r'''local function ClearCompactBagState(module)
    if module and module._compactBackpackButton and module._compactBackpackButton._fguiBagCountText then
        module._compactBackpackButton._fguiBagCountText:SetText("")
    end
    if module then
        module._compactBackpackButton = nil
    end
end
'''
new_clear = r'''local function ClearCompactBagState(module)
    if not module then return end

    local button = module._compactBackpackButton
    local texts = module._bagCountTextByButton
    local text = button and type(texts) == "table" and texts[button] or nil
    if text then
        text:SetText("")
        if type(text.Hide) == "function" then text:Hide() end
    end

    module._compactBackpackButton = nil
    module._compactBagSummary = nil
end
'''
micro = replace_once(micro, old_clear, new_clear, 'owner-local compact bag cleanup')

micro = replace_once(
    micro,
    '''local function RestoreDefaultMicroLayout(module)
    if Shared:IsInCombat() then
        module._pendingAfterCombat = true
        return
    end
''',
    '''local function RestoreDefaultMicroLayout(module)
    if not module then return false, "Companion micro/bag owner unavailable" end
    if Shared:IsInCombat() then
        module._pendingAfterCombat = true
        return false, "Companion micro/bag restore deferred in combat"
    end
''',
    'micro restore result contract',
)
micro = replace_once(
    micro,
    '''    if module then
        ClearCompactBagState(module)
        if module._microAnchor then
            HideFrameSafe(module._microAnchor)
        end
    end
end

local function ApplyMicroMenuOverride(anchor)
''',
    '''    ClearCompactBagState(module)
    if module._microAnchor then
        HideFrameSafe(module._microAnchor)
    end
    return true
end

local function ApplyMicroMenuOverride(anchor)
''',
    'micro restore success result',
)

micro = replace_once(
    micro,
    '''function MicroBags:Apply(module, cp, profile)
    if not (module and cp) then return end
    if Shared:IsInCombat() then
        module._pendingAfterCombat = true
        return
    end
''',
    '''function MicroBags:Apply(module, cp, profile)
    if not (module and cp) then return false, "Companion micro/bag apply owner unavailable" end
    if Shared:IsInCombat() then
        module._pendingAfterCombat = true
        return false, "Companion micro/bag apply deferred in combat"
    end
''',
    'micro apply result contract',
)
micro = replace_once(
    micro,
    '''    if not takeOver then
        RestoreDefaultMicroLayout(module)
        return
    end
''',
    '''    if not takeOver then
        return RestoreDefaultMicroLayout(module)
    end
''',
    'micro non-takeover result',
)
micro = replace_once(
    micro,
    '''        ClearCompactBagState(module)
        return
    end

    local anchor = EnsureMicroAnchor(module)
    if not anchor then return end
''',
    '''        ClearCompactBagState(module)
        return true
    end

    local anchor = EnsureMicroAnchor(module)
    if not anchor then return false, "Companion micro-menu anchor unavailable" end
''',
    'micro hidden/anchor results',
)
queued_anchor = '''                module._applyingMicroLayout = nil
                QueueMicroLayoutRetry(module)
                return
'''
if micro.count(queued_anchor) != 2:
    raise RuntimeError(f'micro retry anchors: expected 2, found {micro.count(queued_anchor)}')
micro = micro.replace(
    queued_anchor,
    '''                module._applyingMicroLayout = nil
                QueueMicroLayoutRetry(module)
                return true, "Companion micro layout retry queued"
''',
)
micro = replace_once(
    micro,
    '''    module._applyingMicroLayout = nil
end

function MicroBags:EnsureHooks(module)
    if not module then return end
''',
    '''    module._applyingMicroLayout = nil
    return true
end

function MicroBags:EnsureHooks(module)
    if not module then return false, "Companion hook owner unavailable" end
''',
    'micro success and hook result',
)

old_bag_hooks = r'''    local bagButtons = GetBagButtons()
    for i = 1, #bagButtons do
        local bagButton = bagButtons[i]
        if bagButton and (not bagButton._fguiSquareSkinHooked) and type(bagButton.UpdateTextures) == "function" then
            bagButton._fguiSquareSkinHooked = true
            hooksecurefunc(bagButton, "UpdateTextures", function(button)
                local selfModule = ns.Companion
                if not IsManagedModuleActive(selfModule) then return end
                local cp = Shared:GetCompanionCfg(nil)
                if not Shared:ShouldManageBags(cp) then return end
                if IsBackpackButton(button) then
                    StyleBackpackButton(button, cp.buttonSize or 32)
                    if type(button.SetCountShown) == "function" then
                        pcall(button.SetCountShown, button, (cp.bags.compact ~= false) and false or true)
                    end
                else
                    StyleBagButton(button, cp.buttonSize or 32)
                end
            end)
        end
    end
end
'''
new_bag_hooks = r'''    module._bagTextureHooks = type(module._bagTextureHooks) == "table"
        and module._bagTextureHooks
        or {}
    local bagHooks = module._bagTextureHooks

    local bagButtons = GetBagButtons()
    for i = 1, #bagButtons do
        local bagButton = bagButtons[i]
        if bagButton and not bagHooks[bagButton] and type(bagButton.UpdateTextures) == "function" then
            bagHooks[bagButton] = true
            hooksecurefunc(bagButton, "UpdateTextures", function(button)
                local selfModule = ns.Companion
                if not IsManagedModuleActive(selfModule) then return end
                local cp = Shared:GetCompanionCfg(nil)
                if not Shared:ShouldManageBags(cp) then return end
                if IsBackpackButton(button) then
                    StyleBackpackButton(button, cp.buttonSize or 32)
                    if type(button.SetCountShown) == "function" then
                        pcall(button.SetCountShown, button, (cp.bags.compact ~= false) and false or true)
                    end
                else
                    StyleBagButton(button, cp.buttonSize or 32)
                end
            end)
        end
    end
    return true
end
'''
micro = replace_once(micro, old_bag_hooks, new_bag_hooks, 'owner-local bag texture hooks')
micro = replace_once(
    micro,
    '''function MicroBags:RestoreDefaultLayout(module)
    CancelRetryTimer()
    RestoreDefaultMicroLayout(module)
end
''',
    '''function MicroBags:RestoreDefaultLayout(module)
    CancelRetryTimer()
    return RestoreDefaultMicroLayout(module)
end
''',
    'micro restore adapter result',
)
micro_path.write_text(micro, encoding='utf-8')

pet_path = Path('modules/CompanionPetBar.lua')
pet = pet_path.read_text(encoding='utf-8')
pet = replace_once(
    pet,
    '''function PetBar:Apply(module, cp, profile)
    if not (module and cp) then return end
    if Shared:IsInCombat() then
        module._pendingAfterCombat = true
        return
    end

    local holder = EnsurePetAnchor(module)
    if not holder then return end
''',
    '''function PetBar:Apply(module, cp, profile)
    if not (module and cp) then return false, "Companion pet-bar apply owner unavailable" end
    if Shared:IsInCombat() then
        module._pendingAfterCombat = true
        return false, "Companion pet-bar apply deferred in combat"
    end

    local holder = EnsurePetAnchor(module)
    if not holder then return false, "Companion pet-bar holder unavailable" end
''',
    'pet apply result contract',
)
pet = replace_once(
    pet,
    '''    if not allReady then
        module._pendingAfterCombat = true
    end
end
''',
    '''    if not allReady then
        module._pendingAfterCombat = true
        return false, "Pet action buttons unavailable"
    end
    return true
end
''',
    'pet apply terminal result',
)
pet_path.write_text(pet, encoding='utf-8')

runtime_path = Path('modules/CompanionRuntime.lua')
runtime = runtime_path.read_text(encoding='utf-8')
runtime = replace_once(
    runtime,
    '''function Runtime.ApplyCompanionConfig(module, profile)
    if not IsReady(module) or IsDetached(module) or not HasCompanionLayers() then
        return false
    end

    local currentProfile = profile
    local cp = Shared:GetCompanionCfg(currentProfile)
    MicroBags:EnsureHooks(module)
    PetBar:Apply(module, cp, currentProfile)
    MicroBags:Apply(module, cp, currentProfile)
    MicroBags:UpdateCompactBagCountText(module, currentProfile)
    return true
end
''',
    '''function Runtime.ApplyCompanionConfig(module, profile)
    if not IsReady(module) then return false, "Companion apply owner unavailable" end
    if IsDetached(module) then return false, "Companion is detached" end
    if not HasCompanionLayers() then return false, "Companion internal layers unavailable" end

    local currentProfile = profile
    local cp = Shared:GetCompanionCfg(currentProfile)

    local hooksReady, hookDetail = MicroBags:EnsureHooks(module)
    if hooksReady ~= true then
        return false, hookDetail or "Companion hooks unavailable"
    end

    local petApplied, petDetail = PetBar:Apply(module, cp, currentProfile)
    if petApplied ~= true then
        if type(PetBar.RestoreDefaultLayout) == "function" and not Shared:IsInCombat() then
            PetBar:RestoreDefaultLayout(module)
        end
        return false, petDetail or "Companion pet-bar apply failed"
    end

    local microApplied, microDetail = MicroBags:Apply(module, cp, currentProfile)
    if microApplied ~= true then
        if not Shared:IsInCombat() then
            if type(MicroBags.RestoreDefaultLayout) == "function" then
                MicroBags:RestoreDefaultLayout(module)
            end
            if type(PetBar.RestoreDefaultLayout) == "function" then
                PetBar:RestoreDefaultLayout(module)
            end
        end
        return false, microDetail or "Companion micro/bag apply failed"
    end

    MicroBags:UpdateCompactBagCountText(module, currentProfile)
    return true, microDetail
end
''',
    'Companion layered apply results',
)
runtime = replace_once(
    runtime,
    '''function Runtime.ApplyConfig(module, profile)
    if not IsReady(module) or IsDetached(module) then
        return false
    end

    return Runtime.ApplyCompanionConfig(module, profile)
end
''',
    '''function Runtime.ApplyConfig(module, profile)
    if not IsReady(module) then return false, "Companion apply owner unavailable" end
    if IsDetached(module) then return false, "Companion is detached" end
    return Runtime.ApplyCompanionConfig(module, profile)
end
''',
    'Companion ApplyConfig detail',
)
runtime = replace_once(
    runtime,
    '''    if Safety and Safety.Debounce and Safety.Debounce(Shared.APPLY_DEBOUNCE_KEY, 0.03, function()
        Runtime.ApplyConfig(GetActiveModule(module))
    end) then
''',
    '''    if Safety and Safety.Debounce and Safety.Debounce(Shared.APPLY_DEBOUNCE_KEY, 0.03, function()
        local applied, detail = Runtime.ApplyConfig(GetActiveModule(module))
        if applied == false and Log and type(Log.Error) == "function" then
            Log:Error("Companion apply failed: " .. tostring(detail or "unknown error"))
        end
    end) then
''',
    'Companion debounced apply reporting',
)
runtime = replace_once(
    runtime,
    '''    if module._initDone then
        return true
    end

    module._initDone = true
    MicroBags:EnsureHooks(module)
    return true
end
''',
    '''    if module._initDone then
        return true
    end

    local hooksReady, detail = MicroBags:EnsureHooks(module)
    if hooksReady ~= true then
        return false, detail or "Companion hooks unavailable"
    end

    module._initDone = true
    return true
end
''',
    'Companion init result contract',
)
runtime_path.write_text(runtime, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
check = replace_once(
    check,
    '''            if (/__fguiBorder(?:Size)?/.test(source)) {
                errors.push(`${name}: border ownership must stay in Media's registry, not on target frames`);
            }
''',
    '''            if (/__fguiBorder(?:Size)?/.test(source)) {
                errors.push(`${name}: border ownership must stay in Media's registry, not on target frames`);
            }
            if (name === 'modules/CompanionMicroBags.lua'
                && /_(?:fguiCompanionHooked|fguiSquareSkinHooked|fguiBagCountText|fguiBagSummary)\\b/.test(source)) {
                errors.push(`${name}: Companion runtime metadata must stay on the owner, not Blizzard frames`);
            }
''',
    'Companion foreign marker scan',
)
check = replace_once(
    check,
    "    assertSourceIncludes('core/Media.lua', 'Media._borderRegistry');\n",
    "    assertSourceIncludes('modules/CompanionMicroBags.lua', 'module._microSourceHooks');\n"
    "    assertSourceIncludes('modules/CompanionMicroBags.lua', 'module._bagTextureHooks');\n"
    "    assertSourceIncludes('modules/CompanionMicroBags.lua', 'module._bagCountTextByButton');\n"
    "    assertSourceIncludes('modules/CompanionRuntime.lua', 'local petApplied, petDetail');\n"
    "    assertSourceIncludes('modules/CompanionRuntime.lua', 'local microApplied, microDetail');\n"
    "    assertSourceIncludes('modules/CompanionPetBar.lua', 'return false, \"Pet action buttons unavailable\"');\n\n"
    "    assertSourceIncludes('core/Media.lua', 'Media._borderRegistry');\n",
    'Companion owner-state contracts',
)
check_path.write_text(check, encoding='utf-8')

# Release metadata and documentation.
toc_path = Path('FeelsGoodUI.toc')
toc = toc_path.read_text(encoding='utf-8')
toc = replace_once(toc, '## Version: 0.0.57', '## Version: 0.0.58', 'TOC version')
toc_path.write_text(toc, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(readme, '- FeelsGoodUI `0.0.57`', '- FeelsGoodUI `0.0.58`', 'README version')
readme = replace_once(
    readme,
    'Styling helpers follow the same boundary: `Media:CreateBorder` keeps border records in a weak-key owner registry and never writes `__fgui*` metadata onto Blizzard or third-party frames.',
    'Styling helpers follow the same boundary: `Media:CreateBorder` keeps border records in a weak-key owner registry and never writes `__fgui*` metadata onto Blizzard or third-party frames. Companion micro-menu/bag hook state, compact-count font strings, and summaries likewise live on the Companion owner; layer apply functions return explicit terminal results, and a failed layer restores already-applied companion presentation before reporting failure to the shared journal.',
    'README Companion owner state',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    '- Center bars: `CenterBars.lua` delegates render/runtime and listens to player power/rune/world/spec events. `CenterBarsRender` owns reversible alpha/mouse suppression of Blizzard class-resource frames through owner-local records and permanent gated OnShow hooks; it never adds fields to foreign frames or calls their `Hide`/`Show`/`Setup`. Companion and ExperienceBar are independent feature families registered through the same lifecycle. `ExperienceBar` owns one lifecycle apply path and the same narrow reversible policy for Blizzard status-tracking frames.\n',
    '- Center bars: `CenterBars.lua` delegates render/runtime and listens to player power/rune/world/spec events. `CenterBarsRender` owns reversible alpha/mouse suppression of Blizzard class-resource frames through owner-local records and permanent gated OnShow hooks; it never adds fields to foreign frames or calls their `Hide`/`Show`/`Setup`.\n- Companion: `CompanionRuntime` coordinates PetBar and MicroBags as result-bearing layers; hook registries, compact count objects, and summaries live on the Companion owner, never on Blizzard buttons. A failed layer restores partial companion presentation and propagates failure to Apply/Lifecycle.\n- ExperienceBar owns one lifecycle apply path and the same narrow reversible policy for Blizzard status-tracking frames.\n',
    'AGENT_GUIDE Companion owner',
)
agent_path.write_text(agent, encoding='utf-8')

index_path = Path('CODE_INDEX.md')
index = index_path.read_text(encoding='utf-8')
index = replace_once(
    index,
    '| `modules/Companion*.lua` | Companion pet-bar, micro-menu, bags, and lifecycle ownership. |',
    '| `modules/CompanionRuntime.lua` | Result-bearing Companion lifecycle/apply coordinator and partial-layer cleanup. |\n| `modules/CompanionMicroBags.lua`, `modules/CompanionPetBar.lua`, `modules/CompanionShared.lua` | Owner-local hook/cache state plus pet-bar, micro-menu, and bag presentation layers. |',
    'CODE_INDEX Companion owner state',
)
index_path.write_text(index, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(todo, '- [x] Target Interface `120105` and release `0.0.57`.', '- [x] Target Interface `120105` and release `0.0.58`.', 'TODO version')
todo = replace_once(
    todo,
    '- [x] Move border ownership out of target frames: `Media` now keeps weak-key records, exposes explicit lookup/color APIs, and static validation rejects `__fguiBorder*` metadata anywhere in first-party Lua.\n',
    '- [x] Move border ownership out of target frames: `Media` now keeps weak-key records, exposes explicit lookup/color APIs, and static validation rejects `__fguiBorder*` metadata anywhere in first-party Lua.\n'
    '- [x] Move Companion hooks/count caches/summaries off Blizzard frames and make PetBar/MicroBags apply terminal-result aware; failed layers clean partial presentation and propagate failure instead of reporting false success.\n',
    'TODO Companion owner-state status',
)
todo = replace_once(
    todo,
    '- [ ] Repeatedly skin and restore Blizzard pet/micro/bag buttons; border frames are reused through `Media` without any `__fguiBorder*` fields on the target buttons, and transparent release is reversed by the next theme/style apply.\n',
    '- [ ] Repeatedly skin and restore Blizzard pet/micro/bag buttons; border frames are reused through `Media` without any `__fguiBorder*` fields on the target buttons, and transparent release is reversed by the next theme/style apply.\n'
    '- [ ] Force hook initialization, missing pet buttons, and MicroBags layer failures; Companion never stamps `_fguiCompanionHooked`/`_fguiSquareSkinHooked`/count metadata on Blizzard frames, partial layers restore, and the exact failure reaches Lifecycle/Apply.\n',
    'TODO Companion owner-state validation',
)
todo_path.write_text(todo, encoding='utf-8')

matrix_path = Path('docs/REGRESSION_MATRIX_1_25.md')
matrix = matrix_path.read_text(encoding='utf-8')
matrix = replace_once(
    matrix,
    '| 22 | Companion micro menu, bags, and pet bar lifecycle, including repeated border restyling | Controls attach, update, restore, and detach without duplicate ownership; border objects are reused and target Blizzard frames receive no `__fguiBorder*` metadata |  |  |',
    '| 22 | Companion micro menu, bags, and pet bar lifecycle, repeated restyling, and injected layer failure | Controls attach/update/restore without duplicate ownership; all hook/count/border metadata stays on addon owners, partial presentation is cleaned, and failure propagates to Lifecycle/Apply |  |  |',
    'regression matrix Companion owner state',
)
matrix_path.write_text(matrix, encoding='utf-8')

print('Moved Companion runtime metadata to the owner and propagated layer results.')
