-- ATM DUI system by OsmFX Mods (https://osmfxmods.com) - https://github.com/OsmFX-Mods/osm-atmdui
-- Used with the author's permission and adapted for hpx_core. Original license: LICENSE-osm-atmdui.txt

-- Camera System
-- Handles scripted camera for ATM interaction
-- Uses screen-projection button detection (benite-atm approach)
-- Projects 3D button positions to screen coordinates, checks proximity to crosshair (screen center)

local _print = print
local print = function(...)
    if Config.Debug then _print(...) end
end

local Camera = {}
Camera.handle = nil
Camera.isActive = false
Camera.initialRot = vec3(0, 0, 0)
Camera.currentRot = vec3(0, 0, 0)
Camera.targetATM = nil
Camera.currentATMModel = nil
Camera.atmCoords = nil
Camera.atmHeadingQuat = nil
Camera.debugMode = false

-- Cached button world positions (computed once per session)
Camera.cachedButtonCoords = {}

-- Math helpers
local function Clamp(value, min, max)
    return math.max(min, math.min(value, max))
end

-- Quaternion from heading (rotation around Z axis)
local function QuatFromHeading(heading)
    return quat(heading, vector3(0, 0, 1))
end

-- Rotate a vector by a quaternion
local function RotateVectorByQuaternion(vec, rotQuat)
    local vecQuat = quat(0, vec.x, vec.y, vec.z)
    local rotatedQuat = rotQuat * vecQuat * inv(rotQuat)
    return vector3(rotatedQuat.x, rotatedQuat.y, rotatedQuat.z)
end

-- Compute world positions of all buttons for the current ATM
local function ComputeButtonWorldPositions(atmEntity, atmModel)
    Camera.cachedButtonCoords = {}

    local buttons = Config.ButtonOffsets[atmModel]
    if not buttons then return end

    local atmCoords = GetEntityCoords(atmEntity)
    local atmHeading = GetEntityHeading(atmEntity)
    local headingQuat = QuatFromHeading(atmHeading)

    Camera.atmCoords = atmCoords
    Camera.atmHeadingQuat = headingQuat

    for _, btn in ipairs(buttons) do
        local rotatedOffset = RotateVectorByQuaternion(btn.offset, headingQuat)
        local worldPos = vector3(
            atmCoords.x + rotatedOffset.x,
            atmCoords.y + rotatedOffset.y,
            atmCoords.z + rotatedOffset.z
        )
        Camera.cachedButtonCoords[#Camera.cachedButtonCoords + 1] = {
            id = btn.id,
            worldPos = worldPos
        }
    end

    print('^2[atm-dui] Computed ' .. #Camera.cachedButtonCoords .. ' button world positions for ' .. atmModel .. '^0')
end

-- Find which button the crosshair (screen center) is closest to
local function GetButtonAtScreenCenter()
    local proximity = Config.ButtonProximity or 0.027
    local closestDist = proximity
    local closestButton = nil

    for _, btn in ipairs(Camera.cachedButtonCoords) do
        local visible, screenX, screenY = GetScreenCoordFromWorldCoord(btn.worldPos.x, btn.worldPos.y, btn.worldPos.z)

        if visible then
            -- Distance from screen center (0.5, 0.5) — where the crosshair is
            local dx = screenX - 0.5
            local dy = screenY - 0.5
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist < proximity and dist < closestDist then
                closestDist = dist
                closestButton = btn.id
            end
        end
    end

    return closestButton
end

-- Create and transition to ATM camera
function Camera.TransitionTo(atmEntity)
    if Camera.isActive then return end

    Camera.targetATM = atmEntity
    local atmHeading = GetEntityHeading(atmEntity)

    -- Detect ATM model name
    local model = GetEntityModel(atmEntity)
    Camera.currentATMModel = nil
    for _, modelName in ipairs(Config.ATMModels) do
        if GetHashKey(modelName) == model then
            Camera.currentATMModel = modelName
            break
        end
    end

    -- Compute button world positions
    if Camera.currentATMModel then
        ComputeButtonWorldPositions(atmEntity, Camera.currentATMModel)
    end

    -- Position camera in front of ATM
    local sideOffset = Config.Camera.sideOffset or 0.0
    local camOffset = GetOffsetFromEntityInWorldCoords(atmEntity, sideOffset, -Config.Camera.distance, Config.Camera.heightOffset)

    -- Create camera
    Camera.handle = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(Camera.handle, camOffset.x, camOffset.y, camOffset.z)

    -- Initial rotation: heading matches ATM, pitch tilts downward for natural POV
    local initialPitch = Config.Camera.initialPitch or -15.0
    Camera.initialRot = vec3(initialPitch, 0.0, atmHeading)
    Camera.currentRot = Camera.initialRot

    SetCamRot(Camera.handle, Camera.initialRot.x, Camera.initialRot.y, Camera.initialRot.z, 2)
    SetCamFov(Camera.handle, Config.Camera.fov)
    SetCamActive(Camera.handle, true)

    -- Smooth transition
    RenderScriptCams(true, true, Config.Camera.transitionTime, true, true)

    -- Freeze player
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)

    -- Hide HUD elements
    TriggerEvent('hud:client:ToggleHUD', false)

    Camera.isActive = true

    print('^2[atm-dui] Camera transitioned - Model: ' .. tostring(Camera.currentATMModel) .. ' | Heading: ' .. atmHeading .. '^0')

    -- Start camera control thread
    Camera.StartControlThread()
end

-- Start the camera control thread
function Camera.StartControlThread()
    local prevButtonId = nil

    CreateThread(function()
        while Camera.isActive and DoesCamExist(Camera.handle) do
            -- Disable all controls
            DisableAllControlActions(0)

            -- Draw crosshair dot in center of screen
            DrawRect(0.5, 0.5, 0.003, 0.005, 255, 255, 255, 200)

            -- Get mouse input
            local xMouse = GetDisabledControlNormal(0, 1) * (Config.Camera.mouseSensitivity or 4.0)
            local yMouse = GetDisabledControlNormal(0, 2) * (Config.Camera.mouseSensitivity or 4.0)

            -- Update camera rotation with limits
            local pitchUp = Config.Camera.pitchUp or 15.0
            local pitchDown = Config.Camera.pitchDown or 28.0
            local yawRange = Config.Camera.yawRange or 20.0

            Camera.currentRot = vec3(
                Clamp(Camera.currentRot.x - yMouse, Camera.initialRot.x - pitchDown, Camera.initialRot.x + pitchUp),
                Camera.currentRot.y,
                Clamp(Camera.currentRot.z - xMouse, Camera.initialRot.z - yawRange, Camera.initialRot.z + yawRange)
            )

            SetCamRot(Camera.handle, Camera.currentRot.x, Camera.currentRot.y, Camera.currentRot.z, 2)

            -- Detect which physical button the crosshair is over
            -- Uses screen-projection: projects each button's 3D world position to screen coords
            -- and checks distance to screen center (0.5, 0.5), exactly like benite-atm
            local hoveredButton = GetButtonAtScreenCenter()

            -- Send highlight updates to DUI
            if hoveredButton ~= prevButtonId then
                ATM_DUI.HighlightButton(hoveredButton)
                prevButtonId = hoveredButton
            end

            -- Handle click (left mouse button)
            if IsDisabledControlJustPressed(0, 24) and hoveredButton then
                Camera.OnButtonClick(hoveredButton)
            end

            -- Physical button highlight: draw a subtle glow over the hovered button
            if hoveredButton then
                for _, btn in ipairs(Camera.cachedButtonCoords) do
                    if btn.id == hoveredButton then
                        -- Draw a premium Fleeca-teal glowing dot
                        DrawMarker(28,
                            btn.worldPos.x, btn.worldPos.y, btn.worldPos.z,
                            0, 0, 0, 0, 0, 0,
                            0.015, 0.015, 0.015,
                            0, 201, 167, 200, -- Teal color
                            false, false, 2, false, nil, nil, false
                        )
                        break
                    end
                end
            end

            -- Debug: draw all button markers
            if Camera.debugMode then
                for _, btn in ipairs(Camera.cachedButtonCoords) do
                    local isHovered = (btn.id == hoveredButton)
                    local r = isHovered and 0 or 255
                    local g = isHovered and 255 or 0
                    local b = isHovered and 0 or 255
                    DrawMarker(28,
                        btn.worldPos.x, btn.worldPos.y, btn.worldPos.z,
                        0, 0, 0, 0, 0, 0,
                        0.015, 0.015, 0.015,
                        r, g, b, 180,
                        false, false, 2, false, nil, nil, false
                    )
                end
            end

            -- Handle exit (ESC or Backspace)
            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 177) then
                Camera.TransitionBack()
                break
            end

            Wait(0)
        end
    end)
