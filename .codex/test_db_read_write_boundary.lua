local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
    end
end

local function DeepCopy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, item in pairs(value) do
        out[DeepCopy(key, seen)] = DeepCopy(item, seen)
    end
    return out
end

_G = _G or {}
_G.NUM_PET_ACTION_SLOTS = 10
_G.Enum = { PowerType = {} }
_G.UnitClass = function() return 'Player', 'WARRIOR' end

local ns = {
    U = { DeepCopy = DeepCopy },
    Log = {
        Info = function() end,
        Warn = function() end,
        Debug = function() end,
    },
    Schema = { CURRENT_VERSION = 1 },
}
assert(loadfile('core/DB.lua'))('FeelsGoodUI', ns)
local DB = assert(ns.DB)
DB.data = {
    profile = {
        present = { value = 1 },
        actionbars = { hideBlizzard = false },
    },
}
DB.defaults.profile.missing = { copied = true }

local present = DB:ReadSection('present')
assertEqual(present.value, 1, 'pure reader returns live section')
assertEqual(DB:ReadSection('missing'), nil, 'pure reader missing result')
assertEqual(DB.data.profile.missing, nil, 'pure reader does not create section')
assertEqual(DB:GetSection('missing'), nil, 'compatibility reader remains pure')
assertEqual(DB.data.profile.missing, nil, 'compatibility reader does not create section')

local ensured = DB:EnsureSection('missing')
assertEqual(type(ensured), 'table', 'explicit ensure creates table')
assertEqual(ensured.copied, true, 'explicit ensure copies defaults')
assertEqual(ensured == DB.defaults.profile.missing, false, 'explicit ensure deep copies defaults')

DB.data.profile.actionbars = nil
assertEqual(DB:ShouldHideBlizzardActionBars(), true, 'missing actionbars uses policy fallback')
assertEqual(DB.data.profile.actionbars, nil, 'policy read does not repair actionbars')
DB.data.profile.actionbars = { hideBlizzard = false }
assertEqual(DB:ShouldHideBlizzardActionBars(), false, 'persisted actionbar policy read')

-- Companion reads through ReadSection and falls back without creating data.
DB.data.profile.companion = nil
ns.CompanionShared = nil
assert(loadfile('modules/CompanionShared.lua'))('FeelsGoodUI', ns)
local companion = ns.CompanionShared:GetCompanionCfg(nil)
assertEqual(companion.buttonSize, 32, 'companion local fallback')
assertEqual(DB.data.profile.companion, nil, 'companion read does not create section')

-- CenterBars exposes its readers through Configure; all must remain pure.
DB.data.profile.center = nil
DB.data.profile.format = nil
DB.data.profile.style = nil
local runtimeContext
local renderContext
ns.CenterBarsRuntime = {
    Configure = function(_, ctx) runtimeContext = ctx end,
    Attach = function() return true end,
    Detach = function() return true end,
    Init = function() return true end,
    ApplyConfig = function() return true end,
}
ns.CenterBarsRender = {
    Configure = function(_, ctx) renderContext = ctx end,
    RefreshThresholdConfig = function() return true end,
    IsThresholdActive = function() return false end,
    EnsureResourceLayout = function() return true end,
    StartRuneTicker = function() return true end,
    StopRuneTicker = function() return true end,
    UpdatePower = function() return true end,
    UpdatePointResource = function() return true end,
    UpdateComboPoints = function() return true end,
    UpdateRunes = function() return true end,
    HideDefaultClassResources = function() return true end,
    OnCombatEnd = function() return true end,
    RefreshResourceMode = function() return true end,
    OnUnitPower = function() return true end,
    OnRuneEvent = function() return true end,
}
ns.Theme = {
    GetFontToken = function() return 'font' end,
    GetFontOutline = function() return 'OUTLINE' end,
    GetFontSize = function() return 12 end,
    GetStatusbarToken = function() return 'status' end,
}
assert(loadfile('modules/CenterBars.lua'))('FeelsGoodUI', ns)
assertEqual(type(runtimeContext), 'table', 'center runtime context')
assertEqual(type(renderContext), 'table', 'center render context')
assertEqual(type(runtimeContext.GetCenterCfg()), 'table', 'center missing fallback')
assertEqual(type(renderContext.GetFormatCfg()), 'table', 'format missing fallback')
assertEqual(type(renderContext.GetStyleCfg()), 'table', 'style missing fallback')
assertEqual(DB.data.profile.center, nil, 'center read does not create section')
assertEqual(DB.data.profile.format, nil, 'format read does not create section')
assertEqual(DB.data.profile.style, nil, 'style read does not create section')

-- ActionBars EditMode reads missing config but its pure builder does not create it.
DB.data.profile.actionbars = nil
local registeredSpec
ns.Movers = {
    Register = function(_, _, _, spec) registeredSpec = spec end,
    Apply = function() return true end,
}
assert(loadfile('modules/ActionBarsEditMode.lua'))('FeelsGoodUI', ns)
ns.ActionBarsEditMode.RegisterHolder({}, 1)
assertEqual(type(registeredSpec), 'table', 'actionbar mover registered')
local width, height = registeredSpec.getSize()
assertEqual(width, 32, 'actionbar missing-config width fallback')
assertEqual(height, 32, 'actionbar missing-config height fallback')
assertEqual(DB.data.profile.actionbars, nil, 'actionbar read does not create section')

print('DB section read/write ownership tests passed.')
