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
Runtime._unitWatchRegistry = Runtime._unitWatchRegistry or setmetatable({}, { __mode = "k" })
local UnitWatchRegistry = Runtime._unitWatchRegistry

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
        return true
    end

    local watched = UnitWatchRegistry[frame] == true
    if enabled then
        if watched then return true end
        if type(_G.RegisterUnitWatch) ~= "function" then
            return false, "RegisterUnitWatch is unavailable"
        end

        local ok, err = pcall(_G.RegisterUnitWatch, frame)
        if not ok then
            return false, "RegisterUnitWatch failed: " .. tostring(err)
        end
        UnitWatchRegistry[frame] = true
        return true
    end

    if watched then
        if type(_G.UnregisterUnitWatch) ~= "function" then
            return false, "UnregisterUnitWatch is unavailable"
        end

        local ok, err = pcall(_G.UnregisterUnitWatch, frame)
        if not ok then
            return false, "UnregisterUnitWatch failed: " .. tostring(err)
        end
        UnitWatchRegistry[frame] = nil
    end

    if type(frame.Hide) == "function" then
        frame:Hide()
    end
    return true
end

local function DisableOptionalUnitWatches(owner)
    local failures = {}
    local fields = { "focus", "targettarget", "pet" }
    for i = 1, #fields do
        local field = fields[i]
        local ok, detail = SetUnitWatch(owner and owner[field], false)
        if ok == false then
            failures[#failures + 1] = field .. ": " .. tostring(detail)
        end
    end

    if #failures > 0 then
        return false, table.concat(failures, "; ")
    end
    return true
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

local function AttachObservers(owner)
    if owner._eventsAttached then
        return true
    end
    if not owner._inited then
        return false, "UnitFrames observers require initialized frames"
    end

    if Target and Target.AttachOwner then
        local attached, detail = Target.AttachOwner(owner)
        if attached == false then
            return false, detail
        end
    end
    owner._eventsAttached = true
    return true
end

local function DetachObservers(owner)
    owner._eventsAttached = false
    if Target and Target.DetachOwner then
        return Target.DetachOwner(owner)
    end
    return true
end

function Runtime:Attach(owner)
    local cfg = GetUnitFramesCfg()
    if cfg.enabled == false then
        local detached, detail = DetachObservers(owner)
        if detached == false then return false, detail end
        return true
    end

    if not owner._inited then
        local initialized, detail = owner:Init()
        if initialized == false then
            return false, detail
        end
    end
    if not owner._inited then
        return false, "UnitFrames initialization incomplete"
    end

    return AttachObservers(owner)
end

function Runtime:Detach(owner)
    local observersDetached, observerDetail = DetachObservers(owner)
    local watchesDisabled, watchDetail = DisableOptionalUnitWatches(owner)

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
    local failures = {}
    if observersDetached == false then
        failures[#failures + 1] = "observers: " .. tostring(observerDetail)
    end
    if watchesDisabled == false then
        failures[#failures + 1] = "unit watches: " .. tostring(watchDetail)
    end
    if #failures > 0 then
        return false, table.concat(failures, "; ")
    end
    return true
end

function Runtime:Init(owner)
    if owner._inited then
        return true
    end

    local oUF = _G.oUF
    if not oUF then
        Log:Warn("oUF not detected; UnitFrames disabled.")
        return false, "oUF not detected"
    end

    local unitframesCfg = GetUnitFramesCfg()
    if unitframesCfg.enabled == false then
        Log:Info("UnitFrames disabled (DB).")
        return true
    end

    local style = Ctx().Style
    if type(style) ~= "function" then
        Log:Warn("UnitFrames style helper missing; runtime init aborted.")
        return false, "UnitFrames style helper missing"
    end

    local createUnitMoverSpec = Ctx().CreateUnitMoverSpec
    if type(createUnitMoverSpec) ~= "function" then
        Log:Warn("UnitFrames mover-spec helper missing; runtime init aborted.")
        return false, "UnitFrames mover-spec helper missing"
    end

    if not owner._styleRegistered then
        oUF:RegisterStyle("FeelsGoodUI", style)
        owner._styleRegistered = true
    end
    oUF:SetActiveStyle("FeelsGoodUI")

    local function SpawnOwned(field, unit, frameName)
        local frame = owner[field]
        if not frame then
            frame = oUF:Spawn(unit, frameName)
            if not frame then
                return nil, "oUF failed to spawn " .. tostring(unit)
            end
            owner[field] = frame
        end
        return frame
    end

    local player, spawnError = SpawnOwned("player", "player", "FGUI_Player")
    if not player then return false, spawnError end
    local target
    target, spawnError = SpawnOwned("target", "target", "FGUI_Target")
    if not target then return false, spawnError end
    local focus
    focus, spawnError = SpawnOwned("focus", "focus", "FGUI_Focus")
    if not focus then return false, spawnError end
    local targettarget
    targettarget, spawnError = SpawnOwned("targettarget", "targettarget", "FGUI_TargetTarget")
    if not targettarget then return false, spawnError end
    local pet
    pet, spawnError = SpawnOwned("pet", "pet", "FGUI_Pet")
    if not pet then return false, spawnError end

    if not (Movers and type(Movers.Register) == "function" and type(Movers.Apply) == "function") then
        return false, "UnitFrames mover registry unavailable"
    end

    local registrations = {
        { key = "player", frame = player, label = "Player" },
        { key = "target", frame = target, label = "Target" },
        { key = "focus", frame = focus, label = "Focus" },
        { key = "targettarget", frame = targettarget, label = "TargetTarget" },
        { key = "pet", frame = pet, label = "Pet" },
    }
    for i = 1, #registrations do
        local record = registrations[i]
        local registered, detail = Movers:Register(
            record.key,
            record.frame,
            createUnitMoverSpec(record.key, record.label)
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

    if focus then focus:Hide() end
    if targettarget then targettarget:Hide() end
    if pet then pet:Hide() end

    if InCombat() and player and player.CombatTime then
        Call("StartCombatTimer", player)
    end

    Log:Info("UnitFrames initialized (player/target/focus/targettarget/pet).")
    return true
end

function Runtime:ApplyConfig(owner)
    local unitframesCfg = GetUnitFramesCfg()

    owner:RefreshCache()

    if InCombat() then
        owner._configDirty = true
        return true, "UnitFrames apply deferred in combat"
    end

    if unitframesCfg.enabled == false then
        local observersDetached, observerDetail = DetachObservers(owner)
        local watchesDisabled, watchDetail = DisableOptionalUnitWatches(owner)

        if owner.player then
            owner.player:Hide()
        end
        if owner.target then
            owner.target:Hide()
        end
        if owner.player and owner.player.CombatTime then
            Call("StopCombatTimer", owner.player)
        end

        local failures = {}
        if observersDetached == false then
            failures[#failures + 1] = "observers: " .. tostring(observerDetail)
        end
        if watchesDisabled == false then
            failures[#failures + 1] = "unit watches: " .. tostring(watchDetail)
        end
        if #failures > 0 then
            return false, table.concat(failures, "; ")
        end
        return true
    end

    if not owner._inited then
        local initialized, detail = owner:Init()
        if initialized == false then
            return false, detail
        end
    end

    if not owner.player or not owner.target then
        return false, "UnitFrames player/target frames unavailable"
    end

    local attached, attachDetail = AttachObservers(owner)
    if attached == false then
        return false, attachDetail
    end

    local defaults = (DB.defaults and DB.defaults.profile and DB.defaults.profile.unitframes) or {}

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

    local focusWatched, focusDetail = SetUnitWatch(owner.focus, showFocus)
    if focusWatched == false then return false, "focus: " .. tostring(focusDetail) end
    local targetTargetWatched, targetTargetDetail = SetUnitWatch(owner.targettarget, showTargetTarget)
    if targetTargetWatched == false then return false, "targettarget: " .. tostring(targetTargetDetail) end
    local petWatched, petDetail = SetUnitWatch(owner.pet, showPet)
    if petWatched == false then return false, "pet: " .. tostring(petDetail) end

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
        elseif InCombat() then
            Call("StartCombatTimer", owner.player)
        else
            Call("StopCombatTimer", owner.player)
        end
    end

    local colors = type(unitframesCfg.colors) == "table" and unitframesCfg.colors or EMPTY
    local r, g, b, a = Call("ResolveRGBA", colors.playerHealth, 0.65, 0.00, 0.00, 1)
    if owner.player and owner.player.Health then
        Call("SetStatusBarColorSafe", owner.player.Health, r, g, b, a)
    end

    if Target and Target.ReconcileOwner then
        local reconciled, reconcileDetail = Target.ReconcileOwner(owner)
        if reconciled == false then
            return false, reconcileDetail
        end
    end

    owner.player:Show()
    owner.target:Show()
    return true
end

return Runtime
