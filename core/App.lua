-- FeelsGoodUI: application lifecycle orchestrator
--
-- Owns:
--  - startup services
--  - feature module lifecycle wiring
--  - combat-safe reapply
--  - protected-action diagnostics routing

local _, ns = ...

local App = {}
ns.App = App

local function Guard(src, fn)
    local safety = ns.Safety
    if safety and safety.Guard then
        return safety.Guard(src, fn)
    end
    return pcall(fn)
end

local function L(text)
    local fn = ns.L
    if type(fn) == "function" then
        return fn(text)
    end
    return text
end

local function CallMethod(object, method, ...)
    if object and type(object[method]) == "function" then
        return object[method](object, ...)
    end
    return nil
end

local function GetRegistry()
    return ns.FeatureRegistry
end

local function CopyThemeTokens()
    local theme = ns.Theme
    local utils = ns.U
    if not (theme and type(theme.tokens) == "table" and utils and utils.DeepCopy) then
        return nil
    end
    return utils.DeepCopy(theme.tokens)
end

local function RestoreThemeTokens(snapshot)
    local theme = ns.Theme
    local utils = ns.U
    if not (theme and type(snapshot) == "table" and utils and utils.DeepCopy) then
        return false
    end
    theme.tokens = utils.DeepCopy(snapshot)
    return true
end

local function RestoreThemeConsumers(appliedModules, failedModule)
    if failedModule and type(failedModule.ApplyConfig) == "function" then
        pcall(failedModule.ApplyConfig, failedModule)
    end

    for i = #appliedModules, 1, -1 do
        local module = appliedModules[i]
        if module and type(module.ApplyConfig) == "function" then
            pcall(module.ApplyConfig, module)
        end
    end
end

local function LogLifecycleFailures(failures)
    if type(failures) ~= "table" or not (ns.Log and ns.Log.Warn) then
        return
    end

    for i = 1, #failures do
        local failure = failures[i]
        local name = type(failure) == "table" and failure.name or "unknown"
        local detail = type(failure) == "table" and failure.detail or nil
        if detail ~= nil and detail ~= "" then
            ns.Log:Warn(("Feature enable failed [%s]: %s"):format(tostring(name), tostring(detail)))
        else
            ns.Log:Warn(("Feature enable failed [%s]"):format(tostring(name)))
        end
    end
end

App._warned = App._warned or {}
App._featureOrder = App._featureOrder or {
    "unitframes",
    "center",
    "experience",
    "actionbars",
    "minimap",
    "companion",
}
App._applyOrder = App._applyOrder or {
    "runtime",
    "theme",
    "unitframes",
    "center",
    "experience",
    "actionbars",
    "companion",
    "minimap",
}

function App:BuildFeatureSpecs()
    local registry = GetRegistry()
    if registry and registry.GetFeatureSpecs then
        local specs = registry:GetFeatureSpecs()
        if type(specs) == "table" then
            return specs
        end
    end
    return {}
end

