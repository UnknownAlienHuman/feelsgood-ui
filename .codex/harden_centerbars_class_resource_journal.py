from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# CenterBarsRender: verified, retryable per-property ownership journal.
# ---------------------------------------------------------------------------
render_path = Path('modules/CenterBarsRender.lua')
render = render_path.read_text(encoding='utf-8')
render = replace_once(
    render,
    '''local Media = ns.Media
local Secret = ns.Secret
''',
    '''local Log = ns.Log
local Media = ns.Media
local Secret = ns.Secret
''',
    'CenterBars render logger',
)

start = render.index('local function ReadNativeFrameAlpha(frame)')
end = render.index('function Render.HideDefaultClassResources(owner)', start)
replacement = r'''local CLASS_RESOURCE_MANAGED_ALPHA = 0
local CLASS_RESOURCE_MANAGED_MOUSE = false
local CLASS_RESOURCE_ALPHA_EPSILON = 0.0001

local function ClassResourceFrameLabel(name, frame)
    if type(name) == "string" and name ~= "" then
        return name
    end
    if frame and type(frame.GetName) == "function" then
        local ok, value = pcall(frame.GetName, frame)
        if ok and type(value) == "string" and value ~= "" then
            return value
        end
    end
    return tostring(frame or "unknown class-resource frame")
end

local function SameClassResourceAlpha(a, b)
    return type(a) == "number"
        and type(b) == "number"
        and math.abs(a - b) <= CLASS_RESOURCE_ALPHA_EPSILON
end

local function ReadNativeFrameAlpha(frame)
    if not (frame and type(frame.GetAlpha) == "function") then
        return false, nil, "GetAlpha is unavailable"
    end
    local ok, value = pcall(frame.GetAlpha, frame)
    if not ok then
        return false, nil, "GetAlpha failed: " .. tostring(value)
    end
    if type(value) ~= "number" then
        return false, nil, "GetAlpha returned a non-number"
    end
    return true, value
end

local function ReadNativeFrameMouseEnabled(frame)
    if not (frame and type(frame.IsMouseEnabled) == "function") then
        return false, nil, "IsMouseEnabled is unavailable"
    end
    local ok, value = pcall(frame.IsMouseEnabled, frame)
    if not ok then
        return false, nil, "IsMouseEnabled failed: " .. tostring(value)
    end
    if type(value) ~= "boolean" then
        return false, nil, "IsMouseEnabled returned a non-boolean"
    end
    return true, value
end

local function SetNativeFrameAlpha(frame, value)
    local readable, current, readDetail = ReadNativeFrameAlpha(frame)
    if not readable then
        return false, readDetail
    end
    if SameClassResourceAlpha(current, value) then
        return true
    end
    if type(frame.SetAlpha) ~= "function" then
        return false, "SetAlpha is unavailable"
    end

    local ok, detail = pcall(frame.SetAlpha, frame, value)
    if not ok then
        return false, "SetAlpha failed: " .. tostring(detail)
    end

    local verified, actual, verifyDetail = ReadNativeFrameAlpha(frame)
    if not verified then
        return false, "SetAlpha could not be verified: " .. tostring(verifyDetail)
    end
    if not SameClassResourceAlpha(actual, value) then
        return false, "SetAlpha did not retain the requested value"
    end
    return true
end

local function SetNativeFrameMouseEnabled(frame, enabled)
    local readable, current, readDetail = ReadNativeFrameMouseEnabled(frame)
    if not readable then
        return false, readDetail
    end
    if current == enabled then
        return true
    end
    if type(frame.EnableMouse) ~= "function" then
        return false, "EnableMouse is unavailable"
    end

    local ok, detail = pcall(frame.EnableMouse, frame, enabled)
    if not ok then
        return false, "EnableMouse failed: " .. tostring(detail)
    end

    local verified, actual, verifyDetail = ReadNativeFrameMouseEnabled(frame)
    if not verified then
        return false, "EnableMouse could not be verified: " .. tostring(verifyDetail)
    end
    if actual ~= enabled then
        return false, "EnableMouse did not retain the requested value"
    end
    return true
end

local function GetClassResourceRegistry(owner)
    if type(owner._classResourceSuppression) ~= "table" then
        owner._classResourceSuppression = {}
    end
    return owner._classResourceSuppression
end

local function GetClassResourceHookRegistry(owner)
    local registry = owner._classResourceSuppressionHooks
    local meta = type(registry) == "table" and getmetatable(registry) or nil
    if type(registry) ~= "table" or type(meta) ~= "table" or meta.__mode ~= "k" then
        local replacement = setmetatable({}, { __mode = "k" })
        if type(registry) == "table" then
            for frame, record in pairs(registry) do
                if type(record) == "table" then
                    replacement[frame] = record
                elseif record == true then
                    replacement[frame] = { OnShow = true }
                end
            end
        end
        registry = replacement
        owner._classResourceSuppressionHooks = registry
    end
    return registry
end

local function AppendClassResourceFailure(failures, label, detail)
    failures[#failures + 1] = tostring(label) .. ": " .. tostring(detail or "unknown failure")
end

local function CaptureClassResourceFrame(record)
    local frame = record and record.frame
    if not frame then return end

    if record.alphaCaptured ~= true and record.alphaOwned ~= true then
        local ok, value, detail = ReadNativeFrameAlpha(frame)
        if ok then
            record.alpha = value
            record.alphaCaptured = true
            record.alphaCaptureDetail = nil
        else
            record.alphaCaptureDetail = detail
        end
    end

    if record.mouseCaptured ~= true and record.mouseOwned ~= true then
        local ok, value, detail = ReadNativeFrameMouseEnabled(frame)
        if ok then
            record.mouseEnabled = value
            record.mouseCaptured = true
            record.mouseCaptureDetail = nil
        else
            record.mouseCaptureDetail = detail
        end
    end
end

local function ApplyClassResourceSuppression(record)
    local frame = record and record.frame
    if not frame then return false, "frame unavailable" end

    record.releasing = nil
    CaptureClassResourceFrame(record)

    local failures = {}
    if record.alphaCaptured ~= true then
        AppendClassResourceFailure(
            failures,
            "alpha",
            record.alphaCaptureDetail or "original value is unreadable"
        )
    else
        local ok, detail = SetNativeFrameAlpha(frame, CLASS_RESOURCE_MANAGED_ALPHA)
        if ok then
            record.alphaOwned = true
        else
            AppendClassResourceFailure(failures, "alpha", detail)
        end
    end

    if record.mouseCaptured ~= true then
        AppendClassResourceFailure(
            failures,
            "mouse",
            record.mouseCaptureDetail or "original value is unreadable"
        )
    else
        local ok, detail = SetNativeFrameMouseEnabled(frame, CLASS_RESOURCE_MANAGED_MOUSE)
        if ok then
            record.mouseOwned = true
        else
            AppendClassResourceFailure(failures, "mouse", detail)
        end
    end

    if #failures > 0 then
        return false, table.concat(failures, "; ")
    end
    return true
end

local function ClassResourceRecordReleased(record)
    return type(record) ~= "table"
        or (record.alphaOwned ~= true and record.mouseOwned ~= true)
end

local function RestoreClassResourceRecord(record)
    local frame = record and record.frame
    if not frame then return false, "frame unavailable" end

    record.releasing = true
    local failures = {}

    if record.alphaOwned == true then
        local readable, current, detail = ReadNativeFrameAlpha(frame)
        if not readable then
            AppendClassResourceFailure(failures, "alpha restore", detail)
        elseif SameClassResourceAlpha(current, CLASS_RESOURCE_MANAGED_ALPHA) then
            local restored, restoreDetail = SetNativeFrameAlpha(frame, record.alpha)
            if restored then
                record.alphaOwned = nil
            else
                AppendClassResourceFailure(failures, "alpha restore", restoreDetail)
            end
        else
            -- A newer owner changed this property. Preserve the conflict and
            -- release only our ownership claim.
            record.alphaOwned = nil
        end
    end

    if record.mouseOwned == true then
        local readable, current, detail = ReadNativeFrameMouseEnabled(frame)
        if not readable then
            AppendClassResourceFailure(failures, "mouse restore", detail)
        elseif current == CLASS_RESOURCE_MANAGED_MOUSE then
            local restored, restoreDetail = SetNativeFrameMouseEnabled(frame, record.mouseEnabled)
            if restored then
                record.mouseOwned = nil
            else
                AppendClassResourceFailure(failures, "mouse restore", restoreDetail)
            end
        else
            -- Preserve a newer conflicting owner.
            record.mouseOwned = nil
        end
    end

    if #failures > 0 then
        return false, table.concat(failures, "; ")
    end
    return true
end

local function ReportClassResourceFailure(owner, detail)
    detail = tostring(detail or "unknown native class-resource failure")
    if owner._classResourceLastError == detail then return end
    owner._classResourceLastError = detail
    if Log and type(Log.Error) == "function" then
        Log:Error("CenterBars native class-resource ownership failed: " .. detail)
    end
end

local function ClearClassResourceFailure(owner)
    owner._classResourceLastError = nil
end

local function EnsureClassResourceShowHook(owner, name, frame)
    if not (owner and frame and type(frame.HookScript) == "function") then
        return false, ClassResourceFrameLabel(name, frame) .. ": OnShow HookScript unavailable"
    end

    local registry = GetClassResourceHookRegistry(owner)
    local hook = registry[frame]
    if type(hook) ~= "table" then
        hook = {}
        registry[frame] = hook
    end
    hook.owner = owner
    hook.name = name

    if type(hook.callback) ~= "function" then
        hook.callback = function(shownFrame)
            local currentHook = registry[shownFrame]
            if not currentHook
                or currentHook.OnShow ~= true
                or currentHook.owner ~= owner
                or owner._classResourceSuppressionActive ~= true then
                return
            end

            local records = owner._classResourceSuppression
            local current = type(records) == "table" and records[currentHook.name] or nil
            if not current or current.frame ~= shownFrame or current.releasing == true then
                return
            end

            local ok, detail = ApplyClassResourceSuppression(current)
            if ok == false then
                ReportClassResourceFailure(
                    owner,
                    ClassResourceFrameLabel(currentHook.name, shownFrame)
                        .. ": OnShow suppression failed: " .. tostring(detail)
                )
            end
        end
    end

    if hook.OnShow == true then return true end
    local ok, detail = pcall(frame.HookScript, frame, "OnShow", hook.callback)
    if not ok then
        return false, ClassResourceFrameLabel(name, frame)
            .. ": OnShow hook failed: " .. tostring(detail)
    end
    hook.OnShow = true
    return true
end

local function SuppressClassResourceFrame(owner, name, frame)
    if type(owner) ~= "table" or type(name) ~= "string" or name == "" or not frame then
        return false, "invalid class-resource suppression target"
    end

    local registry = GetClassResourceRegistry(owner)
    local record = registry[name]
    if record and record.frame ~= frame then
        local restored, restoreDetail = RestoreClassResourceRecord(record)
        if restored == false then
            return false, ClassResourceFrameLabel(name, record.frame)
                .. ": previous frame restore failed: " .. tostring(restoreDetail)
        end
        if not ClassResourceRecordReleased(record) then
            return false, ClassResourceFrameLabel(name, record.frame)
                .. ": previous frame ownership remains unresolved"
        end
        registry[name] = nil
        record = nil
    end

    if not record then
        record = {
            name = name,
            frame = frame,
        }
        registry[name] = record
    else
        record.name = name
        record.releasing = nil
    end

    local failures = {}
    local hooked, hookDetail = EnsureClassResourceShowHook(owner, name, frame)
    if hooked == false then
        failures[#failures + 1] = tostring(hookDetail)
    end

    local suppressed, suppressDetail = ApplyClassResourceSuppression(record)
    if suppressed == false then
        failures[#failures + 1] = ClassResourceFrameLabel(name, frame)
            .. ": " .. tostring(suppressDetail)
    end

    if #failures > 0 then
        return false, table.concat(failures, "; ")
    end
    return true
end

function Render.RestoreDefaultClassResources(owner)
    if type(owner) ~= "table" then
        return false, "CenterBars class-resource owner unavailable"
    end

    owner._pendingClassResourceSync = nil
    owner._classResourceSuppressionActive = false

    local registry = owner._classResourceSuppression
    if type(registry) ~= "table" then
        ClearClassResourceFailure(owner)
        return true
    end

    local failures = {}
    for name, record in pairs(registry) do
        local restored, detail = RestoreClassResourceRecord(record)
        if restored == false then
            AppendClassResourceFailure(
                failures,
                ClassResourceFrameLabel(name, record and record.frame),
                detail
            )
        elseif ClassResourceRecordReleased(record) then
            registry[name] = nil
        end
    end

    if next(registry) == nil then
        owner._classResourceSuppression = nil
    end
    if #failures > 0 then
        local detail = table.concat(failures, "; ")
        ReportClassResourceFailure(owner, detail)
        return false, detail
    end

    ClearClassResourceFailure(owner)
    return true
end

function Render.SyncDefaultClassResources(owner)
    if type(owner) ~= "table" then
        return false, "CenterBars class-resource owner unavailable"
    end

    local center = GetCenterCfg()
    local hideNames = owner._hideFrames
    local shouldHide = center.hideBlizzardClassResources ~= false
        and type(hideNames) == "table"
        and #hideNames > 0

    if _G.InCombatLockdown and InCombatLockdown() then
        owner._pendingClassResourceSync = true
        return true, "CenterBars class-resource sync deferred in combat"
    end

    owner._pendingClassResourceSync = nil
    if not shouldHide then
        return Render.RestoreDefaultClassResources(owner)
    end

    owner._classResourceSuppressionActive = true
    local registry = GetClassResourceRegistry(owner)
    local activeNames = {}
    local failures = {}

    for i = 1, #hideNames do
        local name = hideNames[i]
        if type(name) == "string" and name ~= "" then
            activeNames[name] = true
            local frame = _G[name]
            if frame then
                local suppressed, detail = SuppressClassResourceFrame(owner, name, frame)
                if suppressed == false then
                    AppendClassResourceFailure(failures, name, detail)
                end
            elseif registry[name] then
                local record = registry[name]
                local restored, detail = RestoreClassResourceRecord(record)
                if restored == false then
                    AppendClassResourceFailure(failures, name, detail)
                elseif ClassResourceRecordReleased(record) then
                    registry[name] = nil
                end
            end
        end
    end

    for name, record in pairs(registry) do
        if not activeNames[name] then
            local restored, detail = RestoreClassResourceRecord(record)
            if restored == false then
                AppendClassResourceFailure(failures, name, detail)
            elseif ClassResourceRecordReleased(record) then
                registry[name] = nil
            end
        end
    end

    if next(registry) == nil then
        owner._classResourceSuppression = nil
    end
    if #failures > 0 then
        return false, table.concat(failures, "; ")
    end
    return true
end

local function SyncAndReportClassResources(owner)
    local ok, detail = Render.SyncDefaultClassResources(owner)
    if ok == false then
        ReportClassResourceFailure(owner, detail)
        return false, detail
    end
    ClearClassResourceFailure(owner)
    return true, detail
end

'''
render = render[:start] + replacement + render[end:]

