local function playerData()
  local ok, data = pcall(function() return exports.hpx_core:GetPlayerData() end)
  return ok and type(data) == 'table' and data or {}
end

local function currentJob()
  local data = playerData()
  return type(data.job) == 'table' and data.job.name or nil
end

local function isEmergencyJob(name)
  for _, job in ipairs(Config.EmergencyJobs) do
    if job.name == name then return true end
  end
  return false
end

local function dispatchBlip(data)
  PlaySound(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', 0, 0, 1)

  local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
  SetBlipSprite(blip, data.blip.blipid)
  SetBlipDisplay(blip, 4)
  SetBlipScale(blip, Config.BlipScale)
  SetBlipColour(blip, data.blip.blipcolor)
  SetBlipAsShortRange(blip, true)
  BeginTextCommandSetBlipName('STRING')
  AddTextComponentString(('%s [#%s]'):format(data.title, data.dispatchnumber))
  EndTextCommandSetBlipName(blip)
  PulseBlip(blip)

  SetTimeout(Config.RemoveBlipAfter, function() RemoveBlip(blip) end)
end

local function openMenu()
  local job = currentJob()
  if not isEmergencyJob(job) then return end

  local dispatchs = lib.callback.await('hpx_dispatch:getDispatchs', false)
  local unit = lib.callback.await('hpx_dispatch:getMyUnit', false)

  SendNUIMessage({ action = 'openMenu', data = dispatchs, unit = unit, myjob = job })
  SetNuiFocus(true, true)
end

RegisterCommand(Config.MenuCommand, openMenu, false)
RegisterKeyMapping(Config.MenuCommand, 'Open Dispatch Menu', 'keyboard', Config.MenuKey)

RegisterNUICallback('getPlayers', function(_, cb)
  cb(lib.callback.await('hpx_dispatch:getJobPlayers', false))
end)

RegisterNUICallback('getUnits', function(_, cb)
  cb(lib.callback.await('hpx_dispatch:getUnits', false))
end)

RegisterNUICallback('canAddtoUnit', function(data, cb)
  cb(lib.callback.await('hpx_dispatch:canAddtoUnit', false, data.id))
end)

RegisterNUICallback('createUnit', function(data, cb)
  cb(lib.callback.await('hpx_dispatch:createUnit', false, data))
end)

RegisterNUICallback('leaveUnit', function(_, cb)
  cb(lib.callback.await('hpx_dispatch:leaveUnit', false))
end)

RegisterNUICallback('deleteUnit', function(_, cb)
  cb(lib.callback.await('hpx_dispatch:deleteUnit', false))
end)

RegisterNUICallback('closeMenu', function(_, cb)
  SetNuiFocus(false, false)
  cb('ok')
end)

RegisterNUICallback('setActive', function(data, cb)
  TriggerServerEvent('hpx_dispatch:server:setActive', data.id)
  cb(true)
  Wait(200)
  openMenu()
end)

RegisterNUICallback('setLocation', function(data, cb)
  local coords = lib.callback.await('hpx_dispatch:getLocation', false, data.id)
  if coords then SetNewWaypoint(coords.x, coords.y) end
  cb(coords ~= nil)
end)

RegisterNetEvent('hpx_dispatch:client:dispatch', function(data)
  SendNUIMessage({ action = 'addispatch', data = data })
  dispatchBlip(data)
end)

RegisterNetEvent('hpx_dispatch:client:notify', function(message, kind)
  exports.hpx_notify:Notify(message, kind)
end)

local function sendDispatch(data)
  TriggerServerEvent('hpx_dispatch:server:add', data)
end

exports('sendDispatch', sendDispatch)

local function downAlert(title, code, blipId)
  local info = playerData().charinfo or {}
  local pos = GetEntityCoords(PlayerPedId())
  sendDispatch({
    title = title,
    code = code,
    values = {
      { text = ('%s %s'):format(info.firstname or '', info.lastname or ''), icon = 'fa-solid fa-user' },
      { text = 'Priority 1', icon = 'fa-solid fa-hashtag' }
    },
    jobs = { 'police', 'ambulance' },
    coords = { x = pos.x, y = pos.y, z = pos.z },
    blip = { blipid = blipId, blipcolor = 1 }
  })
end

RegisterNetEvent('hpx_dispatch:client:officerDown', function()
  downAlert('Officer Down', '10-13A', 126)
end)

RegisterNetEvent('hpx_dispatch:client:emsDown', function()
  downAlert('EMS Down', '10-13B', 153)
end)
