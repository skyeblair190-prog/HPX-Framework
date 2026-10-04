local function license(source)
  return HPXGetLicense(source)
end

lib.callback.register('hpx:characters:list', function(source)
  local rows = MySQL.query.await(
    'SELECT id, citizenid, slot, charinfo, job, gang, phone, last_seen FROM hpx_characters WHERE license = ? ORDER BY slot ASC',
    { license(source) }
  )

  for _, row in ipairs(rows) do
    row.charinfo = json.decode(row.charinfo or '{}') or {}
    row.job = json.decode(row.job or '{}') or {}
    row.gang = json.decode(row.gang or '{}') or {}
  end

  return rows
end)

lib.callback.register('hpx:characters:create', function(source, data)
  if type(data) ~= 'table' then return nil, 'invalid_data' end
  return HPXServer.Character.Create(source, data.slot, data.charinfo)
end)

lib.callback.register('hpx:characters:select', function(source, id)
  return HPXServer.Character.Load(source, id)
end)

lib.callback.register('hpx:characters:delete', function(source, id)
  return HPXServer.Character.Delete(source, id)
end)
