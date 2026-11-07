local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertNil(value, label)
    if value ~= nil then
        error((label or "value") .. ": expected nil, got " .. tostring(value), 2)
    end
end

local function NewFrame()
    local frame = {
        hooks = {},
        alpha = 1,
        shown = true,
        hideCalls = 0,
        showCalls = 0,
    }
    function frame:HookScript(name, callback)
        self.hooks[name] = self.hooks[name] or {}
        self.hooks[name][#self.hooks[name] + 1] = callback
    end
    function frame:SetAlpha(value) self.alpha = value end
    function frame:Hide() self.hideCalls = self.hideCalls + 1; self.shown = false end
    function frame:Show() self.showCalls = self.showCalls + 1; self.shown = true end
    function frame:GetWidth() return 32 end
    function frame:GetHeight() return 32 end
    return frame
end

local function NewFontString()
    local fontString = {
        text = nil,
        shown = true,
        showCalls = 0,
        hideCalls = 0,
    }
    function fontString:GetObjectType() return "FontString" end
    function fontString:SetPoint() end
    function fontString:SetJustifyH() end
    function fontString:SetJustifyV() end
    function fontString:SetText(value) self.text = value end
    function fontString:SetTextColor() end
    function fontString:Show() self.showCalls = self.showCalls + 1; self.shown = true end
    function fontString:Hide() self.hideCalls = self.hideCalls + 1; self.shown = false end
    return fontString
end

_G = _G or {}
local secureHooks = {}
_G.hooksecurefunc = function(object, method, callback)
    secureHooks[object] = secureHooks[object] or {}
    secureHooks[object][method] = secureHooks[object][method] or {}
    secureHooks[object][method][#secureHooks[object][method] + 1] = callback
end

local microMenu = NewFrame()
function microMenu:ResetMicroMenuPosition() end
_G.MicroMenu = microMenu

local microButton = NewFrame()
_G.MICRO_BUTTONS = { "MicroButtonA" }
_G.MicroButtonA = microButton

local bagButton = NewFrame()
function bagButton:UpdateTextures() end
function bagButton:IsBackpack() return true end
function bagButton:GetName() return "MainMenuBarBackpackButton" end
function bagButton:CreateFontString()
    self.createdFontStrings = (self.createdFontStrings or 0) + 1
    self.lastFontString = NewFontString()
    return self.lastFontString
end
_G.MainMenuBarBackpackButton = bagButton
_G.BagsBar = NewFrame()
_G.NUM_TOTAL_BAG_FRAMES = 1
_G.C_Container = {
    GetContainerNumSlots = function(index)
        return index == 0 and 16 or 0
    end,
    GetContainerNumFreeSlots = function(index)
        return index == 0 and 7 or 0
    end,
}

local cp = {
    buttonSize = 32,
    spacing = 0,
    microMenu = { enabled = true },
    bags = { enabled = true, compact = true },
    petBar = { showHotkeys = false, strata = "LOW", level = 35 },
}
local inCombat = false
local takeOver = true
local shared = {
    MICRO_LAYOUT_RETRY_KEY = "TEST_MICRO_RETRY",
    MICRO_BAGS_GAP = 4,
    MICRO_ICON_CROP = 0.06,
    GetCompanionCfg = function() return cp end,
    IsInCombat = function() return inCombat end,
    ShouldTakeOverMicroAndBags = function() return takeOver end,
    ShouldManageMicroMenu = function(_, config)
        return takeOver and config.microMenu.enabled ~= false
    end,
    ShouldManageBags = function(_, config)
        return takeOver and config.bags.enabled ~= false
    end,
}

local ns = {
    CompanionShared = shared,
    Media = {
        ApplyFont = function() end,
        ApplyIconCrop = function() end,
    },
    Movers = {
        Register = function() end,
        Apply = function() end,
    },
    Safety = {
        CancelDebounce = function() end,
        Debounce = function() return true end,
    },
    Theme = {
        GetFontToken = function() return "font" end,
        GetFontOutline = function() return "OUTLINE" end,
    },
}

local module = {
    _eventsAttached = true,
}
function module:RequestApply() return true end
ns.Companion = module

assert(loadfile("modules/CompanionMicroBags.lua"))("FeelsGoodUI", ns)
local MicroBags = assert(ns.CompanionMicroBags)

assertEqual(MicroBags:EnsureHooks(module), true, "initial hook registration")
assertEqual(module._microSourceHooks[microMenu], true, "micro menu hook owned by module")
assertEqual(module._microSourceHooks[microButton], true, "micro button hook owned by module")
assertEqual(module._bagTextureHooks[bagButton], true, "bag texture hook owned by module")
assertEqual(#microMenu.hooks.OnShow, 1, "one micro menu OnShow hook")
assertEqual(#microMenu.hooks.OnHide, 1, "one micro menu OnHide hook")
assertEqual(#microButton.hooks.OnShow, 1, "one micro button OnShow hook")
assertEqual(#secureHooks[microMenu].ResetMicroMenuPosition, 1, "one micro reset secure hook")
assertEqual(#secureHooks[bagButton].UpdateTextures, 1, "one bag texture secure hook")
assertNil(rawget(microMenu, "_fguiCompanionHooked"), "micro menu has no foreign marker")
assertNil(rawget(microButton, "_fguiCompanionHooked"), "micro button has no foreign marker")
assertNil(rawget(bagButton, "_fguiSquareSkinHooked"), "bag button has no skin marker")

assertEqual(MicroBags:EnsureHooks(module), true, "repeat hook registration")
assertEqual(#microMenu.hooks.OnShow, 1, "micro menu hook not duplicated")
assertEqual(#microButton.hooks.OnShow, 1, "micro button hook not duplicated")
assertEqual(#secureHooks[microMenu].ResetMicroMenuPosition, 1, "micro reset hook not duplicated")
assertEqual(#secureHooks[bagButton].UpdateTextures, 1, "bag texture hook not duplicated")

module._compactBackpackButton = bagButton
MicroBags:UpdateCompactBagCountText(module, {})
local text = module._bagCountTextByButton[bagButton]
assertEqual(type(text), "table", "count text owned by module")
assertEqual(text.text, "7", "free bag count rendered")
assertEqual(module._compactBagSummary, "7/16", "summary owned by module")
assertEqual(bagButton.createdFontStrings, 1, "one font string created")
assertNil(rawget(bagButton, "_fguiBagCountText"), "button has no count-text marker")
assertNil(rawget(bagButton, "_fguiBagSummary"), "button has no summary marker")

MicroBags:UpdateCompactBagCountText(module, {})
assertEqual(module._bagCountTextByButton[bagButton], text, "count text reused")
assertEqual(bagButton.createdFontStrings, 1, "count text not reallocated")
assertEqual(text.showCalls >= 1, true, "reused count text shown")

cp = {
    buttonSize = 32,
    spacing = 0,
    microMenu = { enabled = false },
    bags = { enabled = false, compact = true },
    petBar = { showHotkeys = false, strata = "LOW", level = 35 },
}
local applied, detail = MicroBags:Apply(module, cp, {})
assertEqual(applied, true, "hidden layout apply succeeds")
assertNil(detail, "hidden layout detail")
assertNil(module._compactBackpackButton, "compact button released")
assertNil(module._compactBagSummary, "compact summary released")
assertEqual(text.text, "", "count text cleared")
assertEqual(text.shown, false, "count text hidden")
assertEqual(bagButton.shown, false, "bag button hidden by requested layout")
assertEqual(microMenu.shown, false, "micro menu hidden by requested layout")

inCombat = true
local combatApplied, combatDetail = MicroBags:Apply(module, cp, {})
assertEqual(combatApplied, false, "combat apply reports deferred failure")
assertEqual(combatDetail, "Companion micro/bag apply deferred in combat", "combat detail")
assertEqual(module._pendingAfterCombat, true, "combat retry requested")
inCombat = false

local invalid, invalidDetail = MicroBags:EnsureHooks(nil)
assertEqual(invalid, false, "missing owner rejected")
assertEqual(invalidDetail, "Companion hook owner unavailable", "missing owner detail")

print("Companion owner-state tests passed.")
