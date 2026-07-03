# FiveM Developer Reference

Generated: 2026-07-01  
Primary source: official Cfx.re/FiveM documentation at `https://docs.fivem.net/docs/`

Use this as a practical Markdown knowledge file for FiveM resource development, Codex prompts, code reviews, and debugging. It is framework-neutral by default, but the patterns are compatible with Qbox/QBCore/ESX style servers when you plug in the correct framework APIs.

---

## 1. Core FiveM mental model

FiveM servers are built from **resources**. A resource is a folder containing scripts, UI files, streamed assets, metadata files, and a required `fxmanifest.lua`. Resources can be started, stopped, refreshed, restarted, and grouped under category folders like `[standalone]`, `[vehicles]`, `[qbox]`, `[scripts]`, or `[maps]`.

Recommended mindset:

- **Client scripts** handle game interaction: peds, vehicles, controls, markers, cameras, NUI focus, local effects, and gameplay visuals.
- **Server scripts** are the source of truth: permissions, money, items, database state, validation, inventory changes, routing buckets, and secure event handling.
- **Shared scripts** hold constants/config/helpers used by both sides.
- **Network events** are not security by themselves. Anything sent from client to server must be validated server-side.
- **Network IDs** are for referring to entities across machines. Local entity handles are not stable across clients.
- **State bags** are best for replicated state like duty status, vehicle flags, entity metadata, or small synced values.
- **Profiler/F8/server console** are your first tools for performance and runtime issues.

---

## 2. Standard resource folder layout

```txt
my_resource/
├── fxmanifest.lua
├── shared/
│   ├── config.lua
│   └── utils.lua
├── client/
│   ├── main.lua
│   └── nui.lua
├── server/
│   ├── main.lua
│   └── callbacks.lua
├── html/
│   ├── index.html
│   ├── app.js
│   └── style.css
├── stream/
│   ├── model.yft
│   ├── texture.ytd
│   └── map.ymap
└── data/
    ├── handling.meta
    ├── vehicles.meta
    ├── carcols.meta
    ├── carvariations.meta
    └── vehiclelayouts.meta
```

Do not place random loose scripts in the server root. Every resource should have a clean manifest and predictable folder structure.

---

## 3. `fxmanifest.lua` essentials

Every modern resource should use `fxmanifest.lua`, not legacy `__resource.lua`.

### Basic Lua resource

```lua
fx_version 'cerulean'
game 'gta5'

author 'Your Name / Studio'
description 'Clean FiveM resource template'
version '1.0.0'

shared_scripts {
    'shared/config.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    'server/*.lua'
}
```

### NUI resource manifest

```lua
fx_version 'cerulean'
game 'gta5'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/app.js',
    'html/style.css',
    'html/assets/*.*'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    'server/*.lua'
}
```

### Vehicle/add-on resource manifest

```lua
fx_version 'cerulean'
game 'gta5'

author 'Your Name / Studio'
description 'Add-on vehicle resource'
version '1.0.0'

files {
    'data/handling.meta',
    'data/vehicles.meta',
    'data/carcols.meta',
    'data/carvariations.meta',
    'data/vehiclelayouts.meta'
}

data_file 'HANDLING_FILE' 'data/handling.meta'
data_file 'VEHICLE_METADATA_FILE' 'data/vehicles.meta'
data_file 'CARCOLS_FILE' 'data/carcols.meta'
data_file 'VEHICLE_VARIATION_FILE' 'data/carvariations.meta'
data_file 'VEHICLE_LAYOUTS_FILE' 'data/vehiclelayouts.meta'
```

### Common manifest entries

| Entry | Use |
|---|---|
| `fx_version 'cerulean'` | Current FXv2 version. |
| `game 'gta5'` | Makes the resource run on FiveM/GTA V. |
| `shared_script(s)` | Loads Lua/JS/C# script on both client and server. |
| `client_script(s)` | Loads client-side scripts. |
| `server_script(s)` | Loads server-side scripts. |
| `files` / `file` | Adds files to the client resource packfile. Required for NUI files and many data files. |
| `ui_page` | Points to the NUI HTML page. |
| `data_file` | Mounts metadata such as vehicle, handling, audio, weapon, map, or ped data. |
| `dependency` / `dependencies` | Requires another resource or runtime constraint before this one loads. |
| `server_only 'yes'` | Stops clients from downloading a server-only resource. |
| `this_is_a_map 'yes'` | Marks the resource as a map resource. |
| `provide` | Makes the current resource act as a replacement provider for another resource. |

### Dependency/runtime constraints

