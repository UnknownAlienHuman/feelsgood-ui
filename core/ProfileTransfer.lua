-- FeelsGoodUI: Profile export/import
-- Uses Blizzard C_EncodingUtil (CBOR + Deflate + Base64), no loadstring.

local _, ns = ...

local ProfileTransfer = {}
ns.ProfileTransfer = ProfileTransfer

local DB = ns.DB
local Schema = ns.Schema or {}
local U = ns.U
local Log = ns.Log
local Settings = ns.Settings
local Movers = ns.Movers
local L = ns.L or function(text) return text end

local PREFIX = "FGUI_PROFILE_V1:"
local MAX_IMPORT_TEXT_LEN = 1024 * 1024
local MAX_COMPRESSED_LEN = 1024 * 1024
local MAX_INFLATED_LEN = 8 * 1024 * 1024

local function GetEncodingUtil()
    local e = _G.C_EncodingUtil
    if not e then return nil end
    if type(e.SerializeCBOR) ~= "function" then return nil end
    if type(e.DeserializeCBOR) ~= "function" then return nil end
    if type(e.CompressString) ~= "function" then return nil end
    if type(e.DecompressString) ~= "function" then return nil end
    if type(e.EncodeBase64) ~= "function" then return nil end
    if type(e.DecodeBase64) ~= "function" then return nil end
    return e
end

local function IsFiniteNumber(v)
    if type(v) ~= "number" then return false end
    local ok, finite = pcall(function()
        return (v == v) and (v < math.huge) and (v > -math.huge)
    end)
    return ok and finite == true
end

local function IsValidKey(k)
    local t = type(k)
    if t == "string" or t == "boolean" then
        return true
    end
    if t == "number" then
        return IsFiniteNumber(k)
    end
    return false
end

local function ValidateTree(v, depth, seen, state)
    depth = depth or 0
    seen = seen or {}
    state = state or { nodes = 0 }

    if depth > 64 then
        return false
    end

    state.nodes = state.nodes + 1
    if state.nodes > 200000 then
        return false
    end

    local t = type(v)
    if t == "nil" or t == "boolean" or t == "string" then
        return true
    end
    if t == "number" then
        return IsFiniteNumber(v)
    end
    if t ~= "table" then
        return false
    end

    if seen[v] then
        return true
    end
    seen[v] = true

    for k, value in pairs(v) do
        if not IsValidKey(k) then
            return false
        end
        if not ValidateTree(value, depth + 1, seen, state) then
            return false
        end
    end

    return true
end

local function EncodeProfileTable(tbl)
    local e = GetEncodingUtil()
    if not e then
        return nil, L("Encoding API is not available in this client.")
    end

    local serialized = e.SerializeCBOR(tbl)
    if type(serialized) ~= "string" or serialized == "" then
        return nil, L("Failed to serialize profile.")
    end

    local compressed = e.CompressString(serialized)
    if type(compressed) ~= "string" or compressed == "" then
        return nil, L("Failed to compress serialized profile.")
    end

    local encoded = e.EncodeBase64(compressed)
    if type(encoded) ~= "string" or encoded == "" then
        return nil, L("Failed to encode profile.")
    end

    return PREFIX .. encoded
end

