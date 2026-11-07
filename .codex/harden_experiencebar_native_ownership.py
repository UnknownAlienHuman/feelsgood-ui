from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


xp_path = Path('modules/ExperienceBar.lua')
text = xp_path.read_text(encoding='utf-8')

old_takeover = r'''local function SoftHideStatusTrackingFrame(frame)
    if not frame then
        return
    end
    pcall(frame.SetAlpha, frame, 0)
    pcall(frame.Hide, frame)
end

local function HideBlizzardStatusTracking()
    for i = 1, #STATUS_TRACKING_FRAME_NAMES do
        SoftHideStatusTrackingFrame(_G[STATUS_TRACKING_FRAME_NAMES[i]])
    end
end

local function RestoreBlizzardStatusTracking()
    local manager = _G.StatusTrackingBarManager
    if not manager then
        return
    end

    pcall(manager.SetAlpha, manager, 1)
    pcall(manager.Show, manager)

    if type(manager.UpdateBarsShown) == "function" then
        pcall(manager.UpdateBarsShown, manager)
    end
    if type(manager.UpdateBarVisuals) == "function" then
        pcall(manager.UpdateBarVisuals, manager, true)
    end
end

local function EnsureStatusTrackingHooks(module)
    if module._statusTrackingHooked then
        return
    end

    local manager = _G.StatusTrackingBarManager
    if type(manager) ~= "table" then
        return
    end

    local function Rehide()
        if module._suppressBlizzardTracking == true then
            HideBlizzardStatusTracking()
        end
    end

    if type(manager.UpdateBarsShown) == "function" then
        hooksecurefunc(manager, "UpdateBarsShown", Rehide)
    end
    if type(manager.UpdateBarVisuals) == "function" then
        hooksecurefunc(manager, "UpdateBarVisuals", Rehide)
    end

    module._statusTrackingHooked = true
end
'''
new_takeover = r'''local function ReadFrameAlpha(frame)
    if not (frame and type(frame.GetAlpha) == "function") then return nil end
    local ok, value = pcall(frame.GetAlpha, frame)
    return ok and type(value) == "number" and value or nil
end

local function ReadFrameMouseEnabled(frame)
    if not (frame and type(frame.IsMouseEnabled) == "function") then return nil end
    local ok, value = pcall(frame.IsMouseEnabled, frame)
    return ok and type(value) == "boolean" and value or nil
end

local function SetFrameAlpha(frame, value)
    if not (frame and type(frame.SetAlpha) == "function" and type(value) == "number") then
        return false
    end
    local current = ReadFrameAlpha(frame)
    if current == value then return true end
    return pcall(frame.SetAlpha, frame, value)
end

local function SetFrameMouseEnabled(frame, enabled)
    if not (frame and type(frame.EnableMouse) == "function" and type(enabled) == "boolean") then
        return false
    end
    local current = ReadFrameMouseEnabled(frame)
    if current == enabled then return true end
    return pcall(frame.EnableMouse, frame, enabled)
end

local function CaptureStatusTrackingFrame(module, frame)
    if type(module) ~= "table" or type(frame) ~= "table" then return nil end
    module._statusTrackingSnapshot = type(module._statusTrackingSnapshot) == "table"
        and module._statusTrackingSnapshot
        or {}

    local record = module._statusTrackingSnapshot[frame]
    if record then return record end

    record = {
        alpha = ReadFrameAlpha(frame),
        mouseEnabled = ReadFrameMouseEnabled(frame),
    }
    module._statusTrackingSnapshot[frame] = record
    return record
end

local function SuppressBlizzardStatusTracking(module)
    for i = 1, #STATUS_TRACKING_FRAME_NAMES do
        local frame = _G[STATUS_TRACKING_FRAME_NAMES[i]]
        if type(frame) == "table" then
            CaptureStatusTrackingFrame(module, frame)
            SetFrameAlpha(frame, 0)
            SetFrameMouseEnabled(frame, false)
        end
    end
    return true
end

local function RestoreBlizzardStatusTracking(module)
    local snapshot = module and module._statusTrackingSnapshot
    if type(snapshot) ~= "table" then return true end

    module._statusTrackingSnapshot = nil
    for frame, record in pairs(snapshot) do
        if type(frame) == "table" and type(record) == "table" then
            -- Restore only properties that still carry our suppression value.
            -- A different owner changing them while attached wins.
            if type(record.alpha) == "number" and ReadFrameAlpha(frame) == 0 then
                SetFrameAlpha(frame, record.alpha)
            end
            if type(record.mouseEnabled) == "boolean" and ReadFrameMouseEnabled(frame) == false then
                SetFrameMouseEnabled(frame, record.mouseEnabled)
            end
        end
    end
    return true
end

local function EnsureStatusTrackingHooks(module)
    if module._statusTrackingHooked then return true end

    local manager = _G.StatusTrackingBarManager
    local secureHook = _G.hooksecurefunc or hooksecurefunc
    if type(manager) ~= "table" or type(secureHook) ~= "function" then
        return false
    end

    local hooked = false
    local function Resuppress()
        if module._suppressBlizzardTracking == true then
            SuppressBlizzardStatusTracking(module)
        end
    end

    if type(manager.UpdateBarsShown) == "function" then
        secureHook(manager, "UpdateBarsShown", Resuppress)
        hooked = true
    end
    if type(manager.UpdateBarVisuals) == "function" then
        secureHook(manager, "UpdateBarVisuals", Resuppress)
        hooked = true
    end

    module._statusTrackingHooked = hooked
    return hooked
end

local function MaintainStatusTrackingOwnership(module)
    EnsureStatusTrackingHooks(module)
    return SuppressBlizzardStatusTracking(module)
end
'''
text = replace_once(text, old_takeover, new_takeover, 'ExperienceBar native takeover block')

