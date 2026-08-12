-- FeelsGoodUI: Movers grid/guides/snap engine

local _, ns = ...

local SnapGrid = {}
ns.MoversSnapGrid = SnapGrid

function SnapGrid.Create(ctx)
    ctx = ctx or {}

    local Movers = ctx.Movers
    local UIWH = ctx.UIWH
    local UIParentRect = ctx.UIParentRect
    local GridStep = ctx.GridStep
    local EditorCfg = ctx.EditorCfg
    local GetFrameSnapBounds = ctx.GetFrameSnapBounds
    local ClampCenterOffsets = ctx.ClampCenterOffsets
    local RoundToStep = ctx.RoundToStep

    local wipeTable = _G.wipe or table.wipe

    local function EnsureGridBuilt()
        local g = Movers._grid
        if not g.frame then
            local f = CreateFrame("Frame", nil, UIParent)
            f:SetAllPoints(UIParent)
            f:SetFrameStrata("BACKGROUND")
            f:SetFrameLevel(1)
            f:Hide()

            g.frame = f
            g.textures = {}
            g.activeCount = 0
        end

        local w, h = UIWH()
        local step = GridStep()

        if w <= 0 or h <= 0 then
            return
        end
        if g.builtW == w and g.builtH == h and g.step == step then
            return
        end

        local function AcquireLineTexture()
            local nextIndex = (g.activeCount or 0) + 1
            local texture = g.textures[nextIndex]
            if not texture then
                texture = g.frame:CreateTexture(nil, "BACKGROUND")
                g.textures[nextIndex] = texture
            end
            g.activeCount = nextIndex
            return texture
        end

        local function LineV(x, alpha)
            local texture = AcquireLineTexture()
            texture:SetColorTexture(1, 1, 1, alpha)
            texture:ClearAllPoints()
            texture:SetPoint("TOPLEFT", g.frame, "TOPLEFT", x, 0)
            texture:SetPoint("BOTTOMLEFT", g.frame, "BOTTOMLEFT", x, 0)
            texture:SetWidth(1)
            texture:Show()
        end

        local function LineH(y, alpha)
            local texture = AcquireLineTexture()
            texture:SetColorTexture(1, 1, 1, alpha)
            texture:ClearAllPoints()
            texture:SetPoint("BOTTOMLEFT", g.frame, "BOTTOMLEFT", 0, y)
            texture:SetPoint("BOTTOMRIGHT", g.frame, "BOTTOMRIGHT", 0, y)
            texture:SetHeight(1)
            texture:Show()
        end

        g.activeCount = 0

        local faint = 0.10
        local strong = 0.25

        local x = 0
        while x <= w do
            LineV(x, faint)
            x = x + step
        end

        local y = 0
        while y <= h do
            LineH(y, faint)
            y = y + step
        end

        LineV(w * 0.5, strong)
        LineH(h * 0.5, strong)

        for i = (g.activeCount + 1), #g.textures do
            local texture = g.textures[i]
            if texture and texture.Hide then
                texture:Hide()
            end
        end

        g.builtW = w
        g.builtH = h
        g.step = step
    end

    local function SetGridVisible(show)
        local g = Movers._grid
        if not g then
            return
        end

        if show then
            EnsureGridBuilt()
            if g.frame then
                g.frame:Show()
            end
        elseif g.frame then
            g.frame:Hide()
        end
    end

    local function EnsureGuides()
        if Movers._guides then
            return Movers._guides
        end

        local f = CreateFrame("Frame", nil, UIParent)
        f:SetAllPoints(UIParent)
        f:SetFrameStrata("TOOLTIP")
        f:SetFrameLevel(5)
        f:Hide()

        local v = f:CreateTexture(nil, "OVERLAY")
        v:SetColorTexture(0, 0.8, 1, 0.55)
        v:SetWidth(1)
        v:Hide()

        local h = f:CreateTexture(nil, "OVERLAY")
        h:SetColorTexture(0, 0.8, 1, 0.55)
        h:SetHeight(1)
        h:Hide()

        local m = f:CreateTexture(nil, "OVERLAY")
        m:SetColorTexture(0, 0.8, 1, 0.85)
        m:SetSize(6, 6)
        m:Hide()

        Movers._guides = { frame = f, v = v, h = h, m = m }
        return Movers._guides
    end

    local function HideGuides()
        local guides = Movers._guides
        if not guides then
            return
        end
        if guides.v then guides.v:Hide() end
        if guides.h then guides.h:Hide() end
        if guides.m then guides.m:Hide() end
        if guides.frame then guides.frame:Hide() end
    end

    local function ShowGuides(xAbs, yAbs, style)
        local cfg = EditorCfg()
        if not cfg.showGuides then
            HideGuides()
            return
        end

        local guides = EnsureGuides()
        local W, H = UIWH()
        if W <= 0 or H <= 0 then
            return
        end

        local r, g, b, a = 0, 0.8, 1, 0.65
        local thickness = 2
        if style == "grid" then
            r, g, b, a = 0.2, 1, 0.35, 0.40
            thickness = 1
        end

        guides.v:SetColorTexture(r, g, b, a)
        guides.h:SetColorTexture(r, g, b, a)
        guides.v:SetWidth(thickness)
        guides.h:SetHeight(thickness)
        if guides.m then
            guides.m:SetColorTexture(r, g, b, math.min(1, a + 0.20))
            guides.m:SetSize(6 + thickness, 6 + thickness)
        end

        guides.frame:Show()

        if type(xAbs) == "number" then
            guides.v:ClearAllPoints()
            guides.v:SetPoint("TOPLEFT", guides.frame, "TOPLEFT", xAbs, 0)
            guides.v:SetPoint("BOTTOMLEFT", guides.frame, "BOTTOMLEFT", xAbs, 0)
            guides.v:Show()
        else
            guides.v:Hide()
        end

        if type(yAbs) == "number" then
            guides.h:ClearAllPoints()
            guides.h:SetPoint("BOTTOMLEFT", guides.frame, "BOTTOMLEFT", 0, yAbs)
            guides.h:SetPoint("BOTTOMRIGHT", guides.frame, "BOTTOMRIGHT", 0, yAbs)
            guides.h:Show()
        else
            guides.h:Hide()
        end

        if guides.m then
            if type(xAbs) == "number" and type(yAbs) == "number" then
                guides.m:ClearAllPoints()
                guides.m:SetPoint("CENTER", guides.frame, "BOTTOMLEFT", xAbs, yAbs)
                guides.m:Show()
            else
                guides.m:Hide()
            end
        end
    end

    local function BuildSnapTargets(activeKey, cfg)
        cfg = cfg or EditorCfg()

        local xt = Movers._snapScratch.xt
        local yt = Movers._snapScratch.yt
        if type(wipeTable) == "function" then
            wipeTable(xt)
            wipeTable(yt)
        else
            for key in pairs(xt) do xt[key] = nil end
            for key in pairs(yt) do yt[key] = nil end
        end

        local parentLeft, parentBottom, W, H = UIParentRect()
        if W <= 0 or H <= 0 then
            return xt, yt
        end

        xt[#xt + 1] = { pos = 0, src = "screen" }
        xt[#xt + 1] = { pos = W * 0.5, src = "screen" }
        xt[#xt + 1] = { pos = W, src = "screen" }

        yt[#yt + 1] = { pos = 0, src = "screen" }
        yt[#yt + 1] = { pos = H * 0.5, src = "screen" }
        yt[#yt + 1] = { pos = H, src = "screen" }

        if cfg.snapToFrames then
            for key, entry in pairs(Movers._registered) do
                if key ~= activeKey and entry and entry.frame and entry.frame.IsShown and entry.frame:IsShown() then
                    local l, b, r, t = GetFrameSnapBounds(entry.frame, parentLeft, parentBottom, W, H)

                    if type(l) == "number" and type(r) == "number" then
                        xt[#xt + 1] = { pos = l, src = key }
                        xt[#xt + 1] = { pos = r, src = key }
                        xt[#xt + 1] = { pos = (l + r) * 0.5, src = key }
                    end

                    if type(b) == "number" and type(t) == "number" then
                        yt[#yt + 1] = { pos = b, src = key }
                        yt[#yt + 1] = { pos = t, src = key }
                        yt[#yt + 1] = { pos = (b + t) * 0.5, src = key }
                    end
                end
            end
        end

        return xt, yt
    end

    local function SnapOffsets(x, y, fw, fh, xt, yt, cfg)
        cfg = cfg or EditorCfg()
        if not cfg.snapEnabled then
            HideGuides()
            return x, y
        end

        local W, H = UIWH()
        if W <= 0 or H <= 0 then
            HideGuides()
            return x, y
        end

        local absCx = (W * 0.5) + x
        local absCy = (H * 0.5) + y

        local left = absCx - (fw * 0.5)
        local right = absCx + (fw * 0.5)
        local bottom = absCy - (fh * 0.5)
        local top = absCy + (fh * 0.5)

        local bestDX, bestDY = 0, 0
        local guideX, guideY = nil, nil
        local th = cfg.snapThreshold

        local bestAbs = th + 1
        for _, target in ipairs(xt) do
            local tx = target.pos
            if type(tx) == "number" then
                local d1 = tx - left
                local a1 = math.abs(d1)
                if a1 < bestAbs and a1 <= th then
                    bestAbs = a1
                    bestDX = d1
                    guideX = tx
                end

                local d2 = tx - right
                local a2 = math.abs(d2)
                if a2 < bestAbs and a2 <= th then
                    bestAbs = a2
                    bestDX = d2
                    guideX = tx
                end

                local d3 = tx - absCx
                local a3 = math.abs(d3)
                if a3 < bestAbs and a3 <= th then
                    bestAbs = a3
                    bestDX = d3
                    guideX = tx
                end
            end
        end

        bestAbs = th + 1
        for _, target in ipairs(yt) do
            local ty = target.pos
            if type(ty) == "number" then
                local d1 = ty - bottom
                local a1 = math.abs(d1)
                if a1 < bestAbs and a1 <= th then
                    bestAbs = a1
                    bestDY = d1
                    guideY = ty
                end

                local d2 = ty - top
                local a2 = math.abs(d2)
                if a2 < bestAbs and a2 <= th then
                    bestAbs = a2
                    bestDY = d2
                    guideY = ty
                end

                local d3 = ty - absCy
                local a3 = math.abs(d3)
                if a3 < bestAbs and a3 <= th then
                    bestAbs = a3
                    bestDY = d3
                    guideY = ty
                end
            end
        end

        local snapped = (bestDX ~= 0) or (bestDY ~= 0)
        local guideStyle = snapped and "target" or nil

        x = x + bestDX
        y = y + bestDY

        if (not snapped) and cfg.snapToGrid then
            local step = GridStep()
            local gx = RoundToStep(x, step)
            local gy = RoundToStep(y, step)
            local snappedGX = (gx ~= x)
            local snappedGY = (gy ~= y)
            x, y = gx, gy
            if snappedGX then guideX = (W * 0.5) + x end
            if snappedGY then guideY = (H * 0.5) + y end
            if snappedGX or snappedGY then
                guideStyle = "grid"
            end
        end

        x, y = ClampCenterOffsets(x, y, fw, fh)

        if guideStyle then
            ShowGuides(guideX, guideY, guideStyle)
        else
            HideGuides()
        end

        return x, y
    end

    return {
        EnsureGridBuilt = EnsureGridBuilt,
        SetGridVisible = SetGridVisible,
        BuildSnapTargets = BuildSnapTargets,
        SnapOffsets = SnapOffsets,
        HideGuides = HideGuides,
    }
end
