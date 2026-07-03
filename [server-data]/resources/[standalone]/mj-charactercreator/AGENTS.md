# Repository Guidelines

## Project Structure & Module Organization

This repository is for a standalone FiveM character creator resource. Keep the resource root flat and FiveM-friendly:

- `fxmanifest.lua` declares the `cerulean` GTA V resource and NUI page.
- `config.lua` stores commands, scan limits, camera views, debug flags, and creator behavior.
- `client/` contains Lua runtime code: `main.lua`, `clothing.lua`, `camera.lua`, and `utils.lua`.
- `server/` contains server-side events and validation, starting with `main.lua`.
- `html/` contains the pure NUI frontend: `index.html`, `style.css`, and `app.js`.
- `README.md` documents install, commands, exports, events, and troubleshooting.

Do not add framework dependencies such as QBCore, Qbox, ESX, ox_lib, or database adapters unless the project scope changes.

## Build, Test, and Development Commands

There is no package manager or build step expected for the base resource. Use direct FiveM testing:

- `ensure mj-charactercreator` starts the resource using the deployed folder name.
- `/creator` opens the creator in-game.
- `/creator male`, `/creator female`, and `/creator close` test command arguments.

For quick syntax checks, use a local Lua parser if available, then validate behavior in a FiveM test server.

## Coding Style & Naming Conventions

Use 4-space indentation for Lua, HTML, CSS, and JavaScript. Prefer clear PascalCase for exported Lua functions such as `OpenCreator` and `ApplyAppearance`, and camelCase for JavaScript functions and variables. Keep NUI callback names stable and lower camelCase, for example `setComponent`, `clearProp`, and `saveCharacter`.

Keep Lua modules focused: camera behavior belongs in `client/camera.lua`, clothing scan/apply logic in `client/clothing.lua`, and shared helpers in `client/utils.lua`.

## Testing Guidelines

No automated test framework is currently configured. Manually verify each change on a FiveM test server. At minimum, confirm creator open/close, male/female switching, all NUI callbacks returning a response, camera cleanup, live component/prop preview, KVP save, and `onClientResourceStop` cleanup.

## Commit & Pull Request Guidelines

No Git history is available in this workspace, so use concise imperative commit messages such as `Add clothing collection scanner` or `Fix camera cleanup on close`. Pull requests should include a short behavior summary, manual test notes, screenshots or video for UI changes, and any addon clothing packs used during validation.

## Security & Configuration Tips

Validate all client and server event payloads before use. Keep `Config.Debug = false` by default, avoid console spam during scans, and cap drawable/texture loops with `Config.Scan` limits so broken clothing packs cannot stall the client.
