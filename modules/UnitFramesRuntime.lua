-- FeelsGoodUI: UnitFrames owner/runtime and config apply helpers

local _, ns = ...

local Runtime = {}
ns.UnitFramesRuntime = Runtime

local Log = ns.Log
local DB = ns.DB
local Media = ns.Media
local Movers = ns.Movers
local Target = ns.UnitFramesTarget

local InCombat = InCombatLockdown or function() return false end
local EMPTY = {}

Runtime._ctx = Runtime._ctx or EMPTY

function Runtime:Configure(context)
    if type(context) == "table" then
        self._ctx = context
    else
        self._ctx = EMPTY
    end
end

local function Ctx()
    return Runtime._ctx or EMPTY
end

local function Call(name, ...)
    local fn = Ctx()[name]
    if type(fn) == "function" then
        return fn(...)
    end
    return nil
end

local function GetUnitFramesCfg()
    local value = Call("GetUnitFramesCfg")
    if type(value) == "table" then
        return value
    end
    return {}
end

local function GetSharedFontToken()
    return Call("GetSharedFontToken") or "Fonts\\FRIZQT__.TTF"
end

local function GetSharedStatusbarToken()
    return Call("GetSharedStatusbarToken") or "Interface/Buttons/WHITE8x8"
end

local function SetUnitWatch(frame, enabled)
    if not frame then
        return
    end

    if enabled then
        if not frame._fguiUnitWatch then
            if _G.RegisterUnitWatch then
                pcall(_G.RegisterUnitWatch, frame)
            end
            frame._fguiUnitWatch = true
        end
    else
        if frame._fguiUnitWatch then
            if _G.UnregisterUnitWatch then
                pcall(_G.UnregisterUnitWatch, frame)
            end
            frame._fguiUnitWatch = false
        end
        frame:Hide()
    end
end

local function ApplyToFrame(frame, unit, unitframesCfg, defaults, font, textCfg, statusbar, castbarHeight)
    if not frame then
        return
    end

    local width, height = Call("GetUnitFrameSize", unitframesCfg, defaults, unit)
    local scale = Call("GetUnitFrameScale", unitframesCfg, defaults, unit)
    if type(width) ~= "number" or type(height) ~= "number" then
        return
    end
    if type(scale) ~= "number" then
        scale = 1
    end
    frame:SetScale(scale)
    frame:SetSize(width, height)

    if frame.Health then
        frame.Health:SetStatusBarTexture(statusbar)
    end

    if frame.HealthValueText then
        Media:ApplyFont(frame.HealthValueText, font, textCfg.size or 12, textCfg.outline or "OUTLINE")
        frame.HealthValueText:SetWidth(math.max(32, math.floor(width * 0.48)))
    end
    if frame.HealthPercentText then
        Media:ApplyFont(frame.HealthPercentText, font, textCfg.size or 12, textCfg.outline or "OUTLINE")
        frame.HealthPercentText:SetWidth(math.max(34, math.floor(width * 0.30)))
    end

    if frame.Castbar then
        frame.Castbar:SetStatusBarTexture(statusbar)
        frame.Castbar:SetHeight(castbarHeight)
        if frame.Castbar.Text then
            Media:ApplyFont(frame.Castbar.Text, font, textCfg.size or 12, textCfg.outline or "OUTLINE")
        end
        if frame.Castbar.Time then
            Media:ApplyFont(frame.Castbar.Time, font, textCfg.size or 12, textCfg.outline or "OUTLINE")
        end
    end

    Call("LayoutUnderFrame", frame)

    if frame.UpdateAllElements then
        frame:UpdateAllElements("FGUI_CFG")
    end
    Call("ForceUpdateHealthText", frame, unit)
end

function Runtime:Attach(owner)
    if not owner._inited then
        owner:Init()
    end
    if not owner._inited then
        return false
    end

    if owner._eventsAttached then
        return true
    end

    if Target and Target.AttachOwner then
        Target.AttachOwner(owner)
    end

    owner._eventsAttached = true
    return true
end

function Runtime:Detach(owner)
    if Target and Target.DetachOwner then
        Target.DetachOwner(owner)
    end

    SetUnitWatch(owner.focus, false)
    SetUnitWatch(owner.targettarget, false)
    SetUnitWatch(owner.pet, false)

    if owner.player then
        owner.player:Hide()
    end
    if owner.target then
        owner.target:Hide()
    end
    if owner.player and owner.player.CombatTime then
        Call("StopCombatTimer", owner.player)
    end

    owner._configDirty = nil
    owner._auraModeDirty = nil
    owner._eventsAttached = false
    return true
end

