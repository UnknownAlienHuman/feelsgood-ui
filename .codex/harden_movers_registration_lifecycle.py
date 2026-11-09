from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# Core Movers registry: result-bearing, replacement-safe registration/apply.
# ---------------------------------------------------------------------------
movers_path = Path('core/Movers.lua')
movers = movers_path.read_text(encoding='utf-8')
helpers = r'''local RETIRED_OVERLAY_SCRIPTS = {
    "OnShow",
    "OnHide",
    "OnClick",
    "OnEnter",
    "OnLeave",
    "OnDragStart",
    "OnDragStop",
    "OnMouseWheel",
    "OnUpdate",
}

local RETIRED_HANDLE_SCRIPTS = {
    "OnEnter",
    "OnLeave",
    "OnMouseDown",
    "OnMouseUp",
    "OnUpdate",
}

local function ConfigureMoverFrame(frame)
    if not frame then return false, "Mover frame unavailable" end
    if type(frame.SetMovable) ~= "function" then
        return false, "Mover frame lacks SetMovable"
    end
    if type(frame.SetClampedToScreen) ~= "function" then
        return false, "Mover frame lacks SetClampedToScreen"
    end

    local movableOK, movableDetail = pcall(frame.SetMovable, frame, true)
    if not movableOK then
        return false, "SetMovable failed: " .. tostring(movableDetail)
    end
    local clampOK, clampDetail = pcall(frame.SetClampedToScreen, frame, true)
    if not clampOK then
        return false, "SetClampedToScreen failed: " .. tostring(clampDetail)
    end
    return true
end

local function ClearScripts(target, scripts)
    if not (target and type(target.SetScript) == "function") then return end
    for i = 1, #scripts do
        pcall(target.SetScript, target, scripts[i], nil)
    end
end

local function RetireMoverEntry(owner, entry)
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

local function CreateMoverEntry(key, frame, descriptor)
    local configured, configureDetail = ConfigureMoverFrame(frame)
    if not configured then return nil, configureDetail end

    local created, overlay, handleRefresh = pcall(
        CreateOverlay,
        key,
        frame,
        descriptor.label
    )
    if not created then
        return nil, "Mover overlay creation failed: " .. tostring(overlay)
    end
    if not overlay then
        return nil, "Mover overlay creation returned nil"
    end

    return {
        key = key,
        frame = frame,
        overlay = overlay,
        label = descriptor.label,
        spec = descriptor,
        _handleRefresh = handleRefresh,
    }
end

local function RefreshEntryHandle(entry)
    if not (entry and type(entry._handleRefresh) == "function") then
        return true
    end
    local ok, detail = pcall(entry._handleRefresh)
    if not ok then
        return false, "Mover handle refresh failed: " .. tostring(detail)
    end
    return true
end

'''
movers = replace_once(
    movers,
    'function Movers:GetEntry(key)\n',
    helpers + 'function Movers:GetEntry(key)\n',
    'Mover registry helpers',
)

