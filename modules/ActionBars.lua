-- FeelsGoodUI: ActionBars owner facade
local _, ns = ...

local ActionBars = {}
ns.ActionBars = ActionBars

local EditMode = ns.ActionBarsEditMode
local Runtime = ns.ActionBarsRuntime
local State = ns.ActionBarsState

local ACTION_BAR_COUNT = 5

local function CreateHolder(id)
    local ok, holder = pcall(
        CreateFrame,
        "Frame",
        "FGUI_ActionBarHolder" .. id,
        UIParent,
        "SecureHandlerStateTemplate"
    )
    if not ok or not holder then
        return nil, ok and "ActionBar holder creation returned nil" or tostring(holder)
    end

    holder:SetFrameStrata("LOW")
    holder:SetFrameLevel(10)
    holder.id = id
    holder.buttons = {}
    holder._layoutDirty = false
    return holder
end

local function EnsureHolderReady(holder, id)
    if not holder then return false, "ActionBar holder unavailable" end

    if holder._visibilityDriverRegistered ~= true then
        if type(_G.RegisterStateDriver) ~= "function" then
            return false, "RegisterStateDriver unavailable"
        end
        local ok, detail = pcall(
            _G.RegisterStateDriver,
            holder,
            "visibility",
            "[petbattle][overridebar][vehicleui][possessbar,@vehicle,exists] hide; show"
        )
        if not ok then
            return false, "ActionBar visibility driver failed: " .. tostring(detail)
        end
        holder._visibilityDriverRegistered = true
    end

    if not (EditMode and type(EditMode.RegisterHolder) == "function") then
        return false, "ActionBars Edit Mode mover owner unavailable"
    end
    return EditMode.RegisterHolder(holder, id)
end

function ActionBars:EnsureCreated()
    if self._created then return true end

    self.bars = self.bars or {}
    for id = 1, ACTION_BAR_COUNT do
        local holder = self.bars[id]
        if not holder then
            local detail
            holder, detail = CreateHolder(id)
            if not holder then
                return false, "ActionBar " .. tostring(id) .. ": " .. tostring(detail)
            end
            self.bars[id] = holder
        end

        local ready, detail = EnsureHolderReady(holder, id)
        if ready == false then
            return false, "ActionBar " .. tostring(id) .. ": " .. tostring(detail)
        end
    end

    self.bar1 = self.bars[1]
    self.bar2 = self.bars[2]
    self.bar3 = self.bars[3]
    self.bar4 = self.bars[4]
    self.bar5 = self.bars[5]
    self.petBar = nil
    self._created = true
    return true
end

function ActionBars:_ForEachHolder(fn)
    if type(fn) ~= "function" or not self.bars then
        return
    end

    for id = 1, ACTION_BAR_COUNT do
        fn(self.bars[id], id)
    end
end

function ActionBars:_SetHolderAutoHidden(holder, hidden)
    if State and State.SetHolderAutoHidden then
        return State.SetHolderAutoHidden(holder, hidden)
    end
    return false
end

function ActionBars:_IsAnyHolderHovered()
    if State and State.IsAnyHolderHovered then
        return State.IsAnyHolderHovered(self)
    end
    return false
end

function ActionBars:_QueueAutoHideUpdate()
    if State and State.QueueAutoHideUpdate then
        State.QueueAutoHideUpdate(self)
    end
end

function ActionBars:UpdateAutoHideState()
    if State and State.UpdateAutoHideState then
        State.UpdateAutoHideState(self)
    end
end

function ActionBars:EnsureAutoHideHooks()
    if State and State.EnsureAutoHideHooks then
        return State.EnsureAutoHideHooks(self)
    end
    return false, "ActionBars state owner unavailable"
end

function ActionBars:EnsureStateHooks(hasActionChangedCallback)
    if State and State.EnsureStateHooks then
        return State.EnsureStateHooks(self, hasActionChangedCallback == true)
    end
    return false, "ActionBars state hook owner unavailable"
end

function ActionBars:RefreshEmptySlots()
    if State and State.RefreshEmptySlots then
        State.RefreshEmptySlots(self)
    end
end

function ActionBars:ApplyConfig()
    if Runtime and Runtime.ApplyConfig then
        return Runtime.ApplyConfig(self)
    end
    return false
end

function ActionBars:QueueInitialApply(delay)
    if Runtime and Runtime.QueueInitialApply then
        return Runtime.QueueInitialApply(self, delay)
    end
end

function ActionBars:Init()
    if Runtime and Runtime.Init then
        return Runtime.Init(self)
    end
    return false
end

function ActionBars:Attach()
    if Runtime and Runtime.Attach then
        return Runtime.Attach(self)
    end
    return false
end

function ActionBars:Detach()
    if Runtime and Runtime.Detach then
        return Runtime.Detach(self)
    end
    return false
end

return ActionBars
