-- FeelsGoodUI: UnitFrames (oUF layout)
-- Player/target compact health frames + auras + combat timer + optional castbar.
--
-- Requirements:
--  - oUF is an external dependency (separate addon)
--  - no always-on OnUpdate (combat timer uses a small ticker only while in combat)
--  - Secret Value safety: never assume type(v)=="number" is safe for math

local _, ns = ...

local UF = {}
ns.UF = UF

local Text = ns.UnitFramesText
local Target = ns.UnitFramesTarget
local Render = ns.UnitFramesRender
local Policy = ns.UnitFramesPolicy
local Runtime = ns.UnitFramesRuntime

assert(Text, "FeelsGoodUI: UnitFramesText not loaded")
assert(Target, "FeelsGoodUI: UnitFramesTarget not loaded")
assert(Render, "FeelsGoodUI: UnitFramesRender not loaded")
assert(Policy, "FeelsGoodUI: UnitFramesPolicy not loaded")
assert(Runtime, "FeelsGoodUI: UnitFramesRuntime not loaded")

-- Cached profile fragments for hot paths (updated in ApplyConfig).
UF._cache = Policy.Cache
local Cache = UF._cache

function UF:RefreshCache(profile)
    return Policy.RefreshCache(profile)
end

local function EnsureCache()
    Policy.EnsureCache()
end

local InCombat = InCombatLockdown or function() return false end

Render:Configure({
    Cache = Cache,
    EnsureCache = EnsureCache,
    GetSharedFontToken = Policy.GetSharedFontToken,
    GetSharedStatusbarToken = Policy.GetSharedStatusbarToken,
    GetStyleCfg = Policy.GetStyleCfg,
    GetUnitFramesCfg = Policy.GetUnitFramesCfg,
    GetUnitFrameScale = Policy.GetUnitFrameScale,
    GetUnitFrameSize = Policy.GetUnitFrameSize,
    NormalizeUFScaleTables = Policy.NormalizeUFScaleTables,
    NormalizeUFSizeTables = Policy.NormalizeUFSizeTables,
})

Runtime:Configure({
    CreateUnitMoverSpec = Policy.CreateUnitMoverSpec,
    ForceUpdateHealthText = Render.ForceUpdateHealthText,
    GetSharedFontToken = Policy.GetSharedFontToken,
    GetSharedStatusbarToken = Policy.GetSharedStatusbarToken,
    GetUnitFramesCfg = Policy.GetUnitFramesCfg,
    GetUnitFrameScale = Policy.GetUnitFrameScale,
    GetUnitFrameSize = Policy.GetUnitFrameSize,
    LayoutUnderFrame = Render.LayoutUnderFrame,
    NormalizeUFScaleTables = Policy.NormalizeUFScaleTables,
    NormalizeUFSizeTables = Policy.NormalizeUFSizeTables,
    ResolveRGBA = Render.ResolveRGBA,
    SetStatusBarColorSafe = Render.SetStatusBarColorSafe,
    StartCombatTimer = Render.StartCombatTimer,
    StopCombatTimer = Render.StopCombatTimer,
    Style = Render.Style,
})

-- -----------------------------
-- Public API
-- -----------------------------

function UF:Attach()
    return Runtime:Attach(self)
end

function UF:Detach()
    return Runtime:Detach(self)
end

function UF:Init()
    return Runtime:Init(self)
end

function UF:OnCombatStart()
    local uf = Policy.GetUnitFramesCfg()
    if uf.combatTimer and uf.combatTimer.enabled == false then
        return
    end
    if self.player and self.player.CombatTime then
        Render.StartCombatTimer(self.player)
    end
end

function UF:FlushDeferredUpdates()
    if self._configDirty then
        self._configDirty = nil
        self._auraModeDirty = nil
        self:ApplyConfig()
        return true
    end

    if self._auraModeDirty then
        self._auraModeDirty = nil
        self:ApplyTargetAuraMode()
        return true
    end

    return false
end

function UF:OnCombatEnd()
    if self.player and self.player.CombatTime then
        Render.StopCombatTimer(self.player)
    end
end

function UF:ApplyTargetAuraMode()
    if InCombat() then
        self._auraModeDirty = true
        return
    end
    if Target and Target.ReconcileOwner then
        Target.ReconcileOwner(self)
    end
end

function UF:ApplyConfig()
    return Runtime:ApplyConfig(self)
end
