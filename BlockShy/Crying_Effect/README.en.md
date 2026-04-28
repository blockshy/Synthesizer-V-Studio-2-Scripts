# Crying Effect

## Purpose

Generates crying-style expression parameters for selected notes. The updated script writes configurable envelopes for vibrato, breathiness, and tension, with an optional tail pitch drop relative to the current `pitchDelta` value.

It can write:

- `vibratoEnv`: strengthens the vibrato envelope around the middle or later part of each note, then restores the normal value at the boundaries.
- `breathiness`: writes a breathiness envelope using attack, peak, and release positions.
- `tension`: writes a tension envelope with optional controlled randomness.
- `pitchDelta`: optional tail pitch drop based on the current `pitchDelta` value at the drop start, instead of forcing the curve to zero.

## Usage

1. Select one or more notes in the piano roll.
2. Run `Crying Effect`.
3. Set the intensity and write mode.
4. Enable the modules to generate: vibrato envelope, breathiness, tension, and tail pitch drop.
5. Adjust the envelope positions:
   - Attack position
   - Peak position
   - Release position
6. Configure tension randomness, fixed random output, pitch drop start, pitch drop depth, and whether pitch drop should apply only to the last note of each selected range.
7. Click OK.

## Write Modes

- `Overwrite selected note ranges`: default. Removes old points for enabled parameters inside selected note ranges, then writes the new result.
- `Append/update only`: keeps old points and only writes this run's points.
- `Clear enabled parameters and rebuild`: removes all old points from enabled parameters before writing this run's result.

## Notes

- Output values are clamped to the official automation range for each parameter.
- Fixed random output is enabled by default, making repeated runs more reproducible.
- Pitch drop depth is multiplied by intensity. For example, depth 150 and intensity 1.5 creates about a 225-cent drop.
- The script writes into the current note group target. If that target is reused by multiple references, those references will change as well.
- `Restore pitch after tail` writes an extra point after the note end and can affect a following note, so use it only when appropriate.
