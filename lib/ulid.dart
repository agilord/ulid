// Copyright (c) 2017, Agilord. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Original implementation: https://github.com/alizain/ulid/
/// Specification: https://github.com/ulid/spec
library;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

final _defaultFactory = UlidFactory();
final _zoneFactoryKey = Object();

/// Lexicographically sortable, 128-bit identifier (UUID) with 48-bit timestamp
/// and 80 random bits. Canonically encoded as a 26-character string, as opposed
/// to the 36-character UUID.
class Ulid implements Comparable<Ulid> {
  final Uint8List _data;
  int? _hashCode;

  Ulid._(this._data) {
    assert(_data.length == 16);
  }

  /// Creates a [Ulid] instance, using the zone-local [UlidFactory] set by
  /// an enclosing [withFactory] call, or the shared default otherwise.
  ///
  /// [millis] must fit the 48-bit timestamp field (`0` to `2^48-1`).
  factory Ulid({int? millis}) {
    final factory =
        (Zone.current[_zoneFactoryKey] as UlidFactory?) ?? _defaultFactory;
    return factory.next(millis: millis);
  }

  /// Runs [body] with [factory] as the zone-local [UlidFactory] used by
  /// [Ulid()], without touching the shared default.
  ///
  /// Applies to [body] itself and anything scheduled from within it
  /// (`Future`s, microtasks, timers) that stays in the same zone.
  static R withFactory<R>(UlidFactory factory, R Function() body) {
    return runZoned(body, zoneValues: {_zoneFactoryKey: factory});
  }

  /// Parses the 26-character base32 (canonical or [toBase32]), the compact
  /// (32-character) or the full (36-character) UUID format. Accepts both
  /// upper- and lowercase input.
  factory Ulid.parse(String value) {
    if (value.length == 26) {
      return Ulid._parseBase32(value);
    } else if (value.length == 32) {
      return Ulid._parseHex16(value);
    } else if (value.length == 36) {
      final hasDashesInPlace = value[8] == '-' &&
          value[13] == '-' &&
          value[18] == '-' &&
          value[23] == '-';
      final withoutSlashes = value.replaceAll('-', '');
      if (hasDashesInPlace && withoutSlashes.length == 32) {
        return Ulid._parseHex16(withoutSlashes);
      }
    }
    throw ArgumentError('Unable to recognize format: $value');
  }

  /// Creates a new instance from the provided bytes buffer.
  factory Ulid.fromBytes(List<int> bytes) {
    if (bytes.length != 16 || bytes.any((b) => b > 255 || b < 0)) {
      throw ArgumentError.value(bytes, 'bytes', 'Invalid input.');
    }
    return Ulid._(Uint8List.fromList(bytes));
  }

