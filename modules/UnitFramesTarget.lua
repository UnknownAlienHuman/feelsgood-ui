-- FeelsGoodUI: UnitFrames target header, info and aura helpers

local _, ns = ...

local Target = {}
ns.UnitFramesTarget = Target

local Media = ns.Media
local Secret = ns.Secret
local U = ns.U

local EMPTY = {}

Target._ctx = Target._ctx or EMPTY

function Target:Configure(context)
    if type(context) == "table" then
        self._ctx = context
    else
        self._ctx = EMPTY
    end
end

local function Ctx()
    return Target._ctx or EMPTY
end

local function EnsureCache()
    local fn = Ctx().EnsureCache
    if type(fn) == "function" then
        fn()
    end
end

local function GetCache()
    local cache = Ctx().Cache
    if type(cache) == "table" then
        return cache
    end
    return EMPTY
end

local function GetUnitFramesCfg()
    local fn = Ctx().GetUnitFramesCfg
    if type(fn) == "function" then
        local value = fn()
        if type(value) == "table" then
            return value
        end
    end
    return EMPTY
end

local function GetSharedFontToken()
    local fn = Ctx().GetSharedFontToken
    if type(fn) == "function" then
        return fn()
    end
    return "Fonts\\FRIZQT__.TTF"
end

local function IsTargetLikeUnit(unit)
    local fn = Ctx().IsTargetLikeUnit
    if type(fn) == "function" then
        return fn(unit) == true
    end
    return false
end

local function SafeSetText(fs, v)
    local fn = Ctx().SafeSetText
    if type(fn) == "function" then
        return fn(fs, v)
    end
    if fs then
        fs:SetText(v or "")
    end
end

local function IsSecretValue(v)
    local fn = Ctx().IsSecretValue
    if type(fn) == "function" then
        return fn(v) == true
    end
    return false
end

local function ResolveRGBA(tbl, fallbackR, fallbackG, fallbackB, fallbackA)
    local fn = Ctx().ResolveRGBA
    if type(fn) == "function" then
        return fn(tbl, fallbackR, fallbackG, fallbackB, fallbackA)
    end
    return fallbackR, fallbackG, fallbackB, fallbackA or 1
end

local function SetStatusBarColorSafe(bar, r, g, b, a)
    local fn = Ctx().SetStatusBarColorSafe
    if type(fn) == "function" then
        fn(bar, r, g, b, a)
    end
end

local function AuraExtractSourceUnit(...)
    local fn = Ctx().AuraExtractSourceUnit
    if type(fn) == "function" then
        return fn(...)
    end
    return nil, nil
end

local function AuraIsFromPlayerOrPet(sourceUnit, auraData, ...)
    local fn = Ctx().AuraIsFromPlayerOrPet
    if type(fn) == "function" then
        return fn(sourceUnit, auraData, ...)
    end
    return nil
end

local function NormalizeTargetHeaderAnchor(anchor)
    if anchor == "AURAS" then return "AURAS" end
    return "FRAME"
end

local function NormalizeTargetHeaderWeight(weight)
    if weight == "bold" then return "bold" end
    return "regular"
end

local function NormalizeTargetHeaderColorMode(mode)
    if mode == "custom" then return "custom" end
    return "inherit"
end

function Target.ResolveTargetInfoFontFlags(outline, weight)
    local flags = (type(outline) == "string") and outline or "OUTLINE"
    if flags == "NONE" then
        flags = ""
    end
    if NormalizeTargetHeaderWeight(weight) ~= "bold" then
        return flags
    end
    if flags == "" or flags == "OUTLINE" then
        return "THICKOUTLINE"
    end
    return flags
end

local function GetTargetHeaderColorConfig()
    EnsureCache()
    local cache = GetCache()
    local ti = (type(cache.targetInfo) == "table") and cache.targetInfo or EMPTY
    local mode = NormalizeTargetHeaderColorMode(ti.colorMode)
    local custom = (type(ti.color) == "table") and ti.color or nil
    return mode, custom
end

local function ResolveTargetHeaderTextColor(frame)
    local mode, custom = GetTargetHeaderColorConfig()
    if mode == "custom" then
        return ResolveRGBA(custom, 1, 1, 1, 1)
    end

    local health = frame and frame.Health
    if health and health.GetStatusBarColor then
        local ok, r, g, b, a = pcall(health.GetStatusBarColor, health)
        if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
            return r, g, b, (type(a) == "number" and a or 1)
        end
    end

    return 1, 1, 1, 1
