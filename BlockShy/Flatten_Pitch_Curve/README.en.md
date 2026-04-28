# Flatten Pitch Curve

## Features

Flatten the pitch curve over selected notes or selected note groups. The script resets the `pitchDelta` automation curve to 0 cents and can optionally remove overlapping Synthesizer V Studio 2 pitch control points/curves.

It can process:

- Selected notes: only the time ranges covered by the selected notes in the current note group.
- Selected note groups: the target time range covered by each selected group reference.
- `pitchDelta`: removes old points in the range and writes 0-cent boundary points.
- Studio 2 pitch controls: removes overlapping Pitch Control Point / Curve objects.

## Usage

1. Select notes in the piano roll, or select note groups in the arrangement.
2. Run `Flatten Pitch Curve`.
3. Choose the processing scope: selected notes, selected note groups, or both.
4. Choose whether to flatten the `pitchDelta` curve.
5. Choose whether to remove Studio 2 pitch controls in the range.
6. Click OK to apply.

## Notes

- The script does not change note pitch, lyrics, duration, or position.
- `pitchDelta` is reset to 0 cents. Natural transitions, generated pitch, and generated vibrato are not `pitchDelta` automation points and may still remain.
- By default, the script writes guard points next to the selected range to reduce changes outside the flattened area.
- When processing note groups, the script modifies the note group target. If the target is reused by multiple references, those references will change as well.
- Studio 2 pitch control APIs are only available in versions that support them; unsupported targets are skipped and reported in the completion message.

