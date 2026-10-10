-- Charging stations: the sd_scoot_charger prop family and how a docked scooter sits in it.
return {
    Model = 'sd_scoot_charger', -- the pay totem on its cast-concrete plinth module (screen, card reader, QR label); prop origin on the plinth centre line where RailStart is measured from
    LightsModel = nil, -- optional bright twin attached to the totem; the LED seams are emissive faces in the drawables, so none is needed
    DockModel = { 'sd_scoot_charger_dock_1', 'sd_scoot_charger_dock_2', 'sd_scoot_charger_dock_3', 'sd_scoot_charger_dock_4' }, -- one per dock position so the dials print 01..04; each is a DockPitch run of plinth with its wheel trough and post, origin at the cell centre
    EndModel = 'sd_scoot_charger_end', -- the plinth's rounded end cap, origin at the last dock's outer edge
    ShellModel = 'sd_scoot_charger_shell_%d', -- the painted post shell, one model per colour; %d is the colour index
    TotemShellModel = 'sd_scoot_charger_tshell_%d', -- the painted totem shell, one model per colour

    -- Paint for a station, chosen when it is placed. Only the post and totem shells carry it, so a
    -- colour costs one small model each and every other part of the station is shared.
    -- `rgb` is the linear colour the shell is baked with; `hex` only feeds the admin swatches.
    Colours = {
        { name = 'Teal', rgb = { 0.010, 0.290, 0.320 }, hex = '#0a949a' },
        { name = 'Charcoal', rgb = { 0.012, 0.014, 0.017 }, hex = '#22282e' },
        { name = 'White', rgb = { 0.905, 0.905, 0.905 }, hex = '#f4f4f4' },
        { name = 'Red', rgb = { 0.527, 0.005, 0.011 }, hex = '#c00e1a' },
        { name = 'Blue', rgb = { 0.004, 0.112, 0.440 }, hex = '#0d5fb1' },
        { name = 'Yellow', rgb = { 0.930, 0.654, 0.008 }, hex = '#f7d117' },
        { name = 'Orange', rgb = { 0.930, 0.235, 0.008 }, hex = '#f78616' },
        { name = 'Green', rgb = { 0.070, 0.591, 0.012 }, hex = '#4cc81f' },
        { name = 'Purple', rgb = { 0.209, 0.027, 0.701 }, hex = '#7f2fdb' },
        { name = 'Pink', rgb = { 0.888, 0.012, 0.319 }, hex = '#f21f99' },
    },
    DefaultColour = 1, -- the colour a station gets when none is picked
    -- One lens per occupied slot, by charge state: idle = docked and connected but not charging (paid
    -- charging nobody has bought yet), charging = topping up, full = done.
    LensModels = { idle = 'sd_scoot_charger_lens_b', charging = 'sd_scoot_charger_lens_a', full = 'sd_scoot_charger_lens_g' },
    HoopModel = nil, -- optional swing arms, two per dock; the posts latch the scooter's stem key inside the head like a real docking station, so none are drawn. 'sd_scoot_charger_hoop' brings the old arms back
    HoopPivot = vec3(0.0, -0.47, 0.0), -- the posts' centre line relative to a slot's X on the rail; matches the model
    HoopSpread = 0.085, -- metres from the slot centre to each post (the left arm sits at -Spread, the right at +Spread)
    HoopOpen = 95.0, -- degrees each arm swings back toward the rail when the dock is open; 0 = closed over the tyre

    -- Docking and undocking are animated on the clients from the scooter's `sd_scoot_dock` state
    -- bag: an empty dock stands open, the scooter glides in, the arms swing shut over the tyre;
    -- unlock swings them open and the scooter backs out. Milliseconds.
    Anim = {
        Hoop = 250, -- latch time, open or shut (also the swing time of the optional arms)
        Approach = 900, -- straighten up onto the dock's centre line, at the depth the rider stopped at (scaled by how far that is)
        ApproachDistance = 1.6, -- metres in front of the slot pose the straightening happens at, at most; further out is pulled in to this
        MinApproach = 0.45, -- ...and at least this far out, so a scooter stopped on the ramp still backs off enough to line up
        Slide = 1300, -- glide from that line-up point into the slot (scaled by the distance)
        Out = 1100, -- glide back out on unlock
        ExitDistance = 0.8, -- metres the scooter backs out of the slot on unlock: just clear of the cradle
        Settle = 250, -- pause before the bars drop again
    },
    StreamDistance = 250.0, -- metres from a station at which its props are created (and removed again)
    Slots = 4, -- docks a freshly placed station gets unless the admin picks another count
    MaxSlots = 4, -- the most docks a station can have; SlotX needs one entry per dock
    RailStart = -1.4, -- x in the prop's space where the first dock begins (the pillar's rail stub ends here)
    DockPitch = 0.7, -- metres of rail per dock; dock i is centred at RailStart + DockPitch * (i - 0.5)

    -- Dock geometry in the prop's own space: X runs along the rail, the docks open towards -Y and
    -- Z is up. A docked scooter's origin (mid-wheelbase) sits at SlotX[slot], SlotY and faces +Y
    -- into the rail, so its heading is the station heading plus SlotHeadingOffset.
    SlotX = { -1.05, -0.35, 0.35, 1.05 },
    SlotY = -1.02, -- metres in front of the rail centre line (front wheel just short of the bumper)
    SlotHeadingOffset = 0.0, -- degrees added to the station heading for a docked scooter
    LensOffset = vec3(-0.0775, -0.7488, 0.7798), -- status bar centre relative to a slot's X: on the dock puck's glass pod, half a millimetre above the printed bar so the two never fight for the same pixels
    -- The stem clamp a docked scooter wears: a dock-side half whose blade sits in the puck's lit slot,
    -- and a jaw hinged at its front seam that swings shut around the stem. Both are authored in the
    -- space of the scooter's steering bone, so they follow the stem's rake exactly.
    PlugModel = 'sd_scoot_charger_plug', -- the dock-side half. nil draws no clamp at all
    JawModel = 'sd_scoot_charger_jaw', -- the swinging half. nil leaves the dock-side half on its own
    PlugBone = 'forks_u', -- the scooter bone both halves attach to
    PlugOffset = vec3(0.0, 0.0, 0.0), -- the dock-side half in bone space (the model is authored in place)
    JawHinge = vec3(0.0, 0.049, 0.3332), -- the jaw's hinge pin in bone space; the jaw swings about the bone's Z (the stem axis)
    PlugAnim = {
        Slide = 0.05, -- metres the dock-side half starts tucked inside the puck before it reaches the stem
        SlideMs = 240, -- ms it takes to reach the stem
        JawOpen = 115.0, -- degrees the jaw stands open before it closes
        SwingMs = 380, -- ms the jaw takes to swing shut (with a slight snap past closed)
        FadeMs = 120, -- ms the jaw takes to fade in at the start of the swing, and out at the end of a release
        ReleaseMs = 260, -- ms the jaw takes to swing open again when the scooter is unlocked
    },

    -- Point light per occupied slot so the lens colour spills onto the deck. nil disables it.
    -- Colours match the lens models: blue connected, amber charging (breathing), green full.
    Glow = {
        idle = { 60, 120, 255 },
        charging = { 255, 150, 20 },
        full = { 60, 255, 120 },
        range = 1.2,
        intensity = 0.8,
        PulseMs = 1800, -- one breath of the charging glow
        PulseMin = 0.35, -- the dimmest point of the breath, as a share of intensity
    },

    -- Riding a scooter up to a dock shows a prompt to park it there. The prompt keys off the
    -- nearest FREE dock, not the station origin, so it only shows when you are actually at the rail.
    Dock = {
        Key = 38, -- control id held while the prompt shows (38 = E)
        PromptDistance = 3.0, -- metres between the scooter and the nearest free dock at which the prompt appears (1.5..6)
    },

    -- The pillar screen is a DUI page drawn over the model's own screen texture. The texture is
    -- replaced model-wide, so the page follows the station nearest the player.
    Screen = {
        Page = 'web/build/screen/index.html', -- served from this resource
        Width = 512, -- pixels; the screen mesh is portrait 16:25
        Height = 800,
        Txd = 'sd_scoot_charger', -- the drawable's embedded texture dictionary
        Txn = 'sd_scoot_charger_screen_d', -- the screen material's texture inside it
        Range = 12.0, -- metres; beyond this the screen shows the idle logo. Every charger shares one screen page showing the nearest station, so the placement tool warns when a new station goes within this distance of another
        -- Paying at the screen: the confirm step offers these accounts. 'bank' shows as Card.
        Payment = {
            Methods = { 'bank', 'cash' }, -- any of 'bank', 'cash'; the first is preselected
        },
        WakeMs = 120000, -- ms the dock list stays up after someone closes the screen view or a scooter docks, before the start screen loop returns (same station only)
        Brightness = 1.0, -- 0..1 dims the page itself (the model's emissive multiplier is 0.18); lower if the screen glows too hard at night
        RefreshMs = 500, -- how often the client re-picks the nearest station and pushes its state
        -- Walk-up viewing: an ox_target option on the pillar (falls back to a text prompt when
        -- ox_target is not running) that puts a scripted camera in front of the screen.
        View = {
            Label = 'View charger screen',
            Icon = 'fa-solid fa-charging-station',
            Distance = 2.5, -- metres the target option is usable from
            CameraOffset = vec3(0.0, -1.05, 0.0), -- camera position relative to the screen centre, in the prop's space (docks open to -Y)
            LookOffset = vec3(0.0, 0.0, 0.0), -- what the camera looks at, relative to the screen centre
            ScreenCentre = vec3(-1.86, -0.721, 1.235), -- the totem's screen glass face in the prop's space; matches the model
            GlassSize = vec2(0.32, 0.50), -- glass width and height (m); the cursor is mapped onto this rectangle
            Fov = 34.0,
            EaseMs = 650, -- interpolation into and out of the view
            -- While the camera is up a mouse cursor is drawn and forwarded into the page, so the
            -- Unlock buttons on the screen can be clicked. The unlock itself follows the app's rules.
            Cursor = 1, -- cursor sprite id (1 = arrow)
            CloseAfterUnlockMs = 1500, -- how long the view stays up after a successful unlock
        },
    },

    -- Inserted on first boot when sd_scoot_stations is empty. Manage everything after that through
    -- /scootadmin; this list is not re-read.
    Seed = {},
}
