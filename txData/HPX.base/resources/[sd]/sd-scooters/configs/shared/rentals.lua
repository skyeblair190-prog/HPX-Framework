-- The rental economy and the phone app that fronts it.
return {
    Enabled = true, -- register the phone app and the rental callbacks (needs a framework for money)
    UnlockFee = 5, -- charged when a ride starts
    Account = 'bank', -- 'bank' | 'cash'; where fees are taken from
    Currency = '$', -- symbol the app shows in front of prices
    RentDistance = 12.0, -- metres the player must be from a scooter to unlock it from the app
    StationDistance = 12.0, -- metres the player must be from a bunker to have it dispense a scooter
    DockDistance = 12.0, -- ending a ride this close to a bunker docks the scooter back into it
    NearbyRadius = 600.0, -- metres around the player the app lists loose scooters in
    ListLimit = 50, -- most bunkers (and most charging stations) the app's Stations tab lists, nearest first; they are listed whatever the distance, so the tab works as a directory
    LockIdle = true, -- lock scooters nobody is renting so they can only be ridden through the app
    MaxRideMinutes = 180, -- rides older than this are closed and billed automatically
    RefreshMs = 2500, -- ms between the app's live refreshes (player + scooter positions)

    -- The paid resource owns the full SCOOT UI and registers it externally with sd-phone.
    App = {
        identifier = 'scoot_external',
        name = 'SCOOT',
        description = 'Rent an e-scooter near you',
        developer = 'SCOOT Mobility',
        size = 4096, -- KB shown in the app store
        defaultApp = true, -- pre-installed on every phone
        wifi = false, -- works without signal so a ride can always be ended
        ForceCustom = true,
    },
}
