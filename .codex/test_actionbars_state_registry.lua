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

local function NewTexture()
    local texture = { shown = false, alpha = 1 }
    function texture:SetAllPoints() end
    function texture:SetColorTexture() end
    function texture:SetBlendMode() end
    function texture:Show() self.shown = true end
    function texture:Hide() self.shown = false end
    function texture:SetAlpha(value) self.alpha = value end
    return texture
end

local holder = { _fguiAutoHidden = false }
local button = {
    action = 1,
    showgrid = 0,
    alpha = 1,
    mouseEnabled = true,
    checked = false,
    hooks = {},
    texturesCreated = 0,
}
function button:CreateTexture()
    self.texturesCreated = self.texturesCreated + 1
    return NewTexture()
end
function button:GetHighlightTexture() return self.defaultHighlight end
function button:GetCheckedTexture() return self.defaultChecked end
function button:GetPushedTexture() return self.defaultPushed end
function button:GetChecked() return self.checked end
function button:GetParent() return holder end
function button:SetAlpha(value) self.alpha = value end
function button:EnableMouse(value) self.mouseEnabled = value end
function button:IsShown() return true end
function button:HookScript(name, callback)
    self.hooks[name] = self.hooks[name] or {}
    self.hooks[name][#self.hooks[name] + 1] = callback
end
button.defaultHighlight = NewTexture()
button.defaultChecked = NewTexture()
button.defaultPushed = NewTexture()

_G = _G or {}
_G.GetActionInfo = function(action)
    return action == 1 and "spell" or nil
end
_G.InCombatLockdown = function() return false end
_G.C_Timer = { After = function(_, callback) callback() end }

local module = {
    _detached = nil,
    _autoHideEnabled = false,
}
local movers = { _unlocked = false }
local ns = { Movers = movers, ActionBars = module }
assert(loadfile("modules/ActionBarsState.lua"))("FeelsGoodUI", ns)
local State = assert(ns.ActionBarsState)

assertEqual(getmetatable(State._buttonRegistry).__mode, "k", "weak button registry")
local record = State.GetButtonRecord(button, true)
record.skinned = true
assertEqual(State.AttachButtonAutoHideHooks(button, module), true, "attach button owner")
assertEqual(record.module, module, "module stored in registry")
assertEqual(State.InitializeButton(button), true, "initialize button")
assertEqual(State.IsManagedButton(button), true, "managed button")
assertEqual(button.texturesCreated, 4, "three state layers plus slot background")
assertEqual(type(record.layers.highlight), "table", "highlight layer in registry")
assertEqual(type(record.layers.checked), "table", "checked layer in registry")
assertEqual(type(record.layers.pressed), "table", "pressed layer in registry")
assertEqual(type(record.slotBackground), "table", "slot background in registry")

local forbidden = {
    "__fguiStateLayers",
    "__fguiHL",
    "__fguiCK",
    "__fguiPR",
    "__fguiSlotBG",
    "__fguiUpdateChecked",
    "__fguiUpdateEmpty",
    "_fguiSkinned",
    "_fguiModule",
    "_fguiAutoHideHooks",
}
for i = 1, #forbidden do
    assertNil(rawget(button, forbidden[i]), "button marker " .. forbidden[i])
end

assertEqual(#button.hooks.OnEnter, 2, "state and auto-hide OnEnter hooks")
assertEqual(#button.hooks.OnLeave, 2, "state and auto-hide OnLeave hooks")
assertEqual(record.autoHideHooks, true, "auto-hide hook state in registry")
assertEqual(record.stateLayers, true, "state-layer state in registry")

-- Checked state is resolved through the registry layer.
button.checked = true
State.UpdateButtonChecked(button)
assertEqual(record.layers.checked.shown, true, "checked layer shown")
button.checked = false
State.UpdateButtonChecked(button)
assertEqual(record.layers.checked.shown, false, "checked layer hidden")

-- Empty-slot state uses the registry background and owner pointer.
button.action = 0
movers._unlocked = false
State.UpdateButtonEmpty(button)
assertEqual(button.alpha, 0, "hidden empty slot")
assertEqual(button.mouseEnabled, false, "hidden empty slot mouse")
assertEqual(record.slotBackground.shown, false, "empty background hidden")

movers._unlocked = true
State.UpdateButtonEmpty(button)
assertEqual(button.alpha, 0.35, "editor empty-slot alpha")
assertEqual(button.mouseEnabled, true, "editor empty-slot mouse")
assertEqual(record.slotBackground.shown, true, "editor empty background shown")

button.action = 1
State.UpdateButtonEmpty(button)
assertEqual(button.alpha, 1, "occupied slot alpha")
assertEqual(record.slotBackground.shown, false, "occupied background hidden")

-- Permanent hover hooks resolve the current owner/layer from the registry.
record.layers.highlight:Hide()
button.hooks.OnEnter[1](button)
assertEqual(record.layers.highlight.shown, true, "highlight shown while attached")
button.hooks.OnLeave[1](button)
assertEqual(record.layers.highlight.shown, false, "highlight hidden on leave")
module._detached = true
button.hooks.OnEnter[1](button)
assertEqual(record.layers.highlight.shown, false, "detached highlight hook inert")
module._detached = nil

-- Reinitialization reuses the same records and textures.
assertEqual(State.AttachButtonAutoHideHooks(button, module), true, "repeat attach")
assertEqual(State.InitializeButton(button), true, "repeat initialize")
assertEqual(button.texturesCreated, 4, "repeat initialization allocates nothing")
assertEqual(#button.hooks.OnEnter, 2, "repeat attach adds no hook")

print("ActionBars state registry tests passed.")
