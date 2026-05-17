# Pitch to Parameter (SV1)

## Purpose

Maps pitch information from selected notes into a target automation parameter. It can convert melody pitch or pitch bends into expressive controls such as tension, breathiness, gender, voicing, vibrato envelope, or loudness.

The dialog shows built-in candidate parameters and validates the target parameter against the current note group when it runs. Built-in candidates include:

- Tension
- Breathiness
- Gender
- Voicing
- Vibrato Envelope
- Loudness
- Tone Shift

A custom parameter name can also be entered to try parameters supported by the current Synthesizer V Studio version or voice database. When entering a vocal-mode name such as `Cool` or `Dark`, the script automatically tries the corresponding `vocalMode_Cool` or `vocalMode_Dark` automation parameter; full `vocalMode_Name` type names can also be entered directly.

## Usage

1. Select one or more notes in the piano roll.
2. Run `Pitch to Parameter (SV1)` from the script menu and fill in the dialog.
3. Choose a target parameter, or enter a custom parameter name.
4. Choose the pitch source:
   - `Lightweight: note pitch + pitchDelta`: fast; includes note pitch, note detune, note group pitch offset, and `pitchDelta`.
   - `PitchDelta only`: ignores melody pitch and maps only pitch bends.
5. Choose the point density:
   - `Smart simplify`: samples by the selected interval, then removes redundant points by linear-error simplification.
   - `Keep all samples`: writes every sampled point.
   - `Force linear`: writes only the start and end point of each note.
6. Choose the write mode:
   - `Overwrite selected note ranges`: default; removes old target points inside selected note ranges first.
   - `Append/update only`: keeps old points and only writes new points.
   - `Clear target parameter and rebuild`: removes all old target points before writing this result.
7. Set sample interval, simplification threshold, center pitch, strength, and direction. Mapping strength is measured in target-parameter units per semitone, so large-range targets such as Tone Shift or vocal modes usually need larger strength values than tension or breathiness.
8. Click `OK`.

## Notes

- Output values are clamped using the target parameter's official automation range instead of a fixed `-1.0` to `1.0` range.
- This directory is the SV1/older-host version. Its static metadata exposes the traditional `main()` dialog entry and does not declare a side-panel type.
- For the SV2.1.2+ side-panel version and `Computed pitch (Studio 2)` source, use `BlockShy/Pitch_To_Param_SV2/Pitch_To_Param_SV2.lua`.
- The SV1 version only offers lightweight pitch and PitchDelta-only sources.
- The default write mode clears old target points inside selected note ranges, which makes repeated runs more predictable.
- The script writes into the current note group target. If that target is reused by multiple references, those references will change as well.
- The script validates the real target returned by `Automation:getType()` / `Automation:getDefinition()` to avoid accidentally writing to `pitchDelta` when a custom parameter name is unavailable.
- `Tone Shift` is written as an automation curve when the host exposes one. If the current host does not expose Tone Shift automation but supports `paramToneShift` through `NoteGroupReference:setVoice()`, the script writes the average generated value to the current note-group reference voice property instead. This fallback is not a time-varying curve, so write mode and selected-range cleanup do not apply.
- `vocalMode_Name` and other custom parameter availability depends on the Synthesizer V Studio version and voice database support.