render = replace_once(
    render,
    '''function Render.HideDefaultClassResources(owner)
    return Render.SyncDefaultClassResources(owner)
end

function Render.OnCombatEnd(owner)
    if owner._pendingClassResourceSync then
        Render.SyncDefaultClassResources(owner)
    end
end
''',
    '''function Render.HideDefaultClassResources(owner)
    return SyncAndReportClassResources(owner)
end

function Render.OnCombatEnd(owner)
    if owner._pendingClassResourceSync then
        return SyncAndReportClassResources(owner)
    end
    return true
end
''',
    'CenterBars combat sync result',
)
render = replace_once(
    render,
    '''function Render.RefreshResourceMode(owner)
    if not owner.frame then return end
''',
    '''function Render.RefreshResourceMode(owner)
    if not owner.frame then
        return false, "CenterBars frame unavailable"
    end
''',
    'CenterBars resource owner guard',
)
render = replace_once(
    render,
    '''        owner.frame:SetSize(w, h2)
        Render.SyncDefaultClassResources(owner)
        return
    end
''',
    '''        owner.frame:SetSize(w, h2)
        return SyncAndReportClassResources(owner)
    end
''',
    'CenterBars no-resource sync result',
)
render = replace_once(
    render,
    '''    Render.SyncDefaultClassResources(owner)
end

function Render.OnUnitPower(owner, unit)
''',
    '''    return SyncAndReportClassResources(owner)
end

function Render.OnUnitPower(owner, unit)
''',
    'CenterBars active-resource sync result',
)
render_path.write_text(render, encoding='utf-8')


