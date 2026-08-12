-- FeelsGoodUI: SavedVariables / DB
-- Minimal DB (single profile) for now; can be extended to per-character/per-spec profiles later.

local _, ns = ...

local DB = {}
ns.DB = DB

local U = ns.U
local Log = ns.Log
local Schema = ns.Schema or {}
local CURRENT_SCHEMA_VERSION = tonumber(Schema.CURRENT_VERSION) or 1

-- Defaults chosen to match the reference screenshot: compact unitframes + compact center bars.
DB.defaults = {
    profile = {
        -- Hard-reset schema version. Old profiles are replaced instead of migrated.
        version = CURRENT_SCHEMA_VERSION,
        general = {
            enabled = true,
            debug = false,
            perfOverlay = false,
            safeHandlers = true,
            safeHandlersFast = false,
        },

        -- Minimap quick access button (LibDataBroker + LibDBIcon).
        minimap = {
            hide = false,
            minimapPos = 220, -- degrees around minimap center
            radius = 80,
        },

        -- Media can be either a file path OR a LibSharedMedia key.
        media = {
            font = "Fonts\\FRIZQT__.TTF",
            statusbar = "Interface/Buttons/WHITE8x8",
        },

        unitframes = {
            enabled = true,
            sizes = {
                player = { width = 160, height = 20 },
                target = { width = 160, height = 20 },
                focus = { width = 160, height = 20 },
                targettarget = { width = 160, height = 20 },
                pet = { width = 160, height = 20 },
            },
            scales = {
                player = 0.90,
                target = 0.90,
                focus = 0.90,
                targettarget = 0.90,
                pet = 0.90,
            },

            -- Extra unit frames
            showFocus = true,
            showTargetTarget = true,
            showPet = true,

            auraIconSize = 20,
            auraSpacing = 0,
            auraMax = 8,

            text = {
                font = "Fonts\\FRIZQT__.TTF",
                size = 12,
                outline = "OUTLINE",
            },

            castbar = {
                enabled = true,
                height = 14,
                showIcon = false,
                showText = true,
                showTime = true,
            },

            targetAuras = {
                -- Step 4 default:
                --  MINI   : show only player debuffs above target
                --  CLASSIC: show all target buffs above + all target debuffs below
                -- Back-compat: "PLAYER_DEBUFFS_TOP" is treated as MINI.
                mode = "MINI",
            },


            targetInfo = {
                -- Step 47: target name/info is enabled by default.
                -- Users can still disable it in options.
                enabled = true,
                showName = true,
                showInfo = true,
                showPower = true,
                powerHeight = 10,
                fontSize = 12,
                outline = "OUTLINE",
                nameAnchor = "FRAME", -- "FRAME" | "AURAS"
                fontWeight = "regular", -- "regular" | "bold"
                colorMode = "inherit", -- "inherit" | "custom"
                color = { r = 1.00, g = 1.00, b = 1.00, a = 1.00 },
            },

            combatTimer = {
                enabled = true,
                updateHz = 5, -- updates per second while in combat
            },

            -- Target coloring
            colors = {
                useClassColorForEnemyPlayers = true,
                useReactionColorForNPC = true,
                playerHealth = { r = 0.65, g = 0.00, b = 0.00, a = 1.00 },
                targetFallback = { r = 0.12, g = 0.12, b = 0.12, a = 1.00 },
            },

            playerLowHP = {
                enabled = true,
                threshold = 30, -- percent
                maxAlpha = 0.65,
                color = { r = 1.00, g = 0.12, b = 0.12, a = 1.00 },
            },
        },

        style = {
            -- 0.08 is common for WoW icons; adjust later per-theme.
            iconInset = 0.08,
            borderSize = 1,
        },

        -- Stage 39+: unified theme tokens (preferred). `style` remains for back-compat.
        theme = {
            style = {
                iconInset = 0.08,
                borderSize = 1,
            },
            colors = {
                border  = { r = 0, g = 0, b = 0, a = 1 },
                text    = { r = 1, g = 1, b = 1, a = 1 },
                muted   = { r = 0.75, g = 0.75, b = 0.75, a = 1 },
                comment = { r = 1.00, g = 0.82, b = 0.20, a = 1 },
            },
            fonts = {
                primary = "Fonts\\FRIZQT__.TTF",
                outline = "OUTLINE",
                size    = 12,
                small   = 10,
            },
        },

        -- Stage 39+: formatting options (used gradually across modules).
        format = {
            shortNumbers = {
                enabled = true,
                suffixCase = "lower", -- "lower"|"upper"
                decimalsSmall = 1,
                decimalsLarge = 0,
                -- User policy: abbreviate only on selected unit frames.
                units = {
                    player = true,
                    target = true,
                    targettarget = true,
                    focus = true,
                },
            },
        },

        -- Stage 39+: editor placeholders (Stage 43 will implement).

        -- Stage 39+: editor config (Stage 43 implemented).
        editor = {
            snap = {
                enabled = true,
                threshold = 10, -- pixels
                toGrid = true,
                toFrames = true,
                showGuides = true,
            },
            nudge = {
                step = 1,
                stepLarge = 10,
            },
            resize = {
                enabled = true,
            },
        },

        -- Stage 41+: settings UX options (live preview / apply modes).
        options = {
            -- Per-panel live preview toggles (default true). If false, changes are saved but not applied until "Apply now".
            livePreview = {
                unitframes = true,
                center = true,
                actionbars = true,
                companion = true,
                editmode = true,
            },
        },


        movers = {
            unlocked = false,
            -- Edit grid size (pixels). Used only when unlocked.
            gridStep = 10,
        },

        -- Center resources/power
        center = {
            enabled = true,
            scale = 0.90,

            hideBlizzardClassResources = true,
            showClassBar = true,

            useClassColorForResource = true, -- class color for class-resource bar by default
            useSpecColorForRunes = false, -- optional DK override (blood/frost/unholy)

            width = 420,
            resourceHeight = 10, -- combo points / runes
            powerHeight = 12,    -- energy / runic power
            spacing = 5,

            maxSegments = 10, -- hard cap for class resources
            showPowerText = true,
            showResourceText = false,
            text = {
                font = "Fonts\\FRIZQT__.TTF",
                size = 12,
                outline = "OUTLINE",
            },
            threshold = {
                enabled = false,
                percent = 70, -- percent
                mode = "below", -- "below" | "above"
                spark = true,
                color = { r = 1.00, g = 0.34, b = 0.12, a = 1.00 },
            },
        },

        -- ActionBars (Blizzard-button layout)
        actionbars = {
            hideBlizzard = true,
            buttonSize = 32,
            spacing = 0,
            showHotkeys = false,
            autoHide = {
                enabled = false,
            },

            -- Step 26: unified 7-bar config (bars[1..7]).
            bars = {
                [1] = { enabled = true,  prefix = "ActionButton",               buttons = 12, rows = 1 },
                [2] = { enabled = true,  prefix = "MultiBarBottomLeftButton",    buttons = 12, rows = 1 },
                [3] = { enabled = true,  prefix = "MultiBarBottomRightButton",   buttons = 12, rows = 1 },
            -- Bars 4/5 are expected to exist in FeelsGoodUI layouts (right side two-column stack).
            -- Default them ON to ensure Blizzard creates the buttons and they can be moved/skinned.
            [4] = { enabled = true, prefix = "MultiBarRightButton",          buttons = 12, rows = 12 },
            [5] = { enabled = true, prefix = "MultiBarLeftButton",           buttons = 12, rows = 12 },
        },
        },

        companion = {
            buttonSize = 32,
            spacing = 0,
            microMenu = {
                enabled = true,
            },
            bags = {
                enabled = true,
                compact = true,
            },
            petBar = {
                showHotkeys = false,
                strata = "LOW",
                level = 35,
            },
        },

        experience = {
            enabled = true,
            showText = true,
            showRested = true,
            width = 420,
            height = 10,
        },

        -- Per-element saved positions (applied via core/Movers.lua)
        positions = {
            player = { point = "CENTER", relPoint = "CENTER", x = -260, y = -40 },
            target = { point = "CENTER", relPoint = "CENTER", x =  260, y = -40 },
            focus  = { point = "CENTER", relPoint = "CENTER", x = -440, y = -40 },
            targettarget = { point = "CENTER", relPoint = "CENTER", x =  440, y = -40 },
            pet = { point = "CENTER", relPoint = "CENTER", x = -260, y = -76 },
            center = { point = "CENTER", relPoint = "CENTER", x = 0, y = -140 },
            micromenu = { point = "CENTER", relPoint = "CENTER", x = 0, y = -338 },
            -- Requested stack: 1-2-3 from bottom to top.
            actionbar1 = { point = "CENTER", relPoint = "CENTER", x = 0, y = -258 },
            actionbar2 = { point = "CENTER", relPoint = "CENTER", x = 0, y = -220 },
            actionbar3 = { point = "CENTER", relPoint = "CENTER", x = 0, y = -182 },

            -- Side bars (right edge, two columns)
            actionbar4 = { point = "RIGHT", relPoint = "RIGHT", x = -90, y = 0 },
            actionbar5 = { point = "RIGHT", relPoint = "RIGHT", x = -50, y = 0 },

            -- Pet action bar (skinned; visibility is driven by pet existence)
            petbar = { point = "CENTER", relPoint = "CENTER", x = 0, y = -160 },
            xpbar = { point = "CENTER", relPoint = "CENTER", x = 0, y = -296 },
        },
    }
}

