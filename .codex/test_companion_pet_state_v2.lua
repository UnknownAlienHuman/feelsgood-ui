local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function NewObject(options)
    options = options or {}
    local object = {
        parent = options.parent,
        points = options.points or {},
        width = options.width or 20,
        height = options.height or 20,
        shown = options.shown ~= false,
        alpha = options.alpha or 1,
        hitRect = options.hitRect or { 0, 0, 0, 0 },
        texCoord = options.texCoord or { 0, 1, 0, 1 },
        text = options.text,
    }
    function object:GetParent() return self.parent end
    function object:SetParent(value) self.parent = value end
    function object:GetNumPoints() return #self.points end
    function object:GetPoint(index) return unpack(self.points[index]) end
    function object:ClearAllPoints() self.points = {} end
    function object:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function object:SetAllPoints(relativeTo)
        self.points = {
            { "TOPLEFT", relativeTo, "TOPLEFT", 0, 0 },
            { "BOTTOMRIGHT", relativeTo, "BOTTOMRIGHT", 0, 0 },
        }
    end
    function object:GetSize() return self.width, self.height end
    function object:SetSize(width, height) self.width, self.height = width, height end
    function object:IsShown() return self.shown end
    function object:Show() self.shown = true end
    function object:Hide() self.shown = false end
    function object:GetAlpha() return self.alpha end
    function object:SetAlpha(value) self.alpha = value end
    function object:GetHitRectInsets() return unpack(self.hitRect) end
    function object:SetHitRectInsets(...) self.hitRect = { ... } end
    function object:GetTexCoord() return unpack(self.texCoord) end
    function object:SetTexCoord(...) self.texCoord = { ... } end
    function object:GetText() return self.text end
    function object:SetText(value) self.text = value end
    return object
end

local function NewFixture(label)
    local parent = { name = label .. "Parent" }
    local button = NewObject({
        parent = parent,
        points = { { "CENTER", parent, "CENTER", 4, -5 } },
        width = 27,
        height = 29,
        shown = true,
        hitRect = { 1, 2, 3, 4 },
    })
    local components = {
        icon = NewObject({
            points = { { "CENTER", button, "CENTER", 1, 2 } },
            texCoord = { 0, 1, 0, 1 },
        }),
        highlight = NewObject({
            points = { { "CENTER", button, "CENTER", 0, 0 } },
            alpha = 0.65,
        }),
        cooldown = NewObject({
            points = { { "TOPLEFT", button, "TOPLEFT", 2, -2 } },
        }),
        iconMask = NewObject({ shown = true }),
        name = NewObject({ shown = true, text = label .. "Name" }),
        hotkey = NewObject({ shown = true, alpha = 0.75, text = label .. "Key" }),
        alphas = {
            normal = NewObject({ alpha = 0.61 }),
            pushed = NewObject({ alpha = 0.52 }),
        },
    }
    return button, components, parent
end

local function Manage(State, module, index, button, components, holder, size)
    assertEqual(State:BeginButton(module, index, button, components), true, "begin")
    button:SetParent(holder)
    button:ClearAllPoints()
    button:SetPoint("LEFT", holder, "LEFT", 9, 0)
    button:SetSize(size, size)
    button:SetHitRectInsets(0, 0, 0, 0)
    button:Show()

    components.icon:ClearAllPoints()
    components.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    components.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    components.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    components.highlight:ClearAllPoints()
    components.highlight:SetAllPoints(button)
    components.highlight:SetAlpha(0.20)
    components.cooldown:ClearAllPoints()
    components.cooldown:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    components.cooldown:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    components.iconMask:Hide()
    components.name:SetText("")
    components.name:Hide()
    components.hotkey:SetAlpha(0)
    components.hotkey:Hide()
    for _, object in pairs(components.alphas) do object:SetAlpha(0) end

    assertEqual(State:FinishButton(module, index, button, components), true, "finish")
end

