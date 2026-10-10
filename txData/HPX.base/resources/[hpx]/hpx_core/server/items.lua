local usable = {}

function HPXServer.CreateUsableItem(name, cb)
  if type(name) ~= 'string' or #name == 0 or #name > 64 or cb == nil then return false end
  usable[name] = cb
  return true
end

function HPXServer.CanUseItem(name)
  return type(name) == 'string' and usable[name] or nil
end

function HPXServer.IsGradeBoss(group, grade)
  if type(group) ~= 'string' then return false end
  local definition = HPXConfig.jobs[group] or HPXConfig.gangs[group]
  local grades = definition and definition.grades
  local entry = grades and (grades[grade] or grades[tostring(grade)])
  return entry ~= nil and entry.isboss == true
end
