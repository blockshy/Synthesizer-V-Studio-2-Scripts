# BlockShy Script Manager

A Synthesizer V Studio 2 side-panel script manager for browsing and running BlockShy scripts from one place.

## Features

- Shows a script manager in the Synthesizer V Studio 2.1.2+ Scripts side panel.
- Lists registered scripts in a compact selector.
- Shows each script's purpose, prerequisites, usage, and managed path.
- Shows the current selected-note, selected-group, and current-group status.
- Runs the embedded same-version script source through the `Run` button.
- Generates the manager index from the `BlockShy` directory with `tools/sync_script_manager.lua`.

## Managed Scripts

- BPM Rescaler
- Crying Effect
- Pitch to Parameter

## Usage

1. Keep the `BlockShy` folder inside the Synthesizer V Studio scripts directory.
2. Open Synthesizer V Studio 2.1.2 or later.
3. Open the Scripts side panel and rescan scripts.
4. Select `BlockShy Script Manager`.
5. Pick a script, review its description, then click `Run`.

## Adding Scripts

After adding a script folder, run:

```sh
lua tools/sync_script_manager.lua
```

The sync tool scans `BlockShy/*/*.lua`, skips side-panel scripts, reads `getClientInfo()`, `README.zh.md`, and `README.en.md`, then updates the manager's script list and embedded source.

Managed scripts must:

- Live under `BlockShy/Script_Folder/`.
- Provide `getClientInfo()`.
- Provide `main()`.
- Keep `README.zh.md` and `README.en.md` available in the same folder.

## Notes

- The manager uses a generated registry and does not scan arbitrary directories at Synthesizer V runtime.
- Managed scripts still keep their original top-menu Scripts entries.
- Side-panel execution uses embedded script source and does not depend on `loadfile()` or relative script directory paths.
- If a managed menu script changes behavior, rerun `lua tools/sync_script_manager.lua`.
- `SV:finish()` inside loaded menu scripts is ignored in the manager environment so the side-panel script remains active.
