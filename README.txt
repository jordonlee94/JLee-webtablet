qb-darkwebtablet
=================

Overview
--------
qb-darkwebtablet is a QBCore-compatible FiveM resource that provides a "dark web" tablet UI and a simple marketplace. Players use an in-game item to open a web-based tablet UI (html folder) and can create, browse, and purchase listings. Server-side scripts persist listings to a MySQL table and validate all marketplace actions.

Key features
------------
- Item-driven tablet: players open the tablet by using the configured item (example: darkweb_tablet).
- Web UI: lightweight HTML/JS/CSS interface served from the resource (html/index.html).
- Persistent listings: listings saved in the database table `darkweb_listings`.
- Server validation: all critical actions (create listing, purchase, remove) are validated on the server.
- QBCore integration: uses QBCore server functions for player/money handling.

How the script works
--------------------
1. Client: when a player uses the configured tablet item, client.lua opens the NUI (html/UI).
2. UI: the web UI (index.html + script.js) sends messages to the client (NUI callbacks) for actions like creating a listing, browsing, and purchasing.
3. Client -> Server: client.lua forwards NUI actions to the server via TriggerServerEvent with resource-prefixed event names.
4. Server: server.lua handles those events, performs validation (player existence, funds, item ownership), interacts with the database (reads/writes `darkweb_listings`) and responds back to the client with results.
5. Client: receives server results and updates the NUI accordingly.

Important server events & exports
---------------------------------
- Server events (prefixed by the resource name):
  - qb-darkwebtablet:createListing — create a new listing (validates input and seller funds/items)
  - qb-darkwebtablet:purchaseListing — attempts a purchase and moves funds/items accordingly
  - qb-darkwebtablet:removeListing — seller or admin can remove a listing

(Exact event names are defined in server.lua — search for RegisterNetEvent in that file to see the exact signatures.)

Config & customization
----------------------
- config.lua exposes settings for the resource such as item name, allowed categories, price limits, and NUI strings.
- You can change the item used to open the tablet (example entry shown in the Installation section). Ensure the item is added to your shared items.

Database
--------
The resource requires a single table `darkweb_listings`. The SQL schema already included in the original README is correct and should be executed once during installation.

Installation (unchanged)
------------------------
Keep the installation steps as originally provided in this file. They include the required SQL table, example item definition, and the server.cfg ensure line.

Files
-----
- client.lua — client-side logic, NUI open/close and NUI -> server forwarding
- server.lua — server-side marketplace handling, validation and DB interactions
- config.lua — resource configuration
- fxmanifest.lua — resource manifest and load order
- html/index.html, html/script.js, html/style.css — UI files served to the player

Developer notes & best practices
-------------------------------
- All marketplace actions are validated on the server. Do not bypass server checks.
- If you customize money/item handling for a modified economy, update server.lua to use your QBCore methods.
- Keep Wait() or CreateThread usage correct if you modify long-running client loops.
- Use resource-prefixed event names when interacting with this script from other resources.

Support
-------
If you need help, provide:
- Server console output related to the resource
- Client console errors (F8) and browser console errors from the NUI
- The QBCore version you are running and any changes you made to config.lua