end

function Target.ApplyTargetHeaderTextColor(frame)
    if not frame then return end
    if not (frame.TargetNameText or frame.TargetInfoText) then return end

    local r, g, b, a = ResolveTargetHeaderTextColor(frame)
    if frame.TargetNameText then
        frame.TargetNameText:SetTextColor(r, g, b, a)
    end
    if frame.TargetInfoText then
        frame.TargetInfoText:SetTextColor(r, g, b, a)
    end
end

local function GetTargetHeaderAnchorFrame(frame)
    if not frame then return nil end

    EnsureCache()
    local cache = GetCache()
    local ti = (type(cache.targetInfo) == "table") and cache.targetInfo or EMPTY
    local anchorMode = NormalizeTargetHeaderAnchor(ti.nameAnchor)
    if anchorMode ~= "AURAS" then
        return frame
    end

    if frame.Buffs and frame.Buffs:IsShown() then
        return frame.Buffs
    end
    if frame.Debuffs and frame.Debuffs:IsShown() then
        return frame.Debuffs
    end
    if frame.Buffs then
        return frame.Buffs
    end
    if frame.Debuffs then
        return frame.Debuffs
    end

    return frame
end

function Target.LayoutTargetHeader(frame)
    if not frame or not frame.TargetHeader then return end

    local anchor = GetTargetHeaderAnchorFrame(frame) or frame
    frame.TargetHeader:ClearAllPoints()
    frame.TargetHeader:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 6)
    frame.TargetHeader:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, 6)
end

function Target.UpdateUnitHealthColor(frame, unit)
    if not frame or not frame.Health then return end

    unit = unit or frame.unit
    if not unit then return end

    EnsureCache()
    local cache = GetCache()
    local cfg = cache.healthColor or EMPTY

    local isPlayer = UnitIsPlayer(unit)
    if (not IsSecretValue(isPlayer)) and isPlayer and cfg.useClassColorForEnemyPlayers ~= false then
        local _, class = UnitClass(unit)
        if class and (not IsSecretValue(class)) and _G.RAID_CLASS_COLORS then
            local color = _G.RAID_CLASS_COLORS[class]
            if color then
                SetStatusBarColorSafe(frame.Health, color.r, color.g, color.b, 1)
                Target.ApplyTargetHeaderTextColor(frame)
                return
            end
        end
    end

    if cfg.useReactionColorForNPC ~= false then
        local reaction = UnitReaction(unit, "player")
        if (not IsSecretValue(reaction)) and reaction and _G.FACTION_BAR_COLORS and _G.FACTION_BAR_COLORS[reaction] then
            local color = _G.FACTION_BAR_COLORS[reaction]
            SetStatusBarColorSafe(frame.Health, color.r, color.g, color.b, 1)
            Target.ApplyTargetHeaderTextColor(frame)
            return
        end
    end

    local r = cfg.fallbackR or 0.12
    local g = cfg.fallbackG or 0.12
    local b = cfg.fallbackB or 0.12
    local a = cfg.fallbackA or 1
    SetStatusBarColorSafe(frame.Health, r, g, b, a)
    Target.ApplyTargetHeaderTextColor(frame)
end

function Target.UpdateTargetHealthColor(frame)
    if not frame or frame.unit ~= "target" or not frame.Health then return end
    Target.UpdateUnitHealthColor(frame, "target")
end

function Target.NormalizeTargetAuraMode(mode)
    if mode == "PLAYER_DEBUFFS_TOP" then return "MINI" end
    if mode == "classic" or mode == "CLASSIC" then return "CLASSIC" end
    if mode == "mini" then return "MINI" end
    return "MINI"
end

local function AuraCustomFilter(element, unit, ...)
    if not IsTargetLikeUnit(unit) then
        return true
    end

    EnsureCache()
    local cache = GetCache()
    local targetAuras = type(cache.targetAuras) == "table" and cache.targetAuras or EMPTY
    local mode = Target.NormalizeTargetAuraMode(targetAuras.mode)

    if element and element.__fgui_isTargetBuffs then
        return mode == "CLASSIC"
    end

    if element and element.__fgui_isTargetDebuffs and mode == "MINI" then
        local sourceUnit, auraData = AuraExtractSourceUnit(...)
        local ok = AuraIsFromPlayerOrPet(sourceUnit, auraData, ...)
        if ok == nil then return true end
        return ok
    end

    return true
