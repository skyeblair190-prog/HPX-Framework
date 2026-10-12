local cfg = HPXConfig.character
local scene = cfg.scene
local S = { open = false, peds = {}, cam = nil, prev = nil, data = nil }
local loggingOut = false

local function sceneVectors()
  local h = math.rad(scene.heading)
  local fwd = vector3(-math.sin(h), math.cos(h), 0.0)
  local right = vector3(-math.cos(h), -math.sin(h), 0.0)
  return fwd, right
end

local function center()
  return vector3(scene.center.x, scene.center.y, scene.center.z)
end

local function slotPosition(slot, total)
  local fwd, right = sceneVectors()
  local offset = (slot - (total + 1) / 2) * scene.spacing
  return center() + right * offset + fwd * (math.abs(offset) * 0.08)
end

local function loadModel(name)
  local hash = joaat(name)
  if not IsModelInCdimage(hash) then return nil end
  RequestModel(hash)
  local timeout = GetGameTimer() + 5000
  while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(0) end
  return HasModelLoaded(hash) and hash or nil
end

local function groundedPed(hash, pos, ghost)
  local found, gz = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 2.0, false)
  local z = (found and gz or pos.z - 1.0) + 1.0
  local ped = CreatePed(4, hash, pos.x, pos.y, z, scene.heading, false, false)
  SetEntityInvincible(ped, true)
  SetBlockingOfNonTemporaryEvents(ped, true)
  SetPedCanRagdoll(ped, false)
  FreezeEntityPosition(ped, true)
  SetEntityCollision(ped, false, false)
  if ghost then
    SetEntityAlpha(ped, 55, false)
  else
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
  end
  SetModelAsNoLongerNeeded(hash)
  return ped
end

local function clearPeds()
  for _, ped in pairs(S.peds) do
    if DoesEntityExist(ped) then DeleteEntity(ped) end
  end
  S.peds = {}
end

local function buildPeds(characters, total, skins)
  clearPeds()
  local bySlot = {}
  for _, character in ipairs(characters) do bySlot[tonumber(character.slot)] = character end

  for slot = 1, total do
    local character = bySlot[slot]
    local pos = slotPosition(slot, total)
    local entry = character and skins and skins[character.citizenid]
    local female = character and character.charinfo and character.charinfo.gender == 'female'
    local model = entry and entry.model or (female and 'mp_f_freemode_01' or 'mp_m_freemode_01')
    local hash = loadModel(model) or loadModel('mp_m_freemode_01')
    if hash then
      local ped = groundedPed(hash, pos, character == nil)
      S.peds[slot] = ped
      if entry and type(entry.skin) == 'table' then
        pcall(function() exports['illenium-appearance']:setPedAppearance(ped, entry.skin) end)
      elseif IsPedModel(ped, joaat('mp_m_freemode_01')) or IsPedModel(ped, joaat('mp_f_freemode_01')) then
        SetPedDefaultComponentVariation(ped)
      end
    end
  end
end

local function moveCam(pos, look, fov, dist, duration)
  local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, fov, false, 2)
  PointCamAtCoord(cam, look.x, look.y, look.z)
  SetCamUseShallowDofMode(cam, true)
  SetCamNearDof(cam, math.max(dist - 1.0, 0.1))
  SetCamFarDof(cam, dist + 3.5)
  SetCamDofStrength(cam, 1.0)

  if S.cam then
    SetCamActiveWithInterp(cam, S.cam, duration, 1, 1)
  else
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
  end
  if S.prev then DestroyCam(S.prev, false) end
  S.prev, S.cam = S.cam, cam
end

local function focusSlot(slot)
  local fwd, right = sceneVectors()
  local total = S.data and S.data.max or cfg.maxSlots
  if slot and S.peds[slot] and DoesEntityExist(S.peds[slot]) then
    local p = GetEntityCoords(S.peds[slot])
    moveCam(p + fwd * 2.5 + vector3(0.0, 0.0, 0.5), p - right * 0.75 + vector3(0.0, 0.0, 0.35), 36.0, 2.5, 900)
  else
    local c = center()
    moveCam(c + fwd * scene.wideDistance + vector3(0.0, 0.0, 1.5), c - right * (total * 0.28) + vector3(0.0, 0.0, 0.95), 46.0, scene.wideDistance, 1100)
  end
end

local function fetch()
  for _ = 1, 20 do
    local ok, list, max, skins = pcall(lib.callback.await, 'hpx:characters:list', false)
    if ok and list then return { list = list, max = max or cfg.maxSlots, skins = skins or {} } end
    Wait(1500)
  end
end

local function payload()
  return {
    characters = S.data.list, max = S.data.max,
    backgrounds = cfg.backgrounds, spawns = cfg.spawns,
  }
end

