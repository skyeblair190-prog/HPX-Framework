RegisterNetEvent('hpx:dispatch:new', function(call)
  TriggerEvent('hpx:dispatch:received', call)
end)

exports('List', function()
  return lib.callback.await('hpx:dispatch:list', false)
end)
