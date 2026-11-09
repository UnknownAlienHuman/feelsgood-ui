from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


movers_path = Path('core/Movers.lua')
movers = movers_path.read_text(encoding='utf-8')

old_retire = r'''local function RetireMoverEntry(owner, entry)
    if type(entry) ~= "table" or entry.retired == true then return end

    local overlay = entry.overlay
    if overlay then
        AbortOverlayInteraction(overlay)
        ClearScripts(overlay, RETIRED_OVERLAY_SCRIPTS)
        overlay._cancelPreview = nil
        if type(overlay.EnableMouse) == "function" then
            pcall(overlay.EnableMouse, overlay, false)
        end

        local handle = overlay.handle
        if handle then
            ClearScripts(handle, RETIRED_HANDLE_SCRIPTS)
            if type(handle.EnableMouse) == "function" then
                pcall(handle.EnableMouse, handle, false)
            end
            if type(handle.Hide) == "function" then pcall(handle.Hide, handle) end
        end
        if type(overlay.Hide) == "function" then pcall(overlay.Hide, overlay) end
    end

    if owner._activeOverlay == overlay or owner._activeKey == entry.key then
        owner._activeKey = nil
        owner._activeOverlay = nil
        HideGuides()
        HideInspector()
    end

    entry.retired = true
    entry._handleRefresh = nil
end
'''
new_retire = r'''local function RetireMoverEntry(owner, entry)
    if type(entry) ~= "table" or entry.retired == true then return true end

    local firstDetail
    local function Capture(label, fn, ...)
        if type(fn) ~= "function" then return end
        local ok, detail = pcall(fn, ...)
        if not ok and not firstDetail then
            firstDetail = tostring(label) .. ": " .. tostring(detail)
        end
    end

    local overlay = entry.overlay
    if overlay then
        Capture("interaction cleanup", AbortOverlayInteraction, overlay)
        ClearScripts(overlay, RETIRED_OVERLAY_SCRIPTS)
        overlay._cancelPreview = nil
        Capture("overlay mouse disable", overlay.EnableMouse, overlay, false)

        local handle = overlay.handle
        if handle then
            ClearScripts(handle, RETIRED_HANDLE_SCRIPTS)
            Capture("handle mouse disable", handle.EnableMouse, handle, false)
            Capture("handle hide", handle.Hide, handle)
        end
        Capture("overlay hide", overlay.Hide, overlay)
    end

    if owner._activeOverlay == overlay or owner._activeKey == entry.key then
        owner._activeKey = nil
        owner._activeOverlay = nil
        Capture("guide cleanup", HideGuides)
        Capture("inspector cleanup", HideInspector)
    end

    entry.retired = true
    entry._handleRefresh = nil
    if firstDetail and Log and type(Log.Warn) == "function" then
        Log:Warn("Mover retirement incomplete for " .. tostring(entry.key) .. ": " .. firstDetail)
    end
    return firstDetail == nil, firstDetail
end
'''
movers = replace_once(movers, old_retire, new_retire, 'best-effort mover retirement')

movers = replace_once(
    movers,
    '''local function RefreshEntryHandle(entry)
    if not (entry and type(entry._handleRefresh) == "function") then
        return true
    end
    local ok, detail = pcall(entry._handleRefresh)
    if not ok then
        return false, "Mover handle refresh failed: " .. tostring(detail)
    end
    return true
end

''',
    '''local function RefreshEntryHandle(entry)
    if not (entry and type(entry._handleRefresh) == "function") then
        return true
    end
    local ok, detail = pcall(entry._handleRefresh)
    if not ok then
        return false, "Mover handle refresh failed: " .. tostring(detail)
    end
    return true
end

local function SetEntryOverlayVisible(entry, visible)
    local overlay = entry and entry.overlay
    if not overlay then return false, "Mover overlay unavailable" end
    local method = visible and overlay.Show or overlay.Hide
    if type(method) ~= "function" then
        return false, visible and "Mover overlay lacks Show" or "Mover overlay lacks Hide"
    end
    local ok, detail = pcall(method, overlay)
    if not ok then
        return false, "Mover overlay visibility failed: " .. tostring(detail)
    end
    return true
end

''',
    'overlay visibility helper',
)

