Config = {}

-- Allowed notification types and their aliases (typos included on purpose)
Config.Types = {
    success = 'success',
    sucess  = 'success', -- common typo, mapped for compatibility
    inform  = 'inform',
    info    = 'inform',
    primary = 'inform',
    warning = 'warning',
    warn    = 'warning',
    error   = 'error'
}

Config.DefaultType = 'inform'

-- Duration bounds (ms)
Config.MinDuration     = 500
Config.MaxDuration     = 30000
Config.DefaultDuration = 4000

-- Keybind used by the /notifyall preview command
Config.PreviewKey = 'L'

-- Delay between each notification in the /notifyall preview (ms)
Config.PreviewGap = 1500
