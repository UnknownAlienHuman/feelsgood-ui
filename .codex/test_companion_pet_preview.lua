local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function NewFrame(parent, width, height, shown)
    local frame = {
        parent = parent,
        points = {},
        width = width or 20,
        height = height or 20,
        shown = shown ~= false,
        hitRect = { 1, 2, 3, 4 },
    }
    function frame:GetParent() return self.parent end
    function frame:SetParent(value) self.parent = value end
    function frame:GetNumPoints() return #self.points end
    function frame:GetPoint(index) return unpack(self.points[index]) end
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function frame:GetSize() return self.width, self.height end
    function frame:GetWidth() return self.width end
    function frame:GetHeight() return self.height end
    function frame:SetSize(w, h) self.width, self.height = w, h end
    function frame:IsShown() return self.shown end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:GetHitRectInsets() return unpack(self.hitRect) end
    function frame:SetHitRectInsets(...) self.hitRect = { ... } end
    function frame:GetName() return self.name end
    function frame:GetNormalTexture() return nil end
    function frame:GetPushedTexture() return nil end
    function frame:GetCheckedTexture() return nil end
    function frame:GetHighlightTexture() return nil end
    return frame
end

_G = _G or {}
_G.UIParent = { name = "UIParent" }
_G.RegisterStateDriver = function() end
_G.UnregisterStateDriver = function() end
_G.PetActionBar = nil

local holder
_G.CreateFrame = function(frameType, name, parent, template)
    assertEqual(frameType, "Frame", "holder type")
    assertEqual(name, "FGUI_oUF_PetBarHolder", "holder name")
    assertEqual(parent, _G.UIParent, "holder parent")
    assertEqual(template, "SecureHandlerStateTemplate", "holder template")
    holder = NewFrame(parent, 320, 32, true)
    holder.name = name
    return holder
end

local defaultParent = { name = "DefaultPetParent" }
local button = NewFrame(defaultParent, 27, 29, true)
button.name = "PetActionButton1"
button.points = { { "CENTER", defaultParent, "CENTER", 5, -6 } }
_G.PetActionButton1 = button

local registeredSpec
local shared = {
    PET_BUTTONS = 1,
    PET_KEY = "petbar",
    PET_ICON_CROP = 0.06,
    IsInCombat = function() return false end,
    GetCompanionCfg = function()
        return {
            buttonSize = 32,
            spacing = 0,
            petBar = { showHotkeys = false, strata = "LOW", level = 35 },
        }
    end,
    ClampButtonSize = function(value)
        local n = tonumber(value) or 32
        if n < 24 then n = 24 end
        if n > 60 then n = 60 end
        return math.floor(n + 0.5)
    end,
    ClampSpacing = function(value)
        local n = tonumber(value) or 0
        if n < 0 then n = 0 end
        if n > 12 then n = 12 end
        return math.floor(n + 0.5)
    end,
    ApplyFrameLayer = function() end,
    GetConfigSection = function() return {} end,
}

local ns = {
    CompanionShared = shared,
    Media = {
        ApplyIconCrop = function() end,
        CreateBorder = function() return {} end,
        SetBorderColor = function() return true end,
    },
    Movers = {
        Register = function(_, key, frame, spec)
            registeredSpec = spec
            assertEqual(key, "petbar", "mover key")
            assertEqual(frame, holder, "mover holder")
        end,
        Apply = function() end,
    },
    Theme = { Get = function() return nil end },
}

assert(loadfile("modules/CompanionPetState.lua"))("FeelsGoodUI", ns)
assert(loadfile("modules/CompanionPetBar.lua"))("FeelsGoodUI", ns)
local PetBar = assert(ns.CompanionPetBar)
local module = {}
ns.Companion = module
local cp = shared.GetCompanionCfg()

assertEqual(PetBar:Apply(module, cp, {}), true, "initial apply")
assertEqual(type(registeredSpec), "table", "mover spec registered")
assertEqual(button.parent, holder, "initial managed parent")
assertEqual(button.width, 32, "initial managed width")
assertEqual(module._petButtonState[1].managed.layout.size.width, 32, "initial managed snapshot")

local previewWidth, previewHeight = registeredSpec.previewSize(nil, 42, 42)
assertEqual(previewWidth, 42, "preview width result")
assertEqual(previewHeight, 42, "preview height result")
assertEqual(button.parent, holder, "preview parent")
assertEqual(button.width, 42, "preview width")
assertEqual(button.height, 42, "preview height")
assertEqual(module._petButtonState[1].managed.layout.size.width, 42, "preview updates managed snapshot")
assertEqual(module._petButtonState[1].managed.layout.size.height, 42, "preview managed height")

-- A dynamic visibility change during preview does not block structural restore.
button:Hide()
assertEqual(PetBar:RestoreDefaultLayout(module), true, "restore after preview")
assertEqual(button.parent, defaultParent, "preview parent restored")
assertEqual(button.width, 27, "preview width restored")
assertEqual(button.height, 29, "preview height restored")
assertEqual(button.shown, false, "newer visibility preserved")
assertEqual(holder.shown, false, "holder hidden on restore")
assertEqual(next(module._petButtonState), nil, "preview journal released")

-- Reapply and wheel preview use the same journal path.
button:Show()
assertEqual(PetBar:Apply(module, cp, {}), true, "reapply")
assertEqual(registeredSpec.previewWheel(nil, 3, false), true, "wheel preview")
assertEqual(button.width, 35, "wheel preview size")
assertEqual(module._petButtonState[1].managed.layout.size.width, 35, "wheel preview managed snapshot")
assertEqual(PetBar:RestoreDefaultLayout(module), true, "wheel preview restore")
assertEqual(button.parent, defaultParent, "wheel preview parent restored")
assertEqual(button.width, 27, "wheel preview width restored")

print("Companion pet-bar preview journal tests passed.")
