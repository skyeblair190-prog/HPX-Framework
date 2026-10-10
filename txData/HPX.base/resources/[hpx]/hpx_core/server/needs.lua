local config = HPXConfig.needs
local statusCooldown = {}

local function clamp(value)
  return math.max(0, math.min(100, value))
end

local function publish(source, metadata)
  local state = Player(source).state
  state:set('hunger', metadata.hunger, true)
  state:set('thirst', metadata.thirst, true)
  state:set('stress', metadata.stress, true)
end

AddEventHandler('hpx:server:characterLoaded', function(source, player)
  publish(source, player.metadata)
end)

RegisterNetEvent('hpx:server:status', function(values)
  local source = source
  local player = HPXServer.GetPlayer(source)
  if not player or type(values) ~= 'table' then return end

  local now = GetGameTimer()
  if statusCooldown[source] and now - statusCooldown[source] < 500 then return end
  statusCooldown[source] = now

  local metadata = player.metadata
  for key, value in pairs(values) do
    if (key == 'hunger' or key == 'thirst' or key == 'stress') and type(value) == 'number' and value == value then
      if value > 100 or value < -100 then value = value * 0.0001 end
      value = math.max(-100, math.min(100, value))
      local fallback = key == 'stress' and 0 or 100
      metadata[key] = clamp((tonumber(metadata[key]) or fallback) + value)
    end
  end

  publish(source, metadata)
  HPXServer.SyncClient(source)
end)

AddEventHandler('playerDropped', function()
  statusCooldown[source] = nil
end)

CreateThread(function()
  if not config.enabled then return end

  while true do
    Wait(config.interval)
    HPXServer.ForEachPlayer(function(source, player)
      local metadata = player.metadata
      if metadata.isdead ~= true then
        metadata.hunger = clamp((tonumber(metadata.hunger) or 100) - config.hungerLoss)
        metadata.thirst = clamp((tonumber(metadata.thirst) or 100) - config.thirstLoss)
        publish(source, metadata)
        HPXServer.SyncClient(source)
      end
    end)
  end
end)
