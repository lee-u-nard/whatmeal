import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/models/family.dart';
import 'package:whatmeal/core/services/family_service.dart';

Future<DocumentSnapshot<Map<String, dynamic>>> snapshot({
  required bool exists,
  required bool cached,
}) async {
  final doc = FakeFirebaseFirestore().doc('families/local-family');
  if (exists) {
    await doc.set({
      'name': 'Local household',
      'schemaVersion': 2,
      'createdBy': 'local',
    });
  }
  return doc.get(GetOptions(source: cached ? Source.cache : Source.server));
}

void main() {
  test(
      'uncached missing family is not falsely reported deleted; authoritative absence is',
      () async {
    final feed = StreamController<DocumentSnapshot<Map<String, dynamic>>>();
    final values = <Family?>[];
    final service = FamilyService(
        firestore: FakeFirebaseFirestore(), watchFamily: (_) => feed.stream);
    final subscription =
        service.familyStream('local-family').listen(values.add);
    feed.add(await snapshot(exists: false, cached: true));
    await Future<void>.delayed(Duration.zero);
    expect(values, isEmpty);
    feed.add(await snapshot(exists: true, cached: false));
    await Future<void>.delayed(Duration.zero);
    expect(values.single?.name, 'Local household');
    feed.add(await snapshot(exists: false, cached: false));
    await Future<void>.delayed(Duration.zero);
    expect(values.length, 2);
    expect(values.last, isNull);
    await subscription.cancel();
    await feed.close();
  });
  test(
      'cached existing family and terminal authorization errors still propagate',
      () async {
    final feed = StreamController<DocumentSnapshot<Map<String, dynamic>>>();
    final values = <Family?>[];
    final errors = <Object>[];
    final service = FamilyService(
        firestore: FakeFirebaseFirestore(), watchFamily: (_) => feed.stream);
    final subscription = service
        .familyStream('local-family')
        .listen(values.add, onError: errors.add);
    feed.add(await snapshot(exists: true, cached: true));
    feed.addError(FirebaseException(
        plugin: 'cloud_firestore', code: 'permission-denied'));
    await Future<void>.delayed(Duration.zero);
    expect(values.single?.name, 'Local household');
    expect(errors.single, isA<FirebaseException>());
    await subscription.cancel();
    await feed.close();
  });
}
