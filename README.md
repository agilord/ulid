# Ulid implementation in Dart

Lexicographically sortable, 128-bit identifier (UUID) with 48-bit timestamp and 80 random bits.
Canonically encoded as a 26 character string, as opposed to the 36 character UUID.

Original implementation: https://github.com/alizain/ulid/

Specification: https://github.com/ulid/spec

## Usage

A simple usage example:

````dart
import 'package:ulid/ulid.dart';

void main() {
  print(Ulid());
  print(Ulid().toUuid());
  print(Ulid().toCanonical());
  print(Ulid().toBase32()); // uppercase, spec-aligned format
}
````

## Links

- [source code][source]
- contributors: [Agilord][agilord]

[source]: https://github.com/agilord/ulid
[agilord]: https://www.agilord.com/
