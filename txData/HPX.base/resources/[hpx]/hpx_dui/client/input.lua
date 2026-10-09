local activeInput = nil

function HPXDUI.SetInput(id, enabled)
    if enabled then
        activeInput = id
        SetNuiFocus(false, false)
        return
    end

    if activeInput == id then
        activeInput = nil
    end
end

function HPXDUI.SendMouse(id, event, x, y, button)
    local surface = HPXDUI.Get(id)
    if not surface or not surface.dui then return false end

    if event == 'move' then
        SendDuiMouseMove(surface.dui, x or 0, y or 0)
    elseif event == 'down' then
        SendDuiMouseDown(surface.dui, button or 'left')
    elseif event == 'up' then
        SendDuiMouseUp(surface.dui, button or 'left')
    elseif event == 'wheel' then
        SendDuiMouseWheel(surface.dui, x or 0, y or 0)
    else
        return false
    end

    return true
end
