HPXConfig = {
  debug = false,
  character = {
    maxSlots = 5,
    defaultMoney = { cash = 500, bank = 2500, crypto = 0 },
    defaultJob = { name = 'unemployed', label = 'Unemployed', grade = 0, onduty = false, payment = 0 },
    defaultGang = { name = 'none', label = 'None', grade = 0 },
  },
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