function App:RegisterFeatureModules()
    if self._featureModulesRegistered then
        return true
    end

    local lifecycle = ns.Lifecycle
    if not (lifecycle and lifecycle.RegisterModule) then
        return false, "Lifecycle.RegisterModule unavailable"
    end

    local specs = self:BuildFeatureSpecs()
    local registry = GetRegistry()
    local featureOrder = (registry and registry.GetFeatureOrder and registry:GetFeatureOrder()) or self._featureOrder
    local missing = {}

    for i = 1, #featureOrder do
        local name = featureOrder[i]
        local spec = specs[name]
        if spec and type(spec.module) == "table" then
            lifecycle:RegisterModule(name, spec.module, spec)
        else
            missing[#missing + 1] = tostring(name)
        end
    end

    if #missing > 0 then
        return false, "Missing feature modules: " .. table.concat(missing, ", ")
    end

    self._featureModulesRegistered = true
    return true
end

function App:ApplyTheme()
    local snapshot = CopyThemeTokens()
    local appliedModules = {}
    local registry = GetRegistry()
    local consumers = (registry and registry.GetThemeConsumers and registry:GetThemeConsumers()) or {}

    local okTheme, themeResult = pcall(function()
        return CallMethod(ns.Theme, "RefreshFromDB")
    end)
    if not okTheme or themeResult == false then
        RestoreThemeTokens(snapshot)
        local reason = okTheme and "Theme.RefreshFromDB returned false" or themeResult
        error(reason, 0)
    end

    -- Shared media/theme tokens are owned by Theme; fan-out to runtime modules
    -- stays centralized here instead of leaking into per-field settings wiring.
    for i = 1, #consumers do
        local module = consumers[i]
        if module and type(module.ApplyConfig) == "function" then
            local ok, result, detail = pcall(module.ApplyConfig, module)
            if not ok or result == false then
                RestoreThemeTokens(snapshot)
                RestoreThemeConsumers(appliedModules, module)

                local reason = result
                if ok then
                    reason = detail or ("Theme consumer returned false: " .. tostring(module._lifecycleName or i))
                end
                error(reason, 0)
            end
            appliedModules[#appliedModules + 1] = module
        end
    end

    return true
end

function App:BuildApplySpecs()
    local registry = GetRegistry()
    if registry and registry.GetApplySpecs then
        local specs = registry:GetApplySpecs()
        if type(specs) == "table" then
            return specs
        end
    end
    return {}
end

function App:GetApplyOrder()
    local registry = GetRegistry()
    if registry and registry.GetApplyOrder then
        local order = registry:GetApplyOrder()
        if type(order) == "table" and #order > 0 then
            return order
        end
    end
    return self._applyOrder
end

function App:GetApplySpec(key)
    if type(key) ~= "string" or key == "" then
        return nil
    end

    local registry = GetRegistry()
    if registry and registry.GetApplySpec then
        local spec = registry:GetApplySpec(key)
        if type(spec) == "table" then
            return spec
        end
    end

    local specs = self:BuildApplySpecs()
    return type(specs) == "table" and specs[key] or nil
end

function App:ShouldDeferApplyInCombat(key)
    local spec = self:GetApplySpec(key)
    return spec and spec.deferInCombat == true or false
end

function App:ApplyByKey(key)
    local spec = self:GetApplySpec(key)
    local handler = spec and spec.handler
    if type(handler) ~= "function" then
        return false, "No apply handler for key: " .. tostring(key)
    end

    local result, detail = handler()
    if result == false then
        return false, detail or ("Apply handler returned false: " .. tostring(key))
    end
    return true
end

function App:EnableFeatureModules()
    local registered, registerDetail = self:RegisterFeatureModules()
    if registered == false then
        return false, { { name = "registration", detail = registerDetail } }
    end

    local lifecycle = ns.Lifecycle
    if not (lifecycle and lifecycle.Enable) then
        return false, { { name = "lifecycle", detail = "Lifecycle.Enable unavailable" } }
    end

    local registry = GetRegistry()
    local featureOrder = (registry and registry.GetFeatureOrder and registry:GetFeatureOrder()) or self._featureOrder

    local ok, failures
    if type(lifecycle.EnableAll) == "function" then
        ok, failures = lifecycle:EnableAll(featureOrder)
    else
        failures = {}
        for i = 1, #featureOrder do
            local name = featureOrder[i]
            local enabled, detail = lifecycle:Enable(name)
            if not enabled then
                failures[#failures + 1] = { name = name, detail = detail }
            end
        end
        ok = #failures == 0
    end

    if not ok then
        LogLifecycleFailures(failures)
    end
    return ok, failures
end

function App:RunStartupServices()
    local services = {
        {
            label = "DB.Init",
            run = function()
                CallMethod(ns.DB, "Init")
            end,
        },
        {
            label = "DB.ApplyRuntime",
            run = function()
                CallMethod(ns.DB, "ApplyRuntime")
            end,
        },
        {
            label = "Theme.RefreshFromDB",
            run = function()
                CallMethod(ns.Theme, "RefreshFromDB")
            end,
        },
        {
            label = "Perf.RefreshFromProfile",
            run = function()
                CallMethod(ns.Perf, "RefreshFromProfile")
            end,
        },
        {
            label = "Commands.Register",
            run = function()
                CallMethod(ns.Commands, "Register")
            end,
        },
        {
            label = "Options.RegisterPanel",
            run = function()
                CallMethod(ns.Options, "RegisterPanel")
            end,
        },
        {
            label = "App.RegisterFeatureModules",
            run = function()
                local ok, detail = self:RegisterFeatureModules()
                if ok == false then
                    error(detail or "Feature registration failed", 0)
                end
            end,
        },
    }

    for i = 1, #services do
        local service = services[i]
        Guard(service.label, service.run)
    end

    if not _G.oUF and ns.Log and ns.Log.Error then
        ns.Log:Error(L("oUF not detected. FeelsGoodUI requires the oUF addon."))
    end
end

function App:ApplyDeferredCombatState()
    CallMethod(ns.UF, "FlushDeferredUpdates")
end

function App:OnAddonLoaded(loadedName)
    if loadedName ~= ns.ADDON_NAME then
        return
    end

    self:RunStartupServices()

    if ns.Log and ns.VERSION then
        ns.Log:Info(L("Loaded v%s"):format(tostring(ns.VERSION)))
    end
end

function App:OnPlayerLogin()
    Guard("App.EnableFeatureModules", function()
        self:EnableFeatureModules()
    end)

    Guard("Movers.ApplyUnlockFromDB", function()
        CallMethod(ns.Movers, "ApplyUnlockFromDB")
    end)
end

function App:OnCombatStart()
    CallMethod(ns.UF, "OnCombatStart")
end

function App:OnCombatEnd()
    CallMethod(ns.UF, "OnCombatEnd")
    CallMethod(ns.Center, "OnCombatEnd")
    self:ApplyDeferredCombatState()
    CallMethod(ns.Apply, "OnCombatEnd")
end

function App:WarnProtectedAction(eventName, addonName, funcName)
    if ns.Diagnostics and ns.Diagnostics.Capture then
        ns.Diagnostics:Capture(eventName, addonName, funcName)
    end

    local key = tostring(eventName) .. ":" .. tostring(addonName) .. ":" .. tostring(funcName)
    if self._warned[key] then
        return
    end
    self._warned[key] = true

    if ns.Log and ns.Log.Warn then
        ns.Log:Warn(L("%s: %s: %s"):format(tostring(eventName), tostring(addonName), tostring(funcName)))
    end
end

function ns:ADDON_LOADED(loadedName)
    App:OnAddonLoaded(loadedName)
end

function ns:PLAYER_LOGIN()
    App:OnPlayerLogin()
end

function ns:PLAYER_REGEN_DISABLED()
    App:OnCombatStart()
end

function ns:PLAYER_REGEN_ENABLED()
    App:OnCombatEnd()
end

function ns:ADDON_ACTION_BLOCKED(addonName, funcName)
    App:WarnProtectedAction("ADDON_ACTION_BLOCKED", addonName, funcName)
end

function ns:ADDON_ACTION_FORBIDDEN(addonName, funcName)
    App:WarnProtectedAction("ADDON_ACTION_FORBIDDEN", addonName, funcName)
end

function ns:MACRO_ACTION_FORBIDDEN(addonName, funcName)
    App:WarnProtectedAction("MACRO_ACTION_FORBIDDEN", addonName, funcName)
end
