-- FeelsGoodUI: Options (no Ace3)
--
-- Step 12:
--  - Split Settings into sub-panels to avoid one long "mesivo" page.
--  - Add an Edit Mode panel with grid controls.
--  - Keep headers neutral (avoid yellow GameFontNormalLarge).

local _, ns = ...

local Log = ns.Log
local Shared = ns.OptionsShared or {}
local PANEL_SPECS = Shared.PANEL_SPECS or {}
local ROOT_CATEGORY_ID = ((PANEL_SPECS[1] and PANEL_SPECS[1].categoryId) or "FGUI_ROOT")

local RegisterSubcategorySafe = Shared.RegisterSubcategorySafe
local EnsureModernSettingsAPI = Shared.EnsureModernSettingsAPI
local EnsurePanelContract = Shared.EnsurePanelContract
local ApplyDefaultLayoutAnchors = Shared.ApplyDefaultLayoutAnchors

local Options = {}
ns.Options = Options

-- Root + sub-panels
local rootPanel, rootCategory
local panels = {}
local categories = {}

local function ResolveCategoryId(value)
    value = tostring(value or "")
    if value:match("^FGUI_") then
        return value
    end
    return "FGUI_" .. value
end

local function EnsurePanelsBuilt()
    if rootPanel then
        return
    end

    for i = 1, #PANEL_SPECS do
        local spec = PANEL_SPECS[i]
        local builder = Shared.GetPanelBuilder(spec.builderKey)
        if type(builder) == "function" then
            local panel = builder()
            if spec.slot == "root" then
                rootPanel = panel
            else
                panels[spec.slot] = panel
            end
            EnsurePanelContract(panel)
        elseif Log and Log.Warn then
            Log:Warn("Options: missing panel builder for '" .. tostring(spec.builderKey) .. "'")
        end
    end
end

-- -----------------------------
-- Registration + open
-- -----------------------------

function Options:RegisterPanel()
    EnsurePanelsBuilt()
    if rootCategory then
        return
    end

    if not rootPanel then
        if Log and Log.Warn then
            Log:Warn("Options:RegisterPanel: root panel builder unavailable")
        end
        return
    end

    if not EnsureModernSettingsAPI() then
        if Log and Log.Warn then
            Log:Warn("Options:RegisterPanel: modern Settings API unavailable")
        end
        return
    end

    -- Canvas categories return (category, layout) on modern clients.
    local cat, layout = _G.Settings.RegisterCanvasLayoutCategory(rootPanel, rootPanel.name)
    if not cat then
        if Log and Log.Warn then
            Log:Warn("Options:RegisterPanel: failed to register root Settings category")
        end
        return
    end

    cat.ID = cat.ID or ROOT_CATEGORY_ID
    rootCategory = cat
    ApplyDefaultLayoutAnchors(layout)
    if _G.Settings.RegisterAddOnCategory then
        _G.Settings.RegisterAddOnCategory(cat)
    end

    local function Reg(key, panel)
        if not panel then return nil end
        local id = ResolveCategoryId(key)
        EnsurePanelContract(panel)

        local sub, subLayout = RegisterSubcategorySafe(cat, panel, panel.name, id)
        if sub then
            sub.ID = sub.ID or id
            ApplyDefaultLayoutAnchors(subLayout)
        end
        return sub
    end

    for i = 1, #PANEL_SPECS do
        local spec = PANEL_SPECS[i]
        if spec.categoryKey then
            categories[spec.categoryKey] = Reg(spec.categoryId, panels[spec.slot])
        end
    end
end

function Options:Open()
    if not rootPanel then
        self:RegisterPanel()
    end

    if EnsureModernSettingsAPI() and rootCategory then
        local target = rootCategory.ID or (rootCategory.GetID and rootCategory:GetID()) or (rootPanel and rootPanel.name) or "FGUI_ROOT"
        _G.C_Timer.After(0, function()
            if _G.Settings and _G.Settings.OpenToCategory then
                _G.Settings.OpenToCategory(target)
                if rootPanel and rootPanel.refresh then
                    rootPanel:refresh()
                end
            end
        end)
        return
    end

    if Log and Log.Warn then
        Log:Warn("Options:Open: modern Settings category unavailable")
    end
end

Log:Debug("Options loaded")
