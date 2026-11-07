local function DeepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, item in pairs(value) do
        out[DeepCopy(key, seen)] = DeepCopy(item, seen)
    end
    return out
end

local warnings = {}
local root = {
    profile = {
        a = 2,
        nested = { x = 9, y = 4 },
        importedOnly = 7,
    },
}
root._profileImportRecovery = {
    version = 1,
    previous = {
        a = 1,
        nested = { x = 1, z = 3 },
        keep = 5,
    },
    expected = DeepCopy(root.profile),
}

-- Changes made after the import started must survive recovery.
root.profile.nested.x = 10
root.profile.importedOnly = nil
root.profile.later = 8

_G = _G or {}
_G.FeelsGoodUIDB = root
local ns = {
    Apply = {},
    DB = { data = root, GetProfile = function(self) return self.data.profile end },
    Log = { Warn = function(_, message) warnings[#warnings + 1] = message end },
    PanelTransactions = {},
    Schema = {},
    Settings = {},
    U = { DeepCopy = DeepCopy },
}

local chunk = assert(loadfile('core/ProfileImport.lua'))
chunk('FeelsGoodUI', ns)
assert(ns.ProfileImport:RecoverInterrupted(root) == true)
assert(root._profileImportRecovery == nil)
assert(root.profile.a == 1)
assert(root.profile.keep == 5)
assert(root.profile.nested.x == 10)
assert(root.profile.nested.z == 3)
assert(root.profile.nested.y == nil)
assert(root.profile.importedOnly == nil)
assert(root.profile.later == 8)
assert(#warnings == 1)

local stable = root.profile
root._profileImportRecovery = { version = 999 }
assert(ns.ProfileImport:RecoverInterrupted(root) == false)
assert(root._profileImportRecovery == nil)
assert(root.profile == stable)
assert(#warnings == 2)

print('Profile import durable recovery tests passed.')
