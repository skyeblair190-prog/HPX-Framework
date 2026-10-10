-- The rental scooters: one server-owned sd_scoot vehicle per row in sd_scoot_scooters.
return {
    Model = 'sd_scoot', -- vehicle model from data/vehicles.meta (bike class)
    PlatePrefix = 'SCOOT', -- plates are the prefix plus a 3-digit counter: SCOOT001, SCOOT002, ...
    SaveInterval = 60, -- seconds between position write-backs for scooters that moved more than 1 m
    HealInterval = 30, -- seconds between checks for missing, unrented scooter entities
    KeepOnRestart = false, -- false: scooters out in the world are removed when the resource starts (dispensed ones go back into their bunker's stock); only scooters docked at a charging station survive. true keeps every scooter where it was
    GroundClearance = 0.379, -- metres the vehicle origin sits above the ground (mid-wheelbase; 0.338 x the 1.12 scale)
    BunkerOffset = vec3(0.0, -1.6, 0.0), -- spawn point relative to a bunker's origin; the slot faces the model's -Y
    SpeedUnit = 'mph', -- 'kmh' or 'mph': the unit the handling editor's test ride reports speeds in
    -- Paint slots from data/carvariations.meta, in the same order as its fifteen <colors> items.
    -- `primary` is the GTA colour index applied to both primary and secondary; `hex` only feeds
    -- the swatches in the admin panel.
    Colours = {
        { name = 'Black', primary = 0, hex = '#0d1116' },
        { name = 'White', primary = 134, hex = '#f4f4f4' },
        { name = 'Red', primary = 27, hex = '#c00e1a' },
        { name = 'Blue', primary = 140, hex = '#0d5fb1' },
        { name = 'Yellow', primary = 89, hex = '#f7d117' },
        { name = 'Orange', primary = 138, hex = '#f78616' },
        { name = 'Green', primary = 139, hex = '#4cc81f' },
        { name = 'Purple', primary = 145, hex = '#7f2fdb' },
        { name = 'Pink', primary = 135, hex = '#f21f99' },
        { name = 'Teal', primary = 54, hex = '#1a6b78' },
        { name = 'Silver', primary = 5, hex = '#777c87' },
        { name = 'Forest Green', primary = 53, hex = '#003805' },
        { name = 'Ice Blue', primary = 67, hex = '#95b2db' },
        { name = 'Cream', primary = 107, hex = '#cfc0a5' },
        { name = 'Burgundy', primary = 31, hex = '#4a0a0a' },
    },
}
