---Local cosmetic props use replicated options; no network object per accessory.
local extras = require 'shared.extras'
local fleet = require 'client.scoot.fleet'
local models = json.decode(LoadResourceFile(GetCurrentResourceName(), 'configs/attachment-models.json'))
local MODEL = joaat('sd_scoot')
local entries, requested, running = {}, {}, true
local colours = {}; for _,item in ipairs(extras.catalog.lighting) do if item.hex then colours[item.id]={tonumber(item.hex:sub(2,3),16),tonumber(item.hex:sub(4,5),16),tonumber(item.hex:sub(6,7),16)} end end

---Map decoded customization options to the accessory prop keys a scooter should carry.
---@param c table decoded options { rear, trim, lighting }
---@return table<string, boolean> prop key -> wanted
local function wanted(c)
    local out = {}
    if c.rear ~= 'none' then out.rack=true end
    if c.rear == 'delivery' then out[c.box and c.box ~= 'stock' and ('delivery_'..c.box) or 'delivery']=true end
    if c.trim ~= 'stock' then for _,part in ipairs({'grip','deck','front','rear'}) do out['trim_'..c.trim..'_'..part]=true end end
    if c.lighting ~= 'off' then out['light_'..c.lighting]=true end
    return out
end
---Delete every accessory prop on a scooter and forget its entry.
---@param v integer vehicle handle
local function remove(v)
    local e=entries[v];if not e then return end
    for _,obj in pairs(e.objects) do if DoesEntityExist(obj) then DeleteEntity(obj) end end
    entries[v]=nil
end
---True when the scooter is not drawn or is mid-dispense, so its accessories should hide.
---@param v integer vehicle handle
---@return boolean
local function hidden(v)
    return not IsEntityVisible(v) or GetEntityAlpha(v)==0 or IsEntityAttached(v)
        or not IsVehicleExtraTurnedOn(v,1) or Entity(v).state.sd_scoot_dispense
end
---Create one accessory prop and attach it to its bone. Requests the model first and returns nothing until it loads.
---@param v integer vehicle handle
---@param key string attachment-models.json key
---@return integer|nil object handle
local function spawn(v,key)
    local m=models[key];if not m then return end
    local hash=joaat(m.model)
    if not HasModelLoaded(hash) then RequestModel(hash);requested[hash]=true;return end
    local bone=GetEntityBoneIndexByName(v,m.bone);if bone<0 and m.bone~='chassis' then return end
    local p=GetEntityCoords(v);local obj=CreateObjectNoOffset(hash,p.x,p.y,p.z,false,false,false)
    if obj==0 then return end
    SetEntityAsMissionEntity(obj,true,true);SetEntityCollision(obj,false,false);SetEntityInvincible(obj,true);SetEntityLodDist(obj,45)
    AttachEntityToEntity(obj,v,bone,0.0,0.0,0.0,0.0,0.0,0.0,false,false,false,false,2,true)
    return obj
