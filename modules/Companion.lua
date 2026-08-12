-- FeelsGoodUI: companion owner facade

local _, ns = ...

local Companion = {}
ns.Companion = Companion

local Runtime = ns.CompanionRuntime

function Companion:ApplyCompanionConfig(profile)
    if Runtime and Runtime.ApplyCompanionConfig then
        return Runtime.ApplyCompanionConfig(self, profile)
    end
    return false
end

function Companion:ApplyConfig(profile)
    if Runtime and Runtime.ApplyConfig then
        return Runtime.ApplyConfig(self, profile)
    end
    return false
end

function Companion:RequestApply()
    if Runtime and Runtime.RequestApply then
        return Runtime.RequestApply(self)
    end
    return false
end

function Companion:Init()
    if Runtime and Runtime.Init then
        return Runtime.Init(self)
    end
    return false
end

function Companion:Attach()
    if Runtime and Runtime.Attach then
        return Runtime.Attach(self)
    end
    return false
end

function Companion:Detach()
    if Runtime and Runtime.Detach then
        return Runtime.Detach(self)
    end
    return false
end

return Companion
