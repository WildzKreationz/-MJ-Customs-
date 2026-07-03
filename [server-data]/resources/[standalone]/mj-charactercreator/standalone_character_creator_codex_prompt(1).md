# Codex Prompt: Standalone FiveM Character Creator

You are an expert FiveM developer. Build a complete standalone FiveM resource named `wk-charactercreator`.

This resource must work without QBCore, Qbox, ESX, ox_lib, ox_inventory, or any database dependency. It is for a basic FiveM test server used for clothing testing, addon clothing previews, and freemode ped customization.

Reference the official FiveM/Cfx.re documentation while coding, especially:
- Resource manifest / fxmanifest structure
- FiveM Lua scripting
- NUI callbacks
- RegisterCommand
- Ped clothing/component natives
- Collection-based drawable and prop natives for addon clothing support
- Camera natives
- Input/control natives

Main goal: create a modern standalone character creator menu that opens by command, forces the player into a freemode ped, detects available addon clothing collections, reads all available drawable/texture variations, previews them live on the ped, and gives camera controls around the ped.

---

## Resource Requirements

Create the full resource with this structure:

```txt
wk-charactercreator/
├── fxmanifest.lua
├── config.lua
├── client/
│   ├── main.lua
│   ├── clothing.lua
│   ├── camera.lua
│   └── utils.lua
├── server/
│   └── main.lua
├── html/
│   ├── index.html
│   ├── style.css
│   └── app.js
└── README.md
```

The resource must be standalone and lightweight.

Use `fx_version 'cerulean'` and `game 'gta5'`.

The NUI must load from `html/index.html`.

Do not require any external UI library CDN. Use pure HTML, CSS, and JavaScript.

---

## Commands

Add these commands:

```lua
/creator
/charcreator
/cc
```

All commands must open the character creator menu.

Add optional command arguments:

```txt
/creator male
/creator female
/creator close
```

Behavior:
- `/creator` opens the UI using the current freemode gender if possible.
- `/creator male` switches player to `mp_m_freemode_01` and opens the UI.
- `/creator female` switches player to `mp_f_freemode_01` and opens the UI.
- `/creator close` closes the UI and restores gameplay camera/focus.

Add config options:

```lua
Config.Commands = { 'creator', 'charcreator', 'cc' }
Config.DefaultGender = 'male'
Config.AllowCommand = true
Config.FreezePlayerInCreator = true
Config.HideHudInCreator = true
Config.CreatorCoords = nil -- if nil, use current player location
Config.UseCreatorBucket = false -- standalone default false
```

---

## Ped Handling

When opening the creator:
1. Detect whether the player is already `mp_m_freemode_01` or `mp_f_freemode_01`.
2. If not, switch them to the configured default freemode model.
3. Support male/female switching from the UI.
4. After changing model, reset default components safely.
5. Keep health, armor, position, and heading where possible.
6. Freeze the player if configured.
7. Make the ped visible and collision-safe.

Use safe model loading with timeout handling:
- `RequestModel`
- `HasModelLoaded`
- `SetPlayerModel`
- `SetModelAsNoLongerNeeded`

Do not leave the player stuck if model loading fails.

---

## Addon Clothing Detection

This is the most important feature.

The system must detect and read addon clothing that is streamed into the server, including custom collections.

Use collection-based natives whenever available:
- `GET_PED_COLLECTIONS_COUNT`
- `GET_PED_COLLECTION_NAME`
- `GET_NUMBER_OF_PED_COLLECTION_DRAWABLE_VARIATIONS`
- `GET_NUMBER_OF_PED_COLLECTION_TEXTURE_VARIATIONS`
- `GET_NUMBER_OF_PED_COLLECTION_PROP_DRAWABLE_VARIATIONS`
- `GET_NUMBER_OF_PED_COLLECTION_PROP_TEXTURE_VARIATIONS`
- `SET_PED_COLLECTION_COMPONENT_VARIATION`
- `SET_PED_COLLECTION_PROP_INDEX`
- `CLEAR_PED_PROP`
- `IS_PED_COLLECTION_COMPONENT_VARIATION_VALID`

The menu must not rely only on global indexes because addon clothing global indexes can shift after GTA/FiveM game updates.

Create a client-side clothing scanner that builds a data table for the current freemode ped.

Scan all ped clothing components:

```lua
Components = {
    { id = 0, name = 'Face' },
    { id = 1, name = 'Mask' },
    { id = 2, name = 'Hair' },
    { id = 3, name = 'Arms' },
    { id = 4, name = 'Pants' },
    { id = 5, name = 'Bags' },
    { id = 6, name = 'Shoes' },
    { id = 7, name = 'Accessories' },
    { id = 8, name = 'Undershirt' },
    { id = 9, name = 'Body Armor' },
    { id = 10, name = 'Decals' },
    { id = 11, name = 'Tops' }
}
```

Scan all props:

```lua
Props = {
    { id = 0, name = 'Hats' },
    { id = 1, name = 'Glasses' },
    { id = 2, name = 'Ears' },
    { id = 6, name = 'Watches' },
    { id = 7, name = 'Bracelets' }
}
```

