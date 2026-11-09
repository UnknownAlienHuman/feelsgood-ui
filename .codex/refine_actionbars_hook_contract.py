from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


state_path = Path('modules/ActionBarsState.lua')
state = state_path.read_text(encoding='utf-8')
state = replace_once(
    state,
    '''local function EnsureStateTexture(btn, record, name, drawLayer, subLevel, alpha, blendMode)
    record.layers = record.layers or {}
    local texture = record.layers[name]
    if not texture then
        if type(btn.CreateTexture) ~= "function" then
            return false, "ActionButton CreateTexture unavailable"
        end
        local ok, created = pcall(btn.CreateTexture, btn, nil, drawLayer, nil, subLevel)
        if not ok or not created then
            return false, ok and "ActionButton texture creation returned nil" or tostring(created)
        end
        texture = created
        record.layers[name] = texture
    end

    local ok, detail = pcall(function()
        texture:SetAllPoints(btn)
        texture:SetColorTexture(1, 1, 1, alpha)
        if blendMode then texture:SetBlendMode(blendMode) end
        texture:Hide()
    end)
    if not ok then
        return false, tostring(detail)
    end
    return true
end
''',
    '''local function EnsureStateTexture(btn, record, name, drawLayer, subLevel, alpha, blendMode)
    record.layers = record.layers or {}
    local readyField = name .. "Ready"
    if record[readyField] == true and record.layers[name] then
        return true
    end

    local texture = record.layers[name]
    if not texture then
        if type(btn.CreateTexture) ~= "function" then
            return false, "ActionButton CreateTexture unavailable"
        end
        local ok, created = pcall(btn.CreateTexture, btn, nil, drawLayer, nil, subLevel)
        if not ok or not created then
            return false, ok and "ActionButton texture creation returned nil" or tostring(created)
        end
        texture = created
        record.layers[name] = texture
    end

    local ok, detail = pcall(function()
        texture:SetAllPoints(btn)
        texture:SetColorTexture(1, 1, 1, alpha)
        if blendMode then texture:SetBlendMode(blendMode) end
        texture:Hide()
    end)
    if not ok then
        return false, tostring(detail)
    end

    record[readyField] = true
    return true
end
''',
    'state texture readiness',
)
state = replace_once(
    state,
    '''local function EnsureSlotBG(btn)
    local record = GetButtonRecord(btn, true)
    if not record then return false, "ActionButton record unavailable" end

    local bg = record.slotBackground
    if not bg then
        if type(btn.CreateTexture) ~= "function" then
            return false, "ActionButton CreateTexture unavailable"
        end
        local ok, created = pcall(btn.CreateTexture, btn, nil, "BACKGROUND")
        if not ok or not created then
            return false, ok and "ActionButton slot background creation returned nil" or tostring(created)
        end
        bg = created
        record.slotBackground = bg
    end

    local ok, detail = pcall(function()
        bg:SetAllPoints(btn)
        bg:SetColorTexture(1, 1, 1, 0.02)
        bg:Hide()
    end)
    if not ok then
        return false, tostring(detail)
    end
    return true
end
''',
    '''local function EnsureSlotBG(btn)
    local record = GetButtonRecord(btn, true)
    if not record then return false, "ActionButton record unavailable" end
    if record.slotBackgroundReady == true and record.slotBackground then
        return true
    end

    local bg = record.slotBackground
    if not bg then
        if type(btn.CreateTexture) ~= "function" then
            return false, "ActionButton CreateTexture unavailable"
        end
        local ok, created = pcall(btn.CreateTexture, btn, nil, "BACKGROUND")
        if not ok or not created then
            return false, ok and "ActionButton slot background creation returned nil" or tostring(created)
        end
        bg = created
        record.slotBackground = bg
    end

    local ok, detail = pcall(function()
        bg:SetAllPoints(btn)
        bg:SetColorTexture(1, 1, 1, 0.02)
        bg:Hide()
    end)
    if not ok then
        return false, tostring(detail)
    end

    record.slotBackgroundReady = true
    return true
end
''',
    'slot background readiness',
)
state = replace_once(
    state,
    '    if not (btn and record and record.skinned) then return false end\n',
    '    if not (btn and record and record.skinned) then return false, "ActionButton is not managed" end\n',
    'button initialization detail',
)
state_path.write_text(state, encoding='utf-8')


