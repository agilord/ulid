# Ulid implementation in Dart

Lexicographically sortable, 128-bit identifier (UUID) with 48-bit timestamp and 80 random bits.
Canonically encoded as a 26 character string, as opposed to the 36 character UUID.

Original implementation: https://github.com/alizain/ulid/

## Usage

A simple usage example:

````dart
import 'package:ulid/ulid.dart';

main() {
  print(Ulid());
  print(Ulid().toUuid());
}
````

## Links

- [source code][source]
- contributors: [Agilord][agilord]

[source]: https://github.com/agilord/ulid
[agilord]: https://www.agilord.com/
