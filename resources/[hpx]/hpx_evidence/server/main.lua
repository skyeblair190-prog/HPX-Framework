local function player(source) return exports.hpx_core:GetPlayer(source) end

lib.callback.register('hpx:evidence:create', function(source, data)
  local p = player(source)
  if not p or type(data) ~= 'table' then return nil end
  local id = MySQL.insert.await(
    'INSERT INTO hpx_evidence (character_id, type, label, data) VALUES (?, ?, ?, ?)',
    { p.charid, tostring(data.type or 'unknown'), tostring(data.label or 'Evidence'), json.encode(data) }
  )
  return id
end)

lib.callback.register('hpx:evidence:list', function(source)
  local p = player(source)
  if not p then return {} end
  return MySQL.query.await(
    'SELECT id, type, label, data, created_at FROM hpx_evidence WHERE character_id = ? ORDER BY id DESC LIMIT 100',
    { p.charid }
  )
end)
