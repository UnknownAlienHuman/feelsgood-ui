-- FeelsGoodUI: shared Movers geometry + apply helpers

local _, ns = ...

local DB = ns.DB
local Log = ns.Log
local Apply = ns.Apply

local Shared = ns.MoversShared or {}
ns.MoversShared = Shared

local VALID_POINTS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true,
    LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local function GetProfileSection(section)
    if DB and DB.GetSection then
        local value = DB:GetSection(section)
        if type(value) == "table" then
            return value
        end
    end
    return {}
end

local function EnsureProfileSection(section)
    if DB and DB.EnsureSection then
        local value = DB:EnsureSection(section)
        if type(value) == "table" then
            return value
        end
    end
    return GetProfileSection(section)
end

local function IsSafeToEdit()
    return not InCombatLockdown()
end

local function UIParentRect()
    local l, b, w, h = UIParent:GetRect()
    if type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then
        return (l or 0), (b or 0), w, h
    end
    return 0, 0, (UIParent:GetWidth() or 0), (UIParent:GetHeight() or 0)
end

local function UIWH()
    local _, _, w, h = UIParentRect()
    return w, h
end

local function GetCursorUI()
    local scale = UIParent:GetEffectiveScale() or 1
    local x, y = GetCursorPosition()
    return (x or 0) / scale, (y or 0) / scale
end

local function Clamp(v, minV, maxV)
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

local function RoundToStep(v, step)
    if step <= 0 then return v end
    return math.floor((v / step) + 0.5) * step
end

local function ClampCenterOffsets(x, y, fw, fh)
    local W, H = UIWH()
    if W <= 0 or H <= 0 then return x, y end

    local minX = (fw * 0.5) - (W * 0.5)
    local maxX = (W - (fw * 0.5)) - (W * 0.5)
    local minY = (fh * 0.5) - (H * 0.5)
    local maxY = (H - (fh * 0.5)) - (H * 0.5)

    return Clamp(x, minX, maxX), Clamp(y, minY, maxY)
end

local function GetFrameSnapSize(frame)
    if not frame then return 1, 1 end

    local w = tonumber(frame:GetWidth()) or 1
    local h = tonumber(frame:GetHeight()) or 1

    local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
    local parentScale = UIParent:GetEffectiveScale() or 1
    local mul = frameScale / parentScale

    w = w * mul
    h = h * mul

    if frame.GetHitRectInsets then
        local il, ir, it, ib = frame:GetHitRectInsets()
        if type(il) == "number" and type(ir) == "number" then
            w = w - ((il + ir) * mul)
        end
        if type(it) == "number" and type(ib) == "number" then
            h = h - ((it + ib) * mul)
        end
    end

    if w < 1 then w = 1 end
    if h < 1 then h = 1 end
    return w, h
end

local function GetFrameSnapBounds(frame, parentLeft, parentBottom, parentW, parentH)
    if not frame then return nil end

    local l, b, w, h = frame:GetRect()
    local r, t
    if type(l) == "number" and type(b) == "number" and type(w) == "number" and type(h) == "number" then
        r = l + w
        t = b + h
    else
        local cx, cy = frame:GetCenter()
        if type(cx) ~= "number" or type(cy) ~= "number" then return nil end
        local fw, fh = GetFrameSnapSize(frame)
        l = cx - (fw * 0.5)
        b = cy - (fh * 0.5)
        r = l + fw
        t = b + fh
    end

    if type(l) ~= "number" or type(b) ~= "number" or type(r) ~= "number" or type(t) ~= "number" then
        return nil
    end

    local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
    local parentScale = UIParent:GetEffectiveScale() or 1
    local mul = frameScale / parentScale

    if frame.GetHitRectInsets then
        local il, ir, it, ib = frame:GetHitRectInsets()
        if type(il) == "number" and type(ir) == "number" and type(it) == "number" and type(ib) == "number" then
            l = l + (il * mul)
            r = r - (ir * mul)
            t = t - (it * mul)
            b = b + (ib * mul)
        end
    end

    l = l - (parentLeft or 0)
    r = r - (parentLeft or 0)
    b = b - (parentBottom or 0)
    t = t - (parentBottom or 0)

    if l > r then l, r = r, l end
    if b > t then b, t = t, b end

    if type(parentW) == "number" and parentW > 0 then
        l = Clamp(l, -parentW, parentW * 2)
        r = Clamp(r, -parentW, parentW * 2)
    end
    if type(parentH) == "number" and parentH > 0 then
        b = Clamp(b, -parentH, parentH * 2)
        t = Clamp(t, -parentH, parentH * 2)
    end

    return l, b, r, t
end

