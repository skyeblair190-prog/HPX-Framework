HPXDB = HPXDB or {}

function HPXDB.Single(query, params) return MySQL.single.await(query, params or {}) end
function HPXDB.Query(query, params) return MySQL.query.await(query, params or {}) end
function HPXDB.Update(query, params) return MySQL.update.await(query, params or {}) end
function HPXDB.Insert(query, params) return MySQL.insert.await(query, params or {}) end
function HPXDB.Transaction(queries) return MySQL.transaction.await(queries) end

exports('Single', HPXDB.Single)
exports('Query', HPXDB.Query)
exports('Update', HPXDB.Update)
exports('Insert', HPXDB.Insert)
exports('Transaction', HPXDB.Transaction)
