-- FeelsGoodUI: canonical owner for general runtime settings
--
-- Persisted values are written through Settings. This owner is the only apply
-- boundary for debug/performance runtime state and registers that boundary in
-- FeatureRegistry after DB, Perf, and the registry are loaded.

local _, ns = ...

local RuntimeSettings = {}
ns.RuntimeSettings = RuntimeSettings

local DB = ns.DB
local Perf = ns.Perf
local Registry = ns.FeatureRegistry

function RuntimeSettings:Apply()
    if not (DB and type(DB.ApplyRuntime) == "function") then
        return false, "DB.ApplyRuntime unavailable"
    end
    if not (Perf and type(Perf.RefreshFromProfile) == "function") then
        return false, "Perf.RefreshFromProfile unavailable"
    end

    local result, detail = DB:ApplyRuntime()
    if result == false then
        return false, detail or "DB.ApplyRuntime returned false"
    end

    local perfResult, perfDetail = Perf:RefreshFromProfile()
    if perfResult == false then
        return false, perfDetail or "Perf.RefreshFromProfile returned false"
    end

    return true
end

local contract = Registry
    and type(Registry.GetApplyContract) == "function"
    and Registry:GetApplyContract("runtime")
    or nil

if type(contract) ~= "table" then
    error("FeelsGoodUI: runtime apply contract unavailable")
end

contract.handler = function()
    return RuntimeSettings:Apply()
end

return RuntimeSettings
