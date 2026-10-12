HPXConfig = {
  debug = false,
  character = {
    maxSlots = 5,
    autoLoad = false,
    selectMenu = true,
    slotOverrides = {},
    backgrounds = { 'Local', 'Immigrant', 'Ex-Military', 'Drifter', 'Trust Fund' },
    scene = {
      center = { x = -75.0, y = -818.0, z = 326.2 },
      heading = 160.0,
      spacing = 1.45,
      wideDistance = 7.0,
      time = { 21, 30 },
      weather = 'CLEAR',
    },
    spawns = {
      { key = 'last', label = 'Last location', desc = 'Pick up exactly where you left off' },
      { key = 'legion', label = 'Legion Square', desc = 'Downtown Los Santos', coords = { x = 195.17, y = -933.77, z = 30.69, w = 144.0 } },
      { key = 'airport', label = 'LSIA Arrivals', desc = 'Los Santos International', coords = { x = -1037.0, y = -2736.5, z = 20.17, w = 330.0 } },
      { key = 'pillbox', label = 'Pillbox Hill', desc = 'Outside Pillbox Medical', coords = { x = 298.6, y = -584.5, z = 43.26, w = 70.0 } },
      { key = 'pier', label = 'Del Perro Pier', desc = 'Beachfront, west coast', coords = { x = -1842.0, y = -1224.0, z = 13.02, w = 320.0 } },
      { key = 'sandy', label = 'Sandy Shores', desc = 'Blaine County desert', coords = { x = 1961.5, y = 3740.7, z = 32.34, w = 300.0 } },
      { key = 'paleto', label = 'Paleto Bay', desc = 'Far north, by the bay', coords = { x = -105.8, y = 6465.1, z = 31.63, w = 45.0 } },
    },
    defaultMoney = { cash = 500, bank = 2500, crypto = 0 },
    defaultJob = { name = 'unemployed', label = 'Unemployed', grade = 0, onduty = false, payment = 0 },
    defaultGang = { name = 'none', label = 'None', grade = 0 },
    defaultMetadata = {
      hunger = 100, thirst = 100, stress = 0, isdead = false, inlaststand = false, armor = 0,
      callsign = 'NO CALLSIGN', ishandcuffed = false, tracker = false, injail = 0,
      licences = { id = true, driver = true, weapon = false },
      criminalrecord = { hasRecord = false },
    },
    bloodTypes = { 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-' },
  },
  needs = {
    enabled = true,
    interval = 60000,
    hungerLoss = 0.6,
    thirstLoss = 0.9,
    starveDamage = 3,
  },
  paycheck = {
    enabled = true,
    interval = 900000,
    account = 'bank',
    requireDuty = true,
  },
  gangs = {},
  jobs = {
    unemployed = { label = 'Unemployed', defaultDuty = false, grades = { [0] = { name = 'Unemployed', payment = 0 } } },
    police = {
      label = 'Los Santos Police Department', type = 'leo', defaultDuty = false,
      grades = {
        [0] = { name = 'Recruit', payment = 250 }, [1] = { name = 'Officer', payment = 350 },
        [2] = { name = 'Sergeant', payment = 450 }, [3] = { name = 'Lieutenant', payment = 550 },
        [4] = { name = 'Chief', payment = 700, isboss = true },
      },
    },
    ambulance = {
      label = 'Los Santos Medical', type = 'ems', defaultDuty = false,
      grades = {
        [0] = { name = 'Trainee', payment = 250 }, [1] = { name = 'Paramedic', payment = 350 },
        [2] = { name = 'Doctor', payment = 450 }, [3] = { name = 'Chief', payment = 650, isboss = true },
      },
    },
    mechanic = {
      label = 'Mechanic', type = 'mechanic', defaultDuty = false,
      grades = { [0] = { name = 'Apprentice', payment = 200 }, [1] = { name = 'Mechanic', payment = 300 }, [2] = { name = 'Owner', payment = 400, isboss = true } },
    },
    taxi = {
      label = 'Downtown Cab Co.', defaultDuty = false,
      grades = { [0] = { name = 'Driver', payment = 150 }, [1] = { name = 'Manager', payment = 250, isboss = true } },
    },
    garbage = {
      label = 'Sanitation', defaultDuty = false,
      grades = { [0] = { name = 'Collector', payment = 150 }, [1] = { name = 'Supervisor', payment = 250, isboss = true } },
    },
  },
  spawn = { x = 195.17, y = -933.77, z = 30.69, w = 144.0 },
  persistence = {
    saveInterval = 60000,
    saveOnDrop = true,
    saveOnResourceStop = true,
  },
  security = {
    maxMoneyDelta = 10000000,
    maxCallbackPayload = 16384,
  }
}

HPXConfig.character.spawnMap = {}
for _, spawn in ipairs(HPXConfig.character.spawns) do
  if spawn.coords then HPXConfig.character.spawnMap[spawn.key] = spawn.coords end
end
