// Copyright (c) 2017, Agilord. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:ulid/ulid.dart';
import 'package:test/test.dart';

/// A [Random] stub that always returns the same byte for [nextInt].
class _FixedRandom implements Random {
  final int _value;
  _FixedRandom(this._value);

  @override
  int nextInt(int max) => _value;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

/// A [Random] stub that replays a fixed sequence of bytes for [nextInt].
class _SequenceRandom implements Random {
  final List<int> _values;
  var _index = 0;
  _SequenceRandom(this._values);

  @override
  int nextInt(int max) => _values[_index++ % _values.length];

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

void main() {
  test('length', () {
    final id = Ulid();
    expect(id.toCanonical(), hasLength(26));
    expect(id.toBase32(), hasLength(26));
    expect(id.toUuid(), hasLength(36));
    expect(id.toUuid(compact: true), hasLength(32));
  });

  test('toBase32 is uppercase, parses back to the same value', () {
    final id = Ulid();
    expect(id.toBase32(), id.toCanonical().toUpperCase());
    expect(Ulid.parse(id.toBase32()), id);
  });

  test('toBase32(lowercase: true) matches toCanonical', () {
    final id = Ulid();
    expect(id.toBase32(lowercase: true), id.toCanonical());
  });

  test('toUuid(uppercase: true) matches toUuid().toUpperCase()', () {
    final id = Ulid();
    expect(id.toUuid(uppercase: true), id.toUuid().toUpperCase());
    expect(
      id.toUuid(compact: true, uppercase: true),
      id.toUuid(compact: true).toUpperCase(),
    );
  });

  test('parse accepts mixed case', () {
    final id = Ulid.parse('01bj755t69g1r3e2c7fseyb102');
    expect(Ulid.parse('01BJ755T69G1R3E2C7FSEYB102'), id);
    expect(Ulid.parse('01Bj755T69g1R3e2C7fSeYb102'), id);
    expect(Ulid.parse('015C8E52-E8C9-8070-3709-877E5DE58402'), id);
    expect(Ulid.parse('015c8e52e8c980703709877e5de58402'.toUpperCase()), id);
  });

  test('fixed time', () {
    final id = Ulid(millis: 1469918176385);
    expect(id.toCanonical().substring(0, 10), '01aryz6s41');
    expect(id.toMillis(), 1469918176385);
  });

  test('parse compact', () {
    final id = Ulid.parse('01bj755t69g1r3e2c7fseyb102');
    expect(id.toCanonical(), '01bj755t69g1r3e2c7fseyb102');
    expect(id.toUuid(), '015c8e52-e8c9-8070-3709-877e5de58402');
    expect(id.toMillis(), 1497036417225);
  });

  test('parse uuid', () {
    final id = Ulid.parse('015c8e52-e8c9-8070-3709-877e5de58402');
    expect(id.toCanonical(), '01bj755t69g1r3e2c7fseyb102');
    expect(id.toUuid(), '015c8e52-e8c9-8070-3709-877e5de58402');
    expect(id.toMillis(), 1497036417225);
  });

  test('parse bytes', () {
    final bytes = [
      1,
      92,
      142,
      82,
      232,
      201,
      128,
      112,
      55,
      9,
      135,
      126,
      93,
      229,
      132,
      2,
    ];
    final id = Ulid.fromBytes(bytes);
    expect(id.toCanonical(), '01bj755t69g1r3e2c7fseyb102');
    expect(id.toUuid(), '015c8e52-e8c9-8070-3709-877e5de58402');
    expect(id.toMillis(), 1497036417225);
    expect(id.toBytes(), bytes);
  });

  test('operator ==', () {
    final ulid1 = Ulid();
    final ulid2 = Ulid.parse(ulid1.toCanonical());
    expect(ulid2, ulid1);
    expect(ulid1, isNot(Ulid()));
  });

  test('hashCode', () {
    final ulid1 = Ulid();
    final ulid2 = Ulid.parse(ulid1.toCanonical());

    expect(ulid2.hashCode, ulid1.hashCode);
    expect(ulid1, isNot(Ulid().hashCode));
  });

  test('hashCode does not collide on byte-boundary shifts', () {
    final a = Ulid.fromBytes([1, 23, ...List.filled(14, 0)]);
    final b = Ulid.fromBytes([12, 3, ...List.filled(14, 0)]);
    expect(a, isNot(b));
    expect(a.hashCode, isNot(b.hashCode));
  });

  test('fromBytes rejects out-of-range byte values', () {
    final bytes = List.filled(16, 0);
    expect(() => Ulid.fromBytes([...bytes]..[0] = 256), throwsArgumentError);
    expect(() => Ulid.fromBytes([...bytes]..[0] = -1), throwsArgumentError);
    expect(Ulid.fromBytes([...bytes]..[0] = 255), isNotNull);
  });

  test('parse rejects invalid base32 characters', () {
    expect(
        () => Ulid.parse('0ibj755t69g1r3e2c7fseyb102'), throwsFormatException);
    expect(
        () => Ulid.parse('01lj755t69g1r3e2c7fseyb102'), throwsFormatException);
    expect(
        () => Ulid.parse('01!j755t69g1r3e2c7fseyb102'), throwsFormatException);
  });

  test('parse rejects UUID strings with misplaced dashes', () {
    expect(Ulid.parse('015c8e52-e8c9-8070-3709-877e5de58402'), isNotNull);
    expect(() => Ulid.parse('015-c8e52e8c980703709877e5-de58402--'),
        throwsArgumentError);
    expect(() => Ulid.parse('0-15c8e52-e8c98070-3709877e5de58402'),
        throwsArgumentError);
  });

  test('Ulid() rejects out-of-range millis', () {
    expect(() => Ulid(millis: -1), throwsArgumentError);
    expect(() => Ulid(millis: (1 << 48)), throwsArgumentError);
    expect(Ulid(millis: 0), isNotNull);
    expect(Ulid(millis: (1 << 48) - 1), isNotNull);
  });

  group('UlidFactory', () {
    test('non-monotonic (default) draws fresh random bits every call', () {
      final factory = UlidFactory(random: Random(42));
      final a = factory.next(millis: 1000);
      final b = factory.next(millis: 1000);
      expect(a.toMillis(), 1000);
      expect(b.toMillis(), 1000);
      expect(a, isNot(b));
    });

    test('same seeded Random produces the same sequence', () {
      final factoryA = UlidFactory(random: Random(1234));
      final factoryB = UlidFactory(random: Random(1234));
      expect(factoryA.next(millis: 500), factoryB.next(millis: 500));
      expect(factoryA.next(millis: 500), factoryB.next(millis: 500));
    });

    test('monotonic increments the random part within the same millisecond',
        () {
      final factory = UlidFactory(monotonic: true);
      final a = factory.next(millis: 1000);
      final b = factory.next(millis: 1000);
      final c = factory.next(millis: 1000);
      expect(a.toMillis(), 1000);
      expect(b.toMillis(), 1000);
      expect(c.toMillis(), 1000);
      expect(a.compareTo(b), -1);
      expect(b.compareTo(c), -1);

      final aBytes = a.toBytes();
      final bBytes = b.toBytes();
      // random part (last 10 bytes) treated as a big-endian integer, +1
      var carry = 1;
      for (var i = 15; i >= 6 && carry > 0; i--) {
        final sum = aBytes[i] + carry;
        expect(bBytes[i], sum & 0xFF);
        carry = sum > 0xFF ? 1 : 0;
      }
    });

    test('monotonic draws fresh random bits when the millisecond changes', () {
      final factory = UlidFactory(monotonic: true);
      final a = factory.next(millis: 1000);
      final b = factory.next(millis: 1001);
      expect(a.compareTo(b), -1);
    });

    test(
        'monotonic clamps to the last timestamp when the clock goes '
        'backwards, and keeps incrementing the random part', () {
      final factory = UlidFactory(monotonic: true);
      final a = factory.next(millis: 2000);
      final b = factory.next(millis: 1000); // clock went backwards
      // the remembered (later) timestamp is reused, not the earlier one
      expect(a.toMillis(), 2000);
      expect(b.toMillis(), 2000);
      // call order is preserved despite the clock going backwards
      expect(a.compareTo(b), -1);

      final aBytes = a.toBytes();
      final bBytes = b.toBytes();
      var carry = 1;
      for (var i = 15; i >= 6 && carry > 0; i--) {
        final sum = aBytes[i] + carry;
        expect(bBytes[i], sum & 0xFF);
        carry = sum > 0xFF ? 1 : 0;
      }
    });

    test('non-monotonic ignores backwards clock jumps (no shared state)', () {
      final factory = UlidFactory();
      final a = factory.next(millis: 2000);
      final b = factory.next(millis: 1000);
      expect(a.toMillis(), 2000);
      expect(b.toMillis(), 1000);
    });

    test('monotonic throws on 80-bit random overflow by default', () {
      final factory = UlidFactory(monotonic: true, random: _FixedRandom(0xFF));
      factory.next(millis: 42); // fills random part with all 0xFF bytes
      expect(() => factory.next(millis: 42), throwsStateError);
    });

    test(
        'a caught overflow does not corrupt state for later calls '
        '(regression)', () {
      final factory = UlidFactory(monotonic: true, random: _FixedRandom(0xFF));
      final a = factory.next(millis: 42);
      expect(() => factory.next(millis: 42), throwsStateError);
      // the failed attempt must not have mutated the persisted counter: a
      // retry at the same millisecond has to overflow again, not silently
      // succeed with a small value that would sort before `a`
      expect(() => factory.next(millis: 42), throwsStateError);
      // once the millisecond genuinely advances, generation resumes fine
      final b = factory.next(millis: 43);
      expect(a.compareTo(b), lessThan(0));
    });

    test(
        'monotonic with incrementMillisOnOverflow advances the timestamp '
        'instead of throwing', () {
      final factory = UlidFactory(
        monotonic: true,
        incrementMillisOnOverflow: true,
        random: _FixedRandom(0xFF),
      );
      final a = factory.next(millis: 42); // fills random part with all 0xFF
      final b = factory.next(millis: 42); // would overflow -> bump millis
      expect(a.toMillis(), 42);
      expect(b.toMillis(), 43);
      expect(a.compareTo(b), -1);

      // the bumped millisecond gets a fresh (non-zero, since random is
      // fixed to 0xFF) random part rather than continuing the overflowed one
      expect(b.toBytes().sublist(6), List.filled(10, 0xFF));
    });

    test(
        'incrementMillisOnOverflow can push the timestamp past a real '
        'clock reading that has not caught up yet', () {
      final factory = UlidFactory(
        monotonic: true,
        incrementMillisOnOverflow: true,
        random: _FixedRandom(0xFF), // every fresh draw is immediately maxed
      );
      factory.next(millis: 42);
      final bumped = factory.next(millis: 42); // overflow -> bumped to 43
      expect(bumped.toMillis(), 43);
      // the wall clock still reads 42 on the next call, but the factory
      // must not go backwards relative to its own last output; since the
      // fixed random source is immediately maxed again, this also
      // overflows and bumps once more, to 44
      final next = factory.next(millis: 42);
      expect(next.toMillis(), 44);
      expect(bumped.compareTo(next), -1);
    });

    test(
        'monotonicRandomBits keeps the tail bits random and only '
        'increments the leading counter bits', () {
      final factory = UlidFactory(
        monotonic: true,
        monotonicRandomBits: 8, // last byte stays random, rest is counter
        random: _SequenceRandom([...List.filled(10, 0x10), 0x99]),
      );
      final a = factory.next(millis: 1000);
      final b = factory.next(millis: 1000);

      expect(a.toBytes().sublist(6), List.filled(10, 0x10));
      expect(
        b.toBytes().sublist(6),
        [...List.filled(8, 0x10), 0x11, 0x99],
      );
      // ordering is preserved: the counter byte dominates the comparison
      expect(a.compareTo(b), -1);
    });

    test('monotonicRandomBits shrinks the counter, so it overflows sooner', () {
      // only 8 bits (1 byte) left for the counter; a maxed-out fixed
      // random source starts that byte already at capacity
      final factory = UlidFactory(
        monotonic: true,
        monotonicRandomBits: 72,
        random: _FixedRandom(0xFF),
      );
      factory.next(millis: 42);
      expect(() => factory.next(millis: 42), throwsStateError);
    });

    test('monotonicRandomBits of 80 leaves no counter bits, always overflows',
        () {
      final factory = UlidFactory(monotonic: true, monotonicRandomBits: 80);
      factory.next(millis: 42);
      expect(() => factory.next(millis: 42), throwsStateError);
    });

    test('UlidFactory rejects out-of-range monotonicRandomBits', () {
      expect(() => UlidFactory(monotonicRandomBits: -1), throwsArgumentError);
      expect(() => UlidFactory(monotonicRandomBits: 81), throwsArgumentError);
      expect(UlidFactory(monotonicRandomBits: 0), isNotNull);
      expect(UlidFactory(monotonicRandomBits: 80), isNotNull);
    });

    test(
        'monotonicBufferBits reserves headroom by clearing leading bits of '
        'fresh draws', () {
      final factory = UlidFactory(
        monotonic: true,
        monotonicBufferBits: 1,
        random: _FixedRandom(0xFF),
      );
      final a = factory.next(millis: 42);
      // top bit of the leading random byte is cleared, rest stays maxed
      expect(a.toBytes().sublist(6), [0x7F, ...List.filled(9, 0xFF)]);

      // without the reserved headroom this would overflow immediately (as
      // in the "shrinks the counter" test above); with 1 buffer bit, at
      // least half the counter's range is guaranteed free
      final b = factory.next(millis: 42);
      expect(b.toBytes().sublist(6), [0x80, ...List.filled(9, 0x00)]);
      expect(a.compareTo(b), -1);
    });

    test('monotonicBufferBits clears leading bits on every fresh draw', () {
      final factory = UlidFactory(
        monotonic: true,
        monotonicBufferBits: 4,
        random: _FixedRandom(0xFF),
      );
      final a = factory.next(millis: 1);
      final b = factory.next(millis: 2); // new millisecond -> fresh draw
      expect(a.toBytes()[6] & 0xF0, 0);
      expect(b.toBytes()[6] & 0xF0, 0);
    });

    test('monotonicBufferBits has no effect when monotonic is false', () {
      final factory =
          UlidFactory(monotonicBufferBits: 8, random: _FixedRandom(0xFF));
      final a = factory.next(millis: 1);
      expect(a.toBytes().sublist(6), List.filled(10, 0xFF));
    });

    test('UlidFactory rejects out-of-range monotonicBufferBits', () {
      expect(() => UlidFactory(monotonicBufferBits: -1), throwsArgumentError);
      expect(() => UlidFactory(monotonicBufferBits: 81), throwsArgumentError);
      expect(UlidFactory(monotonicBufferBits: 0), isNotNull);
      expect(UlidFactory(monotonicBufferBits: 80), isNotNull);
    });

    test(
        'UlidFactory rejects monotonicBufferBits reaching into the '
        'monotonicRandomBits tail (regression)', () {
      // counter is only 80-8=72 bits wide; a 76-bit buffer would clear 4
      // bits that are supposed to always be random
      expect(
        () => UlidFactory(monotonicRandomBits: 8, monotonicBufferBits: 76),
        throwsArgumentError,
      );
      // exactly filling the counter width is fine
      expect(
        UlidFactory(monotonicRandomBits: 8, monotonicBufferBits: 72),
        isNotNull,
      );
    });

    test('Ulid() delegates to a shared default UlidFactory', () {
      final a = Ulid(millis: 1000);
      final b = Ulid(millis: 1000);
      expect(a.toMillis(), 1000);
      expect(a, isNot(b));
    });
  });

  group('Ulid.withFactory', () {
    test('scopes a factory to calls made inside the callback', () {
      final factory = UlidFactory(monotonic: true);
      late Ulid a, b;
      Ulid.withFactory(factory, () {
        a = Ulid(millis: 2000);
        b = Ulid(millis: 1999);
      });
      // only possible if the scoped, monotonic factory was actually used
      expect(a.compareTo(b), -1);
    });

    test('does not affect calls outside the callback', () {
      final factory = UlidFactory(monotonic: true);
      Ulid.withFactory(factory, () => Ulid(millis: 3000));
      final outside1 = Ulid(millis: 3000);
      final outside2 = Ulid(millis: 3000);
      // back to the (non-monotonic) default factory
      expect(outside1, isNot(outside2));
    });

    test('returns the callback\'s value', () {
      final result = Ulid.withFactory(UlidFactory(), () => 42);
      expect(result, 42);
    });

    test('applies to async code scheduled within the callback', () async {
      final factory = UlidFactory(monotonic: true);
      late Ulid a, b;
      await Ulid.withFactory(factory, () async {
        a = Ulid(millis: 5000);
        await Future<void>.delayed(Duration.zero);
        b = Ulid(millis: 5000);
      });
      expect(a.compareTo(b), -1);
    });

    test(
        'Ulid() is immune to unrelated zone values with a colliding name '
        '(regression)', () {
      // some other code in the same isolate scopes an unrelated value
      // under a same-looking key; Ulid() must not pick it up or crash
      late Ulid id;
      runZoned(() {
        id = Ulid(millis: 999);
      }, zoneValues: {#ulid_factory: 'unrelated value'});
      expect(id.toMillis(), 999);
    });
  });
}
