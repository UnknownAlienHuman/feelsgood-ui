from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


render_path = Path('modules/CenterBarsRender.lua')
render = render_path.read_text(encoding='utf-8')
old_block = r'''local function SoftHideFrame(frame)
    if not frame then
        return
    end
    pcall(frame.SetAlpha, frame, 0)
    pcall(frame.Hide, frame)
end

local function RestoreFrameSuppression(frame)
    if not frame then
        return
    end
    frame._fguiSuppressRequested = nil
    pcall(frame.SetAlpha, frame, 1)
    if type(frame.Setup) == "function" then
        pcall(frame.Setup, frame)
        return
    end
    pcall(frame.Show, frame)
end

local function EnsureFrameHideHook(frame)
    if not frame or frame._fguiSuppressHooked then
        return
    end
    if type(frame.HookScript) == "function" then
        pcall(frame.HookScript, frame, "OnShow", function(self)
            if self._fguiSuppressRequested then
                SoftHideFrame(self)
            end
        end)
    end
    frame._fguiSuppressHooked = true
end

local function GetSuppressedFrameRegistry(owner)
    if type(owner._suppressedClassResourceFrames) ~= "table" then
        owner._suppressedClassResourceFrames = {}
    end
    return owner._suppressedClassResourceFrames
end

function Render.RestoreDefaultClassResources(owner)
    if type(owner) ~= "table" then
        return
    end

    owner._pendingClassResourceSync = nil

    local registry = owner._suppressedClassResourceFrames
    if type(registry) ~= "table" then
        return
    end

    for name, frame in pairs(registry) do
        RestoreFrameSuppression(frame)
        registry[name] = nil
    end
end

function Render.SyncDefaultClassResources(owner)
    if type(owner) ~= "table" then
        return
    end

    local center = GetCenterCfg()
    local hideNames = owner._hideFrames
    local shouldHide = center.hideBlizzardClassResources ~= false
        and type(hideNames) == "table"
        and #hideNames > 0

    if _G.InCombatLockdown and InCombatLockdown() then
        owner._pendingClassResourceSync = true
        return
    end

    owner._pendingClassResourceSync = nil

    if not shouldHide then
        Render.RestoreDefaultClassResources(owner)
        return
    end

    local registry = GetSuppressedFrameRegistry(owner)
    local activeNames = {}

    for _, name in ipairs(hideNames) do
        activeNames[name] = true
        local frame = name and _G[name]
        if frame then
            EnsureFrameHideHook(frame)
            frame._fguiSuppressRequested = true
            registry[name] = frame
            SoftHideFrame(frame)
        end
    end

    for name, frame in pairs(registry) do
        if not activeNames[name] then
            RestoreFrameSuppression(frame)
            registry[name] = nil
        end
    end
end
'''
new_block = r'''local function ReadNativeFrameAlpha(frame)
    if not (frame and type(frame.GetAlpha) == "function") then return nil end
    local ok, value = pcall(frame.GetAlpha, frame)
    return ok and type(value) == "number" and value or nil
end

local function ReadNativeFrameMouseEnabled(frame)
    if not (frame and type(frame.IsMouseEnabled) == "function") then return nil end
    local ok, value = pcall(frame.IsMouseEnabled, frame)
    if not ok or type(value) ~= "boolean" then return nil end
    return value
end

local function SetNativeFrameAlpha(frame, value)
    if not (frame and type(frame.SetAlpha) == "function" and type(value) == "number") then
        return false
    end
    if ReadNativeFrameAlpha(frame) == value then return true end
    return pcall(frame.SetAlpha, frame, value)
end

local function SetNativeFrameMouseEnabled(frame, enabled)
    if not (frame and type(frame.EnableMouse) == "function" and type(enabled) == "boolean") then
        return false
    end
    if ReadNativeFrameMouseEnabled(frame) == enabled then return true end
    return pcall(frame.EnableMouse, frame, enabled)
end

local function ApplyClassResourceSuppression(frame)
    if not frame then return false end
    SetNativeFrameAlpha(frame, 0)
    SetNativeFrameMouseEnabled(frame, false)
    return true
end

local function RestoreClassResourceRecord(record)
    local frame = record and record.frame
    if not frame then return false end

    -- Restore only values that still carry our suppression state. A newer
    -- conflicting owner wins and is never overwritten during detach/disable.
    if type(record.alpha) == "number" and ReadNativeFrameAlpha(frame) == 0 then
        SetNativeFrameAlpha(frame, record.alpha)
    end
    if type(record.mouseEnabled) == "boolean" and ReadNativeFrameMouseEnabled(frame) == false then
        SetNativeFrameMouseEnabled(frame, record.mouseEnabled)
    end
    return true
end

local function GetClassResourceRegistry(owner)
    if type(owner._classResourceSuppression) ~= "table" then
        owner._classResourceSuppression = {}
    end
    return owner._classResourceSuppression
end

local function EnsureClassResourceShowHook(owner, frame)
    if not (owner and frame and type(frame.HookScript) == "function") then
        return false
    end

    owner._classResourceSuppressionHooks = type(owner._classResourceSuppressionHooks) == "table"
        and owner._classResourceSuppressionHooks
        or {}
    if owner._classResourceSuppressionHooks[frame] then return true end

    local ok = pcall(frame.HookScript, frame, "OnShow", function(shownFrame)
        if owner._classResourceSuppressionActive ~= true then return end
        for _, record in pairs(owner._classResourceSuppression or EMPTY) do
            if record.frame == shownFrame then
                ApplyClassResourceSuppression(shownFrame)
                return
            end
        end
    end)
    if ok then
        owner._classResourceSuppressionHooks[frame] = true
    end
    return ok
end

local function SuppressClassResourceFrame(owner, name, frame)
    if type(owner) ~= "table" or type(name) ~= "string" or name == "" or not frame then
        return false
    end

    local registry = GetClassResourceRegistry(owner)
    local record = registry[name]
    if record and record.frame ~= frame then
        RestoreClassResourceRecord(record)
        registry[name] = nil
        record = nil
    end

    if not record then
        record = {
            frame = frame,
            alpha = ReadNativeFrameAlpha(frame),
            mouseEnabled = ReadNativeFrameMouseEnabled(frame),
        }
        registry[name] = record
    end

    EnsureClassResourceShowHook(owner, frame)
    return ApplyClassResourceSuppression(frame)
end

function Render.RestoreDefaultClassResources(owner)
    if type(owner) ~= "table" then return false end

    owner._pendingClassResourceSync = nil
    owner._classResourceSuppressionActive = false

    local registry = owner._classResourceSuppression
    if type(registry) ~= "table" then return true end

    for name, record in pairs(registry) do
        RestoreClassResourceRecord(record)
        registry[name] = nil
    end
    return true
end

function Render.SyncDefaultClassResources(owner)
    if type(owner) ~= "table" then return false end

    local center = GetCenterCfg()
    local hideNames = owner._hideFrames
    local shouldHide = center.hideBlizzardClassResources ~= false
        and type(hideNames) == "table"
        and #hideNames > 0

    if _G.InCombatLockdown and InCombatLockdown() then
        owner._pendingClassResourceSync = true
        return true
    end

    owner._pendingClassResourceSync = nil
    if not shouldHide then
        return Render.RestoreDefaultClassResources(owner)
    end

    owner._classResourceSuppressionActive = true
    local registry = GetClassResourceRegistry(owner)
    local activeNames = {}

    for i = 1, #hideNames do
        local name = hideNames[i]
        if type(name) == "string" and name ~= "" then
            activeNames[name] = true
            local frame = _G[name]
            if frame then
                SuppressClassResourceFrame(owner, name, frame)
            end
        end
    end

    for name, record in pairs(registry) do
        if not activeNames[name] then
            RestoreClassResourceRecord(record)
            registry[name] = nil
        end
    end
    return true
end
'''
render = replace_once(render, old_block, new_block, 'CenterBars native suppression owner')
render_path.write_text(render, encoding='utf-8')

