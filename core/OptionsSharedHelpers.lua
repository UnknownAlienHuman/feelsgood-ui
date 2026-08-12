-- FeelsGoodUI: shared Options widget + apply helpers

local _, ns = ...

local DB = ns.DB
local Log = ns.Log
local Movers = ns.Movers
local Media = ns.Media
local Perf = ns.Perf
local Apply = ns.Apply
local Settings = ns.Settings
local MinimapIcon = ns.MinimapIcon
local L = ns.L or function(text) return text end

local Shared = ns.OptionsShared or {}
ns.OptionsShared = Shared

local function SetWidgetText(widget, text)
    if not widget then return end

    local fs = widget.Text or widget.text
    if not fs and widget.GetName then
        local name = widget:GetName()
        if name and _G[name .. "Text"] then
            fs = _G[name .. "Text"]
        end
    end
    if not fs and widget.GetRegions then
        for _, r in ipairs({ widget:GetRegions() }) do
            if r and r.SetText then
                fs = r
                break
            end
        end
    end
    if fs and fs.SetText then
        fs:SetText(text)
    end
end

local function HookAdaptiveWidth(widget, owner, applyFn)
    if not (widget and owner and type(applyFn) == "function") then
        return
    end

    local function SafeApply()
        local ok = pcall(applyFn)
        if not ok then
            -- noop: avoid breaking settings panel if width calc fails on hidden frames.
        end
    end

    SafeApply()
    if not widget._fguiAdaptiveWidthHooked then
        widget._fguiAdaptiveWidthHooked = true
        if owner.HookScript then
            owner:HookScript("OnSizeChanged", SafeApply)
            owner:HookScript("OnShow", SafeApply)
        end
        if widget.HookScript then
            widget:HookScript("OnShow", SafeApply)
        end
    end
end

local function CreateHeader(parent, text, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    fs:SetPoint("TOPLEFT", 16, y)
    fs:SetText(L(text))
    fs:SetTextColor(1, 1, 1)
    return fs
end

local function CreateSubHeader(parent, text, anchor, x, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -14)
    fs:SetText(L(text))
    return fs
end

local function CreateNote(parent, text, anchor, x, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -6)
    fs:SetWidth(520)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetText(L(text))
    HookAdaptiveWidth(fs, parent, function()
        local pw = tonumber(parent:GetWidth()) or 620
        local newWidth = math.floor(pw - 44)
        if newWidth < 180 then newWidth = 180 end
        fs:SetWidth(newWidth)
    end)
    return fs
end

local function CreateCheck(parent, label, tooltip, anchor, x, y)
    local b = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -8)
    SetWidgetText(b, L(label))
    if tooltip then
        b.tooltipText = L(tooltip)
    end
    return b
end

local function CreateButton(parent, label, width, anchor, x, y)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 160, 22)
    b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -10)
    b:SetText(L(label))
    return b
end

local function SetButtonEnabled(btn, enabled)
    if not btn then return end
    enabled = (enabled == true)
    if btn.SetEnabled then
        btn:SetEnabled(enabled)
        return
    end
    if enabled then
        if btn.Enable then btn:Enable() end
    else
        if btn.Disable then btn:Disable() end
    end
end

local function CreateSlider(parent, label, minv, maxv, step, anchor, x, y)
    local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -18)
    s:SetMinMaxValues(minv, maxv)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:SetWidth(300)
    HookAdaptiveWidth(s, parent, function()
        local pw = tonumber(parent:GetWidth()) or 620
        -- Keep room for numeric editbox + +/- buttons on the right.
        local w = math.floor(pw - 250)
        if w < 180 then w = 180 end
        if w > 420 then w = 420 end
        s:SetWidth(w)
    end)

    SetWidgetText(s, L(label))
    if s.Low and s.Low.SetText then s.Low:SetText(tostring(minv)) end
    if s.High and s.High.SetText then s.High:SetText(tostring(maxv)) end
    return s
end

