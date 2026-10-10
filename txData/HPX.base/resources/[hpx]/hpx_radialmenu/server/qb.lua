QBCore = { Functions = {}, Commands = {} }

function QBCore.Functions.CreateCallback(name, handler)
  lib.callback.register(name, function(source, ...)
    local p = promise.new()
    handler(source, function(result) p:resolve(result) end, ...)
    return Citizen.Await(p)
  end)
end

function QBCore.Commands.Add(name, _, _, _, handler)
  RegisterCommand(name, function(source, args) handler(source, args) end, false)
end