runtime_path = Path('modules/ActionBarsRuntime.lua')
runtime = runtime_path.read_text(encoding='utf-8')
runtime = replace_once(
    runtime,
    '''        if Visuals and Visuals.SkinButton then
            local ok, detail = Visuals.SkinButton(button, style)
            if ok == false then
                allOK = false
                firstDetail = firstDetail or detail or "ActionButton skin initialization failed"
            end
        end
        if Visuals and Visuals.RefreshButtonVisualState then
            local ok, detail = Visuals.RefreshButtonVisualState(button, style, showHotkeys)
            if ok == false then
                allOK = false
                firstDetail = firstDetail or detail or "ActionButton visual refresh failed"
            end
        end

        if State and State.AttachButtonAutoHideHooks then
            local ok, detail = State.AttachButtonAutoHideHooks(button, module)
            if ok == false then
                allOK = false
                firstDetail = firstDetail or detail or "ActionButton auto-hide hook registration failed"
            end
        end
''',
    '''        local skinOK = true
        if Visuals and Visuals.SkinButton then
            local ok, detail = Visuals.SkinButton(button, style)
            if ok == false then
                skinOK = false
                allOK = false
                firstDetail = firstDetail
                    or (tostring(prefix) .. tostring(i) .. ": " .. tostring(detail or "skin initialization failed"))
            end
        end
        if skinOK and Visuals and Visuals.RefreshButtonVisualState then
            local ok, detail = Visuals.RefreshButtonVisualState(button, style, showHotkeys)
            if ok == false then
                allOK = false
                firstDetail = firstDetail
                    or (tostring(prefix) .. tostring(i) .. ": " .. tostring(detail or "visual refresh failed"))
            end
        end

        if State and State.AttachButtonAutoHideHooks then
            local ok, detail = State.AttachButtonAutoHideHooks(button, module)
            if ok == false then
                allOK = false
                firstDetail = firstDetail
                    or (tostring(prefix) .. tostring(i) .. ": " .. tostring(detail or "auto-hide hook registration failed"))
            end
        end
''',
    'button detail and duplicate initialization guard',
)
runtime = replace_once(
    runtime,
    '''local function ApplyBarHolderConfig(module, holder, cfg, styleCfg, size, spacing, showHotkeys)
    if not holder then
        return false
    end
''',
    '''local function ApplyBarHolderConfig(module, holder, cfg, styleCfg, size, spacing, showHotkeys)
    if not holder then
        return false, "ActionBar holder unavailable"
    end
''',
    'holder detail',
)
runtime = replace_once(
    runtime,
    '''    local allOk = true

    for id = 1, ACTION_BAR_COUNT do
        local holder = module.bars and module.bars[id]
        if not ApplyBarHolderConfig(module, holder, barsCfg[id], styleCfg, size, spacing, showHotkeys) then
            allOk = false
        end
    end

    if not allOk then
        return false, "ActionBars preview could not acquire every button"
    end
''',
    '''    local allOk = true
    local firstDetail

    for id = 1, ACTION_BAR_COUNT do
        local holder = module.bars and module.bars[id]
        local ok, detail = ApplyBarHolderConfig(module, holder, barsCfg[id], styleCfg, size, spacing, showHotkeys)
        if not ok then
            allOk = false
            firstDetail = firstDetail or ("ActionBar " .. tostring(id) .. ": " .. tostring(detail or "apply failed"))
        end
    end

    if not allOk then
        return false, firstDetail or "ActionBars preview could not acquire every button"
    end
''',
    'preview detail propagation',
)
runtime = replace_once(
    runtime,
    '''        return false
    end
    if not IsReady(module) or IsDetached(module) then
        return false
    end
''',
    '''        return false, "ActionBars DB unavailable"
    end
    if not IsReady(module) or IsDetached(module) then
        return false, "ActionBars apply owner unavailable"
    end
''',
    'apply precondition detail',
)
runtime = replace_once(
    runtime,
    '''        return false
    end

    local autoHide = (type(ab.autoHide) == "table") and ab.autoHide or nil
''',
    '''        return false, "ActionBars auto-hide hook registration failed: " .. tostring(hooksDetail)
    end

    local autoHide = (type(ab.autoHide) == "table") and ab.autoHide or nil
''',
    'holder hook detail propagation',
)
runtime = replace_once(
    runtime,
    '''    local allOk = true
    for id = 1, ACTION_BAR_COUNT do
        local holder = module.bars[id]
        local cfg = barsCfg[id]
        if not ApplyBarHolderConfig(module, holder, cfg, styleCfg, size, spacing, showHotkeys) then
            allOk = false
        end
    end

    if not allOk then
        return false
    end
''',
    '''    local allOk = true
    local firstDetail
    for id = 1, ACTION_BAR_COUNT do
        local holder = module.bars[id]
        local cfg = barsCfg[id]
        local ok, detail = ApplyBarHolderConfig(module, holder, cfg, styleCfg, size, spacing, showHotkeys)
        if not ok then
            allOk = false
            firstDetail = firstDetail or ("ActionBar " .. tostring(id) .. ": " .. tostring(detail or "apply failed"))
        end
    end

    if not allOk then
        return false, firstDetail or "ActionBars could not acquire every button"
    end
''',
    'apply detail propagation',
)
runtime = replace_once(
    runtime,
    '''    local ok = Runtime.ApplyNow(module)
    if not ok then
        module._pending = true
    end
    return ok
end
''',
    '''    local ok, detail = Runtime.ApplyNow(module)
    if not ok then
        module._pending = true
    end
    return ok, detail
end
''',
    'ApplyConfig detail propagation',
)
runtime_path.write_text(runtime, encoding='utf-8')


check_path = Path('check_lua.js')
check = check_path.read_text(encoding='utf-8')
check = replace_once(
    check,
    "    assertSourceIncludes('modules/ActionBarsRuntime.lua', 'local hooksOK, hooksDetail = module:EnsureAutoHideHooks()');\n",
    "    assertSourceIncludes('modules/ActionBarsRuntime.lua', 'local hooksOK, hooksDetail = module:EnsureAutoHideHooks()');\n"
    "    assertSourceIncludes('modules/ActionBarsRuntime.lua', 'local ok, detail = Runtime.ApplyNow(module)');\n"
    "    assertSourceIncludes('modules/ActionBarsRuntime.lua', 'ActionBar \" .. tostring(id)');\n"
    "    assertSourceIncludes('modules/ActionBarsState.lua', 'local readyField = name .. \"Ready\"');\n",
    'ActionBars detail static contracts',
)
check_path.write_text(check, encoding='utf-8')

print('Refined ActionBars hook detail propagation and layer reuse.')
