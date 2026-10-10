function HPXServer.ResolveJob(name, grade, onduty)
  if type(name) ~= 'string' then return nil end
  grade = math.tointeger(tonumber(grade)) or 0

  local definition = HPXConfig.jobs[name]
  if not definition then
    return { name = name, label = name, grade = grade, onduty = onduty == true, payment = 0 }
  end

  local entry = definition.grades[grade]
  if not entry then return nil end

  if onduty == nil then onduty = definition.defaultDuty == true end
  return {
    name = name,
    label = definition.label,
    grade = grade,
    gradelabel = entry.name,
    onduty = onduty == true,
    payment = entry.payment or 0,
    isboss = entry.isboss == true
  }
end

exports('GetJobs', function()
  local list = {}
  for name, definition in pairs(HPXConfig.jobs) do
    local grades = {}
    for grade, entry in pairs(definition.grades) do
      grades[#grades + 1] = { grade = grade, name = entry.name, payment = entry.payment or 0, isboss = entry.isboss == true }
    end
    table.sort(grades, function(a, b) return a.grade < b.grade end)
    list[#list + 1] = { name = name, label = definition.label, grades = grades }
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  return list
end)

RegisterCommand('duty', function(source)
  if source == 0 then return end
  local player = HPXServer.GetPlayer(source)
  local job = player and player.job
  if type(job) ~= 'table' or job.name == 'unemployed' or not HPXConfig.jobs[job.name] then return end

  job.onduty = not job.onduty
  HPXServer.SyncClient(source)
  TriggerEvent('hpx:server:dutyChanged', source, job.onduty)
  lib.notify(source, { type = 'inform', description = job.onduty and 'You are now on duty.' or 'You are now off duty.' })
end, false)

CreateThread(function()
  local config = HPXConfig.paycheck
  if not config.enabled then return end

  while true do
    Wait(config.interval)
    for source, player in pairs(HPXServer.Players) do
      local job = player.job
      local pay = type(job) == 'table' and tonumber(job.payment) or 0
      if pay > 0 and (not config.requireDuty or job.onduty == true) then
        if exports.hpx_core:AddMoney(source, config.account, pay, 'paycheck') then
          lib.notify(source, { type = 'success', description = ('Paycheck received: $%d'):format(pay) })
        end
      end
    end
  end
end)