old_registry = r'''function Movers:Register(key, frame, label, spec)
    if not key or not frame or self._registered[key] then return end

    if type(label) == "table" and spec == nil then
        spec = label
        label = spec.label
    end

    local descriptor = NormalizeRegistrationSpec(key, label, spec)

    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    local overlay, handleRefresh = CreateOverlay(key, frame, descriptor.label)
    if self._unlocked then overlay:Show() else overlay:Hide() end

    self._registered[key] = {
        frame = frame,
        overlay = overlay,
        label = descriptor.label,
        spec = descriptor,
        _handleRefresh = handleRefresh,
    }
end

function Movers:Apply(key, frame)
    local entry = self:GetEntry(key)
    local target = frame or (entry and entry.frame) or nil
    if not target then
        return
    end

    ApplyStoredPoint(key, target, entry and entry.spec or nil)
end

function Movers:ReapplyAll()
    for key, entry in pairs(self._registered) do
        if entry and entry.frame then
            self:Apply(key, entry.frame)
        end
    end
end
'''
new_registry = r'''function Movers:Register(key, frame, label, spec)
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

        existing.label = descriptor.label
        existing.spec = descriptor
        existing.key = key
        if existing.overlay and existing.overlay.text and type(existing.overlay.text.SetText) == "function" then
            pcall(existing.overlay.text.SetText, existing.overlay.text, descriptor.label)
        end
        local refreshed, refreshDetail = RefreshEntryHandle(existing)
        if not refreshed then return false, key .. ": " .. tostring(refreshDetail) end
        return true, "reused"
    end

    local replacement, createDetail = CreateMoverEntry(key, frame, descriptor)
    if not replacement then
        return false, key .. ": " .. tostring(createDetail)
    end

    self._registered[key] = replacement
    if self._unlocked then replacement.overlay:Show() else replacement.overlay:Hide() end
    local refreshed, refreshDetail = RefreshEntryHandle(replacement)
    if not refreshed then
        self._registered[key] = existing
        RetireMoverEntry(self, replacement)
        return false, key .. ": " .. tostring(refreshDetail)
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
    local target = frame or (entry and entry.frame) or nil
    if not target then
        return false, "Mover frame unavailable for " .. key
    end

    local ok, normalized = pcall(ApplyStoredPoint, key, target, entry and entry.spec or nil)
    if not ok then
        return false, key .. ": mover position apply failed: " .. tostring(normalized)
    end
    if type(normalized) ~= "table" then
        return false, key .. ": stored mover position unavailable"
    end
    return true, normalized
end

function Movers:ReapplyAll()
    local firstDetail
    for key, entry in pairs(self._registered) do
        if entry and entry.frame and entry.retired ~= true then
            local applied, detail = self:Apply(key, entry.frame)
            if applied == false and not firstDetail then
                firstDetail = tostring(detail)
            end
        end
    end
    if firstDetail then return false, firstDetail end
    return true
end
'''
movers = replace_once(movers, old_registry, new_registry, 'Mover registration/apply API')

movers = replace_once(
    movers,
    '''function Movers:SyncFromProfile()
    self:ClearActiveInteraction()
    local movers = GetProfileSection("movers")
    ApplyUnlockedState(self, movers.unlocked, { silent = true })
    self:RefreshEditorSettings()
end

function Movers:ApplyUnlockFromDB()
    self:SyncFromProfile()
end

function Movers:RefreshEditorSettings()
    -- Called from Options when editor toggles change.
    if self._unlocked then
        SetGridVisible(true)
    end
    for _, entry in pairs(self._registered) do
        if entry and entry._handleRefresh then
            entry._handleRefresh()
        end
    end
end

function Movers:ApplyConfig()
    if InCombatLockdown() then
        return false, "Movers apply blocked in combat"
    end

    self:ClearActiveInteraction()
    local movers = GetProfileSection("movers")
    ApplyUnlockedState(self, movers.unlocked == true, { silent = true })
    self:ReapplyAll()
    self:RefreshEditorSettings()
    return true
end
''',
    '''function Movers:SyncFromProfile()
    self:ClearActiveInteraction()
    local movers = GetProfileSection("movers")
    ApplyUnlockedState(self, movers.unlocked, { silent = true })
    return self:RefreshEditorSettings()
end

function Movers:ApplyUnlockFromDB()
    return self:SyncFromProfile()
end

function Movers:RefreshEditorSettings()
    -- Called from Options when editor toggles change.
    if self._unlocked then
        SetGridVisible(true)
    end
    local firstDetail
    for _, entry in pairs(self._registered) do
        if entry and entry.retired ~= true then
            local refreshed, detail = RefreshEntryHandle(entry)
            if refreshed == false and not firstDetail then
                firstDetail = tostring(detail)
            end
        end
    end
    if firstDetail then return false, firstDetail end
    return true
end

function Movers:ApplyConfig()
    if InCombatLockdown() then
        return false, "Movers apply blocked in combat"
    end

    self:ClearActiveInteraction()
    local movers = GetProfileSection("movers")
    ApplyUnlockedState(self, movers.unlocked == true, { silent = true })

    local applied, applyDetail = self:ReapplyAll()
    if applied == false then return false, applyDetail end
    local refreshed, refreshDetail = self:RefreshEditorSettings()
    if refreshed == false then return false, refreshDetail end
    return true
end
''',
    'Mover config result propagation',
)
movers_path.write_text(movers, encoding='utf-8')