local function refresh(focus)
  local data = fetch()
  if not data then return false end
  S.data = data
  buildPeds(data.list, data.max, data.skins)
  focusSlot(focus)
  SendNUIMessage({ action = 'data', data = payload() })
  return true
end

local function fadeOut(ms)
  DoScreenFadeOut(ms)
  local timeout = GetGameTimer() + ms + 2000
  while not IsScreenFadedOut() and GetGameTimer() < timeout do Wait(0) end
end

local function closeScene()
  if not S.open then return end
  S.open = false
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
  clearPeds()
  RenderScriptCams(false, false, 0, true, true)
  DestroyAllCams(true)
  S.cam, S.prev = nil, nil
  NetworkClearClockTimeOverride()
  ClearOverrideWeather()
  ClearWeatherTypePersist()
  DisplayRadar(true)
  local ped = PlayerPedId()
  SetEntityVisible(ped, true, false)
  SetEntityCollision(ped, true, true)
  TriggerEvent('hpx:client:multicharClosed')
end

local function beginSelect()
  if S.open then return end
  S.open = true
  TriggerEvent('hpx:client:multicharOpened')

  fadeOut(300)
  local ped = PlayerPedId()
  local c = scene.center
  RequestCollisionAtCoord(c.x, c.y, c.z)
  SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
  FreezeEntityPosition(ped, true)
  SetEntityVisible(ped, false, false)
  SetEntityCollision(ped, false, false)
  DisplayRadar(false)

  local timeout = GetGameTimer() + 4000
  while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do Wait(0) end

  for _ = 1, 10 do
    if lib.callback.await('hpx:characters:enter', false) then break end
    Wait(500)
  end

  NetworkOverrideClockTime(scene.time[1], scene.time[2], 0)
  SetWeatherTypeNowPersist(scene.weather)

  CreateThread(function()
    while S.open do
      SetUseHiDof()
      HideHudAndRadarThisFrame()
      ThefeedHideThisFrame()
      Wait(0)
    end
  end)

  if not refresh(nil) then
    closeScene()
    DoScreenFadeIn(500)
    return
  end

  ShutdownLoadingScreen()
  ShutdownLoadingScreenNui()
  SetNuiFocus(true, true)
  SendNUIMessage({ action = 'open', data = payload() })
  DoScreenFadeIn(700)
end

RegisterNUICallback('mc:focus', function(body, cb)
  focusSlot(tonumber(body and body.slot))
  cb('ok')
end)

RegisterNUICallback('mc:create', function(body, cb)
  if not S.open or type(body) ~= 'table' then return cb({ ok = false, err = 'invalid' }) end
  fadeOut(300)
  local player, err = lib.callback.await('hpx:characters:create', false, { slot = body.slot, charinfo = body.charinfo })
  if not player then
    DoScreenFadeIn(300)
    return cb({ ok = false, err = err })
  end
  closeScene()
  cb({ ok = true })
end)

RegisterNUICallback('mc:play', function(body, cb)
  if not S.open or type(body) ~= 'table' then return cb({ ok = false, err = 'invalid' }) end
  fadeOut(300)
  local player, err = lib.callback.await('hpx:characters:select', false, { id = tonumber(body.id), spawn = body.spawn })
  if not player then
    DoScreenFadeIn(300)
    return cb({ ok = false, err = err })
  end
  closeScene()
  cb({ ok = true })
end)

RegisterNUICallback('mc:delete', function(body, cb)
  if not S.open or type(body) ~= 'table' then return cb({ ok = false, err = 'invalid' }) end
  local ok, err = lib.callback.await('hpx:characters:delete', false, { id = tonumber(body.id), confirm = body.confirm })
  if ok then refresh(nil) end
  cb({ ok = ok == true, err = err })
end)

RegisterNetEvent('hpx:client:characterLoaded', closeScene)

RegisterNetEvent('hpx:client:characterUnloaded', function()
  if not loggingOut then return end
  loggingOut = false
  CreateThread(beginSelect)
end)

RegisterCommand('logout', function()
  if S.open or not exports.hpx_core:IsLoaded() then return end
  loggingOut = true
  lib.callback.await('hpx:characters:logout', false)
end, false)

AddEventHandler('onResourceStop', function(resource)
  if resource ~= GetCurrentResourceName() or not S.open then return end
  clearPeds()
  SetNuiFocus(false, false)
  RenderScriptCams(false, false, 0, true, true)
  DestroyAllCams(true)
  SetEntityVisible(PlayerPedId(), true, false)
  SetEntityCollision(PlayerPedId(), true, true)
  FreezeEntityPosition(PlayerPedId(), false)
  DisplayRadar(true)
end)

CreateThread(function()
  if cfg.autoLoad or not cfg.selectMenu then return end
  while not NetworkIsSessionStarted() do Wait(100) end
  Wait(500)
  if exports.hpx_core:IsLoaded() then return end
  beginSelect()
end)
