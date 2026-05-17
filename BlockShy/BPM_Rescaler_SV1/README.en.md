# BPM Rescaler (SV1)

## Purpose

Fixes note length and automation alignment when imported MIDI or track data was authored at a different BPM from the current project. The script rescales data in the current note group target by `current BPM / original BPM`.

It processes:

- Note onset and duration
- Automation tracks: `pitchDelta`, `vibratoEnv`, `loudness`, `tension`, `breathiness`, `voicing`, `gender`, plus a compatibility attempt for `toneShift`
- Notes and automation curves available to SV1; Studio 2 pitch control points/curves are skipped

## Usage

1. Select the track or note group to process in Synthesizer V Studio.
2. Run `BPM Rescaler (SV1)` from the script menu and fill in the dialog.
3. Click `Detect BPM` to read the BPM at the current group reference.
4. Confirm `Current BPM`, then enter the original BPM of the imported MIDI or track.
5. Choose a scaling anchor:
   - `Note group local 0`: keeps the note group local zero position fixed.
   - `First note onset`: keeps the first note fixed, useful when the group has leading silence.
6. Choose whether to rescale automation; Studio 2 pitch controls are skipped in SV1.
7. Click `OK`.

## Notes

- This script applies one global ratio. It is not a full tempo map conversion tool. It warns when the project contains multiple tempo marks.
- This directory is the SV1/older-host version. Its static metadata exposes the traditional `main()` dialog entry and does not declare a side-panel type.
- For the SV2.1.2+ side-panel version, use `BlockShy/BPM_Rescaler_SV2/BPM_Rescaler_SV2.lua`.
- It can rescale notes and automation, but Studio 2 pitch control objects are skipped automatically.
- The script edits the current note group target. If that target is reused by multiple references, those references will change as well.
- Automation points that collapse onto the same blick are merged; later points overwrite earlier ones. The completion dialog reports the collision count.
- Objects scaled before zero are clamped to 0 blick.