# ---------------------------------------------------------------------------
# ActionBars lifecycle: partial holders survive retry; mover failures propagate.
# ---------------------------------------------------------------------------
edit_path = Path('modules/ActionBarsEditMode.lua')
edit = edit_path.read_text(encoding='utf-8')
edit = replace_once(
    edit,
    '''function EditMode.RegisterHolder(holder, id)
    if not holder or type(id) ~= "number" then
        return
    end
    if not Movers or type(Movers.Register) ~= "function" or type(Movers.Apply) ~= "function" then
        return
    end

    Movers:Register("actionbar" .. id, holder, CreateActionBarMoverSpec(id))
    Movers:Apply("actionbar" .. id, holder)
end
''',
    '''function EditMode.RegisterHolder(holder, id)
    if not holder or type(id) ~= "number" then
        return false, "ActionBar mover holder/id unavailable"
    end
    if not Movers or type(Movers.Register) ~= "function" or type(Movers.Apply) ~= "function" then
        return false, "Mover registry unavailable for ActionBar " .. tostring(id)
    end

    local key = "actionbar" .. id
    local registered, registerDetail = Movers:Register(key, holder, CreateActionBarMoverSpec(id))
    if registered == false then return false, registerDetail end
    local applied, applyDetail = Movers:Apply(key, holder)
    if applied == false then return false, applyDetail end
    return true
end
''',
    'ActionBars mover registration result',
)
edit_path.write_text(edit, encoding='utf-8')

facade_path = Path('modules/ActionBars.lua')
facade = facade_path.read_text(encoding='utf-8')
start = facade.index('local function CreateHolder(id)')
end = facade.index('function ActionBars:_ForEachHolder(fn)', start)
replacement = r'''local function CreateHolder(id)
    local ok, holder = pcall(
        CreateFrame,
        "Frame",
        "FGUI_ActionBarHolder" .. id,
        UIParent,
        "SecureHandlerStateTemplate"
    )
    if not ok or not holder then
        return nil, ok and "ActionBar holder creation returned nil" or tostring(holder)
    end

    holder:SetFrameStrata("LOW")
    holder:SetFrameLevel(10)
    holder.id = id
    holder.buttons = {}
    holder._layoutDirty = false
    return holder
end

local function EnsureHolderReady(holder, id)
    if not holder then return false, "ActionBar holder unavailable" end

    if holder._visibilityDriverRegistered ~= true then
        if type(_G.RegisterStateDriver) ~= "function" then
            return false, "RegisterStateDriver unavailable"
        end
        local ok, detail = pcall(
            _G.RegisterStateDriver,
            holder,
            "visibility",
            "[petbattle][overridebar][vehicleui][possessbar,@vehicle,exists] hide; show"
        )
        if not ok then
            return false, "ActionBar visibility driver failed: " .. tostring(detail)
        end
        holder._visibilityDriverRegistered = true
    end

    if not (EditMode and type(EditMode.RegisterHolder) == "function") then
        return false, "ActionBars Edit Mode mover owner unavailable"
    end
    return EditMode.RegisterHolder(holder, id)
end

function ActionBars:EnsureCreated()
    if self._created then return true end

    self.bars = self.bars or {}
    for id = 1, ACTION_BAR_COUNT do
        local holder = self.bars[id]
        if not holder then
            local detail
            holder, detail = CreateHolder(id)
            if not holder then
                return false, "ActionBar " .. tostring(id) .. ": " .. tostring(detail)
            end
            self.bars[id] = holder
        end

        local ready, detail = EnsureHolderReady(holder, id)
        if ready == false then
            return false, "ActionBar " .. tostring(id) .. ": " .. tostring(detail)
        end
    end

    self.bar1 = self.bars[1]
    self.bar2 = self.bars[2]
    self.bar3 = self.bars[3]
    self.bar4 = self.bars[4]
    self.bar5 = self.bars[5]
    self.petBar = nil
    self._created = true
    return true
end

'''
facade = facade[:start] + replacement + facade[end:]
facade_path.write_text(facade, encoding='utf-8')