old_events = r'''    local ev = CreateFrame("Frame")
    ev:SetScript("OnEvent", function(_, event, unit)
        if (event == "PLAYER_XP_UPDATE" or event == "HONOR_XP_UPDATE" or event == "PLAYER_MAX_LEVEL_UPDATE") and unit and unit ~= "player" then
            return
        end
        if ns and ns.ExperienceBar and ns.ExperienceBar.Update then
            ns.ExperienceBar:Update()
        end
    end)
'''
new_events = r'''    local ev = CreateFrame("Frame")
    ev:SetScript("OnEvent", function(_, event, unit)
        if (event == "PLAYER_XP_UPDATE" or event == "HONOR_XP_UPDATE" or event == "PLAYER_MAX_LEVEL_UPDATE") and unit and unit ~= "player" then
            return
        end
        if module._suppressBlizzardTracking == true then
            MaintainStatusTrackingOwnership(module)
        end
        if type(module.Update) == "function" then
            module:Update()
        end
    end)
'''
text = replace_once(text, old_events, new_events, 'ExperienceBar event owner')

old_apply = r'''function XP:ApplyConfig()
    local cfg = GetCfg()
    local bar = EnsureFrame(self)
    local ev = EnsureEventFrame(self)

    EnsureStatusTrackingHooks(self)

    ev:UnregisterAllEvents()
    if not cfg.enabled then
        self._suppressBlizzardTracking = nil
        RestoreBlizzardStatusTracking()
        SetBarVisible(bar, false, true)
        return
    end

    self._suppressBlizzardTracking = true
    HideBlizzardStatusTracking()

    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("PLAYER_XP_UPDATE")
    ev:RegisterEvent("PLAYER_MAX_LEVEL_UPDATE")
    ev:RegisterEvent("PLAYER_LEVEL_CHANGED")
    ev:RegisterEvent("PLAYER_LEVEL_UP")
    ev:RegisterEvent("UPDATE_EXHAUSTION")
    ev:RegisterEvent("UPDATE_FACTION")
    ev:RegisterEvent("HONOR_XP_UPDATE")
    ev:RegisterEvent("ENABLE_XP_GAIN")
    ev:RegisterEvent("DISABLE_XP_GAIN")

    self:Update()
end
'''
new_apply = r'''function XP:ApplyConfig()
    local initialized, initDetail = self:Init()
    if initialized == false then return false, initDetail end

    local cfg = GetCfg()
    local bar = self._bar
    local ev = self._events
    if not (bar and ev) then
        return false, "ExperienceBar runtime owners unavailable"
    end

    ev:UnregisterAllEvents()
    if not cfg.enabled then
        self._suppressBlizzardTracking = nil
        RestoreBlizzardStatusTracking(self)
        SetBarVisible(bar, false, true)
        return true
    end

    self._suppressBlizzardTracking = true
    MaintainStatusTrackingOwnership(self)

    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("PLAYER_XP_UPDATE")
    ev:RegisterEvent("PLAYER_MAX_LEVEL_UPDATE")
    ev:RegisterEvent("PLAYER_LEVEL_CHANGED")
    ev:RegisterEvent("PLAYER_LEVEL_UP")
    ev:RegisterEvent("UPDATE_EXHAUSTION")
    ev:RegisterEvent("UPDATE_FACTION")
    ev:RegisterEvent("HONOR_XP_UPDATE")
    ev:RegisterEvent("ENABLE_XP_GAIN")
    ev:RegisterEvent("DISABLE_XP_GAIN")

    self:Update()
    return true
end
'''
text = replace_once(text, old_apply, new_apply, 'ExperienceBar ApplyConfig ownership')

