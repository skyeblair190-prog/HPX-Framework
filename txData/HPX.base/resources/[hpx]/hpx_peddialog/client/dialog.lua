local active = nil
local cam = nil
local playerHidden = false
local session = 0
local destroyDialogCam
local rpcId = 0
local rpcWait = {}

local rpc = function(name, payload)
    rpcId = rpcId + 1
    local id = rpcId
    local pending = promise.new()
    rpcWait[id] = pending
    TriggerServerEvent('hpx_peddialog:rpc', id, name, payload or {})
    return Citizen.Await(pending)
end

RegisterNetEvent('hpx_peddialog:rpc:res', function(id, result)
    local pending = rpcWait[id]
    if not pending then return end
    rpcWait[id] = nil
    pending:resolve(result)
end)

local notify = function(description, ntype)
    if GetResourceState('hpx_notify') == 'started' then
        local ok = pcall(function()
            exports.hpx_notify:Notify(description, ntype or 'inform', 5000)
        end)
        if ok then return end
    end
    if GetResourceState('ox_lib') == 'started' then
        local ok = pcall(function()
            exports.ox_lib:notify({ description = description, type = ntype or 'inform' })
        end)
        if ok then return end
    end
    if GetResourceState('es_extended') == 'started' then
        local ok = pcall(function()
            exports['es_extended']:getSharedObject().ShowNotification(description)
        end)
        if ok then return end
    end
    if GetResourceState('qb-core') == 'started' then
        local ok = pcall(function()
            exports['qb-core']:GetCoreObject().Functions.Notify(description, ntype or 'primary')
        end)
        if ok then return end
    end
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(description)
    EndTextCommandThefeedPostTicker(false, false)
end

local TALK_DICT = 'missfbi3_party_d'
local TALK_ANIM = 'stand_talk_loop_a_male1'

