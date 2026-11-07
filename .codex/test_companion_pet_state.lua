local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertPoint(object, index, point, relativeTo, relativePoint, x, y, label)
    local p, rel, rp, px, py = object:GetPoint(index)
    assertEqual(p, point, (label or "point") .. " point")
    assertEqual(rel, relativeTo, (label or "point") .. " relative")
    assertEqual(rp, relativePoint, (label or "point") .. " relativePoint")
    assertEqual(px, x, (label or "point") .. " x")
    assertEqual(py, y, (label or "point") .. " y")
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
    function object:GetPoint(index)
        local p = self.points[index]
        return p[1], p[2], p[3], p[4], p[5]
    end
    function object:ClearAllPoints() self.points = {} end
    function object:SetPoint(point, relativeTo, relativePoint, x, y)
        self.points[#self.points + 1] = { point, relativeTo, relativePoint, x, y }
    end
    function object:GetSize() return self.width, self.height end
    function object:GetWidth() return self.width end
    function object:GetHeight() return self.height end
    function object:SetSize(width, height) self.width, self.height = width, height end
    function object:IsShown() return self.shown end
    function object:Show() self.shown = true end
    function object:Hide() self.shown = false end
    function object:GetAlpha() return self.alpha end
    function object:SetAlpha(value) self.alpha = value end
    function object:GetHitRectInsets()
        return self.hitRect[1], self.hitRect[2], self.hitRect[3], self.hitRect[4]
    end
    function object:SetHitRectInsets(left, right, top, bottom)
        self.hitRect = { left, right, top, bottom }
    end
    function object:GetTexCoord() return unpack(self.texCoord) end
    function object:SetTexCoord(...) self.texCoord = { ... } end
    function object:GetText() return self.text end
    function object:SetText(value) self.text = value end
    return object
end

local function Components(seed)
    return {
        icon = seed.icon,
        highlight = seed.highlight,
        cooldown = seed.cooldown,
        iconMask = seed.iconMask,
        name = seed.name,
        hotkey = seed.hotkey,
        alphas = {
            normal = seed.normal,
            pushed = seed.pushed,
            checked = seed.checked,
            slot = seed.slot,
        },
    }
end

local function NewButtonFixture(label)
    local defaultParent = { name = label .. "DefaultParent" }
    local button = NewObject({
        parent = defaultParent,
        points = { { "CENTER", defaultParent, "CENTER", 3, -4 } },
        width = 27,
        height = 29,
        shown = false,
        hitRect = { 1, 2, 3, 4 },
    })
    local seed = {
        icon = NewObject({ points = { { "CENTER", button, "CENTER", 1, 2 } }, texCoord = { 0, 1, 0, 1 }, alpha = 0.91 }),
        highlight = NewObject({ points = { { "CENTER", button, "CENTER", 0, 0 } }, alpha = 0.67, shown = false }),
        cooldown = NewObject({ points = { { "TOPLEFT", button, "TOPLEFT", 2, -2 } }, alpha = 0.88 }),
        iconMask = NewObject({ shown = true, alpha = 0.76 }),
        name = NewObject({ shown = true, alpha = 0.82, text = label .. "Name" }),
        hotkey = NewObject({ shown = true, alpha = 0.73, text = label .. "Key" }),
        normal = NewObject({ alpha = 0.61 }),
        pushed = NewObject({ alpha = 0.52 }),
        checked = NewObject({ alpha = 0.43 }),
        slot = NewObject({ alpha = 0.34 }),
    }
    return button, seed, defaultParent
end

local function ApplyManaged(button, seed, holder, size)
    button:SetParent(holder)
    button:ClearAllPoints()
    button:SetPoint("LEFT", holder, "LEFT", 11, 0)
    button:SetSize(size, size)
    button:SetHitRectInsets(0, 0, 0, 0)
    button:Show()

    seed.icon:ClearAllPoints()
    seed.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    seed.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    seed.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)

    seed.highlight:ClearAllPoints()
    seed.highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    seed.highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    seed.highlight:SetAlpha(0.20)
    seed.highlight:Show()

    seed.cooldown:ClearAllPoints()
    seed.cooldown:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    seed.cooldown:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)

    seed.iconMask:Hide()
    seed.name:SetText("")
    seed.name:Hide()
    seed.hotkey:SetAlpha(0)
    seed.hotkey:Hide()
    seed.normal:SetAlpha(0)
    seed.pushed:SetAlpha(0)
    seed.checked:SetAlpha(0)
    seed.slot:SetAlpha(0)
end

_G = _G or {}
local ns = {}
assert(loadfile("modules/CompanionPetState.lua"))("FeelsGoodUI", ns)
local State = assert(ns.CompanionPetState)

local holder = { name = "Holder" }
local externalParent = { name = "ExternalParent" }
local module = {}
local button, seed, defaultParent = NewButtonFixture("A")
local components = Components(seed)

local begun, detail = State:BeginButton(module, 1, button, components)
assertEqual(begun, true, "begin button")
assertEqual(detail.button, button, "record returned")
ApplyManaged(button, seed, holder, 32)
assertEqual(State:FinishButton(module, 1, button, components), true, "finish button")

-- Reapply updates the managed state without overwriting the original snapshot.
assertEqual(State:BeginButton(module, 1, button, components), true, "repeat begin")
ApplyManaged(button, seed, holder, 36)
assertEqual(State:FinishButton(module, 1, button, components), true, "repeat finish")

