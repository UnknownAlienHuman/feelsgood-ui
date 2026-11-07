local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function NewButton(parent)
    local button = {
        parent = parent,
        points = { { "CENTER", parent, "CENTER", 0, 0 } },
        width = 20,
        height = 20,
        shown = true,
        alpha = 1,
        hitRect = { 0, 0, 0, 0 },
    }
    function button:GetParent() return self.parent end
    function button:SetParent(value) self.parent = value end
    function button:GetNumPoints() return #self.points end
    function button:GetPoint(index) return unpack(self.points[index]) end
    function button:ClearAllPoints() self.points = {} end
    function button:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function button:GetSize() return self.width, self.height end
    function button:SetSize(width, height) self.width, self.height = width, height end
    function button:IsShown() return self.shown end
    function button:Show() self.shown = true end
    function button:Hide() self.shown = false end
    function button:GetAlpha() return self.alpha end
    function button:SetAlpha(value) self.alpha = value end
    function button:GetHitRectInsets() return unpack(self.hitRect) end
    function button:SetHitRectInsets(...) self.hitRect = { ... } end
    return button
end

local function Manage(State, module, index, button, holder, release)
    local components = { release = release, alphas = {} }
    assertEqual(State:BeginButton(module, index, button, components), true, "begin")
    button:SetParent(holder)
    button:ClearAllPoints()
    button:SetPoint("LEFT", holder, "LEFT", 2, 0)
    button:SetSize(32, 32)
    assertEqual(State:FinishButton(module, index, button, components), true, "finish")
end

_G = _G or {}
local ns = {}
assert(loadfile("modules/CompanionPetState.lua"))("FeelsGoodUI", ns)
local State = assert(ns.CompanionPetState)
local holder = {}

local released = {}
local function Release(button)
    released[button] = (released[button] or 0) + 1
end

local module = {}
local originalParent = {}
local button = NewButton(originalParent)
Manage(State, module, 1, button, holder, Release)
assertEqual(State:RestoreAll(module), true, "normal restore")
assertEqual(released[button], 1, "normal release once")
assertEqual(button.parent, originalParent, "normal state restored")

-- Replacement releases the old object before adopting the new one.
local replacementModule = {}
local oldButton = NewButton({})
Manage(State, replacementModule, 1, oldButton, holder, Release)
local newButton = NewButton({})
local newComponents = { release = Release, alphas = {} }
assertEqual(State:BeginButton(replacementModule, 1, newButton, newComponents), true, "replacement begin")
assertEqual(released[oldButton], 1, "old replacement released")
newButton:SetParent(holder)
newButton:ClearAllPoints()
newButton:SetPoint("LEFT", holder, "LEFT", 2, 0)
newButton:SetSize(32, 32)
assertEqual(State:FinishButton(replacementModule, 1, newButton, newComponents), true, "replacement finish")
assertEqual(State:ReleaseButton(replacementModule, 1), true, "replacement release")
assertEqual(released[newButton], 1, "new replacement released")

-- Unfinished mutation uses force restore and still releases addon-owned style.
local unfinishedModule = {}
local unfinished = NewButton({})
local unfinishedComponents = { release = Release, alphas = {} }
assertEqual(State:BeginButton(unfinishedModule, 1, unfinished, unfinishedComponents), true, "unfinished begin")
unfinished:SetParent(holder)
assertEqual(State:RestoreAll(unfinishedModule), true, "unfinished restore")
assertEqual(released[unfinished], 1, "unfinished style released")

-- Release callbacks are isolated from rollback correctness.
local safeModule = {}
local safeParent = {}
local safeButton = NewButton(safeParent)
Manage(State, safeModule, 1, safeButton, holder, function() error("release failure") end)
assertEqual(State:RestoreAll(safeModule), true, "release error isolated")
assertEqual(safeButton.parent, safeParent, "state restored despite release error")

print("Companion pet-style release tests passed.")