runtime_path = Path('modules/ActionBarsRuntime.lua')
runtime = runtime_path.read_text(encoding='utf-8')
count = runtime.count('    module:EnsureCreated()\n')
if count != 2:
    raise RuntimeError(f'ActionBars EnsureCreated calls: expected 2, found {count}')
runtime = runtime.replace(
    '    module:EnsureCreated()\n',
    '''    local created, createDetail = module:EnsureCreated()
    if created == false then
        return false, tostring(createDetail or "ActionBars holder initialization failed")
    end
''',
    2,
)
runtime_path.write_text(runtime, encoding='utf-8')


# ---------------------------------------------------------------------------
# UnitFrames / CenterBars: mover failures block _inited publication and retry.
# ---------------------------------------------------------------------------
uf_path = Path('modules/UnitFramesRuntime.lua')
uf = uf_path.read_text(encoding='utf-8')
uf = replace_once(
    uf,
    '''    Movers:Register("player", player, Call("CreateUnitMoverSpec", "player", "Player"))
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
''',
    '''    if not (Movers and type(Movers.Register) == "function" and type(Movers.Apply) == "function") then
        return false, "UnitFrames mover registry unavailable"
    end

    local registrations = {
        { key = "player", frame = player, label = "Player" },
        { key = "target", frame = target, label = "Target" },
        { key = "focus", frame = focus, label = "Focus" },
        { key = "targettarget", frame = targettarget, label = "TargetTarget" },
    }
    for i = 1, #registrations do
        local record = registrations[i]
        local registered, detail = Movers:Register(
            record.key,
            record.frame,
            Call("CreateUnitMoverSpec", record.key, record.label)
        )
        if registered == false then
            return false, "UnitFrames mover " .. record.key .. ": " .. tostring(detail)
        end
        local applied, applyDetail = Movers:Apply(record.key, record.frame)
        if applied == false then
            return false, "UnitFrames mover " .. record.key .. ": " .. tostring(applyDetail)
        end
    end

    if type(Movers.ApplyUnlockFromDB) == "function" then
        local unlocked, unlockDetail = Movers:ApplyUnlockFromDB()
        if unlocked == false then
            return false, "UnitFrames mover unlock sync failed: " .. tostring(unlockDetail)
        end
    end

    owner._inited = true
''',
    'UnitFrames mover lifecycle',
)
uf_path.write_text(uf, encoding='utf-8')

center_path = Path('modules/CenterBarsRuntime.lua')
center = center_path.read_text(encoding='utf-8')
center = replace_once(
    center,
    '''    Movers:Register("center", f, createCenterMoverSpec("Center"))
    Movers:Apply("center", f)

    owner._inited = true
''',
    '''    if not (Movers and type(Movers.Register) == "function" and type(Movers.Apply) == "function") then
        f:Hide()
        return false, "CenterBars mover registry unavailable"
    end
    local registered, registerDetail = Movers:Register("center", f, createCenterMoverSpec("Center"))
    if registered == false then
        f:Hide()
        return false, "CenterBars mover registration failed: " .. tostring(registerDetail)
    end
    local applied, applyDetail = Movers:Apply("center", f)
    if applied == false then
        f:Hide()
        return false, "CenterBars mover apply failed: " .. tostring(applyDetail)
    end

    owner._inited = true
''',
    'CenterBars mover lifecycle',
)
center_path.write_text(center, encoding='utf-8')


