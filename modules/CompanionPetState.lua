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

local function HasMethods(object, ...)
    if not object then return false end
    for i = 1, select("#", ...) do
        if type(object[select(i, ...)]) ~= "function" then return false end
    end
    return true
end

local function ValidateCapturedComponents(state, components)
    local icon = components.icon
    if icon and not (
        state.icon and state.icon.points and state.icon.texCoord
        and HasMethods(icon, "ClearAllPoints", "SetPoint", "SetTexCoord")
    ) then
        return false
    end

    local highlight = components.highlight
    if highlight and not (
        state.highlight and state.highlight.points and type(state.highlight.alpha) == "number"
        and HasMethods(highlight, "ClearAllPoints", "SetPoint", "SetAlpha")
    ) then
        return false
    end

    local cooldown = components.cooldown
    if cooldown and not (
        state.cooldown and state.cooldown.points
        and HasMethods(cooldown, "ClearAllPoints", "SetPoint")
    ) then
        return false
    end

    local iconMask = components.iconMask
    if iconMask and not (
        state.iconMask and type(state.iconMask.shown) == "boolean"
        and HasMethods(iconMask, "Show", "Hide")
    ) then
        return false
    end

    local name = components.name
    if name and not (
        state.name and state.name.textKnown and type(state.name.shown) == "boolean"
        and HasMethods(name, "SetText", "Show", "Hide")
    ) then
        return false
    end

    local hotkey = components.hotkey
    if hotkey and not (
        state.hotkey and type(state.hotkey.alpha) == "number"
        and type(state.hotkey.shown) == "boolean"
        and HasMethods(hotkey, "SetAlpha", "Show", "Hide")
    ) then
        return false
    end

    for key, object in pairs(components.alphas or {}) do
        local captured = state.alphas[key]
        if object and not (
            captured and captured.object == object and type(captured.alpha) == "number"
            and HasMethods(object, "SetAlpha")
        ) then
            return false
        end
    end
    return true
end

local function CapturedObject(record)
    return record and record.object or nil
end

local function ComponentsMatch(original, components)
    if type(original) ~= "table" then return false end
    if CapturedObject(original.icon) ~= components.icon
        or CapturedObject(original.highlight) ~= components.highlight
        or CapturedObject(original.cooldown) ~= components.cooldown
        or CapturedObject(original.iconMask) ~= components.iconMask
        or CapturedObject(original.name) ~= components.name
        or CapturedObject(original.hotkey) ~= components.hotkey then
        return false
    end

    local capturedAlphas = original.alphas or {}
    local currentAlphas = components.alphas or {}
    for key, object in pairs(currentAlphas) do
        if CapturedObject(capturedAlphas[key]) ~= object then return false end
    end
    for key, captured in pairs(capturedAlphas) do
        if CapturedObject(captured) ~= currentAlphas[key] then return false end
    end
    return true
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
    if not ValidateCapturedComponents(state, components) then return nil end
    return state
end

local function ForceRestoreLayout(original)
    local object = original and original.object
    if not object then return false end

    if type(object.SetParent) == "function" then object:SetParent(original.parent) end
    RestorePoints(object, original.points)
    if type(object.SetSize) == "function" then
        object:SetSize(original.size.width, original.size.height)
    end
    if original.hitRect and type(object.SetHitRectInsets) == "function" then
        object:SetHitRectInsets(
            original.hitRect.left,
            original.hitRect.right,
            original.hitRect.top,
            original.hitRect.bottom
        )
    end
    SetShown(object, original.shown)
    return true
end

local function RestoreLayout(original, managed)
    local object = original and original.object
    if not (object and managed and managed.object == object) then return end

    local parentKnown, parent = ReadParent(object)
    local currentPoints = ReadPoints(object)
    local currentSize = ReadSize(object)
    local currentShown = ReadShown(object)
    local currentHitRect = ReadHitRect(object)

    local structuralOwned = parentKnown
        and parent == managed.parent
        and currentPoints and PointsEqual(currentPoints, managed.points)
        and currentSize
        and NumberEqual(currentSize.width, managed.size.width)
        and NumberEqual(currentSize.height, managed.size.height)

    if structuralOwned and managed.hitRect then
        structuralOwned = currentHitRect and HitRectEqual(currentHitRect, managed.hitRect)
    end
    if structuralOwned then
        if type(object.SetParent) == "function" then object:SetParent(original.parent) end
        RestorePoints(object, original.points)
        if type(object.SetSize) == "function" then
            object:SetSize(original.size.width, original.size.height)
        end
        if original.hitRect and type(object.SetHitRectInsets) == "function" then
            object:SetHitRectInsets(
                original.hitRect.left,
                original.hitRect.right,
                original.hitRect.top,
                original.hitRect.bottom
            )
        end
    end

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

local function ForceRestoreRegion(original)
    local object = original and original.object
    if not object then return end
    if original.points then RestorePoints(object, original.points) end
    if original.texCoord then RestoreTexCoord(object, original.texCoord) end
    if type(original.alpha) == "number" then SetAlpha(object, original.alpha) end
    if type(original.shown) == "boolean" then SetShown(object, original.shown) end
end

local function ForceRestoreTextRegion(original)
    ForceRestoreRegion(original)
    local object = original and original.object
    if object and original.textKnown and type(object.SetText) == "function" then
        object:SetText(original.text)
    end
end

local function ForceRestoreButtonRecord(record)
    if type(record) ~= "table" or not record.original then return false end
    local original = record.original
    ForceRestoreLayout(original.layout)
    ForceRestoreRegion(original.icon)
    ForceRestoreRegion(original.highlight)
    ForceRestoreRegion(original.cooldown)
    ForceRestoreRegion(original.iconMask)
    ForceRestoreTextRegion(original.name)
    ForceRestoreTextRegion(original.hotkey)
    for _, alpha in pairs(original.alphas or {}) do
        if alpha.object and type(alpha.alpha) == "number" then
            SetAlpha(alpha.object, alpha.alpha)
        end
    end
    if type(record.release) == "function" then
        pcall(record.release, record.button)
    end
    return true
end

local function RestoreButtonRecord(record)
    if type(record) ~= "table" or not record.original then return false end
    if not record.managed then return ForceRestoreButtonRecord(record) end

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
    if type(record.release) == "function" then
        pcall(record.release, record.button)
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

    components = type(components) == "table" and components or {}
    local registry = GetRegistry(module)
    local record = registry[index]
    if record and (
        record.button ~= button
        or not ComponentsMatch(record.original, components)
    ) then
        RestoreButtonRecord(record)
        registry[index] = nil
        record = nil
    end

    if not record then
        local original = CaptureButtonState(button, components)
        if not original then
            return false, "Pet action button state is unreadable"
        end
        record = {
            button = button,
            original = original,
            release = components.release,
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
    if type(record.managedAlpha) ~= "number" or not NumberEqual(record.managedAlpha, 0) then
        SetAlpha(frame, record.alpha)
        module._petNativeBarState = nil
        return false, "Native pet-bar alpha could not be verified"
    end
    return true
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
