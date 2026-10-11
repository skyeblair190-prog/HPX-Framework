Config = {
    command = 'garageadmin',
    group = 'group.admin',
    ace = 'hp4_garages.admin',

    restoreDelay = 420,
    restoreTick = 2000,
    maxSpawnsPerTick = 2,
    retryBackoff = 15,
    maxBackoff = 300,
    spawnTimeout = 3000,

    saveInterval = 5000,
    maxSavesPerTick = 40,
    minMove = 0.75,
    minTurn = 3.0,
    minHealth = 10.0,
    propsInterval = 60000,

    spotRelease = 3.5,
    spotSnap = 2.0,
    minSpotSpacing = 2.5,
    wreckedEngine = -3999.0,

    clearance = {
        automobile = 3.5, bike = 1.8, trailer = 5.0,
        heli = 8.0, plane = 14.0, boat = 7.0, submarine = 7.0,
    },
    defaultClearance = 4.0,

    vehicleTypes = { 'automobile', 'bike', 'trailer', 'boat', 'heli', 'plane' },
    markerDistance = 80.0,

    migrations = { 'sql/001_init.sql' },
}