For every component and prop:
1. Loop through all collections available to the current ped.
2. Read collection names.
3. For each collection, get drawable count.
4. For each drawable, get texture count.
5. Store valid results only.
6. Return data to NUI in clean JSON format.

Expected clothing data format:

```lua
{
    components = {
        [11] = {
            name = 'Tops',
            collections = {
                {
                    collection = '',
                    label = 'Base Game',
                    drawables = {
                        { drawable = 0, textures = 3 },
                        { drawable = 1, textures = 5 }
                    }
                },
                {
                    collection = 'my_custom_pack',
                    label = 'my_custom_pack',
                    drawables = {
                        { drawable = 0, textures = 2 }
                    }
                }
            }
        }
    },
    props = {}
}
```

Also include fallback support using old global-index natives if collection natives fail:
- `GetNumberOfPedDrawableVariations`
- `GetNumberOfPedTextureVariations`
- `SetPedComponentVariation`
- `GetNumberOfPedPropDrawableVariations`
- `GetNumberOfPedPropTextureVariations`
- `SetPedPropIndex`

Fallback mode should still work for base game clothes, but collection mode should be preferred for addon clothing.

---

## Live Clothing Preview

The UI must preview changes live when the player selects clothing.

NUI callbacks required:

```lua
RegisterNUICallback('getCreatorData', function(data, cb) end)
RegisterNUICallback('setGender', function(data, cb) end)
RegisterNUICallback('setComponent', function(data, cb) end)
RegisterNUICallback('setProp', function(data, cb) end)
RegisterNUICallback('clearProp', function(data, cb) end)
RegisterNUICallback('rotatePed', function(data, cb) end)
RegisterNUICallback('setCameraView', function(data, cb) end)
RegisterNUICallback('zoomCamera', function(data, cb) end)
RegisterNUICallback('saveCharacter', function(data, cb) end)
RegisterNUICallback('closeCreator', function(data, cb) end)
```

Every NUI callback must always return `cb({ ok = true })` or `cb({ ok = false, error = 'message' })` so UI fetch requests never hang.

When setting clothing:
- Validate component id.
- Validate collection name.
- Validate drawable.
- Validate texture.
- Check if the variation is valid before applying.
- Apply the item instantly.
- Update local current appearance cache.

For props:
- Support clearing props with `ClearPedProp`.
- Support prop texture selection.
- Support collection-based props.

---

## UI Design

Create a luxury girly clothing-theme NUI with a premium boutique feel.

Style direction:
- Luxury pink glassmorphism theme with soft blush, hot pink, rose gold, white, and deep mauve accents
- Elegant boutique / fashion studio vibe, polished and feminine without looking childish
- Glossy translucent panels with rounded corners, soft shadows, and subtle sparkle/highlight details
- Pink gradient accents for buttons, sliders, active tabs, outlines, and selected clothing options
- Smooth hover states with soft glow effects and gentle scale transitions
- Lightweight animations such as fade-ins, slide panels, shimmer accents, and smooth tab switching
- Professional clothing-test-server feel designed for custom clothing previews and outfit building
- Mobile/responsive friendly enough for different resolutions
- Avoid dark blue accents; keep the full visual identity pink, blush, rose gold, and luxury fashion focused

Main UI layout:

```txt
Left Panel:
- Character Creator title
- Gender switch: Male / Female
- Search box
- Category tabs
  - Face
  - Hair
  - Mask
  - Tops
  - Undershirt
  - Arms
  - Pants
  - Shoes
  - Accessories
  - Bags
  - Armor
  - Decals
  - Hats
  - Glasses
  - Ears
  - Watches
  - Bracelets

Center:
- Game ped/camera view remains visible
- Small camera control hints overlay

Right Panel:
- Selected category
- Collection dropdown
- Drawable slider/input
- Texture slider/input
- Previous/Next buttons
- Randomize current category button
- Reset current category button

Bottom Bar:
- Save button
- Close button
- Rotate left/right buttons
- Camera view buttons: Full Body / Face / Torso / Legs / Feet
- Zoom controls
```

The NUI should use fetch calls like:

