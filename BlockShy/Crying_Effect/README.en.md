# Crying Effect

## Purpose

Generates crying-style expression parameters for selected notes. The updated script includes ready-to-use crying presets and writes preset-driven vibrato, breathiness, tension, and pitch gestures.

It can write:

- `vibratoEnv`: strengthens the vibrato envelope around the middle or later part of each note, then restores the normal value at the boundaries.
- `breathiness`: writes a breathiness envelope using attack, peak, and release positions.
- `tension`: writes a tension envelope with optional controlled randomness.
- `pitchDelta`: optional crying pitch gesture with a small catch, dip, tail wobble, and relative tail drop.

## Presets

- `Light sob`: restrained, useful for subtle local expression.
- `Natural cry (Recommended)`: default preset, balancing vibrato, breathiness, tension, and light pitch movement.
- `Obvious cry`: clearer crying expression for emotional phrases.
- `Strong cry`: larger pitch movement, tension, and breathiness for exaggerated expression.
- `Tail sob`: focuses on note endings and defaults to applying the stronger tail drop only to the last note of each selected range.
- `Custom`: uses the advanced envelope and drop controls below.

## Usage

1. Select one or more notes in the piano roll.
2. Run `Crying Effect`.
3. Choose a crying preset. `Natural cry (Recommended)` is ready to use as the default.
4. Enable the modules to generate: vibrato envelope, breathiness, tension, and tail pitch drop.
5. Set preset strength and write mode.
6. If `Custom` is selected, adjust the envelope positions:
   - Attack position
   - Peak position
   - Release position
7. Configure tension randomness, fixed random output, pitch drop start, pitch drop depth, and whether pitch drop should apply only to the last note of each selected range.
8. Click OK.

## Write Modes

- `Overwrite selected note ranges`: default. Removes old points for enabled parameters inside selected note ranges, then writes the new result.
- `Append/update only`: keeps old points and only writes this run's points.
- `Clear enabled parameters and rebuild`: removes all old points from enabled parameters before writing this run's result.

## Notes

- Output values are clamped to the official automation range for each parameter.
- Fixed random output is enabled by default, making repeated runs more reproducible.
- Presets override the advanced envelope and drop values; the advanced sliders are mainly for the `Custom` preset.
- Pitch gestures are added relative to the current `pitchDelta` curve instead of forcing it back to zero.
- Pitch drop depth is multiplied by the preset strength and the preset's internal strength scale.
- The script writes into the current note group target. If that target is reused by multiple references, those references will change as well.
- `Restore pitch after tail` writes an extra point after the note end and can affect a following note, so use it only when appropriate.
