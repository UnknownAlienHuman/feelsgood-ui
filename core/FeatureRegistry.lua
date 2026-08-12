-- FeelsGoodUI: centralized panel/feature contracts

local _, ns = ...

local Registry = ns.FeatureRegistry or {}
ns.FeatureRegistry = Registry

local function ResolveModule(contract)
    if type(contract) ~= "table" then
        return nil
    end

    local nsKey = contract.nsKey
    if type(nsKey) == "string" and nsKey ~= "" then
        return ns[nsKey]
    end

    return nil
end

local FEATURE_ORDER = Registry.FEATURE_ORDER or {
    "unitframes",
    "center",
    "experience",
    "actionbars",
    "minimap",
    "companion",
}

local FEATURE_CONTRACTS = Registry.FEATURE_CONTRACTS or {
    unitframes = {
        nsKey = "UF",
        attach = "Attach",
        detach = "Detach",
        init = "Init",
        lifecycleApply = "ApplyConfig",
        applyMethod = "ApplyConfig",
        applyKey = "unitframes",
        themeConsumer = true,
    },
    center = {
        nsKey = "Center",
        attach = "Attach",
        detach = "Detach",
        init = "Init",
        lifecycleApply = "ApplyConfig",
        applyMethod = "ApplyConfig",
        applyKey = "center",
        themeConsumer = true,
    },
    experience = {
        nsKey = "ExperienceBar",
        attach = "Attach",
        detach = "Detach",
        init = "Init",
        lifecycleApply = "ApplyConfig",
        applyMethod = "ApplyConfig",
        applyKey = "experience",
        themeConsumer = true,
    },
    actionbars = {
        nsKey = "ActionBars",
        attach = "Attach",
        detach = "Detach",
        init = "Init",
        lifecycleApply = false,
        applyMethod = "ApplyConfig",
        applyKey = "actionbars",
        deferInCombat = true,
        themeConsumer = true,
    },
    minimap = {
        nsKey = "MinimapIcon",
        attach = "Attach",
        detach = "Detach",
        init = "Init",
        lifecycleApply = "ApplyConfig",
        applyMethod = "ApplyConfig",
        applyKey = "minimap",
    },
    companion = {
        nsKey = "Companion",
        attach = "Attach",
        detach = "Detach",
        init = "Init",
        lifecycleApply = "ApplyConfig",
        applyMethod = "ApplyConfig",
        applyKey = "companion",
        deferInCombat = true,
        themeConsumer = true,
    },
}

local APPLY_ORDER = Registry.APPLY_ORDER or {
    "runtime",
    "theme",
    "unitframes",
    "center",
    "experience",
    "actionbars",
    "companion",
    "minimap",
}

local APPLY_CONTRACTS = Registry.APPLY_CONTRACTS or {
    runtime = {
        handler = function()
            local db = ns.DB
            if db and type(db.ApplyRuntime) == "function" then
                db:ApplyRuntime()
            end
        end,
    },
    theme = {
        handler = function()
            local app = ns.App
            if app and type(app.ApplyTheme) == "function" then
                app:ApplyTheme()
            end
        end,
        deferInCombat = true,
    },
    unitframes = { feature = "unitframes" },
    center = { feature = "center" },
    experience = { feature = "experience" },
    actionbars = {
        feature = "actionbars",
        deferInCombat = true,
    },
    companion = {
        feature = "companion",
        deferInCombat = true,
    },
    minimap = { feature = "minimap" },
}

local PANEL_ORDER = {
    "general",
    "editmode",
    "unitframes",
    "center",
    "actionbars",
    "companion",
}

local PANEL_CONTRACTS = Registry.PANEL_CONTRACTS or {
    general = {
        slot = "root",
        builderKey = "general",
        panelKey = "general",
        categoryId = "FGUI_ROOT",
        title = "FeelsGoodUI",
        contextSections = {
            general = "general",
            minimap = "minimap",
            media = "media",
        },
    },
    editmode = {
        slot = "edit",
        builderKey = "edit",
        panelKey = "editmode",
        categoryKey = "edit",
        categoryId = "FGUI_EDIT",
        title = "Edit Mode",
        applyKeys = "runtime",
        resetLabel = "Reset Edit Mode",
        resetSections = { "movers", "editor" },
        contextSections = {
            movers = "movers",
            editor = "editor",
        },
    },
    unitframes = {
        slot = "uf",
        builderKey = "unitframes",
        panelKey = "unitframes",
        categoryKey = "uf",
        categoryId = "FGUI_UNITFRAMES",
        title = "UnitFrames",
        applyKeys = "unitframes",
        resetLabel = "Reset UnitFrames",
        resetSections = { "unitframes" },
        contextSections = {
            uf = "unitframes",
            format = "format",
        },
    },
    center = {
        slot = "center",
        builderKey = "center",
        panelKey = "center",
        categoryKey = "center",
        categoryId = "FGUI_CENTER",
        title = "CenterBars",
        applyKeys = "center",
        resetLabel = "Reset CenterBars",
        resetSections = { "center" },
        contextSections = {
            center = "center",
        },
    },
    actionbars = {
        slot = "ab",
        builderKey = "actionbars",
        panelKey = "actionbars",
        categoryKey = "ab",
        categoryId = "FGUI_ACTIONBARS",
        title = "ActionBars",
        applyKeys = "actionbars",
        restoreApplyKeys = { "actionbars", "companion" },
        resetLabel = "Reset ActionBars",
        resetSections = { "actionbars" },
        contextSections = {
            ab = "actionbars",
        },
    },
    companion = {
        slot = "companion",
        builderKey = "companion",
        panelKey = "companion",
        categoryKey = "companion",
        categoryId = "FGUI_COMPANION",
        title = "Companion",
        applyKeys = "companion",
        resetLabel = "Reset Companion",
        resetSections = { "companion" },
        contextSections = {
            cp = "companion",
        },
    },
}

