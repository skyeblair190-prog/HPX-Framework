---@param state VehicleState
---@return integer stored, string status
local function splitState(state)
    if state == VehicleState.IMPOUNDED then return 1, 'impounded' end
    if state == VehicleState.GARAGED then return 1, 'normal' end
    return 0, 'normal'
end

---@async
local function moveOutVehiclesIntoGarages()
    MySQL.update('UPDATE hpx_vehicles SET stored = 1 WHERE stored = 0')
end

---@param vehicleId integer
---@param garageName string
---@param state VehicleState
---@return integer numRowsAffected
local function setVehicleGarage(vehicleId, garageName, state)
    local stored, status = splitState(state)
    return MySQL.update.await('UPDATE hpx_vehicles SET garage = ?, stored = ?, state = ? WHERE id = ?', {
        garageName,
        stored,
        status,
        vehicleId
    })
end

---@param vehicleId integer
---@param depotPrice integer
---@return integer numRowsAffected
local function setVehicleDepotPrice(vehicleId, depotPrice)
    return MySQL.update.await("UPDATE hpx_vehicles SET depot_price = ? WHERE id = ? AND NOT (stored = 1 AND state = 'normal')", {
        depotPrice,
        vehicleId
    })
end

return {
    moveOutVehiclesIntoGarages = moveOutVehiclesIntoGarages,
    setVehicleGarage = setVehicleGarage,
    setVehicleDepotPrice = setVehicleDepotPrice,
}
