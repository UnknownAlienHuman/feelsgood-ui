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

-- 1px border (simple, fast, no complex backdrops).
function Media:CreateBorder(frame, size)
    -- Default to theme border size when not specified.
    local t = Theme and Theme.Get and Theme:Get() or nil
    local defaultSize = (t and t.style and t.style.borderSize) or 1
    size = (type(size) == "number") and size or defaultSize

    -- If border already exists, allow lightweight updates (size/color) without realloc.
    if frame.__fguiBorder then
        local b = frame.__fguiBorder
        if frame.__fguiBorderSize ~= size then
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", -size, size)
            b:SetPoint("BOTTOMRIGHT", size, -size)
            if b.SetBackdrop then
                local bd = b:GetBackdrop() or { edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = size }
                bd.edgeSize = size
                b:SetBackdrop(bd)
            end
            frame.__fguiBorderSize = size
        end
        -- Color refresh
        local bc = (t and t.colors and t.colors.border) or { r=0,g=0,b=0,a=1 }
        if b.SetBackdropBorderColor then
            b:SetBackdropBorderColor(bc.r or 0, bc.g or 0, bc.b or 0, bc.a or 1)
        end
        return b
    end

    local b = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    b:SetFrameLevel(frame:GetFrameLevel() + 1)
    b:SetPoint("TOPLEFT", -size, size)
    b:SetPoint("BOTTOMRIGHT", size, -size)

    b:SetBackdrop({
        edgeFile = "Interface/Buttons/WHITE8x8",
        edgeSize = size,
    })
    local bc = (t and t.colors and t.colors.border) or { r=0,g=0,b=0,a=1 }
    b:SetBackdropBorderColor(bc.r or 0, bc.g or 0, bc.b or 0, bc.a or 1)

    frame.__fguiBorder = b
    frame.__fguiBorderSize = size
    return b
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
