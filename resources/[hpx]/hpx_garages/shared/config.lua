local function point(coords, spawn, blip, radius)
  return { coords = coords, spawn = spawn, blip = blip, radius = radius }
end

local PUBLIC_BLIP <const> = { sprite = 357, color = 3, name = 'Public Parking' }

local function publicGarage(label, coords, spawn)
  return { label = label, vehicleType = 'car', accessPoints = { point(coords, spawn, PUBLIC_BLIP) } }
end

HPXGarages = {
  control = 38,           -- E
  interactDistance = 2.5, -- default access point radius
  distanceSlack = 3.0,    -- extra server-side tolerance on top of the radius
  spawnClearRadius = 3.0,
  depotFee = 250,         -- used when a vehicle is out or impounded without a set price
  actionCooldown = 1500,  -- ms between garage actions per player
  maxPropsSize = 16384,

  -- vehicleType: 'car' | 'air' | 'sea'
  -- type = 'depot' lists out/impounded vehicles and charges a fee
  -- groups = { name = minGrade } matches job or gang
  -- shared = true lets every member see vehicles stored in that garage
  garages = {
    pillbox       = publicGarage('Pillbox Parking', vec4(218.66, -804.08, 30.75, 65.69), vec4(229.33, -805.01, 30.54, 156.79)),
    motelgarage   = publicGarage('Motel Parking', vec4(275.58, -344.74, 45.17, 70.0), vec4(271.26, -342.32, 44.7, 159.97)),
    sapcounsel    = publicGarage('San Andreas Parking', vec4(-330.67, -781.12, 33.96, 40.46), vec4(-337.11, -775.34, 33.56, 132.09)),
    spanishave    = publicGarage('Spanish Ave Parking', vec4(-1160.46, -741.04, 19.95, 41.26), vec4(-1165.38, -747.65, 18.94, 40.45)),
    caears24      = publicGarage('Caears 24 Parking', vec4(68.08, 13.15, 69.21, 160.44), vec4(72.61, 11.72, 68.47, 157.59)),
    littleseoul   = publicGarage('Little Seoul Parking', vec4(-463.51, -808.2, 30.54, 0.0), vec4(-472.24, -813.61, 30.3, 179.88)),
    lagunapi      = publicGarage('Laguna Parking', vec4(363.85, 297.97, 103.5, 341.39), vec4(367.41, 297.02, 103.2, 341.08)),
    airportp      = publicGarage('Airport Parking', vec4(-796.07, -2023.26, 9.17, 55.18), vec4(-793.35, -2020.62, 8.51, 58.42)),
    beachp        = publicGarage('Beach Parking', vec4(-1184.21, -1509.65, 4.65, 303.72), vec4(-1184.4, -1501.88, 4.39, 214.7)),
    themotorhotel = publicGarage('The Motor Hotel Parking', vec4(1137.77, 2663.54, 37.9, 0.0), vec4(1137.56, 2674.19, 38.17, 359.95)),
    shoreparking  = publicGarage('Shore Parking', vec4(1726.9, 3710.38, 34.26, 22.54), vec4(1728.65, 3714.85, 34.18, 21.26)),
    haanparking   = publicGarage('Bell Farms Parking', vec4(78.34, 6418.74, 31.28, 0.0), vec4(70.71, 6425.16, 30.92, 68.5)),

    intairport = {
      label = 'Airport Hangar',
      vehicleType = 'air',
      accessPoints = { point(vec4(-1025.34, -3017.0, 13.95, 331.99), vec4(-979.2, -2995.51, 13.95, 52.19), { sprite = 360, color = 3, name = 'Hangar' }, 4.0) },
    },
    lsymc = {
      label = 'LSYMC Boathouse',
      vehicleType = 'sea',
      accessPoints = { point(vec4(-794.64, -1510.89, 1.6, 201.55), vec4(-793.58, -1501.4, 0.12, 111.5), { sprite = 356, color = 3, name = 'Boathouse' }, 3.0) },
    },

    police = {
      label = 'Police Garage',
      vehicleType = 'car',
      groups = { police = 0 },
      shared = true,
      accessPoints = { point(vec4(454.6, -1017.4, 28.4, 0.0), vec4(438.4, -1018.3, 27.7, 90.0)) },
    },

    impoundlot = {
      label = 'Impound Lot',
      type = 'depot',
      vehicleType = 'car',
      accessPoints = { point(vec4(400.45, -1630.87, 29.29, 228.88), vec4(407.2, -1645.58, 29.31, 228.28), { sprite = 68, color = 3, name = 'Impound Lot' }) },
    },
    airdepot = {
      label = 'Air Depot',
      type = 'depot',
      vehicleType = 'air',
      accessPoints = { point(vec4(-1244.35, -3391.39, 13.94, 59.26), vec4(-1269.03, -3376.7, 13.94, 330.32), { sprite = 359, color = 3, name = 'Air Depot' }, 4.0) },
    },
    seadepot = {
      label = 'LSYMC Depot',
      type = 'depot',
      vehicleType = 'sea',
      accessPoints = { point(vec4(-772.71, -1431.11, 1.6, 48.03), vec4(-729.77, -1355.49, 1.19, 142.5), { sprite = 356, color = 3, name = 'LSYMC Depot' }, 3.0) },
    },
  },
}