-- Small numeric edit box next to sliders (Stage 41: precise values).
local function AttachNumericEditBox(slider, opts)
    if not slider then return nil end
    opts = opts or {}

    local parent = slider:GetParent()
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetAutoFocus(false)
    eb:SetSize(opts.width or 46, opts.height or 20)
    eb:SetPoint("LEFT", slider, "RIGHT", opts.offsetX or 24, 0)
    eb:SetJustifyH("CENTER")

    local decimals = tonumber(opts.decimals) or 0
    local isInt = opts.int == true

    local btnW = opts.buttonWidth or 16
    local btnH = opts.buttonHeight or 20
    local decBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    decBtn:SetSize(btnW, btnH)
    decBtn:SetPoint("RIGHT", eb, "LEFT", -3, 0)
    decBtn:SetText("-")

    local incBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    incBtn:SetSize(btnW, btnH)
    incBtn:SetPoint("LEFT", eb, "RIGHT", 3, 0)
    incBtn:SetText("+")

    local updating = false

    local function ClampAndQuantize(v)
        local n = tonumber(v)
        if type(n) ~= "number" then return nil end

        local minV, maxV = slider:GetMinMaxValues()
        if type(minV) == "number" and n < minV then n = minV end
        if type(maxV) == "number" and n > maxV then n = maxV end

        local step = slider:GetValueStep()
        if type(step) == "number" and step > 0 and type(minV) == "number" then
            n = minV + math.floor(((n - minV) / step) + 0.5) * step
        end

        if isInt then
            n = math.floor(n + 0.5)
        elseif decimals > 0 then
            local mul = 10 ^ decimals
            n = math.floor((n * mul) + 0.5) / mul
        end

        if type(minV) == "number" and n < minV then n = minV end
        if type(maxV) == "number" and n > maxV then n = maxV end
        return n
    end

    local function Format(v)
        v = tonumber(v) or 0
        if isInt then
            return tostring(math.floor(v + 0.5))
        end
        if decimals <= 0 then
            return tostring(math.floor(v + 0.5))
        end
        return string.format("%0." .. tostring(decimals) .. "f", v)
    end

    local function SyncFromSlider()
        if updating then return end
        updating = true
        eb:SetText(Format(slider:GetValue()))
        updating = false
    end

    local function CommitFromInput(raw)
        local n = ClampAndQuantize(raw)
        if type(n) ~= "number" then
            return false
        end
        slider:SetValue(n)
        return true
    end

    slider:HookScript("OnValueChanged", function()
        SyncFromSlider()
    end)
    slider:HookScript("OnShow", function()
        SyncFromSlider()
    end)
    local sliderParent = slider:GetParent()
    if sliderParent and sliderParent.HookScript and not slider._fguiNumericParentHooked then
        slider._fguiNumericParentHooked = true
        sliderParent:HookScript("OnShow", function()
            SyncFromSlider()
        end)
    end

    eb:SetScript("OnEnterPressed", function(self)
        if not CommitFromInput(self:GetText()) then
            SyncFromSlider()
        end
        self:ClearFocus()
    end)

    eb:SetScript("OnEscapePressed", function(self)
        SyncFromSlider()
        self:ClearFocus()
    end)

    eb:SetScript("OnEditFocusLost", function(self)
        if not CommitFromInput(self:GetText()) then
            SyncFromSlider()
        end
    end)

    decBtn:SetScript("OnClick", function()
        if slider.IsEnabled and (not slider:IsEnabled()) then return end
        local step = slider:GetValueStep()
        if type(step) ~= "number" or step <= 0 then step = 1 end
        local cur = tonumber(slider:GetValue()) or 0
        slider:SetValue(cur - step)
    end)

    incBtn:SetScript("OnClick", function()
        if slider.IsEnabled and (not slider:IsEnabled()) then return end
        local step = slider:GetValueStep()
        if type(step) ~= "number" or step <= 0 then step = 1 end
        local cur = tonumber(slider:GetValue()) or 0
        slider:SetValue(cur + step)
    end)

    SyncFromSlider()
    return eb, decBtn, incBtn
end

local function CreateStatusLine(parent, anchor, x, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -2)
    fs:SetWidth(560)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetText("")
    HookAdaptiveWidth(fs, parent, function()
        local pw = tonumber(parent:GetWidth()) or 620
        local newWidth = math.floor(pw - 36)
        if newWidth < 180 then newWidth = 180 end
        fs:SetWidth(newWidth)
    end)
    return fs
