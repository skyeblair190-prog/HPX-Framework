-- Live handling editor (/scootadmin -> Handling). Admins tune the scooter's handling in the panel, test
-- ride it on their own scooter, and publish a profile that every client applies to every sd_scoot.
-- data/handling.meta stays the baseline: a profile only stores the fields that differ from it, and the
-- panel can export the result as a handling.meta block to make it the permanent default.
return {
    Enabled = true, -- false hides the tab and stops clients applying any saved profile

    -- Test ride: the panel hides so you can ride with the draft applied to your own scooter only.
    ReturnKey = 'F7', -- keybind that brings the panel back from a test ride (players can rebind it in GTA settings)
    TelemetryMs = 100, -- ms between speed readouts on the test-ride HUD
    ApplyEveryMs = 1000, -- ms between client sweeps that catch newly streamed scooters and apply the published values

    HistoryLimit = 60, -- change log rows kept per profile (older ones are pruned)

    -- Plain-language dials. Each writes the raw fields below it; the raw values stay editable afterwards.
    -- TopSpeed: the real top speed is where drive force meets air drag, so it scales with
    -- sqrt(fInitialDriveForce / fInitialDragCoeff). Calibration anchors that ratio: a force of 0.26 with
    -- drag 16 rode at 61 mph. fInitialDriveMaxFlatVel is kept just above the target so it never limits it.
    Presets = {
        TopSpeed = { Min = 10, Max = 80, Step = 1, AnchorMph = 61.0, AnchorForce = 0.26, AnchorDrag = 16.0 },
        Acceleration = { Min = 1, Max = 10, Step = 1, ForceMin = 0.08, ForceMax = 0.45 }, -- 1 = gentle, 10 = punchy; keeps the chosen top speed
        Grip = { Min = 1, Max = 10, Step = 1, CurveMaxMin = 1.3, CurveMaxMax = 3.0 }, -- tyre grip; curve min follows at 90%
        Braking = { Min = 1, Max = 10, Step = 1, ForceMin = 0.3, ForceMax = 1.6 },
        Lean = { Min = 1, Max = 10, Step = 1, BankMin = 15.0, BankMax = 45.0 }, -- how far it leans into corners
    },

    -- Starting points offered when creating a profile. Values are raw fields; anything left out uses handling.meta.
    Templates = {
        { name = 'Relaxed (25 mph)', values = { fInitialDriveForce = 0.16, fInitialDragCoeff = 55.0, fInitialDriveMaxFlatVel = 20.0, fBrakeForce = 0.8 } },
        { name = 'Rental (40 mph)', values = { fInitialDriveForce = 0.21, fInitialDragCoeff = 30.0, fInitialDriveMaxFlatVel = 30.0 } },
        { name = 'Sport (55 mph)', values = { fInitialDriveForce = 0.30, fInitialDragCoeff = 22.0, fInitialDriveMaxFlatVel = 44.0, fBrakeForce = 1.1, fTractionCurveMax = 2.4, fTractionCurveMin = 2.2 } },
    },

    -- Every editable field. class: which handling block it lives in. unit: 'deg' fields are stored in radians
    -- by the game but shown and saved in degrees like handling.meta. min/max bound the slider and the server
    -- clamps to them. Fields not listed here (seat offsets, monetary value, flags) are not editable.
    Groups = {
        { id = 'engine', fields = {
            { name = 'fInitialDriveForce', min = 0.01, max = 2.0, step = 0.005 },
            { name = 'fInitialDragCoeff', min = 1.0, max = 120.0, step = 0.5 },
            { name = 'fInitialDriveMaxFlatVel', min = 5.0, max = 200.0, step = 0.5 },
            { name = 'fDriveInertia', min = 0.1, max = 2.0, step = 0.05 },
            { name = 'nInitialDriveGears', type = 'int', min = 1, max = 6, step = 1 },
            { name = 'fClutchChangeRateScaleUpShift', min = 0.1, max = 10.0, step = 0.1 },
            { name = 'fClutchChangeRateScaleDownShift', min = 0.1, max = 10.0, step = 0.1 },
            { name = 'fDriveBiasFront', min = 0.0, max = 1.0, step = 0.05 },
        } },
        { id = 'brakes', fields = {
            { name = 'fBrakeForce', min = 0.05, max = 3.0, step = 0.05 },
            { name = 'fBrakeBiasFront', min = 0.0, max = 1.0, step = 0.05 },
            { name = 'fHandBrakeForce', min = 0.0, max = 3.0, step = 0.05 },
        } },
        { id = 'traction', fields = {
            { name = 'fTractionCurveMax', min = 0.5, max = 4.0, step = 0.05 },
            { name = 'fTractionCurveMin', min = 0.5, max = 4.0, step = 0.05 },
            { name = 'fTractionCurveLateral', min = 5.0, max = 35.0, step = 0.5 },
            { name = 'fTractionSpringDeltaMax', min = 0.0, max = 0.5, step = 0.005 },
            { name = 'fLowSpeedTractionLossMult', min = 0.0, max = 2.0, step = 0.05 },
            { name = 'fTractionBiasFront', min = 0.0, max = 1.0, step = 0.01 },
            { name = 'fTractionLossMult', min = 0.0, max = 3.0, step = 0.05 },
            { name = 'fSteeringLock', min = 10.0, max = 75.0, step = 0.5 },
        } },
        { id = 'suspension', fields = {
            { name = 'fSuspensionForce', min = 0.5, max = 20.0, step = 0.1 },
            { name = 'fSuspensionCompDamp', min = 0.1, max = 20.0, step = 0.1 },
            { name = 'fSuspensionReboundDamp', min = 0.1, max = 20.0, step = 0.1 },
            { name = 'fSuspensionUpperLimit', min = 0.0, max = 0.3, step = 0.005 },
            { name = 'fSuspensionLowerLimit', min = -0.3, max = 0.0, step = 0.005 },
            { name = 'fSuspensionRaise', min = -0.1, max = 0.1, step = 0.005 },
            { name = 'fSuspensionBiasFront', min = 0.0, max = 1.0, step = 0.05 },
        } },
        { id = 'body', fields = {
            { name = 'fMass', min = 20.0, max = 400.0, step = 1.0 },
            { name = 'vecCentreOfMassOffset', type = 'vector', min = -0.5, max = 0.5, step = 0.01 },
            { name = 'vecInertiaMultiplier', type = 'vector', min = 0.1, max = 3.0, step = 0.05 },
            { name = 'fRollCentreHeightFront', min = -0.5, max = 0.5, step = 0.01 },
            { name = 'fRollCentreHeightRear', min = -0.5, max = 0.5, step = 0.01 },
            { name = 'fPercentSubmerged', min = 10.0, max = 100.0, step = 1.0 },
        } },
        { id = 'bike', fields = {
            { name = 'fLeanFwdForceMult', class = 'CBikeHandlingData', min = 0.0, max = 30.0, step = 0.25 },
            { name = 'fLeanBakForceMult', class = 'CBikeHandlingData', min = 0.0, max = 30.0, step = 0.25 },
            { name = 'fLeanFwdCOMMult', class = 'CBikeHandlingData', min = 0.0, max = 1.0, step = 0.01 },
            { name = 'fLeanBakCOMMult', class = 'CBikeHandlingData', min = 0.0, max = 1.0, step = 0.01 },
            { name = 'fMaxBankAngle', class = 'CBikeHandlingData', min = 5.0, max = 60.0, step = 0.5 },
            { name = 'fFullAnimAngle', class = 'CBikeHandlingData', min = 5.0, max = 60.0, step = 0.5 },
            { name = 'fDesLeanReturnFrac', class = 'CBikeHandlingData', min = 0.01, max = 1.0, step = 0.01 },
            { name = 'fStickLeanMult', class = 'CBikeHandlingData', min = 0.1, max = 3.0, step = 0.05 },
            { name = 'fBrakingStabilityMult', class = 'CBikeHandlingData', min = -3.0, max = 3.0, step = 0.05 },
            { name = 'fInAirSteerMult', class = 'CBikeHandlingData', min = -5.0, max = 5.0, step = 0.1 },
            { name = 'fWheelieBalancePoint', class = 'CBikeHandlingData', unit = 'deg', min = -30.0, max = 45.0, step = 0.5 },
            { name = 'fStoppieBalancePoint', class = 'CBikeHandlingData', unit = 'deg', min = -45.0, max = 30.0, step = 0.5 },
            { name = 'fWheelieSteerMult', class = 'CBikeHandlingData', min = -3.0, max = 3.0, step = 0.05 },
            { name = 'fRearBalanceMult', class = 'CBikeHandlingData', min = 0.0, max = 100.0, step = 0.5 },
            { name = 'fFrontBalanceMult', class = 'CBikeHandlingData', min = 0.0, max = 150.0, step = 0.5 },
            { name = 'fBikeGroundSideFrictionMult', class = 'CBikeHandlingData', min = 0.1, max = 5.0, step = 0.05 },
            { name = 'fBikeWheelGroundSideFrictionMult', class = 'CBikeHandlingData', min = 0.1, max = 5.0, step = 0.05 },
            { name = 'fBikeOnStandLeanAngle', class = 'CBikeHandlingData', min = 0.0, max = 30.0, step = 0.5 },
            { name = 'fBikeOnStandSteerAngle', class = 'CBikeHandlingData', min = 0.0, max = 2.0, step = 0.05 },
            { name = 'fJumpForce', class = 'CBikeHandlingData', min = 0.0, max = 10.0, step = 0.1 },
        } },
        { id = 'damage', fields = {
            { name = 'fCollisionDamageMult', min = 0.0, max = 5.0, step = 0.05 },
            { name = 'fWeaponDamageMult', min = 0.0, max = 5.0, step = 0.05 },
            { name = 'fDeformationDamageMult', min = 0.0, max = 5.0, step = 0.05 },
            { name = 'fEngineDamageMult', min = 0.0, max = 5.0, step = 0.05 },
        } },
        -- Not a handling.meta field: the horn is picked per profile like everything above, and the
        -- handling.meta export leaves it out.
        { id = 'sound', fields = {
            { name = 'horn', type = 'horn' },
        } },
    },

    -- The scooter's horn (the vehicle horn key, E by default). Every entry is a base-game horn; its hash is
    -- what GetVehicleDefaultHornIgnoreMods returns for that vehicle. 'none' switches the horn off
    -- entirely so the key does nothing. DefaultHorn applies when a profile does not pick one.
    DefaultHorn = 'faggio',
    Horns = {
        { id = 'none', label = 'No horn' },
        { id = 'faggio', label = 'Faggio', hash = 899036790 },
        { id = 'sanchez', label = 'Sanchez', hash = 1790729873 },
        { id = 'bmx', label = 'BMX', hash = -477114602 },
        { id = 'cruiser', label = 'Cruiser bicycle', hash = 1031809464 },
        { id = 'panto', label = 'Panto', hash = 1748384362 },
        { id = 'issi', label = 'Issi', hash = -866822230 },
        { id = 'blista', label = 'Blista', hash = -468556329 },
        { id = 'rhapsody', label = 'Rhapsody', hash = 1694568013 },
        { id = 'taxi', label = 'Taxi', hash = 2011053539 },
        { id = 'police', label = 'Police cruiser', hash = -1861357332 },
        { id = 'mule', label = 'Mule van', hash = -579353968 },
        { id = 'bus', label = 'Bus', hash = 1766676233 },
        { id = 'phantom', label = 'Phantom truck', hash = 294845476 },
    },
}
