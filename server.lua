local QBCore = exports['qb-core']:GetCoreObject()

local function tableContains(t, val)
    for _, v in pairs(t or {}) do
        if v == val then return true end
    end
    return false
end

-- MARKED BILLS HELPERS



local function HasEnoughMoney(Player, paymentType, amount)
    if paymentType == "marked_bills" then
        return CountMarkedBills(Player.PlayerData.items) >= amount
    else
        return Player.Functions.GetMoney(paymentType) >= amount
    end
end

local function TakeMoney(Player, paymentType, amount)
    if paymentType == "marked_bills" then
        return TakeMarkedBills(Player, amount)
    else
        return Player.Functions.RemoveMoney(paymentType, amount, "darkweb-purchase")
    end
end

local function GiveMoneyOnline(Player, paymentType, amount)
    if paymentType == "marked_bills" then
        Player.Functions.AddItem(Config.MarkedBillsItem, 1, false, {
            [Config.MarkedBillsMetaKey] = amount
        })
    else
        Player.Functions.AddMoney(paymentType, amount, "darkweb-sale")
    end
end

local function GiveMoneyOffline(citizenid, paymentType, amount)
    -- QBCore 2.0 default: money stored as JSON in players.money
    if paymentType == "cash" or paymentType == "bank" then
        MySQL.single("SELECT money FROM players WHERE citizenid = ?", { citizenid }, function(pRow)
            if not pRow or not pRow.money then return end
            local money = {}
            pcall(function() money = json.decode(pRow.money) end)
            if type(money) ~= "table" then money = {} end
            money[paymentType] = (money[paymentType] or 0) + amount
            MySQL.update("UPDATE players SET money = ? WHERE citizenid = ?", { json.encode(money), citizenid })
        end)
    elseif paymentType == "marked_bills" then
        -- Without knowing your inventory DB schema safely, convert to bank when seller is offline.
        MySQL.single("SELECT money FROM players WHERE citizenid = ?", { citizenid }, function(pRow)
            if not pRow or not pRow.money then return end
            local money = {}
            pcall(function() money = json.decode(pRow.money) end)
            if type(money) ~= "table" then money = {} end
            money.bank = (money.bank or 0) + amount
            MySQL.update("UPDATE players SET money = ? WHERE citizenid = ?", { json.encode(money), citizenid })
        end)
    end
end

-- GARAGE HELPERS

local function GarageCfg()
    return Config.GarageSystems[Config.GarageSystem]
end

local function MoveVehicleToMarket(cid, plate, cb)
    local cfg = GarageCfg()
    if not cfg then return cb(false, "Garage config error") end

    local tbl        = cfg.vehiclesTable
    local ownerField = cfg.ownerField
    local plateField = cfg.plateField
    local stored     = cfg.storedField

    MySQL.single(
        ("SELECT * FROM `%s` WHERE `%s` = ? AND `%s` = ?"):format(tbl, plateField, ownerField),
        { plate, cid },
        function(row)
            if not row then
                return cb(false, "Vehicle not found")
            end

            if Config.GarageSystem == "jg-garages" then
                MySQL.update(
                    ("UPDATE `%s` SET `%s` = 0 WHERE `%s` = ?"):format(tbl, stored, plateField),
                    { plate }
                )
            else
                MySQL.update(
                    ("DELETE FROM `%s` WHERE `%s` = ?"):format(tbl, plateField),
                    { plate }
                )
            end

            cb(true, row)
        end
    )
end

