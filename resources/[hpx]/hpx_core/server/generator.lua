local function unique(prefix, length, query, params)
  for _ = 1, 20 do
    local value = prefix .. lib.string.random(length, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789')
    if not MySQL.scalar.await(query, params and table.unpack(params) or { value }) then
      return value
    end
  end
  error('HPX failed to generate a unique identifier')
end

function HPXServer.GenerateCitizenId()
  return unique('HPX', 8, 'SELECT 1 FROM hpx_characters WHERE citizenid = ? LIMIT 1')
end

function HPXServer.GenerateAccountNumber()
  return unique('HPX', 10, 'SELECT 1 FROM hpx_accounts WHERE account_number = ? LIMIT 1')
end

function HPXServer.GeneratePhoneNumber()
  return unique('021', 7, 'SELECT 1 FROM hpx_characters WHERE phone = ? LIMIT 1')
end