# ---------------------------------------------------------------------------
# CenterBarsRuntime: propagate journal failures and publish init after success.
# ---------------------------------------------------------------------------
runtime_path = Path('modules/CenterBarsRuntime.lua')
runtime = runtime_path.read_text(encoding='utf-8')
runtime = replace_once(
    runtime,
    '''local function Call(name, ...)
    local fn = Ctx()[name]
    if type(fn) == "function" then
        return fn(...)
    end
    return nil
end
''',
    '''local function Call(name, ...)
    local fn = Ctx()[name]
    if type(fn) == "function" then
        return fn(...)
    end
    return nil
end

local function CallResult(name, ...)
    local fn = Ctx()[name]
    if type(fn) ~= "function" then
        return false, "CenterBars " .. tostring(name) .. " helper unavailable"
    end

    local ok, result, detail = pcall(fn, ...)
    if not ok then
        return false, "CenterBars " .. tostring(name) .. " failed: " .. tostring(result)
    end
    if result == false then
        return false, tostring(detail or ("CenterBars " .. tostring(name) .. " failed"))
    end
    return true, detail
end
''',
    'CenterBars result call helper',
)

handler_start = runtime.index('local CENTER_EVENT_HANDLERS = {')
handler_end = runtime.index('local function EnsureEvents(owner)', handler_start)
handlers = r'''local function RefreshResourceOwner(owner)
    local refreshed, refreshDetail = CallResult("RefreshResourceMode", owner)
    if refreshed == false then
        return false, refreshDetail
    end

    local updated, updateDetail = CallResult("UpdatePower", owner)
    if updated == false then
        return false, updateDetail
    end
    return true
end

local function ReportEventRefreshFailure(owner, event, detail)
    detail = tostring(detail or "unknown CenterBars event refresh failure")
    local key = tostring(event) .. ": " .. detail
    if owner._eventRefreshLastError == key then return end
    owner._eventRefreshLastError = key
    if Log and type(Log.Error) == "function" then
        Log:Error("CenterBars " .. tostring(event) .. " refresh failed: " .. detail)
    end
end

local function RefreshResourceOwnerForEvent(owner, event)
    local ok, detail = RefreshResourceOwner(owner)
    if ok == false then
        ReportEventRefreshFailure(owner, event, detail)
        return false
    end
    owner._eventRefreshLastError = nil
    return true
end

local CENTER_EVENT_HANDLERS = {
    PLAYER_ENTERING_WORLD = function(owner)
        RefreshResourceOwnerForEvent(owner, "PLAYER_ENTERING_WORLD")
    end,
    PLAYER_SPECIALIZATION_CHANGED = function(owner, unit)
        if unit ~= "player" then return end
        RefreshResourceOwnerForEvent(owner, "PLAYER_SPECIALIZATION_CHANGED")
    end,
    PLAYER_TALENT_UPDATE = function(owner)
        RefreshResourceOwnerForEvent(owner, "PLAYER_TALENT_UPDATE")
    end,
    UNIT_DISPLAYPOWER = function(owner, unit)
        if unit ~= "player" then return end
        local ok, detail = CallResult("UpdatePower", owner)
        if ok == false then ReportEventRefreshFailure(owner, "UNIT_DISPLAYPOWER", detail) end
    end,
    UNIT_POWER_UPDATE = function(owner, unit, powerType)
        Call("OnUnitPower", owner, unit, powerType)
    end,
    UNIT_POWER_FREQUENT = function(owner, unit, powerType)
        Call("OnUnitPower", owner, unit, powerType)
    end,
    UNIT_MAXPOWER = function(owner, unit, powerType)
        Call("OnUnitPower", owner, unit, powerType)
    end,
    RUNE_POWER_UPDATE = function(owner)
        Call("OnRuneEvent", owner)
    end,
    RUNE_TYPE_UPDATE = function(owner)
        Call("OnRuneEvent", owner)
    end,
}

'''
runtime = runtime[:handler_start] + handlers + runtime[handler_end:]

