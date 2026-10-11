local function applyProps(veh, props)
    lib.setVehicleProperties(veh, props)
    Entity(veh).state:set('hp4:props', nil, true)
end

AddStateBagChangeHandler('hp4:props', nil, function(bagName, _, value)
    if not value then return end
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 then return end
    local deadline = GetGameTimer() + 5000
    while GetGameTimer() < deadline do
        if not DoesEntityExist(entity) then return end
        if NetworkGetEntityOwner(entity) == cache.playerId then
            if Entity(entity).state['hp4:props'] then applyProps(entity, value) end
            return
        end
        Wait(250)
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        local pc = GetEntityCoords(cache.ped)
        local pool = GetGamePool('CVehicle')
        for i = 1, #pool do
            local veh = pool[i]
            local st = Entity(veh).state
            if st.hp4id and NetworkGetEntityIsNetworked(veh) then
                local vc = GetEntityCoords(veh)
                if #(vc - pc) < 150.0 and NetworkGetEntityOwner(veh) == cache.playerId then
                    local props = st['hp4:props']
                    if props then applyProps(veh, props) end
                    if st.hp4frozen then
                        RequestCollisionAtCoord(vc.x, vc.y, vc.z)
                        if HasCollisionLoadedAroundEntity(veh) then
                            FreezeEntityPosition(veh, false)
                            SetVehicleOnGroundProperly(veh)
                            st:set('hp4frozen', false, true)
                        end
                    end
                end
            end
        end
    end
end)

local function pushProps(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if not Entity(veh).state.hp4id then return end
    TriggerServerEvent('hp4_garages:props', NetworkGetNetworkIdFromEntity(veh), lib.getVehicleProperties(veh))
end

lib.onCache('vehicle', function(_, old) pushProps(old) end)

CreateThread(function()
    while true do
        Wait(Config.propsInterval)
        if cache.vehicle and cache.seat == -1 then pushProps(cache.vehicle) end
    end
end)
