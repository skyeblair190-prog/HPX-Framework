local PlayerMethods = {}

function PlayerMethods:GetSource() return self.source end
function PlayerMethods:GetCharacterId() return self.charid end
function PlayerMethods:GetCitizenId() return self.citizenid end
function PlayerMethods:GetName()
  local c = self.charinfo or {}
  return (('%s %s'):format(c.firstname or '', c.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
end
function PlayerMethods:GetJob() return self.job end
function PlayerMethods:GetGang() return self.gang end
function PlayerMethods:GetMetadata(key) return key and self.metadata[key] or self.metadata end
function PlayerMethods:SetMetadata(key, value)
  if type(key) ~= 'string' then return false end
  self.metadata[key] = value
  return true
end
function PlayerMethods:GetMoney(kind) return self.money[kind] or 0 end
function PlayerMethods:SetMoney(kind, amount)
  if not HPXValidate.moneyType(kind) then return false end
  amount = tonumber(amount)
  if not amount or amount < 0 then return false end
  self.money[kind] = HPX.round(amount, 2)
  return true
end
function PlayerMethods:AddMoney(kind, amount, reason)
  return HPXServer.Money.Change(self.source, kind, amount, reason or 'unknown')
end
function PlayerMethods:RemoveMoney(kind, amount, reason)
  return HPXServer.Money.Change(self.source, kind, -amount, reason or 'unknown')
end
function PlayerMethods:SetJob(job, grade)
  return HPXServer.Character.SetJob(self.source, job, grade)
end
function PlayerMethods:SetGang(gang, grade)
  return HPXServer.Character.SetGang(self.source, gang, grade)
end
function PlayerMethods:Save()
  return HPXServer.Character.Save(self.source)
end
function PlayerMethods:Drop(reason)
  DropPlayer(self.source, reason or 'Disconnected')
end

function HPXServer.BuildPlayer(source, row)
  local player = {
    source = source,
    license = row.license,
    charid = row.id,
    citizenid = row.citizenid,
    charinfo = row.charinfo or {},
    money = row.money or HPX.copy(HPXConfig.character.defaultMoney),
    job = row.job or HPX.copy(HPXConfig.character.defaultJob),
    gang = row.gang or HPX.copy(HPXConfig.character.defaultGang),
    metadata = row.metadata or {},
    position = row.position,
    state = {},
    permission = tonumber(row.permission) or 0
  }
  return setmetatable(player, { __index = PlayerMethods })
end
