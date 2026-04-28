# Pitch to Parameter

## Purpose

Maps the pitch movement of selected notes into an automation parameter. It can convert melodic pitch or pitch bends into expressive controls such as tension, breathiness, gender, tone shift, or loudness.

Supported target parameters:

- Tension
- Breathiness
- Gender
- Tone Shift
- Loudness

## Usage

1. Select one or more notes in the piano roll.
2. Run `Pitch to Parameter`.
3. Choose the target parameter.
4. Choose the source mode:
   - `Full pitch follow`: melody pitch and pitch bends both affect the result.
   - `Pitch bend only`: ignores the melody pitch and follows only `pitchDelta`.
5. Choose the point density mode:
   - `Smart simplify`: keeps meaningful changes while reducing redundant points.
   - `Force linear`: writes only the start and end point for each note.
6. Set the center pitch, mapping strength, and direction, then click OK.

## Notes

- The script writes points directly into the target automation track and does not automatically clear existing points in the selected region.
- Parameters other than loudness are clamped to the `-1.0` to `1.0` range.
- `Tone Shift` availability depends on the Synthesizer V Studio version and voice database support.