function DB:Init()
    -- Global saved var (declared in .toc)
    if type(FeelsGoodUIDB) ~= "table" then
        FeelsGoodUIDB = {}
    end
    local schemaState = (type(Schema.GetProfileState) == "function")
        and Schema.GetProfileState(FeelsGoodUIDB.profile)
        or {
            currentVersion = CURRENT_SCHEMA_VERSION,
            hadProfile = (type(FeelsGoodUIDB.profile) == "table"),
            oldVersion = (type(FeelsGoodUIDB.profile) == "table") and tonumber(FeelsGoodUIDB.profile.version) or nil,
            needsReset = (type(FeelsGoodUIDB.profile) ~= "table") or tonumber(FeelsGoodUIDB.profile.version) ~= CURRENT_SCHEMA_VERSION,
        }

    -- Old schemas are not migrated anymore. They are replaced with current defaults.
    if schemaState.needsReset then
        if type(Schema.CreateFreshProfile) == "function" then
            FeelsGoodUIDB.profile = Schema.CreateFreshProfile(self.defaults.profile)
        else
            FeelsGoodUIDB.profile = U.DeepCopy(self.defaults.profile)
            FeelsGoodUIDB.profile.version = CURRENT_SCHEMA_VERSION
        end

        local applied = FeelsGoodUIDB.profile
            and FeelsGoodUIDB.profile.install
            and FeelsGoodUIDB.profile.install.resolutionPreset

        if schemaState.hadProfile and schemaState.oldVersion ~= schemaState.currentVersion then
            Log:Warn(("Profile schema reset: v%s -> v%s"):format(tostring(schemaState.oldVersion), tostring(schemaState.currentVersion)))
        elseif applied then
            Log:Info(("First-install resolution preset: %s"):format(tostring(applied)))
        end
    else
        U.MergeDefaults(FeelsGoodUIDB, self.defaults)
    end

    local p = FeelsGoodUIDB.profile
    -- Normalize the live schema and repair bad persisted values.
    local Settings = ns.Settings
    if Settings and Settings.NormalizeAll then
        Settings:NormalizeAll()
    end
    if type(Schema.NormalizeProfile) == "function" then
        Schema.NormalizeProfile(p, self.defaults and self.defaults.profile)
    else
        p.version = CURRENT_SCHEMA_VERSION
    end

    self.data = FeelsGoodUIDB
    return self.data