runtime = replace_once(
    runtime,
    '''function Runtime:Detach(owner)
    Call("StopRuneTicker", owner)
    Call("RestoreDefaultClassResources", owner)

    if owner.frame then
        owner.frame:Hide()
    end

    DetachEvents(owner)
    return true
end
''',
    '''function Runtime:Detach(owner)
    Call("StopRuneTicker", owner)
    local restored, restoreDetail = CallResult("RestoreDefaultClassResources", owner)

    if owner.frame then
        owner.frame:Hide()
    end

    DetachEvents(owner)
    if restored == false then
        return false, "CenterBars native restore failed: " .. tostring(restoreDetail)
    end
    return true
end
''',
    'CenterBars detach restore result',
)

runtime = replace_once(
    runtime,
    '''    owner._inited = true

    Call("RefreshResourceMode", owner)
    Call("UpdatePower", owner)

    Log:Info("CenterBars initialized.")
    return true
end
''',
    '''    local refreshed, refreshDetail = RefreshResourceOwner(owner)
    if refreshed == false then
        Call("StopRuneTicker", owner)
        local restored, restoreDetail = CallResult("RestoreDefaultClassResources", owner)
        f:Hide()
        if restored == false then
            refreshDetail = tostring(refreshDetail)
                .. "; rollback restore failed: " .. tostring(restoreDetail)
        end
        return false, "CenterBars initialization failed: " .. tostring(refreshDetail)
    end

    owner._inited = true
    Log:Info("CenterBars initialized.")
    return true
end
''',
    'CenterBars delayed init publication',
)

