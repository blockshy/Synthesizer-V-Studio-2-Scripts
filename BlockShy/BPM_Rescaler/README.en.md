# BPM Rescaler

## Purpose

Fixes note length and automation alignment when imported MIDI or track data was authored at a different BPM from the current project. The script rescales data in the current note group target by `current BPM / original BPM`.

It processes:

- Note onset and duration
- Automation tracks: `pitchDelta`, `vibratoEnv`, `loudness`, `tension`, `breathiness`, `voicing`, `gender`, plus a compatibility attempt for `toneShift`
- Synthesizer V Studio 2 pitch control points and pitch control curves

## Usage

1. Select the track or note group to process in Synthesizer V Studio.
2. SV2.1.2+: open the `BPM Rescaler` panel in the Scripts side panel. SV1/older versions: run `BPM Rescaler` from the script menu and fill in the legacy dialog.
3. Click `Detect BPM` to read the BPM at the current group reference.
4. Confirm `Current BPM`, then enter the original BPM of the imported MIDI or track.
5. Choose a scaling anchor:
   - `Note group local 0`: keeps the note group local zero position fixed.
   - `First note onset`: keeps the first note fixed, useful when the group has leading silence.
6. Choose whether to rescale automation and Studio 2 pitch controls.
7. In SV2, click `Run`; in the SV1 dialog, click `OK`.

## Notes

- This script applies one global ratio. It is not a full tempo map conversion tool. It warns when the project contains multiple tempo marks.
- Synthesizer V Studio 2.1.2+ runs this as a side-panel script; SV1/older versions run it through a legacy `main()` dialog.
- SV1 compatibility mode can rescale notes and automation, but Studio 2 pitch control objects are skipped automatically.
- The panel title and UI text can switch between Chinese and English and default to Chinese; the host sidebar script-list name comes from static metadata and cannot follow the in-panel switch in real time.
- The panel shows the full controls by default; the purpose/usage text is hidden by default and can be opened with `Show purpose & usage`.
- The script edits the current note group target. If that target is reused by multiple references, those references will change as well.
- Automation points that collapse onto the same blick are merged; later points overwrite earlier ones. The completion dialog reports the collision count.
- Objects scaled before zero are clamped to 0 blick.
