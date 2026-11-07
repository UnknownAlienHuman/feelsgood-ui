-- FeelsGoodUI: reversible state owner for Blizzard pet-action buttons

local _, ns = ...

local State = {}
ns.CompanionPetState = State

local function NumberEqual(a, b)
    if type(a) ~= "number" or type(b) ~= "number" then return a == b end
    return math.abs(a - b) < 0.001
end

local function ReadParent(object)
    if not (object and type(object.GetParent) == "function") then return false, nil end
    local ok, value = pcall(object.GetParent, object)
    return ok, value
end

local function ReadSize(object)
    if not object then return nil end
    local width, height
    if type(object.GetSize) == "function" then
        local ok, w, h = pcall(object.GetSize, object)
        if ok then width, height = w, h end
    elseif type(object.GetWidth) == "function" and type(object.GetHeight) == "function" then
        local okW, w = pcall(object.GetWidth, object)
        local okH, h = pcall(object.GetHeight, object)
        if okW and okH then width, height = w, h end
    end
    if type(width) ~= "number" or type(height) ~= "number" then return nil end
    return { width = width, height = height }
end

local function ReadPoints(object)
    if not (object and type(object.GetNumPoints) == "function" and type(object.GetPoint) == "function") then
        return nil
    end

    local okCount, count = pcall(object.GetNumPoints, object)
    if not okCount or type(count) ~= "number" then return nil end

    local points = {}
    for i = 1, count do
        local ok, point, relativeTo, relativePoint, x, y = pcall(object.GetPoint, object, i)
        if not ok then return nil end
        points[i] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end
    return points
end

local function PointsEqual(a, b)
    if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
    for i = 1, #a do
        local left, right = a[i], b[i]
        if left.point ~= right.point
            or left.relativeTo ~= right.relativeTo
            or left.relativePoint ~= right.relativePoint
            or not NumberEqual(left.x, right.x)
            or not NumberEqual(left.y, right.y) then
            return false
        end
    end
    return true
end

local function RestorePoints(object, points)
    if not (object and type(points) == "table"
        and type(object.ClearAllPoints) == "function"
        and type(object.SetPoint) == "function") then
        return false
    end

    object:ClearAllPoints()
    for i = 1, #points do
        local point = points[i]
        object:SetPoint(
            point.point,
            point.relativeTo,
            point.relativePoint,
            point.x,
            point.y
        )
    end
    return true
end

local function ReadShown(object)
    if not (object and type(object.IsShown) == "function") then return nil end
    local ok, value = pcall(object.IsShown, object)
    if not ok or type(value) ~= "boolean" then return nil end
    return value
end

local function SetShown(object, shown)
    if not object or type(shown) ~= "boolean" then return false end
    if shown and type(object.Show) == "function" then object:Show(); return true end
    if not shown and type(object.Hide) == "function" then object:Hide(); return true end
    return false
end

local function ReadAlpha(object)
    if not (object and type(object.GetAlpha) == "function") then return nil end
    local ok, value = pcall(object.GetAlpha, object)
    return ok and type(value) == "number" and value or nil
end

local function SetAlpha(object, alpha)
    if not (object and type(object.SetAlpha) == "function" and type(alpha) == "number") then
        return false
    end
    object:SetAlpha(alpha)
    return true
end

local function ReadHitRect(object)
    if not (object and type(object.GetHitRectInsets) == "function") then return nil end
    local ok, left, right, top, bottom = pcall(object.GetHitRectInsets, object)
    if not ok then return nil end
    if type(left) ~= "number" or type(right) ~= "number"
        or type(top) ~= "number" or type(bottom) ~= "number" then
        return nil
    end
    return { left = left, right = right, top = top, bottom = bottom }
end

local function HitRectEqual(a, b)
    return type(a) == "table" and type(b) == "table"
        and NumberEqual(a.left, b.left)
        and NumberEqual(a.right, b.right)
        and NumberEqual(a.top, b.top)
        and NumberEqual(a.bottom, b.bottom)
end