check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
check = replace_once(
    check,
    "    assertSourceIncludes('modules/ExperienceBar.lua', 'SuppressBlizzardStatusTracking');\n",
    "    assertSourceIncludes('modules/CenterBarsRender.lua', 'owner._classResourceSuppression');\n"
    "    assertSourceIncludes('modules/CenterBarsRender.lua', 'EnsureClassResourceShowHook');\n"
    "    assertSourceIncludes('modules/CenterBarsRender.lua', 'RestoreClassResourceRecord');\n"
    "    assertSourceExcludes('modules/CenterBarsRender.lua', /pcall\\(frame\\.Hide,\\s*frame\\)/, 'native class-resource Hide takeover');\n"
    "    assertSourceExcludes('modules/CenterBarsRender.lua', /pcall\\(frame\\.Show,\\s*frame\\)/, 'native class-resource Show restore');\n"
    "    assertSourceExcludes('modules/CenterBarsRender.lua', /pcall\\(frame\\.Setup,\\s*frame\\)/, 'foreign class-resource Setup restore');\n"
    "    assertSourceExcludes('modules/CenterBarsRender.lua', /_fguiSuppress(?:Requested|Hooked)/, 'foreign class-resource ownership markers');\n\n"
    "    assertSourceIncludes('modules/ExperienceBar.lua', 'SuppressBlizzardStatusTracking');\n",
    'CenterBars native ownership contracts',
)
check_path.write_text(check, encoding='utf-8')