end

local function CreateRadio(parent, label, anchor, x, y)
    local r = CreateFrame("CheckButton", nil, parent, "UIRadioButtonTemplate")
    r:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -6)
    SetWidgetText(r, L(label))
    return r
end

local function CreateDropdown(parent, label, width, anchor, x, y)
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -10)
    title:SetText(L(label))

    local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -16, -4)
    local preferred = tonumber(width) or 260
    UIDropDownMenu_SetWidth(dd, preferred)
    HookAdaptiveWidth(dd, parent, function()
        local pw = tonumber(parent:GetWidth()) or 620
        local maxWidth = math.floor(pw - 120)
        if maxWidth < 140 then maxWidth = 140 end
        local target = preferred
        if target > maxWidth then
            target = maxWidth
        end
        UIDropDownMenu_SetWidth(dd, target)
    end)
    return dd
end

local FRAME_STRATA_VALUES = {
    "BACKGROUND",
    "LOW",
    "MEDIUM",
    "HIGH",
    "DIALOG",
    "FULLSCREEN",
    "FULLSCREEN_DIALOG",
    "TOOLTIP",
}

local function CreateScrollablePanel(name, contentHeight)
    local root = CreateFrame("Frame")
    root.name = L(name)
    root:SetClipsChildren(true)

    local scroll = CreateFrame("ScrollFrame", nil, root, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", root, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -28, 8)
    scroll:SetClipsChildren(true)
    scroll:EnableMouseWheel(true)
    if scroll.SetHorizontalScroll then
        scroll:SetHorizontalScroll(0)
    end

    local content = CreateFrame("Frame", nil, scroll)
    content:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    content:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 0)
    content:SetHeight(contentHeight or 1000)
    content:SetClipsChildren(true)
    content:EnableMouseWheel(true)
    scroll:SetScrollChild(content)

    local function ScrollByDelta(self, delta)
        local step = 36
        local cur = tonumber(self:GetVerticalScroll()) or 0
        local maxScroll = 0
        if self.ScrollBar and self.ScrollBar.GetMinMaxValues then
            local _, mx = self.ScrollBar:GetMinMaxValues()
            maxScroll = tonumber(mx) or 0
        else
            local ch = (content.GetHeight and content:GetHeight()) or 0
            local vh = (self.GetHeight and self:GetHeight()) or 0
            maxScroll = math.max(0, ch - vh)
        end
        local nextValue = cur - ((tonumber(delta) or 0) * step)
        if nextValue < 0 then nextValue = 0 end
        if nextValue > maxScroll then nextValue = maxScroll end
        self:SetVerticalScroll(nextValue)
        if self.SetHorizontalScroll then
            self:SetHorizontalScroll(0)
        end
    end
    scroll:SetScript("OnMouseWheel", ScrollByDelta)
    content:SetScript("OnMouseWheel", function(_, delta)
        ScrollByDelta(scroll, delta)
    end)

    root._scroll = scroll
    root._scrollContent = content
    root._contentBaseHeight = contentHeight or 1000

    local function AttachChildWheelProxy(frame)
        if not frame or frame == content or frame == scroll then return end
        if frame._fguiWheelProxy then return end
        if not (frame.EnableMouseWheel and frame.HookScript) then return end

        frame._fguiWheelProxy = true
        frame:EnableMouseWheel(true)
        frame:HookScript("OnMouseWheel", function(_, delta)
            ScrollByDelta(scroll, delta)
        end)
    end

    local function RefreshWheelProxies()
        for _, child in ipairs({ content:GetChildren() }) do
            AttachChildWheelProxy(child)
        end
    end

    local function ComputeContentHeight(viewHeight)
        local top = content:GetTop()
        if type(top) ~= "number" then
            return math.max(root._contentBaseHeight or 1000, (tonumber(viewHeight) or 500) - 24)
        end

        local lowest = top
        local found = false

        for _, child in ipairs({ content:GetChildren() }) do
            if child and child.IsShown and child:IsShown() then
                local b = child:GetBottom()
                if type(b) == "number" then
                    if (not found) or b < lowest then
                        lowest = b
                    end
                    found = true
                end
            end
        end

        for _, region in ipairs({ content:GetRegions() }) do
            if region and region.IsShown and region:IsShown() then
                local b = region:GetBottom()
                if type(b) == "number" then
                    if (not found) or b < lowest then
                        lowest = b
                    end
                    found = true
                end
            end
        end

        local minHeight = math.max(root._contentBaseHeight or 1000, (tonumber(viewHeight) or 500) - 24)
        if not found then
            return minHeight
        end

        local needed = math.ceil((top - lowest) + 34)
        if needed < minHeight then
            needed = minHeight
        end
        return needed
    end

    root._reflow = function()
        local width = tonumber(root:GetWidth()) or 620
        local viewHeight = tonumber(scroll:GetHeight()) or tonumber(root:GetHeight()) or 500
        content:SetWidth(math.max(260, width - 42))
        content:SetHeight(ComputeContentHeight(viewHeight))
        if scroll.SetHorizontalScroll then
            scroll:SetHorizontalScroll(0)
        end
        RefreshWheelProxies()
    end

    root:SetScript("OnSizeChanged", function(_, width, height)
        width = tonumber(width) or 620
        height = tonumber(height) or 500
        content:SetWidth(math.max(260, width - 42))
        local minHeight = math.max(root._contentBaseHeight or 1000, height - 24)
        if content:GetHeight() < minHeight then content:SetHeight(minHeight) end
        if root._reflow then
            root._reflow()
        end
    end)
    root:HookScript("OnShow", function()
        if _G.C_Timer and _G.C_Timer.After then
            _G.C_Timer.After(0, function()
                if root and root._reflow then
                    root._reflow()
                end
            end)
        elseif root and root._reflow then
            root._reflow()
        end
    end)

    return root, content