runtime = replace_once(
    runtime,
    '''    if center.enabled == false then
        Call("StopRuneTicker", owner)
        Call("RestoreDefaultClassResources", owner)
        DetachEvents(owner)
        if owner.frame then
            owner.frame:Hide()
        end
        return true
    end
''',
    '''    if center.enabled == false then
        Call("StopRuneTicker", owner)
        local restored, restoreDetail = CallResult("RestoreDefaultClassResources", owner)
        DetachEvents(owner)
        if owner.frame then
            owner.frame:Hide()
        end
        if restored == false then
            return false, "CenterBars native restore failed: " .. tostring(restoreDetail)
        end
        return true
    end
''',
    'CenterBars disabled restore result',
)

runtime = replace_once(
    runtime,
    '''    owner.frame:Show()
    Call("RefreshResourceMode", owner)
    Call("UpdatePower", owner)
    return true
end
''',
    '''    owner.frame:Show()
    local refreshed, refreshDetail = RefreshResourceOwner(owner)
    if refreshed == false then
        return false, "CenterBars resource refresh failed: " .. tostring(refreshDetail)
    end
    return true
end
''',
    'CenterBars apply refresh result',
)
runtime_path.write_text(runtime, encoding='utf-8')


# Central apply owns combat deferral; the feature does not self-commit a
# transaction before its native ownership work can run.
registry_path = Path('core/FeatureRegistry.lua')
registry = registry_path.read_text(encoding='utf-8')
registry = replace_once(
    registry,
    '    center = { feature = "center" },\n',
    '    center = { feature = "center", deferInCombat = true },\n',
    'CenterBars apply combat deferral',
)
registry_path.write_text(registry, encoding='utf-8')


