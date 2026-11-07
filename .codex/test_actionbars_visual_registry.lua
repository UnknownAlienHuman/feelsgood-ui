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

local function NewRegion(objectType)
    local region = {
        objectType = objectType or "Texture",
        alpha = 1,
        shown = true,
        points = {},
        fontCalls = 0,
        setAllPointsCalls = 0,
    }
    function region:GetObjectType() return self.objectType end
    function region:SetAlpha(value) self.alpha = value end
    function region:GetAlpha() return self.alpha end
    function region:Hide() self.shown = false end
    function region:Show() self.shown = true end
    function region:ClearAllPoints() self.points = {} end
    function region:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function region:SetAllPoints(relativeTo)
        self.setAllPointsCalls = self.setAllPointsCalls + 1
        self.points = { { "ALL", relativeTo } }
    end
    function region:SetJustifyH(value) self.justify = value end
    function region:SetDrawLayer(value) self.drawLayer = value end
    function region:SetTexCoord(...) self.texCoord = { ... } end
    function region:SetDrawEdge(value) self.drawEdge = value end
    function region:SetSwipeTexture(value) self.swipeTexture = value end
    function region:SetDrawSwipe(value) self.drawSwipe = value end
    function region:SetSwipeColor(...) self.swipeColor = { ... } end
    return region
end

local function NewTexture()
    local texture = NewRegion("Texture")
    function texture:SetColorTexture(...) self.color = { ... } end
    function texture:SetBlendMode(value) self.blendMode = value end
    return texture
end

local hotkey = NewRegion("FontString")
local count = NewRegion("FontString")
local nameRegion = NewRegion("FontString")
local timer = NewRegion("FontString")
local cooldown = NewRegion("Cooldown")
function cooldown:GetRegions() return timer end

local icon = NewTexture()
local border = NewTexture()
local flash = NewTexture()
local normalTexture = NewTexture()
local slotBackground = NewTexture()
local slotArt = NewTexture()
local defaultHighlight = NewTexture()
local defaultChecked = NewTexture()
local defaultPushed = NewTexture()

local button = {
    icon = icon,
    HotKey = hotkey,
    Count = count,
    Name = nameRegion,
    cooldown = cooldown,
    alpha = 1,
    mouseEnabled = true,
    hooks = {},
    createdTextures = 0,
}
function button:GetName() return "ActionButton1" end
function button:GetNormalTexture() return defaultPushed end
function button:GetPushedTexture() return defaultPushed end
function button:GetCheckedTexture() return defaultChecked end
function button:GetHighlightTexture() return defaultHighlight end
function button:CreateTexture()
    self.createdTextures = self.createdTextures + 1
    return NewTexture()
