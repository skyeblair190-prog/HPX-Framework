-- Admin panel + placement tool.
return {
    Command = 'scootadmin', -- chat command that opens the panel; the ace it grants is command.scootadmin
    Group = 'group.admin', -- ace principal with full access: the command, every read and every change
    ViewGroup = false, -- optional ace principal (e.g. 'group.mod') that can open the panel and look, but not change anything
    EditAce = 'sd_scoot.edit', -- the ace every change needs; granted to Group automatically, add it to other principals to let them edit
    UndoSeconds = 30, -- how long a deleted bunker, station or scooter can be restored from the toast
    ActivityPoints = 400, -- recent ride start/end points the map's activity layer draws
    FlushCommand = 'scootflush', -- after `restart sd_scoot_assets`: every client drops and reloads the SCOOT models, no reconnect
    FlushWaitMs = 8000, -- ms a client waits for the game to report the models unloaded before giving up and rebuilding anyway
    LiftCommand = 'scootlift', -- debug: /scootlift [metres] holds the nearest bunker above ground on your client; run it again with no number to sink it
    CircleCommand = 'scootcircle', -- debug: /scootcircle [radius] parks one scooter of every colour in a ring around you; /scootcircle clear removes the last ring
    CircleRadius = 7.0, -- metres from the caller the ring is drawn at when no radius is given
    DockCommand = 'scootdocks', -- debug: /scootdocks [spacing] lines up one charging station per colour in front of you; /scootdocks clear removes the last line-up
    DockSpacing = 6.0, -- metres between stations along a row; a station is ~4 m wide, so this leaves a walkable gap
    DockPerRow = 5, -- stations per row before the next row starts further back
    DockRowGap = 9.0, -- metres between rows, enough to walk (and ride) down the aisle
    DockAhead = 10.0, -- metres in front of the caller the first row stands
    SizeCommand = 'scootsizes', -- debug: /scootsizes [spacing] lines up one charging station of every dock count, biggest first; /scootsizes clear removes it
    SizeSpacing = 7.0, -- metres between the size samples; the widest station is ~4 m, so this keeps a clear gap
    SizeAhead = 9.0, -- metres in front of the caller the size line stands
    FlushRespawnMs = 12000, -- ms the server waits before respawning the idle fleet; must exceed FlushWaitMs or a respawned scooter re-requests the old model mid-flush
    PlaceReach = 25.0, -- metres ahead of the camera a new placement starts when nothing closer is in view
    Placement = { -- the built-in placement gizmo used for bunkers and charging stations
        SnapMove = 0.25, -- metres per step while snapping is on (G)
        SnapTurn = 15.0, -- degrees per step while snapping is on
        Nudge = 0.05, -- metres per frame the arrow keys / Page Up / Page Down move it (Shift x5)
        TurnStep = 5.0, -- degrees per mouse-wheel notch (Shift + wheel: 15, Ctrl + wheel: 1)
    },
    MapStyle = 'atlas', -- tiles the Map tab opens with: 'atlas' | 'satellite' (the admin can switch)
    PositionsInterval = 3000, -- ms between live scooter position polls while the Map tab is open
}
