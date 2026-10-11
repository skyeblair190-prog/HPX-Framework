-- Interact target bridge (Codera interact) for ps_lib. Added for the HPX framework (modification of ps_lib, CC BY-NC-SA 4.0, see LICENSE.md).
local ids = {}

local function store(resource, name, id)
    ids[resource] = ids[resource] or {}
    ids[resource][name] = id
end

local function convert(options)
    local compat = {}
    for _, option in pairs(options or {}) do
        compat[#compat + 1] = {
            label = option.label,
            action = option.action or option.onSelect,
            event = option.event,
            canInteract = option.canInteract,
            args = option.data,
        }
    end
    return compat
end

local function addZone(name, location, size, options)
    if not name then return end
    local resource = GetInvokingResource() or GetCurrentResourceName()
    if ids[resource] and ids[resource][name] then exports.interact:RemoveInteraction(ids[resource][name]) end

    size = size or {}
    local reach = math.min(3.0, math.max(1.5, math.max(size.length or 1.0, size.width or 1.0) / 2 + 0.75))
    local id = exports.interact:AddInteraction({
        name = name,
        coords = vector3(location.x, location.y, location.z),
        distance = 8.0,
        interactDst = reach,
        options = convert(options),
    })
    store(resource, name, id)
end

function ps.boxTarget(name, location, size, options) addZone(name, location, size, options) end
function ps.circleTarget(name, location, size, options) addZone(name, location, size, options) end

function ps.entityTarget(entity, options)
    if not entity or entity == 0 then return end
    local resource = GetInvokingResource() or GetCurrentResourceName()
    local id = exports.interact:AddLocalEntityInteraction({
        entity = entity,
        name = ('ps:entity:%s'):format(entity),
        distance = 8.0,
        interactDst = 2.0,
        options = convert(options),
    })
    store(resource, ('entity:%s'):format(entity), id)
end

function ps.targetModel(models, options)
    if type(models) ~= 'table' then models = { models } end
    local modelData = {}
    for _, model in ipairs(models) do
        if type(model) == 'string' then model = joaat(model) end
        modelData[#modelData + 1] = { model = model, offset = vec3(0.0, 0.0, 1.0) }
    end
    exports.interact:AddModelInteraction({
        name = ('ps:model:%s'):format(modelData[1] and modelData[1].model or 'none'),
        modelData = modelData,
        distance = 6.0,
        interactDst = 2.0,
        options = convert(options),
    })
end

local function removeAll(resource)
    for _, id in pairs(ids[resource] or {}) do exports.interact:RemoveInteraction(id) end
    ids[resource] = nil
end

function ps.destroyAllTargets()
    removeAll(GetInvokingResource() or GetCurrentResourceName())
end

function ps.destroyTarget(name)
    local resource = GetInvokingResource() or GetCurrentResourceName()
    local id = ids[resource] and ids[resource][name]
    if not id then return end
    exports.interact:RemoveInteraction(id)
    ids[resource][name] = nil
end

AddEventHandler('onResourceStop', function(resourceName)
    removeAll(resourceName)
end)

exports('boxTarget', ps.boxTarget)
exports('circleTarget', ps.circleTarget)
exports('entityTarget', ps.entityTarget)
exports('targetModel', ps.targetModel)
exports('destroyAllTargets', ps.destroyAllTargets)
exports('destroyTarget', ps.destroyTarget)
ps.success('Target Module Loaded: Interact Target')