function Runtime:Init(owner)
    local oUF = _G.oUF
    if not oUF then
        Log:Warn("oUF not detected; UnitFrames disabled.")
        return
    end

    local unitframesCfg = GetUnitFramesCfg()
    if unitframesCfg.enabled == false then
        Log:Info("UnitFrames disabled (DB).")
        return
    end

    if owner._inited then
        return
    end

    local style = Ctx().Style
    if type(style) ~= "function" then
        Log:Warn("UnitFrames style helper missing; runtime init aborted.")
        return
    end

    local createUnitMoverSpec = Ctx().CreateUnitMoverSpec
    if type(createUnitMoverSpec) ~= "function" then
        Log:Warn("UnitFrames mover-spec helper missing; runtime init aborted.")
        return
    end

    owner._inited = true

    oUF:RegisterStyle("FeelsGoodUI", style)
    oUF:SetActiveStyle("FeelsGoodUI")

    local player = oUF:Spawn("player", "FGUI_Player")
    local target = oUF:Spawn("target", "FGUI_Target")
    local focus = oUF:Spawn("focus", "FGUI_Focus")
    local targettarget = oUF:Spawn("targettarget", "FGUI_TargetTarget")
    local pet = oUF:Spawn("pet", "FGUI_Pet")

    Movers:Register("player", player, createUnitMoverSpec("player", "Player"))
    Movers:Register("target", target, createUnitMoverSpec("target", "Target"))
    Movers:Register("focus", focus, createUnitMoverSpec("focus", "Focus"))
    Movers:Register("targettarget", targettarget, createUnitMoverSpec("targettarget", "TargetTarget"))
    Movers:Register("pet", pet, createUnitMoverSpec("pet", "Pet"))

    Movers:Apply("player", player)
    Movers:Apply("target", target)
    Movers:Apply("focus", focus)
    Movers:Apply("targettarget", targettarget)
    Movers:Apply("pet", pet)
    Movers:ApplyUnlockFromDB()

    owner.player = player
    owner.target = target
    owner.focus = focus
    owner.targettarget = targettarget
    owner.pet = pet

    if focus then focus:Hide() end
    if targettarget then targettarget:Hide() end
    if pet then pet:Hide() end

    if InCombat() and player and player.CombatTime then
        Call("StartCombatTimer", player)
    end

    Log:Info("UnitFrames initialized (player/target/focus/targettarget/pet).")
end

function Runtime:ApplyConfig(owner)
    local unitframesCfg = GetUnitFramesCfg()

    owner:RefreshCache()

    if InCombat() then
        owner._configDirty = true
        return
    end

    if unitframesCfg.enabled == false then
        SetUnitWatch(owner.focus, false)
        SetUnitWatch(owner.targettarget, false)
        SetUnitWatch(owner.pet, false)

        if owner.player then
            owner.player:Hide()
        end
        if owner.target then
            owner.target:Hide()
        end
        if owner.player and owner.player.CombatTime then
            Call("StopCombatTimer", owner.player)
        end
        return
    end

    if not owner._inited then
        owner:Init()
    end

    if not owner.player or not owner.target then
        return
    end

    local defaults = (DB.defaults and DB.defaults.profile and DB.defaults.profile.unitframes) or {}
    Call("NormalizeUFSizeTables", unitframesCfg, defaults)
    Call("NormalizeUFScaleTables", unitframesCfg, defaults)

    local textCfg = unitframesCfg.text or {}
    local font = textCfg.font or GetSharedFontToken()
    local statusbar = Media:FetchStatusbar(GetSharedStatusbarToken())
    local castbarCfg = unitframesCfg.castbar or {}
    local castbarHeight = castbarCfg.height or 14

    ApplyToFrame(owner.player, "player", unitframesCfg, defaults, font, textCfg, statusbar, castbarHeight)
    ApplyToFrame(owner.target, "target", unitframesCfg, defaults, font, textCfg, statusbar, castbarHeight)

    local showFocus = not (unitframesCfg.showFocus == false)
    local showTargetTarget = not (unitframesCfg.showTargetTarget == false)
    local showPet = not (unitframesCfg.showPet == false)

    SetUnitWatch(owner.focus, showFocus)
    SetUnitWatch(owner.targettarget, showTargetTarget)
    SetUnitWatch(owner.pet, showPet)

    ApplyToFrame(owner.focus, "focus", unitframesCfg, defaults, font, textCfg, statusbar, castbarHeight)
    ApplyToFrame(owner.targettarget, "targettarget", unitframesCfg, defaults, font, textCfg, statusbar, castbarHeight)
    ApplyToFrame(owner.pet, "pet", unitframesCfg, defaults, font, textCfg, statusbar, castbarHeight)

    local targetInfo = type(unitframesCfg.targetInfo) == "table" and unitframesCfg.targetInfo or EMPTY
    if Target and Target.ApplyTargetHeaderStyle then
        Target.ApplyTargetHeaderStyle(owner.target, font, textCfg.size or 12, textCfg.outline or "OUTLINE", targetInfo)
    end

    if owner.player and owner.player.CombatTime then
        local combatTimer = type(unitframesCfg.combatTimer) == "table" and unitframesCfg.combatTimer or EMPTY
        if combatTimer.enabled == false then
            Call("StopCombatTimer", owner.player)
        else
            if InCombat() then
                Call("StartCombatTimer", owner.player)
            else
                Call("StopCombatTimer", owner.player)
            end
        end
    end

    local colors = type(unitframesCfg.colors) == "table" and unitframesCfg.colors or EMPTY
    local r, g, b, a = Call("ResolveRGBA", colors.playerHealth, 0.65, 0.00, 0.00, 1)
    if owner.player and owner.player.Health then
        Call("SetStatusBarColorSafe", owner.player.Health, r, g, b, a)
    end

    if Target and Target.ReconcileOwner then
        Target.ReconcileOwner(owner)
    end

    owner.player:Show()
    owner.target:Show()
end

return Runtime
