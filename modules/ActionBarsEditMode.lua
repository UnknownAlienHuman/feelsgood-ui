-- FeelsGoodUI: ActionBars edit-mode registration
local _, ns = ...

local EditMode = {}
ns.ActionBarsEditMode = EditMode

local DB = ns.DB
local Movers = ns.Movers

local function GetActionBarsCfg()
    if DB and DB.GetSection then
        return DB:GetSection("actionbars") or {}
    end
    return {}
end

local function ResolveBarSpacing(spacing)
    spacing = tonumber(spacing) or 0
    if spacing < 0 then
        return 0
    end
    return spacing
end

EditMode.ResolveBarSpacing = ResolveBarSpacing

local function ClampActionButtonSize(value)
    local size = math.floor((tonumber(value) or 32) + 0.5)
    if size < 24 then size = 24 end
    if size > 60 then size = 60 end
    return size
end

local function ClampActionSpacing(value)
    local spacing = ResolveBarSpacing(value)
    if spacing > 12 then
        spacing = 12
    end
    return spacing
end

local function CreateActionBarMoverSpec(id)
    return {
        label = "ActionBar " .. tostring(id),
        applyKeys = "actionbars",
        positionKey = "actionbar" .. tostring(id),
        getSize = function()
            local ab = GetActionBarsCfg()
            local size = ClampActionButtonSize(ab.buttonSize)
            return size, size
        end,
        setSize = function(width, height)
            local rw = tonumber(width) or 32
            local rh = tonumber(height)
            if type(rh) ~= "number" then
                rh = rw
            end

            local ab = GetActionBarsCfg()
            ab.buttonSize = ClampActionButtonSize((rw + rh) * 0.5)
        end,
        onWheel = function(delta, shiftDown)
            local ab = GetActionBarsCfg()
            if shiftDown then
                ab.spacing = ClampActionSpacing((tonumber(ab.spacing) or 0) + delta)
            else
                ab.buttonSize = ClampActionButtonSize((tonumber(ab.buttonSize) or 32) + delta)
            end
            return true
        end,
    }
end

function EditMode.RegisterHolder(holder, id)
    if not holder or type(id) ~= "number" then
        return
    end
    if not Movers or type(Movers.Register) ~= "function" or type(Movers.Apply) ~= "function" then
        return
    end

    Movers:Register("actionbar" .. id, holder, CreateActionBarMoverSpec(id))
    Movers:Apply("actionbar" .. id, holder)
end

return EditMode
