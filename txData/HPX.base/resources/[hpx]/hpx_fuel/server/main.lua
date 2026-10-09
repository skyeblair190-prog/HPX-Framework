lib.callback.register('hpx:fuel:getPrice', function()
  return HPXFuelConfig.defaultPrice
end)

lib.callback.register('hpx:fuel:purchase', function(source, liters, price)
  liters = tonumber(liters)
  price = tonumber(price)
  if not liters or liters <= 0 or liters > 150 then return false end
  if not price or price <= 0 or price > 100 then return false end

  local expected = math.floor(liters * HPXFuelConfig.defaultPrice * 100 + 0.5) / 100
  if math.abs(price - expected) > 0.01 then return false end

  local player = exports.hpx_core:GetPlayer(source)
  if not player then return false end
  return player:RemoveMoney('bank', price, 'fuel-purchase')
end)