register_start = movers.index('function Movers:Register(key, frame, label, spec)')
register_end = movers.index('function Movers:ReapplyAll()', register_start)
new_register_apply = r'''function Movers:Register(key, frame, label, spec)
    if type(key) ~= "string" or key == "" then
        return false, "Mover registration key is required"
    end
    if not frame then
        return false, "Mover frame is required for " .. key
    end

    if type(label) == "table" and spec == nil then
        spec = label
        label = spec.label
    end

    local descriptor = NormalizeRegistrationSpec(key, label, spec)
    local existing = self._registered[key]
    if existing and existing.frame == frame and existing.retired ~= true then
        local configured, configureDetail = ConfigureMoverFrame(frame)
        if not configured then return false, key .. ": " .. tostring(configureDetail) end

        local previousLabel = existing.label
        local previousSpec = existing.spec
        existing.label = descriptor.label
        existing.spec = descriptor
        existing.key = key

        local text = existing.overlay and existing.overlay.text
        if text and type(text.SetText) == "function" then
            local textOK, textDetail = pcall(text.SetText, text, descriptor.label)
            if not textOK then
                existing.label = previousLabel
                existing.spec = previousSpec
                return false, key .. ": mover label refresh failed: " .. tostring(textDetail)
            end
        end

        local refreshed, refreshDetail = RefreshEntryHandle(existing)
        if not refreshed then
            existing.label = previousLabel
            existing.spec = previousSpec
            if text and type(text.SetText) == "function" then
                pcall(text.SetText, text, previousLabel)
            end
            RefreshEntryHandle(existing)
            return false, key .. ": " .. tostring(refreshDetail)
        end
        return true, "reused"
    end

    local replacement, createDetail = CreateMoverEntry(key, frame, descriptor)
    if not replacement then
        return false, key .. ": " .. tostring(createDetail)
    end

    -- Publish temporarily so overlay callbacks and handle refresh resolve the new spec.
    self._registered[key] = replacement
    local visible, visibilityDetail = SetEntryOverlayVisible(replacement, self._unlocked)
    local refreshed, refreshDetail = visible and RefreshEntryHandle(replacement) or false, nil
    if visible then
        refreshed, refreshDetail = RefreshEntryHandle(replacement)
    end
    if not visible or not refreshed then
        self._registered[key] = existing
        RetireMoverEntry(self, replacement)
        return false, key .. ": " .. tostring(visibilityDetail or refreshDetail)
    end

    if existing then
        RetireMoverEntry(self, existing)
    end
    return true, existing and "replaced" or "registered"
end

function Movers:Apply(key, frame)
    if type(key) ~= "string" or key == "" then
        return false, "Mover apply key is required"
    end

    local entry = self:GetEntry(key)
    if not entry or entry.retired == true or not entry.frame then
        return false, "Mover registration unavailable for " .. key
    end
    if frame and frame ~= entry.frame then
        return false, key .. ": supplied frame does not own mover key"
    end

    local target = entry.frame
    local ok, normalized = pcall(ApplyStoredPoint, key, target, entry.spec)
    if not ok then
        return false, key .. ": mover position apply failed: " .. tostring(normalized)
    end
    if type(normalized) ~= "table" then
        return false, key .. ": stored mover position unavailable"
    end
    return true, normalized
end

'''
movers = movers[:register_start] + new_register_apply + movers[register_end:]

