local function player(source) return exports.hpx_core:GetPlayer(source) end

lib.callback.register('hpx:business:get', function(source, name)
  local p = player(source)
  if not p or type(name) ~= 'string' then return nil end
  return MySQL.single.await(
    'SELECT id, name, label, owner_character_id, funds, data FROM hpx_businesses WHERE name = ? LIMIT 1',
    { name }
  )
end)

lib.callback.register('hpx:business:deposit', function(source, name, amount)
  local p = player(source)
  amount = tonumber(amount)
  if not p or not amount or amount <= 0 then return false end
  local business = MySQL.single.await('SELECT id FROM hpx_businesses WHERE name = ? LIMIT 1', { name })
  if not business or not p:RemoveMoney('bank', amount, 'business-deposit') then return false end
  return MySQL.update.await('UPDATE hpx_businesses SET funds = funds + ? WHERE id = ?', { amount, business.id }) == 1
end)
