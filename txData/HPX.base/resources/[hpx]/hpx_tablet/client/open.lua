

RegisterNUICallback("openApp", function(data)
    TriggerEvent("codera-tablet:fB")

    if data.appName == "gruppe6" then
        TriggerEvent("codera-gruppe6job:Sign")

    elseif data.appName == "contacts" then
        TriggerEvent("codera-npcdialog:showTablet")

    elseif data.appName == "groups" then
        TriggerEvent("codera-grops:open")

    elseif data.appName == "trucking" then
        TriggerEvent("codera-trucking:OpenTab")

    elseif data.appName == "underground" then
        CoderaClient.TriggerCallback('codera-tablet:hasItem', function(hasItem)
            if hasItem then
                TriggerEvent('codera-boosting:OpenTab')
            else
                TriggerEvent("codera-tablet:Notify", "Underground", "You need a chip to access this application.", 'assets/ug-icon.png', 5000)
            end
        end, Config.UndergroundAppItem)

    elseif data.appName == "hq" then
        CoderaClient.TriggerCallback('codera-tablet:hasItem', function(hasItem)
            if hasItem then
                TriggerEvent("codera-hq:OpenTab") -- change to your own HQ resource's event
            else
                TriggerEvent("codera-tablet:Notify", "HQ", "You need a chip to access this application.", 'assets/hq.png', 5000)
            end
        end, Config.HQAppItem)

    elseif data.appName == "realestate" then
        TriggerEvent("codera-realestate:OpenTab")
        TriggerEvent("codera-tablet:Notify", "Real Estate", "Not ready yet!", 'assets/realestate-icon.png', 5000)

    elseif data.appName == "business" then
        TriggerEvent("codera-bussiness:OpenTab")
        TriggerEvent("codera-tablet:Notify", "Business", "Not ready yet!", 'assets/business.png', 5000)

    end
end)
