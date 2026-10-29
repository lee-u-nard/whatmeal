import 'package:whatmeal/features/meal_plan/models/meal_plan.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/auth/models/user_model.dart';
import 'package:whatmeal/features/family/models/family_space.dart';
import 'package:whatmeal/features/meal_plan/data/saved_plans_repository.dart';
import 'package:whatmeal/features/meal/models/meal.dart';

void main() {
  test('generated plan commit preserves meal identity, dates and participants', () async {
    final db = FakeFirebaseFirestore();
    final account = ValueNotifier<UserModel?>(UserModel(id: 'a', name: 'A', email: 'a@example.test'));
    final household = ValueNotifier<FamilySpace?>(null);
    final repo = SavedPlansRepository(firestore: db, account: account, household: household, canEditShared: () => true);
    final start = DateTime(2026, 10, 5);
    final id = await repo.savePlan(MealPlan(id: '', title: 'Generated', startDate: start,
      numberOfDays: 2, mealTypes: ['Dinner'], selectedMemberIds: ['profile-a'], createdBy: 'a'),
      [Meal(id: 'generated-1', title: 'Rice dinner', dayIndex: 1, mealType: 'Dinner')]);
    final parent = (await db.doc('users/a/mealPlans/$id').get()).data()!;
    expect(parent['selectedMemberIds'], ['profile-a']);
    expect((parent['startDate'] as Timestamp).toDate(), start);
    final child = (await db.doc('users/a/mealPlans/$id/meals/generated-1').get()).data()!;
    expect(child['dayIndex'], 1);
    expect(child['mealType'], 'Dinner');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(repo.value.single.meals.single.id, 'generated-1');
    repo.dispose(); account.dispose(); household.dispose();
  });
  test('A logout B login A reentry clears state and rejects stale scope mutations', () async {
    final db = FakeFirebaseFirestore();
    for (final uid in ['a', 'b']) {
      final plan = db.doc('users/$uid/mealPlans/same-id');
      await plan.set({'title': uid, 'createdAt': Timestamp.now()});
      await plan.collection('meals').doc('same-meal').set(Meal(id: 'same-meal', title: 'Meal $uid').toFirestore());
    }
    UserModel user(String uid) => UserModel(id: uid, name: uid, email: '$uid@example.test');
    final account = ValueNotifier<UserModel?>(user('a'));
    final household = ValueNotifier<FamilySpace?>(null);
    final repo = SavedPlansRepository(firestore: db, account: account, household: household, canEditShared: () => true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(repo.value.single.title, 'a');
    final firstSession = repo.sessionVersion;
    account.value = null;
    expect(repo.value, isEmpty);
    account.value = user('b');
    expect(repo.value, isEmpty);
    await db.doc('users/a/mealPlans/same-id/meals/same-meal').update({'title': 'Late A'});
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(repo.value.single.title, 'b');
    expect(repo.value.single.meals.single.title, 'Meal b');
    await expectLater(repo.updateMealStatus('same-meal', MealStatus.accepted, planPath: 'users/a/mealPlans/same-id'), throwsStateError);
    expect((await db.doc('users/a/mealPlans/same-id/meals/same-meal').get()).data()!['status'], 'pending');
    account.value = user('a');
    expect(repo.value, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(repo.sessionVersion, greaterThan(firstSession));
    expect(repo.value.single.meals.single.title, 'Late A');
    repo.dispose(); account.dispose(); household.dispose();
  });
}
