-- FeelsGoodUI: Movers inspector + scale/resize helpers

local _, ns = ...

local InspectorModule = {}
ns.MoversInspector = InspectorModule

function InspectorModule.Create(ctx)
    ctx = ctx or {}

    local Movers = ctx.Movers
    local Log = ctx.Log
    local Media = ctx.Media
    local L = ctx.L or function(text) return text end
    local Transactions = ctx.Transactions or ns.MoversTransactions

    local IsSafeToEdit = ctx.IsSafeToEdit
    local UIParentRect = ctx.UIParentRect
    local GetFrameSnapSize = ctx.GetFrameSnapSize
    local Clamp = ctx.Clamp
    local ClampCenterOffsets = ctx.ClampCenterOffsets
    local GetMoverSpec = ctx.GetMoverSpec
    local RequestApplyForRegisteredKey = ctx.RequestApplyForRegisteredKey
    local GetEditablePosition = ctx.GetEditablePosition
    local SetEditablePosition = ctx.SetEditablePosition
    local BuildStoredPointWrites = ctx.BuildStoredPointWrites

    local previewSizes = {}

    local function EnsureInspector()
        if Movers._inspector then return Movers._inspector end

        local f = CreateFrame("Frame", nil, UIParent)
        f:SetFrameStrata("TOOLTIP")
        f:SetFrameLevel(10)
        f:SetSize(220, 128)
        f:SetClampedToScreen(true)
        f:Hide()

        f.bg = f:CreateTexture(nil, "BACKGROUND")
        f.bg:SetAllPoints()
        f.bg:SetColorTexture(0, 0, 0, 0.55)
        Media:CreateBorder(f, 1)

        f.title = f:CreateFontString(nil, "OVERLAY")
        f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
        f.title:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        f.title:SetText(L("Inspector"))

        local function Field(label, y)
            local text = f:CreateFontString(nil, "OVERLAY")
            text:SetPoint("TOPLEFT", f, "TOPLEFT", 10, y)
            text:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
            text:SetText(L(label))

            local editBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
            editBox:SetAutoFocus(false)
            editBox:SetSize(90, 20)
            editBox:SetPoint("LEFT", text, "RIGHT", 8, 0)
            editBox:SetTextInsets(6, 6, 0, 0)
            editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            editBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() if f.OnCommit then f:OnCommit() end end)

            return text, editBox
        end

        f.lx, f.ex = Field("X", -32)
        f.ly, f.ey = Field("Y", -54)
        f.ls, f.es = Field("Scale", -76)
        f.lw, f.ew = Field("Width", -98)
        f.lh, f.eh = Field("Height", -120)

        f.hint = f:CreateFontString(nil, "OVERLAY")
        f.hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
        f.hint:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        f.hint:SetText(L("Enter to apply"))

        Movers._inspector = f
        return f
    end

    local function HideInspector()
        local inspector = Movers._inspector
        if inspector then
            inspector._key = nil
            inspector._frame = nil
            inspector._overlay = nil
            inspector:Hide()
        end
    end

    local function PositionInspector(inspector, overlay)
        if not (inspector and overlay) then
            return
        end

        local parentLeft, parentBottom, parentWidth, parentHeight = UIParentRect()
        if parentWidth <= 0 or parentHeight <= 0 then
            inspector:ClearAllPoints()
            inspector:SetPoint("TOPLEFT", overlay, "TOPRIGHT", 8, 0)
            return
        end

        local margin = 8
        local inspectorWidth = tonumber(inspector:GetWidth()) or 220
        local inspectorHeight = tonumber(inspector:GetHeight()) or 128
        local parentRight = parentLeft + parentWidth
        local parentTop = parentBottom + parentHeight
        local overlayLeft = overlay.GetLeft and overlay:GetLeft() or nil
        local overlayRight = overlay.GetRight and overlay:GetRight() or nil
        local overlayTop = overlay.GetTop and overlay:GetTop() or nil

        local left = (tonumber(overlayRight) or parentLeft) + margin
        if type(overlayLeft) == "number" and (left + inspectorWidth) > (parentRight - margin) then
            left = overlayLeft - inspectorWidth - margin
        end
        left = Clamp(left, parentLeft + margin, parentRight - inspectorWidth - margin)

        local top = tonumber(overlayTop) or (parentTop - margin)
        top = Clamp(top, parentBottom + inspectorHeight + margin, parentTop - margin)

        inspector:ClearAllPoints()
        inspector:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left - parentLeft, top - parentBottom)
    end

    local function GetPosition(key, frame)
        if type(GetEditablePosition) == "function" then
            local x, y = GetEditablePosition(key, frame)
            if type(x) == "number" and type(y) == "number" then
                return x, y
            end
        end

        if frame then
            local parentLeft, parentBottom, W, H = UIParentRect()
            local cx, cy = frame:GetCenter()
            if type(cx) == "number" and type(cy) == "number" and W > 0 and H > 0 then
                return (cx - parentLeft) - (W * 0.5), (cy - parentBottom) - (H * 0.5)
            end
        end

        return 0, 0
    end

    local function SetPosition(key, frame, x, y)
        if not key or not frame then
            return
        end

        if type(SetEditablePosition) == "function" then
            SetEditablePosition(key, frame, x, y)
            return
        end

        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
    end

    local function RequestApplyForMover(key)
        if type(RequestApplyForRegisteredKey) == "function" then
            RequestApplyForRegisteredKey(key)
        end
    end

    local function GetSpec(key)
        if type(GetMoverSpec) == "function" then
            return GetMoverSpec(key)
        end
        return nil
    end

    local function SupportsScale(key)
        local spec = GetSpec(key)
        return spec and type(spec.getScale) == "function" and type(spec.buildScaleWrites) == "function"
    end

    local function GetScaleValue(key)
        local spec = GetSpec(key)
        if spec and type(spec.getScale) == "function" then
            local value = spec.getScale(spec, key)
            if type(value) == "number" then
                return value
            end
            return tonumber(value) or 1
        end

        return 1
    end

    local function SetScaleValue(key, value)
        local spec = GetSpec(key)
        local entry = Movers._registered[key]
        if not (spec and entry and entry.frame and Transactions) then
            return false
        end

        value = Clamp(tonumber(value) or 1, 0.60, 1.30)
        local previewOK, previewDetail = Transactions:Preview(spec, entry.frame, "scale", value)
        if not previewOK then
            if Log and Log.Warn then Log:Warn("Mover scale preview failed: " .. tostring(previewDetail)) end
            return false
        end

        local changed, detail = Transactions:Commit(spec, "scale", value)
        if changed == false and detail and Log and Log.Warn then
            Log:Warn("Mover scale commit failed: " .. tostring(detail))
        end
        return changed == true
    end

    local function SupportsResize(key)
        local spec = GetSpec(key)
        return spec and type(spec.getSize) == "function" and type(spec.buildSizeWrites) == "function"
    end

    local function GetResizeValue(key)
        local preview = previewSizes[key]
        if type(preview) == "table" then
            return preview.width, preview.height
        end

        local spec = GetSpec(key)
        if spec and type(spec.getSize) == "function" then
            local w, h = spec.getSize(spec, key)
            return tonumber(w) or 160, tonumber(h) or 20
        end

        return 160, 20
    end

    local function PreviewResizeValue(key, w, h)
        local spec = GetSpec(key)
        local entry = Movers._registered[key]
        if not (spec and entry and entry.frame and Transactions) then
            return nil, nil
        end

        local ok, first, second = Transactions:Preview(spec, entry.frame, "size", w, h)
        if not ok then
            if Log and Log.Warn then Log:Warn("Mover size preview failed: " .. tostring(first)) end
            return nil, nil
        end

        local width = tonumber(first) or tonumber(w)
        local height = tonumber(second) or tonumber(h)
        if type(width) ~= "number" or type(height) ~= "number" then
            return nil, nil
        end

        previewSizes[key] = { width = width, height = height }
        return width, height
    end

    local function CancelResizePreview(key)
        if previewSizes[key] == nil then
            return false
        end
        previewSizes[key] = nil
        RequestApplyForMover(key)
        return true
    end

    local function AppendWrites(target, writes)
        if type(writes) ~= "table" then return end
        if type(writes.path) == "table" then
            target[#target + 1] = writes
            return
        end
        for i = 1, #writes do target[#target + 1] = writes[i] end
    end

    local function SetResizeValue(key, w, h)
        local spec = GetSpec(key)
        local entry = Movers._registered[key]
        if not (spec and entry and entry.frame and Transactions) then
            return false
        end

        local width, height = PreviewResizeValue(key, w, h)
        if type(width) ~= "number" or type(height) ~= "number" then
            return false
        end

        local sizeWrites, sizeError = Transactions:BuildWrites(spec, "size", width, height)
        if not sizeWrites then
            previewSizes[key] = nil
            Transactions:Restore(spec.applyKeys)
            if Log and Log.Warn then Log:Warn("Mover size write build failed: " .. tostring(sizeError)) end
            return false
        end

        local positionWrites, positionApplyKeys, positionPanelKey, positionError
        if type(BuildStoredPointWrites) == "function" then
            positionWrites, positionApplyKeys, positionPanelKey, positionError = BuildStoredPointWrites(key, entry.frame)
        end
        if not positionWrites then
            previewSizes[key] = nil
            Transactions:Restore(Transactions:MergeApplyKeys(spec.applyKeys, positionApplyKeys or "movers"))
            if Log and Log.Warn then Log:Warn("Mover resize position build failed: " .. tostring(positionError)) end
            return false
        end

        local writes = {}
        AppendWrites(writes, sizeWrites)
        AppendWrites(writes, positionWrites)
        local applyKeys = Transactions:MergeApplyKeys(spec.applyKeys, positionApplyKeys)
        local changed, detail = Transactions:CommitWrites(applyKeys, writes, spec.panelKey or positionPanelKey)
        previewSizes[key] = nil
        if changed == false and detail and Log and Log.Warn then
            Log:Warn("Mover size commit failed: " .. tostring(detail))
        end
        return changed == true
    end

    local function ComputeWheelResizePair(w, h, delta, uniform)
        local bw = tonumber(w) or 1
        local bh = tonumber(h) or 1
        if bw <= 0 then bw = 1 end
        if bh <= 0 then bh = 1 end

        if uniform then
            local factor = 1 + ((tonumber(delta) or 0) * 0.05)
            if factor < 0.10 then factor = 0.10 end
            return bw * factor, bh * factor
        end

        local nw = bw + ((tonumber(delta) or 0) * 10)
        if nw < 1 then nw = 1 end
        local ratio = bh / bw
        local nh = nw * ratio
        return nw, nh
    end

    local function HandleWheelAction(key, delta, shiftDown, altDown)
        local spec = GetSpec(key)
        if not spec then
            return false
        end

        if (not altDown) and SupportsScale(key) then
            local scale = GetScaleValue(key)
            return SetScaleValue(key, scale + ((tonumber(delta) or 0) * 0.02))
        end

        if altDown and type(spec.buildWheelWrites) == "function" and Transactions then
            local entry = Movers._registered[key]
            local amount = tonumber(delta) or 0
            local previewOK, previewDetail = Transactions:Preview(spec, entry and entry.frame, "wheel", amount, shiftDown == true)
            if not previewOK then
                if Log and Log.Warn then Log:Warn("Mover wheel preview failed: " .. tostring(previewDetail)) end
                return false
            end

            local changed, detail = Transactions:Commit(spec, "wheel", amount, shiftDown == true)
            if changed == false and detail and Log and Log.Warn then
                Log:Warn("Mover wheel commit failed: " .. tostring(detail))
            end
            return changed == true
        end

        if altDown and SupportsResize(key) then
            local w, h = GetResizeValue(key)
            local nw, nh = ComputeWheelResizePair(w, h, delta, shiftDown)
            return SetResizeValue(key, nw, nh)
        end

        return false
    end

    local function UpdateInspector(key, frame)
        local f = Movers._inspector
        if not f or not f:IsShown() then
            return
        end

        PositionInspector(f, f._overlay)

        local x, y = GetPosition(key, frame)

        if not (f.ex and f.ex:HasFocus()) then f.ex:SetText(string.format("%d", math.floor(x + 0.5))) end
        if not (f.ey and f.ey:HasFocus()) then f.ey:SetText(string.format("%d", math.floor(y + 0.5))) end

        if SupportsScale(key) then
            f.ls:Show()
            f.es:Show()
            if not f.es:HasFocus() then
                f.es:SetText(string.format("%.2f", GetScaleValue(key)))
            end
        else
            f.ls:Hide()
            f.es:Hide()
        end

        if SupportsResize(key) then
            f.lw:Show()
            f.ew:Show()
            f.lh:Show()
            f.eh:Show()
            local w, h = GetResizeValue(key)
            if not f.ew:HasFocus() then f.ew:SetText(string.format("%d", math.floor(w + 0.5))) end
            if not f.eh:HasFocus() then f.eh:SetText(string.format("%d", math.floor(h + 0.5))) end
        else
            f.lw:Hide()
            f.ew:Hide()
            f.lh:Hide()
            f.eh:Hide()
        end

        local entry = Movers._registered[key]
        local title = (entry and entry.label) or key or ""
        f.title:SetText(L("Inspector: %s"):format(title))
    end

    local function CommitInspectorValues(key, frame, x, y, scale, width, height)
        local spec = GetSpec(key)
        if not (spec and frame and Transactions) then return false end

        local writes = {}
        local applyKeys = {}
        local panelKey = spec.panelKey or "editmode"

        if SupportsScale(key) and type(scale) == "number" then
            scale = Clamp(scale, 0.60, 1.30)
            local previewOK, previewDetail = Transactions:Preview(spec, frame, "scale", scale)
            if not previewOK then
                Transactions:Restore(spec.applyKeys)
                if Log and Log.Warn then Log:Warn("Mover inspector scale preview failed: " .. tostring(previewDetail)) end
                return false
            end
            local scaleWrites, detail = Transactions:BuildWrites(spec, "scale", scale)
            if not scaleWrites then
                Transactions:Restore(spec.applyKeys)
                if Log and Log.Warn then Log:Warn("Mover inspector scale build failed: " .. tostring(detail)) end
                return false
            end
            AppendWrites(writes, scaleWrites)
            applyKeys = Transactions:MergeApplyKeys(applyKeys, spec.applyKeys)
        end

        if SupportsResize(key) and type(width) == "number" and type(height) == "number" then
            local previewWidth, previewHeight = PreviewResizeValue(key, width, height)
            if type(previewWidth) ~= "number" or type(previewHeight) ~= "number" then
                Transactions:Restore(Transactions:MergeApplyKeys(applyKeys, spec.applyKeys))
                return false
            end
            local sizeWrites, detail = Transactions:BuildWrites(spec, "size", previewWidth, previewHeight)
            previewSizes[key] = nil
            if not sizeWrites then
                Transactions:Restore(Transactions:MergeApplyKeys(applyKeys, spec.applyKeys))
                if Log and Log.Warn then Log:Warn("Mover inspector size build failed: " .. tostring(detail)) end
                return false
            end
            AppendWrites(writes, sizeWrites)
            applyKeys = Transactions:MergeApplyKeys(applyKeys, spec.applyKeys)
        end

        if type(x) == "number" and type(y) == "number" then
            local fw, fh = GetFrameSnapSize(frame)
            x, y = ClampCenterOffsets(x, y, fw, fh)
            SetPosition(key, frame, x, y)
            if type(BuildStoredPointWrites) ~= "function" then
                Transactions:Restore(Transactions:MergeApplyKeys(applyKeys, spec.applyKeys, "movers"))
                return false
            end
            local positionWrites, positionKeys, positionPanel, detail = BuildStoredPointWrites(key, frame)
            if not positionWrites then
                Transactions:Restore(Transactions:MergeApplyKeys(applyKeys, spec.applyKeys, positionKeys or "movers"))
                if Log and Log.Warn then Log:Warn("Mover inspector position build failed: " .. tostring(detail)) end
                return false
            end
            AppendWrites(writes, positionWrites)
            applyKeys = Transactions:MergeApplyKeys(applyKeys, positionKeys)
            panelKey = positionPanel or panelKey
        end

        if #writes == 0 then return false end
        local changed, detail = Transactions:CommitWrites(applyKeys, writes, panelKey)
        if changed == false and detail and Log and Log.Warn then
            Log:Warn("Mover inspector commit failed: " .. tostring(detail))
        end
        return changed == true
    end

    local function ShowInspectorFor(key, overlay)
        local entry = Movers._registered[key]
        if not entry or not entry.frame then
            return
        end

        local f = EnsureInspector()
        f._overlay = overlay
        PositionInspector(f, overlay)

        f._key = key
        f._frame = entry.frame

        function f:OnCommit()
            if not IsSafeToEdit() then
                Log:Warn(L("Cannot edit frames in combat."))
                return
            end

            local inspectKey = self._key
            local inspectFrame = self._frame
            if not inspectKey or not inspectFrame then
                return
            end

            CommitInspectorValues(
                inspectKey,
                inspectFrame,
                tonumber(self.ex:GetText()),
                tonumber(self.ey:GetText()),
                SupportsScale(inspectKey) and tonumber(self.es:GetText()) or nil,
                SupportsResize(inspectKey) and tonumber(self.ew:GetText()) or nil,
                SupportsResize(inspectKey) and tonumber(self.eh:GetText()) or nil
            )
            UpdateInspector(inspectKey, inspectFrame)
        end

        f:Show()
        UpdateInspector(key, entry.frame)
    end

    return {
        EnsureInspector = EnsureInspector,
        HideInspector = HideInspector,
        GetPosition = GetPosition,
        SetPosition = SetPosition,
        SupportsScale = SupportsScale,
        SupportsResize = SupportsResize,
        GetResizeValue = GetResizeValue,
        PreviewResizeValue = PreviewResizeValue,
        CancelResizePreview = CancelResizePreview,
        SetResizeValue = SetResizeValue,
        GetScaleValue = GetScaleValue,
        SetScaleValue = SetScaleValue,
        ComputeWheelResizePair = ComputeWheelResizePair,
        HandleWheelAction = HandleWheelAction,
        UpdateInspector = UpdateInspector,
        ShowInspectorFor = ShowInspectorFor,
    }
end