end
function button:GetParent() return { _fguiAutoHidden = false } end
function button:SetAlpha(value) self.alpha = value end
function button:EnableMouse(value) self.mouseEnabled = value end
function button:IsShown() return true end
function button:GetChecked() return false end
function button:HookScript(event, callback)
    self.hooks[event] = self.hooks[event] or {}
    self.hooks[event][#self.hooks[event] + 1] = callback
end

_G = _G or {}
_G.ActionButton1Icon = icon
_G.ActionButton1Border = border
_G.ActionButton1Flash = flash
_G.ActionButton1NormalTexture = normalTexture
_G.ActionButton1SlotBackground = slotBackground
_G.ActionButton1SlotArt = slotArt
_G.ActionButton1HotKey = hotkey
_G.ActionButton1Count = count
_G.ActionButton1Name = nameRegion
_G.ActionButton1Cooldown = cooldown
_G.GetActionInfo = function() return "spell" end
_G.InCombatLockdown = function() return false end

local borderCalls = 0
local fontCalls = 0
local cropCalls = 0
local ns = {
    Movers = { _unlocked = false },
    Media = {
        CreateBorder = function()
            borderCalls = borderCalls + 1
            return {}
        end,
        ApplyFont = function(region, font, size, outline)
            fontCalls = fontCalls + 1
            region.lastFont = { font, size, outline }
        end,
        ApplyIconCrop = function(region)
            cropCalls = cropCalls + 1
            region:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end,
    },
    Theme = {
        GetFontToken = function() return "FontA" end,
        GetFontOutline = function() return "OUTLINE" end,
    },
}

assert(loadfile("modules/ActionBarsState.lua"))("FeelsGoodUI", ns)
assert(loadfile("modules/ActionBarsVisuals.lua"))("FeelsGoodUI", ns)
local State = assert(ns.ActionBarsState)
local Visuals = assert(ns.ActionBarsVisuals)
local module = {}
ns.ActionBars = module
State.AttachButtonAutoHideHooks(button, module)

assertEqual(getmetatable(Visuals._regionRegistry).__mode, "k", "weak region registry")
local styleA = {
    font = "FontA",
    outline = "OUTLINE",
    hotkeySize = 10,
    countSize = 11,
    cooldownSize = 12,
    nameSize = 9,
}
assertEqual(Visuals.SkinButton(button, styleA), true, "skin button")
Visuals.SetButtonHotkey(button, false)

local buttonRecord = State.GetButtonRecord(button, false)
assertEqual(buttonRecord.skinned, true, "skinned state in registry")
assertEqual(buttonRecord.visualStyle, styleA, "style in button registry")
assertEqual(buttonRecord.showHotkeys, false, "hotkey policy in registry")
assertEqual(borderCalls, 1, "one border creation")
assertEqual(button.createdTextures, 4, "state textures created once")
assertEqual(fontCalls, 4, "hotkey/count/name/timer font applications")
assertEqual(cropCalls >= 1, true, "icon crop applied")
assertEqual(hotkey.shown, false, "hotkey hidden")

local hotkeyRecord = Visuals._regionRegistry[hotkey]
local countRecord = Visuals._regionRegistry[count]
local nameRecord = Visuals._regionRegistry[nameRegion]
local cooldownRecord = Visuals._regionRegistry[cooldown]
local timerRecord = Visuals._regionRegistry[timer]
assertEqual(hotkeyRecord.font, "FontA", "hotkey font cached")
assertEqual(countRecord.anchored, true, "count anchor cached")
assertEqual(nameRecord.anchored, true, "name anchor cached")
assertEqual(cooldownRecord.anchored, true, "cooldown anchor cached")
assertEqual(cooldownRecord.timerText, timer, "timer cached on cooldown record")
assertEqual(timerRecord.anchored, true, "timer anchor cached")

local forbiddenButton = {
    "_fguiSkinned",
    "_fguiVisualStyle",
    "_fguiShowHotkeys",
    "__fguiUpdateChecked",
    "__fguiUpdateEmpty",
}
for i = 1, #forbiddenButton do
    assertNil(rawget(button, forbiddenButton[i]), "button marker " .. forbiddenButton[i])
end
for _, region in ipairs({ hotkey, count, nameRegion, cooldown, timer }) do
    assertNil(rawget(region, "_fguiFont"), "region font marker")
    assertNil(rawget(region, "_fguiSize"), "region size marker")
    assertNil(rawget(region, "_fguiOutline"), "region outline marker")
    assertNil(rawget(region, "_fguiAnchored"), "region anchor marker")
    assertNil(rawget(region, "_fguiTimerText"), "region timer marker")
end

-- Repeated refresh reuses all records, layers, anchors and border.
assertEqual(Visuals.RefreshButtonVisualState(button, styleA, false), true, "repeat refresh")
assertEqual(borderCalls, 1, "repeat refresh creates no border")
assertEqual(button.createdTextures, 4, "repeat refresh creates no state textures")
assertEqual(fontCalls, 4, "identical style does not reapply fonts")
assertEqual(hotkeyRecord, Visuals._regionRegistry[hotkey], "hotkey record reused")
assertEqual(cooldownRecord.timerText, timer, "timer cache reused")

local styleB = {
    font = "FontB",
    outline = "THICKOUTLINE",
    hotkeySize = 12,
    countSize = 13,
    cooldownSize = 14,
    nameSize = 11,
}
assertEqual(Visuals.RefreshButtonVisualState(button, styleB, true), true, "style refresh")
assertEqual(buttonRecord.visualStyle, styleB, "new style stored")
assertEqual(buttonRecord.showHotkeys, true, "new hotkey policy stored")
assertEqual(fontCalls, 8, "new style reapplies four fonts")
assertEqual(hotkey.shown, true, "hotkey shown")
assertEqual(hotkey.lastFont[1], "FontB", "new hotkey font")
assertEqual(timer.lastFont[2], 14, "new cooldown font size")

print("ActionBars visual registry tests passed.")