end

function DB:GetProfile()
    return (self.data and self.data.profile) or self.defaults.profile
end

function DB:EnsureProfileRoot()
    self.data = (type(self.data) == "table") and self.data or {}

    local profile = self.data.profile
    if type(profile) == "table" then
        return profile
    end

    local defaults = self.defaults and self.defaults.profile
    if type(defaults) == "table" then
        if type(Schema.CreateFreshProfile) == "function" then
            profile = Schema.CreateFreshProfile(defaults)
        else
            profile = U.DeepCopy(defaults)
            profile.version = CURRENT_SCHEMA_VERSION
        end
    else
        profile = {}
    end

    self.data.profile = profile
    return profile
end

function DB:EnsureSection(section)
    if type(section) ~= "string" or section == "" then
        return nil
    end

    local profile = self:GetProfile()
    if type(profile) ~= "table" then
        return nil
    end

    local value = profile[section]
    if type(value) == "table" then
        return value
    end

    local defaults = self.defaults and self.defaults.profile
    local fallback = defaults and defaults[section] or nil
    if type(fallback) == "table" then
        value = U.DeepCopy(fallback)
    else
        value = {}
    end

    profile[section] = value
    return value
end

function DB:GetSection(section)
    if type(section) ~= "string" or section == "" then
        return nil
    end

    local profile = self:GetProfile()
    if type(profile) ~= "table" then
        return nil
    end

    local value = profile[section]
    if value ~= nil then
        return value
    end

    local defaults = self.defaults and self.defaults.profile
    local fallback = defaults and defaults[section] or nil
    if type(fallback) == "table" then
        return self:EnsureSection(section)
    end

    return fallback
end

function DB:ShouldHideBlizzardActionBars()
    local actionbars = self:GetSection("actionbars")
    return not (type(actionbars) == "table" and actionbars.hideBlizzard == false)
end

function DB:ApplyRuntime()
    local p = self:GetProfile()
    if p.general and p.general.debug then
        Log:SetLevel("DEBUG")
    else
        Log:SetLevel("INFO")
    end
end
