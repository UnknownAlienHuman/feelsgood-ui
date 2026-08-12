-- FeelsGoodUI: Theme (unified style tokens)
--
-- Stage 39: Foundation refactor
-- Goal: one place to define style primitives used across modules (borders, icon crop, fonts, colors).
-- Notes:
--  - Keep tokens minimal and Secret-safe (no arithmetic on unknown values).
--  - Tokens are computed from DB on login (/reload) and can be refreshed later.
--
-- Author: Neomorph

local _, ns = ...

local Theme = {}
ns.Theme = Theme

local DB = ns.DB
local U  = ns.U

local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local DEFAULT_OUTLINE = "OUTLINE"
local DEFAULT_STATUSBAR = "Interface/Buttons/WHITE8x8"

-- Default tokens (safe, minimal).
Theme.tokens = {
    style = {
        iconInset  = 0.08,
        borderSize = 1,
    },
    colors = {
        border  = { r = 0, g = 0, b = 0, a = 1 },
        text    = { r = 1, g = 1, b = 1, a = 1 },
        muted   = { r = 0.75, g = 0.75, b = 0.75, a = 1 },
        comment = { r = 1.00, g = 0.82, b = 0.20, a = 1 }, -- yellow-ish
    },
    fonts = {
        primary = DEFAULT_FONT,
        outline = DEFAULT_OUTLINE,
        size    = 12,
        small   = 10,
    },
    statusbars = {
        primary = DEFAULT_STATUSBAR,
    },
}

local function ClampNumber(v, minV, maxV, fallback)
    local ok, n = U.TryNumber(v)
    if not ok then return fallback end
    if minV ~= nil then
        local okMin, mn = U.TryNumber(minV)
        if okMin and n < mn then n = mn end
    end
    if maxV ~= nil then
        local okMax, mx = U.TryNumber(maxV)
        if okMax and n > mx then n = mx end
    end
    return n
end

local function NormalizeStringToken(v, fallback)
    if type(v) == "string" and v ~= "" then
        return v
    end
    return fallback
end

-- Refresh tokens from DB (if available).
function Theme:RefreshFromDB()
    if not DB or not DB.GetSection then return end

    -- Style primitives
    local style = nil
    local theme = DB:GetSection("theme")
    local media = DB:GetSection("media")
    if type(theme) == "table" and type(theme.style) == "table" then
        style = theme.style
    else
        local baseStyle = DB:GetSection("style")
        if type(baseStyle) == "table" then
        -- Back-compat (pre v23)
            style = baseStyle
        end
    end

    if type(style) == "table" then
        -- iconInset: typical 0.08..0.10
        self.tokens.style.iconInset  = ClampNumber(style.iconInset, 0.00, 0.20, self.tokens.style.iconInset)
        -- borderSize: keep sane (1..4)
        self.tokens.style.borderSize = ClampNumber(style.borderSize, 1, 4, self.tokens.style.borderSize)
    end

    local themeFonts = (type(theme) == "table" and type(theme.fonts) == "table") and theme.fonts or nil
    local themeStatusbars = (type(theme) == "table" and type(theme.statusbars) == "table") and theme.statusbars or nil

    self.tokens.fonts.primary = NormalizeStringToken(
        type(media) == "table" and media.font or nil,
        NormalizeStringToken(themeFonts and themeFonts.primary, DEFAULT_FONT)
    )
    self.tokens.fonts.outline = NormalizeStringToken(themeFonts and themeFonts.outline, DEFAULT_OUTLINE)
    self.tokens.fonts.size = ClampNumber(themeFonts and themeFonts.size, 6, 48, self.tokens.fonts.size)
    self.tokens.fonts.small = ClampNumber(themeFonts and themeFonts.small, 6, 32, self.tokens.fonts.small)
    self.tokens.statusbars.primary = NormalizeStringToken(
        type(media) == "table" and media.statusbar or nil,
        NormalizeStringToken(themeStatusbars and themeStatusbars.primary, DEFAULT_STATUSBAR)
    )
end

function Theme:Get()
    return self.tokens
end

function Theme:GetFontToken()
    return (self.tokens.fonts and self.tokens.fonts.primary) or DEFAULT_FONT
end

function Theme:GetFontOutline()
    return (self.tokens.fonts and self.tokens.fonts.outline) or DEFAULT_OUTLINE
end

function Theme:GetFontSize()
    local size = self.tokens.fonts and self.tokens.fonts.size
    return (type(size) == "number") and size or 12
end

function Theme:GetStatusbarToken()
    return (self.tokens.statusbars and self.tokens.statusbars.primary) or DEFAULT_STATUSBAR
end
