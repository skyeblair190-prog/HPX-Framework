---@class FrameworkInfo
---@field name 'hpx'|'qb'|'esx'|'none' Detected framework identifier.
---@field isQbx boolean True when the qb backend is actually Qbox (qbx_core providing qb-core).
---@field core any Live core object, nil when no framework is running.

---Detects which framework is running. Qbox counts as 'qb': qbx_core `provide`s qb-core, so the
---compat core object resolves through the same export. Unlike the sibling resources this does
---NOT error without a framework: bunkers, scooters and the admin panel work without one, and only
---the rental app (money + identifiers) needs it, so the app simply stays unregistered.
---@return FrameworkInfo
local function detect()
    if GetResourceState('hpx_core') == 'started' then
        return { name = 'hpx', isQbx = false, core = exports.hpx_core }
    end
    if GetResourceState('qb-core') == 'started' then
        return { name = 'qb', isQbx = GetResourceState('qbx_core') == 'started', core = exports['qb-core']:GetCoreObject() }
    end
    if GetResourceState('es_extended') == 'started' then
        return { name = 'esx', isQbx = false, core = exports['es_extended']:getSharedObject() }
    end
    return { name = 'none', isQbx = false, core = nil }
end

---@type FrameworkInfo Detected framework descriptor.
local info = detect()

return info
