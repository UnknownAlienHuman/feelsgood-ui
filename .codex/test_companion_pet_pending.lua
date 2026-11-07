local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function NewHolder()
    local holder = {
        shown = false,
        setSizeCalls = 0,
    }
    function holder:SetSize(width, height)
        self.setSizeCalls = self.setSizeCalls + 1
        self.width, self.height = width, height
    end
    function holder:SetPoint() end
    function holder:Show() self.shown = true end
    function holder:Hide() self.shown = false end
    return holder
end

local function NewPetButton(index)
    local button = {
        index = index,
        shown = false,
        sizeCalls = 0,
        parent = nil,
    }
    function button:SetParent(parent) self.parent = parent end
    function button:ClearAllPoints() end
    function button:SetPoint() end
    function button:SetSize(width, height)
        self.sizeCalls = self.sizeCalls + 1
        self.width, self.height = width, height
    end
    function button:SetHitRectInsets() end
    function button:Show() self.shown = true end
    function button:GetNormalTexture() return nil end
    function button:GetPushedTexture() return nil end
    function button:GetCheckedTexture() return nil end
    function button:GetHighlightTexture() return nil end
    function button:GetName() return "PetActionButton" .. tostring(index) end
    return button
end

_G = _G or {}
_G.UIParent = {}
local inCombat = false
_G.InCombatLockdown = function() return inCombat end
_G.RegisterStateDriver = function() end
_G.UnregisterStateDriver = function() end

local createdHolders = 0
_G.CreateFrame = function(frameType, name, parent, template)
    assertEqual(frameType, "Frame", "holder frame type")
    assertEqual(name, "FGUI_oUF_PetBarHolder", "holder name")
    assertEqual(parent, _G.UIParent, "holder parent")
    assertEqual(template, "SecureHandlerStateTemplate", "holder template")
    createdHolders = createdHolders + 1
    return NewHolder()
end

local petBarAlpha = 1
_G.PetActionBar = {
    SetAlpha = function(_, value) petBarAlpha = value end,
}

local button1 = NewPetButton(1)
_G.PetActionButton1 = button1
_G.PetActionButton2 = nil

local cp = {
    buttonSize = 32,
    spacing = 2,
    petBar = {
        showHotkeys = false,
        strata = "LOW",
        level = 35,
    },
}

local registeredMover
local ns = {
    CompanionShared = {
        PET_BUTTONS = 2,
        PET_KEY = "petbar",
        PET_ICON_CROP = 0.06,
        IsInCombat = function() return inCombat end,
        GetCompanionCfg = function() return cp end,
        ClampButtonSize = function(value) return tonumber(value) or 32 end,
        ClampSpacing = function(value) return tonumber(value) or 0 end,
        ApplyFrameLayer = function() end,
        GetConfigSection = function() return {} end,
    },
    Media = {
        ApplyIconCrop = function() end,
        CreateBorder = function() return {} end,
        SetBorderColor = function() return true end,
    },
    Movers = {
        Register = function(_, key, frame, spec)
            registeredMover = { key = key, frame = frame, spec = spec }
        end,
        Apply = function() end,
    },
    Theme = {
        Get = function() return nil end,
    },
}

assert(loadfile("modules/CompanionPetBar.lua"))("FeelsGoodUI", ns)
local PetBar = assert(ns.CompanionPetBar)
local module = {}
ns.Companion = module

local applied, detail = PetBar:Apply(module, cp, {})
assertEqual(applied, true, "missing pet button is queued, not fatal")
assertEqual(detail, "Pet action buttons pending runtime creation", "queued detail")
assertEqual(module._pendingPetButtons, true, "pet pending marker")
assertEqual(module._pendingAfterCombat, true, "watcher retry marker")
assertEqual(createdHolders, 1, "holder created once")
assertEqual(registeredMover.key, "petbar", "mover registered")
assertEqual(button1.parent, module._petAnchor, "ready button attached")
assertEqual(button1.shown, true, "ready button shown")
assertEqual(petBarAlpha, 0, "native pet bar suppressed")

local button2 = NewPetButton(2)
_G.PetActionButton2 = button2
applied, detail = PetBar:Apply(module, cp, {})
assertEqual(applied, true, "all pet buttons apply")
assertEqual(detail, nil, "terminal apply detail")
assertEqual(module._pendingPetButtons, nil, "pet pending marker cleared")
assertEqual(module._pendingAfterCombat, nil, "watcher retry marker cleared")
assertEqual(createdHolders, 1, "holder reused")
assertEqual(button2.parent, module._petAnchor, "late button attached")
assertEqual(button2.shown, true, "late button shown")
assertEqual(module._petAnchor.width, 66, "holder width uses size and spacing")
assertEqual(module._petAnchor.height, 32, "holder height")

inCombat = true
local combatApplied, combatDetail = PetBar:Apply(module, cp, {})
assertEqual(combatApplied, false, "combat apply is deferred")
assertEqual(combatDetail, "Companion pet-bar apply deferred in combat", "combat detail")
assertEqual(module._pendingAfterCombat, true, "combat pending marker")
inCombat = false

local invalidApplied, invalidDetail = PetBar:Apply(nil, cp, {})
assertEqual(invalidApplied, false, "missing owner rejected")
assertEqual(invalidDetail, "Companion pet-bar apply owner unavailable", "missing owner detail")

print("Companion pet-button pending tests passed.")
