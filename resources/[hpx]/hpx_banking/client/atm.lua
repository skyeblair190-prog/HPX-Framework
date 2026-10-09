local config = HPXBankingConfig
local atm = config.atm

local surface = nil
local replaced = {}
local camera = nil
local session = nil

local function modelNameOf(entity)
  local hash = GetEntityModel(entity)
  for name in pairs(atm.textures) do
    if joaat(name) == hash then return name end
  end
end

local function nearestATM(radius)
  local coords = GetEntityCoords(PlayerPedId())
  local best, bestDistance, bestModel

  for name in pairs(atm.textures) do
    local object = GetClosestObjectOfType(coords.x, coords.y, coords.z, radius or 3.0, joaat(name), false, false, false)
    if object ~= 0 then
      local distance = #(coords - GetEntityCoords(object))
      if not bestDistance or distance < bestDistance then
        best, bestDistance, bestModel = object, distance, name
      end
    end
  end

  return best, bestModel
end

-- ===== DUI surface shared by every ATM prop =====

local function removeTextures()
  for _, texture in pairs(replaced) do
    RemoveReplaceTexture(texture.dict, texture.name)
  end
  replaced = {}
end

local function setupSurface()
  if surface then return end

  while GetResourceState('hpx_dui') ~= 'started' do Wait(250) end

  local created = exports.hpx_dui:Create({
    url = ('nui://%s/web/index.html?mode=dui'):format(GetCurrentResourceName()),
    width = config.dui.width,
    height = config.dui.height
  })
  if not created then return end

  surface = created
  Wait(500)

  for name, texture in pairs(atm.textures) do
    AddReplaceTexture(texture.dict, texture.name, surface.txd, surface.txn)
    replaced[name] = texture
  end

  HPXBank.SendDui({ action = 'view', view = { screen = 'idle' } })
end

function HPXBank.SendDui(payload)
  if surface and GetResourceState('hpx_dui') == 'started' then
    exports.hpx_dui:Send(surface.id, payload)
  end
end

-- ===== camera, ped and input while a player is using an ATM =====

local function startCamera(entity, model)
  if not atm.camera.enabled then return end

  local tuning = atm.camera.models[model] or atm.camera.default
  local ped = PlayerPedId()
  local pedCoords = GetEntityCoords(ped)
  local relative = GetOffsetFromEntityGivenWorldCoords(entity, pedCoords.x, pedCoords.y, pedCoords.z)
  local side = relative.y < 0.0 and -1.0 or 1.0

  local position = GetOffsetFromEntityInWorldCoords(entity, tuning.side or 0.0, side * tuning.distance, tuning.height)
  local target = GetOffsetFromEntityInWorldCoords(entity, 0.0, 0.0, tuning.lookHeight)

  camera = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', position.x, position.y, position.z, 0.0, 0.0, 0.0, tuning.fov, false, 2)
  PointCamAtCoord(camera, target.x, target.y, target.z)
  SetCamActive(camera, true)
  RenderScriptCams(true, true, 600, true, false)
end

local function stopCamera()
  if not camera then return end
  RenderScriptCams(false, true, 500, true, false)
  DestroyCam(camera, false)
  camera = nil
end

local function runInput()
  CreateThread(function()
    while HPXBank.IsActive() and HPXBank.GetMode() == 'dui' do
      DisableAllControlActions(0)

      if IsDisabledControlJustPressed(0, 172) or IsDisabledControlJustPressed(0, 32) then HPXBank.Move(-1) end
      if IsDisabledControlJustPressed(0, 173) or IsDisabledControlJustPressed(0, 33) then HPXBank.Move(1) end
      if IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 38) then
        CreateThread(function() HPXBank.Select() end)
      end
      if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then
        CreateThread(HPXBank.Back)
      end

      if IsEntityDead(PlayerPedId()) then
        HPXBank.Close()
        break
      end

      Wait(0)
    end
  end)
end

function HPXBank.BeginDui(entity, model)
  local ped = PlayerPedId()
  session = { entity = entity }

  if entity and DoesEntityExist(entity) then
    local from, to = GetEntityCoords(ped), GetEntityCoords(entity)
    SetEntityHeading(ped, GetHeadingFromVector_2d(to.x - from.x, to.y - from.y))
    startCamera(entity, model)
  end

  FreezeEntityPosition(ped, true)
  runInput()
end

function HPXBank.EndDui()
  if not session then return end
  session = nil

  stopCamera()
  FreezeEntityPosition(PlayerPedId(), false)
  HPXBank.SendDui({ action = 'view', view = { screen = 'idle' } })
end

-- ===== using an ATM =====

local function useATM(passed)
  if HPXBank.IsActive() or IsPedInAnyVehicle(PlayerPedId(), false) then return end

  local entity, model
  if type(passed) == 'number' and passed ~= 0 and DoesEntityExist(passed) then
    model = modelNameOf(passed)
    entity = model and passed or nil
  end
  if not entity then entity, model = nearestATM() end
  if not entity then return end

  HPXBank.Start(surface and 'dui' or 'nui', entity, model)
end

CreateThread(function()
  local modelData = {}
  for name in pairs(atm.textures) do modelData[#modelData + 1] = { model = joaat(name), offset = vec3(0.0, 0.0, 1.0) } end

  exports.interact:AddModelInteraction({
    name = 'hpx_atm',
    modelData = modelData,
    distance = 5.0,
    interactDst = atm.interactDistance,
    options = {
      {
        name = 'hpx_atm:use',
        label = 'Use ATM',
        action = function(entity) useATM(entity) end
      }
    }
  })

  setupSurface()
end)

AddEventHandler('onClientResourceStart', function(resource)
  if resource == 'hpx_dui' then CreateThread(setupSurface) end
end)

AddEventHandler('onClientResourceStop', function(resource)
  if resource == 'hpx_dui' then
    removeTextures()
    surface = nil
  elseif resource == GetCurrentResourceName() then
    HPXBank.Close()
    removeTextures()
    if surface and GetResourceState('hpx_dui') == 'started' then exports.hpx_dui:Destroy(surface.id) end
    surface = nil
  end
end)