# ---------------------------------------------------------------------------
# Static contracts, docs, release metadata.
# ---------------------------------------------------------------------------
check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
contracts = r'''    assertSourceIncludes('modules/CenterBarsRender.lua', 'SetAlpha did not retain the requested value');
    assertSourceIncludes('modules/CenterBarsRender.lua', 'EnableMouse did not retain the requested value');
    assertSourceIncludes('modules/CenterBarsRender.lua', 'record.alphaOwned = true');
    assertSourceIncludes('modules/CenterBarsRender.lua', 'record.mouseOwned = true');
    assertSourceIncludes('modules/CenterBarsRender.lua', 'previous frame restore failed');
    assertSourceIncludes('modules/CenterBarsRender.lua', 'owner._classResourceSuppression = nil');
    assertSourceIncludes('modules/CenterBarsRuntime.lua', 'CenterBars native restore failed');
    assertSourceIncludes('modules/CenterBarsRuntime.lua', 'CenterBars initialization failed');
    assertSourceIncludes('core/FeatureRegistry.lua', 'center = { feature = "center", deferInCombat = true }');

'''
check = replace_once(
    check,
    "    assertSourceIncludes('modules/CenterBarsRender.lua', 'ApplyClassResourceSuppression(record)');\n",
    "    assertSourceIncludes('modules/CenterBarsRender.lua', 'ApplyClassResourceSuppression(record)');\n" + contracts,
    'CenterBars journal static contracts',
)
check_path.write_text(check, encoding='utf-8')


