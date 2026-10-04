Config = {}

Config.Position = 'bottom' 
Config.HoldKey = 'E'       
Config.HoldTime = 5        

Config.Texts = {
    dead = 'YOU ARE DEAD',
    incapacitated = 'YOU ARE INCAPACITATED',
    doctorWait = 'PLEASE WAIT FOR DOCTORS, EVERYTHING WILL BE FINE.',
    holdPrefix = 'HOLD',
    holdSuffix = 'TO RESPAWN OR WAIT FOR THE EMS',
}

Config.Debug = false 


Config.Integrations = {
    Enabled = true, 

  
    IncapacitatedEvents = {
        { name = 'hospital:client:SetLaststandStatus', timeArg = 1 },
        { name = 'codera-deathscreen:die',                 timeArg = 1 },
      
    },

   
    DeadEvents = {
        { name = 'baseevents:onPlayerDied' },
    },

  
    ReviveEvents = {
        'hospital:client:Revive',
        'hospital:client:RespawnAtHospital',
        'NX-deathscreen:revive',
        -- 'esx_ambulancejob:revive',
    },
}
