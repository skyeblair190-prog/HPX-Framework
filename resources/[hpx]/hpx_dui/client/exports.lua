local function summary(surface)
    if not surface then return nil end
    return {
        id = surface.id,
        txd = surface.txd,
        txn = surface.txn,
        width = surface.width,
        height = surface.height,
        url = surface.url
    }
end

exports('Create', function(data)
    return summary(HPXDUI.Create(data))
end)

exports('Destroy', function(id)
    return HPXDUI.Destroy(id)
end)

exports('Send', function(id, message)
    return HPXDUI.Send(id, message)
end)

exports('SetUrl', function(id, url)
    return HPXDUI.SetUrl(id, url)
end)

exports('GetTexture', function(id)
    return HPXDUI.GetTexture(id)
end)

exports('Get', function(id)
    return summary(HPXDUI.Get(id))
end)
