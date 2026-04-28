# BlockShy Script Manager

A Synthesizer V Studio 2 side-panel script manager for browsing and running BlockShy scripts from one place.

## Features

- Shows a script manager in the Synthesizer V Studio 2.1.2+ Scripts side panel.
- Lists registered scripts in a compact selector.
- Shows each script's purpose, prerequisites, usage, and managed path.
- Shows the current selected-note, selected-group, and current-group status.
- Runs the original menu scripts through the `Run` button.

## Managed Scripts

- BPM Rescaler
- Pitch to Parameter
- Crying Effect

## Usage

1. Keep the `BlockShy` folder inside the Synthesizer V Studio scripts directory.
2. Open Synthesizer V Studio 2.1.2 or later.
3. Open the Scripts side panel and rescan scripts.
4. Select `BlockShy Script Manager`.
5. Pick a script, review its description, then click `Run`.

## Notes

- The manager uses an explicit registry and does not scan arbitrary directories.
- Managed scripts still keep their original top-menu Scripts entries.
- The manager loads scripts from registered paths; update the registry if script folders are moved.
- `SV:finish()` inside loaded menu scripts is ignored in the manager environment so the side-panel script remains active.