_G = _G or {}
local ns = {}
assert(loadfile("modules/CompanionPetState.lua"))("FeelsGoodUI", ns)
local State = assert(ns.CompanionPetState)
local holder = { name = "Holder" }

-- Dynamic visibility is independent from structural layout ownership.
local visibilityModule = {}
local visibilityButton, visibilityComponents, visibilityParent = NewFixture("Visibility")
Manage(State, visibilityModule, 1, visibilityButton, visibilityComponents, holder, 32)
visibilityButton:Hide() -- Blizzard/pet state changed while our structural layout stayed owned.
assertEqual(State:RestoreAll(visibilityModule), true, "visibility restore")
assertEqual(visibilityButton.parent, visibilityParent, "structure restored despite visibility conflict")
assertEqual(visibilityButton.width, 27, "size restored despite visibility conflict")
assertEqual(visibilityButton.shown, false, "newer visibility preserved")

-- Replacing a component object on the same button reopens the snapshot.
local componentModule = {}
local componentButton, oldComponents, componentParent = NewFixture("Component")
Manage(State, componentModule, 1, componentButton, oldComponents, holder, 31)
local oldIcon = oldComponents.icon
local newIcon = NewObject({
    points = { { "CENTER", componentButton, "CENTER", 7, -8 } },
    texCoord = { 0.10, 0.90, 0.20, 0.80 },
})
local newComponents = {}
for key, value in pairs(oldComponents) do newComponents[key] = value end
newComponents.icon = newIcon

assertEqual(State:BeginButton(componentModule, 1, componentButton, newComponents), true, "component replacement begin")
assertEqual(componentButton.parent, componentParent, "old layout restored before recapture")
assertEqual(oldIcon.texCoord[1], 0, "old icon crop restored before recapture")

Manage(State, componentModule, 1, componentButton, newComponents, holder, 35)
assertEqual(State:RestoreAll(componentModule), true, "component replacement restore")
assertEqual(componentButton.parent, componentParent, "new snapshot layout restored")
assertEqual(newIcon.texCoord[1], 0.10, "new icon original crop restored")
assertEqual(newIcon.points[1][4], 7, "new icon original x restored")
assertEqual(newIcon.points[1][5], -8, "new icon original y restored")

-- A mutable but unreadable component is rejected before any mutation.
local unreadableModule = {}
local unreadableButton, readableComponents = NewFixture("Unreadable")
local unreadableIcon = {
    points = { { "CENTER", unreadableButton, "CENTER", 0, 0 } },
}
function unreadableIcon:GetNumPoints() return #self.points end
function unreadableIcon:GetPoint(index) return unpack(self.points[index]) end
function unreadableIcon:ClearAllPoints() self.points = {} end
function unreadableIcon:SetPoint(...) self.points[#self.points + 1] = { ... } end
function unreadableIcon:SetTexCoord(...) self.texCoord = { ... } end
readableComponents.icon = unreadableIcon
local unreadableOK, unreadableDetail = State:BeginButton(
    unreadableModule,
    1,
    unreadableButton,
    readableComponents
)
assertEqual(unreadableOK, false, "unreadable icon rejected")
assertEqual(unreadableDetail, "Pet action button state is unreadable", "unreadable icon detail")
assertEqual(unreadableButton.parent ~= holder, true, "unreadable button not mutated")

-- An unreadable alpha target also prevents adoption.
local badAlphaButton, badAlphaComponents = NewFixture("BadAlpha")
local badAlpha = { alpha = 0.5 }
function badAlpha:SetAlpha(value) self.alpha = value end
badAlphaComponents.alphas.normal = badAlpha
local badAlphaOK = State:BeginButton({}, 1, badAlphaButton, badAlphaComponents)
assertEqual(badAlphaOK, false, "unreadable alpha target rejected")
assertEqual(badAlpha.alpha, 0.5, "unreadable alpha target untouched")

print("Companion pet-state ownership edge tests passed.")