end

local function CreateColorSwatch(parent, label, anchor, x, y)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(420, 20)
    row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -8)

    local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", row, "LEFT", 0, 0)
    text:SetText(L(label))

    local swatch = CreateFrame("Button", nil, row, "BackdropTemplate")
    swatch:SetSize(24, 14)
    swatch:SetPoint("LEFT", text, "RIGHT", 8, 0)
    swatch:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Buttons/WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    swatch:SetBackdropColor(0, 0, 0, 1)
    swatch:SetBackdropBorderColor(0, 0, 0, 1)

    swatch.fill = swatch:CreateTexture(nil, "ARTWORK")
    swatch.fill:SetPoint("TOPLEFT", swatch, "TOPLEFT", 1, -1)
    swatch.fill:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -1, 1)
    swatch.fill:SetColorTexture(1, 1, 1, 1)

    return swatch, row
end

local function SetSwatchColor(swatch, r, g, b, a)
    if not (swatch and swatch.fill) then return end
    swatch.fill:SetColorTexture(r or 1, g or 1, b or 1, a or 1)
end

local function OpenColorPicker(initial, hasAlpha, onChanged)
    if not (_G.ColorPickerFrame and _G.ColorPickerFrame.SetupColorPickerAndShow) then
        return
    end
    if type(onChanged) ~= "function" then
        return
    end

    local r = tonumber(initial and initial.r) or 1
    local g = tonumber(initial and initial.g) or 1
    local b = tonumber(initial and initial.b) or 1
    local a = tonumber(initial and initial.a) or 1

    local function ApplyCurrent()
        local nr, ng, nb = _G.ColorPickerFrame:GetColorRGB()
        local na = hasAlpha and _G.ColorPickerFrame:GetColorAlpha() or a
        onChanged(nr, ng, nb, na)
    end

    _G.ColorPickerFrame:SetupColorPickerAndShow({
        r = r,
        g = g,
        b = b,
        opacity = a,
        hasOpacity = hasAlpha == true,
        swatchFunc = ApplyCurrent,
        opacityFunc = ApplyCurrent,
        cancelFunc = function(previousValues)
            if type(previousValues) == "table" then
                onChanged(previousValues.r, previousValues.g, previousValues.b, previousValues.a)
            else
                onChanged(r, g, b, a)
            end
        end,
    })
