-- FeelsGoodUI: shared lifecycle owner for feature modules
local _, ns = ...

local Lifecycle = ns.Lifecycle or {}
ns.Lifecycle = Lifecycle

Lifecycle._modules = Lifecycle._modules or {}
Lifecycle._order = Lifecycle._order or {}

local EMPTY_SPEC = {}

local function EnsureState(module)
    local state = rawget(module, "_lifecycleState")
    if type(state) ~= "table" then
        state = {
            attached = false,
            enabled = false,
            generation = 0,
        }
        module._lifecycleState = state
    end
    return state
end

local function GetSpec(module)
    local spec = rawget(module, "_lifecycleSpec")
    return type(spec) == "table" and spec or EMPTY_SPEC
end

local function ErrorHandler(err)
    local message = tostring(err or "unknown lifecycle error")
    if type(_G) == "table" and type(_G.debugstack) == "function" then
        message = message .. "\n" .. _G.debugstack(3, 20, 20)
    end
    return message
end

local function ResolveMethod(module, key)
    if type(key) == "function" then
        return key
    end
    if type(key) == "string" and type(module[key]) == "function" then
        return module[key]
    end
    return nil
end

local function Invoke(module, key, phase)
    local fn = ResolveMethod(module, key)
    if not fn then
        return false, "Missing lifecycle " .. tostring(phase) .. " method: " .. tostring(key)
    end

    local ok, result, detail = xpcall(function()
        return fn(module)
    end, ErrorHandler)

    if not ok then
        return false, result
    end
    if result == false then
        return false, detail
    end
    return true, detail
end

local function ResolveAttachKey(module, spec)
    local key = spec.attach
    if ResolveMethod(module, key) then
        return key
    end

    local initKey = spec.init or "Init"
    if ResolveMethod(module, initKey) then
        return initKey
    end

    if ResolveMethod(module, "Attach") then
        return "Attach"
    end
    return nil
end

local function ResolveDetachKey(module, spec)
    local key = spec.detach
    if ResolveMethod(module, key) then
        return key
    end
    if ResolveMethod(module, "Detach") then
        return "Detach"
    end
    return nil
end

local function ResolveApplyKey(module, spec)
    if spec.apply == false then
        return false
    end
    local key = spec.apply or "ApplyConfig"
    if ResolveMethod(module, key) then
        return key
    end
    return nil
end

local function BeginTransition(state, transition)
    if state.transition then
        return false, "Lifecycle transition already active: " .. tostring(state.transition)
    end
    state.generation = (tonumber(state.generation) or 0) + 1
    state.transition = transition
    return true
end

local function FinishTransition(state, success, detail)
    state.transition = nil
    state.lastError = success and nil or detail
    return success, detail
end

local function DetachModule(module, state, spec)
    local key = ResolveDetachKey(module, spec)
    if not key then
        return false, "Missing lifecycle detach method"
    end

    local ok, detail = Invoke(module, key, "detach")
    if ok or module._detached == true then
        state.attached = false
        state.enabled = false
        return true, detail
    end
    return false, detail
end

local function CleanupFailedAttach(module, state, spec)
    local key = ResolveDetachKey(module, spec)
    if not key then
        state.attached = false
        state.enabled = false
        return true
    end

    local ok = Invoke(module, key, "attach cleanup")
    state.attached = not (ok or module._detached == true)
    state.enabled = false
    return not state.attached
end

local function InjectControlMethods(name, module)
    if type(module.Enable) ~= "function" then
        function module:Enable()
            return Lifecycle:Enable(name)
        end
        module._lifecycleInjectedEnable = true
    end

    if type(module.Disable) ~= "function" then
        function module:Disable()
            return Lifecycle:Disable(name)
        end
        module._lifecycleInjectedDisable = true
    end
end

function Lifecycle:RegisterModule(name, module, spec)
    if type(name) ~= "string" or name == "" or type(module) ~= "table" then
        return module
    end

    local entry = self._modules[name]
    if entry then
        entry.module = module
        entry.spec = spec or EMPTY_SPEC
    else
        entry = {
            module = module,
            spec = spec or EMPTY_SPEC,
        }
        self._modules[name] = entry
        self._order[#self._order + 1] = name
    end

    module._lifecycleName = name
    module._lifecycleSpec = entry.spec
    EnsureState(module)
    InjectControlMethods(name, module)
    return module
end

function Lifecycle:GetModule(name)
    local entry = self._modules[name]
    return entry and entry.module or nil
end

function Lifecycle:GetState(name)
    local module = self:GetModule(name)
    if not module then return nil end
    return EnsureState(module)
end

function Lifecycle:IsEnabled(name)
    local state = self:GetState(name)
    return state and state.enabled == true or false
end

function Lifecycle:Enable(name)
    local module = self:GetModule(name)
    if not module then
        return false, "Unknown lifecycle module: " .. tostring(name)
    end

    local state = EnsureState(module)
    if state.enabled then
        return true
    end

    local started, detail = BeginTransition(state, "enable")
    if not started then
        return false, detail
    end

    local spec = GetSpec(module)
    local attachedBefore = state.attached == true

    if not attachedBefore then
        local attachKey = ResolveAttachKey(module, spec)
        if not attachKey then
            return FinishTransition(state, false, "Missing lifecycle attach/init method")
        end

        local attached, attachDetail = Invoke(module, attachKey, "attach")
        if not attached then
            CleanupFailedAttach(module, state, spec)
            return FinishTransition(state, false, attachDetail)
        end
        state.attached = true
    end

    local applyKey = ResolveApplyKey(module, spec)
    if applyKey == nil then
        if not attachedBefore then
            CleanupFailedAttach(module, state, spec)
        end
        return FinishTransition(state, false, "Missing lifecycle apply method")
    end

    if applyKey ~= false then
        local applied, applyDetail = Invoke(module, applyKey, "apply")
        if not applied then
            if not attachedBefore then
                CleanupFailedAttach(module, state, spec)
            end
            return FinishTransition(state, false, applyDetail)
        end
    end

    state.enabled = true
    state.attached = true
    return FinishTransition(state, true)
end

function Lifecycle:Disable(name)
    local module = self:GetModule(name)
    if not module then
        return false, "Unknown lifecycle module: " .. tostring(name)
    end

    local state = EnsureState(module)
    if not state.enabled and not state.attached then
        return true
    end

    local started, detail = BeginTransition(state, "disable")
    if not started then
        return false, detail
    end

    local detached, detachDetail = DetachModule(module, state, GetSpec(module))
    if not detached then
        return FinishTransition(state, false, detachDetail)
    end

    return FinishTransition(state, true, detachDetail)
end

function Lifecycle:EnableAll(order)
    local list = order or self._order
    if type(list) ~= "table" then
        return false, { { name = "<order>", detail = "Invalid lifecycle order" } }
    end

    local failures = {}
    for i = 1, #list do
        local name = list[i]
        local ok, detail = self:Enable(name)
        if not ok then
            failures[#failures + 1] = { name = name, detail = detail }
        end
    end

    return #failures == 0, failures
end

function Lifecycle:DisableAll(order)
    local list = order or self._order
    if type(list) ~= "table" then
        return false, { { name = "<order>", detail = "Invalid lifecycle order" } }
    end

    local failures = {}
    for i = #list, 1, -1 do
        local name = list[i]
        local ok, detail = self:Disable(name)
        if not ok then
            failures[#failures + 1] = { name = name, detail = detail }
        end
    end

    return #failures == 0, failures
end

return Lifecycle