  factory Ulid._parseBase32(String value) {
    final lc = value.toLowerCase();
    final data = Uint8List(16);
    final buffer = Uint8List(26);
    for (var i = 0; i < 26; i++) {
      final code = lc.codeUnitAt(i);
      final decoded = code < _base32Decode.length ? _base32Decode[code] : -1;
      if (decoded == -1) {
        throw FormatException('Invalid character in ULID.', value, i);
      }
      buffer[i] = decoded;
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

  /// Renders the 36- or 32-character UUID format (lowercase hex, unless
  /// [uppercase] is set).
  String toUuid({bool compact = false, bool uppercase = false}) {
    final sb = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (!compact && (i == 4 || i == 6 || i == 8 || i == 10)) {
        sb.write('-');
      }
      sb.write(_hex[_data[i] >> 4]);
      sb.write(_hex[_data[i] & 0x0F]);
    }
    final value = sb.toString();
    return uppercase ? value.toUpperCase() : value;
  }

  /// Renders the canonical, 26-character base32 format (lowercase).
  @Deprecated('The method will be removed, use toBase32 instead.')
  String toCanonical() => _toBase32Lower();

  /// Renders the 26-character base32 format in uppercase (unless [lowercase]
  /// is set), matching the representation used by the ULID specification.
  String toBase32({bool lowercase = false}) {
    final value = _toBase32Lower();
    return lowercase ? value : value.toUpperCase();
  }

  String _toBase32Lower() {
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

  /// Returns the millisecond component.
  int toMillis() {
    var millis = 0;
    for (var i = 0; i < 6; i++) {
      millis = (millis << 8) + _data[i];
    }
    return millis;
  }

  /// Returns the internals as bytes (copied buffer).
  Uint8List toBytes() {
    return Uint8List.fromList(_data);
  }

  /// Returns the lowercase, canonical 26-character format.
  ///
  /// Warning: a future major version will switch this to the uppercase
  /// [toBase32] representation used by the ULID specification. Call
  /// [toBase32] or [toCanonical] directly if your code depends on a
  /// specific casing.
  @override
  String toString() => _toBase32Lower();

  @override
  bool operator ==(other) {
    if (identical(this, other)) return true;
    if (other is Ulid) {
      for (var i = 0; i < _data.length; i++) {
        if (other._data[i] != _data[i]) return false;
      }
      return true;
    }

    return false;
  }

  @override
  int get hashCode => _hashCode ??= Object.hashAll(_data);

  @override
  int compareTo(Ulid other) {
    for (var i = 0; i < _data.length; i++) {
      final cmp = _data[i].compareTo(other._data[i]);
      if (cmp != 0) return cmp;
    }
    return 0;
  }

  void _encode(int inS, int inE, Uint8List buffer, int outS, int outE) {
    var value = 0;
    for (var i = inS; i <= inE; i++) {
      value = (value << 8) | _data[i];
    }
    for (var i = outE; i >= outS; i--) {
      buffer[i] = value & 0x1F;
      value = value >> 5;
    }
  }

  static void _decode(
      Uint8List buffer, int inS, int inE, Uint8List data, int outS, int outE) {
    var value = 0;
    for (var i = inS; i <= inE; i++) {
      value = (value << 5) | buffer[i];
    }
    for (var i = outE; i >= outS; i--) {
      data[i] = value & 0xFF;
      value = value >> 8;
    }
  }
}

/// Generates [Ulid] instances.
///
/// By default every [next] call draws a fresh 80-bit random value. With
/// [monotonic] set, a call whose timestamp does not exceed the last one
/// (same millisecond, or the clock went backwards) reuses the last
/// timestamp and increments the last random value instead, so IDs from
/// this factory always sort in call order (see the
/// [ULID spec](https://github.com/ulid/spec)'s monotonicity recommendation).
///
/// [monotonicRandomBits] keeps that many least-significant bits genuinely
/// random on every call instead of incrementing them; only the remaining,
/// most-significant `80 - N` bits act as the counter. Ordering is
/// unaffected, but a bigger tail means a smaller, sooner-overflowing
/// counter. [monotonicBufferBits] clears that many most-significant bits
/// of every freshly drawn random value, guaranteeing the counter that
/// amount of headroom before it can overflow (`1` guarantees at least half
/// of the counter's range is free; this is the usual practical setting).
///
/// Counter overflow throws a [StateError] by default; set
/// [incrementMillisOnOverflow] to advance the timestamp by 1ms and draw a
/// fresh random value instead.
///
/// A single [UlidFactory] instance is not safe to share across isolates,
/// but is safe to reuse across calls within the same isolate.
class UlidFactory {
  final bool _monotonic;
  final bool _incrementMillisOnOverflow;
  final int _monotonicRandomBits;
  final int _monotonicBufferBits;
  final Random _random;

  int? _lastMillis;
  Uint8List? _lastRandomBytes;

  /// Creates a new [UlidFactory].
  ///
  /// [random] overrides the default [Random.secure] source (used
  /// regardless of [monotonic]); the rest only matter when [monotonic] is
  /// `true` (see class docs): [incrementMillisOnOverflow],
  /// [monotonicRandomBits] and [monotonicBufferBits] (both `0` to `80`,
  /// and their sum must not exceed `80` — the buffer only reserves
  /// headroom within the counter, it must not reach into the random tail).
  UlidFactory({
    bool monotonic = false,
    bool incrementMillisOnOverflow = false,
    int monotonicRandomBits = 0,
    int monotonicBufferBits = 0,
    Random? random,
  })  : _monotonic = monotonic,
        _incrementMillisOnOverflow = incrementMillisOnOverflow,
        _monotonicRandomBits = monotonicRandomBits,
        _monotonicBufferBits = monotonicBufferBits,
        _random = random ?? Random.secure() {
    if (monotonicRandomBits < 0 || monotonicRandomBits > 80) {
      throw ArgumentError.value(monotonicRandomBits, 'monotonicRandomBits',
          'Must be between 0 and 80.');
    }
    if (monotonicBufferBits < 0 || monotonicBufferBits > 80) {
      throw ArgumentError.value(monotonicBufferBits, 'monotonicBufferBits',
          'Must be between 0 and 80.');
    }
    if (monotonicBufferBits + monotonicRandomBits > 80) {
      throw ArgumentError(
          'monotonicBufferBits ($monotonicBufferBits) + monotonicRandomBits '
          '($monotonicRandomBits) must not exceed 80: the buffer must stay '
          'within the counter and not reach into the random tail.');
    }
  }

  /// Creates a new [Ulid] instance.
  ///
  /// [millis] must fit the 48-bit timestamp field (`0` to `2^48-1`).
  Ulid next({int? millis}) {
    final ts = millis ?? DateTime.now().millisecondsSinceEpoch;
    if (ts < 0 || ts > 0xFFFFFFFFFFFF) {
      throw ArgumentError.value(
          millis, 'millis', 'Must be between 0 and 2^48-1.');
    }

    var effectiveMillis = ts;
    Uint8List randomBytes;

    final lastMillis = _lastMillis;
    if (_monotonic && lastMillis != null && ts <= lastMillis) {
      // Same millisecond, or the clock went backwards: keep the previous
      // timestamp and increment the previous random value to preserve
      // monotonic ordering.
      effectiveMillis = lastMillis;
      // Increment a copy: _incrementCounter mutates in place even when it
      // fails (overflow), so incrementing _lastRandomBytes directly would
      // corrupt the factory's state for later calls when this one throws.
      randomBytes = Uint8List.fromList(_lastRandomBytes!);
      if (_incrementCounter(randomBytes, _monotonicRandomBits)) {
        _randomizeTailBits(randomBytes, _monotonicRandomBits);
      } else {
        if (!_incrementMillisOnOverflow) {
          throw StateError('Monotonic counter overflow: exhausted the '
              '${80 - _monotonicRandomBits}-bit counter within the same '
              'millisecond.');
        }
        effectiveMillis++;
        if (effectiveMillis > 0xFFFFFFFFFFFF) {
          throw StateError('Monotonic millis overflow: exhausted the '
              '48-bit timestamp field.');
        }
        randomBytes = _freshRandomBytes();
      }
    } else {
      randomBytes = _freshRandomBytes();
    }

    if (_monotonic) {
      _lastMillis = effectiveMillis;
      _lastRandomBytes = randomBytes;
    }

    final data = Uint8List(16);
    var tsRemaining = effectiveMillis;
    for (var i = 5; i >= 0; i--) {
      data[i] = tsRemaining & 0xFF;
      tsRemaining = tsRemaining >> 8;
    }
    data.setRange(6, 16, randomBytes);
    return Ulid._(data);
  }

  Uint8List _freshRandomBytes() {
    final bytes = Uint8List(10);
    for (var i = 0; i < 10; i++) {
      bytes[i] = _random.nextInt(256);
    }
    if (_monotonic) {
      _clearLeadingBits(bytes, _monotonicBufferBits);
    }
    return bytes;
  }

  /// Zeros the most-significant [bufferBits] bits of the 80-bit,
  /// big-endian [bytes], reserving that much headroom for [_incrementCounter].
  static void _clearLeadingBits(Uint8List bytes, int bufferBits) {
    if (bufferBits <= 0) return;
    final fullBytes = bufferBits ~/ 8;
    final remainderBits = bufferBits % 8;
    for (var i = 0; i < fullBytes; i++) {
      bytes[i] = 0;
    }
    if (remainderBits > 0) {
      bytes[fullBytes] &= 0xFF >> remainderBits;
    }
  }

  /// Increments the most-significant `80 - [randomBits]` bits of the
  /// 80-bit, big-endian [bytes] by 1, leaving the least-significant
  /// [randomBits] bits untouched. Returns `false` if the counter portion
  /// was already at its maximum value (in which case its bits are left as
  /// all zeros; the untouched [randomBits] bits are unaffected either way).
  static bool _incrementCounter(Uint8List bytes, int randomBits) {
    if (randomBits >= 80) {
      return false; // no counter bits to increment
    }
    final bitPos = randomBits % 8;
    var i = 9 - randomBits ~/ 8;
    var addend = 1 << bitPos;
    for (; i >= 0; i--) {
      final sum = bytes[i] + addend;
      if (sum > 0xFF) {
        bytes[i] = sum & 0xFF;
        addend = 1;
      } else {
        bytes[i] = sum;
        return true;
      }
    }
    return false;
  }

  /// Overwrites the least-significant [randomBits] bits of the 80-bit,
  /// big-endian [bytes] with fresh random bits, leaving the remaining,
  /// most-significant bits untouched.
  void _randomizeTailBits(Uint8List bytes, int randomBits) {
    if (randomBits <= 0) return;
    final fullBytes = randomBits ~/ 8;
    final remainderBits = randomBits % 8;
    final firstFullByte = 10 - fullBytes;
    for (var i = firstFullByte; i < 10; i++) {
      bytes[i] = _random.nextInt(256);
    }
    if (remainderBits > 0) {
      final boundaryIndex = firstFullByte - 1;
      final randomMask = (1 << remainderBits) - 1;
      final keepMask = ~randomMask & 0xFF;
      bytes[boundaryIndex] = (bytes[boundaryIndex] & keepMask) |
          (_random.nextInt(256) & randomMask);
    }
  }
}

// https://en.wikipedia.org/wiki/Base32
const _hex16 = '0123456789abcdef';
final _crockfordBase32 = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'.toLowerCase();

final List<String> _hex = List<String>.generate(16, (int i) => _hex16[i]);
final List<String> _base32 =
    List<String>.generate(32, (int i) => _crockfordBase32[i]);

final List<int> _lowercaseCodes =
    List<int>.generate(32, (int i) => _crockfordBase32[i].codeUnits.first);
final List<int> _base32Decode =
    List<int>.generate(256, (int i) => _lowercaseCodes.indexOf(i));
