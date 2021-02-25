// Copyright (c) 2017, Agilord. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Lexicographically sortable, 128-bit identifier (UUID) with 48-bit timestamp
/// and 80 random bits. Canonically encoded as a 26 character string.
///
/// Original implementation: https://github.com/alizain/ulid/
library ulid;

import 'dart:math';
import 'dart:typed_data';

Random _random = Random.secure();

/// Lexicographically sortable, 128-bit identifier (UUID) with 48-bit timestamp
/// and 80 random bits. Canonically encoded as a 26 character string, as opposed
/// to the 36 character UUID.
class Ulid {
  final Uint8List _data;

  Ulid._(this._data) {
    assert(_data.length == 16);
  }

  /// Create a  [Ulid] instance.
  factory Ulid({int? millis}) {
    final data = Uint8List(16);
    var ts = millis ?? DateTime.now().millisecondsSinceEpoch;
    for (var i = 5; i >= 0; i--) {
      data[i] = ts & 0xFF;
      ts = ts >> 8;
    }
    for (var i = 6; i < 16; i++) {
      data[i] = _random.nextInt(256);
    }
    return Ulid._(data);
  }

  /// Parse the canonical or the UUID format.
  factory Ulid.parse(String value) {
    if (value.length == 26) {
      return Ulid._parseBase32(value);
    } else if (value.length == 32) {
      return Ulid._parseHex16(value);
    } else if (value.length == 36) {
      // TODO: assert dash positions
      final withoutSlashes = value.replaceAll('-', '');
      if (withoutSlashes.length == 32) return Ulid._parseHex16(withoutSlashes);
    }
    throw ArgumentError('Unable to recognize format: $value');
  }

  /// Creates a new instance form the provided bytes buffer.
  factory Ulid.fromBytes(List<int> bytes) {
    if (bytes.length != 16 || bytes.any((b) => b > 256 || b < 0)) {
      throw ArgumentError.value(bytes, 'bytes', 'Invalid input.');
    }
    return Ulid._(Uint8List.fromList(bytes));
  }

  factory Ulid._parseBase32(String value) {
    final lc = value.toLowerCase();
    final data = Uint8List(16);
    final buffer = Uint8List(26);
    for (var i = 0; i < 26; i++) {
      buffer[i] = _base32Decode[lc.codeUnitAt(i)];
    }
    _decode(buffer, 0, 9, data, 0, 5); // time
    _decode(buffer, 10, 17, data, 6, 10); // random higher 40 bit
    _decode(buffer, 18, 25, data, 11, 15); // random lower 40 bit
    return Ulid._(data);
  }

  factory Ulid._parseHex16(String value) {
    final data = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      data[i] = int.parse(value.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return Ulid._(data);
  }

  /// Render the 36- or 32-character UUID format.
  String toUuid({bool compact = false}) {
    final sb = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (!compact && (i == 4 || i == 6 || i == 8 || i == 10)) {
        sb.write('-');
      }
      sb.write(_hex[_data[i] >> 4]);
      sb.write(_hex[_data[i] & 0x0F]);
    }
    return sb.toString();
  }

  /// Render the canonical, 26-character format.
  String toCanonical() {
    final result = Uint8List(26);
    _encode(0, 5, result, 0, 9); // time
    _encode(6, 10, result, 10, 17); // random upper 40-bit
    _encode(11, 15, result, 18, 25); // random lower 40-bit
    final sb = StringBuffer();
    for (var i = 0; i < 26; i++) {
      sb.write(_base32[result[i]]);
    }
    return sb.toString();
  }

  /// Get the millisecond component.
  int toMillis() {
    var millis = 0;
    for (var i = 0; i < 6; i++) {
      millis = (millis << 8) + _data[i];
    }
    return millis;
  }

  /// Get the internals as bytes (copied buffer).
  Uint8List toBytes() {
    return Uint8List.fromList(_data);
  }

  @override
  String toString() => toCanonical();

  @override
  bool operator ==(other) {
    if (other is Ulid) {
      for (var i = 0; i < _data.length; i++) {
        if (other._data[i] != _data[i]) return false;
      }
      return true;
    }

    return false;
  }

  @override
  int get hashCode => _data.join().hashCode;

  void _encode(int inS, int inE, Uint8List buffer, int outS, int outE) {
    var value = BigInt.from(0);
    for (var i = inS; i <= inE; i++) {
      value = (value << 8) + BigInt.from(_data[i]);
    }
    for (var i = outE; i >= outS; i--) {
      buffer[i] = value.toInt() & 0x1F;
      value = value >> 5;
    }
  }

  static void _decode(
      Uint8List buffer, int inS, int inE, Uint8List data, int outS, int outE) {
    var value = BigInt.from(0);
    for (var i = inS; i <= inE; i++) {
      value = (value << 5) + BigInt.from(buffer[i]);
    }
    for (var i = outE; i >= outS; i--) {
      data[i] = value.toInt() & 0xFF;
      value = value >> 8;
    }
  }
}

// https://en.wikipedia.org/wiki/Base32
String _hex16 = '0123456789abcdef';
String _crockfordBase32 = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'.toLowerCase();

List<String> _hex = List<String>.generate(16, (int i) => _hex16[i]);
List<String> _base32 =
    List<String>.generate(32, (int i) => _crockfordBase32[i]);

List<int> _lowercaseCodes =
    List<int>.generate(32, (int i) => _crockfordBase32[i].codeUnits.first);
List<int> _base32Decode =
    List<int>.generate(256, (int i) => _lowercaseCodes.indexOf(i));
