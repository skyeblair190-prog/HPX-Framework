---Calculates the fee for retrieving a vehicle from the depot.
---@param vehicleId number
---@param modelName string
---@return number
local defaultCalculateImpoundFee = function(vehicleId, modelName)
    return Config.defaultImpoundFee or 0
end

return defaultCalculateImpoundFee
