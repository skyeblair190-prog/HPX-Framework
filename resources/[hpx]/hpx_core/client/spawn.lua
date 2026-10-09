local spawned = false

local function placeAt(position)
  local c = (type(position) == 'table' and position.x and position.y and position.z) and position or HPXConfig.spawn

  DoScreenFadeOut(250)
  local timeout = GetGameTimer() + 3000
  while not IsScreenFadedOut() and GetGameTimer() < timeout do Wait(0) end

  local ped = PlayerPedId()
  FreezeEntityPosition(ped, true)
  RequestCollisionAtCoord(c.x, c.y, c.z)
  SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
  SetEntityHeading(ped, c.w or 0.0)

  timeout = GetGameTimer() + 5000
  while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do Wait(0) end

  FreezeEntityPosition(ped, false)
  ShutdownLoadingScreen()
  ShutdownLoadingScreenNui()
  DoScreenFadeIn(500)
end

RegisterNetEvent('hpx:client:characterLoaded', function(data)
  spawned = true
  CreateThread(function() placeAt(type(data) == 'table' and data.position or nil) end)
end)

RegisterNetEvent('hpx:client:characterUnloaded', function()
  spawned = false
end)

CreateThread(function()
  if not HPXConfig.character.autoLoad then return end
  while not NetworkIsSessionStarted() do Wait(100) end

  for _ = 1, 15 do
    if spawned then return end
    Wait(2000)
    local ok, result = pcall(lib.callback.await, 'hpx:characters:autoload', false)
    if ok and (result or spawned) then return end
  end
end)