end

function Target.ApplyTargetAuraModeToFrame(frame)
    if not frame or not IsTargetLikeUnit(frame.unit) then return end

    local unitframesCfg = GetUnitFramesCfg()
    local targetAuras = type(unitframesCfg.targetAuras) == "table" and unitframesCfg.targetAuras or nil
    if not targetAuras and unitframesCfg ~= EMPTY then
        targetAuras = {}
        unitframesCfg.targetAuras = targetAuras
    end

    local mode = Target.NormalizeTargetAuraMode(targetAuras and targetAuras.mode)

    local buffs = frame.Buffs
    local debuffs = frame.Debuffs
    if not buffs or not debuffs then return end

    buffs.filter = "HELPFUL"
    debuffs.filter = "HARMFUL"
    buffs.__fgui_isTargetBuffs = true
    debuffs.__fgui_isTargetDebuffs = true
    buffs.CustomFilter = AuraCustomFilter
    buffs.customFilter = AuraCustomFilter
    debuffs.CustomFilter = AuraCustomFilter
    debuffs.customFilter = AuraCustomFilter

    buffs:ClearAllPoints()
    debuffs:ClearAllPoints()

    if mode == "CLASSIC" then
        buffs:Show()
        buffs:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 6)
        buffs["growth-y"] = "UP"
        buffs.onlyShowPlayer = nil

        debuffs:Show()
        debuffs:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -6)
        debuffs["growth-y"] = "DOWN"
        debuffs.onlyShowPlayer = nil
    else
        buffs:Hide()

        debuffs:Show()
        debuffs:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 6)
        debuffs["growth-y"] = "UP"
        debuffs.onlyShowPlayer = true
    end

    if targetAuras then
        targetAuras.mode = mode
    end

    if frame.unit == "target" then
        Target.LayoutTargetHeader(frame)
    end

    if frame.UpdateAllElements then
        frame:UpdateAllElements("FGUI_AURA_MODE")
    end
end

local function ClassificationTag(unit)
    local classification = _G.UnitClassification and UnitClassification(unit)
    if not classification or IsSecretValue(classification) then
        return ""
    end

    if Secret and type(Secret.CanAccessValue) == "function" then
        local okAccess, canAccess = pcall(Secret.CanAccessValue, classification)
        if okAccess and canAccess == false then
            return ""
        end
    end

    if classification == "normal" then return "" end
    if classification == "elite" then return "+" end
    if classification == "rare" then return "R" end
    if classification == "rareelite" then return "R+" end
    if classification == "worldboss" then return "B" end
    return tostring(classification)
end