end

local function SetProfileValueRaw(path, value)
    if type(path) ~= "table" or #path < 2 then
        return false
    end

    local root
    if DB and DB.EnsureSection then
        root = DB:EnsureSection(path[1])
    elseif DB and DB.GetSection then
        root = DB:GetSection(path[1])
    end
    if type(root) ~= "table" then
        return false
    end

    local t = root
    for i = 2, #path - 1 do
        local k = path[i]
        t[k] = t[k] or {}
        t = t[k]
    end
    t[path[#path]] = value
    return true
end

local function SetProfileValue(path, value, rule, applyKeys, panelKey)
    if Settings and Settings.SetTx and (applyKeys ~= nil or (type(panelKey) == "string" and panelKey ~= "")) then
        return Settings:SetTx(applyKeys, path, value, rule, panelKey)
    end

    if Settings and Settings.Set then
        return Settings:Set(path, value, rule)
    end

    if SetProfileValueRaw(path, value) then
        return true, value
    end
    return false, nil
end

local warnedMissingApplyQueue = false
local function WarnMissingApplyQueue(scope)
    if warnedMissingApplyQueue then
        return
    end
    warnedMissingApplyQueue = true
    if Log and Log.Warn then
        Log:Warn(tostring(scope or "Options") .. ": apply queue unavailable; runtime refresh skipped.")
    end
end

local function RequestApply(keys, scope)
    if Apply and Apply.Request then
        Apply:Request(keys)
        return
    end
    WarnMissingApplyQueue(scope)
end

local SHARED_APPLY_RESOLVE_ORDER = {
    "runtime",
    "theme",
    "unitframes",
    "center",
    "actionbars",
    "companion",
    "minimap",
}

local APPLY_KEY_THEME = "theme"
local APPLY_KEYS_ACTIONBAR_HIDE = { "actionbars", "companion" }

local function NormalizeApplyKeyList(keys)
    if type(keys) == "string" then
        if keys ~= "" then
            return { keys }
        end
        return {}
    end
    if type(keys) ~= "table" then
        return {}
    end

    local out, seen = {}, {}
    for i = 1, #keys do
        local key = keys[i]
        if type(key) == "string" and key ~= "" and not seen[key] then
            seen[key] = true
            out[#out + 1] = key
        end
    end
    return out
end

local function CreatePendingApplyState(defaultKeys)
    return {
        defaultKeys = NormalizeApplyKeyList(defaultKeys),
        keys = {},
    }
end

local function ResetPendingApplyState(state)
    if type(state) ~= "table" or type(state.keys) ~= "table" then
        return
    end
    for key in pairs(state.keys) do
        state.keys[key] = nil
    end
end

local function AddPendingApplyKeys(state, keys)
    if type(state) ~= "table" or type(state.keys) ~= "table" then
        return
    end
    for _, key in ipairs(NormalizeApplyKeyList(keys)) do
        state.keys[key] = true
    end
end

local function ResolvePendingApplyKeys(state)
    if type(state) ~= "table" then
        return nil
    end

    local out, seen = {}, {}
    local function AddKey(key)
        if type(key) ~= "string" or key == "" or seen[key] then
            return
        end
        seen[key] = true
        out[#out + 1] = key
    end

    for i = 1, #(state.defaultKeys or {}) do
        AddKey(state.defaultKeys[i])
    end

    if type(state.keys) == "table" then
        for i = 1, #SHARED_APPLY_RESOLVE_ORDER do
            local key = SHARED_APPLY_RESOLVE_ORDER[i]
            if state.keys[key] then
                AddKey(key)
            end
        end
        for key in pairs(state.keys) do
            AddKey(key)
        end
    end

    if #out == 0 then
        return nil
    end
    if #out == 1 then
        return out[1]
    end
    return out
end

local function GetProfileSection(section)
    if DB and DB.GetSection then
        local value = DB:GetSection(section)
        if type(value) == "table" then
            return value
        end
    end
    return {}
end

local function GetLivePreview(panelKey)
    local options = GetProfileSection("options")
    local lp = options.livePreview
    if type(lp) == "table" and lp[panelKey] == false then
        return false
    end
    return true
end

local function SetLivePreview(panelKey, enabled)
    enabled = (enabled == true)
    SetProfileValue({ "options", "livePreview", panelKey }, enabled, { type = "boolean", fallback = true }, nil, "general")
end

local function NormalizeSectionList(sections)
    if type(sections) == "string" then
        if sections ~= "" then
            return { sections }
        end
        return {}
    end
    if type(sections) ~= "table" then
        return {}
    end

    local out, seen = {}, {}
    for i = 1, #sections do
        local section = sections[i]
        if type(section) == "string" and section ~= "" and not seen[section] then
            seen[section] = true
            out[#out + 1] = section
        end
    end
    return out
end

local function ResetProfileSections(sections)
    local list = NormalizeSectionList(sections)
    if #list == 0 or not Settings then
        return false
    end

    if type(Settings.ResetSections) == "function" then
        return Settings:ResetSections(list)
    end

    local didReset = false
    if type(Settings.ResetSection) == "function" then
        for i = 1, #list do
            didReset = Settings:ResetSection(list[i]) or didReset
        end
    end
    return didReset
end

local function CreatePanelApplyController(panelKey, defaultApplyKeys, liveCheck, applyBtn, statusLine)
    local state = {
        panelKey = panelKey,
        defaultApplyKeys = defaultApplyKeys,
        pending = false,
        pendingApply = CreatePendingApplyState(defaultApplyKeys),
        liveCheck = liveCheck,
        applyBtn = applyBtn,
        statusLine = statusLine,
    }

    function state:UpdateUI()
        local live = GetLivePreview(self.panelKey)
        if self.liveCheck then
            self.liveCheck:SetChecked(live)
        end
        if self.applyBtn then
            SetButtonEnabled(self.applyBtn, (not live) and self.pending)
        end
        if self.statusLine then
            if self.pending and (not live) then
                self.statusLine:SetText(L("Pending changes (press Apply now)."))
            else
                self.statusLine:SetText("")
            end
        end
    end

    function state:MarkPending(keys)
        AddPendingApplyKeys(self.pendingApply, keys or self.defaultApplyKeys)
        self.pending = true
        self:UpdateUI()
    end

    function state:ApplyNow(applyKeys)
        local keys = applyKeys or ResolvePendingApplyKeys(self.pendingApply) or self.defaultApplyKeys
        RequestApply(keys, self.panelKey)
        self.pending = false
        ResetPendingApplyState(self.pendingApply)
        self:UpdateUI()
    end

    function state:SetValue(path, value, rule, applyKeys, refreshing)
        if refreshing then
            return
        end

        local keys = applyKeys or self.defaultApplyKeys
        SetProfileValue(path, value, rule, keys, self.panelKey)
        AddPendingApplyKeys(self.pendingApply, keys)

        if GetLivePreview(self.panelKey) then
            self:ApplyNow(keys)
        else
            self.pending = true
            self:UpdateUI()
        end
    end

    return state
end

local function CreatePanelValueSetter(applyState, isRefreshing)
    return function(path, value, rule, applyKeys)
        local refreshing = false
        if type(isRefreshing) == "function" then
            refreshing = (isRefreshing() == true)
        else
            refreshing = (isRefreshing == true)
        end
        applyState:SetValue(path, value, rule, applyKeys, refreshing)
    end
end

local function BindPanelApplyControls(applyState, undoBtn, resetBtn, resetSections, refreshFn, restoreApplyKeys)
    if type(applyState) ~= "table" then
        return
    end

    local function RefreshPanel()
        if type(refreshFn) == "function" then
            refreshFn()
        end
    end

    if applyState.liveCheck then
        applyState.liveCheck:SetScript("OnClick", function(self)
            local enabled = self:GetChecked() and true or false
            SetLivePreview(applyState.panelKey, enabled)
            if enabled and applyState.pending then
                applyState:ApplyNow()
            else
                applyState:UpdateUI()
            end
        end)
    end

    if applyState.applyBtn then
        applyState.applyBtn:SetScript("OnClick", function()
            applyState:ApplyNow()
            RefreshPanel()
        end)
    end

    if undoBtn then
        undoBtn:SetScript("OnClick", function()
            if Settings and Settings.UndoPanel and Settings:UndoPanel(applyState.panelKey) then
                applyState:ApplyNow(restoreApplyKeys)
                RefreshPanel()
            end
        end)
    end

    if resetBtn then
        resetBtn:SetScript("OnClick", function()
            if ResetProfileSections(resetSections) then
                local invalidateKeys = restoreApplyKeys or applyState.defaultApplyKeys
                if Settings and Settings.InvalidatePanelHistory then
                    Settings:InvalidatePanelHistory(applyState.panelKey, invalidateKeys)
                end
                applyState.pending = false
                applyState:ApplyNow(restoreApplyKeys)
                RefreshPanel()
            end
        end)
    end
end

function Shared.CreateBuilderContext()
    return {
        DB = DB,
        Log = Log,
        Movers = Movers,
        Media = Media,
        Perf = Perf,
        Apply = Apply,
        Settings = Settings,
        MinimapIcon = MinimapIcon,
        L = L,
        CreateHeader = CreateHeader,
        CreateSubHeader = CreateSubHeader,
        CreateNote = CreateNote,
        CreateCheck = CreateCheck,
        CreateButton = CreateButton,
        CreateSlider = CreateSlider,
        AttachNumericEditBox = AttachNumericEditBox,
        CreateStatusLine = CreateStatusLine,
        CreateRadio = CreateRadio,
        CreateDropdown = CreateDropdown,
        CreateScrollablePanel = CreateScrollablePanel,
        CreateColorSwatch = CreateColorSwatch,
        SetSwatchColor = SetSwatchColor,
        OpenColorPicker = OpenColorPicker,
        SetProfileValue = SetProfileValue,
        RequestApply = RequestApply,
        APPLY_KEY_THEME = APPLY_KEY_THEME,
        APPLY_KEYS_ACTIONBAR_HIDE = APPLY_KEYS_ACTIONBAR_HIDE,
        GetProfileSection = GetProfileSection,
        GetLivePreview = GetLivePreview,
        SetLivePreview = SetLivePreview,
        CreatePanelApplyController = CreatePanelApplyController,
        CreatePanelValueSetter = CreatePanelValueSetter,
        BindPanelApplyControls = BindPanelApplyControls,
        FRAME_STRATA_VALUES = FRAME_STRATA_VALUES,
    }
end

Shared.SetWidgetText = SetWidgetText
Shared.HookAdaptiveWidth = HookAdaptiveWidth
Shared.CreateHeader = CreateHeader
Shared.CreateSubHeader = CreateSubHeader
Shared.CreateNote = CreateNote
Shared.CreateCheck = CreateCheck
Shared.CreateButton = CreateButton
Shared.SetButtonEnabled = SetButtonEnabled
Shared.CreateSlider = CreateSlider
Shared.AttachNumericEditBox = AttachNumericEditBox
Shared.CreateStatusLine = CreateStatusLine
Shared.CreateRadio = CreateRadio
Shared.CreateDropdown = CreateDropdown
Shared.CreateScrollablePanel = CreateScrollablePanel
Shared.CreateColorSwatch = CreateColorSwatch
Shared.SetSwatchColor = SetSwatchColor
Shared.OpenColorPicker = OpenColorPicker
Shared.SetProfileValue = SetProfileValue
Shared.RequestApply = RequestApply
Shared.APPLY_KEY_THEME = APPLY_KEY_THEME
Shared.APPLY_KEYS_ACTIONBAR_HIDE = APPLY_KEYS_ACTIONBAR_HIDE
Shared.GetProfileSection = GetProfileSection
Shared.GetLivePreview = GetLivePreview
Shared.SetLivePreview = SetLivePreview
Shared.ResetProfileSections = ResetProfileSections
Shared.CreatePanelApplyController = CreatePanelApplyController
Shared.CreatePanelValueSetter = CreatePanelValueSetter
Shared.BindPanelApplyControls = BindPanelApplyControls
Shared.FRAME_STRATA_VALUES = FRAME_STRATA_VALUES
