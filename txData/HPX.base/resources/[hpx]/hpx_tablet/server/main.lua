local allowedItems = {
  [Config.UndergroundAppItem] = true,
  [Config.HQAppItem] = true
}

lib.callback.register('codera-tablet:hasItem', function(source, item)
  if type(item) ~= 'string' or not allowedItems[item] then return false end
  if not exports.hpx_core:GetPlayer(source) then return false end
  return (exports.ox_inventory:GetItemCount(source, item) or 0) > 0
end)
