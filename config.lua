Config = {}

-- How tablet is opened
Config.OpenTabletCommand = "darkweb"      -- also has useable item
Config.RequireItem       = true
Config.TabletItem        = "darkweb_tablet"

-- Payment options
Config.AllowedPaymentTypes = { "cash", "bank", "marked_bills" }
Config.MarkedBillsItem     = "markedbills"
Config.MarkedBillsMetaKey  = "worth"

-- Garage system support (qb-garages or jg-garages)
Config.GarageSystem = "qb-garages"  -- change to "jg-garages" if needed

Config.GarageSystems = {
    ['qb-garages'] = {
        vehiclesTable = "player_vehicles",
        ownerField    = "citizenid",
        plateField    = "plate",
        storedField   = "state",      -- qb-garages uses 'state'
    },
    ['jg-garages'] = {
        vehiclesTable = "player_vehicles",
        ownerField    = "citizenid",
        plateField    = "plate",
        storedField   = "in_garage",  -- jg-garages uses 'in_garage'
    },
}

-- DB table for listings (create via SQL)
Config.ListingsTable = "darkweb_listings"

-- Categories
Config.Categories = {
    Items = "item",
    Cars  = "vehicle",
    Drugs = "drug",
    Guns  = "gun",
}

-- Drug-only items (can *only* be listed in Drugs tab)
Config.DrugItems = {
    "weed_white-widow",
    "weed_og-kush",
    "weed_amnesia",
    "coke_brick",
    "crack",
    "meth",
}

-- Gun-only items (can *only* be listed in Guns tab)
Config.GunItems = {
    "weapon_pistol",
    "weapon_pistol_mk2",
    "weapon_combatpistol",
    "weapon_microsmg",
    "weapon_assaultrifle",
}

-- Inventory images (qb-inventory style)
Config.InventoryImageBase = "nui://qb-inventory/html/images"
