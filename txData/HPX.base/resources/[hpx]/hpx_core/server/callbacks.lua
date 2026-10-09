local callbacks = {}

function HPXServer.RegisterCallback(name, handler)
  assert(type(name) == 'string' and type(handler) == 'function', 'invalid HPX callback')
  callbacks[name] = handler
end

lib.callback.register('hpx:core:invoke', function(source, name, ...)
  local handler = callbacks[name]
  if not handler then return nil, 'callback_not_found' end
  local packed = {...}
  if #json.encode(packed) > HPXConfig.security.maxCallbackPayload then return nil, 'payload_too_large' end
  return handler(source, table.unpack(packed))
end)