local function DecodeProfileTable(text)
    local e = GetEncodingUtil()
    if not e then
        return nil, L("Encoding API is not available in this client.")
    end

    local payload = tostring(text or "")
    payload = payload:gsub("%s+", "")
    if payload == "" then
        return nil, L("Import text is empty.")
    end
    if payload:sub(1, #PREFIX) == PREFIX then
        payload = payload:sub(#PREFIX + 1)
    end
    if #payload > MAX_IMPORT_TEXT_LEN then
        return nil, L("Import payload is too large.")
    end

    local decoded = e.DecodeBase64(payload)
    if type(decoded) ~= "string" or decoded == "" then
        return nil, L("Invalid Base64 payload.")
    end
    if #decoded > MAX_COMPRESSED_LEN then
        return nil, L("Compressed payload is too large.")
    end

    local inflated = e.DecompressString(decoded)
    if type(inflated) ~= "string" or inflated == "" then
        return nil, L("Failed to decompress payload.")
    end
    if #inflated > MAX_INFLATED_LEN then
        return nil, L("Decoded payload is too large.")
    end

    local value = e.DeserializeCBOR(inflated)
    if type(value) ~= "table" then
        return nil, L("Decoded payload is not a profile table.")
    end

    if not ValidateTree(value, 0, {}, { nodes = 0 }) then
        return nil, L("Payload contains unsupported values.")
    end

    return value
end

local function NormalizeByDefaults(value, defaults, depth)
    depth = depth or 0
    if depth > 64 then
        return defaults
    end

    local dt = type(defaults)
    if dt ~= "table" then
        if type(value) == dt then
            return value
        end
        return defaults
    end

    if type(value) ~= "table" then
        value = {}
    end

    local out = {}

    -- Preserve unknown keys (forward compatibility for future schema fields).
    for k, v in pairs(value) do
        if defaults[k] == nil then
            out[k] = v
        end
    end

    for k, defaultValue in pairs(defaults) do
        out[k] = NormalizeByDefaults(value[k], defaultValue, depth + 1)
    end

    return out
end

local function WipeTable(t)
    if type(t) ~= "table" then return end
    if type(_G.wipe) == "function" then
        _G.wipe(t)
        return
    end
    for k in pairs(t) do
        t[k] = nil
    end
end

local function BuildImportCompatibilityError(state)
    state = (type(state) == "table") and state or {}
    local importedVersion = tostring(state.oldVersion or "?")
    local currentVersion = tostring(state.currentVersion or "?")

    if state.status == "future_version" then
        return L(("Imported profile schema v%s is newer than this addon build (current v%s)."):format(importedVersion, currentVersion))
    end
    if state.status == "unsupported_older" then
        return L(("Imported profile schema v%s is no longer supported by the live FeelsGoodUI tree (current v%s)."):format(importedVersion, currentVersion))
    end
    if state.status == "missing_or_invalid" then
        return L(("Imported profile does not contain a supported schema version (current v%s)."):format(currentVersion))
    end
    return L("Imported profile schema is incompatible with this addon build.")
end

function ProfileTransfer:ExportCurrentProfile()
    local prof = DB and DB.GetProfile and DB:GetProfile()
    if type(prof) ~= "table" then
        return nil, L("Profile is not available.")
    end

    local snapshot = U and U.DeepCopy and U.DeepCopy(prof) or prof
    return EncodeProfileTable(snapshot)
end

function ProfileTransfer:ImportToCurrentProfile(text)
    local decoded, err = DecodeProfileTable(text)
    if not decoded then
        return false, err
    end

    local schemaState = (type(Schema.GetProfileState) == "function")
        and Schema.GetProfileState(decoded)
        or nil
    if type(schemaState) == "table" and schemaState.canImport ~= true then
        return false, BuildImportCompatibilityError(schemaState)
    end

    local prof = DB and DB.GetProfile and DB:GetProfile()
    if type(prof) ~= "table" then
        return false, L("Profile is not available.")
    end

    local snapshot = U and U.DeepCopy and U.DeepCopy(decoded) or decoded
    local defaults = DB and DB.defaults and DB.defaults.profile
    if type(defaults) == "table" then
        snapshot = NormalizeByDefaults(snapshot, defaults, 0)
    end

    local backup = U and U.DeepCopy and U.DeepCopy(prof) or nil
    local function RestoreBackup()
        if type(backup) == "table" then
            WipeTable(prof)
            for k, v in pairs(backup) do
                prof[k] = v
            end
        end
        if DB and DB.Init then
            pcall(DB.Init, DB)
        end
        if DB and DB.ApplyRuntime then
            pcall(DB.ApplyRuntime, DB)
        end
    end

    WipeTable(prof)
    for k, v in pairs(snapshot) do
        prof[k] = v
    end

    -- Re-run DB init so the imported current-schema payload is normalized and runtime services refresh.
    if DB and DB.Init then
        local okInit = pcall(DB.Init, DB)
        if not okInit then
            RestoreBackup()
            return false, L("Failed to apply imported profile. Previous profile has been restored.")
        end
    elseif U and U.MergeDefaults and DB and DB.defaults and DB.defaults.profile then
        local okFallback = pcall(function()
            U.MergeDefaults(prof, DB.defaults.profile)
            if Settings and Settings.NormalizeAll then
                Settings:NormalizeAll()
            end
        end)
        if not okFallback then
            RestoreBackup()
            return false, L("Failed to apply imported profile. Previous profile has been restored.")
        end
    end
    if DB and DB.ApplyRuntime then
        local okRuntime = pcall(DB.ApplyRuntime, DB)
        if not okRuntime then
            RestoreBackup()
            return false, L("Failed to apply imported profile. Previous profile has been restored.")
        end
    end
    if Movers and Movers.ApplyUnlockFromDB then
        pcall(Movers.ApplyUnlockFromDB, Movers)
    end

    if Settings and Settings.InvalidateAllHistory then
        Settings:InvalidateAllHistory()
    end

    if ns.Apply and ns.Apply.RequestAll then
        pcall(ns.Apply.RequestAll, ns.Apply)
    elseif ns.ApplyAll then
        pcall(ns.ApplyAll)
    end

    return true
end

local function EnsureWindow()
    if ProfileTransfer._window then return ProfileTransfer._window end

    local f = CreateFrame("Frame", "FGUI_ProfileTransferFrame", UIParent, "BackdropTemplate")
    f:SetSize(760, 520)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:Hide()

    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
    title:SetText(L("FeelsGoodUI - Profile Transfer"))
    f._title = title

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -36)
    hint:SetPoint("RIGHT", f, "RIGHT", -36, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText(L("Export creates a compressed Base64 string. Import applies immediately to the current profile."))

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -56)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 48)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject("ChatFontNormal")
    edit:SetWidth(690)
    edit:SetText("")
    edit:SetScript("OnEscapePressed", function() f:Hide() end)
    scroll:SetScrollChild(edit)
    f._edit = edit

    local status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 44)
    status:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 44)
    status:SetJustifyH("LEFT")
    status:SetText("")
    f._status = status

    local selectAll = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    selectAll:SetSize(120, 24)
    selectAll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 16)
    selectAll:SetText(L("Select All"))
    selectAll:SetScript("OnClick", function()
        f._edit:SetFocus()
        f._edit:HighlightText(0, -1)
    end)

    local exportBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    exportBtn:SetSize(140, 24)
    exportBtn:SetPoint("LEFT", selectAll, "RIGHT", 8, 0)
    exportBtn:SetText(L("Export Current"))
    exportBtn:SetScript("OnClick", function()
        local payload, err = ProfileTransfer:ExportCurrentProfile()
        if not payload then
            f._status:SetText(err or L("Export failed."))
            f._status:SetTextColor(1, 0.25, 0.25)
            return
        end
        f._edit:SetText(payload)
        f._edit:SetFocus()
        f._edit:HighlightText(0, -1)
        f._status:SetText(L("Profile exported. Copy the text and keep it safe."))
        f._status:SetTextColor(0.35, 1, 0.35)
    end)

    local importBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    importBtn:SetSize(140, 24)
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 8, 0)
    importBtn:SetText(L("Import Text"))
    importBtn:SetScript("OnClick", function()
        local ok, err = ProfileTransfer:ImportToCurrentProfile(f._edit:GetText() or "")
        if not ok then
            f._status:SetText(err or L("Import failed."))
            f._status:SetTextColor(1, 0.25, 0.25)
            return
        end
        f._status:SetText(L("Profile imported and applied."))
        f._status:SetTextColor(0.35, 1, 0.35)
        if Log and Log.Info then
            Log:Info(L("Profile imported and applied."))
        end
    end)

    ProfileTransfer._window = f
    return f
end

function ProfileTransfer:OpenExportWindow()
    local f = EnsureWindow()
    local payload, err = self:ExportCurrentProfile()
    if payload then
        f._edit:SetText(payload)
        f._status:SetText(L("Profile exported. Copy the text and keep it safe."))
        f._status:SetTextColor(0.35, 1, 0.35)
        f._edit:SetFocus()
        f._edit:HighlightText(0, -1)
    else
        f._edit:SetText("")
        f._status:SetText(err or L("Export failed."))
        f._status:SetTextColor(1, 0.25, 0.25)
    end
    f:Show()
end

function ProfileTransfer:OpenImportWindow()
    local f = EnsureWindow()
    f._edit:SetText("")
    f._status:SetText(L("Paste an export string and press Import Text."))
    f._status:SetTextColor(1, 1, 1)
    f._edit:SetFocus()
    f._edit:HighlightText(0, 0)
    f:Show()
end
