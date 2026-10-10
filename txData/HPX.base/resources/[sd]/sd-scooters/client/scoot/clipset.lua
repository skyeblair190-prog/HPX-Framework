---@type string The standing-rider clipset registered in data/clip_sets.xml.
local CLIPSET = 'clipset@veh@bike@sd_scoot@front@base'
---@type string The clip dictionary that clipset resolves into (stream/veh@bike@sd_scoot@front@base.ycd).
local DICT = 'veh@bike@sd_scoot@front@base'
local TRANSITIONS = { 'veh@bike@sd_scoot@front@ds', 'veh@bike@sd_scoot@front@ps' }
---Request the side-entry transition dictionaries and their clip sets, so mounting from either side
---plays the standing-rider animation instead of the vanilla fallback.
local function requestTransitions()
    for _, dictionary in ipairs(TRANSITIONS) do
        if not HasAnimDictLoaded(dictionary) then RequestAnimDict(dictionary) end
        local clipset = 'clipset@' .. dictionary
        if not HasClipSetLoaded(clipset) then RequestClipSet(clipset) end
    end
end

---@type boolean True while a flush is waiting for the game to drop the dictionary; the keeper stays out of the way.
local flushing = false

---Keeps the standing-rider clipset resident. The bike move network resolves clips the moment a
---ped enters the seat; if the dictionary is not loaded yet it latches onto the vanilla scooter
---clips and never re-evaluates. Re-requests every five seconds unless a flush is in progress.
CreateThread(function()
    while true do
        if not flushing then
            requestTransitions()
            if not HasClipSetLoaded(CLIPSET) then RequestClipSet(CLIPSET) end
            if not HasAnimDictLoaded(DICT) then RequestAnimDict(DICT) end
        end
        Wait(5000)
    end
end)

---/scootflush: let go of the dictionary and clip set (kept for completeness: a changed .ycd is only
---picked up on reconnect, so this mostly matters for a restart of this resource). Releasing is not enough: the game keeps the old data resident until the
---streamer runs, and re-requesting before that just re-references the old copy. So the keeper is
---paused, the streamer is nudged with unrelated requests, and the dictionary is only re-requested
---once the game reports it unloaded. A ped sitting on a scooter pins the old clips, so get off first.
RegisterNetEvent('sd_scoot:client:flush', function()
    flushing = true
    for _, dictionary in ipairs(TRANSITIONS) do
        RemoveClipSet('clipset@' .. dictionary)
        RemoveAnimDict(dictionary)
    end
    RemoveClipSet(CLIPSET)
    RemoveAnimDict(DICT)
    local nudgeModel, nudgeDict = joaat('adder'), 'anim@heists@heist_corona@single_team'
    RequestModel(nudgeModel)
    RequestAnimDict(nudgeDict)
    local deadline = GetGameTimer() + 8000
    while HasAnimDictLoaded(DICT) and GetGameTimer() < deadline do Wait(100) end
    local dropped = not HasAnimDictLoaded(DICT)
    SetModelAsNoLongerNeeded(nudgeModel)
    RemoveAnimDict(nudgeDict)
    flushing = false
    requestTransitions()
    RequestAnimDict(DICT)
    RequestClipSet(CLIPSET)
    if dropped then
        lib.notify({ title = locale('notify.title'), description = locale('notify.flushed', DICT), type = 'success' })
    else
        lib.notify({ title = locale('notify.title'), description = locale('notify.flush_stuck', DICT .. ' (get off the scooter and flush again)'), type = 'error' })
    end
end)
