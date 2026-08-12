-- FeelsGoodUI: Logging
-- Lightweight structured logger (chat + optional DevTools dump).
-- Performance: strings only, no table allocation in hot path.

local _, ns = ...

local Log = {}
ns.Log = Log

Log.levels = {
    ERROR = 1,
    WARN  = 2,
    INFO  = 3,
    DEBUG = 4,
}

-- Default to INFO. DB may override on load.
Log.currentLevel = Log.levels.INFO

local PREFIX = "|cff00d1b2FGUI|r"

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. " " .. tostring(msg))
    end
end

function Log:SetLevel(level)
    local lv = self.levels[level]
    if lv then
        self.currentLevel = lv
        return true
    end
    return false
end

function Log:Can(level)
    return self.currentLevel >= (self.levels[level] or 0)
end

function Log:Error(msg) if self:Can("ERROR") then Print("|cffff4040" .. tostring(msg) .. "|r") end end
function Log:Warn(msg)  if self:Can("WARN")  then Print("|cffffb000" .. tostring(msg) .. "|r") end end
function Log:Info(msg)  if self:Can("INFO")  then Print(tostring(msg)) end end
function Log:Debug(msg) if self:Can("DEBUG") then Print("|cff80bfff" .. tostring(msg) .. "|r") end end

-- Safe table dump for DevTools (avoid unless requested).
function Log:Dump(label, tbl)
    if not self:Can("DEBUG") then return end
    if DevTools_Dump then
        DevTools_Dump({ label = label, value = tbl })
    else
        self:Debug(label .. ": DevTools_Dump not available.")
    end
end
