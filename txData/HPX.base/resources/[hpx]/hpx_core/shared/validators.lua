HPXValidate = {}

function HPXValidate.source(source)
  return type(source) == 'number' and source > 0 and GetPlayerName(source) ~= nil
end

function HPXValidate.moneyType(kind)
  return type(kind) == 'string' and HPXConstants.moneyTypes[kind] == true
end

function HPXValidate.amount(amount)
  amount = tonumber(amount)
  return amount ~= nil and amount > 0 and amount <= HPXConfig.security.maxMoneyDelta
end

function HPXValidate.text(value, max)
  return type(value) == 'string' and #value > 0 and #value <= (max or 128)
end