apply_unlocked_start = movers.index('local function ApplyUnlockedState(owner, state, opts)')
apply_unlocked_end = movers.index('function Movers:RegisterStateListener', apply_unlocked_start)
new_unlocked = r'''local function PresentUnlockedState(owner, unlocked)
    local firstDetail
    for key, entry in pairs(owner._registered) do
        if entry and entry.retired ~= true then
            local visible, visibilityDetail = SetEntryOverlayVisible(entry, unlocked)
            if visible == false and not firstDetail then
                firstDetail = tostring(key) .. ": " .. tostring(visibilityDetail)
            end
            local refreshed, refreshDetail = RefreshEntryHandle(entry)
            if refreshed == false and not firstDetail then
                firstDetail = tostring(key) .. ": " .. tostring(refreshDetail)
            end
        end
    end
    if firstDetail then return false, firstDetail end

    local ok, detail = pcall(function()
        if not unlocked then
            owner:ClearActiveInteraction()
        end

        SetGridVisible(unlocked)
        SetGlobalHintVisible(unlocked)
        if unlocked then
            EnsureInspector()
            EnsureKeyListener()
        else
            DisableKeyListener()
        end
    end)
    if not ok then
        return false, "Mover editor presentation failed: " .. tostring(detail)
    end
    return true
end

local function ApplyUnlockedState(owner, state, opts)
    opts = opts or {}
    local unlocked = state == true
    local previous = owner._unlocked == true
    local changed = previous ~= unlocked
    owner._unlocked = unlocked

    local presented, detail = PresentUnlockedState(owner, unlocked)
    if presented == false then
        owner._unlocked = previous
        PresentUnlockedState(owner, previous)
        return false, detail
    end

    if changed then
        for key, callback in pairs(owner._stateListeners) do
            if type(callback) == "function" then
                local ok = pcall(callback, owner._unlocked, owner, key)
                if not ok then
                    Log:Warn("Movers state listener failed for " .. tostring(key))
                end
            end
        end
    end

    if not opts.silent then
        Log:Info("Movers " .. (owner._unlocked and "UNLOCKED" or "LOCKED"))
    end
    return true
end

'''
movers = movers[:apply_unlocked_start] + new_unlocked + movers[apply_unlocked_end:]

movers = replace_once(
    movers,
    '''function Movers:PreviewUnlocked(state, opts)
    if not IsSafeToEdit() then
        return false, "Mover preview blocked in combat"
    end
    ApplyUnlockedState(self, state, opts)
    return true
end
''',
    '''function Movers:PreviewUnlocked(state, opts)
    if not IsSafeToEdit() then
        return false, "Mover preview blocked in combat"
    end
    return ApplyUnlockedState(self, state, opts)
end
''',
    'preview unlock result',
)
movers = replace_once(
    movers,
    '''    if IsSafeToEdit() then
        ApplyUnlockedState(self, unlocked)
    end
    return changed == true
end
''',
    '''    if IsSafeToEdit() then
        local applied, applyDetail = ApplyUnlockedState(self, unlocked)
        if applied == false then
            if Log and type(Log.Warn) == "function" then
                Log:Warn("Mover lock-state preview failed: " .. tostring(applyDetail))
            end
            return false
        end
    end
    return changed == true
end
''',
    'SetUnlocked result',
)
movers = replace_once(
    movers,
    '''function Movers:SyncFromProfile()
    self:ClearActiveInteraction()
    local movers = GetProfileSection("movers")
    ApplyUnlockedState(self, movers.unlocked, { silent = true })
    return self:RefreshEditorSettings()
end
''',
    '''function Movers:SyncFromProfile()
    self:ClearActiveInteraction()
    local movers = GetProfileSection("movers")
    local applied, applyDetail = ApplyUnlockedState(self, movers.unlocked, { silent = true })
    if applied == false then return false, applyDetail end
    return self:RefreshEditorSettings()
end
''',
    'SyncFromProfile result',
)
movers = replace_once(
    movers,
    '''    ApplyUnlockedState(self, movers.unlocked == true, { silent = true })

    local applied, applyDetail = self:ReapplyAll()
''',
    '''    local unlocked, unlockDetail = ApplyUnlockedState(self, movers.unlocked == true, { silent = true })
    if unlocked == false then return false, unlockDetail end

    local applied, applyDetail = self:ReapplyAll()
''',
    'ApplyConfig unlock result',
)
movers_path.write_text(movers, encoding='utf-8')