local function NormalizePointTable(pos, fallback)
    if type(pos) ~= "table" then
        pos = nil
    end
    if type(fallback) ~= "table" then
        fallback = nil
    end

    local point = pos and pos.point or nil
    if type(point) ~= "string" or not VALID_POINTS[point] then
        point = (fallback and fallback.point) or "CENTER"
    end

    local relPoint = pos and pos.relPoint or nil
    if type(relPoint) ~= "string" or not VALID_POINTS[relPoint] then
        relPoint = (fallback and fallback.relPoint) or point
    end

    local x = tonumber(pos and pos.x)
    if type(x) ~= "number" then
        x = tonumber(fallback and fallback.x) or 0
    end

    local y = tonumber(pos and pos.y)
    if type(y) ~= "number" then
        y = tonumber(fallback and fallback.y) or 0
    end

    return {
        point = point,
        relPoint = relPoint,
        x = x,
        y = y,
    }
end

local function GetMoverPositionKey(key, spec)
    if type(spec) == "table" then
        local positionKey = spec.positionKey
        if type(positionKey) == "string" and positionKey ~= "" then
            return positionKey
        end
    end

    if type(key) == "string" and key ~= "" then
        return key
    end

    return nil
end

local function GetStoredPoint(key, spec, frame)
    if type(spec) == "table" and type(spec.getStoredPoint) == "function" then
        local ok, point = pcall(spec.getStoredPoint, spec, key, frame)
        if ok and type(point) == "table" then
            return NormalizePointTable(point)
        end
    end

    local positionKey = GetMoverPositionKey(key, spec)
    if not positionKey then
        return nil
    end

    local positions = GetProfileSection("positions")
    local point = positions[positionKey]
    if type(point) ~= "table" then
        return nil
    end

    return NormalizePointTable(point)
end

local function SetStoredPoint(key, spec, point, frame)
    local normalized = NormalizePointTable(point)

    if type(spec) == "table" and type(spec.setStoredPoint) == "function" then
        local ok, handled = pcall(spec.setStoredPoint, spec, key, frame, normalized)
        if ok and handled == true then
            return normalized
        end
        if ok and type(handled) == "table" then
            normalized = NormalizePointTable(handled, normalized)
        end
    end

    local positionKey = GetMoverPositionKey(key, spec)
    if not positionKey then
        return normalized
    end

    local positions = EnsureProfileSection("positions")
    positions[positionKey] = normalized
    return normalized
end

local function GetFrameCenterOffsets(frame)
    if not frame then
        return nil, nil
    end

    local parentLeft, parentBottom, W, H = UIParentRect()
    if W <= 0 or H <= 0 then
        return nil, nil
    end

    local cx, cy = frame:GetCenter()
    if type(cx) ~= "number" or type(cy) ~= "number" then
        return nil, nil
    end

    return (cx - parentLeft) - (W * 0.5), (cy - parentBottom) - (H * 0.5)
end

local function ApplyPoint(frame, pos, spec, key)
    if not frame or not pos then return end

    local normalized = NormalizePointTable(pos)

    if type(spec) == "table" and type(spec.applyPoint) == "function" then
        local ok, handled = pcall(spec.applyPoint, spec, key, frame, normalized)
        if ok and handled == true then
            return normalized
        end
    end

    frame:ClearAllPoints()
    frame:SetPoint(normalized.point, UIParent, normalized.relPoint, normalized.x, normalized.y)
    return normalized
end

local function ApplyStoredPoint(key, frame, spec)
    local point = GetStoredPoint(key, spec, frame)
    if not point then
        return nil
    end

    return ApplyPoint(frame, point, spec, key)
end

local function GetEditablePosition(key, frame, spec)
    if type(spec) == "table" and type(spec.getEditPosition) == "function" then
        local ok, x, y = pcall(spec.getEditPosition, spec, key, frame)
        if ok and type(x) == "number" and type(y) == "number" then
            return x, y
        end
    end

    local x, y = GetFrameCenterOffsets(frame)
    if type(x) == "number" and type(y) == "number" then
        return x, y
    end

    local point = GetStoredPoint(key, spec, frame)
    if point and point.point == "CENTER" and point.relPoint == "CENTER" then
        return point.x, point.y
    end

    return 0, 0
end

local function SetEditablePosition(key, frame, x, y, spec)
    local normalized = NormalizePointTable({
        point = "CENTER",
        relPoint = "CENTER",
        x = x,
        y = y,
    })

    if type(spec) == "table" and type(spec.setEditPosition) == "function" then
        local ok, handled = pcall(spec.setEditPosition, spec, key, frame, normalized.x, normalized.y, normalized)
        if ok and handled == true then
            SetStoredPoint(key, spec, normalized, frame)
            return normalized
        end
        if ok and type(handled) == "table" then
            normalized = NormalizePointTable(handled, normalized)
        end
    end

    if frame then
        ApplyPoint(frame, normalized, spec, key)
    end

    return SetStoredPoint(key, spec, normalized, frame)
