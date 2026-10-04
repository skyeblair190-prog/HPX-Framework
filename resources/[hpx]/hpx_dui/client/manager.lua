HPXDUI = HPXDUI or {}

local surfaces = {}
local nextId = 0

local function encode(data)
    return json.encode(data or {})
end

local function createSurface(data)
    nextId += 1

    local id = ('hpx_dui_%s'):format(nextId)
    local width = math.max(256, math.floor(data.width or 1024))
    local height = math.max(256, math.floor(data.height or 768))
    local url = data.url or ('https://cfx-nui-%s/web/index.html'):format(GetCurrentResourceName())

    local dui = CreateDui(url, width, height)
    if not dui then return nil end

    local handle = GetDuiHandle(dui)
    if not handle then
        DestroyDui(dui)
        return nil
    end

    local txdName = id
    local txnName = id .. '_tx'
    local txd = CreateRuntimeTxd(txdName)
    CreateRuntimeTextureFromDuiHandle(txd, txnName, handle)

    surfaces[id] = {
        id = id,
        dui = dui,
        handle = handle,
        txd = txdName,
        txn = txnName,
        width = width,
        height = height,
        url = url
    }

    if data.message then
        SendDuiMessage(dui, encode(data.message))
    end

    return surfaces[id]
end

local function destroySurface(id)
    local surface = surfaces[id]
    if not surface then return false end

    if surface.dui then
        DestroyDui(surface.dui)
    end

    surfaces[id] = nil
    return true
end

function HPXDUI.Create(data)
    assert(type(data) == 'table', 'HPXDUI.Create expects a table')
    return createSurface(data)
end

function HPXDUI.Destroy(id)
    return destroySurface(id)
end

function HPXDUI.Send(id, message)
    local surface = surfaces[id]
    if not surface or not surface.dui then return false end

    SendDuiMessage(surface.dui, encode(message))
    return true
end

function HPXDUI.SetUrl(id, url)
    local surface = surfaces[id]
    if not surface or not surface.dui or type(url) ~= 'string' then return false end

    SetDuiUrl(surface.dui, url)
    surface.url = url
    return true
end

function HPXDUI.Get(id)
    return surfaces[id]
end

function HPXDUI.GetTexture(id)
    local surface = surfaces[id]
    if not surface then return nil end
    return surface.txd, surface.txn
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for id in pairs(surfaces) do
        destroySurface(id)
    end
end)
