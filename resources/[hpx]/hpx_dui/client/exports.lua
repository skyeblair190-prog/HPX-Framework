exports('Create', function(data)
    return HPXDUI.Create(data)
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
    return HPXDUI.Get(id)
end)