local nativeBar = NewObject({ alpha = 0.64 })
assertEqual(State:SuppressNativeBar(module, nativeBar), true, "native suppression")
assertEqual(nativeBar.alpha, 0, "native alpha managed")

-- One newer external property change survives while all still-owned properties restore.
seed.hotkey:SetAlpha(0.45)
assertEqual(State:RestoreAll(module), true, "restore all")
assertEqual(button.parent, defaultParent, "button parent restored")
assertPoint(button, 1, "CENTER", defaultParent, "CENTER", 3, -4, "button point restored")
assertEqual(button.width, 27, "button width restored")
assertEqual(button.height, 29, "button height restored")
assertEqual(button.shown, false, "button visibility restored")
assertEqual(button.hitRect[1], 1, "hit rect left restored")
assertPoint(seed.icon, 1, "CENTER", button, "CENTER", 1, 2, "icon point restored")
assertEqual(seed.icon.texCoord[1], 0, "icon crop restored")
assertEqual(seed.highlight.alpha, 0.67, "highlight alpha restored")
assertEqual(seed.highlight.shown, false, "highlight visibility restored")
assertPoint(seed.cooldown, 1, "TOPLEFT", button, "TOPLEFT", 2, -2, "cooldown restored")
assertEqual(seed.iconMask.shown, true, "mask restored")
assertEqual(seed.name.text, "AName", "name text restored")
assertEqual(seed.name.shown, true, "name visibility restored")
assertEqual(seed.hotkey.alpha, 0.45, "newer hotkey alpha preserved")
assertEqual(seed.hotkey.shown, true, "still-owned hotkey visibility restored")
assertEqual(seed.normal.alpha, 0.61, "normal alpha restored")
assertEqual(seed.pushed.alpha, 0.52, "pushed alpha restored")
assertEqual(nativeBar.alpha, 0.64, "native alpha restored")
assertEqual(next(module._petButtonState), nil, "button registry emptied")
assertEqual(module._petNativeBarState, nil, "native registry cleared")

-- Replacing a button restores the old instance before capturing the new one.
local replaceModule = {}
local oldButton, oldSeed, oldParent = NewButtonFixture("Old")
assertEqual(State:BeginButton(replaceModule, 1, oldButton, Components(oldSeed)), true, "old begin")
ApplyManaged(oldButton, oldSeed, holder, 31)
assertEqual(State:FinishButton(replaceModule, 1, oldButton, Components(oldSeed)), true, "old finish")
local newButton, newSeed = NewButtonFixture("New")
assertEqual(State:BeginButton(replaceModule, 1, newButton, Components(newSeed)), true, "replacement begin")
assertEqual(oldButton.parent, oldParent, "old replacement parent restored")
assertEqual(oldButton.width, 27, "old replacement size restored")
ApplyManaged(newButton, newSeed, holder, 33)
assertEqual(State:FinishButton(replaceModule, 1, newButton, Components(newSeed)), true, "replacement finish")

-- Layout is one ownership group: an external parent change preserves the whole managed layout.
newButton:SetParent(externalParent)
assertEqual(State:RestoreAll(replaceModule), true, "replacement restore")
assertEqual(newButton.parent, externalParent, "external parent preserved")
assertPoint(newButton, 1, "LEFT", holder, "LEFT", 11, 0, "managed points preserved with layout conflict")
assertEqual(newButton.width, 33, "managed size preserved with layout conflict")
assertEqual(newSeed.normal.alpha, 0.61, "independent texture state restored")

-- A Begin without Finish is force-restored during rollback.
local unfinishedModule = {}
local unfinished, unfinishedSeed, unfinishedParent = NewButtonFixture("Unfinished")
assertEqual(State:BeginButton(unfinishedModule, 1, unfinished, Components(unfinishedSeed)), true, "unfinished begin")
ApplyManaged(unfinished, unfinishedSeed, holder, 40)
assertEqual(State:RestoreAll(unfinishedModule), true, "unfinished force restore")
assertEqual(unfinished.parent, unfinishedParent, "unfinished parent restored")
assertEqual(unfinished.width, 27, "unfinished size restored")
assertEqual(unfinishedSeed.normal.alpha, 0.61, "unfinished texture restored")

-- A native frame that ignores SetAlpha is rejected and immediately reconciled.
local stubborn = NewObject({ alpha = 0.77 })
function stubborn:SetAlpha() end
local nativeModule = {}
local nativeOK, nativeDetail = State:SuppressNativeBar(nativeModule, stubborn)
assertEqual(nativeOK, false, "unverified native suppression rejected")
assertEqual(nativeDetail, "Native pet-bar alpha could not be verified", "unverified native detail")
assertEqual(stubborn.alpha, 0.77, "stubborn native state unchanged")
assertEqual(nativeModule._petNativeBarState, nil, "failed native state cleared")

-- An unreadable button is rejected before mutation.
local unreadable = { SetParent = function() end }
local unreadableOK, unreadableDetail = State:BeginButton({}, 1, unreadable, {})
assertEqual(unreadableOK, false, "unreadable button rejected")
assertEqual(unreadableDetail, "Pet action button state is unreadable", "unreadable detail")

print("Companion pet-state journal tests passed.")
