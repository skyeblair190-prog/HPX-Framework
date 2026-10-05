local spawned = {}

local dbg = function(msg)
    if Config.Debug then
        print(('[hasib_peddialog] %s'):format(msg))
    end
end

local loadModel = function(model)
    local hash = type(model) == 'number' and model or joaat(model)
    local inCd = IsModelInCdimage(hash)
    local isPed = inCd and IsModelAPed(hash)
    local already = isPed and HasModelLoaded(hash)
    dbg(('model request=%s hash=%s inCd=%s isPed=%s alreadyLoaded=%s'):format(tostring(model), hash, tostring(inCd), tostring(isPed), tostring(already)))
    if not inCd or not isPed then return nil end
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    local waits = 0
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do
        Wait(10)
        waits = waits + 1
    end
    local loaded = HasModelLoaded(hash)
    dbg(('model result hash=%s loaded=%s waits=%s'):format(hash, tostring(loaded), waits))
    if not loaded then return nil end
    return hash
end

local openFor = function(entry, ped)
    local dialog = entry.dialog
    if not dialog or not dialog.options or #dialog.options == 0 then return end
    exports[GetCurrentResourceName()]:Open({
        ped = ped,
        pedId = entry.id,
        name = dialog.name,
        role = dialog.role,
        text = dialog.text,
        options = dialog.options,
        nodes = entry.nodes,
        shop = entry.shop,
        anim = entry.anim,
        scene = entry.scene,
    })
end

local targetSystem = function()
    local set = (Config.Target and Config.Target.system) or 'auto'
    if set ~= 'auto' then return set end
    if GetResourceState('ox_target') == 'started' then return 'ox' end
    if GetResourceState('qb-target') == 'started' then return 'qb' end
    return 'text'
end

local playAnim = function(ped, anim)
    if not anim or not anim.dict or anim.dict == '' then return end
    local clip = anim.name or anim.clip
    if not clip or clip == '' then return end
    RequestAnimDict(anim.dict)
    local deadline = GetGameTimer() + 4000
    while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < deadline do
        Wait(10)
    end
    if not HasAnimDictLoaded(anim.dict) then
        dbg(('anim fail dict=%s'):format(anim.dict))
        return
    end
    TaskPlayAnim(ped, anim.dict, clip, 2.0, 2.0, -1, anim.flag or 1, 0.0, false, false, false)
end

local deletePed = function(id, reason)
    local state = spawned[id]
    if not state then
        dbg(('delete skip id=%s reason=%s no state'):format(tostring(id), reason or 'unknown'))
        return
    end
    local ped = state.ped
    local exists = ped and ped ~= 0 and DoesEntityExist(ped)
    dbg(('delete id=%s reason=%s handle=%s exists=%s'):format(tostring(id), reason or 'unknown', tostring(ped), tostring(exists)))
    if exists then
        local ok, err = pcall(function()
            if state.targetSystem == 'ox' then
                exports.ox_target:removeLocalEntity(ped, state.targetName)
            elseif state.targetSystem == 'qb' then
                exports['qb-target']:RemoveTargetEntity(ped, state.targetLabel)
            end
        end)
        if not ok then
            dbg(('target remove fail id=%s err=%s'):format(tostring(id), tostring(err)))
        end
        DeleteEntity(ped)
        dbg(('deleted id=%s stillExists=%s'):format(tostring(id), tostring(DoesEntityExist(ped))))
    end
    spawned[id] = nil
end

local spawnPed = function(entry)
    if not entry or not entry.id or not entry.coords or not entry.model then
        dbg(('spawn reject id=%s model=%s coords=%s'):format(entry and tostring(entry.id) or 'nil', entry and tostring(entry.model) or 'nil', entry and tostring(entry.coords) or 'nil'))
        return
    end
    dbg(('spawn start id=%s model=%s coords=%s'):format(entry.id, entry.model, tostring(entry.coords)))
    deletePed(entry.id, 'respawn')
    local hash = loadModel(entry.model)
    if not hash then
        dbg(('spawn abort id=%s model load failed'):format(entry.id))
        return
    end
    local coords = entry.coords
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    Wait(0)
    local ped = CreatePed(4, hash, coords.x, coords.y, coords.z, coords.w, false, true)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        Wait(200)
        ped = CreatePed(4, hash, coords.x, coords.y, coords.z, coords.w, false, true)
    end
    SetModelAsNoLongerNeeded(hash)
    local existsNow = ped and ped ~= 0 and DoesEntityExist(ped)
    dbg(('CreatePed id=%s handle=%s exists=%s'):format(entry.id, tostring(ped), tostring(existsNow)))
    if not existsNow then
        dbg(('spawn abort id=%s CreatePed returned nothing'):format(entry.id))
        return
    end
    SetEntityAsMissionEntity(ped, true, true)
    SetEntityHeading(ped, coords.w)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    playAnim(ped, entry.anim)
    local target = entry.target or Config.Target or {}
    local fallback = Config.Target or {}
    local label = target.label or fallback.label or 'Talk'
    local icon = target.icon or fallback.icon or 'fas fa-comments'
    local distance = target.distance or fallback.distance or 2.5
    local system = targetSystem()
    local targetName = ('hasib_peddialog_%s'):format(entry.id)
    local ok, err = pcall(function()
        if system == 'ox' then
            exports.ox_target:addLocalEntity(ped, {
                {
                    name = targetName,
                    label = label,
                    icon = icon,
                    distance = distance,
                    onSelect = function()
                        openFor(entry, ped)
                    end,
                },
            })
        elseif system == 'qb' then
            exports['qb-target']:AddTargetEntity(ped, {
                options = {
                    {
                        icon = icon,
                        label = label,
                        action = function()
                            openFor(entry, ped)
                        end,
                    },
                },
                distance = distance,
            })
        elseif system ~= 'text' then
            error('no target')
        end
    end)
    dbg(('target add id=%s system=%s ok=%s err=%s'):format(entry.id, system, tostring(ok), ok and '' or tostring(err)))
    spawned[entry.id] = {
        ped = ped,
        entry = entry,
        coords = vector3(coords.x, coords.y, coords.z),
        distance = distance,
        targetSystem = system,
        targetName = targetName,
        targetLabel = label,
    }
    local handle = ped
    local id = entry.id
    CreateThread(function()
        Wait(1500)
        local tracked = spawned[id]
        dbg(('alive +1.5s id=%s handle=%s exists=%s tracked=%s'):format(id, tostring(handle), tostring(DoesEntityExist(handle)), tostring(tracked ~= nil and tracked.ped == handle)))
    end)
end

CreateThread(function()
    local list = Config.Peds or {}
    local player = GetEntityCoords(PlayerPedId())
    dbg(('resource start peds=%s player=%s'):format(#list, tostring(player)))
    for i = 1, #list do
        spawnPed(list[i])
    end
    dbg('spawn pass done')
end)

CreateThread(function()
    while true do
        local sleep = 1000
        local playerCoords = GetEntityCoords(PlayerPedId())
        for _, state in pairs(spawned) do
            if state.targetSystem == 'text' and #(playerCoords - state.coords) <= state.distance then
                sleep = 0
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(('Press ~INPUT_CONTEXT~ to %s'):format(tostring(state.targetLabel):lower()))
                EndTextCommandDisplayHelp(0, false, true, -1)
                if IsControlJustReleased(0, 38) then
                    openFor(state.entry, state.ped)
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    dbg('resource stop, deleting spawned peds')
    for id in pairs(spawned) do
        deletePed(id, 'resource stop')
    end
end)