```lua
dependencies {
    '/server:4500',
    '/onesync',
    '/gameBuild:mp2023_01',
    'ox_lib',
    'oxmysql'
}
```

Use runtime constraints when a resource requires a minimum server artifact, OneSync/state awareness, or a specific GTA game build.

---

## 4. Lua runtime notes

FiveM Lua uses **CfxLua**, a modified Lua runtime. Lua files use `.lua`. Modern FiveM uses Lua 5.4 behavior, so avoid relying on older Lua assumptions.

Useful Lua patterns:

```lua
local RESOURCE = GetCurrentResourceName()

local function debugPrint(...)
    if Config and Config.Debug then
        print(('[%s]'):format(RESOURCE), ...)
    end
end
```

```lua
CreateThread(function()
    while true do
        Wait(1000)
        -- Do periodic work here.
    end
end)
```

Avoid heavy `while true do Wait(0)` loops unless truly needed. Increase wait time when idle.

---

## 5. Client vs server responsibilities

### Client should handle

- Drawing markers, text, zones, prompts, blips, temporary visuals.
- Player input/control detection.
- Local ped/vehicle tasks and animations.
- Opening/closing NUI.
- Requesting actions from server.

### Server should handle

- Permission checks.
- Money/item/database changes.
- Job, gang, duty, inventory, ownership, and cooldown authority.
- Validating player position, inventory, roles, state, and target entity.
- Creating trusted persistent entities when appropriate.
- Broadcasting clean updates to target clients.

Bad pattern:

```lua
-- BAD: client chooses item and amount, server blindly gives it.
RegisterNetEvent('job:giveItem', function(item, amount)
    GiveItem(source, item, amount)
end)
```

Better pattern:

```lua
local VALID_TURNIN = vector3(100.0, 100.0, 30.0)
local ITEM_NAME = 'log'
local MAX_AMOUNT = 10

local function isNear(src, coords, dist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - coords) <= dist
end

RegisterNetEvent('job:turnIn', function()
    local src = source

    if not isNear(src, VALID_TURNIN, 10.0) then return end
    if not PlayerHasJob(src, 'lumber') then return end

    local amount = math.min(GetPendingJobCount(src), MAX_AMOUNT)
    if amount <= 0 then return end

    ClearPendingJobCount(src)
    GiveItem(src, ITEM_NAME, amount)
end)
```

---

## 6. Events: local, networked, and secure

### Local events

Use `AddEventHandler` for events inside the same context.

```lua
AddEventHandler('my_resource:localEvent', function(data)
    print('Local event fired', json.encode(data))
end)

TriggerEvent('my_resource:localEvent', { hello = true })
```

### Network events

Use `RegisterNetEvent` when an event crosses client/server boundaries.

Client to server:

```lua
-- client.lua
TriggerServerEvent('my_resource:requestAction', targetNetId)
```

```lua
-- server.lua
RegisterNetEvent('my_resource:requestAction', function(targetNetId)
    local src = source
    -- Always validate src, target, distance, state, permission, cooldown, etc.
end)
```

Server to client:

```lua
-- server.lua
TriggerClientEvent('my_resource:notify', src, 'Action complete')
TriggerClientEvent('my_resource:syncEffect', -1, coords)
```

```lua
-- client.lua
RegisterNetEvent('my_resource:notify', function(message)
    print(message)
end)
```

### Event security checklist

Before changing anything important server-side, check:

- Is the player allowed to do this?
- Is the player close enough to the target/place?
- Does the player have the required job/gang/permission/item?
- Is the target entity valid and in scope?
- Is the requested amount/name/type server-approved?
- Is there a cooldown or rate limit?
- Is the state pulled from trusted server data, not client input?
- Is the event name unique enough to avoid collisions?

### Save `source` before async work

The `source` global is only reliable during the initial event call. Store it before `Wait`, callbacks, promises, or async DB work.

```lua
RegisterNetEvent('my_resource:doAsyncThing', function()
    local src = source

    CreateThread(function()
        Wait(500)
        print('Still using correct source:', src)
    end)
end)
```

---

## 7. Triggering events correctly

### Small data payload

```lua
TriggerServerEvent('resource:eventName', data)
```

### Large data payload

Use latent events for larger payloads so you do not block the network channel.

```lua
TriggerLatentServerEvent('resource:largePayload', 25000, bigData)
```

Server to all clients:

```lua
TriggerClientEvent('resource:eventName', -1, data)
```

Server to one client:

```lua
TriggerClientEvent('resource:eventName', src, data)
```

---

