-- FeelsGoodUI: Movers overlay/input/editor layer

local _, ns = ...

local EditorModule = {}
ns.MoversEditor = EditorModule

function EditorModule.Create(ctx)
    ctx = ctx or {}

    local Movers = ctx.Movers
    local Log = ctx.Log
    local Media = ctx.Media
    local L = ctx.L or function(text) return text end

    local IsSafeToEdit = ctx.IsSafeToEdit
    local GetCursorUI = ctx.GetCursorUI
    local Clamp = ctx.Clamp
    local EditorCfg = ctx.EditorCfg
    local EnsureCenterAnchor = ctx.EnsureCenterAnchor
    local GetPosition = ctx.GetPosition
    local BuildSnapTargets = ctx.BuildSnapTargets
    local SnapOffsets = ctx.SnapOffsets
    local GetFrameSnapSize = ctx.GetFrameSnapSize
    local ClampCenterOffsets = ctx.ClampCenterOffsets
    local SetPosition = ctx.SetPosition
    local UpdateInspector = ctx.UpdateInspector
    local ShowInspectorFor = ctx.ShowInspectorFor
    local HideInspector = ctx.HideInspector
    local HideGuides = ctx.HideGuides
    local SetActiveMover = ctx.SetActiveMover or function(key, overlay)
        Movers._activeKey = key
        Movers._activeOverlay = overlay
    end
    local SavePoint = ctx.SavePoint
    local SupportsResize = ctx.SupportsResize
    local GetResizeValue = ctx.GetResizeValue
    local SetResizeValue = ctx.SetResizeValue
    local HandleWheelAction = ctx.HandleWheelAction

    local GRIP_TEX_UP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"
    local GRIP_TEX_HL = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight"
    local GRIP_TEX_DOWN = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down"

    local function EnsureGlobalHint()
        if Movers._globalHint then return Movers._globalHint end

        local f = CreateFrame("Frame", nil, UIParent)
        f:SetFrameStrata("TOOLTIP")
        f:SetFrameLevel(20)
        f:SetPoint("TOP", UIParent, "TOP", 0, -24)
        f:SetSize(1600, 24)
        f:Hide()

        local fs = f:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("CENTER", f, "CENTER", 0, 0)
        fs:SetFont("Fonts\\FRIZQT__.TTF", 17, "OUTLINE")
        fs:SetTextColor(0.25, 1.00, 0.25, 1.00)
        fs:SetText(L("Shift = Drag, Ctrl+Wheel = scale (selected), Ctrl+Alt+Wheel = resize, Click = Inspector, Arrows = Nudge, Esc = Save+Close"))

        f.text = fs
        Movers._globalHint = f
        return f
    end

    local function SetGlobalHintVisible(show)
        local f = EnsureGlobalHint()
        if not f then
            return
        end
        if show then
            f:Show()
        else
            f:Hide()
        end
    end

    local function CreateOverlay(key, frame, label)
        local overlay = CreateFrame("Button", nil, UIParent)
        overlay:SetFrameStrata("TOOLTIP")
        overlay:SetFrameLevel((frame:GetFrameLevel() or 0) + 50)
        overlay:SetAllPoints(frame)

        overlay:EnableMouse(true)
        overlay:RegisterForDrag("LeftButton")
        overlay:RegisterForClicks("AnyUp")

        overlay.bg = overlay:CreateTexture(nil, "BACKGROUND")
        overlay.bg:SetAllPoints()
        overlay.bg:SetColorTexture(0.05, 0.85, 0.20, 0.16)

        Media:CreateBorder(overlay, 1)

        overlay.text = overlay:CreateFontString(nil, "OVERLAY")
        overlay.text:SetPoint("CENTER")
        overlay.text:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
        overlay.text:SetTextColor(0.20, 1.00, 0.25, 1.00)
        overlay.text:SetText(L(label or "Move"))
        overlay.text:SetJustifyH("CENTER")
        overlay.text:SetJustifyV("MIDDLE")

        overlay.hl = overlay:CreateTexture(nil, "BORDER")
        overlay.hl:SetAllPoints()
        overlay.hl:SetColorTexture(0.18, 1.00, 0.20, 0.24)
        overlay.hl:Hide()

        overlay.handle = CreateFrame("Button", nil, overlay)
        overlay.handle:SetSize(16, 16)
        overlay.handle:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, 0)
        overlay.handle:EnableMouse(true)
        overlay.handle:SetNormalTexture(GRIP_TEX_UP)
        overlay.handle:SetHighlightTexture(GRIP_TEX_HL, "ADD")
        overlay.handle:SetPushedTexture(GRIP_TEX_DOWN)

        local nt = overlay.handle:GetNormalTexture()
        if nt then
            nt:SetAlpha(0.95)
            nt:SetVertexColor(1.00, 0.20, 0.20)
        end
        local ht = overlay.handle:GetHighlightTexture()
        if ht then
            ht:SetAlpha(0.95)
            ht:SetVertexColor(1.00, 0.32, 0.32)
        end
        local pt = overlay.handle:GetPushedTexture()
        if pt then
            pt:SetAlpha(0.95)
            pt:SetVertexColor(1.00, 0.12, 0.12)
        end

        overlay._dragging = false
        overlay._resizing = false
        overlay._startCursorX = 0
        overlay._startCursorY = 0
        overlay._startX = 0
        overlay._startY = 0
        overlay._snapXT = nil
        overlay._snapYT = nil
        overlay._startW = 0
        overlay._startH = 0

        local function UpdateHandleVisibility()
            local cfg = EditorCfg()
            if cfg.resizeEnabled and SupportsResize(key) then
                overlay.handle:Show()
            else
                overlay.handle:Hide()
            end
        end

        overlay:SetScript("OnShow", UpdateHandleVisibility)

        overlay:SetScript("OnClick", function(_, button)
            if button ~= "LeftButton" or not Movers._unlocked then
                return
            end

            SetActiveMover(key, overlay)

            ShowInspectorFor(key, overlay)
        end)

        overlay:SetScript("OnEnter", function()
            if not Movers._unlocked or Movers._activeKey == key then
                return
            end
        end)

        overlay:SetScript("OnLeave", function()
            if not Movers._unlocked then
                return
            end
            if Movers._activeKey ~= key and not overlay._dragging and not overlay._resizing then
                HideGuides()
                HideInspector()
            end
        end)

        overlay:SetScript("OnDragStart", function()
            if not Movers._unlocked then
                return
            end
            if not IsSafeToEdit() then
                Log:Warn("Cannot move frames in combat.")
                return
            end
            if not IsShiftKeyDown() then
                return
            end

            EnsureCenterAnchor(key, frame)

            SetActiveMover(key, overlay)

            local cx, cy = GetCursorUI()
            local x, y = GetPosition(key, frame)

            overlay._startCursorX, overlay._startCursorY = cx, cy
            overlay._startX, overlay._startY = x, y

            local cfg = EditorCfg()
            if cfg.snapEnabled then
                overlay._snapXT, overlay._snapYT = BuildSnapTargets(key)
            else
                overlay._snapXT, overlay._snapYT = nil, nil
            end

            overlay._dragging = true

            ShowInspectorFor(key, overlay)
            UpdateInspector(key, frame)

            overlay:SetScript("OnUpdate", function()
                if not overlay._dragging then
                    return
                end

                local ccx, ccy = GetCursorUI()
                local dx = ccx - overlay._startCursorX
                local dy = ccy - overlay._startCursorY

                local nx = overlay._startX + dx
                local ny = overlay._startY + dy
                local fw, fh = GetFrameSnapSize(frame)

                if overlay._snapXT and overlay._snapYT then
                    nx, ny = SnapOffsets(nx, ny, fw, fh, overlay._snapXT, overlay._snapYT)
                else
                    nx, ny = ClampCenterOffsets(nx, ny, fw, fh)
                end

                SetPosition(key, frame, nx, ny)
                UpdateInspector(key, frame)
            end)
        end)

        overlay:SetScript("OnDragStop", function()
            if not overlay._dragging then
                return
            end
            overlay._dragging = false
            overlay:SetScript("OnUpdate", nil)
            HideGuides()
            SavePoint(key, frame)
            UpdateInspector(key, frame)
        end)

        overlay:EnableMouseWheel(true)
        overlay:SetScript("OnMouseWheel", function(_, delta)
            if not Movers._unlocked then
                return
            end
            if not IsSafeToEdit() then
                Log:Warn("Cannot resize frames in combat.")
                return
            end
            if not (_G.IsControlKeyDown and IsControlKeyDown()) then
                return
            end

            local altDown = (_G.IsAltKeyDown and IsAltKeyDown()) or false
            local shiftDown = (_G.IsShiftKeyDown and IsShiftKeyDown()) or false
            local changed = (type(HandleWheelAction) == "function") and HandleWheelAction(key, delta, shiftDown, altDown) == true

            if changed then
                UpdateInspector(key, frame)
            end
        end)

        overlay.handle:SetScript("OnMouseDown", function(_, btn)
            if btn ~= "LeftButton" or not Movers._unlocked then
                return
            end
            if not IsSafeToEdit() then
                Log:Warn("Cannot resize frames in combat.")
                return
            end

            local cfg = EditorCfg()
            if not (cfg.resizeEnabled and SupportsResize(key)) then
                return
            end

            EnsureCenterAnchor(key, frame)

            SetActiveMover(key, overlay)

            local cx, cy = GetCursorUI()
            overlay._startCursorX, overlay._startCursorY = cx, cy
            overlay._startW, overlay._startH = GetResizeValue(key)
            overlay._resizing = true

            ShowInspectorFor(key, overlay)
            UpdateInspector(key, frame)

            overlay:SetScript("OnUpdate", function()
                if not overlay._resizing then
                    return
                end

                local ccx, ccy = GetCursorUI()
                local dx = ccx - overlay._startCursorX
                local dy = ccy - overlay._startCursorY

                local nw = overlay._startW + dx
                local nh = overlay._startH - dy

                SetResizeValue(key, nw, nh)
                UpdateInspector(key, frame)
            end)
        end)

        overlay.handle:SetScript("OnMouseUp", function(_, btn)
            if btn ~= "LeftButton" or not overlay._resizing then
                return
            end
            overlay._resizing = false
            overlay:SetScript("OnUpdate", nil)
            UpdateInspector(key, frame)
        end)

        return overlay, UpdateHandleVisibility
    end

    local function HandleKeyDown(self, key)
        if not Movers._unlocked then
            return
        end

        if _G.ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then
            if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
            return
        end

        if key == "ESCAPE" then
            if self.SetPropagateKeyboardInput then
                self:SetPropagateKeyboardInput(false)
            end
            Movers:SetUnlocked(false)
            return
        end

        if not Movers._activeKey then
            if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
            return
        end

        local isArrow = (key == "LEFT" or key == "RIGHT" or key == "UP" or key == "DOWN")
        if not isArrow then
            if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
            return
        end

        if self.SetPropagateKeyboardInput then
            self:SetPropagateKeyboardInput(false)
        end

        if not IsSafeToEdit() then
            Log:Warn("Cannot nudge frames in combat.")
            return
        end

        local entry = Movers._registered[Movers._activeKey]
        if not entry or not entry.frame then
            return
        end

        local cfg = EditorCfg()
        local step = cfg.nudgeStep
        if IsShiftKeyDown() then
            step = cfg.nudgeStepLarge
        end

        local x, y = GetPosition(Movers._activeKey, entry.frame)
        if key == "LEFT" then x = x - step end
        if key == "RIGHT" then x = x + step end
        if key == "UP" then y = y + step end
        if key == "DOWN" then y = y - step end

        local fw, fh = GetFrameSnapSize(entry.frame)
        x, y = ClampCenterOffsets(x, y, fw, fh)

        SetPosition(Movers._activeKey, entry.frame, x, y)
        SavePoint(Movers._activeKey, entry.frame)
        UpdateInspector(Movers._activeKey, entry.frame)
    end

    local function EnsureKeyListener()
        local f = Movers._keyListener
        if not f then
            f = CreateFrame("Frame", nil, UIParent)
            f:SetScript("OnKeyDown", HandleKeyDown)
            Movers._keyListener = f
        end

        f:EnableKeyboard(true)
        if f.SetPropagateKeyboardInput then
            f:SetPropagateKeyboardInput(true)
        end
        if f.Show and not f:IsShown() then
            f:Show()
        end
    end

    local function DisableKeyListener()
        if not Movers._keyListener then
            return
        end
        Movers._keyListener:EnableKeyboard(false)
        if Movers._keyListener.SetPropagateKeyboardInput then
            Movers._keyListener:SetPropagateKeyboardInput(true)
        end
        if Movers._keyListener.Hide and Movers._keyListener:IsShown() then
            Movers._keyListener:Hide()
        end
    end

    return {
        SetGlobalHintVisible = SetGlobalHintVisible,
        CreateOverlay = CreateOverlay,
        EnsureKeyListener = EnsureKeyListener,
        DisableKeyListener = DisableKeyListener,
    }
end