```js
fetch(`https://${GetParentResourceName()}/setComponent`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json; charset=UTF-8' },
  body: JSON.stringify(payload)
})
```

---

## Camera System

Create `client/camera.lua`.

When creator opens:
- Create a scripted camera facing the ped.
- Keep player ped centered.
- Hide gameplay HUD if configured.
- Freeze player if configured.
- Disable firing/combat controls while in creator.

Camera views:

```lua
Config.CameraViews = {
    full = { label = 'Full Body', offset = vec3(0.0, 2.5, 0.7), point = vec3(0.0, 0.0, 0.4), fov = 45.0 },
    face = { label = 'Face', offset = vec3(0.0, 0.9, 0.65), point = vec3(0.0, 0.0, 0.65), fov = 35.0 },
    torso = { label = 'Torso', offset = vec3(0.0, 1.4, 0.35), point = vec3(0.0, 0.0, 0.25), fov = 40.0 },
    legs = { label = 'Legs', offset = vec3(0.0, 1.8, -0.35), point = vec3(0.0, 0.0, -0.35), fov = 42.0 },
    feet = { label = 'Feet', offset = vec3(0.0, 1.2, -0.8), point = vec3(0.0, 0.0, -0.85), fov = 38.0 }
}
```

Functions required:

```lua
StartCreatorCamera(viewName)
StopCreatorCamera()
SetCreatorCameraView(viewName)
ZoomCreatorCamera(delta)
RotateCreatorPed(direction)
```

Camera must clean up properly on close/resource stop:
- `RenderScriptCams(false, true, 500, true, true)`
- `DestroyCam`
- restore focus
- unfreeze player
- re-enable controls
- restore HUD/radar

---

## Save System

Because this is standalone, do not require a database.

When the user clicks Save:
1. Save current appearance to client KVP using `SetResourceKvp` / `SetResourceKvpNoSync` if available.
2. Also trigger a server event with the appearance table so developers can hook into it later.
3. Add client export to get current appearance.
4. Add client export to apply an appearance table.

Required exports:

```lua
exports('OpenCreator', OpenCreator)
exports('CloseCreator', CloseCreator)
exports('GetCurrentAppearance', GetCurrentAppearance)
exports('ApplyAppearance', ApplyAppearance)
```

Server events:

```lua
RegisterNetEvent('wk-charactercreator:server:saveAppearance', function(appearance) end)
```

Client events:

```lua
RegisterNetEvent('wk-charactercreator:client:open', function(gender) end)
RegisterNetEvent('wk-charactercreator:client:close', function() end)
RegisterNetEvent('wk-charactercreator:client:applyAppearance', function(appearance) end)
```

Do not trust server event data blindly. Validate table size and types before processing.

---

## Appearance Data Format

Save appearance like this:

```lua
{
    model = 'mp_m_freemode_01',
    gender = 'male',
    components = {
        ['11'] = { component = 11, collection = 'custom_pack', drawable = 0, texture = 0, palette = 0 },
        ['4'] = { component = 4, collection = '', drawable = 10, texture = 1, palette = 0 }
    },
    props = {
        ['0'] = { prop = 0, collection = 'custom_hat_pack', drawable = 2, texture = 0 },
        ['1'] = { prop = 1, collection = '', drawable = -1, texture = 0, clear = true }
    }
}
```

---

## Performance Requirements

The scanner can be heavy if done badly. Optimize it.

Requirements:
- Scan only when opening creator or switching gender.
- Cache scanned data per model/gender.
- Do not scan every frame.
- Do not spam console.
- Use waits inside deep loops if necessary.
- UI should be responsive while large addon packs load.
- Show loading state in NUI while scanning.
- Add config option to cap scan limits in case a server has broken clothing packs.

Config options:

```lua
Config.Scan = {
    UseCollectionNatives = true,
    EnableFallbackGlobalScan = true,
    MaxDrawablesPerCollection = 1000,
    MaxTexturesPerDrawable = 50,
    YieldEvery = 100
}
```

---

## Error Handling

Add clear debug mode:

```lua
Config.Debug = false
```

Create debug print helper:

```lua
local function DebugPrint(...)
    if Config.Debug then print('[wk-charactercreator]', ...) end
end
```

Handle:
- Missing NUI callbacks
- Invalid clothing data
- Invalid gender
- Failed model load
- Camera cleanup failure
- Resource restart while menu is open
- Player death while menu is open

On `onClientResourceStop`, close UI and destroy camera if this resource stops.

---

## Input / Controls

While the menu is open:
- Disable attack
- Disable aim
- Disable weapon wheel
- Disable melee
- Disable pause combat inputs
- Allow mouse/UI focus

Use:

```lua
SetNuiFocus(true, true)
SetNuiFocusKeepInput(false)
```

On close:

```lua
SetNuiFocus(false, false)
SetNuiFocusKeepInput(false)
```

Add ESC key handling in UI that calls `closeCreator`.

---

## README Requirements

Create a clear README with:
- Resource description
- Install instructions
- `ensure wk-charactercreator`
- Commands
- Exports
- Events
- Config explanation
- Notes about addon clothing detection
- Troubleshooting section

Troubleshooting should include:
- Make sure addon clothing resources are started before `wk-charactercreator`.
- Make sure clothing packs stream correctly.
- If collection names do not appear, enable debug mode.
- If addon clothes do not show, confirm the clothes work on freemode peds.
- Global indexes may shift after game updates, so collection-based natives are preferred.

---

## Final Deliverable

Create all files. Do not leave placeholder code. The resource must run when added to a FiveM server and started with:

```cfg
ensure wk-charactercreator
```

After creating the files, review the code for syntax errors and confirm:
- Commands open the UI.
- Male/female switching works.
- NUI callbacks return responses.
- Camera starts and stops cleanly.
- Addon clothing collections are scanned.
- Components and props preview live.
- Save stores appearance locally.
- Resource stop cleanup works.

Build this as production-quality Lua + NUI code, not pseudocode.
