function HPXServer.SetState(source, key, value)
  local player = HPXServer.GetPlayer(source)
  if not player then return false end
  player.state[key] = value
  Player(source).state:set(('hpx:%s'):format(key), value, true)
  return true
end

function HPXServer.GetState(source, key)
  local player = HPXServer.GetPlayer(source)
  return player and player.state[key]
end

function HPXServer.ClearState(source, key)
  local player = HPXServer.GetPlayer(source)
  if not player then return false end
  player.state[key] = nil
  Player(source).state:set(('hpx:%s'):format(key), nil, true)
  return true
end
