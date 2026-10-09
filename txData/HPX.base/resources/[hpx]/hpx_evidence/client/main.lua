exports('Create', function(data)
  return lib.callback.await('hpx:evidence:create', false, data)
end)

exports('List', function()
  return lib.callback.await('hpx:evidence:list', false)
end)
