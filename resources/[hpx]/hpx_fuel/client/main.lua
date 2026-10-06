local activePump = nil

local function vehicleFuel(vehicle)
  return GetVehicleFuelLevel(vehicle)
end

local function setFuel(vehicle, value)
  SetVehicleFuelLevel(vehicle, math.max(0.0, math.min(100.0, value)))
end

local function buyFuel(vehicle, liters)
  local price = lib.callback.await('hpx:fuel:getPrice', false)
  local total = math.floor(liters * price * 100 + 0.5) / 100
  local ok = lib.callback.await('hpx:fuel:purchase', false, liters, total)
  if not ok then
    lib.notify({ type = 'error', description = 'Unable to pay for fuel.' })
    return false
  end
  setFuel(vehicle, vehicleFuel(vehicle) + liters)
  return true
end

local function openPump()
  local ped = PlayerPedId()
  local vehicle = GetVehiclePedIsIn(ped, false)
  if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then return end

  local current = vehicleFuel(vehicle)
  local liters = math.max(0, math.min(100 - current, 20))
  if liters <= 0 then
    lib.notify({ description = 'Tank is already full.' })
    return
  end

  buyFuel(vehicle, liters)
end

CreateThread(function()
  while true do
    Wait(HPXFuelConfig.tick)
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == PlayerPedId() and GetIsVehicleEngineRunning(vehicle) then
      setFuel(vehicle, vehicleFuel(vehicle) - HPXFuelConfig.drain)
    end
  end
end)

CreateThread(function()
  exports.hpx_core:AddModelInteraction({
    models = { `prop_gas_pump_1a`, `prop_gas_pump_1b`, `prop_gas_pump_1c`, `prop_gas_pump_1d`, `prop_gas_pump_old2`, `prop_gas_pump_old3` },
    name = 'hpx_fuel_pump',
    distance = 2.0,
    options = {
      { label = 'Fuel vehicle', icon = 'gas-pump', action = openPump }
    }
  })
end)

exports('GetFuel', vehicleFuel)
exports('SetFuel', setFuel)
exports('BuyFuel', buyFuel)