local function BuildTargetInfoText(unit)
    if not unit then return "" end

    local out = {}

    if _G.UnitLevel then
        local level = UnitLevel(unit)
        local okLevel, numericLevel = U.TryNumber(level)
        if okLevel then
            out[#out + 1] = "Lv"
            out[#out + 1] = tostring(U.Round(numericLevel))
        end
    end

    local tag = ClassificationTag(unit)
    if tag ~= "" then
        out[#out + 1] = tag
    end

    if _G.UnitClass then
        local className = UnitClass(unit)
        if className and (not IsSecretValue(className)) then
            if Secret and type(Secret.CanAccessValue) == "function" then
                local okAccess, canAccess = pcall(Secret.CanAccessValue, className)
                if okAccess and canAccess == false then
                    className = nil
                end
            end
            if className then
                out[#out + 1] = tostring(className)
            end
        end
    end

    return table.concat(out, " ")
end

function Target.CreateTargetHeader(frame)
    local unitframesCfg = GetUnitFramesCfg()
    local cfg = type(unitframesCfg.targetInfo) == "table" and unitframesCfg.targetInfo or EMPTY

    local header = CreateFrame("Frame", nil, frame)
    local textCfg = type(unitframesCfg.text) == "table" and unitframesCfg.text or EMPTY
    local font = textCfg.font or GetSharedFontToken()
    local size = cfg.fontSize or textCfg.size or 12
    local outline = Target.ResolveTargetInfoFontFlags(cfg.outline or textCfg.outline or "OUTLINE", cfg.fontWeight)
    local lineSize = (type(size) == "number" and size or 12)
    header:SetHeight((lineSize * 2) + 4)

    local name = header:CreateFontString(nil, "OVERLAY")
    name:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
    name:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 0)
    Media:ApplyFont(name, font, size, outline)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    name:SetTextColor(1, 1, 1, 1)

    local info = header:CreateFontString(nil, "OVERLAY")
    info:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    info:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    Media:ApplyFont(info, font, size, outline)
    info:SetJustifyH("LEFT")
    info:SetWordWrap(false)
    info:SetTextColor(1, 1, 1, 1)

    frame.TargetHeader = header
    frame.TargetNameText = name
    frame.TargetInfoText = info
    Target.LayoutTargetHeader(frame)
    Target.ApplyTargetHeaderTextColor(frame)
end

function Target.ApplyTargetHeaderStyle(frame, font, fallbackSize, fallbackOutline, cfg)
    if not frame then return end

    cfg = type(cfg) == "table" and cfg or EMPTY
    local size = cfg.fontSize or fallbackSize or 12
    local flags = Target.ResolveTargetInfoFontFlags(cfg.outline or fallbackOutline or "OUTLINE", cfg.fontWeight)

    if frame.TargetNameText then
        Media:ApplyFont(frame.TargetNameText, font, size, flags)
    end
    if frame.TargetInfoText then
        Media:ApplyFont(frame.TargetInfoText, font, size, flags)
    end

    Target.LayoutTargetHeader(frame)
    Target.ApplyTargetHeaderTextColor(frame)
end

function Target.UpdateTargetInfoFrame(frame)
    local unit = frame and frame.unit
    if not frame or unit ~= "target" or not frame.TargetHeader then return end

    EnsureCache()
    local cache = GetCache()
    local cfg = type(cache.targetInfo) == "table" and cache.targetInfo or EMPTY
    local hasTarget = false
    if _G.UnitExists then
        local okExists, exists = pcall(_G.UnitExists, unit)
        hasTarget = okExists and (exists == true)
    end

    local showHeader = (cfg.enabled == true) and hasTarget
    if frame.TargetHeader then
        if showHeader then
            frame.TargetHeader:Show()
        else
            frame.TargetHeader:Hide()
        end
    end

    if not showHeader then
        if frame.TargetNameText then frame.TargetNameText:SetText("") end
        if frame.TargetInfoText then frame.TargetInfoText:SetText("") end
        return
    end

    if frame.TargetNameText then
        if cfg.showName ~= false then
            local name
            if _G.UnitName then
                local okName, unitName = pcall(_G.UnitName, unit)
                if okName then
                    name = unitName
                end
            end
            SafeSetText(frame.TargetNameText, name)
            frame.TargetNameText:Show()
        else
            frame.TargetNameText:SetText("")
            frame.TargetNameText:Hide()
        end
    end

    if frame.TargetInfoText then
        if cfg.showInfo ~= false then
            SafeSetText(frame.TargetInfoText, BuildTargetInfoText(unit))
            frame.TargetInfoText:Show()
        else
            frame.TargetInfoText:SetText("")
            frame.TargetInfoText:Hide()
        end
    end

    Target.LayoutTargetHeader(frame)
    Target.ApplyTargetHeaderTextColor(frame)
end

function Target.UpdateTargetInfo(frameOrOwner)
    if type(frameOrOwner) ~= "table" then
        return
    end

    if frameOrOwner.unit then
        Target.UpdateTargetInfoFrame(frameOrOwner)
        return
    end

    if frameOrOwner.target then
        Target.UpdateTargetInfoFrame(frameOrOwner.target)
    end
end

local function RefreshFrame(frame)
    if type(frame) ~= "table" then
        return
    end

    local unit = frame.unit
    if type(unit) ~= "string" or unit == "" then
        return
    end

    if frame.TargetHeader then
        Target.UpdateTargetInfoFrame(frame)
    end

    Target.UpdateUnitHealthColor(frame, unit)
end

local function HookTargetHeaderAnchorSignals(frame)
    if type(frame) ~= "table" or not frame.TargetHeader or frame._fguiTargetHeaderSignals then
        return
    end

    local function RefreshHeader()
        Target.LayoutTargetHeader(frame)
        Target.ApplyTargetHeaderTextColor(frame)
    end

    if frame.Buffs and frame.Buffs.HookScript then
        frame.Buffs:HookScript("OnShow", RefreshHeader)
        frame.Buffs:HookScript("OnHide", RefreshHeader)
    end
    if frame.Debuffs and frame.Debuffs.HookScript then
        frame.Debuffs:HookScript("OnShow", RefreshHeader)
        frame.Debuffs:HookScript("OnHide", RefreshHeader)
    end

    frame._fguiTargetHeaderSignals = true
end

local function HandleObservedEvent(frame, owner, event, unit)
    local observedUnit = frame and frame.unit
    if type(observedUnit) ~= "string" or observedUnit == "" then
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        RefreshFrame(frame)
        if type(owner) == "table" and owner.targettarget then
            RefreshFrame(owner.targettarget)
        end
        return
    end

    if event == "PLAYER_FOCUS_CHANGED" then
        RefreshFrame(frame)
        return
    end

    if event == "UNIT_TARGET" then
        if unit == observedUnit and type(owner) == "table" and owner.targettarget then
            RefreshFrame(owner.targettarget)
        end
        return
    end

    if event == "UNIT_FACTION" or event == "UNIT_NAME_UPDATE" or event == "UNIT_LEVEL" or event == "UNIT_CLASSIFICATION_CHANGED" then
        if unit == nil or unit == observedUnit then
            RefreshFrame(frame)
        end
    end
end

local function AttachFrameSignals(frame, owner)
    if type(frame) ~= "table" then
        return
    end

    local unit = frame.unit
    if unit ~= "target" and unit ~= "focus" and unit ~= "targettarget" then
        return
    end

    if unit == "target" then
        HookTargetHeaderAnchorSignals(frame)
    end

    local observer = frame._fguiTargetObserver
    if not observer then
        observer = CreateFrame("Frame", nil, frame)
        frame._fguiTargetObserver = observer
    end

    observer:UnregisterAllEvents()
    observer._fguiFrame = frame
    observer._fguiOwner = owner
    observer:SetScript("OnEvent", function(self, event, ...)
        HandleObservedEvent(self._fguiFrame, self._fguiOwner, event, ...)
    end)

    if unit == "target" then
        observer:RegisterEvent("PLAYER_TARGET_CHANGED")
        if observer.RegisterUnitEvent then
            observer:RegisterUnitEvent("UNIT_NAME_UPDATE", unit)
            observer:RegisterUnitEvent("UNIT_LEVEL", unit)
            observer:RegisterUnitEvent("UNIT_CLASSIFICATION_CHANGED", unit)
            observer:RegisterUnitEvent("UNIT_FACTION", unit)
            observer:RegisterUnitEvent("UNIT_TARGET", unit)
        else
            observer:RegisterEvent("UNIT_NAME_UPDATE")
            observer:RegisterEvent("UNIT_LEVEL")
            observer:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
            observer:RegisterEvent("UNIT_FACTION")
            observer:RegisterEvent("UNIT_TARGET")
        end
        return
    end

    if unit == "focus" then
        observer:RegisterEvent("PLAYER_FOCUS_CHANGED")
    end

    if observer.RegisterUnitEvent then
        observer:RegisterUnitEvent("UNIT_FACTION", unit)
    else
        observer:RegisterEvent("UNIT_FACTION")
    end
end

local function DetachFrameSignals(frame)
    local observer = type(frame) == "table" and frame._fguiTargetObserver or nil
    if not observer then
        return
    end

    observer:UnregisterAllEvents()
    observer:SetScript("OnEvent", nil)
    observer._fguiFrame = nil
    observer._fguiOwner = nil
end

function Target.AttachOwner(owner)
    if type(owner) ~= "table" then
        return
    end

    AttachFrameSignals(owner.target, owner)
    AttachFrameSignals(owner.focus, owner)
    AttachFrameSignals(owner.targettarget, owner)
end

function Target.DetachOwner(owner)
    if type(owner) ~= "table" then
        return
    end

    DetachFrameSignals(owner.target)
    DetachFrameSignals(owner.focus)
    DetachFrameSignals(owner.targettarget)
end

local function ApplyOwnerAuraMode(owner)
    if type(owner) ~= "table" then
        return
    end

    if owner.target then Target.ApplyTargetAuraModeToFrame(owner.target) end
    if owner.focus then Target.ApplyTargetAuraModeToFrame(owner.focus) end
    if owner.targettarget then Target.ApplyTargetAuraModeToFrame(owner.targettarget) end
end

function Target.ReconcileOwner(owner)
    if type(owner) ~= "table" then
        return
    end

    HookTargetHeaderAnchorSignals(owner.target)

    ApplyOwnerAuraMode(owner)
    RefreshFrame(owner.target)
    RefreshFrame(owner.focus)
    RefreshFrame(owner.targettarget)
    RefreshFrame(owner.pet)
end

return Target
