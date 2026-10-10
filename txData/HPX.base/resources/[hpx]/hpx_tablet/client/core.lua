CoderaClient = {}

function CoderaClient.Notify(message, kind)
  exports.hpx_notify:Notify(message, kind)
end

function CoderaClient.TriggerCallback(name, cb, ...)
  local args = { ... }
  CreateThread(function() cb(lib.callback.await(name, false, table.unpack(args))) end)
end
