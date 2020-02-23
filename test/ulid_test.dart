// Copyright (c) 2017, Agilord. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:ulid/ulid.dart';
import 'package:test/test.dart';

void main() {
  test('length', () {
    final id = Ulid();
    expect(id.toCanonical(), hasLength(26));
    expect(id.toUuid(), hasLength(36));
    expect(id.toUuid(compact: true), hasLength(32));
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
}
