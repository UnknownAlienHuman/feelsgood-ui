local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
    end
end

local function countKeys(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do count = count + 1 end
    return count
end

local profile = {}
local defaults = {
    profile = {
        format = {
            shortNumbers = {
                enabled = true,
                suffixCase = 'upper',
                decimalsSmall = 2,
                decimalsLarge = 1,
            },
        },
        style = { iconInset = 0.1, borderSize = 2 },
        unitframes = {
            text = { font = 'DefaultFont' },
            sizes = {
                player = { width = 200, height = 24 },
                target = { width = 180, height = 22 },
            },
            scales = { player = 0.9, target = 1.1 },
        },
    },
}

local ns = {
    DB = {
        defaults = defaults,
        GetProfile = function() return profile end,
    },
    Theme = {
        GetFontToken = function() return 'ThemeFont' end,
        GetStatusbarToken = function() return 'ThemeStatusbar' end,
    },
}

assert(loadfile('modules/UnitFramesPolicy.lua'))('FeelsGoodUI', ns)
local Policy = assert(ns.UnitFramesPolicy)

assertEqual(Policy.NormalizeUFSizeTables, nil, 'runtime size normalizer removed')
assertEqual(Policy.NormalizeUFScaleTables, nil, 'runtime scale normalizer removed')
assertEqual(countKeys(profile), 0, 'load does not create profile sections')

local format = Policy.GetFormatCfg()
local style = Policy.GetStyleCfg()
local unitframes = Policy.GetUnitFramesCfg()
assertEqual(countKeys(format), 0, 'missing format uses empty read-only fallback')
assertEqual(countKeys(style), 0, 'missing style uses empty read-only fallback')
assertEqual(countKeys(unitframes), 0, 'missing unitframes uses empty read-only fallback')
assertEqual(countKeys(profile), 0, 'getters do not create sections')

Policy.RefreshCache(profile)
assertEqual(countKeys(profile), 0, 'cache refresh does not mutate detached profile')
assertEqual(Policy.Cache.font, 'ThemeFont', 'cache uses theme fallback')
assertEqual(Policy.Cache.iconInset, 0.08, 'cache uses local style fallback')
assertEqual(Policy.Cache.borderSize, 1, 'cache uses local border fallback')
assertEqual(Policy.Cache.combatHz, 5, 'cache uses local combat fallback')

local defUF = defaults.profile.unitframes
local width, height = Policy.GetUnitFrameSize(unitframes, defUF, 'player')
assertEqual(width, 200, 'player width default')
assertEqual(height, 24, 'player height default')
assertEqual(Policy.GetUnitFrameScale(unitframes, defUF, 'target'), 1.1, 'target scale default')
assertEqual(countKeys(profile), 0, 'fallback reads remain pure')

profile.unitframes = {
    sizes = { player = { width = 240 } },
    scales = { player = 1.2 },
}
local liveUF = Policy.GetUnitFramesCfg()
width, height = Policy.GetUnitFrameSize(liveUF, defUF, 'player')
assertEqual(width, 240, 'persisted width read')
assertEqual(height, 24, 'missing height resolves without write')
assertEqual(liveUF.sizes.player.height, nil, 'missing height not repaired at runtime')
assertEqual(Policy.GetUnitFrameScale(liveUF, defUF, 'target'), 1.1, 'missing target scale resolves without write')
assertEqual(liveUF.scales.target, nil, 'missing scale not repaired at runtime')

local spec = Policy.CreateUnitMoverSpec('player', 'Player')
local scaleWrite = spec.buildScaleWrites(1.7)
assertEqual(scaleWrite.value, 1.3, 'mover scale write clamps')
assertEqual(profile.unitframes.scales.player, 1.2, 'mover builder does not mutate scale')
local sizeWrites = spec.buildSizeWrites(999, 1)
assertEqual(sizeWrites[1].value, 520, 'mover width clamps')
assertEqual(sizeWrites[2].value, 14, 'mover height clamps')
assertEqual(profile.unitframes.sizes.player.width, 240, 'mover builder does not mutate width')
assertEqual(profile.unitframes.sizes.player.height, nil, 'mover builder does not create height')

local detached = {}
Policy.RefreshCache(detached)
assertEqual(countKeys(detached), 0, 'detached refresh remains pure after live reads')

print('UnitFrames runtime configuration purity tests passed.')
