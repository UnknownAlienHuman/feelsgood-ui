-- FeelsGoodUI: shared Options registry + Settings glue

local _, ns = ...

local Shared = ns.OptionsShared or {}
ns.OptionsShared = Shared

local Registry = ns.FeatureRegistry

local FALLBACK_PANEL_SPECS = {
    { slot = "root", builderKey = "general", categoryId = "FGUI_ROOT" },
    { slot = "edit", builderKey = "edit", categoryKey = "edit", categoryId = "FGUI_EDIT" },
    { slot = "uf", builderKey = "unitframes", categoryKey = "uf", categoryId = "FGUI_UNITFRAMES" },
    { slot = "center", builderKey = "center", categoryKey = "center", categoryId = "FGUI_CENTER" },
    { slot = "ab", builderKey = "actionbars", categoryKey = "ab", categoryId = "FGUI_ACTIONBARS" },
    { slot = "companion", builderKey = "companion", categoryKey = "companion", categoryId = "FGUI_COMPANION" },
}

local PANEL_SPECS = (Registry and Registry.GetPanelSpecs and Registry:GetPanelSpecs()) or FALLBACK_PANEL_SPECS

local panelBuilders = Shared._panelBuilders or {}
Shared._panelBuilders = panelBuilders

function Shared.RegisterPanelBuilder(key, builder)
    if type(key) ~= "string" or key == "" or type(builder) ~= "function" then
        return
    end
    panelBuilders[key] = builder
end

function Shared.GetPanelBuilder(key)
    if type(key) ~= "string" or key == "" then
        return nil
    end
    return panelBuilders[key]
end

local function RegisterSubcategorySafe(parentCategory, panel, name, id)
    if not (_G.Settings and _G.Settings.RegisterCanvasLayoutSubcategory) then return nil end

    id = id or name

    local function Try(...)
        local ok, a, b = pcall(_G.Settings.RegisterCanvasLayoutSubcategory, ...)
        if ok and a then
            return a, b
        end
        return nil
    end

    local sub, layout = Try(parentCategory, panel, name, id)
    if sub then return sub, layout end

    sub, layout = Try(parentCategory, name, panel, id)
    if sub then return sub, layout end

    sub, layout = Try(parentCategory, panel, name)
    if sub then return sub, layout end

    return nil
end

local function EnsureModernSettingsAPI()
    local settings = _G.Settings
    if settings and settings.RegisterCanvasLayoutCategory and settings.OpenToCategory then
        return true
    end

    if _G.C_AddOns and _G.C_AddOns.LoadAddOn then
        pcall(_G.C_AddOns.LoadAddOn, "Blizzard_Settings")
    elseif _G.LoadAddOn then
        pcall(_G.LoadAddOn, "Blizzard_Settings")
    end

    settings = _G.Settings
    return settings and settings.RegisterCanvasLayoutCategory and settings.OpenToCategory
end

local function EnsurePanelContract(panel)
    if not panel then return end

    if type(panel.OnRefresh) ~= "function" then
        function panel:OnRefresh()
            if self.refresh then
                self:refresh()
            end
        end
    end
    if type(panel.OnCommit) ~= "function" then
        function panel:OnCommit() end
    end
    if type(panel.OnDefault) ~= "function" then
        function panel:OnDefault() end
    end
end

local function ApplyDefaultLayoutAnchors(layout)
    if not layout or type(layout.AddAnchorPoint) ~= "function" then return end

    layout:AddAnchorPoint("TOPLEFT", 0, 0)
    layout:AddAnchorPoint("BOTTOMRIGHT", 0, 0)
end

local function GetPanelContract(panelKey)
    if Registry and Registry.GetPanelContract then
        return Registry:GetPanelContract(panelKey)
    end
    return nil
end

local function BuildPanelContext(getProfileSection, panelKey)
    if Registry and Registry.BuildPanelContext then
        return Registry:BuildPanelContext(getProfileSection, panelKey)
    end
    return {}
end

Shared.PANEL_SPECS = PANEL_SPECS
Shared.RegisterSubcategorySafe = RegisterSubcategorySafe
Shared.EnsureModernSettingsAPI = EnsureModernSettingsAPI
Shared.EnsurePanelContract = EnsurePanelContract
Shared.ApplyDefaultLayoutAnchors = ApplyDefaultLayoutAnchors
Shared.GetPanelContract = GetPanelContract
Shared.BuildPanelContext = BuildPanelContext