# ---------------------------------------------------------------------------
# Experience / Companion anchors retry mover ownership before returning ready.
# ---------------------------------------------------------------------------
xp_path = Path('modules/ExperienceBar.lua')
xp = xp_path.read_text(encoding='utf-8')
start = xp.index('local function EnsureFrame(module)')
end = xp.index('local function UpdateRestedOverlay', start)
new_ensure_frame = r'''local function EnsureFrame(module)
    local bar = module._bar
    if not bar then
        bar = CreateFrame("StatusBar", "FGUI_XPBar", UIParent)
        bar:SetSize(420, 10)
        bar:SetPoint("CENTER", UIParent, "CENTER", 0, -296)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        bar:SetFrameStrata("LOW")
        bar:SetFrameLevel(10)
        bar:SetStatusBarTexture("Interface/Buttons/WHITE8x8")
        bar._fguiVisible = true

        bar.bg = bar:CreateTexture(nil, "BACKGROUND")
        bar.bg:SetAllPoints()
        bar.bg:SetColorTexture(0.07, 0.07, 0.07, 1)

        bar.rested = bar:CreateTexture(nil, "ARTWORK")
        bar.rested:SetColorTexture(0.15, 0.35, 0.80, 0.55)
        bar.rested:Hide()

        bar.text = bar:CreateFontString(nil, "OVERLAY")
        bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
        bar.text:SetJustifyH("CENTER")
        bar.text:SetText("")

        if Media and Media.CreateBorder then
            Media:CreateBorder(bar)
        end
        module._bar = bar
    end

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

    return bar
end

'''
xp = xp[:start] + new_ensure_frame + xp[end:]
xp = replace_once(
    xp,
    '''function XP:Update()
    local cfg, profile = GetCfg()
    local bar = EnsureFrame(self)

    if not cfg.enabled then
''',
    '''function XP:Update()
    local cfg, profile = GetCfg()
    local bar, frameDetail = EnsureFrame(self)
    if not bar then return false, frameDetail end

    if not cfg.enabled then
''',
    'ExperienceBar update mover detail',
)
xp = replace_once(
    xp,
    '''    SetBarVisible(bar, true, false)
end
''',
    '''    SetBarVisible(bar, true, false)
    return true
end
''',
    'ExperienceBar update result',
)
xp = replace_once(
    xp,
    '''    local bar = EnsureFrame(self)
    local events = EnsureEventFrame(self)
    if not (bar and events) then
        return false, "ExperienceBar initialization failed"
    end
''',
    '''    local bar, frameDetail = EnsureFrame(self)
    local events = EnsureEventFrame(self)
    if not bar then return false, frameDetail end
    if not events then return false, "ExperienceBar event owner unavailable" end
''',
    'ExperienceBar init mover result',
)
xp_path.write_text(xp, encoding='utf-8')

pet_path = Path('modules/CompanionPetBar.lua')
pet = pet_path.read_text(encoding='utf-8')
start = pet.index('local function EnsurePetAnchor(module)')
end = pet.index('local function GetPetButtonIcon', start)
new_pet_anchor = r'''local function EnsurePetAnchor(module)
    local frame = module._petAnchor
    if not frame then
        frame = CreateFrame("Frame", "FGUI_oUF_PetBarHolder", UIParent, "SecureHandlerStateTemplate")
        frame:SetSize(320, 32)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
        frame:Show()
        module._petAnchor = frame
    end

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

    ApplyPetAnchorVisibility(frame)
    return frame
end

'''
pet = pet[:start] + new_pet_anchor + pet[end:]
pet = replace_once(
    pet,
    '''    local holder = EnsurePetAnchor(module)
    if not holder then
        return false, "Pet bar holder unavailable"
    end
''',
    '''    local holder, holderDetail = EnsurePetAnchor(module)
    if not holder then
        return false, holderDetail or "Pet bar holder unavailable"
    end
''',
    'Companion pet preview mover detail',
)
pet = replace_once(
    pet,
    '''    local holder = EnsurePetAnchor(module)
    if not holder then return false, "Companion pet-bar holder unavailable" end
''',
    '''    local holder, holderDetail = EnsurePetAnchor(module)
    if not holder then return false, holderDetail or "Companion pet-bar holder unavailable" end
''',
    'Companion pet apply mover detail',
)
pet_path.write_text(pet, encoding='utf-8')

