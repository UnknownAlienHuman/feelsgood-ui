-- FeelsGoodUI: ActionBars owner facade
local _, ns = ...

local ActionBars = {}
ns.ActionBars = ActionBars

local EditMode = ns.ActionBarsEditMode
local Runtime = ns.ActionBarsRuntime
local State = ns.ActionBarsState

local ACTION_BAR_COUNT = 5

local function CreateHolder(id)
    local holder = CreateFrame("Frame", "FGUI_ActionBarHolder" .. id, UIParent, "SecureHandlerStateTemplate")
    holder:SetFrameStrata("LOW")
    holder:SetFrameLevel(10)
    holder.id = id
    holder.buttons = {}
    holder._layoutDirty = false

    if EditMode and EditMode.RegisterHolder then
        EditMode.RegisterHolder(holder, id)
    end

    RegisterStateDriver(holder, "visibility", "[petbattle][overridebar][vehicleui][possessbar,@vehicle,exists] hide; show")
    return holder
end

function ActionBars:EnsureCreated()
    if self._created then
        return
    end

    self.bars = {}
    for id = 1, ACTION_BAR_COUNT do
        self.bars[id] = CreateHolder(id)
    end

    self.bar1 = self.bars[1]
    self.bar2 = self.bars[2]
    self.bar3 = self.bars[3]
    self.bar4 = self.bars[4]
    self.bar5 = self.bars[5]
    self.petBar = nil
    self._created = true
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
        State.SetHolderAutoHidden(holder, hidden)
    end
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
        State.EnsureAutoHideHooks(self)
    end
end

function ActionBars:EnsureStateHooks()
    if State and State.EnsureStateHooks then
        State.EnsureStateHooks(self)
    end
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
