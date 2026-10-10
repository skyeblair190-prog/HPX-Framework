-- The scooter battery: drains on rides, recovers at a charging station.
return {
    Enabled = true, -- false keeps every scooter at 100 and hides the battery from the app
    DrainPerMinute = 2.5, -- percent per ride minute (2.5 = about 40 minutes from full)
    MinToRent = 15, -- percent; below this the app shows "Needs charge" and refuses to unlock
    ChargePerMinute = 20, -- percent per minute while docked at a station (20 = 5 minutes to full); the screen's time estimates and prices follow this
    FullAt = 100, -- percent at which the slot lens turns green
    FlatRecoverMinutes = 30, -- minutes a flat scooter waits in the street before the fleet collects it
    AdoptedLevel = 55, -- percent a scooter that was not part of the fleet starts with when someone docks it (0..100)
    TickSeconds = 60, -- seconds between battery ticks; also the resolution of the drain (10..300)

    -- Charging is a paid service picked on the station screen: a docked scooter only charges once
    -- someone chose a target percent and paid for it. The charge stops at that target.
    Paid = {
        Enabled = true, -- false: every docked scooter charges to full for free, no screen purchase needed
        Account = 'bank', -- 'bank' | 'cash'; where the charge is paid from
        PricePerPercent = 0.1, -- currency per percent of charge bought; the bill is rounded up to whole currency
        MinimumFee = 1, -- the smallest bill for any charge
        Step = 5, -- the target moves in steps of this many percent on the screen
        Presets = { 50, 75, 100 }, -- one-tap targets the screen offers (only those above the current level show)
        RefundOnStop = true, -- stopping a charge early refunds the percent not yet delivered, at PricePerPercent, rounded down
    },
}
