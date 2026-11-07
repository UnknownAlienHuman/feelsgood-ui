local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local button = { hooks = {}, scripts = {} }
function button:HookScript(name, fn)
    self.hooks[name] = self.hooks[name] or {}
    self.hooks[name][#self.hooks[name] + 1] = fn
end
function button:SetScript(name, fn)
    self.scripts[name] = fn
end

local registeredDb
local refreshCount = 0
local hidden = false
local fakeLDBIcon = {}
function fakeLDBIcon:Register(_, _, db)
    registeredDb = db
    button.db = db
end
function fakeLDBIcon:Refresh(_, db)
    refreshCount = refreshCount + 1
    registeredDb = db
    button.db = db
end
function fakeLDBIcon:GetMinimapButton()
    return button
end
function fakeLDBIcon:Hide()
    hidden = true
end
function fakeLDBIcon:Show()
    hidden = false
end

local fakeLDB = {}
function fakeLDB:NewDataObject(_, data)
    return data
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
    radius = 80,
    angle = 44,
}
local applyRequests = 0
local changedWrites = 0
local setCalls = 0
local lastRule
local settings = {}
function settings:SetTx(_, path, value, rule)
    setCalls = setCalls + 1
    lastRule = rule
    local key = path[#path]
    local old = cfg[key]
    if old == value then
        return false, value
    end
    cfg[key] = value
    changedWrites = changedWrites + 1
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
        Request = function()
            applyRequests = applyRequests + 1
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
local icon = assert(ns.MinimapIcon)
assert(icon:Attach() == true)
assert(registeredDb ~= cfg, "LibDBIcon must receive a detached runtime proxy")
assertEqual(registeredDb.minimapPos, 220, "initial proxy position")
assertEqual(registeredDb.radius, nil, "dead radius excluded from proxy")
assertEqual(#button.hooks.OnDragStart, 1, "one drag-start hook")
assertEqual(#button.hooks.OnDragStop, 1, "one drag-stop hook")

local function Fire(name)
    for i = 1, #(button.hooks[name] or {}) do
        button.hooks[name][i](button)
    end
end

-- Per-frame LibDBIcon writes stay on the proxy until terminal drag stop.
Fire("OnDragStart")
registeredDb.minimapPos = 137.6
assertEqual(cfg.minimapPos, 220, "drag preview does not touch profile")
assertEqual(changedWrites, 0, "drag preview creates no write")
Fire("OnDragStop")
assertEqual(cfg.minimapPos, 138, "terminal drag position normalized")
assertEqual(changedWrites, 1, "one terminal write")
assertEqual(applyRequests, 1, "one terminal apply request")
assertEqual(lastRule.type, "int", "position stored as integer")

-- Apply and rollback always reconcile the same proxy instead of replacing it.
assert(icon:ApplyConfig() == true)
assertEqual(button.db, registeredDb, "refresh retains runtime proxy identity")
assertEqual(registeredDb.minimapPos, 138, "applied proxy position")
cfg.minimapPos = 220
assert(icon:ApplyConfig() == true)
assertEqual(registeredDb.minimapPos, 220, "rollback restores persisted position")

-- A rounded no-op invokes no Settings transaction and no Apply request.
local writesBefore = changedWrites
local appliesBefore = applyRequests
Fire("OnDragStart")
registeredDb.minimapPos = 220.4
Fire("OnDragStop")
assertEqual(changedWrites, writesBefore, "no-op drag creates no changed write")
assertEqual(applyRequests, appliesBefore, "no-op drag creates no apply request")
assertEqual(registeredDb.minimapPos, 220, "no-op drag reconciles proxy")

-- Missing write owner fails closed and restores persisted presentation.
settings.SetTx = nil
Fire("OnDragStart")
registeredDb.minimapPos = 300
Fire("OnDragStop")
assertEqual(cfg.minimapPos, 220, "missing writer leaves profile unchanged")
assertEqual(registeredDb.minimapPos, 220, "missing writer restores proxy")
assertEqual(applyRequests, appliesBefore, "missing writer requests no apply")

-- Detach cancels active library OnUpdate and discards the preview.
settings.SetTx = function(self, _, path, value, rule)
    setCalls = setCalls + 1
    lastRule = rule
    local key = path[#path]
    local old = cfg[key]
    if old == value then return false, value end
    cfg[key] = value
    changedWrites = changedWrites + 1
    return true, value
end
Fire("OnDragStart")
registeredDb.minimapPos = 310
button.scripts.OnUpdate = function() end
assert(icon:Detach() == true)
assertEqual(button.scripts.OnUpdate, nil, "detach cancels drag OnUpdate")
assertEqual(cfg.minimapPos, 220, "detach does not commit preview")
assertEqual(registeredDb.minimapPos, 220, "detach restores proxy")
assertEqual(hidden, true, "detach hides icon")

-- Reattach refreshes the proxy without stacking permanent hooks.
assert(icon:Attach() == true)
assertEqual(#button.hooks.OnDragStart, 1, "reattach keeps one drag-start hook")
assertEqual(#button.hooks.OnDragStop, 1, "reattach keeps one drag-stop hook")
assertEqual(#errors, 0, "no drag errors")
assert(refreshCount >= 4)
assert(setCalls >= 2)

print("Minimap transactional drag tests passed.")
