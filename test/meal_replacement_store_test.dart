import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/services/meal_replacement_store.dart';
import 'package:whatmeal/features/meal/models/meal.dart';

void main() {
  late FakeFirebaseFirestore db;
  setUp(() {
    db = FakeFirebaseFirestore();
  });
  Future<void> seed() async {
    await db.doc('families/f/mealPlans/p').set({'title': 'Week'});
    await db.doc('families/f/mealPlans/p/meals/old').set(
        Meal(id: 'old', title: 'Old', dayIndex: 3, mealType: 'Dinner')
            .toFirestore());
  }

  Future<MealReplacementResult> replace(String id) =>
      MealReplacementStore(db).replace(
          plan: db.doc('families/f/mealPlans/p'),
          oldMealId: 'old',
          replacement:
              Meal(id: id, title: 'New', dayIndex: 0, mealType: 'Lunch'));

  test('commits both links and retains original day and slot', () async {
    await seed();
    final result = await replace('next');
    expect(result.created, isTrue);
    expect(result.successor.dayIndex, 3);
    expect(result.successor.mealType, 'Dinner');
    expect(
        (await db.doc('families/f/mealPlans/p/meals/old').get())
            .data()?['replacedByMealId'],
        'next');
    expect(
        (await db.doc('families/f/mealPlans/p/meals/next').get())
            .data()?['replacedMealId'],
        'old');
  });
  test('same operation is idempotent and competing successor is rejected',
      () async {
    await seed();
    await replace('next');
    expect((await replace('next')).created, isFalse);
    await expectLater(replace('other'), throwsStateError);
    expect((await db.collection('families/f/mealPlans/p/meals').get()).size, 2);
  });
  test('missing parent does not resurrect deleted plan', () async {
    await seed();
    await db.doc('families/f/mealPlans/p').delete();
    await expectLater(replace('next'), throwsStateError);
    expect((await db.doc('families/f/mealPlans/p').get()).exists, isFalse);
  });
  test('existing destination never overwritten', () async {
    await seed();
    await db.doc('families/f/mealPlans/p/meals/next').set({'title': 'Keep'});
    await expectLater(replace('next'), throwsStateError);
    expect(
        (await db.doc('families/f/mealPlans/p/meals/next').get())
            .data()?['title'],
        'Keep');
  });
  test('generated document ID is returned and stored in predecessor', () async {
    await seed();
    final result = await replace('');
    expect(result.successor.id, isNotEmpty);
    expect(
        (await db.doc('families/f/mealPlans/p/meals/old').get())
            .data()?['replacedByMealId'],
        result.successor.id);
  });
  for (final omitted in [false, true]) {
    test(
        'replacement preserves ${omitted ? "missing" : "null"} original meal slot',
        () async {
      await db.doc('families/f/mealPlans/p').set({'title': 'Week'});
      final original =
          Meal(id: 'old', title: 'Unslotted', dayIndex: 3).toFirestore();
      if (omitted) original.remove('mealType');
      await db.doc('families/f/mealPlans/p/meals/old').set(original);
      final result = await replace('next');
      expect(result.successor.mealType, isNull);
      expect(result.successor.dayIndex, 3);
      final old =
          (await db.doc('families/f/mealPlans/p/meals/old').get()).data()!;
      final next =
          (await db.doc('families/f/mealPlans/p/meals/next').get()).data()!;
      expect(old.containsKey('mealType'), isTrue);
      expect(old['mealType'], isNull);
      expect(next['mealType'], isNull);
      expect(next['replacedMealId'], 'old');
      expect(old['replacedByMealId'], 'next');
    });
  }
}
