HPXDatabase = {}

function HPXDatabase.prepare(query, params)
  return MySQL.prepare.await(query, params or {})
end

function HPXDatabase.single(query, params)
  return MySQL.single.await(query, params or {})
end

function HPXDatabase.query(query, params)
  return MySQL.query.await(query, params or {})
end

function HPXDatabase.update(query, params)
  return MySQL.update.await(query, params or {})
end

function HPXDatabase.insert(query, params)
  return MySQL.insert.await(query, params or {})
end

function HPXDatabase.transaction(queries)
  return MySQL.transaction.await(queries)
end

function HPXDatabase.ensureColumn(tableName, column, definition)
  local exists = MySQL.scalar.await(
    'SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
    { tableName, column }
  )
  if (tonumber(exists) or 0) == 0 then
    MySQL.query.await(('ALTER TABLE %s ADD COLUMN %s %s'):format(tableName, column, definition))
  end
end
