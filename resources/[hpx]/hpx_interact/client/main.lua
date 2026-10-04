HPXInteract = HPXInteract or {}

function HPXInteract.AddModelInteraction(data)
  if GetResourceState('interact') ~= 'started' then
    error('HPX requires the interact resource to be started')
  end
  return exports.interact:AddModelInteraction(data)
end

function HPXInteract.AddInteraction(data)
  return exports.interact:AddInteraction(data)
end

function HPXInteract.RemoveModelInteraction(name)
  if exports.interact.RemoveModelInteraction then
    return exports.interact:RemoveModelInteraction(name)
  end
  return false
end

exports('AddModelInteraction', HPXInteract.AddModelInteraction)
exports('AddInteraction', HPXInteract.AddInteraction)
exports('RemoveModelInteraction', HPXInteract.RemoveModelInteraction)