micro_path = Path('modules/CompanionMicroBags.lua')
micro = micro_path.read_text(encoding='utf-8')
start = micro.index('local function EnsureMicroAnchor(module)')
end = micro.index('local function ResolveMicroFrame', start)
new_micro_anchor = r'''local function EnsureMicroAnchor(module)
    local frame = module._microAnchor
    if not frame then
        frame = CreateFrame("Frame", "FGUI_oUF_MicroMenuHolder", UIParent)
        frame:SetSize(360, 40)
        frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 4)
        frame:Show()
        module._microAnchor = frame
    end

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
    return frame
end

'''
micro = micro[:start] + new_micro_anchor + micro[end:]
micro = replace_once(
    micro,
    '''    local anchor = EnsureMicroAnchor(module)
    if not anchor then return false, "Companion micro-menu anchor unavailable" end
''',
    '''    local anchor, anchorDetail = EnsureMicroAnchor(module)
    if not anchor then return false, anchorDetail or "Companion micro-menu anchor unavailable" end
''',
    'Companion micro apply mover detail',
)
micro_path.write_text(micro, encoding='utf-8')


# ---------------------------------------------------------------------------
# Static contracts and release docs.
# ---------------------------------------------------------------------------
check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
contracts = r'''    assertSourceIncludes('core/Movers.lua', 'local function RetireMoverEntry(owner, entry)');
    assertSourceIncludes('core/Movers.lua', 'return true, existing and "replaced" or "registered"');
    assertSourceIncludes('core/Movers.lua', 'stored mover position unavailable');
    assertSourceIncludes('core/Movers.lua', 'if firstDetail then return false, firstDetail end');
    assertSourceIncludes('modules/ActionBarsEditMode.lua', 'local registered, registerDetail = Movers:Register');
    assertSourceIncludes('modules/ActionBars.lua', 'local ready, detail = EnsureHolderReady(holder, id)');
    assertSourceIncludes('modules/UnitFramesRuntime.lua', 'UnitFrames mover unlock sync failed');
    assertSourceIncludes('modules/CenterBarsRuntime.lua', 'CenterBars mover registration failed');
    assertSourceIncludes('modules/ExperienceBar.lua', 'ExperienceBar mover registration failed');
    assertSourceIncludes('modules/CompanionPetBar.lua', 'Companion pet mover registration failed');
    assertSourceIncludes('modules/CompanionMicroBags.lua', 'Companion micro mover registration failed');
    assertSourceExcludes('modules/UnitFramesRuntime.lua', /^\s*Movers:Register\(/m, 'unchecked UnitFrames mover registration');
    assertSourceExcludes('modules/CenterBarsRuntime.lua', /^\s*Movers:Register\(/m, 'unchecked CenterBars mover registration');
    assertSourceExcludes('modules/ExperienceBar.lua', /^\s*Movers:Register\(/m, 'unchecked ExperienceBar mover registration');
    assertSourceExcludes('modules/CompanionPetBar.lua', /^\s*Movers:Register\(/m, 'unchecked Companion pet mover registration');
    assertSourceExcludes('modules/CompanionMicroBags.lua', /^\s*Movers:Register\(/m, 'unchecked Companion micro mover registration');

'''
check = replace_once(
    check,
    "    assertSourceIncludes('core/MoversTransactions.lua', 'function Transactions:CommitWrites');\n",
    contracts + "    assertSourceIncludes('core/MoversTransactions.lua', 'function Transactions:CommitWrites');\n",
    'Mover registration lifecycle static contracts',
)
check_path.write_text(check, encoding='utf-8')

