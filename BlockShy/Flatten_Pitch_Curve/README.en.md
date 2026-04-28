# Flatten Pitch Curve

## Features

Flatten the pitch curve over selected notes or selected note groups. The script draws a fully horizontal Synthesizer V Studio 2 Pitch Control Curve for each target note, keeping the rendered pitch flat at the note's MIDI pitch.

It can process:

- Selected notes: only the time ranges covered by the selected notes in the current note group.
- Selected note groups: the target time range covered by each selected group reference.
- Horizontal Pitch Control Curves: creates one flat curve from note start to note end for each target note.
- Existing Studio 2 pitch controls: can first remove overlapping Pitch Control Point / Curve objects.
- `pitchDelta`: can optionally remove old points in the range and write 0-cent boundary points as cleanup.

## Usage

1. Select notes in the piano roll, or select note groups in the arrangement.
2. Open the `Flatten Pitch Curve` panel in the Scripts side panel.
3. Choose the processing scope: selected notes, selected note groups, or both.
4. Keep `Draw horizontal Studio 2 Pitch Control Curve` enabled.
5. Choose whether to also reset the `pitchDelta` curve.
6. Choose whether to first remove existing Studio 2 pitch controls in the range.
7. Click `Run`.

## Notes

- The script does not change note pitch, lyrics, duration, or position.
- This is a Synthesizer V Studio 2.1.2+ side-panel script and no longer runs from a top-menu modal dialog.
- The panel title and UI text can switch between Chinese and English and default to Chinese; the host sidebar script-list name comes from static metadata and cannot follow the in-panel switch in real time.
- The panel shows the full controls by default; the purpose/usage text is hidden by default and can be opened with `Show purpose & usage`.
- Resetting only `pitchDelta` is not enough to flatten SV2's generated pitch; the default behavior also writes horizontal Pitch Control Curves.
- By default, the script writes guard points next to the selected range to reduce changes outside the flattened area.
- When processing note groups, the script modifies the note group target. If the target is reused by multiple references, those references will change as well.
- Studio 2 Pitch Control APIs are only available in versions that support them; unsupported targets are skipped and reported in the completion message.
