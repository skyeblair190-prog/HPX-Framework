-- ATM DUI system by OsmFX Mods (https://osmfxmods.com) - https://github.com/OsmFX-Mods/osm-atmdui
-- Used with the author's permission and adapted for hpx_core. Original license: LICENSE-osm-atmdui.txt

-- DUI Manager
-- Handles creation and management of Direct UI for ATM screens
-- Using native FiveM DUI functions for reliability

local _print = print
local print = function(...)
    if Config.Debug then _print(...) end
end

local DUI = {}
DUI.duiObject = nil
DUI.duiHandle = nil
DUI.txdName = nil
DUI.texName = nil
DUI.isActive = false
DUI.appliedTexture = nil
DUI.currentTextureIdx = 1

-- Texture replacement candidates for ATM models
-- Based on benite-atm reference: { textureDict, textureName, resolution }
-- The screen texture is "softwareTexture" in the reference
local TextureCandidates = {
    ['prop_atm_01'] = {
        { dict = 'prop_atm_01', name = 'prop_cashpoint_screen' },    -- Correct from benite-atm
        { dict = 'prop_atm_01', name = 'prop_cashpoint_01' },        -- Hardware texture
    },
    ['prop_atm_02'] = {
        { dict = 'prop_atm_02', name = 'prop_cashpoint_screen' },    -- Correct from benite-atm
        { dict = 'prop_atm_02', name = 'prop_cashpoint_02b' },       -- Hardware texture
    },
    ['prop_atm_03'] = {
        { dict = 'prop_atm_03', name = 'prop_cashpoint_screen' },    -- Correct from benite-atm
        { dict = 'prop_atm_03', name = 'prop_cashpoint_02b' },       -- Hardware texture
    },
    ['prop_fleeca_atm'] = {
        { dict = 'prop_fleeca_atm', name = 'prop_fleece_emis' },     -- Correct from benite-atm (emissive/screen)
        { dict = 'prop_fleeca_atm', name = 'prop_fleece_atm' },      -- Hardware texture
    },
}

-- Current model being targeted
DUI.currentModel = nil

-- Create the DUI instance using native functions
function DUI.Create()
    if DUI.duiObject then return end
    
    local url = ('nui://%s/html/index.html?dui=true'):format(GetCurrentResourceName())
    local width = Config.DUI.width or 512
    local height = Config.DUI.height or 512
    
    print('^3[atm-dui] Creating DUI with URL: ' .. url .. '^0')
    
    -- Create DUI browser
    DUI.duiObject = CreateDui(url, width, height)
    
    if not DUI.duiObject then
        print('^1[atm-dui] Failed to create DUI object!^0')
        return false
    end
    
    -- Get handle for texture creation
    DUI.duiHandle = GetDuiHandle(DUI.duiObject)
    
    -- Create runtime texture dictionary and texture
    DUI.txdName = 'atm_dui_txd'
    DUI.texName = 'atm_dui_tex'
    
    local txd = CreateRuntimeTxd(DUI.txdName)
    
    -- Wait a moment for TXD to be ready (stability fix from reference)
    Wait(250)
    
    CreateRuntimeTextureFromDuiHandle(txd, DUI.texName, DUI.duiHandle)
    
    print('^2[atm-dui] DUI created successfully^0')
    print('^2[atm-dui] TXD: ' .. DUI.txdName .. ', TEX: ' .. DUI.texName .. '^0')
    
    -- Wait a moment for the page to load
    Wait(500)
    
    return true
end

-- Apply texture replacement to an ATM
function DUI.ApplyTexture(atmModel)
    if not DUI.duiObject then 
        if not DUI.Create() then
            return false
        end
    end
    
    local modelName = nil
    for _, model in ipairs(Config.ATMModels) do
        if GetHashKey(model) == atmModel then
            modelName = model
            break
        end
    end
    
    if not modelName then 
        print('^1[atm-dui] Unknown ATM model: ' .. atmModel .. '^0')
        return false 
    end
    
    local candidates = TextureCandidates[modelName]
    if not candidates or #candidates == 0 then 
        print('^1[atm-dui] No texture candidates for: ' .. modelName .. '^0')
        return false 
    end
    
    DUI.currentModel = modelName
    
    DUI.SendMessage('SET_MODEL', { model = modelName })
    
    -- Apply current candidate
    local candidate = candidates[DUI.currentTextureIdx]
    if not candidate then
        DUI.currentTextureIdx = 1
        candidate = candidates[1]
    end
    
    print('^3[atm-dui] Applying texture replacement: ' .. candidate.dict .. '/' .. candidate.name .. ' (candidate ' .. DUI.currentTextureIdx .. '/' .. #candidates .. ')^0')
    
    -- Remove previous texture if any
    if DUI.appliedTexture then
        RemoveReplaceTexture(DUI.appliedTexture.dict, DUI.appliedTexture.name)
    end
    
    -- Apply the runtime texture to replace the ATM screen texture
    AddReplaceTexture(candidate.dict, candidate.name, DUI.txdName, DUI.texName)
    DUI.appliedTexture = candidate
    DUI.isActive = true
    
    return true
end

-- Remove texture replacement
function DUI.RemoveTexture()
    if not DUI.isActive or not DUI.appliedTexture then return end
    
    RemoveReplaceTexture(DUI.appliedTexture.dict, DUI.appliedTexture.name)
    DUI.appliedTexture = nil
    DUI.isActive = false
    DUI.currentModel = nil
end

-- Send message to DUI
function DUI.SendMessage(action, data)
    if not DUI.duiObject then return end
    
    local message = json.encode({
        action = action,
        data = data
    })
    
    SendDuiMessage(DUI.duiObject, message)
end

-- Set ATM screen state
function DUI.SetScreen(screen, data)
    DUI.SendMessage('SET_SCREEN', {
        screen = screen,
        data = data or {}
    })
end

-- Show notification on ATM screen
function DUI.ShowNotification(message, type)
    DUI.SendMessage('NOTIFICATION', {
        message = message,
        type = type or 'info'
    })
end

-- Set processing state
function DUI.SetProcessing(isProcessing, duration)
    DUI.SendMessage('SET_PROCESSING', { processing = isProcessing, duration = duration })
end

-- Highlight button (for mouse hover simulation)
function DUI.HighlightButton(buttonId)
    DUI.SendMessage('HIGHLIGHT_BUTTON', { buttonId = buttonId })
end

-- Click button
function DUI.ClickButton(buttonId)
    DUI.SendMessage('CLICK_BUTTON', { buttonId = buttonId })
end

-- Initialize ATM session
function DUI.InitSession(playerData)
    DUI.SendMessage('INIT_SESSION', {
        playerName = playerData.name,
        bankBalance = playerData.bank,
        bankName = Config.UI.bankName,
        quickAmounts = Config.Transactions.quickAmounts,
        maxWithdraw = Config.Transactions.maxWithdraw,
        maxDeposit = Config.Transactions.maxDeposit,
        locale = Config.Locales[Config.UI.language] or Config.Locales['en']
    })
end

-- End ATM session
function DUI.EndSession()
    DUI.SendMessage('END_SESSION', {})
    DUI.SetScreen('welcome')
end

-- Cleanup
function DUI.Destroy()
    DUI.RemoveTexture()
    if DUI.duiObject then
        DestroyDui(DUI.duiObject)
        DUI.duiObject = nil
        DUI.duiHandle = nil
    end
    DUI.isActive = false
end

-- Export DUI module
_G.ATM_DUI = DUI

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    DUI.Destroy()
end)