toc_path = Path('FeelsGoodUI.toc')
toc = toc_path.read_text(encoding='utf-8')
toc = replace_once(toc, '## Version: 0.0.67', '## Version: 0.0.68', 'TOC version')
toc_path.write_text(toc, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(readme, '- FeelsGoodUI `0.0.67`', '- FeelsGoodUI `0.0.68`', 'README version')
readme = replace_once(
    readme,
    'Mover state follows the same ownership rule:',
    'Mover registration is replacement-safe and result-bearing: re-registering the same key updates its descriptor, replacing a frame atomically installs a new overlay and retires every old script/handle, apply reports missing/invalid stored positions, and feature `_inited`/`_created` flags publish only after registration and position apply succeed. Mover state follows the same ownership rule:',
    'README mover registry lifecycle',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    '- Change mover behavior:',
    '- Change mover registration/lifecycle: `Movers:Register` and `Movers:Apply` are result-bearing; callers must propagate failure before publishing feature `_inited`/`_created`. Re-registering a key may replace the frame, so overlays/scripts must be retired atomically and partial feature frames retained for retry.\n- Change mover behavior:',
    'AGENT_GUIDE mover lifecycle routing',
)
agent = replace_once(
    agent,
    '- Settings transaction rollback and apply-key ordering are correctness invariants:',
    '- Mover keys have one current frame owner: duplicate registration with the same frame reuses the overlay, frame replacement retires the old overlay/scripts, and failed replacement preserves the previous registry entry. No feature may ignore mover registration/apply results and then publish initialized state.\n- Settings transaction rollback and apply-key ordering are correctness invariants:',
    'AGENT_GUIDE mover lifecycle invariant',
)
agent_path.write_text(agent, encoding='utf-8')

index_path = Path('CODE_INDEX.md')
index = index_path.read_text(encoding='utf-8')
index = replace_once(
    index,
    '| `core/Movers.lua`, `core/MoversEditor.lua`, `core/MoversInspector.lua`, `core/MoversSnapGrid.lua` | Mover registry, editor overlays, inspector, snapping/grid and lock-state presentation. |',
    '| `core/Movers.lua`, `core/MoversEditor.lua`, `core/MoversInspector.lua`, `core/MoversSnapGrid.lua` | Result-bearing replacement-safe mover registry, retired-overlay cleanup, position apply, editor overlays, inspector, snapping/grid and lock-state presentation. |',
    'CODE_INDEX mover lifecycle',
)
index_path.write_text(index, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(todo, '- [x] Target Interface `120105` and release `0.0.67`.', '- [x] Target Interface `120105` and release `0.0.68`.', 'TODO version')
todo = replace_once(
    todo,
    '- [x] Make ActionBars permanent state, EndCaps, SettingsPanel and action-change hooks result-bearing: weak target/method registries prevent duplicates, partial hooks stay inert until full init publishes active owners, init/callback flags publish after success, callback generations make stale handles inert before cleanup, owner replacement is dynamic, and detach releases owners/handles.\n',
    '- [x] Make ActionBars permanent state, EndCaps, SettingsPanel and action-change hooks result-bearing: weak target/method registries prevent duplicates, partial hooks stay inert until full init publishes active owners, init/callback flags publish after success, callback generations make stale handles inert before cleanup, owner replacement is dynamic, and detach releases owners/handles.\n- [x] Make mover registration/apply result-bearing and replacement-safe: duplicate same-frame registration reuses state, frame replacement atomically retires old overlay scripts, invalid positions fail explicitly, and all feature families block initialized state until mover ownership succeeds.\n',
    'TODO mover lifecycle status',
)
todo = replace_once(
    todo,
    '- [ ] Force mover position/scale/size apply failure; profile, exact undo artifact, and visible frame geometry return to the persisted state.\n',
    '- [ ] Force mover registration, overlay creation, position apply and handle-refresh failure across ActionBars, UnitFrames, CenterBars, Companion and ExperienceBar; feature init stays pending, retry reuses partial frames, same-frame registration stays single, replacement retires every old overlay script/handle, and only the current frame receives later movement.\n- [ ] Force mover position/scale/size apply failure; profile, exact undo artifact, and visible frame geometry return to the persisted state.\n',
    'TODO mover lifecycle validation',
)
todo_path.write_text(todo, encoding='utf-8')

matrix_path = Path('docs/REGRESSION_MATRIX_1_25.md')
matrix = matrix_path.read_text(encoding='utf-8')
anchor = '| 15 | Drag, resize, wheel-adjust, reset, undo, and lock movers | Preview does not write SavedVariables; each terminal action is one transaction; rollback restores exact geometry |  |  |'
replacement = anchor + '\n| 15a | Re-register each mover key with same and replacement frames; inject overlay/position failure and retry | Same frame reuses one overlay; replacement retires old scripts/handle; failed replacement preserves prior owner; feature init publishes only after register+apply success |  |  |'
matrix = replace_once(matrix, anchor, replacement, 'regression matrix mover registration')
matrix_path.write_text(matrix, encoding='utf-8')

print('Made mover registration and feature lifecycle result-bearing.')