local function ReadTexCoord(texture)
    if not (texture and type(texture.GetTexCoord) == "function") then return nil end
    local values = { pcall(texture.GetTexCoord, texture) }
    if values[1] ~= true then return nil end
    local out = { n = #values - 1 }
    for i = 2, #values do out[i - 1] = values[i] end
    return out
end

local function TexCoordEqual(a, b)
    if type(a) ~= "table" or type(b) ~= "table" or a.n ~= b.n then return false end
    for i = 1, a.n do
        if not NumberEqual(a[i], b[i]) then return false end
    end
    return true
end

local function RestoreTexCoord(texture, value)
    if not (texture and type(texture.SetTexCoord) == "function" and type(value) == "table") then
        return false
    end
    texture:SetTexCoord(unpack(value, 1, value.n))
    return true
end

local function ReadText(fontString)
    if not (fontString and type(fontString.GetText) == "function") then return false, nil end
    local ok, value = pcall(fontString.GetText, fontString)
    return ok, value
end

local function CaptureLayout(frame)
    local parentKnown, parent = ReadParent(frame)
    local points = ReadPoints(frame)
    local size = ReadSize(frame)
    local shown = ReadShown(frame)
    local hitRect = ReadHitRect(frame)

    if not parentKnown or not points or not size or type(shown) ~= "boolean" then
        return nil
    end
    if type(frame.SetHitRectInsets) == "function" and not hitRect then
        return nil
    end

    return {
        object = frame,
        parent = parent,
        points = points,
        size = size,
        shown = shown,
        hitRect = hitRect,
    }
end

local function CaptureRegion(region, includeTexCoord)
    if not region then return nil end
    return {
        object = region,
        points = ReadPoints(region),
        texCoord = includeTexCoord and ReadTexCoord(region) or nil,
        alpha = ReadAlpha(region),
        shown = ReadShown(region),
    }
end

local function CaptureTextRegion(region)
    if not region then return nil end
    local textKnown, text = ReadText(region)
    return {
        object = region,
        points = ReadPoints(region),
        alpha = ReadAlpha(region),
        shown = ReadShown(region),
        textKnown = textKnown,
        text = text,
    }
end

local function CaptureButtonState(button, components)
    local layout = CaptureLayout(button)
    if not layout then return nil end

    local state = {
        layout = layout,
        icon = CaptureRegion(components.icon, true),
        highlight = CaptureRegion(components.highlight, false),
        cooldown = CaptureRegion(components.cooldown, false),
        iconMask = CaptureRegion(components.iconMask, false),
        name = CaptureTextRegion(components.name),
        hotkey = CaptureTextRegion(components.hotkey),
        alphas = {},
    }

    for key, object in pairs(components.alphas or {}) do
        state.alphas[key] = {
            object = object,
            alpha = ReadAlpha(object),
        }
    end
    return state
end

local function RestoreLayout(original, managed)
    local object = original and original.object
    if not (object and managed and managed.object == object) then return end

    local parentKnown, parent = ReadParent(object)
    if parentKnown and parent == managed.parent and type(object.SetParent) == "function" then
        object:SetParent(original.parent)
    end

    local currentPoints = ReadPoints(object)
    if currentPoints and PointsEqual(currentPoints, managed.points) then
        RestorePoints(object, original.points)
    end

    local currentSize = ReadSize(object)
    if currentSize and NumberEqual(currentSize.width, managed.size.width)
        and NumberEqual(currentSize.height, managed.size.height)
        and type(object.SetSize) == "function" then
        object:SetSize(original.size.width, original.size.height)
    end

    local currentHitRect = ReadHitRect(object)
    if original.hitRect and managed.hitRect and currentHitRect
        and HitRectEqual(currentHitRect, managed.hitRect)
        and type(object.SetHitRectInsets) == "function" then
        object:SetHitRectInsets(
            original.hitRect.left,
            original.hitRect.right,
            original.hitRect.top,
            original.hitRect.bottom
        )
    end

    local currentShown = ReadShown(object)
    if currentShown == managed.shown then
        SetShown(object, original.shown)
    end
end

local function RestoreRegion(original, managed)
    local object = original and original.object
    if not (object and managed and managed.object == object) then return end

    if original.points and managed.points then
        local current = ReadPoints(object)
        if current and PointsEqual(current, managed.points) then
            RestorePoints(object, original.points)
        end
    end

    if original.texCoord and managed.texCoord then
        local current = ReadTexCoord(object)
        if current and TexCoordEqual(current, managed.texCoord) then
            RestoreTexCoord(object, original.texCoord)
        end
    end

    if type(original.alpha) == "number" and type(managed.alpha) == "number"
        and NumberEqual(ReadAlpha(object), managed.alpha) then
        SetAlpha(object, original.alpha)
    end

    if type(original.shown) == "boolean" and type(managed.shown) == "boolean"
        and ReadShown(object) == managed.shown then
        SetShown(object, original.shown)
    end
end

local function RestoreTextRegion(original, managed)
    RestoreRegion(original, managed)
    local object = original and original.object
    if not (object and managed and managed.object == object) then return end
    if original.textKnown and managed.textKnown and type(object.SetText) == "function" then
        local known, current = ReadText(object)
        if known and current == managed.text then
            object:SetText(original.text)
        end
    end
end

local function RestoreButtonRecord(record)
    if type(record) ~= "table" or not record.original or not record.managed then return false end

    RestoreLayout(record.original.layout, record.managed.layout)
    RestoreRegion(record.original.icon, record.managed.icon)
    RestoreRegion(record.original.highlight, record.managed.highlight)
    RestoreRegion(record.original.cooldown, record.managed.cooldown)
    RestoreRegion(record.original.iconMask, record.managed.iconMask)
    RestoreTextRegion(record.original.name, record.managed.name)
    RestoreTextRegion(record.original.hotkey, record.managed.hotkey)

    for key, original in pairs(record.original.alphas or {}) do
        local managed = record.managed.alphas and record.managed.alphas[key]
        local object = original and original.object
        if object and managed and managed.object == object
            and type(original.alpha) == "number" and type(managed.alpha) == "number"
            and NumberEqual(ReadAlpha(object), managed.alpha) then
            SetAlpha(object, original.alpha)
        end
    end
    return true
end

local function GetRegistry(module)
    module._petButtonState = type(module._petButtonState) == "table"
        and module._petButtonState
        or {}
    return module._petButtonState
end

function State:BeginButton(module, index, button, components)
    if type(module) ~= "table" or type(index) ~= "number" or not button then
        return false, "Invalid pet-button state owner"
    end

    local registry = GetRegistry(module)
    local record = registry[index]
    if record and record.button ~= button then
        RestoreButtonRecord(record)
        registry[index] = nil
        record = nil
    end

    if not record then
        local original = CaptureButtonState(button, components or {})
        if not original then
            return false, "Pet action button state is unreadable"
        end
        record = {
            button = button,
            original = original,
        }
        registry[index] = record
    end
    return true, record
end

function State:FinishButton(module, index, button, components)
    local registry = type(module) == "table" and module._petButtonState or nil
    local record = type(registry) == "table" and registry[index] or nil
    if not (record and record.button == button) then
        return false, "Pet action button state was not captured"
    end

    record.managed = CaptureButtonState(button, components or {})
    if not record.managed then
        RestoreButtonRecord(record)
        registry[index] = nil
        return false, "Managed pet action button state is unreadable"
    end
    return true
end

function State:ReleaseButton(module, index)
    local registry = type(module) == "table" and module._petButtonState or nil
    local record = type(registry) == "table" and registry[index] or nil
    if not record then return true end
    RestoreButtonRecord(record)
    registry[index] = nil
    return true
end

local function RestoreNativeBar(module)
    local record = type(module) == "table" and module._petNativeBarState or nil
    if type(record) ~= "table" then return true end
    module._petNativeBarState = nil

    local frame = record.frame
    if frame and type(record.alpha) == "number" and type(record.managedAlpha) == "number"
        and NumberEqual(ReadAlpha(frame), record.managedAlpha) then
        SetAlpha(frame, record.alpha)
    end
    return true
end

function State:SuppressNativeBar(module, frame)
    if type(module) ~= "table" then return false, "Invalid native pet-bar owner" end

    local record = module._petNativeBarState
    if record and record.frame ~= frame then
        RestoreNativeBar(module)
        record = nil
    end
    if not frame then
        RestoreNativeBar(module)
        return true
    end

    if not record then
        local alpha = ReadAlpha(frame)
        if type(alpha) ~= "number" or type(frame.SetAlpha) ~= "function" then
            return false, "Native pet-bar alpha is unreadable"
        end
        record = { frame = frame, alpha = alpha }
        module._petNativeBarState = record
    end

    SetAlpha(frame, 0)
    record.managedAlpha = ReadAlpha(frame)
    return type(record.managedAlpha) == "number"
end

function State:RestoreAll(module)
    if type(module) ~= "table" then return false end

    local registry = module._petButtonState
    if type(registry) == "table" then
        for index, record in pairs(registry) do
            RestoreButtonRecord(record)
            registry[index] = nil
        end
    end
    RestoreNativeBar(module)
    return true
end

return State
