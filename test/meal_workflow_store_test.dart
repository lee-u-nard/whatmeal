import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/services/meal_workflow_store.dart';
import 'package:whatmeal/core/services/meal_replacement_store.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal_plan/data/saved_plan_stream.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';
import 'package:whatmeal/features/grocery/data/meal_grocery_projection.dart';
import 'package:whatmeal/features/pantry/models/pantry_item.dart';

void main() {
  test(
      'persisted acceptance reaches independent nested listeners and grocery calculation',
      () async {
    final db = FakeFirebaseFirestore();
    final ref = db.doc('families/a/mealPlans/p');
    await ref.set({
      'title': 'Original',
      'selectedMemberIds': ['profile-id']
    });
    await ref.collection('meals').doc('m').set(Meal(
            id: 'm',
            title: 'Soup',
            ingredients: [Ingredient(name: 'onion', amount: '3 pieces')])
        .toFirestore());
    List<SavedMealPlan> first = [], second = [];
    final a = watchSavedPlans(ref.parent).listen((v) => first = v);
    final b = watchSavedPlans(ref.parent).listen((v) => second = v);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(MealGroceryProjection.calculate(first, []), isEmpty);
    await MealWorkflowStore(db).setStatus(
        plan: ref, mealId: 'm', status: MealStatus.accepted, actorUid: 'owner');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(second.single.sourcePath, ref.path);
    expect(second.single.familyMembers, ['profile-id']);
    final result = MealGroceryProjection.calculate(second, [
      PantryItem(
          name: 'onions', quantity: '1 piece', expirationDate: DateTime(2030))
    ]);
    expect(result.values.single.missing, 2);
    final events = await db.collection('families/a/activity').get();
    expect(events.docs.single.data()['type'], 'mealAccepted');
    await MealWorkflowStore(db).setStatus(
        plan: ref, mealId: 'm', status: MealStatus.accepted, actorUid: 'owner');
    expect((await db.collection('families/a/activity').get()).docs.length, 1);
    await a.cancel();
    await b.cancel();
  });

  test('failed meal operation creates neither status nor activity', () async {
    final db = FakeFirebaseFirestore();
    final ref = db.doc('families/a/mealPlans/missing');
    await expectLater(
        MealWorkflowStore(db).setStatus(
            plan: ref,
            mealId: 'm',
            status: MealStatus.accepted,
            actorUid: 'owner'),
        throwsStateError);
    expect((await db.collection('families/a/activity').get()).docs, isEmpty);
    expect((await ref.collection('meals').get()).docs, isEmpty);
  });

  test('replacement commits one event and old grocery contribution disappears',
      () async {
    final db = FakeFirebaseFirestore();
    final ref = db.doc('families/a/mealPlans/p');
    await ref.set({'title': 'Plan'});
    await ref.collection('meals').doc('old').set(Meal(
        id: 'old',
        title: 'Old',
        mealType: 'Dinner',
        dayIndex: 2,
        status: MealStatus.accepted,
        ingredients: [Ingredient(name: 'onion', amount: '2')]).toFirestore());
    final replacement = Meal(
        id: 'new',
        title: 'New',
        ingredients: [Ingredient(name: 'rice', amount: '200 g')]);
    final store = MealReplacementStore(db);
    await store.replace(
        plan: ref,
        oldMealId: 'old',
        replacement: replacement,
        status: MealStatus.accepted,
        actorUid: 'owner');
    await store.replace(
        plan: ref,
        oldMealId: 'old',
        replacement: replacement,
        status: MealStatus.accepted,
        actorUid: 'owner');
    final snapshot = await watchSavedPlans(ref.parent).first;
    final groceries = MealGroceryProjection.calculate(snapshot, []);
    expect(groceries.values.single.name, 'rice');
    expect(snapshot.single.meals.firstWhere((m) => m.id == 'new').dayIndex, 2);
    expect((await db.collection('families/a/activity').get()).docs.length, 1);
  });
}