toc_path = Path('FeelsGoodUI.toc')
toc = toc_path.read_text(encoding='utf-8')
toc = replace_once(toc, '## Version: 0.0.68', '## Version: 0.0.69', 'TOC version')
toc_path.write_text(toc, encoding='utf-8')

readme_path = Path('README.md')
readme = readme_path.read_text(encoding='utf-8')
readme = replace_once(readme, '- FeelsGoodUI `0.0.68`', '- FeelsGoodUI `0.0.69`', 'README version')
readme = replace_once(
    readme,
    'CenterBars follows the same narrow policy for Blizzard class-resource frames: owner-local snapshots and hooks replace foreign-frame markers, frame replacement restores the old instance before adopting the new one, and combat-deferred sync never guesses visibility or calls native setup.',
    'CenterBars follows the same verified property-journal policy for Blizzard class-resource frames: alpha and mouse channels are captured only when readable, every suppression and restore write is checked by readback, hook/write/restore failures propagate to Apply/Lifecycle, unresolved restores remain retryable, frame replacement cannot adopt a new instance until the old ownership record releases, and newer conflicting values are preserved. Combat-sensitive CenterBars apply is centrally deferred and never guesses visibility or calls native setup.',
    'README CenterBars journal policy',
)
readme_path.write_text(readme, encoding='utf-8')

agent_path = Path('AGENT_GUIDE.md')
agent = agent_path.read_text(encoding='utf-8')
agent = replace_once(
    agent,
    '- Center bars: `CenterBars.lua` delegates render/runtime and listens to player power/rune/world/spec events. `CenterBarsRender` owns reversible alpha/mouse suppression of Blizzard class-resource frames through owner-local records and permanent gated OnShow hooks; it never adds fields to foreign frames or calls their `Hide`/`Show`/`Setup`.',
    '- Center bars: `CenterBars.lua` delegates render/runtime and listens to player power/rune/world/spec events. `CenterBarsRender` owns a verified, retryable alpha/mouse property journal for Blizzard class-resource frames: capture and write-readback are per channel, unresolved restores stay owned for retry, replacement waits for old-owner release, permanent OnShow hooks resolve the current record, and exact failures reach Apply/Lifecycle. It never adds fields to foreign frames or calls their `Hide`/`Show`/`Setup`.',
    'AGENT_GUIDE CenterBars journal',
)
agent_path.write_text(agent, encoding='utf-8')

