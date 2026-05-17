# Flatten Pitch Curve (SV1)

## Features

Clear/reset the `pitchDelta` curve over selected notes or selected note groups as an SV1/older-host pitch simplification pass. SV1 cannot write Synthesizer V Studio 2 Pitch Control Curves; use the SV2 version when you need horizontal Pitch Control Curves.

It can process:

- Selected notes: only the time ranges covered by the selected notes in the current note group.
- Selected note groups: the target time range covered by each selected group reference.
- Studio 2 Pitch Control Point / Curve objects are skipped.
- `pitchDelta`: can optionally remove old points in the range and write 0-cent boundary points as cleanup.

## Usage

1. Select notes in the piano roll, or select note groups in the arrangement.
2. Run `Flatten Pitch Curve (SV1)` from the script menu and fill in the dialog.
3. Choose the processing scope: selected notes, selected note groups, or both.
4. Choose whether to reset the `pitchDelta` curve.
5. Studio 2 Pitch Control options are skipped in SV1.
6. Click `OK`.

## Notes

- The script does not change note pitch, lyrics, duration, or position.
- This directory is the SV1/older-host version. Its static metadata exposes the traditional `main()` dialog entry and does not declare a side-panel type.
- For the SV2.1.2+ side-panel version, use `BlockShy/Flatten_Pitch_Curve_SV2/Flatten_Pitch_Curve_SV2.lua`.
- The SV1 version can only clean/reset `pitchDelta`; it cannot write Studio 2 Pitch Control Curves, so flattening is a fallback.
- By default, the script writes guard points next to the selected range to reduce changes outside the flattened area.
- When processing note groups, the script modifies the note group target. If the target is reused by multiple references, those references will change as well.
- Studio 2 Pitch Control APIs are only available in versions that support them; unsupported targets are skipped and reported in the completion message.
