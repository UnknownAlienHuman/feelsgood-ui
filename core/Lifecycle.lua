-- FeelsGoodUI: shared lifecycle helper for feature modules.
--
-- Narrow Phase 1 slice:
--  - keep current module internals intact;
--  - expose a stable Attach/Enable/Disable/Detach surface;
--  - let bootstrap wire modules through one registry instead of hand-written calls.

local _, ns = ...

local Lifecycle = ns.Lifecycle or {}
ns.Lifecycle = Lifecycle

Lifecycle._modules = Lifecycle._modules or {}
Lifecycle._order = Lifecycle._order or {}

local EMPTY_SPEC = {}

local function EnsureState(module)
    local state = rawget(module, "_lifecycleState")
    if type(state) ~= "table" then
        state = {}
        module._lifecycleState = state
    end
    return state
end

local function GetSpec(module)
    local spec = rawget(module, "_lifecycleSpec")
    if type(spec) == "table" then
        return spec
    end
    return EMPTY_SPEC
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

local function CallModuleMethod(module, key)
    local fn = ResolveMethod(module, key)
    if fn then
        return fn(module)
    end
    return nil
end

local function InjectLifecycleMethods(module)
    if type(module.Attach) ~= "function" then
        function module:Attach()
            local state = EnsureState(self)
            if state.attached then
                return true
            end

            local spec = GetSpec(self)
            CallModuleMethod(self, spec.attach or spec.init or "Init")
            state.attached = true
            return true
        end
    end

    if type(module.Detach) ~= "function" then
        function module:Detach()
            local spec = GetSpec(self)
            if not spec.detach then
                return false
            end

            CallModuleMethod(self, spec.detach)
            local state = EnsureState(self)
            state.attached = false
            return true
        end
    end

    if type(module.Enable) ~= "function" then
        function module:Enable()
            local state = EnsureState(self)
            if state.enabled then
                return true
            end

            local attached = self:Attach()
            if attached == false then
                state.attached = false
                return false
            end
            state.attached = true

            local spec = GetSpec(self)
            if spec.apply ~= false then
                CallModuleMethod(self, spec.apply or "ApplyConfig")
            end

            state.enabled = true
            return true
        end
    end

    if type(module.Disable) ~= "function" then
        function module:Disable()
            local spec = GetSpec(self)
            if spec.disable then
                CallModuleMethod(self, spec.disable)
            elseif type(self.Detach) == "function" then
                self:Detach()
            end

            local state = EnsureState(self)
            state.attached = false
            state.enabled = false
            return true
        end
    end
end

function Lifecycle:RegisterModule(name, module, spec)
    if type(name) ~= "string" or name == "" then
        return module
    end
    if type(module) ~= "table" then
        return module
    end

    local entry = self._modules[name]
    if entry then
        entry.module = module
        entry.spec = spec or EMPTY_SPEC
    else
        self._modules[name] = {
            module = module,
            spec = spec or EMPTY_SPEC,
        }
        self._order[#self._order + 1] = name
    end

    module._lifecycleName = name
    module._lifecycleSpec = spec or EMPTY_SPEC

    InjectLifecycleMethods(module)

    return module
end

function Lifecycle:GetModule(name)
    local entry = self._modules[name]
    return entry and entry.module or nil
end

function Lifecycle:Enable(name)
    local module = self:GetModule(name)
    if not module or type(module.Enable) ~= "function" then
        return false
    end
    return module:Enable()
end

function Lifecycle:Disable(name)
    local module = self:GetModule(name)
    if not module or type(module.Disable) ~= "function" then
        return false
    end
    return module:Disable()
end

function Lifecycle:EnableAll(order)
    local list = order or self._order
    if type(list) ~= "table" then
        return
    end
    for i = 1, #list do
        self:Enable(list[i])
    end
end