end

local function EnsureCenterAnchor(key, frame, spec)
    if not frame then return end
    local x, y = GetEditablePosition(key, frame, spec)
    SetEditablePosition(key, frame, x, y, spec)
end

local function SavePoint(key, frame, spec)
    if not key or not frame then return end

    local point, relFrame, relPoint, x, y = frame:GetPoint(1)
    if relFrame and relFrame ~= UIParent then
        local cx, cy = GetEditablePosition(key, frame, spec)
        return SetStoredPoint(key, spec, {
            point = "CENTER",
            relPoint = "CENTER",
            x = cx,
            y = cy,
        }, frame)
    end

    if type(point) ~= "string" or type(relPoint) ~= "string" then
        local cx, cy = GetEditablePosition(key, frame, spec)
        return SetStoredPoint(key, spec, {
            point = "CENTER",
            relPoint = "CENTER",
            x = cx,
            y = cy,
        }, frame)
    end

    return SetStoredPoint(key, spec, {
        point = point,
        relPoint = relPoint,
        x = (type(x) == "number") and x or 0,
        y = (type(y) == "number") and y or 0,
    }, frame)
end

local function GridStep()
    local movers = GetProfileSection("movers")
    local step = movers.gridStep
    if type(step) ~= "number" or step < 4 or step > 128 then
        step = 10
    end
    return math.floor(step + 0.5)
end

local function EditorCfg()
    local ed = GetProfileSection("editor")
    local snap = ed.snap or {}
    local nudge = ed.nudge or {}
    local resize = ed.resize or {}

    local cfg = {
        snapEnabled = (snap.enabled ~= false),
        snapThreshold = (type(snap.threshold) == "number") and snap.threshold or 10,
        snapToGrid = (snap.toGrid ~= false),
        snapToFrames = (snap.toFrames ~= false),
        showGuides = (snap.showGuides ~= false),
        nudgeStep = (type(nudge.step) == "number") and nudge.step or 1,
        nudgeStepLarge = (type(nudge.stepLarge) == "number") and nudge.stepLarge or 10,
        resizeEnabled = (resize.enabled ~= false),
    }

    cfg.snapThreshold = Clamp(math.floor(cfg.snapThreshold + 0.5), 2, 30)
    cfg.nudgeStep = Clamp(math.floor(cfg.nudgeStep + 0.5), 1, 20)
    cfg.nudgeStepLarge = Clamp(math.floor(cfg.nudgeStepLarge + 0.5), 5, 50)

    return cfg
end

local function NormalizeApplyKeys(keys)
    if type(keys) == "string" then
        if keys ~= "" then
            return { keys }
        end
        return {}
    end

    if type(keys) ~= "table" then
        return {}
    end

    local out = {}
    local seen = {}
    for i = 1, #keys do
        local key = keys[i]
        if type(key) == "string" and key ~= "" and not seen[key] then
            seen[key] = true
            out[#out + 1] = key
        end
    end
    return out
end

local function RequestApplyForKeys(keys, scope)
    local resolved = NormalizeApplyKeys(keys)
    if #resolved == 0 then
        if Log and Log.Warn then
            Log:Warn("Movers: no apply mapping for '" .. tostring(scope) .. "'.")
        end
        return
    end

    if Apply and Apply.Request then
        if #resolved == 1 then
            Apply:Request(resolved[1])
        else
            Apply:Request(resolved)
        end
        return
    end

    if Log and Log.Warn then
        Log:Warn("Movers: apply queue unavailable; runtime refresh skipped for '" .. tostring(scope) .. "'.")
    end
end

Shared.GetProfileSection = GetProfileSection
Shared.EnsureProfileSection = EnsureProfileSection
Shared.IsSafeToEdit = IsSafeToEdit
Shared.UIParentRect = UIParentRect
Shared.UIWH = UIWH
Shared.GetCursorUI = GetCursorUI
Shared.Clamp = Clamp
Shared.RoundToStep = RoundToStep
Shared.ClampCenterOffsets = ClampCenterOffsets
Shared.GetFrameSnapSize = GetFrameSnapSize
Shared.GetFrameSnapBounds = GetFrameSnapBounds
Shared.ApplyPoint = ApplyPoint
Shared.ApplyStoredPoint = ApplyStoredPoint
Shared.GetStoredPoint = GetStoredPoint
Shared.SetStoredPoint = SetStoredPoint
Shared.GetEditablePosition = GetEditablePosition
Shared.SetEditablePosition = SetEditablePosition
Shared.EnsureCenterAnchor = EnsureCenterAnchor
Shared.SavePoint = SavePoint
Shared.GridStep = GridStep
Shared.EditorCfg = EditorCfg
Shared.RequestApplyForKeys = RequestApplyForKeys
