local addonName, ns = ...

local Log = ns.Log
local Options = ns.Options
local Errors = ns.Errors

local Actions = {}
ns.MinimapIconActions = Actions

local function PrintRecentErrors()
    if not (Errors and Errors.GetAll) then
        Log:Info("No error store available.")
        return
    end

    local list = Errors:GetAll()
    if #list == 0 then
        Log:Info("No captured errors.")
        return
    end

    local start = math.max(1, #list - 15 + 1)
    for i = start, #list do
        local entry = list[i]
        Log:Warn(("[%0.1fs] %s: %s"):format(entry.t or 0, entry.src or "", entry.msg or ""))
    end
end

function Actions:HandleClick(owner, button)
    if button == "LeftButton" then
        if Options and Options.Open then
            Options:Open()
        end
        return
    end

    if button == "RightButton" then
        if _G.IsShiftKeyDown and IsShiftKeyDown() then
            if owner and owner.ResetPosition then
                owner:ResetPosition()
            end
        else
            PrintRecentErrors()
        end
    end
end

function Actions:AttachDataObject(dataObj, owner, title)
    if not dataObj then return nil end

    dataObj.OnClick = function(_, button)
        self:HandleClick(owner, button)
    end

    dataObj.OnTooltipShow = function(tt)
        if not tt then return end
        tt:AddLine(title or addonName)
        tt:AddLine("Left-click: Settings", 1, 1, 1)
        tt:AddLine("Right-click: Recent errors", 1, 1, 1)
        tt:AddLine("Shift+Right-click: Reset icon", 1, 1, 1)
    end

    return dataObj
end

return Actions
