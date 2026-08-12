-- FeelsGoodUI: Settings write helpers (validation + safe writes)
--
-- Stage 39: Foundation refactor
-- Goals:
--  - Centralize all SavedVariables writes behind a small API.
--  - Clamp/validate values to prevent "broken" profiles (bad types/out-of-range).
--  - Keep Secret Values safe (never compare/do arithmetic on unsafe numbers).
--
-- Author: Neomorph

local _, ns = ...

local Settings = {}
ns.Settings = Settings

local DB  = ns.DB
local U   = ns.U
local Log = ns.Log

-- -----------------------------
-- Validation
-- -----------------------------

local function ValidateBoolean(v, fallback)
    if v == true then return true end
    if v == false then return false end
    return (fallback == true)
end

local function ValidateString(v, fallback, maxLen)
    if type(v) ~= "string" then
        return (type(fallback) == "string") and fallback or ""
    end
    if type(maxLen) == "number" and maxLen > 0 and #v > maxLen then
        return v:sub(1, maxLen)
    end
    return v
end

local function ValidateEnum(v, allowed, fallback)
    if type(v) == "string" and type(allowed) == "table" then
        for _, a in ipairs(allowed) do
            if v == a then return v end
        end
    end
    return fallback
end

local function ValidateNumber(v, minV, maxV, fallback, integer)
    local ok, n = U.TryNumber(v)
    if not ok then
        ok, n = U.TryNumber(fallback)
        if not ok then return fallback end
    end

    local okMin, mn = U.TryNumber(minV)
    local okMax, mx = U.TryNumber(maxV)

    -- Comparisons only happen on plain numbers (TryNumber guarantees that).
    if okMin and n < mn then n = mn end
    if okMax and n > mx then n = mx end

    if integer == true then
        local okFloor, r = pcall(function() return math.floor(n + 0.5) end)
        if okFloor then n = r end
    end

    return n
end

-- rule:
--  { type="number"|"int"|"boolean"|"string"|"enum", min=, max=, fallback=, maxLen=, values={...} }
function Settings:Validate(value, rule)
    if type(rule) ~= "table" then return value end

    local t = rule.type
    if t == "boolean" then
        return ValidateBoolean(value, rule.fallback)
    end
    if t == "string" then
        return ValidateString(value, rule.fallback, rule.maxLen)
    end
    if t == "enum" then
        return ValidateEnum(value, rule.values, rule.fallback)
    end
    if t == "int" then
        return ValidateNumber(value, rule.min, rule.max, rule.fallback, true)
    end
    if t == "number" then
        return ValidateNumber(value, rule.min, rule.max, rule.fallback, false)
    end

    return value
end

-- -----------------------------
-- Path helpers
-- -----------------------------

local function EnsureProfile()
    if not (DB and DB.EnsureProfileRoot) then return nil end
    local p = DB:EnsureProfileRoot()
    if type(p) ~= "table" then return nil end
    return p
end

local function EnsureSection(section)
    if type(section) ~= "string" or section == "" then return nil end
    local profile = EnsureProfile()
    if not profile then return nil end
    if type(profile[section]) ~= "table" then
        profile[section] = {}
    end
    return profile[section]
end

