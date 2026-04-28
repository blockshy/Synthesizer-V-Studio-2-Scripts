# Crying Effect

## Purpose

Quickly adds a crying-style expression to selected notes. The script combines vibrato envelope, breathiness, tension, and an optional tail pitch drop.

It writes:

- `vibratoEnv`: increases vibrato depth
- `breathiness`: adds breathiness
- `tension`: adds tension with slight random variation
- `pitchDelta`: optional tail pitch drop

## Usage

1. Select one or more notes in the piano roll.
2. Run `Crying Effect`.
3. Adjust the intensity.
4. Enable `Sobbing Tail` if a tail pitch drop is desired.
5. Click OK.

## Notes

- The script writes automation points directly and does not automatically clear existing points in the selected region.
- The tension curve includes random variation, so repeated runs may produce slightly different results.
- Very short notes can receive dense parameter changes; manual cleanup may be useful afterward.