old_lifecycle = r'''function XP:Attach()
    if self._attached then
        return
    end
    self._attached = true
    self:Init()
end

function XP:Detach()
    if not self._attached then
        return
    end
    self._attached = false

    if self._events and self._events.UnregisterAllEvents then
        self._events:UnregisterAllEvents()
    end
    self._suppressBlizzardTracking = nil
    RestoreBlizzardStatusTracking()
    if self._bar then
        SetBarVisible(self._bar, false, true)
    end
end

function XP:Enable()
    self:Attach()
    self:ApplyConfig()
end

function XP:Disable()
    self:Detach()
end

function XP:Init()
    if self._inited then
        return
    end
    self._inited = true

    EnsureFrame(self)
    EnsureEventFrame(self)
    self:ApplyConfig()

    if Log and Log.Debug then
        Log:Debug("ExperienceBar loaded")
    end
end
'''
new_lifecycle = r'''function XP:Attach()
    if self._attached then return true end

    local initialized, detail = self:Init()
    if initialized == false then return false, detail end
    self._attached = true
    return true
end

function XP:Detach()
    self._attached = false

    if self._events and self._events.UnregisterAllEvents then
        self._events:UnregisterAllEvents()
    end
    self._suppressBlizzardTracking = nil
    RestoreBlizzardStatusTracking(self)
    if self._bar then
        SetBarVisible(self._bar, false, true)
    end
    return true
end

function XP:Init()
    if self._inited then return true end

    local bar = EnsureFrame(self)
    local events = EnsureEventFrame(self)
    if not (bar and events) then
        return false, "ExperienceBar initialization failed"
    end

    self._inited = true
    if Log and Log.Debug then
        Log:Debug("ExperienceBar loaded")
    end
    return true
end
'''
text = replace_once(text, old_lifecycle, new_lifecycle, 'ExperienceBar lifecycle owner')
xp_path.write_text(text, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
check = replace_once(
    check,
    "    assertSourceIncludes('core/MinimapIcon.lua', 'local runtimeCfg = {}');\n",
    "    assertSourceIncludes('modules/ExperienceBar.lua', 'SuppressBlizzardStatusTracking');\n"
    "    assertSourceIncludes('modules/ExperienceBar.lua', 'module._statusTrackingSnapshot');\n"
    "    assertSourceIncludes('modules/ExperienceBar.lua', 'MaintainStatusTrackingOwnership');\n"
    "    assertSourceExcludes('modules/ExperienceBar.lua', /pcall\\(frame\\.Hide,\\s*frame\\)/, 'native status-frame Hide takeover');\n"
    "    assertSourceExcludes('modules/ExperienceBar.lua', /function\\s+XP:Enable\\(/, 'parallel ExperienceBar lifecycle enable owner');\n"
    "    assertSourceExcludes('modules/ExperienceBar.lua', /function\\s+XP:Disable\\(/, 'parallel ExperienceBar lifecycle disable owner');\n"
    "    assertSourceExcludes('modules/ExperienceBar.lua', /pcall\\(manager\\.Show/, 'unconditional Blizzard status manager Show');\n\n"
    "    assertSourceIncludes('core/MinimapIcon.lua', 'local runtimeCfg = {}');\n",
    'ExperienceBar native ownership contracts',
)
check_path.write_text(check, encoding='utf-8')

# Release metadata and documentation.
toc_path = Path('FeelsGoodUI.toc')
toc = toc_path.read_text(encoding='utf-8')
toc = replace_once(toc, '## Version: 0.0.54', '## Version: 0.0.55', 'TOC version')
toc_path.write_text(toc, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(readme, '- FeelsGoodUI `0.0.54`', '- FeelsGoodUI `0.0.55`', 'README version')
readme = replace_once(
    readme,
    'Protected action-bar and Blizzard-frame mutations remain deferred outside combat.',
    'Protected action-bar and Blizzard-frame mutations remain deferred outside combat. ExperienceBar suppresses native status tracking through captured alpha/mouse ownership only: it never hides or unconditionally shows foreign frames, reasserts suppression after Blizzard refreshes, and restores only properties that still carry its owned values.',
    'README ExperienceBar native ownership',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    '- Center bars: `CenterBars.lua` delegates render/runtime and listens to player power/rune/world/spec events. Companion and ExperienceBar are independent feature families registered through the same lifecycle.',
    '- Center bars: `CenterBars.lua` delegates render/runtime and listens to player power/rune/world/spec events. Companion and ExperienceBar are independent feature families registered through the same lifecycle. `ExperienceBar` owns one lifecycle apply path and a reversible alpha/mouse takeover of Blizzard status-tracking frames; it never calls `Hide`/`Show` on those foreign frames.',
    'AGENT_GUIDE ExperienceBar owner',
)
agent = replace_once(
    agent,
    '- Third-party runtime adapters must not receive live SavedVariables tables when they can mutate them;',
    '- Foreign Blizzard-frame takeover must mutate the narrowest properties, capture them before first write, avoid duplicate lifecycle owners, and restore only values still owned by the addon.\n- Third-party runtime adapters must not receive live SavedVariables tables when they can mutate them;',
    'AGENT_GUIDE foreign frame invariant',
)
agent_path.write_text(agent, encoding='utf-8')

index_path = Path('CODE_INDEX.md')
index = index_path.read_text(encoding='utf-8')
index = replace_once(
    index,
    '| `modules/CenterBars*.lua`, `modules/Companion*.lua`, `modules/ExperienceBar.lua` | Other feature families. |',
    '| `modules/CenterBars*.lua`, `modules/Companion*.lua` | Center-resource and companion feature families. |\n| `modules/ExperienceBar.lua` | XP/reputation/honor presentation, single lifecycle apply owner, and reversible Blizzard status-tracking alpha/mouse suppression. |',
    'CODE_INDEX ExperienceBar ownership',
)
index_path.write_text(index, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(todo, '- [x] Target Interface `120105` and release `0.0.54`.', '- [x] Target Interface `120105` and release `0.0.55`.', 'TODO version')
todo = replace_once(
    todo,
    '- [x] Isolate LibDBIcon from SavedVariables: use a detached minimap proxy during drag, commit one normalized position on drag stop, restore persisted state on failure/cancel, and remove the dead per-addon radius field.\n',
    '- [x] Isolate LibDBIcon from SavedVariables: use a detached minimap proxy during drag, commit one normalized position on drag stop, restore persisted state on failure/cancel, and remove the dead per-addon radius field.\n'
    '- [x] Make ExperienceBar native takeover narrow and reversible: capture alpha/mouse state without hiding foreign frames, keep one lifecycle apply owner, re-suppress after Blizzard refreshes, and restore only properties still carrying addon-owned values.\n',
    'TODO ExperienceBar status',
)
todo = replace_once(
    todo,
    '- [ ] Resize/scale ActionBars, UnitFrames, CenterBars, Companion PetBar, and ExperienceBar; each terminal action produces one undo entry and one owner apply.\n',
    '- [ ] Resize/scale ActionBars, UnitFrames, CenterBars, Companion PetBar, and ExperienceBar; each terminal action produces one undo entry and one owner apply.\n'
    '- [ ] Give Blizzard status-tracking manager/containers distinctive alpha, mouse and visibility states, enable/disable ExperienceBar repeatedly, trigger native refreshes, and verify no foreign `Hide`/`Show`, one lifecycle apply, exact owned-property restore, and preservation of conflicting newer changes.\n',
    'TODO ExperienceBar validation',
)
todo_path.write_text(todo, encoding='utf-8')

matrix_path = Path('docs/REGRESSION_MATRIX_1_25.md')
matrix = matrix_path.read_text(encoding='utf-8')
matrix = replace_once(
    matrix,
    '| 23 | Experience/reputation/honor states | Correct bar is shown; capped/unsupported states hide cleanly |  |  |',
    '| 23 | Experience/reputation/honor states plus repeated enable/disable and native manager refresh | Correct custom bar is shown; native status frames retain visibility ownership, receive no addon `Hide`/`Show`, and restore captured alpha/mouse state without overwriting newer conflicting changes |  |  |',
    'regression matrix ExperienceBar ownership',
)
matrix_path.write_text(matrix, encoding='utf-8')

print('Hardened ExperienceBar native frame and lifecycle ownership.')