# Release metadata and documentation.
toc_path = Path('FeelsGoodUI.toc')
toc = toc_path.read_text(encoding='utf-8')
toc = replace_once(toc, '## Version: 0.0.55', '## Version: 0.0.56', 'TOC version')
toc_path.write_text(toc, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(readme, '- FeelsGoodUI `0.0.55`', '- FeelsGoodUI `0.0.56`', 'README version')
readme = replace_once(
    readme,
    'ExperienceBar suppresses native status tracking through captured alpha/mouse ownership only: it never hides or unconditionally shows foreign frames, reasserts suppression after Blizzard refreshes, and restores only properties that still carry its owned values.',
    'ExperienceBar suppresses native status tracking through captured alpha/mouse ownership only: it never hides or unconditionally shows foreign frames, reasserts suppression after Blizzard refreshes, and restores only properties that still carry its owned values. CenterBars follows the same narrow policy for Blizzard class-resource frames: owner-local snapshots and hooks replace foreign-frame markers, frame replacement restores the old instance before adopting the new one, and combat-deferred sync never guesses visibility or calls native setup.',
    'README CenterBars native ownership',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    '- Center bars: `CenterBars.lua` delegates render/runtime and listens to player power/rune/world/spec events. Companion and ExperienceBar are independent feature families registered through the same lifecycle. `ExperienceBar` owns one lifecycle apply path and a reversible alpha/mouse takeover of Blizzard status-tracking frames; it never calls `Hide`/`Show` on those foreign frames.',
    '- Center bars: `CenterBars.lua` delegates render/runtime and listens to player power/rune/world/spec events. `CenterBarsRender` owns reversible alpha/mouse suppression of Blizzard class-resource frames through owner-local records and permanent gated OnShow hooks; it never adds fields to foreign frames or calls their `Hide`/`Show`/`Setup`. Companion and ExperienceBar are independent feature families registered through the same lifecycle. `ExperienceBar` owns one lifecycle apply path and the same narrow reversible policy for Blizzard status-tracking frames.',
    'AGENT_GUIDE CenterBars owner',
)
agent_path.write_text(agent, encoding='utf-8')

index_path = Path('CODE_INDEX.md')
index = index_path.read_text(encoding='utf-8')
index = replace_once(
    index,
    '| `modules/CenterBars*.lua`, `modules/Companion*.lua` | Center-resource and companion feature families. |',
    '| `modules/CenterBars*.lua` | Center-resource rendering/runtime plus reversible, conflict-aware Blizzard class-resource alpha/mouse ownership. |\n| `modules/Companion*.lua` | Companion pet-bar, micro-menu, bags, and lifecycle ownership. |',
    'CODE_INDEX CenterBars ownership',
)
index_path.write_text(index, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(todo, '- [x] Target Interface `120105` and release `0.0.55`.', '- [x] Target Interface `120105` and release `0.0.56`.', 'TODO version')
todo = replace_once(
    todo,
    '- [x] Make ExperienceBar native takeover narrow and reversible: capture alpha/mouse state without hiding foreign frames, keep one lifecycle apply owner, re-suppress after Blizzard refreshes, and restore only properties still carrying addon-owned values.\n',
    '- [x] Make ExperienceBar native takeover narrow and reversible: capture alpha/mouse state without hiding foreign frames, keep one lifecycle apply owner, re-suppress after Blizzard refreshes, and restore only properties still carrying addon-owned values.\n'
    '- [x] Make CenterBars class-resource takeover narrow and reversible: keep snapshots/hooks on the owner, never stamp or Hide/Show/Setup foreign frames, handle native frame replacement, and preserve newer conflicting alpha/mouse changes on release.\n',
    'TODO CenterBars ownership status',
)
todo = replace_once(
    todo,
    '- [ ] Center bars handle ordinary and restricted power/rune values without duplicate producer calls, error loops, retained opaque samples, or stale text.\n',
    '- [ ] Center bars handle ordinary and restricted power/rune values without duplicate producer calls, error loops, retained opaque samples, or stale text.\n'
    '- [ ] Across DK/Rogue/Druid/Paladin/Monk/Warlock/Mage/Evoker, give native class-resource frames distinctive alpha/mouse/visibility states, trigger OnShow, replace a named frame, toggle suppression in combat, and verify zero addon Hide/Show/Setup calls, exact owned-property restore, and preservation of newer conflicting changes.\n',
    'TODO CenterBars ownership validation',
)
todo_path.write_text(todo, encoding='utf-8')

matrix_path = Path('docs/REGRESSION_MATRIX_1_25.md')
matrix = matrix_path.read_text(encoding='utf-8')
matrix = replace_once(
    matrix,
    '| 18 | Point resources across supported classes/specs | Segment count/fill/color follows current max and caps safely |  |  |',
    '| 18 | Point resources across supported classes/specs | Segment count/fill/color follows current max and caps safely |  |  |\n'
    '| 18a | Native class-resource takeover across supported classes, including OnShow, frame replacement, combat-deferred toggle, and conflicting external changes | No addon `Hide`/`Show`/`Setup` or foreign markers; owner-local alpha/mouse suppression restores exact still-owned values and preserves newer conflicts |  |  |',
    'regression matrix CenterBars ownership',
)
matrix_path.write_text(matrix, encoding='utf-8')

print('Hardened CenterBars native class-resource ownership.')