## 8. Network/local IDs

Important rule: **entity handles are local; network IDs travel across machines**.

### Player IDs

- Server scripts usually use `source` as the player's server ID.
- Client scripts use local player indexes and player peds.
- Convert server ID to client player index with `GetPlayerFromServerId(serverId)`.
- Convert client player index to server ID with `GetPlayerServerId(playerIndex)`.

### Entity IDs

Convert local entity handle to network ID:

```lua
local netId = NetworkGetNetworkIdFromEntity(vehicle)
```

Convert network ID back to local entity handle:

```lua
if NetworkDoesEntityExistWithNetworkId(netId) then
    local entity = NetworkGetEntityFromNetworkId(netId)
end
```

Never assume the same entity handle exists on every client.

---

## 9. State bags

State bags store arbitrary key/value pairs attached to an entity, player, or global state in state-awareness mode.

Good use cases:

- `Player(src).state.onDuty`
- `Player(src).state.jobName`
- `Entity(vehicle).state.fuel`
- `Entity(vehicle).state.locked`
- `Entity(vehicle).state.owner`
- `GlobalState.eventActive`

### Server setting replicated state

```lua
local player = Player(src)
player.state:set('onDuty', true, true) -- key, value, replicated
```

### Entity state

```lua
local veh = NetworkGetEntityFromNetworkId(netId)
Entity(veh).state:set('impounded', true, true)
```

### Client reading state

```lua
local state = LocalPlayer.state
if state.onDuty then
    -- player is on duty
end
```

### Shallow state limitation

Do not mutate nested tables and expect replication:

```lua
-- BAD: nested assignment may not replicate how you expect.
Entity(veh).state.status.engine = false
```

Prefer granular keys:

```lua
Entity(veh).state:set('status:engine', false, true)
Entity(veh).state:set('status:fuel', 50, true)
```

---

## 10. OneSync notes

OneSync enables state awareness and better server-side entity handling. Prefer state bags over expensive scope-enter/leave logic when syncing scoped state.

Best practices:

- Use server-created entities when the server should own/control persistence.
- Use network IDs for cross-client references.
- Use `SetEntityOrphanMode(entity, 2)` when you need to keep server-created entities from being cleaned up unexpectedly.
- Do not spam scope events for large player counts.
- Validate that a network ID exists on the target client before using it.

---

## 11. NUI / UI development

NUI is HTML/CSS/JS rendered through CEF. Use it for full-screen UI, panels, tablets, phones, inventories, radial menus, keypads, and business apps.

### Manifest setup

```lua
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/app.js',
    'html/style.css'
}
```

### Open/close UI from client Lua

```lua
local uiOpen = false

local function setUi(open)
    uiOpen = open
    SetNuiFocus(open, open)
    SendNUIMessage({
        action = open and 'open' or 'close'
    })
end

RegisterCommand('openui', function()
    setUi(true)
end, false)

RegisterNUICallback('close', function(_, cb)
    setUi(false)
    cb({ ok = true })
end)
```

### NUI callback from browser JS

```js
fetch(`https://${GetParentResourceName()}/close`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json; charset=UTF-8' },
  body: JSON.stringify({})
});
```

Always call the NUI callback response (`cb`) in Lua. If you fail to return data, the UI fetch can timeout.

### NUI debugging

- Use F8 command `nui_devTools` when developer mode is enabled.
- CEF remote debugging is exposed on localhost while FiveM is running.
- Check browser console and client F8 console.

---

## 12. Commands

### Client command

```lua
RegisterCommand('repairlocal', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        SetVehicleFixed(veh)
    end
end, false)
```

### Server command

```lua
RegisterCommand('announce', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'my_resource.announce') then
        return
    end

    local message = table.concat(args, ' ')
    TriggerClientEvent('chat:addMessage', -1, {
        args = { 'Announcement', message }
    })
end, false)
```

---

## 13. Server config basics

Common server commands:

```cfg
endpoint_add_tcp "0.0.0.0:30120"
endpoint_add_udp "0.0.0.0:30120"

sv_hostname "My FiveM Server"
sets sv_projectName "My Project"
sets sv_projectDesc "Clean roleplay server"
sets tags "roleplay, qbox, seriousrp"
sets locale "en-US"

set onesync on
sv_maxclients 48
sv_enforceGameBuild 2944

ensure mapmanager
ensure chat
ensure spawnmanager
ensure sessionmanager
ensure hardcap
ensure rconlog

ensure oxmysql
ensure ox_lib
ensure qbx_core
ensure my_resource

