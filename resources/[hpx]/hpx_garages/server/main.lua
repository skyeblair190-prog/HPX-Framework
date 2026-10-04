lib.callback.register('hpx:garages:list', function(source, garage)
  local p = exports.hpx_core:GetPlayer(source)
  if not p then return {} end
  return MySQL.query.await(
    'SELECT id, plate, model, props, stored, garage FROM hpx_vehicles WHERE character_id = ? AND garage = ? ORDER BY id DESC',
    { p.charid, tostring(garage or 'pillbox') }
  )
end)
