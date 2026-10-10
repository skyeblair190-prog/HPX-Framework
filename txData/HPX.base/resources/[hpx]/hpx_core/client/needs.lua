CreateThread(function()
  if not HPXConfig.needs.enabled then return end

  while true do
    Wait(10000)
    if LocalPlayer.state.isLoggedIn or exports.hpx_core:IsLoaded() then
      local data = exports.hpx_core:GetPlayerData()
      local metadata = type(data) == 'table' and data.metadata or nil
      local ped = PlayerPedId()

      if metadata and not IsPedDeadOrDying(ped, true) and ((metadata.hunger or 100) <= 0 or (metadata.thirst or 100) <= 0) then
        local health = GetEntityHealth(ped)
        if health > 105 then SetEntityHealth(ped, math.max(101, health - HPXConfig.needs.starveDamage)) end
      end
    end
  end
end)