end

-- Handle button click
function Camera.OnButtonClick(buttonId)
    -- Play click sound
    if Config.Sounds.enabled then
        -- Use different sounds for side buttons vs number pad buttons
        if buttonId:match('^side_') then
            PlaySoundFrontend(-1, 'ATM_WINDOW', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        else
            PlaySoundFrontend(-1, 'PIN_BUTTON', 'ATM_SOUNDS', true)
        end
    end

    -- Send to DUI for visual feedback
    ATM_DUI.ClickButton(buttonId)

    -- Trigger event for main.lua to handle logic
    TriggerEvent('atm-dui:client:buttonClicked', buttonId)
end

-- Transition back to normal view
function Camera.TransitionBack()
    if not Camera.isActive then return end

    Camera.isActive = false

    if DoesCamExist(Camera.handle) then
        RenderScriptCams(false, true, Config.Camera.transitionTime, true, true)
        DestroyCam(Camera.handle, false)
        Camera.handle = nil
    end

    -- Unfreeze player
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)

    -- Show HUD
    TriggerEvent('hud:client:ToggleHUD', true)

    -- Reset DUI highlight
    ATM_DUI.HighlightButton(nil)

    Camera.targetATM = nil
    Camera.currentATMModel = nil
    Camera.atmCoords = nil
    Camera.atmHeadingQuat = nil
    Camera.cachedButtonCoords = {}
    Camera.initialRot = vec3(0, 0, 0)
    Camera.currentRot = vec3(0, 0, 0)

    -- Trigger session end
    TriggerEvent('atm-dui:client:sessionEnded')
end

-- Export Camera module
_G.ATM_Camera = Camera

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    if Camera.isActive then
        Camera.TransitionBack()
    end
end)