local function NormalizeSharedTypography()
    local defaults = DB and DB.defaults and DB.defaults.profile or {}
    local mediaDefaults = (type(defaults.media) == "table") and defaults.media or {}
    local themeDefaults = (type(defaults.theme) == "table") and defaults.theme or {}
    local themeFontDefaults = (type(themeDefaults.fonts) == "table") and themeDefaults.fonts or {}
    local unitframesDefaults = (type(defaults.unitframes) == "table") and defaults.unitframes or {}
    local legacyDefaults = (type(unitframesDefaults.text) == "table") and unitframesDefaults.text or {}

    local media = EnsureSection("media")
    if type(media) ~= "table" then
        return
    end

    local theme = EnsureSection("theme")
    if type(theme) ~= "table" then
        return
    end
    theme.fonts = (type(theme.fonts) == "table") and theme.fonts or {}

    local uf = EnsureSection("unitframes")
    local legacyText = (type(uf) == "table" and type(uf.text) == "table") and uf.text or {}

    local defaultMediaFont = mediaDefaults.font or legacyDefaults.font or "Fonts\\FRIZQT__.TTF"
    local defaultThemeOutline = themeFontDefaults.outline or legacyDefaults.outline or "OUTLINE"

    media.font = ValidateString(media.font, defaultMediaFont, 256)
    theme.fonts.outline = ValidateString(theme.fonts.outline, defaultThemeOutline, 32)

    if media.font == defaultMediaFont then
        local legacyFont = ValidateString(legacyText.font, defaultMediaFont, 256)
        if legacyFont ~= "" and legacyFont ~= defaultMediaFont then
            media.font = legacyFont
        end
    end

    if theme.fonts.outline == defaultThemeOutline then
        local legacyOutline = ValidateString(legacyText.outline, defaultThemeOutline, 32)
        if legacyOutline ~= "" and legacyOutline ~= defaultThemeOutline then
            theme.fonts.outline = legacyOutline
        end
    end
end

