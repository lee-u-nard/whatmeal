import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/models/app_notification.dart';
import 'package:whatmeal/core/services/household_activity_store.dart';
import 'package:whatmeal/features/auth/models/user_model.dart';
import 'package:whatmeal/features/family/models/family_space.dart';
import 'package:whatmeal/features/grocery/data/meal_grocery_projection.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal_plan/data/saved_plans_repository.dart';
import 'package:whatmeal/features/meal_plan/models/meal_plan.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';
import 'package:whatmeal/features/pantry/data/pantry_store.dart';
import 'package:whatmeal/features/pantry/models/pantry_item.dart';

// Two independent repository sessions, using fake Firestore, NOT security/device tests.
void main() {
  test(
      'shared accept replace pantry and deletion flow preserves remaining needs and receipts',
      () async {
    final db = FakeFirebaseFirestore();
    final family = ValueNotifier<FamilySpace?>(
        const FamilySpace(id: 'f', name: 'Home', inviteCode: '', members: [
      SharedSpaceMember(id: 'a', name: 'A', email: '', role: FamilyRole.owner),
      SharedSpaceMember(id: 'b', name: 'B', email: '', role: FamilyRole.member),
    ]));
    final accountA = ValueNotifier<UserModel?>(
        UserModel(id: 'a', name: 'A', email: 'a@test.invalid'));
    final accountB = ValueNotifier<UserModel?>(
        UserModel(id: 'b', name: 'B', email: 'b@test.invalid'));
    final a = SavedPlansRepository(
        firestore: db,
        account: accountA,
        household: family,
        canEditShared: () => true);
    final b = SavedPlansRepository(
        firestore: db,
        account: accountB,
        household: family,
        canEditShared: () => true);
    final activity = HouseholdActivityStore(db);
    List<AppNotification> feed = [];
    final sub = activity
        .watch(uid: 'b', familyId: 'f', joinedAt: DateTime(2000))
        .listen((events) => feed = events);
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 35));
    final id = await a.savePlan(
        MealPlan(
            id: '',
            title: 'Week',
            createdBy: 'a',
            selectedMemberIds: ['dependent-1']),
        [
          Meal(
              id: 'one',
              title: 'Meal one',
              ingredients: [const Ingredient(name: 'rice', amount: '2 cups')]),
          Meal(
              id: 'two',
              title: 'Meal two',
              ingredients: [const Ingredient(name: 'rice', amount: '3 cups')]),
        ]);
    final path = 'families/f/mealPlans/$id';
    await a.updateMealStatus('one', MealStatus.accepted, planPath: path);
    await settle();
    expect(b.value.single.meals.singleWhere((m) => m.id == 'one').status,
        MealStatus.accepted);
    await b.updateMealStatus('two', MealStatus.accepted, planPath: path);
    await settle();
    expect(a.value.single.meals.singleWhere((m) => m.id == 'two').status,
        MealStatus.accepted);
    final stock = db.doc('families/f/pantryItems/rice');
    final pantry = PantryStore(db);
    await pantry.write(
        item: stock,
        actorUid: 'a',
        action: 'added',
        data: PantryItem(
                name: 'rice',
                quantity: '2 cups',
                expirationDate: DateTime(2030))
            .toFirestore());
    Future<double> shortage() async {
      final item = PantryItem.fromFirestore(await stock.get());
      return MealGroceryProjection.calculate(a.value, [item])
          .values
          .where((r) => r.name == 'rice')
          .single
          .missing;
    }

    expect(await shortage(), 3);
    await pantry.write(
        item: stock,
        actorUid: 'b',
        action: 'updated',
        data: {'quantity': '4 cups'});
    expect(await shortage(), 1);
    await a.deleteMeal(path, 'one');
    await settle();
    expect(await shortage(), 0); // Meal two still owns its 3-cup requirement.
    expect(
        MealGroceryProjection.calculate(b.value, []).values.single.required, 3);
    final successor = await b.replaceMeal(
        'two',
        GeneratedMeal.fromCore(Meal(
            id: 'successor',
            title: 'Chicken',
            ingredients: [
              const Ingredient(name: 'chicken', amount: '2 pieces')
            ])),
        planPath: path,
        newMealStatus: MealStatus.accepted);
    await settle();
    final needs = MealGroceryProjection.calculate(a.value, []);
    expect(needs.values.single.name, 'chicken');
    expect(needs.values.single.required, 2);
    expect(
        a.value.single.meals.singleWhere((m) => m.id == 'two').replacedByMealId,
        successor.id);
    await settle();
    final accepted =
        feed.firstWhere((e) => e.type == AppNotificationType.mealAccepted);
    await activity.markRead('b', accepted.id);
    await settle();
    expect(feed.singleWhere((e) => e.id == accepted.id).read, isTrue);
    expect((await db.collection('users/a/notificationReceipts').get()).docs,
        isEmpty);
    final before = (await db.collection('families/f/activity').get()).size;
    await expectLater(
        pantry.write(
            item: db.doc('families/f/pantryItems/missing'),
            actorUid: 'a',
            action: 'updated',
            data: {'quantity': '9'}),
        throwsStateError);
    expect((await db.collection('families/f/activity').get()).size, before);
    await a.updateMealStatus(successor.id, MealStatus.completed,
        planPath: path);
    await settle();
    expect(MealGroceryProjection.calculate(b.value, []), isEmpty);
    accountB.value = null;
    expect(b.value, isEmpty);
    accountB.value = UserModel(
        id: 'outsider', name: 'Outside', email: 'outside@test.invalid');
    await settle();
    expect(b.value, isEmpty);
    await sub.cancel();
    a.dispose();
    b.dispose();
    family.dispose();
    accountA.dispose();
    accountB.dispose();
  });
}