add_ace group.admin command allow
add_ace group.admin command.quit deny
add_principal identifier.fivem:1 group.admin

sv_licenseKey "CHANGE_ME"
```

Useful console commands:

| Command | Use |
|---|---|
| `refresh` | Rescan resources and manifests. |
| `ensure resourceName` | Start resource if stopped, restart if already running. |
| `restart resourceName` | Restart a running resource. |
| `stop resourceName` | Stop a resource. |
| `start resourceName` | Start a stopped resource. |
| `status` | List connected players with IDs and ping. |
| `clientkick id reason` | Kick a player by server ID. |
| `exec file.cfg` | Execute another cfg file. |

---

## 14. Vehicle/resource data files

Common vehicle-related data file keys:

```lua
data_file 'HANDLING_FILE' 'data/handling.meta'
data_file 'VEHICLE_METADATA_FILE' 'data/vehicles.meta'
data_file 'CARCOLS_FILE' 'data/carcols.meta'
data_file 'VEHICLE_VARIATION_FILE' 'data/carvariations.meta'
data_file 'VEHICLE_LAYOUTS_FILE' 'data/vehiclelayouts.meta'
data_file 'AUDIO_WAVEPACK' 'sfx/dlc_mycar'
data_file 'AUDIO_GAMEDATA' 'audioconfig/mycar_game.dat'
data_file 'AUDIO_SOUNDDATA' 'audioconfig/mycar_sounds.dat'
```

Vehicle debugging checklist:

- `fxmanifest.lua` includes every meta file under `files`.
- Every meta file has the correct `data_file` type.
- `vehicles.meta` modelName matches spawn name and stream files.
- `handlingId` in `vehicles.meta` matches the handling name in `handling.meta`.
- `carcols.meta` kit IDs and mod kit references are unique and correct.
- `carvariations.meta` references the correct model name.
- Streamed `.yft`, `.ytd`, `_hi.yft`, and livery `.ytd` names match the vehicle model.
- Texture dictionary names match what the model expects.
- For extra seats, check `vehiclelayouts.meta`, seat bones, layout names, and `vehicles.meta` layout references.
- Use client console `modelviewer true` to inspect TXDs/drawables.

---

## 15. Performance best practices

### Thread loops

Bad:

```lua
CreateThread(function()
    while true do
        Wait(0)
        -- expensive checks every frame forever
    end
end)
```

Better:

```lua
CreateThread(function()
    while true do
        local sleep = 1000

        if IsPlayerNearSomethingImportant() then
            sleep = 0
            -- draw marker / listen for key
        end

        Wait(sleep)
    end
end)
```

### General performance rules

- Avoid frame loops unless drawing or capturing input.
- Cache player ped and coordinates carefully, but refresh often enough to avoid stale data.
- Avoid sending network events every frame.
- Batch updates where possible.
- Use state bags for small replicated state instead of spam events.
- Avoid client-wide loops over every player/entity unless necessary.
- Use the profiler when you see hitch warnings or FPS drops.

### Profiler commands

```txt
profiler record 500
profiler save filename
```

Start with around 500 frames to identify expensive threads, then inspect the saved profile in Chrome.

---

## 16. Security best practices

Treat the client as untrusted.

### Never trust client input for

- Item names/counts.
- Money amounts.
- Job/gang/rank/permission claims.
- Entity ownership claims.
- Coordinates without validation.
- Cooldown/timer claims.
- Weapon/license claims.

### Server event validation pattern

```lua
local cooldown = {}