xp_path = Path('modules/ExperienceBar.lua')
xp = xp_path.read_text(encoding='utf-8')
xp = replace_once(
    xp,
    '''    if not (Movers and type(Movers.Register) == "function" and type(Movers.Apply) == "function") then
        return nil, "ExperienceBar mover registry unavailable"
    end
    local registered, registerDetail = Movers:Register("xpbar", bar, CreateMoverSpec())
    if registered == false then
        return nil, "ExperienceBar mover registration failed: " .. tostring(registerDetail)
    end
    local applied, applyDetail = Movers:Apply("xpbar", bar)
    if applied == false then
        return nil, "ExperienceBar mover apply failed: " .. tostring(applyDetail)
    end

    return bar
end
''',
    '''    if module._moverReadyFrame ~= bar then
        if not (Movers and type(Movers.Register) == "function" and type(Movers.Apply) == "function") then
            return nil, "ExperienceBar mover registry unavailable"
        end
        local registered, registerDetail = Movers:Register("xpbar", bar, CreateMoverSpec())
        if registered == false then
            return nil, "ExperienceBar mover registration failed: " .. tostring(registerDetail)
        end
        local applied, applyDetail = Movers:Apply("xpbar", bar)
        if applied == false then
            return nil, "ExperienceBar mover apply failed: " .. tostring(applyDetail)
        end
        module._moverReadyFrame = bar
    end

    return bar
end
''',
    'ExperienceBar mover readiness',
)
xp = replace_once(
    xp,
    '''    if not cfg.enabled then
        SetBarVisible(bar, false, false)
        return
    end
''',
    '''    if not cfg.enabled then
        SetBarVisible(bar, false, false)
        return true
    end
''',
    'ExperienceBar disabled update result',
)
xp = replace_once(
    xp,
    '''    if type(progress) ~= "table" then
        SetBarVisible(bar, false, false)
        return
    end
''',
    '''    if type(progress) ~= "table" then
        SetBarVisible(bar, false, false)
        return true
    end
''',
    'ExperienceBar no-progress result',
)
xp = replace_once(
    xp,
    '''    self:Update()
    return true
end
''',
    '''    local updated, updateDetail = self:Update()
    if updated == false then return false, updateDetail end
    return true
end
''',
    'ExperienceBar ApplyConfig update result',
)
xp_path.write_text(xp, encoding='utf-8')

pet_path = Path('modules/CompanionPetBar.lua')
pet = pet_path.read_text(encoding='utf-8')
pet = replace_once(
    pet,
    '''    if not (Movers and type(Movers.Register) == "function" and type(Movers.Apply) == "function") then
        return nil, "Companion pet mover registry unavailable"
    end
    local registered, registerDetail = Movers:Register(Shared.PET_KEY, frame, CreatePetBarMoverSpec())
    if registered == false then
        return nil, "Companion pet mover registration failed: " .. tostring(registerDetail)
    end
    local applied, applyDetail = Movers:Apply(Shared.PET_KEY, frame)
    if applied == false then
        return nil, "Companion pet mover apply failed: " .. tostring(applyDetail)
    end

    ApplyPetAnchorVisibility(frame)
''',
    '''    if module._petMoverReadyFrame ~= frame then
        if not (Movers and type(Movers.Register) == "function" and type(Movers.Apply) == "function") then
            return nil, "Companion pet mover registry unavailable"
        end
        local registered, registerDetail = Movers:Register(Shared.PET_KEY, frame, CreatePetBarMoverSpec())
        if registered == false then
            return nil, "Companion pet mover registration failed: " .. tostring(registerDetail)
        end
        local applied, applyDetail = Movers:Apply(Shared.PET_KEY, frame)
        if applied == false then
            return nil, "Companion pet mover apply failed: " .. tostring(applyDetail)
        end
        module._petMoverReadyFrame = frame
    end

    ApplyPetAnchorVisibility(frame)
''',
    'Companion pet mover readiness',
)
pet_path.write_text(pet, encoding='utf-8')

