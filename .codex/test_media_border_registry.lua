local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertNil(value, label)
    if value ~= nil then
        error((label or "value") .. ": expected nil, got " .. tostring(value), 2)
    end
end

local created = 0
local function NewBorder(parent)
    local border = {
        parent = parent,
        points = {},
        clearCalls = 0,
        level = nil,
        backdrop = nil,
        color = nil,
        colorWrites = 0,
    }
    function border:SetFrameLevel(level) self.level = level end
    function border:ClearAllPoints() self.clearCalls = self.clearCalls + 1; self.points = {} end
    function border:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function border:SetBackdrop(backdrop)
        self.backdrop = {
            edgeFile = backdrop.edgeFile,
            edgeSize = backdrop.edgeSize,
        }
    end
    function border:GetBackdrop()
        if not self.backdrop then return nil end
        return {
            edgeFile = self.backdrop.edgeFile,
            edgeSize = self.backdrop.edgeSize,
        }
    end
    function border:SetBackdropBorderColor(r, g, b, a)
        self.colorWrites = self.colorWrites + 1
        self.color = { r, g, b, a }
    end
    return border
end

_G = _G or {}
_G.LibStub = nil
_G.CreateFrame = function(frameType, name, parent, template)
    assertEqual(frameType, "Frame", "border frame type")
    assertNil(name, "anonymous border")
    assertEqual(template, "BackdropTemplate", "border template")
    created = created + 1
    return NewBorder(parent)
end

local themeState = {
    style = { borderSize = 2 },
    colors = { border = { r = 0.10, g = 0.20, b = 0.30, a = 0.80 } },
}
local ns = {
    U = {
        IconTexCoord = function() return 0, 1, 0, 1 end,
    },
    Theme = {
        Get = function() return themeState end,
    },
}

assert(loadfile("core/Media.lua"))("FeelsGoodUI", ns)
local Media = assert(ns.Media)
assertEqual(getmetatable(Media._borderRegistry).__mode, "k", "weak-key registry")

local parentA = { level = 7 }
function parentA:GetFrameLevel() return self.level end
local parentB = { level = 12 }
function parentB:GetFrameLevel() return self.level end

local borderA = Media:CreateBorder(parentA)
assertEqual(created, 1, "one border allocated")
assertEqual(Media:GetBorder(parentA), borderA, "border lookup")
assertEqual(borderA.level, 8, "border frame level")
assertEqual(borderA.backdrop.edgeSize, 2, "default theme size")
assertEqual(borderA.points[1][1], "TOPLEFT", "top-left anchor")
assertEqual(borderA.points[1][2], -2, "top-left x")
assertEqual(borderA.points[1][3], 2, "top-left y")
assertEqual(borderA.points[2][1], "BOTTOMRIGHT", "bottom-right anchor")
assertEqual(borderA.points[2][2], 2, "bottom-right x")
assertEqual(borderA.points[2][3], -2, "bottom-right y")
assertEqual(borderA.color[1], 0.10, "theme red")
assertEqual(borderA.color[4], 0.80, "theme alpha")
assertNil(rawget(parentA, "__fguiBorder"), "parent has no border marker")
assertNil(rawget(parentA, "__fguiBorderSize"), "parent has no size marker")

local initialClearCalls = borderA.clearCalls
local initialColorWrites = borderA.colorWrites
local sameBorder = Media:CreateBorder(parentA, 2)
assertEqual(sameBorder, borderA, "same-size border reused")
assertEqual(created, 1, "same-size no allocation")
assertEqual(borderA.clearCalls, initialClearCalls, "same-size geometry unchanged")
assertEqual(borderA.colorWrites, initialColorWrites + 1, "same-size theme color refreshed")

local resizedBorder = Media:CreateBorder(parentA, 4)
assertEqual(resizedBorder, borderA, "resized border reused")
assertEqual(created, 1, "resize no allocation")
assertEqual(borderA.clearCalls, initialClearCalls + 1, "resize reapplies geometry once")
assertEqual(borderA.backdrop.edgeSize, 4, "resize updates edge size")
assertEqual(borderA.points[1][2], -4, "resized top-left x")
assertEqual(borderA.points[2][3], -4, "resized bottom-right y")

assertEqual(Media:SetBorderColor(parentA, 0, 0, 0, 0), true, "explicit color update")
assertEqual(borderA.color[1], 0, "explicit red")
assertEqual(borderA.color[4], 0, "explicit alpha")
assertEqual(Media:SetBorderColor({}, 1, 1, 1, 1), false, "unknown frame color rejected")
assertNil(Media:GetBorder({}), "unknown frame lookup")

-- A future style pass restores theme color on the same border object.
themeState.colors.border = { r = 0.90, g = 0.80, b = 0.70, a = 1 }
assertEqual(Media:CreateBorder(parentA, 4), borderA, "theme refresh border reused")
assertEqual(borderA.color[1], 0.90, "theme refresh red")
assertEqual(borderA.color[4], 1, "theme refresh alpha")

local borderB = Media:CreateBorder(parentB, 1)
assertEqual(created, 2, "second parent gets one border")
assertEqual(Media:GetBorder(parentB), borderB, "second border lookup")
assertEqual(borderB.level, 13, "second frame level")
assertEqual(Media:GetBorder(parentA), borderA, "first registry entry retained")
assertNil(rawget(parentB, "__fguiBorder"), "second parent has no marker")

print("Media border registry tests passed.")
