exports('Get', function(name)
  return lib.callback.await('hpx:business:get', false, name)
end)
