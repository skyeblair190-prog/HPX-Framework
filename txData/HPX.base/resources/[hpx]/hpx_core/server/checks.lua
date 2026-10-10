CreateThread(function()
  Wait(1000)
  local problems = {}

  if GetConvar('onesync', 'off') == 'off' then
    problems[#problems + 1] = 'OneSync is off. Add "set onesync on" to server.cfg (position saving and entities need it).'
  end
  if GetResourceState('ox_lib') ~= 'started' then problems[#problems + 1] = 'ox_lib is not started.' end
  if GetResourceState('oxmysql') ~= 'started' then problems[#problems + 1] = 'oxmysql is not started.' end
  if GetResourceState('ox_inventory') ~= 'missing' and GetConvar('inventory:framework', '') ~= 'hpx' then
    problems[#problems + 1] = 'inventory:framework must be "hpx" (setr inventory:framework "hpx").'
  end

  for _, message in ipairs(problems) do
    print(('^1[hpx_core] %s^7'):format(message))
  end
  if #problems == 0 then print('^2[hpx_core] startup checks passed^7') end
end)
