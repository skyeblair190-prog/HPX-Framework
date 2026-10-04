HPXServer.Money = {}

function HPXServer.Money.Change(source, kind, delta, reason)
  local player = HPXServer.GetPlayer(source)
  if not player or not HPXValidate.moneyType(kind) then return false end
  delta = tonumber(delta)
  if not delta or math.abs(delta) > HPXConfig.security.maxMoneyDelta then return false end

  local old = tonumber(player.money[kind]) or 0
  local new = old + delta
  if new < 0 then return false end

  player.money[kind] = HPX.round(new, 2)

  local ok = MySQL.update.await(
    'UPDATE hpx_characters SET money = ? WHERE id = ? AND license = ?',
    { json.encode(player.money), player.charid, player.license }
  )

  if ok ~= 1 then
    player.money[kind] = old
    return false
  end

  TriggerEvent('hpx:server:moneyChanged', source, kind, player.money[kind], delta, reason)
  return true
end

function HPXServer.Money.Get(source, kind)
  local player = HPXServer.GetPlayer(source)
  if not player then return nil end
  return kind and player.money[kind] or player.money
end
