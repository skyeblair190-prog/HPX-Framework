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
