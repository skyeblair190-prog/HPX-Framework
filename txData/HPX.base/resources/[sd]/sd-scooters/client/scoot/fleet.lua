---@type table sd_scoot config root (configs/config.lua).
local config = require 'configs.config'

---One scan of the vehicle pool for the whole resource. Every client module that used to walk
---GetGamePool('CVehicle') on its own timer (extras, kickstand, rider, handling, docks,
---upright check) reads these lists instead, so the pool is walked once, not seven times.
---Networked vehicles stream in from ~400 m, far beyond anything drawn or animated on a scooter, so
---the per-frame work keys off `near` (scooters within NEAR metres) and everything sleeps while that
---is empty, even with scooters parked across the map.
local fleet = {}

local MODEL = joaat(config.Scooters.Model)
local NEAR = 80.0 -- metres from the player; the widest feature range (kickstand/extras 35 m, rider IK) plus margin
local BUSY_MS = 500 -- rescan interval while a scooter is near
local IDLE_MS = 1000 -- ...and while none is

---@type integer[] every streamed scooter handle as of the last scan
local all = {}
---@type integer[] streamed scooters within NEAR metres
local near = {}

---Scooters near the player, as of the last scan.
---@return integer[] scooters within NEAR metres of the player (a handle may have been deleted since the scan; check the model)
function fleet.list() return near end

---Every streamed scooter, as of the last scan.
---@return integer[] every streamed scooter, however far (for owner-side checks that must cover them all)
function fleet.all() return all end

---Whether any scooter was near the player at the last scan.
---@return boolean true while a scooter is within NEAR metres
function fleet.any() return near[1] ~= nil end

fleet.model = MODEL

---Scans the vehicle pool for scooters, refreshing the all and near lists every 500 ms while one is near, 1 s otherwise.
CreateThread(function()
    while true do
        local found, close = {}, {}
        local pool = GetGamePool('CVehicle')
        local here = GetEntityCoords(PlayerPedId())
        for i = 1, #pool do
            local v = pool[i]
            if GetEntityModel(v) == MODEL then
                found[#found + 1] = v
                if #(GetEntityCoords(v) - here) <= NEAR then close[#close + 1] = v end
            end
        end
        all, near = found, close
        Wait(close[1] and BUSY_MS or IDLE_MS)
    end
end)

---Module export: the fleet lists.
package.preload['client.scoot.fleet'] = function() return fleet end