micro_path = Path('modules/CompanionMicroBags.lua')
micro = micro_path.read_text(encoding='utf-8')
micro = replace_once(
    micro,
    '''    if not (Movers and type(Movers.Register) == "function" and type(Movers.Apply) == "function") then
        return nil, "Companion micro mover registry unavailable"
    end
    local registered, registerDetail = Movers:Register(Shared.MICRO_KEY, frame, CreateMicroMenuMoverSpec())
    if registered == false then
        return nil, "Companion micro mover registration failed: " .. tostring(registerDetail)
    end
    local applied, applyDetail = Movers:Apply(Shared.MICRO_KEY, frame)
    if applied == false then
        return nil, "Companion micro mover apply failed: " .. tostring(applyDetail)
    end
    return frame
end
''',
    '''    if module._microMoverReadyFrame ~= frame then
        if not (Movers and type(Movers.Register) == "function" and type(Movers.Apply) == "function") then
            return nil, "Companion micro mover registry unavailable"
        end
        local registered, registerDetail = Movers:Register(Shared.MICRO_KEY, frame, CreateMicroMenuMoverSpec())
        if registered == false then
            return nil, "Companion micro mover registration failed: " .. tostring(registerDetail)
        end
        local applied, applyDetail = Movers:Apply(Shared.MICRO_KEY, frame)
        if applied == false then
            return nil, "Companion micro mover apply failed: " .. tostring(applyDetail)
        end
        module._microMoverReadyFrame = frame
    end
    return frame
end
''',
    'Companion micro mover readiness',
)
micro_path.write_text(micro, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
contracts = r'''    assertSourceIncludes('core/Movers.lua', 'supplied frame does not own mover key');
    assertSourceIncludes('core/Movers.lua', 'local function PresentUnlockedState(owner, unlocked)');
    assertSourceIncludes('core/Movers.lua', 'owner._unlocked = previous');
    assertSourceIncludes('core/Movers.lua', 'existing.spec = previousSpec');
    assertSourceIncludes('core/Movers.lua', 'local visible, visibilityDetail = SetEntryOverlayVisible');
    assertSourceIncludes('modules/ExperienceBar.lua', 'module._moverReadyFrame ~= bar');
    assertSourceIncludes('modules/CompanionPetBar.lua', 'module._petMoverReadyFrame ~= frame');
    assertSourceIncludes('modules/CompanionMicroBags.lua', 'module._microMoverReadyFrame ~= frame');

'''
check = replace_once(
    check,
    "    assertSourceIncludes('core/Movers.lua', 'local function RetireMoverEntry(owner, entry)');\n",
    "    assertSourceIncludes('core/Movers.lua', 'local function RetireMoverEntry(owner, entry)');\n" + contracts,
    'Mover atomicity static contracts',
)
check_path.write_text(check, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(
    readme,
    'failed replacement preserves the previous registry entry. No feature may ignore mover registration/apply results and then publish initialized state.',
    'failed replacement preserves the previous registry entry, same-frame refresh rolls back descriptor changes, stale frames cannot apply a key, and unlock presentation restores the previous state on error. Hot-path feature updates retain mover readiness instead of re-registering every event. No feature may ignore mover registration/apply results and then publish initialized state.',
    'README mover atomicity policy',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    'failed replacement preserves the previous registry entry. No feature may ignore mover registration/apply results and then publish initialized state.',
    'failed replacement preserves the previous registry entry, same-frame descriptor updates roll back on refresh failure, stale frames cannot apply a key, and unlock presentation rolls back runtime state on error. Hot-path owners retain a frame-specific mover-ready token instead of registering/applying on every update. No feature may ignore mover registration/apply results and then publish initialized state.',
    'AGENT_GUIDE mover atomicity invariant',
)
agent_path.write_text(agent, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(
    todo,
    'frame replacement atomically retires old overlay scripts, invalid positions fail explicitly, and all feature families block initialized state until mover ownership succeeds.',
    'frame replacement atomically retires old overlay scripts, same-frame updates and unlock presentation roll back on failure, stale frames cannot apply a key, hot paths retain mover readiness, invalid positions fail explicitly, and all feature families block initialized state until mover ownership succeeds.',
    'TODO mover atomicity status',
)
todo_path.write_text(todo, encoding='utf-8')

print('Refined mover replacement atomicity, ownership checks, and hot-path readiness.')