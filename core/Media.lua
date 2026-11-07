-- FeelsGoodUI: Media / Styling helpers
--
-- Goals:
--  - Minimal pixel UI (1px black borders, square icons)
--  - No heavy backdrops or textures by default
--  - Optional LibSharedMedia-3.0 support for fonts/statusbars

local _, ns = ...

local Media = {}
ns.Media = Media

local U = ns.U
local Theme = ns.Theme

-- Optional: LibSharedMedia
local LSM
if _G.LibStub then
    LSM = _G.LibStub("LibSharedMedia-3.0", true)
end
Media.LSM = LSM

Media._borderRegistry = Media._borderRegistry or setmetatable({}, { __mode = "k" })
local BorderRegistry = Media._borderRegistry

-- -----------------------------
-- Base primitives
-- -----------------------------

-- Create a solid-color texture (1x1) that can be stretched.
function Media:CreateColorTex(parent, r, g, b, a, drawLayer, subLevel)
    local tex = parent:CreateTexture(nil, drawLayer or "ARTWORK", nil, subLevel or 0)
    tex:SetColorTexture(r or 1, g or 1, b or 1, a or 1)
    tex:SetAllPoints()
    return tex
end

local function ResolveBorderColor(theme)
    local color = theme and theme.colors and theme.colors.border or nil
    if type(color) ~= "table" then
        return 0, 0, 0, 1
    end
    return color.r or 0, color.g or 0, color.b or 0, color.a or 1
end

local function ApplyBorderGeometry(border, size)
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", -size, size)
    border:SetPoint("BOTTOMRIGHT", size, -size)
    if border.SetBackdrop then
        local backdrop = border:GetBackdrop() or {
            edgeFile = "Interface/Buttons/WHITE8x8",
            edgeSize = size,
        }
        backdrop.edgeSize = size
        border:SetBackdrop(backdrop)
    end
end

function Media:GetBorder(frame)
    local record = frame and BorderRegistry[frame] or nil
    return record and record.border or nil
end

function Media:SetBorderColor(frame, r, g, b, a)
    local border = self:GetBorder(frame)
    if not (border and type(border.SetBackdropBorderColor) == "function") then
        return false
    end
    border:SetBackdropBorderColor(r or 0, g or 0, b or 0, a or 0)
    return true
end

-- 1px border (simple, fast, no complex backdrops). Border ownership stays in
-- Media's weak-key registry; foreign Blizzard frames are never stamped with
-- addon-specific fields.
function Media:CreateBorder(frame, size)
    if not frame then return nil end

    local theme = Theme and Theme.Get and Theme:Get() or nil
    local defaultSize = (theme and theme.style and theme.style.borderSize) or 1
    size = (type(size) == "number") and size or defaultSize

    local record = BorderRegistry[frame]
    local border = record and record.border or nil
    if border then
        if record.size ~= size then
            ApplyBorderGeometry(border, size)
            record.size = size
        end
        local r, g, b, a = ResolveBorderColor(theme)
        if border.SetBackdropBorderColor then
            border:SetBackdropBorderColor(r, g, b, a)
        end
        return border
    end

    border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    border:SetFrameLevel(frame:GetFrameLevel() + 1)
    border:SetBackdrop({
        edgeFile = "Interface/Buttons/WHITE8x8",
        edgeSize = size,
    })
    ApplyBorderGeometry(border, size)

    local r, g, b, a = ResolveBorderColor(theme)
    border:SetBackdropBorderColor(r, g, b, a)

    BorderRegistry[frame] = {
        border = border,
        size = size,
    }
    return border
end

function Media:ApplyIconCrop(tex, inset)
    if not tex then return end
    local tkn = Theme and Theme.Get and Theme:Get() or nil
    local defaultInset = (tkn and tkn.style and tkn.style.iconInset) or 0.08
    local l, r, t, b = U.IconTexCoord(inset or defaultInset)
    tex:SetTexCoord(l, r, t, b)
end

-- -----------------------------
-- LibSharedMedia helpers
-- -----------------------------

local function LooksLikeFilePath(s)
    if type(s) ~= "string" then return false end
    if s:find("\\") or s:find("/") then return true end
    local lower = s:lower()
    if lower:find("%.ttf") or lower:find("%.otf") or lower:find("%.tga") or lower:find("%.blp") then
        return true
    end
    return false
end

function Media:FetchFont(nameOrPath)
    if type(nameOrPath) ~= "string" or nameOrPath == "" then
        return "Fonts\\FRIZQT__.TTF"
    end

    if LooksLikeFilePath(nameOrPath) then
        return nameOrPath
    end

    if LSM then
        local ok, path = pcall(function()
            return LSM:Fetch("font", nameOrPath, true)
        end)
        if ok and type(path) == "string" and path ~= "" then
            return path
        end
    end

    -- Fallback: treat input as path.
    return nameOrPath
end

function Media:FetchStatusbar(nameOrPath)
    if type(nameOrPath) ~= "string" or nameOrPath == "" then
        return "Interface/Buttons/WHITE8x8"
    end

    if LooksLikeFilePath(nameOrPath) then
        return nameOrPath
    end

    if LSM then
        local ok, path = pcall(function()
            return LSM:Fetch("statusbar", nameOrPath, true)
        end)
        if ok and type(path) == "string" and path ~= "" then
            return path
        end
    end

    return nameOrPath
end

function Media:GetFontList()
    local out = {}
    if LSM and LSM.HashTable then
        local ok, tbl = pcall(function() return LSM:HashTable("font") end)
        if ok and type(tbl) == "table" then
            for name in pairs(tbl) do
                out[#out + 1] = name
            end
            table.sort(out)
        end
    end
    if #out == 0 then
        out[1] = "Fonts\\FRIZQT__.TTF"
    end
    return out
end

function Media:GetStatusbarList()
    local out = {}
    if LSM and LSM.HashTable then
        local ok, tbl = pcall(function() return LSM:HashTable("statusbar") end)
        if ok and type(tbl) == "table" then
            for name in pairs(tbl) do
                out[#out + 1] = name
            end
            table.sort(out)
        end
    end
    if #out == 0 then
        out[1] = "Interface/Buttons/WHITE8x8"
    end
    return out
end

function Media:ApplyFont(fs, fontNameOrPath, size, outline)
    if not fs then return end
    local fontPath = self:FetchFont(fontNameOrPath)
    size = (type(size) == "number") and size or 12
    outline = outline or "OUTLINE"
    fs:SetFont(fontPath, size, outline)
end