local function GetPathRoot(path)
    if type(path) ~= "table" or #path == 0 then return nil end
    local p = EnsureProfile()
    if not p then return nil end

    local t = p
    for i = 1, #path - 1 do
        local k = path[i]
        if type(k) ~= "string" and type(k) ~= "number" then return nil end
        if type(t[k]) ~= "table" then t[k] = {} end
        t = t[k]
    end

    local last = path[#path]
    if type(last) ~= "string" and type(last) ~= "number" then return nil end
    return t, last
end

function Settings:Get(path, fallback)
    if type(path) ~= "table" or #path == 0 then return fallback end
    local p = EnsureProfile()
    if not p then return fallback end

    local t = p
    for i = 1, #path do
        local k = path[i]
        if type(t) ~= "table" then return fallback end
        t = t[k]
        if t == nil then return fallback end
    end
    return t
end

-- Writes a value into the profile after validation.
-- Returns: changed:boolean, storedValue:any
function Settings:Set(path, value, rule)
    local root, key = GetPathRoot(path)
    if not root then
        if Log and Log.Warn then Log:Warn("Settings:Set failed (bad path)") end
        return false, nil
    end

    local v = (rule and self:Validate(value, rule)) or value
    local old = root[key]
    if old == v then return false, v end

    root[key] = v
    return true, v
end

-- -----------------------------
-- Stage 41: Transactional writes + panel undo + section reset
-- -----------------------------

Settings._pending = Settings._pending or {}          -- per apply-key rollback lists
Settings._undoPanels = Settings._undoPanels or {}    -- per panel-key undo stack
Settings._undoPanelBatches = Settings._undoPanelBatches or {} -- active panel-key batch state

local function CopyPath(path)
    if type(path) ~= "table" then return nil end
    local t = {}
    for i = 1, #path do
        t[i] = path[i]
    end
    return t
end

local function WriteRaw(path, value)
    local root, key = GetPathRoot(path)
    if not root then return false end
    root[key] = value
    return true
end

local function RecordPending(keys, path, oldValue)
    if type(keys) == "string" then
        Settings._pending[keys] = Settings._pending[keys] or {}
        table.insert(Settings._pending[keys], { path = CopyPath(path), old = oldValue })
        return
    end
    if type(keys) == "table" then
        for _, k in ipairs(keys) do
            if type(k) == "string" and k ~= "" then
                Settings._pending[k] = Settings._pending[k] or {}
                table.insert(Settings._pending[k], { path = CopyPath(path), old = oldValue })
            end
        end
    end
end

local function PushUndoEntry(panelKey, entry)
    if type(panelKey) ~= "string" or panelKey == "" or type(entry) ~= "table" then
        return
    end

    local stack = Settings._undoPanels[panelKey]
    if type(stack) ~= "table" then
        stack = {}
        Settings._undoPanels[panelKey] = stack
    end

    stack[#stack + 1] = entry
    if #stack > 50 then
        table.remove(stack, 1)
    end
end

local function GetUndoBatch(panelKey)
    if type(panelKey) ~= "string" or panelKey == "" then
        return nil
    end

    local batch = Settings._undoPanelBatches[panelKey]
    if type(batch) ~= "table" then
        batch = { depth = 0, changes = {} }
        Settings._undoPanelBatches[panelKey] = batch
    end

    return batch
end

local function RecordUndo(panelKey, path, oldValue, newValue)
    if type(panelKey) ~= "string" or panelKey == "" then return end
    local batch = Settings._undoPanelBatches and Settings._undoPanelBatches[panelKey]
    if type(batch) == "table" and batch.depth > 0 then
        batch.changes[#batch.changes + 1] = { path = CopyPath(path), old = oldValue, new = newValue }
        return
    end

    PushUndoEntry(panelKey, { path = CopyPath(path), old = oldValue, new = newValue })
end

function Settings:BeginPanelUndoBatch(panelKey)
    local batch = GetUndoBatch(panelKey)
    if not batch then
        return false
    end

    batch.depth = batch.depth + 1
    return true
end

function Settings:EndPanelUndoBatch(panelKey)
    local batch = type(panelKey) == "string" and self._undoPanelBatches and self._undoPanelBatches[panelKey] or nil
    if type(batch) ~= "table" or batch.depth <= 0 then
        return false
    end

    batch.depth = batch.depth - 1
    if batch.depth > 0 then
        return false
    end

    self._undoPanelBatches[panelKey] = nil
    if type(batch.changes) ~= "table" or #batch.changes == 0 then
        return false
    end

    PushUndoEntry(panelKey, { kind = "batch", changes = batch.changes })
    return true
end

-- Transactional write:
--  - validates value
--  - writes it into the profile
--  - records old value for rollback tied to apply key(s)
--  - records undo entry tied to a UI panel key
-- Returns: changed:boolean, storedValue:any
function Settings:SetTx(applyKeys, path, value, rule, panelKey)
    local root, key = GetPathRoot(path)
    if not root then
        if Log and Log.Warn then Log:Warn("Settings:SetTx failed (bad path)") end
        return false, nil
    end

    local v = (rule and self:Validate(value, rule)) or value
    local old = root[key]
    if old == v then return false, v end

    root[key] = v
    RecordPending(applyKeys, path, old)
    RecordUndo(panelKey, path, old, v)

    return true, v
end

-- Rollback any pending changes recorded under apply key.
function Settings:Rollback(applyKey)
    if type(applyKey) ~= "string" or applyKey == "" then return end
    local list = self._pending and self._pending[applyKey]
    if type(list) ~= "table" or #list == 0 then return end

    for i = #list, 1, -1 do
        local rec = list[i]
        if type(rec) == "table" and type(rec.path) == "table" then
            WriteRaw(rec.path, rec.old)
        end
    end

    self._pending[applyKey] = nil
end

-- Commit clears rollback list after successful apply.
function Settings:Commit(applyKey)
    if type(applyKey) ~= "string" or applyKey == "" then return end
    if self._pending then
        self._pending[applyKey] = nil
    end
end

local function ClearPendingKeys(keys)
    if type(Settings._pending) ~= "table" then
        return false
    end

    local cleared = false
    if type(keys) == "string" then
        if keys ~= "" and Settings._pending[keys] ~= nil then
            Settings._pending[keys] = nil
            cleared = true
        end
        return cleared
    end

    if type(keys) ~= "table" then
        return false
    end

    for i = 1, #keys do
        local key = keys[i]
        if type(key) == "string" and key ~= "" and Settings._pending[key] ~= nil then
            Settings._pending[key] = nil
            cleared = true
        end
    end
    return cleared
end

function Settings:InvalidatePanelHistory(panelKey, applyKeys)
    local invalidated = false

    if type(panelKey) == "string" and panelKey ~= "" and type(self._undoPanels) == "table" and self._undoPanels[panelKey] ~= nil then
        self._undoPanels[panelKey] = nil
        invalidated = true
    end

    if type(panelKey) == "string" and panelKey ~= "" and type(self._undoPanelBatches) == "table" and self._undoPanelBatches[panelKey] ~= nil then
        self._undoPanelBatches[panelKey] = nil
        invalidated = true
    end

    if ClearPendingKeys(applyKeys) then
        invalidated = true
    end

    return invalidated
end

function Settings:InvalidateAllHistory()
    self._pending = {}
    self._undoPanels = {}
    self._undoPanelBatches = {}
end

-- Soft undo for UI panels (independent from apply-key rollback).
-- Returns: didUndo:boolean
function Settings:UndoPanel(panelKey)
    if type(panelKey) ~= "string" or panelKey == "" then return false end
    local stack = self._undoPanels and self._undoPanels[panelKey]
    if type(stack) ~= "table" or #stack == 0 then return false end

    local rec = table.remove(stack)
    if type(rec) ~= "table" then return false end

    if type(rec.changes) == "table" then
        for i = #rec.changes, 1, -1 do
            local change = rec.changes[i]
            if type(change) == "table" and type(change.path) == "table" then
                WriteRaw(change.path, change.old)
            end
        end
        return true
    end

    if type(rec.path) ~= "table" then return false end
    WriteRaw(rec.path, rec.old)
    return true
end

local function ResetProfileSection(section)
    if type(section) ~= "string" or section == "" then return false end
    if not (DB and DB.defaults and DB.defaults.profile) then return false end

    local prof = EnsureProfile()
    if not prof then return false end

    local def = DB.defaults.profile[section]
    if type(def) ~= "table" then return false end

    prof[section] = U.DeepCopy(def)
    return true
end

-- Reset a top-level section of the profile to defaults.
-- Example sections: "unitframes", "actionbars", "movers", "center".
function Settings:ResetSection(section)
    return ResetProfileSection(section)
end

function Settings:ResetSections(sections)
    if type(sections) == "string" then
        return ResetProfileSection(sections)
    end
    if type(sections) ~= "table" then
        return false
    end

    local didReset = false
    for i = 1, #sections do
        didReset = ResetProfileSection(sections[i]) or didReset
    end
    return didReset
end

-- Cross-field consistency fixes (for old DBs or manual edits).
local function ClampInt(v, minV, maxV, fallback)
    return ValidateNumber(v, minV, maxV, fallback, true)
end

local function NormalizeCompanionSpacing(v)
    local spacing = ClampInt(v, 0, 12, 0)
    if spacing <= 1 then
        return 0
    end
    return spacing
end

local function NormalizeActionBarSpacing(v)
    local spacing = ClampInt(v, 0, 12, 0)
    if spacing <= 1 then
        return 0
    end
    return spacing
end

function Settings:Normalize(key)
    if key == "actionbars" then
        local ab = EnsureSection("actionbars")
        if type(ab) ~= "table" then return end

        -- Legacy field; no longer used.
        ab.enabled = nil
        ab.buttonSize = ClampInt(ab.buttonSize, 24, 60, 32)
        ab.spacing = NormalizeActionBarSpacing(ab.spacing)
        if ab.hideBlizzard == nil then ab.hideBlizzard = true end
        if ab.showHotkeys == nil then ab.showHotkeys = false end
        ab.autoHide = (type(ab.autoHide) == "table") and ab.autoHide or {}
        ab.autoHide.enabled = ValidateBoolean(ab.autoHide.enabled, false)
        ab._bar45Imported = nil
        ab.keepMicroBags = nil
        ab.compactBags = nil
        if type(ab.layering) == "table" then
            ab.layering.petBarStrata = nil
            ab.layering.petBarLevel = nil
            if next(ab.layering) == nil then
                ab.layering = nil
            end
        end

        local defaults = {
            [1] = { enabled = true,  prefix = "ActionButton",               buttons = 12, rows = 1 },
            [2] = { enabled = true,  prefix = "MultiBarBottomLeftButton",   buttons = 12, rows = 1 },
            [3] = { enabled = true,  prefix = "MultiBarBottomRightButton",  buttons = 12, rows = 1 },
            [4] = { enabled = true,  prefix = "MultiBarRightButton",        buttons = 12, rows = 12 },
            [5] = { enabled = true,  prefix = "MultiBarLeftButton",         buttons = 12, rows = 12 },
        }

        if type(ab.bars) ~= "table" then
            ab.bars = {
                [1] = {
                    enabled = true,
                    prefix = defaults[1].prefix,
                    buttons = ClampInt(ab.bar1Buttons, 1, 12, defaults[1].buttons),
                    rows = ClampInt(ab.bar1Rows, 1, 4, defaults[1].rows),
                },
                [2] = {
                    enabled = true,
                    prefix = defaults[2].prefix,
                    buttons = ClampInt(ab.bar2Buttons, 1, 12, defaults[2].buttons),
                    rows = ClampInt(ab.bar2Rows, 1, 4, defaults[2].rows),
                },
                [3] = {
                    enabled = true,
                    prefix = defaults[3].prefix,
                    buttons = defaults[3].buttons,
                    rows = defaults[3].rows,
                },
                [4] = {
                    enabled = ValidateBoolean(ab.bar3Enabled, false),
                    prefix = defaults[4].prefix,
                    buttons = ClampInt(ab.bar3Buttons, 1, 12, defaults[4].buttons),
                    rows = ClampInt(ab.bar3Rows, 1, 12, defaults[4].rows),
                },
                [5] = {
                    enabled = ValidateBoolean(ab.bar4Enabled, false),
                    prefix = defaults[5].prefix,
                    buttons = ClampInt(ab.bar4Buttons, 1, 12, defaults[5].buttons),
                    rows = ClampInt(ab.bar4Rows, 1, 12, defaults[5].rows),
                },
            }
        end

        for id, _ in pairs(ab.bars) do
            if type(id) == "number" and id > 5 then
                ab.bars[id] = nil
            end
        end
        local maxRows = { [1]=4, [2]=4, [3]=4, [4]=12, [5]=12 }
        for id = 1, 5 do
            ab.bars[id] = ab.bars[id] or {}
            local b = ab.bars[id]
            local d = defaults[id]
            b.enabled = ValidateBoolean(b.enabled, d.enabled)
            if type(b.prefix) ~= "string" or b.prefix == "" then
                b.prefix = d.prefix
            end
            b.buttons = ClampInt(b.buttons, 1, 12, d.buttons)
            local mr = maxRows[id] or 4
            b.rows = ClampInt(b.rows, 1, mr, d.rows)
            if b.rows > b.buttons then b.rows = b.buttons end
        end

        ab.bar1Buttons = nil
        ab.bar1Rows = nil
        ab.bar2Buttons = nil
        ab.bar2Rows = nil
        ab.bar3Enabled = nil
        ab.bar3Buttons = nil
        ab.bar3Rows = nil
        ab.bar4Enabled = nil
        ab.bar4Buttons = nil
        ab.bar4Rows = nil
        return
    end

    if key == "companion" then
        local cp = EnsureSection("companion")
        if type(cp) ~= "table" then return end

        cp.buttonSize = ClampInt(cp.buttonSize, 24, 60, 32)
        cp.spacing = NormalizeCompanionSpacing(cp.spacing)

        cp.microMenu = (type(cp.microMenu) == "table") and cp.microMenu or {}
        cp.microMenu.enabled = ValidateBoolean(cp.microMenu.enabled, true)

        cp.bags = (type(cp.bags) == "table") and cp.bags or {}
        cp.bags.enabled = ValidateBoolean(cp.bags.enabled, true)
        cp.bags.compact = ValidateBoolean(cp.bags.compact, true)

        cp.petBar = (type(cp.petBar) == "table") and cp.petBar or {}
        cp.petBar.showHotkeys = ValidateBoolean(cp.petBar.showHotkeys, false)
        cp.petBar.strata = ValidateEnum(cp.petBar.strata, {
            "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP"
        }, "LOW")
        cp.petBar.level = ClampInt(cp.petBar.level, 1, 200, 35)
        return
    end

    if key == "experience" then
        local xp = EnsureSection("experience")
        if type(xp) ~= "table" then return end

        xp.enabled = ValidateBoolean(xp.enabled, true)
        xp.showText = ValidateBoolean(xp.showText, true)
        xp.showRested = ValidateBoolean(xp.showRested, true)
        xp.width = ClampInt(xp.width, 200, 900, 420)
        xp.height = ClampInt(xp.height, 6, 24, 10)
        return
    end

    if key == "unitframes" then
        local uf = EnsureSection("unitframes")
        if type(uf) ~= "table" then return end

        local defUF = (DB and DB.defaults and DB.defaults.profile and DB.defaults.profile.unitframes) or {}
        local defSizes = (type(defUF.sizes) == "table") and defUF.sizes or {}
        local defScales = (type(defUF.scales) == "table") and defUF.scales or {}

        local function NormalizeSizeEntry(entry, fallbackW, fallbackH)
            entry = (type(entry) == "table") and entry or {}
            entry.width = ClampInt(entry.width, 120, 520, fallbackW)
            entry.height = ClampInt(entry.height, 14, 40, fallbackH)
            return entry
        end

        uf.scales = (type(uf.scales) == "table") and uf.scales or {}
        uf.scales.player = ValidateNumber(uf.scales.player, 0.60, 1.30, defScales.player or 0.90, false)
        uf.scales.target = ValidateNumber(uf.scales.target, 0.60, 1.30, defScales.target or uf.scales.player, false)
        uf.scales.focus = ValidateNumber(uf.scales.focus, 0.60, 1.30, defScales.focus or uf.scales.player, false)
        uf.scales.targettarget = ValidateNumber(uf.scales.targettarget, 0.60, 1.30, defScales.targettarget or uf.scales.player, false)
        uf.scales.pet = ValidateNumber(uf.scales.pet, 0.60, 1.30, defScales.pet or uf.scales.player, false)

        uf.sizes = (type(uf.sizes) == "table") and uf.sizes or {}
        uf.sizes.player = NormalizeSizeEntry(uf.sizes.player, (defSizes.player and defSizes.player.width) or 160, (defSizes.player and defSizes.player.height) or 20)
        uf.sizes.target = NormalizeSizeEntry(uf.sizes.target, (defSizes.target and defSizes.target.width) or uf.sizes.player.width, (defSizes.target and defSizes.target.height) or uf.sizes.player.height)
        uf.sizes.focus = NormalizeSizeEntry(uf.sizes.focus, (defSizes.focus and defSizes.focus.width) or uf.sizes.player.width, (defSizes.focus and defSizes.focus.height) or uf.sizes.player.height)
        uf.sizes.targettarget = NormalizeSizeEntry(uf.sizes.targettarget, (defSizes.targettarget and defSizes.targettarget.width) or uf.sizes.player.width, (defSizes.targettarget and defSizes.targettarget.height) or uf.sizes.player.height)
        uf.sizes.pet = NormalizeSizeEntry(uf.sizes.pet, (defSizes.pet and defSizes.pet.width) or uf.sizes.player.width, (defSizes.pet and defSizes.pet.height) or uf.sizes.player.height)

        uf.enabled = ValidateBoolean(uf.enabled, true)
        uf.showFocus = ValidateBoolean(uf.showFocus, true)
        uf.showTargetTarget = ValidateBoolean(uf.showTargetTarget, true)
        uf.showPet = ValidateBoolean(uf.showPet, true)
        uf.auraIconSize = ClampInt(uf.auraIconSize, 12, 48, 20)
        uf.auraSpacing = ClampInt(uf.auraSpacing, 0, 12, 0)
        uf.auraMax = ClampInt(uf.auraMax, 1, 16, 8)

        uf.castbar = uf.castbar or {}
        if uf.castbar.enabled == nil then uf.castbar.enabled = true end
        uf.castbar.height = ClampInt(uf.castbar.height, 8, 24, 14)

        uf.targetInfo = uf.targetInfo or {}
        uf.targetInfo.powerHeight = ClampInt(uf.targetInfo.powerHeight, 6, 20, 10)
        if uf.targetInfo.nameAnchor ~= "FRAME" and uf.targetInfo.nameAnchor ~= "AURAS" then
            uf.targetInfo.nameAnchor = "FRAME"
        end
        if uf.targetInfo.fontWeight ~= "regular" and uf.targetInfo.fontWeight ~= "bold" then
            uf.targetInfo.fontWeight = "regular"
        end
        if uf.targetInfo.colorMode ~= "inherit" and uf.targetInfo.colorMode ~= "custom" then
            uf.targetInfo.colorMode = "inherit"
        end
        uf.targetInfo.color = (type(uf.targetInfo.color) == "table") and uf.targetInfo.color or {}
        uf.targetInfo.color.r = ValidateNumber(uf.targetInfo.color.r, 0.00, 1.00, 1.00, false)
        uf.targetInfo.color.g = ValidateNumber(uf.targetInfo.color.g, 0.00, 1.00, 1.00, false)
        uf.targetInfo.color.b = ValidateNumber(uf.targetInfo.color.b, 0.00, 1.00, 1.00, false)
        uf.targetInfo.color.a = ValidateNumber(uf.targetInfo.color.a, 0.00, 1.00, 1.00, false)

        uf.playerLowHP = (type(uf.playerLowHP) == "table") and uf.playerLowHP or {}
        local lhp = uf.playerLowHP
        lhp.enabled = ValidateBoolean(lhp.enabled, true)
        lhp.threshold = ClampInt(lhp.threshold, 5, 80, 30)
        lhp.maxAlpha = ValidateNumber(lhp.maxAlpha, 0.10, 1.00, 0.65, false)
        lhp.color = (type(lhp.color) == "table") and lhp.color or {}
        lhp.color.r = ValidateNumber(lhp.color.r, 0.00, 1.00, 1.00, false)
        lhp.color.g = ValidateNumber(lhp.color.g, 0.00, 1.00, 0.12, false)
        lhp.color.b = ValidateNumber(lhp.color.b, 0.00, 1.00, 0.12, false)
        lhp.color.a = ValidateNumber(lhp.color.a, 0.00, 1.00, 1.00, false)

        uf.targetAuras = uf.targetAuras or {}
        if uf.targetAuras.mode ~= "MINI" and uf.targetAuras.mode ~= "CLASSIC" then
            uf.targetAuras.mode = "MINI"
        end
        return
    end

    if key == "center" then
        local c = EnsureSection("center")
        if type(c) ~= "table" then return end
        local uf = EnsureSection("unitframes")
        local legacyText = (type(uf) == "table" and type(uf.text) == "table") and uf.text or {}
        c.scale = ValidateNumber(c.scale, 0.60, 1.30, 0.90, false)
        c.width = ClampInt(c.width, 200, 900, 420)
        c.resourceHeight = ClampInt(c.resourceHeight, 6, 24, 10)
        c.powerHeight = ClampInt(c.powerHeight, 6, 24, 12)
        c.spacing = ClampInt(c.spacing, 0, 20, 5)
        c.maxSegments = ClampInt(c.maxSegments, 1, 20, 10)
        c.showClassBar = ValidateBoolean(c.showClassBar, true)
        c.hideBlizzardClassResources = ValidateBoolean(c.hideBlizzardClassResources, true)
        c.useClassColorForResource = ValidateBoolean(c.useClassColorForResource, true)
        c.useSpecColorForRunes = ValidateBoolean(c.useSpecColorForRunes, false)
        c.showPowerText = ValidateBoolean(c.showPowerText, true)
        c.showResourceText = ValidateBoolean(c.showResourceText, false)
        c.text = (type(c.text) == "table") and c.text or {}
        c.text.font = ValidateString(c.text.font, legacyText.font or "Fonts\\FRIZQT__.TTF", 256)
        c.text.size = ValidateNumber(c.text.size, 8, 28, legacyText.size or 12, true)
        c.text.outline = ValidateString(c.text.outline, legacyText.outline or "OUTLINE", 32)
        c.threshold = (type(c.threshold) == "table") and c.threshold or {}
        c.threshold.enabled = ValidateBoolean(c.threshold.enabled, false)
        c.threshold.percent = ClampInt(c.threshold.percent, 10, 95, 70)
        c.threshold.mode = ValidateEnum(c.threshold.mode, { "below", "above" }, "below")
        c.threshold.spark = ValidateBoolean(c.threshold.spark, true)
        c.threshold.color = (type(c.threshold.color) == "table") and c.threshold.color or {}
        c.threshold.color.r = ValidateNumber(c.threshold.color.r, 0.00, 1.00, 1.00, false)
        c.threshold.color.g = ValidateNumber(c.threshold.color.g, 0.00, 1.00, 0.34, false)
        c.threshold.color.b = ValidateNumber(c.threshold.color.b, 0.00, 1.00, 0.12, false)
        c.threshold.color.a = ValidateNumber(c.threshold.color.a, 0.00, 1.00, 1.00, false)
        return
    end
end

-- Stage 45: run all known normalizers + clamp common non-module settings.
function Settings:NormalizeAll()
    -- Module normalizers
    self:Normalize("unitframes")
    self:Normalize("center")
    self:Normalize("actionbars")
    self:Normalize("companion")
    self:Normalize("experience")

    -- Shared typography/multi-module media policy.
    NormalizeSharedTypography()

    -- General
    local g = EnsureSection("general")
    if not g then return end
    g.enabled = ValidateBoolean(g.enabled, true)
    g.debug = ValidateBoolean(g.debug, false)
    g.perfOverlay = ValidateBoolean(g.perfOverlay, false)
    g.safeHandlers = ValidateBoolean(g.safeHandlers, true)
    g.safeHandlersFast = ValidateBoolean(g.safeHandlersFast, false)

    -- Minimap
    local mm = EnsureSection("minimap")
    mm.hide = ValidateBoolean(mm.hide, false)
    mm.minimapPos = ValidateNumber(mm.minimapPos, 0, 360, 220, true)
    mm.radius = ValidateNumber(mm.radius, 40, 200, 80, true)

    -- Format
    local format = EnsureSection("format")
    format.shortNumbers = format.shortNumbers or {}
    local sn = format.shortNumbers
    sn.enabled = ValidateBoolean(sn.enabled, true)
    sn.suffixCase = ValidateEnum(sn.suffixCase, { "lower", "upper" }, "lower")
    sn.decimalsSmall = ValidateNumber(sn.decimalsSmall, 0, 2, 1, true)
    sn.decimalsLarge = ValidateNumber(sn.decimalsLarge, 0, 2, 0, true)
    if type(sn.units) ~= "table" then
        sn.units = { player = true, target = true, targettarget = true, focus = true }
    else
        if sn.units.player == nil then sn.units.player = true end
        if sn.units.target == nil then sn.units.target = true end
        if sn.units.targettarget == nil then sn.units.targettarget = true end
        if sn.units.focus == nil then sn.units.focus = true end
    end

    -- Editor
    local editor = EnsureSection("editor")
    editor.snap = editor.snap or {}
    local s = editor.snap
    s.enabled = ValidateBoolean(s.enabled, true)
    s.threshold = ValidateNumber(s.threshold, 2, 30, 10, true)
    s.toGrid = ValidateBoolean(s.toGrid, true)
    s.toFrames = ValidateBoolean(s.toFrames, true)
    s.showGuides = ValidateBoolean(s.showGuides, true)

    editor.nudge = editor.nudge or {}
    local n = editor.nudge
    n.step = ValidateNumber(n.step, 1, 20, 1, true)
    n.stepLarge = ValidateNumber(n.stepLarge, 5, 50, 10, true)

    editor.resize = editor.resize or {}
    editor.resize.enabled = ValidateBoolean(editor.resize.enabled, true)

    -- Movers
    local mv = EnsureSection("movers")
    mv.unlocked = ValidateBoolean(mv.unlocked, false)
    mv.gridStep = ValidateNumber(mv.gridStep, 4, 128, 10, true)

    -- Options UX
    local options = EnsureSection("options")
    options.livePreview = options.livePreview or {}
    local lp = options.livePreview
    lp.unitframes = ValidateBoolean(lp.unitframes, true)
    lp.center = ValidateBoolean(lp.center, true)
    lp.actionbars = ValidateBoolean(lp.actionbars, true)
    lp.companion = ValidateBoolean(lp.companion, true)
    lp.editmode = ValidateBoolean(lp.editmode, true)
end
