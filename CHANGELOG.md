# Changelog

## 2.2.0

- Improved performance in various places.
- `Comparable<Ulid>`
- `UlidFactory` for using custom `Random` and/or monotonic increments,
  with customizable options on the monotonic counter's range and randomness.
- `Ulid()` constructor will use a Zone-local or falls back to the default factory.

## 2.1.0

- Fixed minor correctness bugs, invalid ULID string will throw `FormatException`.
- Added `Ulid.toBase32()`: uppercase, spec-aligned 26-character format, with an
  optional `lowercase` parameter. Added a matching `uppercase` parameter to
  `Ulid.toUuid()`.
- Clarified method docs on which format and casing each `toXxx()` method emits.
- `Ulid.parse` doc clarifies it accepts both upper- and lowercase input (unchanged behavior).
- Deprecated `Ulid.toCanonical()` in favor of `Ulid.toBase32()`; it will be removed
  in a future major version.
- **Warning**: `Ulid.toString()` currently returns the lowercase canonical format,
  but a future major version will switch it to the uppercase `toBase32()`
  format. Call `toBase32()` or `toCanonical()` explicitly if your code depends
  on a specific casing.

## 2.0.2

- Updated lints and readme.

## 2.0.1

- Updated lints.

## 2.0.0

- Migrate to null safety. ([#10](https://github.com/agilord/ulid/pull/10) by [ChristianGaertner](https://github.com/ChristianGaertner))

## 1.1.0

- Updated code to 2.7 Dart and latest `pedantic` lints. 
- Added `Ulid.toBytes` and `Ulid.fromBytes`.

## 1.0.4

- implement `operator ==` and `hashCode`

## 1.0.3

- Fixed bit loss in browser's int handling.

## 1.0.2

- Using `package:pedantic`.
- Removed leftover `main` method.

## 1.0.1

- Declared support for Dart 2.
- Upgraded dependencies.

## 1.0.0

- First public version.
