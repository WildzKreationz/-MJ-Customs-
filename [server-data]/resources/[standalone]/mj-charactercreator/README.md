# mj-charactercreator

Standalone FiveM freemode character creator for clothing test servers, addon clothing previews, and quick ped customization. It has no framework, inventory, or database dependency.

## Install

1. Place this folder in your server resources, for example `resources/[standalone]/mj-charactercreator`.
2. Ensure addon clothing resources start before this resource.
3. Add this to `server.cfg`:

```cfg
ensure mj-charactercreator
```

## Command

- `/creator` opens the creator using the current freemode gender when possible.
- `/creator male` switches to `mp_m_freemode_01` and opens the creator.
- `/creator female` switches to `mp_f_freemode_01` and opens the creator.
- `/creator close` closes the creator and restores camera/focus.

## Exports

```lua
exports['mj-charactercreator']:OpenCreator(gender)
exports['mj-charactercreator']:CloseCreator()
exports['mj-charactercreator']:GetCurrentAppearance()
exports['mj-charactercreator']:ApplyAppearance(appearance)
```

## Events

Client:

```lua
TriggerEvent('mj-charactercreator:client:open', gender)
TriggerEvent('mj-charactercreator:client:close')
TriggerEvent('mj-charactercreator:client:applyAppearance', appearance)
```

Server:

```lua
RegisterNetEvent('mj-charactercreator:server:saveAppearance', function(appearance) end)
AddEventHandler('mj-charactercreator:server:appearanceSaved', function(source, appearance) end)
```

## Configuration

Edit `config.lua` to change commands, default gender, freezing, HUD visibility, creator coordinates, camera views, scan caps, and debug logging. `Config.UseCreatorBucket` is off by default and can isolate players while editing if enabled.

## Addon Clothing Detection

The scanner prefers collection-based natives so addon clothing remains stable even when global drawable indexes shift after GTA/FiveM updates. Base game fallback scanning remains enabled through global component and prop natives.

Scanning runs only when the creator opens or gender changes, then caches results per model. Use `Config.Scan.MaxDrawablesPerCollection`, `MaxTexturesPerDrawable`, and `YieldEvery` to protect clients from broken or unusually large clothing packs.

## Saved Appearance

Saving writes the current appearance to client KVP under `mj_charactercreator_appearance` and triggers the server save event so developers can hook their own persistence later.

## Troubleshooting

- Start addon clothing resources before `mj-charactercreator`.
- Confirm clothing packs stream correctly and work on freemode peds.
- Enable `Config.Debug = true` if collection names or scanner results look wrong.
- If addon clothes do not appear, verify the pack exposes collection data and supports `mp_m_freemode_01` or `mp_f_freemode_01`.
- If the UI hangs on fetches, check F8 for NUI callback errors; every callback in this resource returns an `{ ok = ... }` response.
