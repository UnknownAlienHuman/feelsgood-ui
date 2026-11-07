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

local function NewButton(name)
    local button = {
        name = name,
        hooks = {},
        scripts = {},
        hidden = false,
    }
    function button:HookScript(event, callback)
        self.hooks[event] = self.hooks[event] or {}
        self.hooks[event][#self.hooks[event] + 1] = callback
    end
    function button:SetScript(event, callback)
        self.scripts[event] = callback
    end
    function button:Fire(event)
        for i = 1, #(self.hooks[event] or {}) do
            self.hooks[event][i](self)
        end
    end
    return button
end

local buttonA = NewButton("A")
local buttonB = NewButton("B")
local buttonC = NewButton("C")
local currentButton = buttonA
local registeredDb
local registerCalls = 0
local refreshCalls = 0
local showCalls = 0
local hideCalls = 0

local fakeLDBIcon = {}
function fakeLDBIcon:Register(name, object, db)
    registerCalls = registerCalls + 1
    registeredDb = db
    currentButton.db = db
end
function fakeLDBIcon:Refresh(name, db)
    refreshCalls = refreshCalls + 1
    registeredDb = db
    currentButton.db = db
end
function fakeLDBIcon:GetMinimapButton(name)
    return currentButton
end
function fakeLDBIcon:Show(name)
    showCalls = showCalls + 1
    currentButton.hidden = false
end
function fakeLDBIcon:Hide(name)
    hideCalls = hideCalls + 1
    currentButton.hidden = true
end

local fakeLDB = {}
function fakeLDB:NewDataObject(name, object)
    object.name = name
    return object
end

_G = _G or {}
_G.LibStub = function(name)
    if name == "LibDataBroker-1.1" then return fakeLDB end
    if name == "LibDBIcon-1.0" then return fakeLDBIcon end
    return nil
end

local cfg = {
    hide = false,
    minimapPos = 220,
}
local writes = 0
local applyRequests = 0
local lastRule
local settings = {}
function settings:SetTx(applyKey, path, value, rule, panelKey)
    lastRule = rule
    local key = path[#path]
    if cfg[key] == value then return false, value end
    cfg[key] = value
    writes = writes + 1
    return true, value
end
function settings:BeginPanelUndoBatch() return true end
function settings:EndPanelUndoBatch() return true end

local errors = {}
local ns = {
    DB = {
        ReadSection = function(_, section)
            if section == "minimap" then return cfg end
            return nil
        end,
    },
    Settings = settings,
    Apply = {
        Request = function(_, key)
            assertEqual(key, "minimap", "apply key")
            applyRequests = applyRequests + 1
            return true
        end,
    },
    Log = {
        Debug = function() end,
        Warn = function() end,
        Error = function(_, message) errors[#errors + 1] = message end,
    },
    MinimapIconActions = {
        AttachDataObject = function() end,
    },
}

assert(loadfile("core/MinimapIcon.lua"))("FeelsGoodUI", ns)
local MinimapIcon = assert(ns.MinimapIcon)
assertEqual(getmetatable(MinimapIcon._dragHookRegistry).__mode, "k", "weak drag-hook registry")

assertEqual(MinimapIcon:Attach(), true, "initial attach")
assertEqual(registerCalls, 1, "registered once")
assertEqual(registeredDb ~= cfg, true, "detached runtime config")
assertEqual(#buttonA.hooks.OnDragStart, 1, "A one drag-start hook")
assertEqual(#buttonA.hooks.OnDragStop, 1, "A one drag-stop hook")
assertEqual(MinimapIcon._dragHookRegistry[buttonA].startHooked, true, "A start hook owned in registry")
assertEqual(MinimapIcon._dragHookRegistry[buttonA].stopHooked, true, "A stop hook owned in registry")
assertNil(rawget(buttonA, "_fguiTransactionalDragHooked"), "A has no foreign marker")

assertEqual(MinimapIcon:Attach(), true, "repeat attach")
assertEqual(registerCalls, 1, "repeat attach does not register")
assertEqual(#buttonA.hooks.OnDragStart, 1, "A start hook not duplicated")
assertEqual(#buttonA.hooks.OnDragStop, 1, "A stop hook not duplicated")

-- LibDBIcon may replace its button object. The new object gets its own registry
-- entry while the old permanent hooks become harmless through exact-owner checks.
currentButton = buttonB
assertEqual(MinimapIcon:ApplyConfig(), true, "apply after button replacement")
assertEqual(#buttonB.hooks.OnDragStart, 1, "B one drag-start hook")
assertEqual(#buttonB.hooks.OnDragStop, 1, "B one drag-stop hook")
assertEqual(type(MinimapIcon._dragHookRegistry[buttonB]), "table", "B registry record")
assertNil(rawget(buttonB, "_fguiTransactionalDragHooked"), "B has no foreign marker")

buttonA:Fire("OnDragStart")
buttonB:Fire("OnDragStart")
registeredDb.minimapPos = 142.6
buttonA:Fire("OnDragStop")
assertEqual(writes, 0, "stale A stop is inert")
assertEqual(applyRequests, 0, "stale A stop requests no apply")
buttonB:Fire("OnDragStop")
assertEqual(writes, 1, "B terminal drag writes once")
assertEqual(applyRequests, 1, "B terminal drag applies once")
assertEqual(cfg.minimapPos, 143, "B position normalized")
assertEqual(lastRule.type, "int", "drag position integer rule")

-- Active drag blocks unrelated runtime apply until the owning button stops or
-- detach cancels it.
buttonB:Fire("OnDragStart")
local applyOK, applyDetail = MinimapIcon:ApplyConfig()
assertEqual(applyOK, false, "apply blocked during drag")
assertEqual(applyDetail, "Minimap apply blocked while icon drag is active", "drag apply detail")
registeredDb.minimapPos = 300
buttonB.scripts.OnUpdate = function() end
currentButton = buttonC
assertEqual(MinimapIcon:Detach(), true, "detach active B drag")
assertNil(buttonB.scripts.OnUpdate, "detach clears exact B OnUpdate")
assertEqual(registeredDb.minimapPos, 143, "detach restores persisted proxy position")
assertEqual(cfg.minimapPos, 143, "detach does not commit preview")
assertEqual(writes, 1, "detach creates no write")
assertEqual(currentButton.hidden, true, "current LibDBIcon button hidden")

buttonB:Fire("OnDragStop")
assertEqual(writes, 1, "stale B stop after detach is inert")
assertEqual(applyRequests, 1, "stale B stop requests no apply")

-- Reattach hooks the current replacement exactly once and normal apply resumes.
assertEqual(MinimapIcon:Attach(), true, "reattach C")
assertEqual(#buttonC.hooks.OnDragStart, 1, "C one drag-start hook")
assertEqual(#buttonC.hooks.OnDragStop, 1, "C one drag-stop hook")
assertEqual(MinimapIcon:ApplyConfig(), true, "apply after detach")
assertEqual(#buttonC.hooks.OnDragStart, 1, "C start hook not duplicated")
assertEqual(#buttonC.hooks.OnDragStop, 1, "C stop hook not duplicated")
assertNil(rawget(buttonC, "_fguiTransactionalDragHooked"), "C has no foreign marker")
assertEqual(#errors, 0, "no minimap hook errors")
assertEqual(refreshCalls >= 4, true, "runtime proxy refreshed")
assertEqual(showCalls >= 2, true, "visible icon shown")
assertEqual(hideCalls >= 1, true, "detach hides icon")

print("Minimap hook registry tests passed.")