index_path = Path('CODE_INDEX.md')
index = index_path.read_text(encoding='utf-8')
index = replace_once(
    index,
    '| `modules/CenterBars*.lua` | Center-resource rendering/runtime plus reversible, conflict-aware Blizzard class-resource alpha/mouse ownership. |',
    '| `modules/CenterBars*.lua` | Center-resource rendering/runtime plus verified, retryable and conflict-aware Blizzard class-resource alpha/mouse property ownership. |',
    'CODE_INDEX CenterBars journal',
)
index_path.write_text(index, encoding='utf-8')

todo_path = Path('todo.md')
todo = todo_path.read_text(encoding='utf-8')
todo = replace_once(todo, '- [x] Target Interface `120105` and release `0.0.68`.', '- [x] Target Interface `120105` and release `0.0.69`.', 'TODO version')
todo = replace_once(
    todo,
    '- [x] Make CenterBars class-resource takeover narrow and reversible: keep snapshots/hooks on the owner, never stamp or Hide/Show/Setup foreign frames, handle native frame replacement, and preserve newer conflicting alpha/mouse changes on release.',
    '- [x] Make CenterBars class-resource takeover a verified property journal: capture readable alpha/mouse independently, verify every suppression/restore write, retain unresolved restore records, block frame replacement until old ownership releases, centrally defer combat-sensitive apply, propagate exact failure, and preserve newer conflicts without foreign Hide/Show/Setup calls.',
    'TODO CenterBars journal status',
)
todo = replace_once(
    todo,
    '- [ ] Across DK/Rogue/Druid/Paladin/Monk/Warlock/Mage/Evoker, give native class-resource frames distinctive alpha/mouse/visibility states, trigger OnShow, replace a named frame, toggle suppression in combat, and verify zero addon Hide/Show/Setup calls, exact owned-property restore, and preservation of newer conflicting changes.',
    '- [ ] Across DK/Rogue/Druid/Paladin/Monk/Warlock/Mage/Evoker, give native class-resource frames distinctive alpha/mouse/visibility states; inject unreadable channels, stubborn setters, HookScript failure, restore failure, OnShow, named-frame replacement and combat toggle; verify exact failure reaches Apply/Lifecycle, unresolved restore retries, zero addon Hide/Show/Setup calls, exact still-owned restore, and preservation of newer conflicts.',
    'TODO CenterBars runtime validation',
)
todo_path.write_text(todo, encoding='utf-8')

matrix_path = Path('docs/REGRESSION_MATRIX_1_25.md')
matrix = matrix_path.read_text(encoding='utf-8')
matrix = replace_once(
    matrix,
    '| 18a | Native class-resource takeover across supported classes, including OnShow, frame replacement, combat-deferred toggle, and conflicting external changes | No addon `Hide`/`Show`/`Setup` or foreign markers; owner-local alpha/mouse suppression restores exact still-owned values and preserves newer conflicts |  |  |',
    '| 18a | Native class-resource takeover across supported classes with unreadable alpha/mouse, stubborn setters, HookScript/restore failure, OnShow, frame replacement, combat-deferred toggle, and conflicts | Only readable channels mutate; every write is read back; exact failures reach Apply/Lifecycle; unresolved restores retry; replacement waits for old-owner release; no addon `Hide`/`Show`/`Setup` or foreign markers; exact still-owned values restore and newer conflicts survive |  |  |',
    'regression matrix CenterBars journal',
)
matrix_path.write_text(matrix, encoding='utf-8')

print('Hardened CenterBars native class-resource ownership and failure propagation.')
