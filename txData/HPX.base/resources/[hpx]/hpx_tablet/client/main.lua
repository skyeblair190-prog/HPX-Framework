
local isPlayingTabletAnim = false
local isTabletOpen = false

local ANIM_DICT = "amb@code_human_in_bus_passenger_idles@female@tablet@base"
local ANIM_NAME = "base"
local TABLET_MODEL = "prop_cs_tablet"
local ATTACH_BONE = 60309

local ATTACH_OFFSET = vector3(0.03, 0.002, -0.0)
local ATTACH_ROTATION = vector3(10.0, 160.0, 0.0)


RegisterNetEvent("codera-tablet:openTablet")
AddEventHandler("codera-tablet:openTablet", function()
    SetNuiFocus(true, true)
    ToggleTablet(true)

    local savedBackground = GetResourceKvpString("coderaTabletBG")

    SendNUIMessage({
        type = "showTabletUI",
        bG = savedBackground,
    })

    isTabletOpen = true
end)


RegisterNUICallback("codera-tablet:saveSettings", function(data, cb)
    if data.bg then
        SetResourceKvp("coderaTabletBG", data.bg)

        SetNuiFocus(false, false)
        ToggleTablet(false)

        SavedSettings()

        SendNUIMessage({
            type = "hideTabletUI",
        })

        isTabletOpen = false
    end

    if cb then cb('ok') end
end)

RegisterNetEvent("codera-tablet:Notify")
AddEventHandler("codera-tablet:Notify", function(title, description, imgSrc, duration)
    SendNUIMessage({
        type = "notify",
        title = title,
        description = description,
        imgSrc = imgSrc,
        duration = duration,
    })
end)


RegisterNetEvent("codera-tablet:fB")
AddEventHandler("codera-tablet:fB", function()
    if isTabletOpen then
        SetNuiFocus(true, true)
    end
end)

RegisterNetEvent("codera-tablet:fB2")
AddEventHandler("codera-tablet:fB2", function()
    if isTabletOpen then
        SetNuiFocus(true, true)
    end
end)


RegisterNUICallback("hideTab", function(data, cb)
    SetNuiFocus(false, false)
    ToggleTablet(false)

    SendNUIMessage({
        type = "hideTabletUI",
    })

    isTabletOpen = false

    if cb then cb('ok') end
end)


function ToggleTablet(state)
    if state then
        if isPlayingTabletAnim then return end
        isPlayingTabletAnim = true

        local isInVehicle = IsPedInAnyVehicle(PlayerPedId(), false)
        if isInVehicle then return end

        Citizen.CreateThread(function()
            RequestAnimDict(ANIM_DICT)
            while not HasAnimDictLoaded(ANIM_DICT) do
                Citizen.Wait(150)
            end

            RequestModel(TABLET_MODEL)
            while not HasModelLoaded(TABLET_MODEL) do
                Citizen.Wait(150)
            end

            local playerPed = PlayerPedId()

            local tabletObj = CreateObject(TABLET_MODEL, 0.0, 0.0, 0.0, true, true, false)
            local boneIndex = GetPedBoneIndex(playerPed, ATTACH_BONE)

            SetCurrentPedWeapon(playerPed, `weapon_unarmed`, true)

            AttachEntityToEntity(
                tabletObj, playerPed, boneIndex,
                ATTACH_OFFSET.x, ATTACH_OFFSET.y, ATTACH_OFFSET.z,
                ATTACH_ROTATION.x, ATTACH_ROTATION.y, ATTACH_ROTATION.z,
                true, false, false, false, 2, true
            )

            SetModelAsNoLongerNeeded(TABLET_MODEL)

            while isPlayingTabletAnim do
                Citizen.Wait(100)

                playerPed = PlayerPedId()

                if not IsEntityPlayingAnim(playerPed, ANIM_DICT, ANIM_NAME, 3) then
                    TaskPlayAnim(
                        playerPed, ANIM_DICT, ANIM_NAME,
                        3.0, 3.0, -1, 49, 0, false, false, false
                    )
                end
            end

            ClearPedSecondaryTask(playerPed)
            Citizen.Wait(450)

            DetachEntity(tabletObj, true, false)
            DeleteEntity(tabletObj)
        end)
    else
        isPlayingTabletAnim = false
    end
end

function SavedSettings()
  CoderaClient.Notify('Your settings were saved successfully!', 'success')
end