Registry.FEATURE_ORDER = FEATURE_ORDER
Registry.FEATURE_CONTRACTS = FEATURE_CONTRACTS
Registry.APPLY_ORDER = APPLY_ORDER
Registry.APPLY_CONTRACTS = APPLY_CONTRACTS
Registry.PANEL_ORDER = PANEL_ORDER
Registry.PANEL_CONTRACTS = PANEL_CONTRACTS

function Registry:GetFeatureOrder()
    return FEATURE_ORDER
end

function Registry:GetFeatureContract(featureKey)
    if type(featureKey) ~= "string" or featureKey == "" then
        return nil
    end
    return FEATURE_CONTRACTS[featureKey]
end

function Registry:GetFeatureSpecs()
    local specs = {}
    for i = 1, #FEATURE_ORDER do
        local featureKey = FEATURE_ORDER[i]
        local contract = FEATURE_CONTRACTS[featureKey]
        if contract then
            specs[featureKey] = {
                module = ResolveModule(contract),
                attach = contract.attach or "Attach",
                detach = contract.detach or "Detach",
                init = contract.init or "Init",
                apply = contract.lifecycleApply,
            }
        end
    end
    return specs
end

function Registry:GetThemeConsumers()
    local consumers = {}
    for i = 1, #FEATURE_ORDER do
        local contract = FEATURE_CONTRACTS[FEATURE_ORDER[i]]
        if contract and contract.themeConsumer then
            local module = ResolveModule(contract)
            if type(module) == "table" then
                consumers[#consumers + 1] = module
            end
        end
    end
    return consumers
end

function Registry:GetApplyOrder()
    return APPLY_ORDER
end

function Registry:GetApplyContract(applyKey)
    if type(applyKey) ~= "string" or applyKey == "" then
        return nil
    end
    return APPLY_CONTRACTS[applyKey]
end

function Registry:GetApplySpec(applyKey)
    local contract = self:GetApplyContract(applyKey)
    if type(contract) ~= "table" then
        return nil
    end

    local spec = {
        deferInCombat = contract.deferInCombat == true,
    }

    if type(contract.handler) == "function" then
        spec.handler = contract.handler
        return spec
    end

    local featureKey = contract.feature
    local featureContract = FEATURE_CONTRACTS[featureKey]
    local module = ResolveModule(featureContract)
    local method = contract.method or (featureContract and featureContract.applyMethod)
    if type(module) == "table" and type(method) == "string" and type(module[method]) == "function" then
        spec.handler = function()
            module[method](module)
        end
        return spec
    end

    return spec
end

function Registry:GetApplySpecs()
    local specs = {}
    for i = 1, #APPLY_ORDER do
        local applyKey = APPLY_ORDER[i]
        local spec = self:GetApplySpec(applyKey)
        if type(spec) == "table" then
            specs[applyKey] = spec
        end
    end
    return specs
end

function Registry:GetPanelContract(panelKey)
    if type(panelKey) ~= "string" or panelKey == "" then
        return nil
    end
    return PANEL_CONTRACTS[panelKey]
end

function Registry:GetPanelSpecs()
    local specs = {}
    for i = 1, #PANEL_ORDER do
        local panelKey = PANEL_ORDER[i]
        local contract = PANEL_CONTRACTS[panelKey]
        if contract then
            specs[#specs + 1] = contract
        end
    end
    return specs
end

function Registry:BuildPanelContext(getProfileSection, panelKey)
    local context = {}
    local contract = self:GetPanelContract(panelKey)
    if type(getProfileSection) ~= "function" or type(contract) ~= "table" then
        return context
    end

    local contextSections = contract.contextSections
    if type(contextSections) ~= "table" then
        return context
    end

    for alias, section in pairs(contextSections) do
        context[alias] = getProfileSection(section)
    end

    return context
end

return Registry
