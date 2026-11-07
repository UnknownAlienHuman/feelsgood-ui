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

local function ResolveRequestedSize(width, height)
    local rw = tonumber(width) or 32
    local rh = tonumber(height)
    if type(rh) ~= "number" then rh = rw end
    return ClampActionButtonSize((rw + rh) * 0.5)
end

local function PreviewLayout(size, spacing)
    local runtime = ns.ActionBarsRuntime
    local module = ns.ActionBars
    if not (runtime and type(runtime.PreviewMoverLayout) == "function" and module) then
        return false, "ActionBars preview owner unavailable"
    end
    return runtime.PreviewMoverLayout(module, size, spacing)
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
        buildSizeWrites = function(width, height)
            local size = ResolveRequestedSize(width, height)
            return {
                path = { "actionbars", "buttonSize" },
                value = size,
                rule = { type = "int", min = 24, max = 60, fallback = 32 },
            }
        end,
        previewSize = function(_, width, height)
            local ab = GetActionBarsCfg()
            local size = ResolveRequestedSize(width, height)
            local ok, detail = PreviewLayout(size, ClampActionSpacing(ab.spacing))
            if ok == false then return false, detail end
            return size, size
        end,
        buildWheelWrites = function(delta, shiftDown)
            local ab = GetActionBarsCfg()
            if shiftDown then
                return {
                    path = { "actionbars", "spacing" },
                    value = ClampActionSpacing((tonumber(ab.spacing) or 0) + delta),
                    rule = { type = "int", min = 0, max = 12, fallback = 0 },
                }
            end

            return {
                path = { "actionbars", "buttonSize" },
                value = ClampActionButtonSize((tonumber(ab.buttonSize) or 32) + delta),
                rule = { type = "int", min = 24, max = 60, fallback = 32 },
            }
        end,
        previewWheel = function(_, delta, shiftDown)
            local ab = GetActionBarsCfg()
            local size = ClampActionButtonSize(ab.buttonSize)
            local spacing = ClampActionSpacing(ab.spacing)
            if shiftDown then
                spacing = ClampActionSpacing(spacing + delta)
            else
                size = ClampActionButtonSize(size + delta)
            end
            local ok, detail = PreviewLayout(size, spacing)
            if ok == false then return false, detail end
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