RegisterNetEvent('my_resource:serverAction', function(netId)
    local src = source
    local now = os.time()

    if cooldown[src] and now - cooldown[src] < 3 then return end
    cooldown[src] = now

    if not IsPlayerAceAllowed(src, 'my_resource.use') then return end
    if type(netId) ~= 'number' then return end
    if not NetworkDoesEntityExistWithNetworkId(netId) then return end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 then return end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end

    if #(GetEntityCoords(ped) - GetEntityCoords(entity)) > 10.0 then return end

    -- Safe to run action now.
end)
```

---

## 17. Debugging workflow

When something breaks:

1. Check server console for resource start errors.
2. Check F8 client console for Lua/NUI/native errors.
3. Run `refresh`, then `ensure resourceName`.
4. Confirm `fxmanifest.lua` loads all files.
5. Print `GetCurrentResourceName()` to make sure you are testing the right resource.
6. Add debug prints at event entry and before return points.
7. For network issues, log `source`, `netId`, entity existence, and distance checks.
8. For NUI, check `nui_devTools` and verify every callback calls `cb()`.
9. For vehicles, verify file names, model names, handling IDs, data_file entries, and stream folder names.
10. Use profiler for performance issues.

---

## 18. Common resource templates

### Secure interactable server event

```lua
-- client.lua
local function requestTow(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    TriggerServerEvent('tow:requestAttach', netId)
end
```

```lua
-- server.lua
RegisterNetEvent('tow:requestAttach', function(targetNetId)
    local src = source

    if type(targetNetId) ~= 'number' then return end
    if not NetworkDoesEntityExistWithNetworkId(targetNetId) then return end
    if not PlayerHasJob(src, 'tow') then return end

    local ped = GetPlayerPed(src)
    local targetVeh = NetworkGetEntityFromNetworkId(targetNetId)
    if ped == 0 or targetVeh == 0 then return end

    if #(GetEntityCoords(ped) - GetEntityCoords(targetVeh)) > 12.0 then return end

    TriggerClientEvent('tow:attachConfirmed', src, targetNetId)
end)
```

### Resource startup logging

```lua
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    print(('[%s] started successfully'):format(resourceName))
end)
```

### Player dropped cleanup

```lua
local activeJobs = {}

AddEventHandler('playerDropped', function()
    local src = source
    activeJobs[src] = nil
end)
```

---

## 19. Codex prompt template for FiveM tasks

Use this when asking Codex to build or update a FiveM resource:

```md
You are an expert FiveM developer working on a production Qbox/QBCore-compatible server.

Follow official FiveM/Cfx.re patterns:
- Use `fxmanifest.lua` with `fx_version 'cerulean'` and `game 'gta5'`.
- Keep client, server, shared, html, stream, and data files organized.
- Treat the client as untrusted.
- Validate all client-triggered server events server-side.
- Use `AddEventHandler` for same-context events and `RegisterNetEvent` only for networked events.
- Save `source` into a local variable before async work.
- Use network IDs when referencing entities across client/server.
- Use state bags for small replicated state instead of spamming events.
- Avoid heavy `Wait(0)` loops; use adaptive sleep.
- Add debug config and clear startup logs.
- Do not break existing exports/events unless explicitly requested.

Task:
[DESCRIBE TASK HERE]

Existing resource structure:
[PASTE FILE TREE HERE]

Required integrations:
[ox_lib / ox_target / ox_inventory / qbx_core / qb-core / mysql / nui / etc.]

Acceptance checks:
- Resource starts cleanly with no console errors.
- Client and server scripts are separated correctly.
- Security validation exists on all server events.
- Manifest includes every required file/data_file.
- Code is readable, commented only where useful, and production-safe.
```

---

## 20. Official docs used

- FiveM docs home: `https://docs.fivem.net/docs/`
- Introduction to resources: `https://docs.fivem.net/docs/scripting-manual/introduction/introduction-to-resources/`
- Resource manifest: `https://docs.fivem.net/docs/scripting-reference/resource-manifest/`
- Scripting in Lua: `https://docs.fivem.net/docs/scripting-manual/runtimes/lua/`
- Creating your first Lua script: `https://docs.fivem.net/docs/scripting-manual/introduction/creating-your-first-script/`
- Native functions: `https://docs.fivem.net/docs/scripting-manual/introduction/about-native-functions/`
- Working/listening/triggering/canceling events: `https://docs.fivem.net/docs/scripting-manual/working-with-events/`
- Secure your events: `https://docs.fivem.net/docs/developers/server-security/`
- Network and local IDs: `https://docs.fivem.net/docs/scripting-manual/networking/ids/`
- State bags: `https://docs.fivem.net/docs/scripting-manual/networking/state-bags/`
- OneSync: `https://docs.fivem.net/docs/scripting-reference/onesync/`
- NUI: `https://docs.fivem.net/docs/scripting-manual/nui-development/`
- NUI callbacks: `https://docs.fivem.net/docs/scripting-manual/nui-development/nui-callbacks/`
- Fullscreen NUI: `https://docs.fivem.net/docs/scripting-manual/nui-development/full-screen-nui/`
- Console commands: `https://docs.fivem.net/docs/client-manual/console-commands/`
- Server commands: `https://docs.fivem.net/docs/server-manual/server-commands/`
- Vanilla FXServer setup: `https://docs.fivem.net/docs/server-manual/setting-up-a-server-vanilla/`
- Data files: `https://docs.fivem.net/docs/game-references/data-files/`
- Profiler: `https://docs.fivem.net/docs/scripting-manual/debugging/using-profiler/`
```