local requestAnimDict = function(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 4000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

local showLocalPlayer = function(player)
    if not playerHidden then return end
    playerHidden = false
    SetEntityVisible(player, true, false)
    SetPedAoBlobRendering(player, true)
end

local stopNpcTalk = function(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    StopCurrentPlayingAmbientSpeech(ped)
    ClearPedTasks(ped)
end

local startNpcTalk = function(ped, player)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    TaskLookAtEntity(ped, player, -1, 2048, 3)
    CreateThread(function()
        if not requestAnimDict(TALK_DICT) then return end
        if not active or active.ped ~= ped or not DoesEntityExist(ped) then return end
        TaskPlayAnim(ped, TALK_DICT, TALK_ANIM, 2.0, 2.0, -1, 49, 0.0, false, false, false)
        PlayPedAmbientSpeechNative(ped, 'GENERIC_HI', 'SPEECH_PARAMS_FORCE_NORMAL')
    end)
end

local createDialogCam = function(ped, player)
    destroyDialogCam()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    player = (player and player ~= 0) and player or PlayerPedId()
    local npcPos = GetEntityCoords(ped)
    local plyPos = GetEntityCoords(player)
    if active and not active.pedHeading then
        active.pedHeading = GetEntityHeading(ped)
    end
    SetEntityHeading(player, GetHeadingFromVector_2d(npcPos.x - plyPos.x, npcPos.y - plyPos.y))
    SetEntityHeading(ped, GetHeadingFromVector_2d(plyPos.x - npcPos.x, plyPos.y - npcPos.y))
    TaskLookAtEntity(player, ped, -1, 2048, 3)
    TaskLookAtEntity(ped, player, -1, 2048, 3)
    local camPos = GetOffsetFromEntityInWorldCoords(player, -0.42, -1.05, 0.58)
    SetFocusPosAndVel((plyPos.x + npcPos.x) * 0.5, (plyPos.y + npcPos.y) * 0.5, (plyPos.z + npcPos.z) * 0.5, 0.0, 0.0, 0.0)
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    PointCamAtEntity(cam, ped, 0.0, 0.0, 0.45, true)
    SetCamFov(cam, 38.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 650, true, false)
end

destroyDialogCam = function()
    if not cam then
        ClearFocus()
        return
    end
    RenderScriptCams(false, true, 450, true, false)
    SetCamActive(cam, false)
    DestroyCam(cam, false)
    cam = nil
    ClearFocus()
end

local pushDialogUi = function()
    if not active then return end
    local labels = {}
    local options = active.options
    for i = 1, #options do
        labels[i] = options[i].label
    end
    local hints = Config.Hints
    SendNUIMessage({
        action = 'openPedDialog',
        data = {
            name = active.name,
            role = active.role,
            text = active.text,
            options = labels,
            selected = active.selected,
            hints = {
                move = hints.move,
                select = hints.select,
                back = hints.back,
            },
            version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '',
        },
    })
end

local pushSelection = function()
    if not active then return end
    SendNUIMessage({
        action = 'pedDialogSelect',
        data = { selected = active.selected },
    })
end

local snapshot = function()
    return {
        name = active.name,
        role = active.role,
        text = active.text,
        options = active.options,
    }
end

local applyScreen = function(data)
    if data.name ~= nil then active.name = data.name end
    if data.role ~= nil then active.role = data.role end
    if data.text ~= nil then active.text = data.text end
    if data.options then
        active.options = data.options
        active.selected = 1
    end
    if data.nodes ~= nil then active.nodes = data.nodes end
    pushDialogUi()
end

local playClip = function(ped, dict, clip, flag)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    if not dict or dict == '' or not clip or clip == '' then return end
    if not requestAnimDict(dict) then return end
    TaskPlayAnim(ped, dict, clip, 2.0, 2.0, -1, flag or 1, 0.0, false, false, false)
end

local playScene = function(ped, player, scene)
    if not scene or not scene.dict then return end
    playClip(ped, scene.dict, scene.ped or scene.name, scene.flag or 1)
    if scene.player and scene.player ~= '' then
        TaskTurnPedToFaceEntity(player, ped, 800)
        playClip(player, scene.dict, scene.player, scene.flag or 1)
    end
end

local closeDialog = function()
    if not active then return end
    local npc = active.ped
    local pedId = active.pedId
    local idle = active.anim
    local face = active.pedHeading
    active = nil
    local player = PlayerPedId()
    FreezeEntityPosition(player, false)
    ClearPedTasks(player)
    stopNpcTalk(npc)
    if face and npc and npc ~= 0 and DoesEntityExist(npc) then
        SetEntityHeading(npc, face)
    end
    if idle and npc and npc ~= 0 and DoesEntityExist(npc) then
        playClip(npc, idle.dict, idle.name or idle.clip, idle.flag or 1)
    end
    showLocalPlayer(player)
    destroyDialogCam()
    DisplayRadar(true)
    ClearFocus()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeClerkShop', data = {} })
    SendNUIMessage({ action = 'closePedDialog', data = {} })
    TriggerEvent('hpx_peddialog:closed', pedId)
end

local popHistory = function()
    if not active then return false end
    local history = active.history
    local prev = history[#history]
    if not prev then return false end
    history[#history] = nil
    active.name = prev.name
    active.role = prev.role
    active.text = prev.text
    active.options = prev.options
    active.selected = 1
    pushDialogUi()
    return true
end

local fireOption = function(pedId, opt)
    TriggerEvent('hpx_peddialog:option', pedId, opt.id)
    local clientEvent = opt.client or opt.event
    if type(clientEvent) == 'string' and clientEvent ~= '' then
        TriggerEvent(clientEvent, pedId, opt.id)
    end
end

local optionFailed = function(res)
    local reason = res and res.reason
    if reason == 'money' then
        notify('Not enough money', 'error')
    elseif reason == 'inventory' then
        notify('Could not move that item', 'error')
    elseif reason == 'far' then
        notify('Too far', 'error')
    else
        notify('Could not do that', 'error')
    end
end

local openShopUi = function()
    if not active or type(active.shop) ~= 'table' then return end
    local shop = active.shop
    local items = shop.items or {}
    local nuiItems = {}
    for i = 1, #items do
        local it = items[i]
        nuiItems[i] = {
            slot = i,
            name = it.item,
            label = it.label or it.item,
            price = tonumber(it.price) or 0,
            count = tonumber(it.stock) or 99,
            category = it.category,
            image = it.image,
        }
    end
    local address = shop.address
    if type(address) ~= 'table' then
        address = { 'UNKNOWN STREET', 'SAN ANDREAS' }
    end
    SendNUIMessage({
        action = 'openClerkShop',
        data = {
            label = shop.label or active.name or 'SHOP',
            address = { address[1] or 'UNKNOWN STREET', address[2] or 'SAN ANDREAS' },
            tax = tonumber(shop.tax) or 0,
            moneyType = shop.moneyType or 'cash',
            version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '',
            items = nuiItems,
        },
    })
end

local confirmSelected = function()
    if not active then return end
    local opt = active.options[active.selected]
    if not opt then return end
    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    local hasServer = type(opt.fn) == 'function' or (type(opt.server) == 'string' and opt.server ~= '')
    if hasServer then
        local res = rpc('option', { pedId = active.pedId, optionId = opt.id })
        if type(res) ~= 'table' or not res.success then
            optionFailed(res)
            return
        end
        notify('Done', 'success')
    end
    if opt.id == 'shop' and active.shop then
        openShopUi()
        return
    end
    if opt.next and active.nodes and active.nodes[opt.next] then
        local node = active.nodes[opt.next]
        active.history[#active.history + 1] = snapshot()
        applyScreen({
            name = node.name,
            role = node.role,
            text = node.text,
            options = node.options,
        })
        return
    end
    if opt.back then
        if popHistory() then return end
        closeDialog()
        return
    end
    local pedId = active.pedId
    if opt.keepOpen then
        fireOption(pedId, opt)
        return
    end
    closeDialog()
    fireOption(pedId, opt)
end

local handleBack = function()
    PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    if popHistory() then return end
    closeDialog()
end

local openDialog = function(data)
    session = session + 1
    local token = session
    if active then
        closeDialog()
    end
    if not data or not data.options or #data.options == 0 then return end
    local player = PlayerPedId()
    local target = data.ped
    active = {
        ped = target,
        pedId = data.pedId,
        name = data.name or '',
        role = data.role or '',
        text = data.text or '',
        options = data.options,
        nodes = data.nodes,
        shop = data.shop,
        anim = data.anim,
        scene = data.scene,
        history = {},
        selected = 1,
    }
    FreezeEntityPosition(player, true)
    local scene = data.scene
    if target and target ~= 0 and DoesEntityExist(target) then
        if scene and scene.dict and scene.dict ~= '' then
            playScene(target, player, scene)
        else
            startNpcTalk(target, player)
        end
        CreateThread(function()
            Wait(120)
            if session == token and active and active.ped == target then
                createDialogCam(target, player)
            end
        end)
    end
    SetNuiFocus(true, true)
    pushDialogUi()
    DisplayRadar(false)
    CreateThread(function()
        while active and session == token do
            HideHudAndRadarThisFrame()
            DisplayRadar(false)
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 32, true)
            DisableControlAction(0, 33, true)
            DisableControlAction(0, 34, true)
            DisableControlAction(0, 35, true)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)
            if active and active.ped and active.ped ~= 0 and not DoesEntityExist(active.ped) then
                closeDialog()
                break
            end
            Wait(0)
        end
        if session == token then
            DisplayRadar(true)
        end
    end)
end

local updateDialog = function(data)
    if not active or not data then return false end
    if data.pushHistory then
        active.history[#active.history + 1] = snapshot()
    end
    applyScreen(data)
    return true
end

exports('Open', function(data)
    openDialog(data)
end)

RegisterNetEvent('hpx_peddialog:open', function(data)
    openDialog(data)
end)

RegisterNetEvent('hpx_peddialog:update', function(data)
    updateDialog(data)
end)

RegisterNetEvent('hpx_peddialog:close', function()
    closeDialog()
end)

RegisterNUICallback('pedDialogHover', function(data, cb)
    if not active then
        cb({ ok = false })
        return
    end
    local idx = tonumber(data and data.index) or 0
    if idx >= 1 and idx <= #active.options then
        active.selected = idx
        pushSelection()
    end
    cb({ ok = true })
end)

RegisterNUICallback('pedDialogConfirm', function(data, cb)
    if not active then
        cb({ ok = false })
        return
    end
    local idx = tonumber(data and data.index)
    if idx and idx >= 1 and idx <= #active.options then
        active.selected = idx
    end
    confirmSelected()
    cb({ ok = true })
end)

RegisterNUICallback('pedDialogNav', function(data, cb)
    if not active then
        cb({ ok = false })
        return
    end
    local dir = data and data.dir
    if dir == 'up' then
        active.selected = active.selected - 1
        if active.selected < 1 then
            active.selected = #active.options
        end
        pushSelection()
        PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    elseif dir == 'down' then
        active.selected = active.selected + 1
        if active.selected > #active.options then
            active.selected = 1
        end
        pushSelection()
        PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    elseif dir == 'confirm' then
        confirmSelected()
    elseif dir == 'back' then
        handleBack()
    end
    cb({ ok = true })
end)

RegisterNUICallback('pedDialogClose', function(_, cb)
    if active then
        PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        closeDialog()
    end
    cb({ ok = true })
end)

RegisterNUICallback('clerkShopClose', function(_, cb)
    cb({ ok = true })
end)

RegisterNUICallback('clerkShopCheckout', function(data, cb)
    if not active or not active.pedId then
        cb({ success = false, reason = 'closed' })
        return
    end
    local res = rpc('buyShop', {
        pedId = active.pedId,
        items = data and data.items,
        payment = data and data.payment,
    })
    if type(res) ~= 'table' then
        res = { success = false }
    end
    if res.success then
        notify('Purchase complete', 'success')
    elseif res.reason == 'money' then
        notify('Not enough money', 'error')
    elseif res.reason == 'inventory' then
        notify('Not enough inventory space', 'error')
    else
        notify('Could not buy that', 'error')
    end
    cb(res)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if active then
        closeDialog()
    end
end)
