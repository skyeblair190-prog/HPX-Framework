local selecting, loggingOut = false, false
local showMenu

local function notify(description, kind)
  lib.notify({ description = description, type = kind or 'error' })
end

local function beginSelect()
  if selecting then return end
  selecting = true

  DoScreenFadeOut(300)
  local timeout = GetGameTimer() + 3000
  while not IsScreenFadedOut() and GetGameTimer() < timeout do Wait(0) end

  local ped = PlayerPedId()
  local spawn = HPXConfig.spawn
  SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, spawn.z, false, false, false)
  FreezeEntityPosition(ped, true)
  SetEntityVisible(ped, false, false)
  DisplayRadar(false)
  SetTimecycleModifier('hud_def_blur')
  SetTimecycleModifierStrength(1.0)

  ShutdownLoadingScreen()
  ShutdownLoadingScreenNui()
  DoScreenFadeIn(500)
end

local function endSelect()
  if not selecting then return end
  selecting = false
  ClearTimecycleModifier()
  DisplayRadar(true)
  SetEntityVisible(PlayerPedId(), true, false)
end

local function createCharacter(slot)
  local year, month, day = GetLocalTime()
  local newest = ('%02d/%02d/%04d'):format(day, month, year - 18)

  local dialog = lib.inputDialog('Create character', {
    { type = 'input', label = 'First name', icon = 'user-pen', required = true, min = 2, max = 24 },
    { type = 'input', label = 'Last name', icon = 'user-pen', required = true, min = 2, max = 24 },
    { type = 'input', label = 'Nationality', icon = 'flag', required = true, default = 'American', min = 2, max = 32 },
    { type = 'select', label = 'Gender', icon = 'circle-user', required = true, options = {
      { value = 'male', label = 'Male' }, { value = 'female', label = 'Female' }
    } },
    { type = 'date', label = 'Birth date', icon = 'calendar-days', required = true, format = 'DD/MM/YYYY',
      returnString = true, min = '01/01/1930', max = newest, default = newest }
  })
  if not dialog then return showMenu() end

  local player, err = lib.callback.await('hpx:characters:create', false, {
    slot = slot,
    charinfo = { firstname = dialog[1], lastname = dialog[2], nationality = dialog[3], gender = dialog[4], birthdate = dialog[5] }
  })
  if not player then
    notify(err == 'invalid_charinfo' and 'Those character details were not accepted.' or 'Character could not be created.')
    return showMenu()
  end
end

local function openCharacter(character)
  local info = character.charinfo or {}
  local job = type(character.job) == 'table' and (character.job.label or character.job.name) or 'Unemployed'

  lib.registerContext({
    id = 'hpx_character',
    title = ('%s %s'):format(info.firstname or '?', info.lastname or '?'),
    canClose = false,
    options = {
      {
        title = 'Play', icon = 'play', description = ('%s | Phone %s'):format(job, character.phone or 'none'),
        onSelect = function()
          local player, err = lib.callback.await('hpx:characters:select', false, character.id)
          if not player then
            notify('Character could not be loaded.')
            showMenu()
          end
        end
      },
      {
        title = 'Delete', icon = 'trash', iconColor = '#ff4e55',
        onSelect = function()
          local confirmed = lib.alertDialog({
            header = 'Delete character',
            content = ('Permanently delete %s %s? This cannot be undone.'):format(info.firstname or '?', info.lastname or '?'),
            centered = true, cancel = true
          })
          if confirmed == 'confirm' then
            if not lib.callback.await('hpx:characters:delete', false, character.id) then notify('Character could not be deleted.') end
          end
          showMenu()
        end
      },
      { title = 'Back', icon = 'arrow-left', onSelect = function() showMenu() end }
    }
  })
  lib.showContext('hpx_character')
end

showMenu = function()
  local characters, maxSlots = lib.callback.await('hpx:characters:list', false)
  if not characters then
    notify('Characters could not be loaded. Retrying...')
    Wait(2000)
    return showMenu()
  end

  local bySlot = {}
  for _, character in ipairs(characters) do bySlot[tonumber(character.slot)] = character end

  local options = {}
  for slot = 1, maxSlots or HPXConfig.character.maxSlots do
    local character = bySlot[slot]
    if character then
      local info = character.charinfo or {}
      options[#options + 1] = {
        title = ('%s %s'):format(info.firstname or '?', info.lastname or '?'),
        description = ('%s | Born %s'):format(character.citizenid or '', info.birthdate or '?'),
        icon = 'user',
        onSelect = function() openCharacter(character) end
      }
    else
      options[#options + 1] = {
        title = 'Create character', description = ('Slot %d'):format(slot), icon = 'user-plus',
        onSelect = function() createCharacter(slot) end
      }
    end
  end

  lib.registerContext({ id = 'hpx_characters', title = 'Select character', canClose = false, options = options })
  lib.showContext('hpx_characters')
end

RegisterNetEvent('hpx:client:characterLoaded', endSelect)

RegisterNetEvent('hpx:client:characterUnloaded', function()
  if not loggingOut then return end
  loggingOut = false
  CreateThread(function()
    beginSelect()
    showMenu()
  end)
end)

RegisterCommand('logout', function()
  if selecting or not exports.hpx_core:IsLoaded() then return end
  loggingOut = true
  lib.callback.await('hpx:characters:logout', false)
end, false)

CreateThread(function()
  if HPXConfig.character.autoLoad or not HPXConfig.character.selectMenu then return end
  while not NetworkIsSessionStarted() do Wait(100) end
  Wait(500)
  if exports.hpx_core:IsLoaded() then return end

  for _ = 1, 20 do
    local ok, list = pcall(lib.callback.await, 'hpx:characters:list', false)
    if ok and list then break end
    Wait(1500)
  end

  beginSelect()
  showMenu()
end)