local function ReturnVehicle(cid, vehicleRow)
    local cfg = GarageCfg()
    if not cfg then return end

    vehicleRow[cfg.ownerField]  = cid
    vehicleRow[cfg.storedField] = 1

    -- ensure vehicle is assigned to a garage for the buyer
    local garageName = Config.DefaultGarage or "pillboxgarage"
    if Config.GarageSystem == "qb-garages" then
        vehicleRow.garage = garageName
        -- 'state' is already used as storedField for qb-garages
    elseif Config.GarageSystem == "jg-garages" then
        vehicleRow.garage_id = garageName
        vehicleRow.state     = 1
        -- 'in_garage' is already set via storedField for jg-garages
    end

    local cols, qs, vals = {}, {}, {}
    for k, v in pairs(vehicleRow) do
        cols[#cols+1] = ("`%s`"):format(k)
        qs[#qs+1]   = "?"
        vals[#vals+1] = v
    end

    MySQL.insert(
        ("INSERT INTO `%s` (%s) VALUES (%s)")
            :format(cfg.vehiclesTable, table.concat(cols, ","), table.concat(qs, ",")),
        vals
    )
end

-- GET OWNED CARS

QBCore.Functions.CreateCallback("qb-darkwebtablet:server:GetOwnedCars", function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end

    local cfg = GarageCfg()
    if not cfg then return cb({}) end

    local cid = Player.PlayerData.citizenid

    MySQL.query(
        ("SELECT `%s` AS plate, `vehicle`, `garage` FROM `%s` WHERE `%s` = ?")
            :format(cfg.plateField, cfg.vehiclesTable, cfg.ownerField),
        { cid },
        function(rows)
            cb(rows or {})
        end
    )
end)

-- LISTINGS

local function DeactivateListing(id)
    MySQL.update(("UPDATE `%s` SET active = 0 WHERE id = ?"):format(Config.ListingsTable), { id })
end

-- GET LISTINGS

QBCore.Functions.CreateCallback("qb-darkwebtablet:server:GetListings", function(source, cb, category)
    MySQL.query(
        ("SELECT * FROM `%s` WHERE active = 1 AND category = ?"):format(Config.ListingsTable),
        { category },
        function(rows)
            for _, row in ipairs(rows or {}) do
                row.extraData = json.decode(row.data or "{}")
            end
            cb(rows or {})
        end
    )
end)

-- CREATE LISTING (seller does NOT choose payment type)

QBCore.Functions.CreateCallback("qb-darkwebtablet:server:CreateListing", function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({ success = false, msg = "No player" }) end

    local category   = data.category
    local price      = tonumber(data.price)
    local amount     = tonumber(data.amount or 1)
    local cid        = Player.PlayerData.citizenid

    if not category then return cb({ success = false, msg = "Missing category" }) end
    if not price or price <= 0 then return cb({ success = false, msg = "Invalid price" }) end
    if amount <= 0 then return cb({ success = false, msg = "Invalid amount" }) end

    -- ITEMS / DRUGS / GUNS
    if category == Config.Categories.Items
       or category == Config.Categories.Drugs
       or category == Config.Categories.Guns
    then
        local itemName = data.item
        if not itemName or itemName == "" then
            return cb({ success = false, msg = "No item selected" })
        end

        local isDrug = tableContains(Config.DrugItems, itemName)
        local isGun  = tableContains(Config.GunItems,  itemName)

        if category == Config.Categories.Items and (isDrug or isGun) then
            return cb({ success = false, msg = "This item must be listed in Drugs/Guns tab" })
        end
        if category == Config.Categories.Drugs and not isDrug then
            return cb({ success = false, msg = "Item not allowed in Drugs tab" })
        end
        if category == Config.Categories.Guns and not isGun then
            return cb({ success = false, msg = "Item not allowed in Guns tab" })
        end

        local item = Player.Functions.GetItemByName(itemName)
        if not item or (item.amount or 0) < amount then
            return cb({ success = false, msg = "Not enough items" })
        end

        Player.Functions.RemoveItem(itemName, amount)

        MySQL.insert(
            ("INSERT INTO `%s` (category,item,label,amount,price,payment_type,seller_cid,data) VALUES (?,?,?,?,?,?,?,?)")
                :format(Config.ListingsTable),
            {
                category,
                itemName,
                item.label or item.name,
                amount,
                price,
                "any", -- payment decided later by buyer
                cid,
                json.encode({ info = item.info })
            },
            function(id)
                cb({ success = true, id = id })
            end
        )

    -- CARS
    elseif category == Config.Categories.Cars then
        local plate = data.plate
        if not plate or plate == "" then
            return cb({ success = false, msg = "No plate selected" })
        end

        MoveVehicleToMarket(cid, plate, function(ok, row)
            if not ok then
                return cb({ success = false, msg = row or "Failed to move vehicle" })
            end

            MySQL.insert(
                ("INSERT INTO `%s` (category,item,label,amount,price,payment_type,seller_cid,data) VALUES (?,?,?,?,?,?,?,?)")
                    :format(Config.ListingsTable),
                {
                    category,
                    plate,
                    plate,
                    1,
                    price,
                    "any",
                    cid,
                    json.encode({ vehicleRow = row })
                },
                function(id)
                    cb({ success = true, id = id })
                end
            )
        end)
    else
        cb({ success = false, msg = "Unknown category" })
    end
end)

-- CANCEL LISTING

QBCore.Functions.CreateCallback("qb-darkwebtablet:server:CancelListing", function(source, cb, id)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({ success = false, msg = "No player" }) end
    local cid = Player.PlayerData.citizenid

    MySQL.single(
        ("SELECT * FROM `%s` WHERE id = ? AND seller_cid = ? AND active = 1"):format(Config.ListingsTable),
        { id, cid },
        function(row)
            if not row then
                return cb({ success = false, msg = "Listing not found" })
            end

            DeactivateListing(row.id)
            local data = json.decode(row.data or "{}")

            if row.category == Config.Categories.Items
               or row.category == Config.Categories.Drugs
               or row.category == Config.Categories.Guns
            then
                Player.Functions.AddItem(row.item, row.amount, false, data.info)
            elseif row.category == Config.Categories.Cars then
                if data.vehicleRow then
                    ReturnVehicle(cid, data.vehicleRow)
                end
            end

            cb({ success = true })
        end
    )
end)

-- BUY LISTING (buyer chooses payment type)

QBCore.Functions.CreateCallback("qb-darkwebtablet:server:BuyListing", function(source, cb, id, paymentType)
    local Buyer = QBCore.Functions.GetPlayer(source)
    if not Buyer then return cb({ success = false, msg = "No player" }) end

    if not paymentType or not tableContains(Config.AllowedPaymentTypes, paymentType) then
        return cb({ success = false, msg = "Invalid payment type" })
    end

    MySQL.single(
        ("SELECT * FROM `%s` WHERE id = ? AND active = 1"):format(Config.ListingsTable),
        { id },
        function(row)
            if not row then
                return cb({ success = false, msg = "Listing not available" })
            end

            local cidBuyer  = Buyer.PlayerData.citizenid
            local sellerCid = row.seller_cid

            if cidBuyer == sellerCid then
                return cb({ success = false, msg = "You cannot buy your own listing" })
            end

            local price = row.price
            local data  = json.decode(row.data or "{}")
            local payment = paymentType

            if not HasEnoughMoney(Buyer, payment, price) then
                return cb({ success = false, msg = "Not enough money" })
            end

            if not TakeMoney(Buyer, payment, price) then
                return cb({ success = false, msg = "Payment failed" })
            end

            -- give item / car to buyer
            if row.category == Config.Categories.Items
               or row.category == Config.Categories.Drugs
               or row.category == Config.Categories.Guns
            then
                if not Buyer.Functions.AddItem(row.item, row.amount, false, data.info) then
                    GiveMoneyOnline(Buyer, payment, price)
                    return cb({ success = false, msg = "Inventory full" })
                end
            elseif row.category == Config.Categories.Cars then
                if not data.vehicleRow then
                    GiveMoneyOnline(Buyer, payment, price)
                    return cb({ success = false, msg = "Vehicle data missing" })
                end
                ReturnVehicle(cidBuyer, data.vehicleRow)
            end

            -- pay seller online or offline
            local Seller = QBCore.Functions.GetPlayerByCitizenId(sellerCid)
            if Seller then
                GiveMoneyOnline(Seller, payment, price)
            else
                GiveMoneyOffline(sellerCid, payment, price)
            end

            DeactivateListing(row.id)
            cb({ success = true, msg = "Purchase complete" })
        end
    )
end)

-- USABLE ITEM: using the tablet item opens NUI

QBCore.Functions.CreateUseableItem(Config.TabletItem, function(source, item)
    TriggerClientEvent("qb-darkwebtablet:client:OpenTablet", source)
end)
