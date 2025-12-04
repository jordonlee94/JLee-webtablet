local QBCore = exports['qb-core']:GetCoreObject()

local tabletOpen = false

local function HasTablet()
    if not Config.RequireItem then return true end
    local pdata = QBCore.Functions.GetPlayerData()
    local items = pdata and pdata.items or {}
    for _, item in pairs(items) do
        if item.name == Config.TabletItem and (item.amount or 0) > 0 then
            return true
        end
    end
    return false
end

local function OpenTablet()
    if tabletOpen then return end
    if not HasTablet() then
        QBCore.Functions.Notify("You need a dark web tablet.", "error")
        return
    end
    tabletOpen = true
    SetNuiFocus(true, true)
    -- send config so NUI can filter drugs / guns
    SendNUIMessage({
        action = "setConfig",
        drugs  = Config.DrugItems or {},
        guns   = Config.GunItems or {},
    })
    SendNUIMessage({ action = "open" })
end

local function CloseTablet()
    if not tabletOpen then return end
    tabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
end



-- open by event (used by server usable item)
RegisterNetEvent("qb-darkwebtablet:client:OpenTablet", function()
    OpenTablet()
end)

-- open when using item (client-side hook)
RegisterNetEvent("QBCore:Client:UseItem", function(item)
    if not item or not item.name then return end
    if item.name == Config.TabletItem then
        OpenTablet()
    end
end)

-- NUI callbacks

RegisterNUICallback("close", function(_, cb)
    CloseTablet()
    cb("ok")
end)

RegisterNUICallback("loadListings", function(data, cb)
    QBCore.Functions.TriggerCallback("qb-darkwebtablet:server:GetListings", function(list)
        cb(list)
    end, data.category)
end)

RegisterNUICallback("createListing", function(data, cb)
    QBCore.Functions.TriggerCallback("qb-darkwebtablet:server:CreateListing", function(res)
        cb(res)
    end, data)
end)

RegisterNUICallback("cancelListing", function(data, cb)
    QBCore.Functions.TriggerCallback("qb-darkwebtablet:server:CancelListing", function(res)
        cb(res)
    end, data.id)
end)

RegisterNUICallback("buyListing", function(data, cb)
    QBCore.Functions.TriggerCallback("qb-darkwebtablet:server:BuyListing", function(res)
        cb(res)
    end, data.id, data.payment_type)
end)

RegisterNUICallback("getOwnedCars", function(_, cb)
    QBCore.Functions.TriggerCallback("qb-darkwebtablet:server:GetOwnedCars", function(cars)
        cb(cars)
    end)
end)

RegisterNUICallback("getInventory", function(_, cb)
    local pdata = QBCore.Functions.GetPlayerData()
    cb(pdata and pdata.items or {})
end)

-- ESC / BACKSPACE closes tablet
CreateThread(function()
    while true do
        if tabletOpen then
            if IsControlJustReleased(0, 177) or IsControlJustReleased(0, 322) then
                CloseTablet()
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)
