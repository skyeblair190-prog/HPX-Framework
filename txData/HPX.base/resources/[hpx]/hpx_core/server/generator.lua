local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

local function randomString(length)
  local out = {}
  for i = 1, length do
    local index = math.random(1, #alphabet)
    out[i] = alphabet:sub(index, index)
  end
  return table.concat(out)
end

local function randomDigits(length)
  local out = {}
  for i = 1, length do out[i] = tostring(math.random(0, 9)) end
  return table.concat(out)
end

local function unique(prefix, length, query, digitsOnly)
  for _ = 1, 30 do
    local value = prefix .. (digitsOnly and randomDigits(length) or randomString(length))
    if not MySQL.scalar.await(query, { value }) then return value end
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
  return unique('021', 7, 'SELECT 1 FROM hpx_characters WHERE phone = ? LIMIT 1', true)
end

function HPXServer.GenerateFingerprint()
  return randomString(2) .. randomDigits(3) .. randomString(1) .. randomDigits(2)
end

function HPXServer.GenerateWalletId()
  return 'HPX-' .. randomDigits(8)
end
