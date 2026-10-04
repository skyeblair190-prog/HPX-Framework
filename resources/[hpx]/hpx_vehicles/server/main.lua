local function player(source) return exports.hpx_core:GetPlayer(source) end

lib.callback.register('hpx:vehicles:listOwned', function(source)
  local p = player(source)
  if not p then return {} end
  return MySQL.query.await('SELECT id, plate, model, props, stored, garage, state FROM hpx_vehicles WHERE character_id = ? ORDER BY id DESC', { p.charid })
end)

lib.callback.register('hpx:vehicles:save', function(source, data)
  local p = player(source)
  if not p or type(data) ~= 'table' then return false end
  local plate = tostring(data.plate or ''):upper()
  if #plate < 1 or #plate > 8 then return false end
  local changed = MySQL.update.await(
    'UPDATE hpx_vehicles SET props = ?, stored = ?, garage = ?, state = ? WHERE id = ? AND character_id = ?',
    { json.encode(data.props or {}), data.stored and 1 or 0, data.garage, data.state or 'normal', data.id, p.charid }
  )
  return changed == 1
end)

exports('ListOwned', function(source)
  return lib.callback.await('hpx:vehicles:listOwned', source)
end)
