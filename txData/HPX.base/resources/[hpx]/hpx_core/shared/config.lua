HPXConfig = {
  debug = false,
  character = {
    maxSlots = 5,
    autoLoad = true,
    defaultMoney = { cash = 500, bank = 2500, crypto = 0 },
    defaultJob = { name = 'unemployed', label = 'Unemployed', grade = 0, onduty = false, payment = 0 },
    defaultGang = { name = 'none', label = 'None', grade = 0 },
    defaultMetadata = { hunger = 100, thirst = 100, stress = 0, isdead = false, armor = 0 },
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
      label = 'Los Santos Police Department', defaultDuty = false,
      grades = {
        [0] = { name = 'Recruit', payment = 250 }, [1] = { name = 'Officer', payment = 350 },
        [2] = { name = 'Sergeant', payment = 450 }, [3] = { name = 'Lieutenant', payment = 550 },
        [4] = { name = 'Chief', payment = 700, isboss = true },
      },
    },
    ambulance = {
      label = 'Los Santos Medical', defaultDuty = false,
      grades = {
        [0] = { name = 'Trainee', payment = 250 }, [1] = { name = 'Paramedic', payment = 350 },
        [2] = { name = 'Doctor', payment = 450 }, [3] = { name = 'Chief', payment = 650, isboss = true },
      },
    },
    mechanic = {
      label = 'Mechanic', defaultDuty = false,
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
