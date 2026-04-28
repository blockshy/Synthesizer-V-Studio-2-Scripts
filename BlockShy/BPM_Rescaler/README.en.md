# BPM Rescaler

## Purpose

Fixes note length and automation alignment when imported MIDI or track data was authored at a different BPM from the current project. The script rescales data in the current note group target by `current BPM / original BPM`.

It processes:

- Note onset and duration
- Automation tracks: `pitchDelta`, `vibratoEnv`, `loudness`, `tension`, `breathiness`, `voicing`, `gender`, plus a compatibility attempt for `toneShift`
- Synthesizer V Studio 2 pitch control points and pitch control curves

## Usage

1. Select the track or note group to process in Synthesizer V Studio 2.
2. Run `BPM Rescaler`.
3. Confirm the current project BPM, then enter the original BPM of the imported MIDI or track.
4. Choose a scaling anchor:
   - `Note group local 0`: keeps the note group local zero position fixed.
   - `First note onset`: keeps the first note fixed, useful when the group has leading silence.
5. Choose whether to rescale automation and Studio 2 pitch controls.
6. Click OK.

## Notes

- This script applies one global ratio. It is not a full tempo map conversion tool. It warns when the project contains multiple tempo marks.
- The script edits the current note group target. If that target is reused by multiple references, those references will change as well.
- Automation points that collapse onto the same blick are merged; later points overwrite earlier ones. The completion dialog reports the collision count.
- Objects scaled before zero are clamped to 0 blick.
