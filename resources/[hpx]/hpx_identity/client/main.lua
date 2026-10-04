RegisterNetEvent('hpx:identity:sync', function(identity)
  LocalPlayer.state:set('hpx:identity', identity, false)
end)

exports('Get', function()
  return LocalPlayer.state['hpx:identity']
end)
