local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertContains(value, needle, label)
    if type(value) ~= "string" or not value:find(needle, 1, true) then
        error((label or "string") .. ": expected to contain " .. tostring(needle) .. ", got " .. tostring(value), 2)
    end
end

local function NewAuraElement(failEvent)
    local element = { hooks = {}, shown = false }
    function element:HookScript(name, fn)
        if name == failEvent then error("injected " .. name .. " hook failure") end
        self.hooks[name] = self.hooks[name] or {}
        self.hooks[name][#self.hooks[name] + 1] = fn
    end
    function element:IsShown() return self.shown end
    function element:Show() self.shown = true end
    function element:Hide() self.shown = false end
    function element:ClearAllPoints() end
    function element:SetPoint() end
    return element
end

local function NewObserver()
    local observer = { events = {}, unitEvents = {}, scripts = {} }
    function observer:UnregisterAllEvents()
        self.events = {}
        self.unitEvents = {}
    end
    function observer:RegisterEvent(event) self.events[event] = true end
    function observer:RegisterUnitEvent(event, unit) self.unitEvents[event] = unit end
    function observer:SetScript(name, fn) self.scripts[name] = fn end
    return observer
end

local function NewTargetFrame(buffs, debuffs)
    local header = {}
    function header:ClearAllPoints() end
    function header:SetPoint() end
    return {
        unit = "target",
        Buffs = buffs or NewAuraElement(),
        Debuffs = debuffs or NewAuraElement(),
        TargetHeader = header,
        Health = {},
        UpdateAllElements = function() end,
    }
end

_G = _G or {}
_G.CreateFrame = function() return NewObserver() end
_G.UnitExists = function() return false end
_G.UnitIsPlayer = function() return false end
_G.UnitReaction = function() return nil end
_G.UnitClass = function() return nil end
_G.UnitLevel = function() return nil end
_G.UnitClassification = function() return nil end
_G.RAID_CLASS_COLORS = {}
_G.FACTION_BAR_COLORS = {}

local nsTarget = {
    Media = { ApplyFont = function() end },
    Secret = { CanAccess = function() return true end },
    U = {
        TryNumber = function(value)
            local number = tonumber(value)
            return number ~= nil, number
        end,
        Round = function(value) return math.floor(value + 0.5) end,
    },
}
assert(loadfile('modules/UnitFramesTarget.lua'))('FeelsGoodUI', nsTarget)
local Target = assert(nsTarget.UnitFramesTarget)
local targetCfg = { targetAuras = { mode = 'MINI' } }
Target:Configure({
    Cache = { targetAuras = targetCfg.targetAuras, targetInfo = {}, healthColor = {} },
    EnsureCache = function() end,
    GetUnitFramesCfg = function() return targetCfg end,
    GetSharedFontToken = function() return 'font' end,
    IsTargetLikeUnit = function(unit)
        return unit == 'target' or unit == 'focus' or unit == 'targettarget'
    end,
    IsSecretValue = function() return false end,
    SafeSetText = function() end,
    ResolveRGBA = function(_, r, g, b, a) return r, g, b, a end,
    SetStatusBarColorSafe = function() end,
    AuraExtractSourceUnit = function() return 'player', {} end,
    AuraIsFromPlayerOrPet = function() return true end,
})

local first = NewTargetFrame()
local owner = { target = first }
local reconciled, detail = Target.ReconcileOwner(owner)
assertEqual(reconciled, true, detail)
local firstRecord = assert(Target._frameRegistry[first])
assertEqual(firstRecord.active, true, 'first frame active')
assertEqual(Target._ownerRegistry[owner].target, first, 'owner records first frame')
assertEqual(#first.Buffs.hooks.OnShow, 1, 'first header hook once')

local replacement = NewTargetFrame()
owner.target = replacement
reconciled, detail = Target.ReconcileOwner(owner)
assertEqual(reconciled, true, detail)
assertEqual(firstRecord.active, false, 'replacement deactivates old frame')
assertEqual(next(firstRecord.observer.events), nil, 'replacement clears old observer events')
assertEqual(Target._frameRegistry[replacement].active, true, 'replacement observer active')
assertEqual(Target._ownerRegistry[owner].target, replacement, 'owner adopts replacement')
assertEqual(#replacement.Buffs.hooks.OnShow, 1, 'replacement header hook once')
assertEqual(Target.ReconcileOwner(owner), true, 'repeat reconcile succeeds')
assertEqual(#replacement.Buffs.hooks.OnShow, 1, 'repeat reconcile adds no hook')

local bad = NewTargetFrame(NewAuraElement('OnShow'), NewAuraElement())
owner.target = bad
local badOK, badDetail = Target.ReconcileOwner(owner)
assertEqual(badOK, false, 'replacement hook failure propagates')
assertContains(badDetail, 'Target header OnShow hook failed', 'replacement hook detail')
assertEqual(Target._frameRegistry[bad].active, false, 'failed replacement not published active')

_G.InCombatLockdown = function() return false end
_G.RegisterUnitWatch = function() end
_G.UnregisterUnitWatch = function() end
local reconcileFailure = 'injected reconcile failure'
local nsRuntime = {
    Log = { Warn = function() end, Info = function() end },
    DB = { defaults = { profile = { unitframes = {} } } },
    Media = {
        FetchStatusbar = function(_, value) return value end,
        ApplyFont = function() end,
    },
    Movers = {},
    UnitFramesTarget = {
        AttachOwner = function() return true end,
        DetachOwner = function() return true end,
        ApplyTargetHeaderStyle = function() end,
        ReconcileOwner = function()
            if reconcileFailure then return false, reconcileFailure end
            return true
        end,
    },
}
assert(loadfile('modules/UnitFramesRuntime.lua'))('FeelsGoodUI', nsRuntime)
local Runtime = assert(nsRuntime.UnitFramesRuntime)
local cfg = {
    enabled = true,
    showFocus = false,
    showTargetTarget = false,
    showPet = false,
    text = {}, castbar = {}, colors = {},
}
Runtime:Configure({
    GetUnitFramesCfg = function() return cfg end,
    GetUnitFrameSize = function() return 100, 20 end,
    GetUnitFrameScale = function() return 1 end,
    GetSharedFontToken = function() return 'font' end,
    GetSharedStatusbarToken = function() return 'status' end,
    LayoutUnderFrame = function() end,
    ForceUpdateHealthText = function() end,
    ResolveRGBA = function(_, r, g, b, a) return r, g, b, a end,
    SetStatusBarColorSafe = function() end,
    StopCombatTimer = function() end,
})

local function NewUnitFrame()
    local frame = {}
    function frame:SetScale() end
    function frame:SetSize() end
    function frame:Show() end
    function frame:Hide() end
    function frame:UpdateAllElements() end
    frame.Health = { SetStatusBarTexture = function() end }
    return frame
end

local runtimeOwner = {
    _inited = true,
    _eventsAttached = true,
    RefreshCache = function() end,
    player = NewUnitFrame(),
    target = NewUnitFrame(),
    focus = NewUnitFrame(),
    targettarget = NewUnitFrame(),
    pet = NewUnitFrame(),
}
local applied, applyDetail = Runtime:ApplyConfig(runtimeOwner)
assertEqual(applied, false, 'runtime reconciliation failure propagates')
assertEqual(applyDetail, reconcileFailure, 'runtime reconciliation detail preserved')

reconcileFailure = nil
applied, applyDetail = Runtime:ApplyConfig(runtimeOwner)
assertEqual(applied, true, applyDetail)

print('UnitFrames reconciliation tests passed.')
