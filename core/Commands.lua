-- FeelsGoodUI: slash command router
--
-- Keeps the user-facing slash surface out of the app bootstrap file.

local _, ns = ...

local Commands = {}
ns.Commands = Commands

local function L(text)
    local fn = ns.L
    if type(fn) == "function" then
        return fn(text)
    end
    return text
end

local function Guard(src, fn)
    local safety = ns.Safety
    if safety and safety.Guard then
        return safety.Guard(src, fn)
    end
    return pcall(fn)
end

local function GetSection(section)
    local db = ns.DB
    if not (db and db.GetSection) then
        return nil
    end
    local value = db:GetSection(section)
    if type(value) ~= "table" then
        return nil
    end
    return value
end

local function PrintRecentErrors()
    local Errors = ns.Errors
    local Log = ns.Log
    if not (Errors and Errors.GetAll and Log) then
        return
    end

    local list = Errors:GetAll()
    if #list == 0 then
        Log:Info(L("No captured errors."))
        return
    end

    local start = math.max(1, #list - 15 + 1)
    for i = start, #list do
        local e = list[i]
        Log:Warn(("[%0.1fs] %s: %s"):format(e.t or 0, e.src or "", e.msg or ""))
    end
end

local function BuildCommandMap()
    return {
        debug = {
            group = "diagnostic",
            help = "/fgui debug",
            desc = "toggle debug logging",
            run = function()
                local general = GetSection("general")
                local Log = ns.Log
                local DB = ns.DB
                if not (general and Log and DB and DB.ApplyRuntime) then
                    return
                end
                general.debug = not general.debug
                DB:ApplyRuntime()
                Log:Info(L("Debug = %s"):format(tostring(general.debug)))
            end,
        },
        unlock = {
            group = "user",
            help = "/fgui unlock",
            desc = "unlock movers",
            run = function()
                local Movers = ns.Movers
                if Movers then Movers:SetUnlocked(true) end
            end,
        },
        lock = {
            group = "user",
            help = "/fgui lock",
            desc = "lock movers",
            run = function()
                local Movers = ns.Movers
                if Movers then Movers:SetUnlocked(false) end
            end,
        },
        resetpos = {
            group = "user",
            help = "/fgui resetpos",
            desc = "reset positions to defaults",
            run = function()
                local Movers = ns.Movers
                if Movers and Movers.ResetPositions then
                    Movers:ResetPositions()
                end
            end,
        },
        aura = {
            group = "transitional",
            help = "/fgui aura mini|classic",
            desc = "target aura mode bridge",
            run = function(rest)
                local mode = (rest or ""):match("^(%S+)$")
                local Log = ns.Log
                local UF = ns.UF
                local unitframes = GetSection("unitframes")
                if mode ~= "mini" and mode ~= "classic" then
                    if Log then Log:Warn(L("Usage: /fgui aura mini|classic")) end
                    return
                end
                if not unitframes then
                    return
                end
                unitframes.targetAuras = unitframes.targetAuras or {}
                unitframes.targetAuras.mode = (mode == "mini") and "MINI" or "CLASSIC"
                if UF and UF.ApplyTargetAuraMode then
                    UF:ApplyTargetAuraMode()
                end
                if Log then
                    Log:Info(L("Target auras: %s"):format(unitframes.targetAuras.mode))
                end
            end,
        },
        config = {
            group = "user",
            help = "/fgui config",
            desc = "open addon settings",
            run = function()
                local Options = ns.Options
                if Options and Options.Open then
                    Options:Open()
                end
            end,
        },
        export = {
            group = "user",
            help = "/fgui export",
            desc = "open profile export window",
            run = function()
                local Transfer = ns.ProfileTransfer
                local Log = ns.Log
                if Transfer and Transfer.OpenExportWindow then
                    Transfer:OpenExportWindow()
                elseif Log then
                    Log:Warn(L("Profile transfer module not available."))
                end
            end,
        },
        import = {
            group = "user",
            help = "/fgui import",
            desc = "open profile import window",
            run = function()
                local Transfer = ns.ProfileTransfer
                local Log = ns.Log
                if Transfer and Transfer.OpenImportWindow then
                    Transfer:OpenImportWindow()
                elseif Log then
                    Log:Warn(L("Profile transfer module not available."))
                end
            end,
        },
        minimap = {
            group = "user",
            help = "/fgui minimap show|hide|reset",
            desc = "control minimap icon",
            run = function(rest)
                local Log = ns.Log
                local M = ns.MinimapIcon
                local sub = (rest or ""):match("^(%S+)$") or ""
                if not M then
                    if Log then Log:Warn(L("Minimap icon module not available.")) end
                    return
                end
                if sub == "show" then
                    M:SetHidden(false)
                    return
                end
                if sub == "hide" then
                    M:SetHidden(true)
                    if Log then
                        Log:Info(L("Minimap icon hidden. Use /fgui minimap show to restore."))
                    end
                    return
                end
                if sub == "reset" then
                    M:ResetPosition()
                    return
                end
                if Log then Log:Warn(L("Usage: /fgui minimap show|hide|reset")) end
            end,
        },
        perf = {
            group = "diagnostic",
            help = "/fgui perf",
            desc = "toggle perf overlay",
            run = function()
                local general = GetSection("general")
                local Perf = ns.Perf
                if not general then
                    return
                end
                general.perfOverlay = not (general.perfOverlay == true)
                if Perf and Perf.SetEnabled then
                    Perf:SetEnabled(general.perfOverlay)
                end
            end,
        },
        errors = {
            group = "diagnostic",
            help = "/fgui errors",
            desc = "show last captured errors",
            run = PrintRecentErrors,
        },
        clearerrors = {
            group = "diagnostic",
            help = "/fgui clearerrors",
            desc = "clear captured errors",
            run = function()
                local Errors = ns.Errors
                local Log = ns.Log
                if Errors and Errors.Clear then
                    Errors:Clear()
                    if Log then Log:Info(L("Captured errors cleared.")) end
                end
            end,
        },
        qa = {
            group = "diagnostic",
            help = "/fgui qa",
            desc = "run QA report",
            run = function()
                local QA = ns.QA
                local Log = ns.Log
                if QA and QA.Cmd then
                    QA:Cmd("")
                elseif Log then
                    Log:Warn(L("QA module not available."))
                end
            end,
        },
        report = {
            group = "diagnostic",
            help = "/fgui report",
            desc = "open last QA report",
            run = function()
                local QA = ns.QA
                local Log = ns.Log
                if QA and QA.Cmd then
                    QA:Cmd("report")
                elseif Log then
                    Log:Warn(L("QA module not available."))
                end
            end,
        },
        soak = {
            group = "diagnostic",
            help = "/fgui soak <seconds>|stop",
            desc = "run apply/memory soak",
            run = function(rest)
                local QA = ns.QA
                local Log = ns.Log
                if QA and QA.SoakCmd then
                    QA:SoakCmd(rest)
                elseif Log then
                    Log:Warn(L("QA module not available."))
                end
            end,
        },
        reset = {
            group = "user",
            help = "/fgui reset",
            desc = "reset FeelsGoodUI saved variables",
            run = function()
                local Log = ns.Log
                FeelsGoodUIDB = nil
                if Log then
                    Log:Warn(L("FeelsGoodUIDB cleared. Reloading UI..."))
                end
                ReloadUI()
            end,
        },
    }
end

local COMMAND_GROUPS = {
    user = {
        title = "User Commands:",
        order = { "unlock", "lock", "resetpos", "config", "export", "import", "minimap", "reset" },
    },
    transitional = {
        title = "Transitional Commands:",
        order = { "aura" },
    },
    diagnostic = {
        title = "Diagnostic Commands:",
        order = { "debug", "perf", "errors", "clearerrors", "qa", "report", "soak" },
    },
}

function Commands:GetCommandMap()
    if not self._commands then
        self._commands = BuildCommandMap()
    end
    return self._commands
end

function Commands:PrintHelp()
    local Log = ns.Log
    if not Log then
        return
    end

    local commands = self:GetCommandMap()
    for _, groupKey in ipairs({ "user", "transitional", "diagnostic" }) do
        local group = COMMAND_GROUPS[groupKey]
        Log:Info(L(group.title))
        for i = 1, #group.order do
            local key = group.order[i]
            local cmd = commands[key]
            if cmd then
                Log:Info(("  %s - %s"):format(cmd.help, L(cmd.desc)))
            end
        end
    end
end

function Commands:Handle(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = cmd or ""
    rest = rest or ""

    if cmd == "" or cmd == "help" then
        self:PrintHelp()
        return
    end

    local commands = self:GetCommandMap()
    local entry = commands[cmd]
    if not entry or type(entry.run) ~= "function" then
        self:PrintHelp()
        return
    end

    Guard("Commands." .. tostring(cmd), function()
        entry.run(rest)
    end)
end

function Commands:Register()
    if self._registered then
        return true
    end

    SLASH_FEELSGOODUI1 = "/fgui"
    SlashCmdList.FEELSGOODUI = function(msg)
        Commands:Handle(msg)
    end

    self._registered = true
    return true
end
