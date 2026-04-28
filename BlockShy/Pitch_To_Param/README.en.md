# Pitch to Parameter

## Purpose

Maps pitch information from selected notes into a target automation parameter. It can convert melody pitch, pitch bends, or Synthesizer V Studio 2 computed pitch into expressive controls such as tension, breathiness, gender, voicing, vibrato envelope, or loudness.

The side-panel UI shows built-in candidate parameters and validates the target parameter against the current note group when it runs. Built-in candidates include:

- Tension
- Breathiness
- Gender
- Voicing
- Vibrato Envelope
- Loudness
- Tone Shift, as a compatibility attempt

A custom parameter name can also be entered to try parameters supported by the current Synthesizer V Studio version or voice database.

## Usage

1. Select one or more notes in the piano roll.
2. SV2.1.2+: open the `Pitch to Parameter` panel in the Scripts side panel. SV1/older versions: run `Pitch to Parameter` from the script menu and fill in the legacy dialog.
3. Choose a target parameter, or enter a custom parameter name.
4. Choose the pitch source:
   - `Lightweight: note pitch + pitchDelta`: fast; includes note pitch, note detune, note group pitch offset, and `pitchDelta`.
   - `PitchDelta only`: ignores melody pitch and maps only pitch bends.
   - `Computed pitch`: uses Synthesizer V Studio 2 computed pitch for a closer match to the actual sung pitch. If computed pitch is unavailable, the script warns or falls back per sample.
5. Choose the point density:
   - `Smart simplify`: samples by the selected interval, then removes redundant points by linear-error simplification.
   - `Keep all samples`: writes every sampled point.
   - `Force linear`: writes only the start and end point of each note.
6. Choose the write mode:
   - `Overwrite selected note ranges`: default; removes old target points inside selected note ranges first.
   - `Append/update only`: keeps old points and only writes new points.
   - `Clear target parameter and rebuild`: removes all old target points before writing this result.
7. Set sample interval, simplification threshold, center pitch, strength, and direction.
8. Click `Refresh` to update the suggested center pitch from the current selection.
9. In SV2, click `Run`; in the SV1 dialog, click `OK`.

## Notes

- Output values are clamped using the target parameter's official automation range instead of a fixed `-1.0` to `1.0` range.
- Synthesizer V Studio 2.1.2+ runs this as a side-panel script; SV1/older versions run it through a legacy `main()` dialog.
- SV1 compatibility mode does not offer `Computed pitch (Studio 2)`; it only offers lightweight pitch and PitchDelta-only sources.
- The panel title and UI text can switch between Chinese and English and default to Chinese; the host sidebar script-list name comes from static metadata and cannot follow the in-panel switch in real time.
- The panel shows the full controls by default; the purpose/usage text is hidden by default and can be opened with `Show purpose & usage`.
- The default write mode clears old target points inside selected note ranges, which makes repeated runs more predictable.
- `Computed pitch` depends on Synthesizer V Studio pitch calculation state. The completion dialog reports any fallback samples.
- The script writes into the current note group target. If that target is reused by multiple references, those references will change as well.
- `Tone Shift` and custom parameter availability depends on the Synthesizer V Studio version and voice database support.