end
---A scooter's accessories only change when it is customised, so once its props stand they are
---re-validated (state bag decode, prop checks) every REFRESH_MS; the scan in between is a distance
---check. Visibility flips are handled by the draw loop below within CHECK_MS.
local REFRESH_MS=2000
---Streaming: keeps accessory props in sync with each nearby scooter's customization and removes those out of range, releasing unused models. Runs every 500 ms with a scooter near, 1 s otherwise.
CreateThread(function()
    while running do
        local now=GetGameTimer()
        local p,keep,needed=GetEntityCoords(PlayerPedId()),{},{}
        for _,v in ipairs(fleet.list()) do
            if GetEntityModel(v)==MODEL and #(GetEntityCoords(v)-p)<35.0 then
                local e=entries[v]
                if e and now<(e.refreshAt or 0) then
                    keep[v]=true
                    for hash in pairs(e.needed) do needed[hash]=true end
                else
                    local state=Entity(v).state.sd_scoot
                    if state and not hidden(v) then
                        keep[v]=true
                        if e and e.id~=state.id then remove(v);e=nil end
                        if not e then e={id=state.id,objects={}};entries[v]=e end
                        e.options=extras.decode(state.customization)
                        local desired=wanted(e.options)
                        for key,obj in pairs(e.objects) do
                            if not desired[key] or not DoesEntityExist(obj) or not IsEntityAttachedToEntity(obj,v) then
                                if DoesEntityExist(obj) then DeleteEntity(obj) end;e.objects[key]=nil
                            end
                        end
                        local complete=true
                        e.needed={}
                        for key in pairs(desired) do
                            if models[key] then local h=joaat(models[key].model);needed[h]=true;e.needed[h]=true end
                            if not e.objects[key] then e.objects[key]=spawn(v,key) end
                            if models[key] and not e.objects[key] then complete=false end
                        end
                        e.refreshAt=complete and now+REFRESH_MS or 0
                    end
                end
            end
        end
        for v in pairs(entries) do if not keep[v] then remove(v) end end
        for hash in pairs(requested) do if not needed[hash] then SetModelAsNoLongerNeeded(hash);requested[hash]=nil end end
        Wait(fleet.any() and 500 or 1000)
    end
end)
---Underglow is the only thing drawn per frame. The visibility/state-bag checks and engine state are
---refreshed a few times a second; the light itself only while the engine runs and the scooter is on screen.
local CHECK_MS=150
---Underglow and visibility: syncs prop visibility and engine state every CHECK_MS and draws the underglow light for running on-screen scooters. Every frame while a light is drawn, 100 ms with props, 1 s with none.
CreateThread(function()
    while running do
        local now=GetGameTimer()
        local camera=GetFinalRenderedCamCoord()
        local drew=false
        for v,e in pairs(entries) do
            if now>=(e.checkAt or 0) then
                e.checkAt=now+CHECK_MS
                e.exists=GetEntityModel(v)==MODEL
                local invisible=not e.exists or not not hidden(v)
                if invisible~=e.hidden then
                    for _,obj in pairs(e.objects) do if DoesEntityExist(obj) then SetEntityVisible(obj,not invisible,false) end end
                    e.hidden=invisible
                end
                e.running=e.exists and GetIsVehicleEngineRunning(v)
            end
            if e.exists and not e.hidden then
                local c=e.options
                local light=colours[c.lighting]
                if light and e.running and IsEntityOnScreen(v) then
                    local distance=#(GetEntityCoords(v)-camera)
                    if distance<22.0 and math.abs(GetEntityRoll(v))<45.0 then
                        local p=GetOffsetFromEntityInWorldCoords(v,0.0,-.025,-.29)
                        DrawLightWithRange(p.x,p.y,p.z,light[1],light[2],light[3],1.2,1.1)
                        drew=true
                    end
                end
            end
        end
        Wait(drew and 0 or (next(entries) and 100 or 1000))
    end
end)
---Delete every accessory prop and release the models when this resource stops.
AddEventHandler('onResourceStop',function(name)
    if name~=GetCurrentResourceName() then return end
    running=false;for v in pairs(entries) do remove(v) end
    for hash in pairs(requested) do SetModelAsNoLongerNeeded(hash) end
end)
---Dress a scooter the streaming loop skips (the bunker's local dispense copy is attached and has no
---state bag) with the accessory props of one customization. Requests models, so call it in a thread.
---@param v integer vehicle handle
---@param customization table|string|nil
---@return table<string, integer> objects prop key -> handle
local function dress(v, customization)
    local objects = {}
    if not DoesEntityExist(v) then return objects end
    for key in pairs(wanted(extras.decode(customization))) do
        local m = models[key]
        if m and lib.requestModel(joaat(m.model), 3000) then
            requested[joaat(m.model)] = true
            local obj = spawn(v, key)
            if obj then objects[key] = obj end
        end
    end
    return objects
end

---Delete the props `dress` created.
---@param objects table<string, integer>|nil
local function undress(objects)
    for _, obj in pairs(objects or {}) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
end

---Module export: the options-to-props mapper and the one-off dressing helpers.
package.preload['client.scoot.extras'] = function() return { wanted=wanted, dress=dress, undress=undress } end
