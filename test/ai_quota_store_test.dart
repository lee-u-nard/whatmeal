import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/services/ai_quota_store.dart';

void main() {
  test('reservation consumes capacity before dispatch and cannot exceed limit',
      () async {
    final db = FakeFirebaseFirestore();
    final store = AiQuotaStore(db, now: () => DateTime(2026, 10, 5));
    expect(await store.remaining('a', 2), 2);
    expect(await store.reserve('a', 2), 1);
    expect(await store.reserve('a', 2), 0);
    expect(await store.reserve('a', 2), isNull);
    expect(await store.remaining('a', 2), 0);
    expect(await store.remaining('b', 2), 2);
  });
  test('day rollover resets the existing schema', () async {
    final db = FakeFirebaseFirestore();
    await db
        .doc('users/a/usageCounters/daily')
        .set({'date': '2026-10-04', 'count': 10});
    final store = AiQuotaStore(db, now: () => DateTime(2026, 10, 5));
    expect(await store.reserve('a', 10), 9);
    expect((await db.doc('users/a/usageCounters/daily').get()).data(),
        {'date': '2026-10-05', 'count': 1});
  });
  test('malformed current counter fails closed', () async {
    final db = FakeFirebaseFirestore();
    await db
        .doc('users/a/usageCounters/daily')
        .set({'date': '2026-10-05', 'count': -1});
    final store = AiQuotaStore(db, now: () => DateTime(2026, 10, 5));
    await expectLater(store.reserve('a', 10), throwsStateError);
  });
}
