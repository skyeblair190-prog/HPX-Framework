-- The bunker prop and how it behaves in the world.
return {
    Model = 'sd_scoot_bunker2', -- streamed from stream/ with its ytyp; the origin is at the base of the body
    StreamDistance = 250.0, -- metres from a bunker at which its prop is created (and removed again)
    RiseDepth = 1.05, -- metres the body sits below ground when parked; matches the Blender animation
    Stock = 5, -- scooters a freshly created bunker holds; docking a ride puts one back
    DispenseRadius = 200.0, -- metres around a bunker in which clients play the dispense animation

    -- The dispense cycle. Every client near the bunker plays the same fixed timeline; the server
    -- spawns the real vehicle at `SpawnAt` and frees the bunker at `TotalMs`. Offsets are in the
    -- prop's own space (the hatch faces -X, Z is up), matching the Blender file.
    Dispense = {
        Models = { slat = 'sd_scoot_slat', ramp = 'sd_scoot_ramp', pusher = 'sd_scoot_pusher' },
        Rise = { 0, 2200 },
        ShutterOpen = { 2200, 3400 },
        RampOut = { 3300, 4000 },
        Push = { 4000, 6000 },
        Coast = { 6000, 7000 },
        Unfold = { 7000, 7350 }, -- the stem snaps up like a spring latch: one extras pose per ~30 ms (about two frames)
        VehicleAt = 4000, -- the server creates the vehicle here, hidden, so it is streamed in before the swap
        SpawnAt = 8200, -- the scooter props vanish and the vehicle is revealed in the same frame
        Colour = 10, -- Config.Scooters.Colours index the props are painted in (Teal); the vehicle matches it
        PusherBack = { 6000, 7300 },
        RampIn = { 8400, 9100 },
        ShutterClose = { 9100, 10300 },
        Sink = { 10300, 12500 },
        TotalMs = 12500,

        Slats = 11, SlatPitch = 0.06, SlatBottom = 0.10, HousingBottom = 0.76, ShutterLift = 0.68,
        RampHinge = vec3(-1.02, 0.0, 0.1195), RampOpenDeg = 164.5,
        PusherRest = 0.32, PusherOut = -0.93,
        -- X of the vehicle origin (mid-wheelbase). Folded, the real scooter reaches 0.58 m behind its
        -- origin (handlebars), so at rest it sits 0.12 m further into the bay than the old prop did to
        -- keep the pusher's hook face (PusherRest - 0.14) clear of it; the push travel equals the pusher's.
        -- 1.12x scooter (2026-09-13): folded rear reach 0.65 m, hook face now at 0.30 (short pusher).
        ScooterRest = vec3(-0.37, 0.0, 0.112), ScooterPushed = -1.62, ScooterClear = -2.45,
        RampTopX = -0.51, RampBottomX = -0.91, RearOnRampX = -1.18, RearDownX = -1.58, RampPitchDeg = 9.5, RampDropZ = 0.062,
        VehicleHeadingOffset = 90.0, -- vehicle heading = bunker heading + this (the scooter exits along the prop's -X)

        -- The scooter that rides out is a local, non-networked copy of the real vehicle: same model,
        -- same paint as the one the server spawns, so the hand-over at SpawnAt is between two
        -- identical vehicles. The stem fold is a flipbook of vehicle extras baked into sd_scoot.yft
        -- (extra 1 = riding stem, 2 = folded, 3..12 = in-betweens with the easing already in them).
        Vehicle = {
            OriginHeight = 0.379, -- vehicle origin above its wheel contact patch (0.338 x 1.12); the deck path is ground-relative
            Yaw = 90.0, -- attach yaw that points the vehicle's nose (+Y) along the prop's -X exit
            Upright = 1, -- extra id every real scooter must show
            StemPoses = { 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 1 }, -- folded -> upright, played evenly over Unfold (extra 10 is unusable in-game, so it is empty)
            -- The real vehicle is created this far below the exit spot, out of sight, so nobody can see it
            -- before the hand-over; its owner lifts it onto the local copy's exact pose at SpawnAt and every
            -- client swaps only once it reports being there (or after RevealWaitMs, whichever comes first).
            HiddenDepth = 3.0,
            RevealWaitMs = 1000,
            -- If the real vehicle has not reached this client yet at SpawnAt (the first dispense of a
            -- session streams both the model and the entity), the ride-out copy is detached from the
            -- bunker and held at the exit spot for this long rather than vanishing into the gap.
            HandoverGraceMs = 4000,
        },
    },

    -- The lid LEDs. The bunker's own lenses are baked dim; a bright twin prop of the same lenses
    -- (sd_scoot_lights, offset a hair above them) fades in over the dim ones while a scooter is
    -- being called and fades out again as the body sinks. Windows are ms into the dispense cycle.
    Lights = {
        Model = 'sd_scoot_lights',
        FadeIn = { 0, 1500 },
        FadeOut = { 11000, 12500 },
        -- A cyan point light over the lid while lit, so the glow spills onto the pavement. nil disables it.
        Glow = { colour = { 0, 210, 255 }, height = 1.4, range = 3.0, intensity = 1.5 },
    },

    -- Inserted on first boot when sd_scoot_bunkers is empty, so a fresh install has one bunker to
    -- look at. Manage everything after that through /scootadmin; this list is not re-read.
    Seed = {
        { name = 'Legion Square', x = 195.2, y = -933.8, z = 30.69, heading = 0.0 },
    },
}
