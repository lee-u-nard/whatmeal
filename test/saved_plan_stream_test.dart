import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal_plan/data/saved_plan_stream.dart';

void main() {
  test('nested meal watcher boundary is used and forwards terminal errors',
      () async {
    final db = FakeFirebaseFirestore();
    final col = db.collection('users/a/mealPlans');
    await col.doc('p').set({'title': 'Week', 'createdAt': Timestamp.now()});
    final feed =
        StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast(
            sync: true);
    var watches = 0;
    final errors = <Object>[];
    final sub = watchSavedPlans(col, watchMeals: (_) {
      watches++;
      return feed.stream;
    }).listen((_) {}, onError: errors.add);
    addTearDown(() async {
      await sub.cancel();
      await feed.close();
    });
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(watches, 1,
        reason: 'Fault injection must reach the actual child subscription');
    feed.addError(StateError('synthetic child denial'));
    await Future<void>.delayed(Duration.zero);
    expect(errors.single, isA<StateError>());
  });
  test(
      'nested status/favorite/add/delete changes publish without parent writes',
      () async {
    final db = FakeFirebaseFirestore();
    final plans = db.collection('users/a/mealPlans');
    final plan = plans.doc('p');
    await plan.set({'title': 'Week', 'createdAt': Timestamp.now()});
    final meal = plan.collection('meals').doc('m');
    await meal.set(Meal(id: 'm', title: 'Soup').toFirestore());
    final events = StreamIterator(watchSavedPlans(plans));
    addTearDown(events.cancel);
    expect(await events.moveNext().timeout(const Duration(seconds: 5)), isTrue);
    expect(events.current.single.meals.single.title, 'Soup');
    await meal.update({'status': 'completed', 'isFavorite': true});
    expect(await events.moveNext().timeout(const Duration(seconds: 5)), isTrue);
    expect(events.current.single.meals.single.isCompleted, isTrue);
    expect(events.current.single.meals.single.isFavorite, isTrue);
    await meal.delete();
    expect(await events.moveNext().timeout(const Duration(seconds: 5)), isTrue);
    expect(events.current.single.meals, isEmpty);
    await plan
        .collection('meals')
        .doc('m')
        .set(Meal(id: 'm', title: 'Rice').toFirestore());
    expect(await events.moveNext().timeout(const Duration(seconds: 5)), isTrue);
    expect(events.current.single.meals.single.title, 'Rice');
    await plan.delete();
    expect(await events.moveNext().timeout(const Duration(seconds: 5)), isTrue);
    expect(events.current, isEmpty);
  });

  test('cancellation stops old scope callbacks', () async {
    final db = FakeFirebaseFirestore();
    final col = db.collection('users/a/mealPlans');
    final received = <Object>[];
    final first = Completer<void>();
    final sub = watchSavedPlans(col).listen((plans) {
      received.add(plans);
      if (!first.isCompleted) first.complete();
    });
    await first.future;
    await sub.cancel();
    final count = received.length;
    await col
        .doc('late')
        .set({'title': 'Old account', 'createdAt': Timestamp.now()});
    await Future<void>.delayed(Duration.zero);
    expect(received.length, count);
  });
}
