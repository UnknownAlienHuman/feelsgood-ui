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

local function HookCount(target, event)
    return #(target.hooks[event] or {})
end

local function Fire(target, event, ...)
    for i = 1, #(target.hooks[event] or {}) do
        target.hooks[event][i](target, ...)
    end
end

local function NewTexture()
    local texture = { shown = false }
    function texture:SetAllPoints() end
    function texture:SetColorTexture() end
    function texture:SetBlendMode() end
    function texture:Show() self.shown = true end
    function texture:Hide() self.shown = false end
    function texture:SetAlpha(value) self.alpha = value end
    return texture
end

local function NewButton(parent, failures)
    local button = {
        hooks = {},
        failures = failures or {},
        attempts = {},
        parent = parent,
        action = 1,
        alpha = 1,
        mouseEnabled = true,
        createCalls = 0,
        shown = true,
    }

    function button:HookScript(event, callback)
        self.attempts[event] = (self.attempts[event] or 0) + 1
        local remaining = tonumber(self.failures[event]) or 0
        if remaining > 0 then
            self.failures[event] = remaining - 1
            error("injected " .. event .. " failure")
        end
        self.hooks[event] = self.hooks[event] or {}
        self.hooks[event][#self.hooks[event] + 1] = callback
    end

    function button:CreateTexture()
        self.createCalls = self.createCalls + 1
        return NewTexture()
    end
    function button:GetParent() return self.parent end
    function button:GetAttribute() return self.action end
    function button:GetChecked() return false end
    function button:GetHighlightTexture() return nil end
    function button:GetCheckedTexture() return nil end
    function button:GetPushedTexture() return nil end
    function button:SetAlpha(value) self.alpha = value end
    function button:EnableMouse(enabled) self.mouseEnabled = enabled == true end
    function button:IsShown() return self.shown end

    return button
end

local function NewHolder(failures)
    local holder = {
        hooks = {},
        failures = failures or {},
        attempts = {},
        buttons = {},
        alpha = 1,
        mouseEnabled = true,
        shown = true,
        _maxButtons = 12,
    }

    function holder:HookScript(event, callback)
        self.attempts[event] = (self.attempts[event] or 0) + 1
        local remaining = tonumber(self.failures[event]) or 0
        if remaining > 0 then
            self.failures[event] = remaining - 1
            error("injected holder " .. event .. " failure")
        end
        self.hooks[event] = self.hooks[event] or {}
        self.hooks[event][#self.hooks[event] + 1] = callback
    end
    function holder:SetAlpha(value) self.alpha = value end
    function holder:EnableMouse(enabled) self.mouseEnabled = enabled == true end
    function holder:IsShown() return self.shown end
    function holder:IsMouseOver() return false end

    return holder
end

_G = _G or {}
_G.InCombatLockdown = function() return false end
_G.GetActionInfo = function() return "spell" end
_G.C_Timer = nil

local ns = {
    Movers = { _unlocked = false },
}
assert(loadfile("modules/ActionBarsState.lua"))("FeelsGoodUI", ns)
local State = assert(ns.ActionBarsState)

assertEqual(getmetatable(State._buttonRegistry).__mode, "k", "button registry mode")
assertEqual(getmetatable(State._holderRegistry).__mode, "k", "holder registry mode")

local holder = NewHolder({ OnLeave = 1 })
local button = NewButton(holder, { OnEnter = 1 })
holder.buttons[1] = button
local buttonRecord = State.GetButtonRecord(button, true)
buttonRecord.skinned = true
buttonRecord.module = { _detached = false }

local ok, detail = State.InitializeButton(button)
assertEqual(ok, false, "partial state-layer initialization fails")
assertEqual(type(detail), "string", "partial state-layer detail")
assertEqual(button.createCalls, 4, "slot and three state textures allocated once")
assertEqual(HookCount(button, "OnEnter"), 0, "failed state enter edge unpublished")
assertEqual(HookCount(button, "OnLeave"), 1, "successful state leave edge published")
assertEqual(buttonRecord.stateLayers, false, "summary remains false after partial failure")

ok = State.InitializeButton(button)
assertEqual(ok, true, "state-layer retry succeeds")
assertEqual(button.createCalls, 4, "retry reuses existing textures")
assertEqual(HookCount(button, "OnEnter"), 1, "missing state enter edge installed once")
assertEqual(HookCount(button, "OnLeave"), 1, "successful state leave edge not duplicated")
assertEqual(buttonRecord.stateLayers, true, "summary published after every edge succeeds")
assertNil(rawget(button, "_fguiStateHooks"), "button state marker absent")

assertEqual(State.InitializeButton(button), true, "repeated initialization succeeds")
assertEqual(button.createCalls, 4, "repeated initialization allocates nothing")
assertEqual(HookCount(button, "OnEnter"), 1, "repeated initialization keeps one enter hook")
assertEqual(HookCount(button, "OnLeave"), 1, "repeated initialization keeps one leave hook")
Fire(button, "OnEnter")
assertEqual(buttonRecord.layers.highlight.shown, true, "state enter shows highlight")
Fire(button, "OnLeave")
assertEqual(buttonRecord.layers.highlight.shown, false, "state leave hides highlight")

-- Button auto-hide edges publish independently and resolve the current record owner.
local autoButton = NewButton(holder, { OnEnter = 1 })
local moduleA = { _detached = false }
local moduleB = { _detached = false }
ok, detail = State.AttachButtonAutoHideHooks(autoButton, moduleA)
assertEqual(ok, false, "partial button auto-hide registration fails")
assertEqual(HookCount(autoButton, "OnEnter"), 0, "failed button enter edge unpublished")
assertEqual(HookCount(autoButton, "OnLeave"), 1, "successful button leave edge published")

ok = State.AttachButtonAutoHideHooks(autoButton, moduleA)
assertEqual(ok, true, "button auto-hide retry succeeds")
assertEqual(HookCount(autoButton, "OnEnter"), 1, "missing button edge installed once")
assertEqual(HookCount(autoButton, "OnLeave"), 1, "successful button edge not duplicated")
assertEqual(autoButton.attempts.OnEnter, 2, "failed button edge retried once")
assertEqual(autoButton.attempts.OnLeave, 1, "successful button edge not retried")
assertNil(rawget(autoButton, "_fguiAutoHideHooks"), "button auto-hide marker absent")

assertEqual(State.AttachButtonAutoHideHooks(autoButton, moduleB), true, "button owner replacement succeeds")
assertEqual(HookCount(autoButton, "OnEnter"), 1, "owner replacement reuses button enter hook")
assertEqual(HookCount(autoButton, "OnLeave"), 1, "owner replacement reuses button leave hook")
local queuedOwners = {}
State.QueueAutoHideUpdate = function(owner)
    queuedOwners[#queuedOwners + 1] = owner
end
Fire(autoButton, "OnEnter")
assertEqual(queuedOwners[#queuedOwners], moduleB, "button callback resolves current owner")

-- Holder edges use the same result-bearing contract without holder metadata.
function moduleA:_ForEachHolder(callback) callback(holder, 1) end
function moduleB:_ForEachHolder(callback) callback(holder, 1) end
ok, detail = State.EnsureAutoHideHooks(moduleA)
assertEqual(ok, false, "partial holder registration fails")
assertEqual(HookCount(holder, "OnEnter"), 1, "holder enter edge published")
assertEqual(HookCount(holder, "OnLeave"), 0, "failed holder leave edge unpublished")
assertEqual(State.GetHolderRecord(holder, false).autoHideHooks, false, "holder summary remains false")

ok = State.EnsureAutoHideHooks(moduleA)
assertEqual(ok, true, "holder retry succeeds")
assertEqual(HookCount(holder, "OnEnter"), 1, "holder enter edge not duplicated")
assertEqual(HookCount(holder, "OnLeave"), 1, "missing holder leave edge installed once")
assertEqual(holder.attempts.OnEnter, 1, "successful holder edge not retried")
assertEqual(holder.attempts.OnLeave, 2, "failed holder edge retried once")
assertNil(rawget(holder, "_fguiAutoHideHooks"), "holder hook marker absent")
assertNil(rawget(holder, "_fguiAutoHidden"), "holder hidden marker absent")

assertEqual(State.EnsureAutoHideHooks(moduleB), true, "holder owner replacement succeeds")
assertEqual(HookCount(holder, "OnEnter"), 1, "holder replacement reuses enter hook")
assertEqual(HookCount(holder, "OnLeave"), 1, "holder replacement reuses leave hook")
Fire(holder, "OnLeave")
assertEqual(queuedOwners[#queuedOwners], moduleB, "holder callback resolves current owner")

assertEqual(State.SetHolderAutoHidden(holder, true), true, "holder hidden state applies")
assertEqual(State.GetHolderRecord(holder, false).autoHidden, true, "holder hidden state stored in registry")
assertEqual(holder.alpha, 0, "holder alpha hidden")
assertNil(rawget(holder, "_fguiAutoHidden"), "holder remains marker-free")

-- Empty-slot update reads the registry-owned holder state.
buttonRecord.module = moduleB
State.UpdateButtonEmpty(button)
assertEqual(button.mouseEnabled, false, "hidden holder disables button mouse")
assertEqual(State.SetHolderAutoHidden(holder, false), true, "holder shown state applies")
State.UpdateButtonEmpty(button)
assertEqual(button.mouseEnabled, true, "shown holder enables button mouse")

print("ActionBars hook ownership tests passed.")
